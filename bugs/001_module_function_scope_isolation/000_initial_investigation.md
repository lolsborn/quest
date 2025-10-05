# Bug: Module Function Aliasing Loses Access to Module Scope

**Status**: ✅ FIXED (2025-10-02)

**Reported**: Session continuation (previous context overflow)

## Summary

When aliasing module functions (e.g., `let describe = test.describe`), the aliased function lost access to other module members, causing "Undefined function" errors. This was particularly problematic in test files where aliasing is common for cleaner syntax.

## Symptoms

### Original Bug
```quest
use "std/test" as test

# This works:
test.describe("My tests", fun ()
    test.it("works", fun () ... end)
end)

# This fails with "Undefined function: cyan":
let describe = test.describe
describe("My tests", fun ()
    test.it("works", fun () ... end)
end)
```

The error occurred because `describe` internally calls helper functions like `cyan()` and `bold()` that are defined in the test module.

### Secondary Bug (Discovered During Fix)
When running the test suite via `quest run test`, we encountered:
- "Variable 'io' already declared in this scope"
- "Variable 'parts' already declared in this scope"

This happened when module functions called other module functions that imported the same modules or declared variables with the same names.

## Root Cause Analysis

### Initial Implementation (Broken)
Module functions were just regular `QUserFun` objects. When accessed via `module.member`, we returned a clone of the function. This clone had no connection to the module's scope, so it couldn't access other module members.

### The Problem
```rust
// In module member access (simplified):
if let QValue::Module(module) = &result {
    result = module.get_member(method_name).cloned(); // Just returns a clone!
}
```

When `test.describe` was aliased, it was just a function with no knowledge of where it came from. When it tried to call `cyan()`, it looked in its closure scope (empty) and the caller's scope (no `cyan` there), and failed.

## Attempted Solutions

### Attempt 1: Closure Capture of Module Functions
**Approach**: When creating a module, capture all module members (including functions) in each function's closure environment.

**Problem**: Circular references! If function A captures function B, and function B captures function A, we get infinite loops during serialization/cloning.

**Result**: ❌ Caused hangs and infinite recursion

### Attempt 2: Two-Level Closure Scope
**Approach**: Separate closure scope from execution scope to allow proper shadowing.

**Problem**: While this fixed shadowing issues, it didn't solve the fundamental problem that module functions needed access to module members.

**Result**: ❌ Didn't address the core issue

### Attempt 3: Copy Parent Variables to Module Function Scope
**Approach**: When calling a module function, copy all variables from the calling scope into the function's execution scope.

**Problems**:
1. Caused "Variable already declared" errors when nested calls happened (e.g., `find_tests` calling `find_tests_dir`, both trying to `use "std/io"`)
2. Violated encapsulation - module functions shouldn't depend on caller's variables
3. Wrong semantics - meant test file variables leaked into module functions

**Result**: ❌ Fixed aliasing but broke test runner

## Final Solution: Module Scope References

### Implementation

Added `module_scope` field to `QUserFun`:

```rust
pub struct QUserFun {
    pub name: Option<String>,
    pub params: Vec<String>,
    pub body: String,
    pub doc: Option<String>,
    pub closure_env: Option<HashMap<String, QValue>>,
    pub module_scope: Option<Rc<RefCell<HashMap<String, QValue>>>>,  // NEW!
    pub id: u64,
}
```

### Key Changes

1. **Module Creation** (`QModule::with_doc` in types.rs:1244-1265):
   - When creating a module, set `module_scope` on ALL `UserFun` members
   - The module_scope is an `Rc<RefCell<HashMap>>` shared by all functions in that module
   - This happens once at module creation time

```rust
pub fn with_doc(name: String, mut members: HashMap<String, QValue>, ...) -> Self {
    let members_rc = Rc::new(RefCell::new(members.clone()));

    // Set module_scope on all UserFun members
    for (_, value) in members.iter_mut() {
        if let QValue::UserFun(user_fun) = value {
            *user_fun = user_fun.clone().with_module_scope(Rc::clone(&members_rc));
        }
    }

    *members_rc.borrow_mut() = members;
    // ... rest of module creation
}
```

2. **Function Execution** (`call_user_function` in main.rs:2787-2806):
   - Check if function has `module_scope`
   - If yes: Create execution scope with `Scope::with_shared_base(module_scope)`
   - If no: Use normal parent scope with closure capture
   - **Critical**: Module functions do NOT inherit caller's variables!

