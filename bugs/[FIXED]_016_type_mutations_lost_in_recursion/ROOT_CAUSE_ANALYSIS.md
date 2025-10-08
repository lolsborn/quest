# Root Cause Analysis: Bug #016 - Type Mutations Lost in Recursion

**Date**: 2025-10-06
**Status**: Root cause identified, solution requires significant refactoring

---

## The Problem

When a type instance is passed as a parameter to a function, mutations made inside the function do NOT persist in the caller's version of the object. This affects both recursive and non-recursive calls.

### What Works:
```quest
let c = Counter.new(count: 0)
c.increment()  # ✅ Works - method called ON object
puts(c.count)  # 1
```

### What Doesn't Work:
```quest
fun mutate(counter)
    counter.increment()
end

let c = Counter.new(count: 0)
mutate(c)      # ❌ Doesn't work - object passed as parameter
puts(c.count)  # 0 (should be 1)
```

---

## Root Cause

### 1. Current Implementation

**File**: `src/types/mod.rs:216`
```rust
pub enum QValue {
    // ...
    Struct(Box<QStruct>),  // ← Uses Box, not Rc<RefCell<>>
    // ...
}
```

**File**: `src/types/user_types.rs:155`
```rust
#[derive(Debug, Clone)]  // ← Clone derives deep copy
pub struct QStruct {
    pub type_name: String,
    pub type_id: u64,
    pub fields: HashMap<String, QValue>,
    pub id: u64,
}
```

### 2. The Problem Flow

**File**: `src/function_call.rs:74-76`
```rust
// Bind parameters to arguments
for (param_name, arg_value) in user_fun.params.iter().zip(args.iter()) {
    func_scope.declare(param_name, arg_value.clone())?;  // ← DEEP COPY!
}
```

When a function is called:

```quest
let c = Counter.new(count: 0)
mutate(c)
```

1. `c` contains `QValue::Struct(Box<QStruct { count: 0 }>)`
2. `mutate()` is called with `args = [c]`
3. Line 75 does `arg_value.clone()` which:
   - Clones the `QValue` enum (cheap)
   - Which contains `Box<QStruct>`
   - The `Clone` impl for `Box<T>` clones the inner `T`
   - QStruct derives `Clone`, so it deep copies the struct
   - Result: **Completely separate copy** with different memory address

4. Inside `mutate()`, the parameter `counter` points to the COPY
5. `counter.increment()` mutates the COPY
6. Function returns, COPY is discarded
7. Original `c` is unchanged

---

## Why Method Calls Work

When you call a method ON an object:

**File**: `src/main.rs:2149-2166`
```rust
// Bind 'self' to the struct and call method
scope.push();
scope.declare("self", result.clone())?;  // Clone here too
let return_value = call_user_function(method, args, scope)?;
// Get potentially modified self from scope
let updated_self = scope.get("self").unwrap();
scope.pop();

// Update the original variable with potentially modified struct
if let (Some(ref var_name), QValue::Struct(_)) = (&original_identifier, &updated_self) {
    if var_name != "self" {
        scope.set(var_name, updated_self);  // ← COPY BACK!
    }
}
```

This works because:
1. `self` is cloned (line 2151)
2. Method modifies the clone
3. **Clone is copied back to the original variable** (line 2164)

But this ONLY works when:
- The object is accessed via a variable name (`c.method()`)
- The variable name is tracked in `original_identifier`

It does NOT work when:
- Object is passed as parameter (no `original_identifier`)
- Object is in an array/dict (`array[0].method()` - no single variable)

---

## Why Other Languages Don't Have This Problem

### Python:
```python
class Counter:
    def __init__(self):
        self.count = 0

def mutate(counter):
    counter.count += 1

c = Counter()
mutate(c)  # ✅ Works!
print(c.count)  # 1
```

Python uses **reference semantics** - objects are always passed by reference.

### Ruby:
```ruby
class Counter
  attr_accessor :count
  def initialize
    @count = 0
  end
end

def mutate(counter)
  counter.count += 1
end

c = Counter.new
mutate(c)  # ✅ Works!
puts c.count  # 1
```

Ruby also uses **reference semantics** for objects.

### JavaScript:
```javascript
class Counter {
  constructor() { this.count = 0; }
}

function mutate(counter) {
  counter.count++;
}

let c = new Counter();
mutate(c);  // ✅ Works!
console.log(c.count);  # 1
```

JavaScript also passes objects by reference.

### Rust (Quest's implementation language):
```rust
struct Counter {
    count: i32,
}

fn mutate(counter: &mut Counter) {  // Explicit &mut reference
    counter.count += 1;
}

let mut c = Counter { count: 0 };
mutate(&mut c);  // ✅ Works!
println!("{}", c.count);  // 1
```

