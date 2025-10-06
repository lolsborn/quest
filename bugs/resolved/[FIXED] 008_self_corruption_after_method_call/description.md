# Bug 008: `self` Gets Corrupted After Method Call on Object from `self.field`

## Issue

When calling a method on an object that was retrieved from `self.field[i]`, Quest corrupts the `self` reference, causing it to point to the retrieved object instead of the original instance. Subsequent accesses to `self` incorrectly reference the wrong object.

## Current Behavior

```quest
pub type Logger
    array: handlers

    fun handle(record_data)
        let i = 0
        while i < self.handlers.len()  # self is Logger (correct)
            let handler = self.handlers[i]
            handler.handle(record_data)   # Call method on handler
            i = i + 1
        end  # Loop back to while condition
        # BUG: self.handlers.len() now tries to access .handlers on StreamHandler!
        # Error: "Struct StreamHandler has no field 'handlers'"
    end
end
```

After `handler.handle(record_data)` returns, when the while loop evaluates `self.handlers.len()` again, `self` has become the `handler` (a StreamHandler) instead of remaining the Logger instance.

## Expected Behavior

`self` should always refer to the current instance (Logger) throughout the entire method execution, even after calling methods on objects retrieved from `self`'s fields.

## Reproduction

```quest
use "std/log"

log.warning("Test message")  # This triggers the bug
```

The error occurs in `Logger.handle()` when the while loop tries to check the loop condition after the first iteration.

## Root Cause

Quest's implementation of `self` appears to be getting overwritten or corrupted when:
1. You retrieve an object from a field: `let handler = self.handlers[i]`
2. You call a method on that object: `handler.handle(record_data)`
3. You then try to access `self` again: `self.handlers.len()`

At step 3, `self` incorrectly points to `handler` instead of the original Logger instance.

## Workaround

Cache the field access before the loop:

```quest
fun handle(record_data)
    # Cache self.handlers to avoid repeated self access after method calls
    let handlers = self.handlers
    let i = 0
    while i < handlers.len()  # Use cached variable
        let handler = handlers[i]
        handler.handle(record_data)
        i = i + 1
    end
end
```

This avoids accessing `self.handlers` after the method call, preventing the corruption.

## Impact

- **Severity**: High - causes runtime errors in any code that accesses `self` fields in loops with method calls
- **Affected Code**: Any type method that:
  - Accesses `self.field` inside a loop
  - Calls methods on objects retrieved from `self.field`
  - Then accesses `self` again (e.g., in loop condition)

## Related Code

- Main implementation: `src/main.rs` - `self` handling in method calls and scope management
- Test case: `lib/std/log.q` - Logger.handle() method demonstrates the bug
- Discovered during: QEP-004 Logging Framework implementation

## Notes

This bug was discovered after recent refactoring of `self` handling in Quest. The corruption happens specifically when a method is called on an object that came from a `self.field` access.

The error message "Struct StreamHandler has no field 'handlers'" is misleading - it's actually trying to access `self.handlers` where `self` has been corrupted to point to a StreamHandler instead of the Logger.

## Status

**FIXED** - 2025-10-04

## Fix

The bug was caused by the postfix handler automatically updating variables after method calls (lines 1961-1975 in main.rs). When evaluating expressions like `self.field.method()`, the code would:

1. Track the starting identifier (`self`)
2. Evaluate the postfix chain
3. After completion, automatically update the variable with the result

This was intended to support mutating methods on structs, but incorrectly updated `self` with the method's target object or return value.

**Solution**: Added a check to prevent automatic updates of `self` (line 1964):
```rust
if var_name != "self" {  // Don't auto-update self!
```

The `self` variable should only be modified explicitly within method bodies, never automatically by the postfix expression handler.