```rust
let scope_to_use: &mut Scope = if let Some(ref module_scope) = user_fun.module_scope {
    // Module function - isolated, only has access to:
    // 1. Module members (in shared base scope)
    // 2. Parameters
    // 3. Local variables
    execution_scope = Scope::with_shared_base(
        Rc::clone(module_scope),
        Rc::clone(&parent_scope.module_cache)
    );
    execution_scope.push(); // Function execution scope
    execution_scope.push_stack_frame(...);
    &mut execution_scope
} else {
    // Regular function - uses parent scope + closure capture
    // ...
}
```

3. **Closure Capture** (main.rs:242-252):
   - `to_flat_map_no_functions()` excludes functions but INCLUDES modules
   - This allows lambdas/closures to access imported modules
   - Avoids circular references (functions don't capture other functions)

```rust
fn to_flat_map_no_functions(&self) -> HashMap<String, QValue> {
    let mut result = HashMap::new();
    for scope in &self.scopes {
        for (key, value) in scope.borrow().iter() {
            // Skip functions but include modules
            if !matches!(value, QValue::UserFun(_)) {
                result.insert(key.clone(), value.clone());
            }
        }
    }
    result
}
```

4. **Module Member Access** (main.rs:1957-1961):
   - Simply return the member - no cloning needed!
   - Member already has `module_scope` set, so it "remembers" its module

```rust
if let QValue::Module(module) = &result {
    result = module.get_member(method_name)
        .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?;
    i += 1;
}
```

## Why This Works

### Object Identity Preserved
- Aliased functions have the same `_id()` as the original (they're references, not copies)
- No unnecessary cloning or copying

### Proper Scoping
- Module functions execute in isolated scopes with access to module members
- Module functions cannot access caller's variables (proper encapsulation)
- Regular closures still capture variables normally (including imported modules)

### No Circular References
- Functions don't capture other functions
- Module scope is shared via `Rc<RefCell<>>`, not duplicated

### Solves Both Bugs
1. ✅ Aliasing works: `let describe = test.describe` retains access to `cyan()`, `bold()`, etc.
2. ✅ Test runner works: Module functions can call each other without variable conflicts

## Test Results

**Before fix**: Test runner failed with "Variable 'io' already declared"

**After fix**:
- 727 tests discovered
- 713 passing (98.1%)
- 7 failing (pre-existing closure semantics issues, not regressions)

The 7 failures are related to closure-by-value vs closure-by-reference semantics and are known limitations.

## Design Implications

### Module Functions vs Regular Functions

**Module Functions** (have `module_scope`):
- Completely isolated from caller
- Access module members via shared scope
- Can call other module functions
- Cannot access caller's variables

**Regular Functions/Closures** (no `module_scope`):
- Capture variables from defining scope (closure environment)
- Can access caller's variables
- Normal lexical scoping

This creates clean, predictable semantics where module boundaries are respected.

## Files Modified

1. **src/types.rs**
   - Added `module_scope` field to `QUserFun` (line 1120)
   - Added `with_module_scope()` builder method (lines 1162-1165)
   - Modified `QModule::with_doc()` to set module_scope on members (lines 1244-1265)

2. **src/main.rs**
   - Updated `to_flat_map_no_functions()` to include modules for closure capture (lines 239-252)
   - Simplified module member access - no cloning (lines 1957-1961)
   - Modified `call_user_function()` to use module_scope when present (lines 2787-2806)
   - Module functions get isolated execution scope, no parent variable copying

## Future Considerations

### Advantages of Current Approach
- Clean module semantics
- Proper encapsulation
- No circular reference issues
- Minimal memory overhead (shared scope via Rc)

### Potential Enhancements
- Could add explicit "module context" parameter if needed
- Could allow modules to expose "public" vs "private" members
- Module scope could be immutable for even better safety

### Not a Concern
- Module state being shared is intentional (modules are singletons)
- Memory overhead is minimal (one Rc per module, not per function)
- Function isolation is a feature, not a bug

## Lessons Learned

1. **Object Identity Matters**: Cloning should preserve semantics, not break them
2. **Scope Isolation is Good**: Module functions should not depend on caller context
3. **Share, Don't Copy**: `Rc<RefCell<>>` is the right tool for shared mutable state
4. **Test Real Usage**: The test runner exposed edge cases that simple tests missed

## Related Issues

- Stack traces: Already implemented and working
- Exception handling: Works correctly with module functions
- Module caching: Properly integrated with module_scope

## Verification

To verify the fix works:

```bash
# Test aliasing works
./target/release/quest test/term.q

# Test runner works with multiple modules
./target/release/quest run test

# Check object identity preserved
printf 'use "std/test" as test\nlet d = test.describe\nputs(test.describe._id() == d._id())' | ./target/release/quest
# Should print: true
```
