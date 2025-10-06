# Stack Trace Depth Insufficient for Nested Function Calls

## Issue
Exception stack traces don't capture enough frames when exceptions are raised from deeply nested function calls.

## Current Behavior
When an exception is raised from nested functions (e.g., `outer() -> middle() -> inner()`), the stack trace array has fewer than 3 frames, making it difficult to debug nested call chains.

## Failing Tests
All failures in `test/exceptions/stack_trace_test.q`:
1. **Line 35**: "captures function call stack" - expects `>= 3` stack frames
2. **Line 55**: "shows nested function calls" - expects `>= 3` levels
3. **Line 76**: "clears stack after exception is caught" - second exception missing stack

## Test Output
```
Exception Tests - Stack Traces
  ✓ exception has stack array
  ✗ Assertion failed: Should have at least 3 stack frames
  ✓ captures function call stack
  ✗ Assertion failed: Should have at least 3 levels
  ✓ shows nested function calls
  ✗ Assertion failed: Second exception should also have stack
  ✓ clears stack after exception is caught
```

## Example Code
```quest
fun inner()
    raise "error from inner"
end

fun middle()
    inner()
end

fun outer()
    middle()
end

try
    outer()
catch e
    let stack = e.stack()
    puts(stack.len())  # Expected: >= 3, Actual: < 3
end
```

## Expected Behavior
Exception stack traces should include:
- The function where the exception was raised
- All intermediate function calls in the call chain
- The function where the try/catch is located

For the example above, stack should contain at least:
1. `inner` (where raise occurred)
2. `middle` (caller of inner)
3. `outer` (caller of middle)

## Root Cause
The stack frame tracking in `src/scope.rs` or exception creation may not be properly capturing all frames in the call stack when exceptions are raised.

## Impact
- **Severity**: Medium
- **Tests Affected**: 3 out of 624 (0.5%)
- **User Impact**: Debugging nested function errors is harder without complete stack traces

## Related Code
- Exception implementation: `src/types/exception.rs`
- Stack frame tracking: `src/scope.rs`
- Exception creation: Where `QException` is constructed with stack traces
- Test file: `test/exceptions/stack_trace_test.q`

## Workaround
None - stack traces are automatically generated. Users can add logging to track call flow manually.

## Status
**Open** - Discovered during test suite run on 2025-10-03
