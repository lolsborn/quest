# Return Statement Not Exiting Function

## Issue
The `return` statement does not immediately exit a function when used inside an `if` block. The function continues executing subsequent statements after the `return`, leading to incorrect behavior.

## Current Behavior
When a function has multiple `if` blocks (not `elif`), a `return` statement inside one `if` block does not prevent subsequent `if` blocks from executing. The function continues running and may execute multiple branches.

## Expected Behavior
A `return` statement should immediately exit the function and return the specified value, preventing any further code in the function from executing.

## Example Code
```quest
fun test_return(x)
    if x.eq(1)
        return "first"
    end
    if x.eq(1)
        return "second"
    end
    return "third"
end

# Expected: "first"
# Actual: "third" (or "second")
```

## Root Cause
The evaluator is not properly handling `return` statements inside conditional blocks. When a `return` is encountered, it should propagate up through the call stack immediately, but instead execution continues in the parent scope.

## Impact
- **Severity**: High
- **User Impact**: Functions with early returns don't work as expected, leading to incorrect logic. Common patterns like guard clauses and early exit conditions are broken.
- **Workaround**: Use `elif` chains instead of separate `if` statements, or use a variable to store the result and return it at the end.

## Related Code
- `src/main.rs` - Main evaluator logic
- Likely in the `eval_pair` function where `Rule::if_statement` is handled
- Return statement handling in statement evaluation

## Fix
Implemented control flow mechanism for function returns:
1. Added `return_value` field to `Scope` struct to store return values
2. Modified return statement handler to store value in scope and signal `__FUNCTION_RETURN__`
3. Updated `call_user_function` to catch `__FUNCTION_RETURN__` and retrieve stored value
4. Existing control flow structures (if/while/for) already propagate errors correctly

## Status
**Fixed** - 2025-10-04
