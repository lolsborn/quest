# Bug #019: Stack Overflow with Nested Module Method Calls

## Status
Open

## Severity
Critical - Blocks all test execution

## Summary
The interpreter encounters a stack overflow when executing nested module method calls, specifically when a function passed to a module method (e.g., `test.describe()`) contains calls to other methods on the same module (e.g., `test.it()`). This makes the test framework unusable and affects any similar pattern of nested module method calls.

## Description
When running test files that use the `std/test` module, the interpreter crashes with `thread 'main' has overflowed its stack`. The crash occurs specifically when:

1. Calling a method on a module (e.g., `test.describe(name, fun)`)
2. The function argument contains calls to other methods on the same module (e.g., `test.it()` inside the describe function)
3. This pattern causes infinite recursion in the evaluator

This is NOT a stack size issue - increasing the stack size from 8MB to 16MB does not resolve the problem. The issue is infinite recursion in the interpreter's evaluation logic.

## Reproduction Steps
1. Build the latest version: `cargo build --release`
2. Run any test file: `./target/release/quest.exe test/bool/bool_test.q`
3. Observe stack overflow crash

## Minimal Reproduction Case
See `example.q` - a minimal test case that triggers the bug.

## Expected Behavior
The test should execute without stack overflow:
```
Test Group
  ✓ first test

Tests: 1 passed, 1 total
```

## Actual Behavior
```
thread 'main' has overflowed its stack
```

## Root Cause Analysis
The infinite recursion likely occurs in one of these areas:

1. **Method Resolution on Modules**: When resolving `test.it()` inside a function that was passed to `test.describe()`, the evaluator may be re-evaluating the module or function context incorrectly.

2. **Closure Capture**: The lambda passed to `describe()` may be incorrectly capturing or resolving the module reference, causing circular evaluation.

3. **Variable Scope Resolution**: The nested function calls may be triggering infinite recursion in variable lookup or scope resolution.

## Investigation Notes

### What Works
- Loading modules: `use "std/test" as test` ✓
- Simple module method calls: `test.module("Name")` ✓
- Basic function execution ✓
- Individual module imports (std/term, std/math, std/time, std/sys, std/io) ✓

### What Fails
- Nested module method calls in function arguments ✗
- `test.describe()` containing `test.it()` ✗
- Any similar pattern of nested module method invocations ✗

## Impact
- **Test suite completely broken**: Cannot run any test files
- **Blocks development**: No way to verify functionality
- **Affects any module with nested method calls**: Not limited to test framework

## Workarounds
None identified. The pattern is fundamental to how the test framework operates.

## Next Steps
1. Add debug logging to `eval_pair()` to trace the recursion
2. Examine how module method calls are resolved in nested contexts
3. Check closure/lambda evaluation for circular references
4. Review variable scope resolution in nested function calls
5. Consider adding recursion depth limiting as a safety measure

## Environment
- OS: Windows 10 (MSYS_NT-10.0-26100)
- Rust version: 1.89.0
- Quest version: 0.1.1
- Build: cargo build --release

## Related Files
- `src/main.rs`: Main evaluator (`eval_pair`, `eval_expression`)
- `lib/std/test.q`: Test framework module
- All test files in `test/` directory