Rust requires **explicit mutable references** (`&mut`).

---

## The Solution

Quest currently uses **value semantics** (copy on assignment/parameter passing). We need **reference semantics** for type instances.

### Option 1: Use Rc<RefCell<>> (Recommended)

Change struct representation from `Box<QStruct>` to `Rc<RefCell<QStruct>>`:

**File**: `src/types/mod.rs`
```rust
use std::rc::Rc;
use std::cell::RefCell;

pub enum QValue {
    // ...
    Struct(Rc<RefCell<QStruct>>),  // ← Reference-counted mutable reference
    // ...
}
```

**Pros:**
- Matches Python/Ruby/JS semantics
- `.clone()` shares the reference (cheap)
- Mutations visible to all holders of the reference
- No need to track `original_identifier`

**Cons:**
- Requires changes throughout the codebase
- Runtime borrow checking (may panic if rules violated)
- Slight performance overhead (reference counting)

### Option 2: Copy-Back Mechanism for Parameters

Modify `call_user_function()` to copy back modified structs:

**File**: `src/function_call.rs`
```rust
// After function execution, before returning
for (param_name, arg_value) in user_fun.params.iter().zip(args.iter()) {
    if let QValue::Struct(_) = arg_value {
        // If parameter was a struct, copy it back
        if let Some(modified) = func_scope.get(param_name) {
            // But how do we update the CALLER's version?
            // We don't have a reference to the caller's variable!
        }
    }
}
```

**Pros:**
- Minimal changes to type system

**Cons:**
- Doesn't work - we don't have a reference to the caller's variable
- Would require passing mutable references to function call
- Doesn't match Python/Ruby/JS semantics

### Option 3: Make Structs Immutable (Not Recommended)

Remove mutation capability from structs entirely.

**Pros:**
- Avoids the problem

**Cons:**
- Breaks existing code
- Incompatible with user expectations
- Defeats the purpose of mutable types

---

## Recommended Approach

**Implement Option 1: Rc<RefCell<>> for Structs**

This matches all major scripting languages and is the least surprising behavior.

### Implementation Steps:

1. **Change QValue enum**:
   ```rust
   Struct(Rc<RefCell<QStruct>>)
   ```

2. **Update all struct creation sites**:
   ```rust
   // Old:
   QValue::Struct(Box::new(qstruct))

   // New:
   QValue::Struct(Rc::new(RefCell::new(qstruct)))
   ```

3. **Update all struct access sites**:
   ```rust
   // Old:
   if let QValue::Struct(ref s) = value {
       s.fields.get("x")
   }

   // New:
   if let QValue::Struct(ref s) = value {
       s.borrow().fields.get("x")
   }
   ```

4. **Update all struct mutation sites**:
   ```rust
   // Old:
   if let QValue::Struct(ref mut s) = value {
       s.fields.insert("x", QValue::Int(...));
   }

   // New:
   if let QValue::Struct(ref s) = value {
       s.borrow_mut().fields.insert("x", QValue::Int(...));
   }
   ```

5. **Remove copy-back logic**:
   - Lines 2160-2166 in `src/main.rs` can be simplified
   - No longer need to track `original_identifier` for structs

### Testing:

- All existing tests should pass
- Bug #016 test cases should pass
- Verify no borrow panics occur

---

## Impact Analysis

### Files to Change:

```bash
$ rg "QValue::Struct\|Box<QStruct>" --files-with-matches
src/main.rs              # Primary file - many changes
src/types/mod.rs         # Enum definition
src/types/user_types.rs  # Struct definition
src/scope.rs             # May have struct handling
```

### Estimated Effort:

- **3-5 hours** for implementation
- **1-2 hours** for testing
- **Total: 4-7 hours**

### Risk Level: **MEDIUM**

- Core type system change
- Touches many code paths
- Potential for borrow panics if not careful
- Comprehensive test suite helps mitigate risk

---

## Alternative: Shallow Investigation

If full refactoring is too risky, investigate why the copy-back mechanism (lines 2160-2166) doesn't work for parameters:

```rust
// This works for: c.increment()
if let (Some(ref var_name), QValue::Struct(_)) = (&original_identifier, &updated_self) {
    scope.set(var_name, updated_self);
}

// But not for: mutate(c) where parameter is 'counter'
// Because 'counter' is the parameter name, not 'c'
```

Could we pass metadata about the original variable through the call chain? This seems more complex than just using references.

---

## Conclusion

**Root cause**: Structs use `Box<QStruct>` with `Clone` trait, causing deep copies on parameter passing.

**Solution**: Change to `Rc<RefCell<QStruct>>` for reference semantics, matching Python/Ruby/JS.

**Priority**: HIGH - Blocks recursive algorithms and violates user expectations.
