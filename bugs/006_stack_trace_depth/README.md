# Bug 006: Stack Trace Depth Insufficient

## Summary
Exception stack traces are empty or have insufficient depth when exceptions are raised from nested function calls.

## Reproduction
```bash
./target/release/quest bugs/006_stack_trace_depth/_reproduce.q
```

**Expected output**: Stack trace with at least 3 frames (inner, middle, outer)
**Actual output**: Stack trace array has 0 frames

## Failing Tests
Run the test suite to see failures:
```bash
./target/release/quest test/exceptions/stack_trace_test.q
```

3 tests fail:
- "captures function call stack"
- "shows nested function calls"
- "clears stack after exception is caught"

## Test Results
```
Total:   624 tests
Passed:  621 tests (99.5%)
Failed:  3 tests (0.5%)
```

All 3 failures are stack trace related.

## Files
- `description.md` - Detailed bug description and analysis
- `_reproduce.q` - Minimal reproduction case

## Status
- **Priority**: Medium
- **Discovered**: 2025-10-03
- **Status**: Open
- **Impact**: Debugging nested function errors is harder without stack traces
