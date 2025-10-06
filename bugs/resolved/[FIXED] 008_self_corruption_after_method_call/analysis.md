# Technical Analysis: `self` Corruption Bug

## Root Cause

The bug is in `src/scope.rs` in the `set()` method:

```rust
pub fn set(&mut self, name: &str, value: QValue) {
    // Search from innermost to outermost
    for scope in self.scopes.iter().rev() {
        if scope.borrow().contains_key(name) {
            scope.borrow_mut().insert(name.to_string(), value);
            return;  // <-- BUG: Modifies outer scope!
        }
    }
    // Not found in any scope - add to current (innermost) scope
    self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
}
```

**Problem**: When `scope.set("self", new_value)` is called, it walks up the scope chain and modifies the FIRST scope that contains `self`, even if that's an outer scope that shouldn't be modified.

## Execution Flow

1. **Logger.handle() executing**
   - `self` = Logger instance (in Logger's method scope)

2. **Access handler from array**
   ```quest
   let handler = self.handlers[i]
   ```

3. **Call method on handler**
   ```quest
   handler.handle(record_data)
   ```

4. **Inside Handler.handle()**
   - Push new scope
   - Declare `self` = Handler instance (in Handler's method scope)
   - Execute method body

5. **If Handler's method modifies self** (e.g., via compound assignment or field update)
   - Quest calls `scope.set("self", updated_handler)`
   - `set()` searches for existing `self` in scope chain
   - Finds `self` in OUTER scope (Logger's `self`)
   - **BUG**: Overwrites Logger's `self` with Handler!

6. **Return to Logger.handle()**
   - Try to access `self.handlers.len()`
   - But `self` now points to Handler (not Logger)
   - Error: "Struct Handler has no field 'handlers'"

## Why This Happens

The `set()` method was designed to allow inner scopes to modify outer scope variables (like in closures). However, `self` should NEVER be modified across scope boundaries - each method's `self` should be isolated to that method's scope only.

##Fix Options

### Option 1: Make `self` special in `set()`
```rust
pub fn set(&mut self, name: &str, value: QValue) {
    // Special handling for 'self' - only set in current scope
    if name == "self" {
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        return;
    }

    // Normal handling for other variables
    for scope in self.scopes.iter().rev() {
        if scope.borrow().contains_key(name) {
            scope.borrow_mut().insert(name.to_string(), value);
            return;
        }
    }
    self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
}
```

### Option 2: Change `set()` to only modify current scope
```rust
pub fn set(&mut self, name: &str, value: QValue) {
    // Only set in current (innermost) scope
    self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
}
```

This would require introducing a new `set_outer()` method for cases where we actually want to modify outer scopes.

### Option 3: Don't use `set()` for self updates
Change the code at line 899 in main.rs to use a different method that only updates the current scope's `self`.

## Recommended Fix

**Option 1** is the safest fix. `self` should always be scope-local and never leak across method boundaries. This preserves the current behavior for other variables while fixing the `self` corruption bug.

## Test Case

See `reproduce.q` for a minimal reproduction case that demonstrates the bug.

## Workaround

Until fixed, avoid accessing `self.field` repeatedly in loops where you call methods on objects from that field. Cache the field value:

```quest
# Instead of:
while i < self.handlers.len()
    self.handlers[i].method()
    i = i + 1
end

# Do this:
let handlers = self.handlers
while i < handlers.len()
    handlers[i].method()
    i = i + 1
end
```
