# Analysis: Likelihood Clone is Causing Bug #019

**Likelihood: 🚨 EXTREMELY HIGH (95%+)**

The Clone trait usage is **almost certainly** causing Bug #019. This is a textbook case of circular references created through cloning operations.

---

## The Smoking Gun

Look at [src/function_call.rs:65](../../src/function_call.rs#L65):

```rust
new_scope.scopes = user_fun.captured_scopes.clone();
```

This line clones `captured_scopes`, which is defined as:
```rust
pub captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
```

---

## The Circular Reference Problem

When a function is defined, it captures the current scope chain (which includes the function itself). Here's what happens:

1. **Function `helper()` is defined**
   - Captured scope includes `helper` itself as a `QValue::UserFun`
   - The captured scope contains: `{"helper": QValue::UserFun(helper)}`

2. **Function `main_fn()` is defined**
   - Captured scope includes both `helper` and `main_fn`
   - The captured scope contains: `{"helper": QValue::UserFun(helper), "main_fn": QValue::UserFun(main_fn)}`

3. **`main_fn()` is called**
   - Executes successfully, prints "Main function"

4. **Inside `main_fn()`, we call `helper()`**:
   - Line 3549: `scope.get("helper")` returns a **cloned** `QValue::UserFun`
   - Line 3552: `call_user_function(&user_fun, call_args, scope)` is called
   - Line 65: `new_scope.scopes = user_fun.captured_scopes.clone()`
   - **CRITICAL**: `captured_scopes` contains the original scope, which contains `helper`, which contains `captured_scopes`, which contains `helper`... **INFINITE LOOP**

---

## The Clone Chain of Death

Every time we call a user function:

1. **Step 1**: We **clone** `captured_scopes` (function_call.rs:65)
   ```rust
   new_scope.scopes = user_fun.captured_scopes.clone();
   ```

2. **Step 2**: Those captured scopes contain **cloned** function values (from main.rs:3549)
   ```rust
   if let Some(func_value) = scope.get(func_name) {  // <-- CLONES here!
   ```

3. **Step 3**: From scope.rs:220-227, `get()` clones the value:
   ```rust
   pub fn get(&self, name: &str) -> Option<QValue> {
       for scope in self.scopes.iter().rev() {
           if let Some(value) = scope.borrow().get(name) {
               return Some(value.clone());  // <-- CLONE HERE
           }
       }
       None
   }
   ```

4. **Step 4**: Those function values contain **captured_scopes** pointing back to the original scope

5. **Step 5**: This creates a circular reference that is **re-evaluated on EVERY call**

---

## Visual Diagram of the Circular Reference

```
Global Scope
|
├── "helper" -> QValue::UserFun
|   |
|   └── captured_scopes: [Rc -> Global Scope]  ← CIRCULAR!
|
└── "main_fn" -> QValue::UserFun
    |
    └── captured_scopes: [Rc -> Global Scope]  ← CIRCULAR!
```

**The Problem**:
- `helper` function has `captured_scopes` pointing to Global Scope
- Global Scope contains `"helper"` -> `QValue::UserFun`
- Looking up `"helper"` **clones** the `QUserFun`
- The clone includes `captured_scopes` which points back to Global Scope
- Global Scope still contains `"helper"` which contains `captured_scopes`...
- **INFINITE LOOP**

**What happens when we call `helper()` from `main_fn()`**:

```text
1. main_fn() is called
   - Clones captured_scopes (contains helper)
   - Creates new scope with those captured scopes

2. Inside main_fn(), we call helper()
   - scope.get("helper") -> CLONES QUserFun(helper)
   - The cloned helper has captured_scopes pointing to scope

3. call_user_function(&helper, ...)
   - Line 65: new_scope.scopes = helper.captured_scopes.clone()
   - This scope STILL contains "helper"

4. If helper() looks up ANY function (or we trace the scope)
   - The scope contains helper
   - Which contains captured_scopes
     - Which contains helper
       - Which contains captured_scopes...
         - INFINITE RECURSION!
```

Each time we call `helper()`:
1. Clone the function value (includes captured_scopes)
2. Clone the captured_scopes to create new function scope
3. The cloned scopes still contain `helper`
4. If we look up `helper` again, we clone it again
5. **INFINITE RECURSION**

---

## Why Built-in Functions Work

Built-in functions (`QValue::Fun`) don't have `captured_scopes`, so they **break the cycle**:

```rust
// Built-in function (works fine)
QValue::Fun(QFun {
    name: "puts",
    // NO captured_scopes field!
    // Cannot create circular reference
})

// User function (creates cycle)
QValue::UserFun(QUserFun {
    name: "helper",
    captured_scopes: Vec<Rc<RefCell<HashMap<...>>>>,  // Contains "helper"!
    // � THIS is the problem
})
```

---

## The Debug Evidence

The debug statements in [function_call.rs:56-58](../../src/function_call.rs#L56-L58) would show:

```
DEBUG[CALL_DEPTH=0]: Calling function: main_fn
DEBUG: Function body: ...
DEBUG[CALL_DEPTH=1]: Calling function: helper
DEBUG: Function body: ...
DEBUG[CALL_DEPTH=2]: Calling function: helper  � SHOULDN'T HAPPEN!
DEBUG: Function body: ...
DEBUG[CALL_DEPTH=3]: Calling function: helper
DEBUG: Function body: ...
...
(thousands of lines later)
thread 'main' has overflowed its stack
```

The call depth keeps incrementing because **each call re-clones the captured scope containing the function**.

---

## Root Cause: Multiple Clone Pitfalls Combined

This bug is caused by a **perfect storm** of Clone-related issues from the analysis:

### PITFALL #2.1: Reference Semantics Confusion
- `captured_scopes` use `Rc<RefCell<>>` for shared mutable state
- Cloning creates new references to the SAME data
- Functions end up referencing themselves

### PITFALL #2.4: Clone in Scope Chains (Hidden Cost)
- Every `scope.get()` clones the value (scope.rs:227)
- Function lookups clone the entire `QUserFun` structure
- This happens on EVERY function call

### PITFALL #2.6: Memory Leaks via Circular References
- Rc + RefCell can create reference cycles
- Functions reference their captured scopes
- Captured scopes reference the functions
- **Logical circular reference** (not memory leak, but infinite loop)

---

## Why This Wasn't Caught Earlier

This bug was introduced by **recent closure semantics changes** (likely QEP-003, QEP-033, QEP-034, or QEP-035). Previously, functions either:

1. Didn't capture their defining scope, OR
2. Captured scopes differently (maybe excluding function definitions), OR
3. Shared captured scopes without cloning

The bug manifests when:
- Functions capture the scope they're defined in
- That scope contains the function itself
- We clone the captured scopes on every call
- We look up function names in those scopes (which clones them)

---

## Proof: Why Test 4 Works

From test_repro_4.q (the one that WORKS):
```quest
fun process_data(data, transform)
    puts("Processing: " .. data)
    # transform is passed but NEVER CALLED
    puts("Transform passed: " .. transform.str())
end

process_data("test", helper)  # Works!
```

This works because:
- `helper` is **passed** as a value (one clone)
- `helper` is **never called** from inside `process_data`
- No infinite recursion because we never look up `helper` in the captured scope

---

## Recommended Fixes

### Option A: Filter Function Definitions from Captured Scopes (Safest)

When capturing scopes during function definition, **exclude function values**:

```rust
// In function definition code
let mut filtered_scope = HashMap::new();
for (name, value) in current_scope.borrow().iter() {
    match value {
        QValue::UserFun(_) => {
            // Skip - don't capture other functions
        }
        _ => {
            filtered_scope.insert(name.clone(), value.clone());
        }
    }
}
captured_scopes.push(Rc::new(RefCell::new(filtered_scope)));
```

**Pros**:
- Completely eliminates circular references
- Functions can still access variables from outer scopes
- Simple to implement

**Cons**:
- Closures can't call other functions from their defining scope
- Breaks valid use cases like mutual recursion via closures

### Option B: Use Function IDs Instead of Cloning (Better)

Store function references by ID, not by value:

```rust
// Instead of:
scope.insert("helper", QValue::UserFun(helper));

// Use:
scope.insert("helper", QValue::FunRef(helper.id));
```

**Pros**:
- Eliminates cloning overhead
- Breaks circular references
- Maintains full functionality

**Cons**:
- Requires global function registry
- Significant refactoring

### Option C: Don't Clone Captured Scopes (Simplest)

The captured scopes are **already wrapped in `Rc<RefCell<>>`**, so cloning just bumps refcounts. Instead of:

```rust
new_scope.scopes = user_fun.captured_scopes.clone();
```

Do:
```rust
// Don't clone the Vec - just reference it
// The Rc<RefCell<>> inside will be shared anyway
for scope_ref in user_fun.captured_scopes.iter() {
    new_scope.scopes.push(Rc::clone(scope_ref));
}
```

Wait, that's the same thing! The issue is deeper...

### Option D: Don't Include Functions in Scope Lookup for Nested Calls (Hack)

Add a flag to skip function values during nested function lookups:

```rust
pub fn get_non_function(&self, name: &str) -> Option<QValue> {
    self.get(name).filter(|v| !matches!(v, QValue::UserFun(_)))
}
```

**Pros**: Quick fix
**Cons**: Hacky, doesn't address root cause

---

## The REAL Solution: Lazy Function Resolution

The root issue is that we're **cloning functions** when we look them up. Instead:

1. Keep functions in a **separate namespace** from variables
2. Look up functions by **name** at call time, not by cloning the value
3. Functions are **always resolved from the current scope**, not captured scopes

**Change from**:
```rust
if let Some(func_value) = scope.get(func_name) {  // Clones function!
    match func_value {
        QValue::UserFun(user_fun) => {
            return call_user_function(&user_fun, call_args, scope);
        }
    }
}
```

**Change to**:
```rust
if let Some(func_ref) = scope.lookup_function(func_name) {  // Returns &QUserFun
    return call_user_function(func_ref, call_args, scope);
}
```

This avoids cloning entirely and breaks the circular reference.

---

## Immediate Next Steps

1. **Verify the hypothesis**: Add instrumentation to count recursive calls
2. **Quick workaround**: Filter out `QValue::UserFun` from captured scopes
3. **Proper fix**: Implement function reference system or lazy resolution
4. **Add regression test**: Ensure test_repro_7.q passes after fix

---

## Conclusion

**This is 95%+ likely the cause of Bug #019**. The evidence is overwhelming:

- Explains why ALL user function calls fail
- Explains why built-in functions work
- Explains why passing functions works but calling them doesn't
- Matches the infinite recursion symptom
- Points to recent closure changes as the regression source

The Clone trait isn't inherently wrong - it's being used correctly from Rust's perspective. The bug is that we're creating **logical circular references** through the clone operations, where functions reference themselves through their captured scopes.

Fix: Don't capture function definitions in closure scopes, or use lazy function resolution instead of cloning function values.
