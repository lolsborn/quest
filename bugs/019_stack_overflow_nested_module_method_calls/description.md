# Bug #019: Stack Overflow When Calling User-Defined Functions

## Status
Open

## Severity
CRITICAL - Completely breaks user-defined function calls

## Summary
The interpreter encounters infinite recursion and stack overflow when ANY user-defined function calls another user-defined function. This is a catastrophic bug that breaks the most basic functionality of the language. Built-in methods work fine, but any function-to-function call causes immediate stack overflow.

## Description
The interpreter crashes with `thread 'main' has overflowed its stack` when executing ANY user-defined function that calls another user-defined function. Through systematic testing, we've determined:

**The bug occurs with:**
- User-defined function calling another user-defined function ✗
- Functions defined in modules calling other module functions ✗
- Functions passed as callbacks/parameters ✗
- Direct function calls ✗
- Lambda expressions ✗
- Named function references ✗

**What still works:**
- Built-in method calls (e.g., `"hello".len()`) ✓
- Functions that don't call other functions ✓
- Passing functions as parameters (without calling them) ✓

This is NOT a stack size issue - increasing the stack size from 8MB to 16MB does not resolve the problem. The issue is infinite recursion in the interpreter's function call evaluation logic.

## Reproduction Steps
1. Build the latest version: `cargo build --release`
2. Create a file with a function calling another function (see reproduction test suite below)
3. Run: `./target/release/quest.exe <file>`
4. Observe immediate stack overflow crash

## Minimal Reproduction Cases
A complete test suite demonstrating the bug is available in the bug directory. The simplest case:

```quest
# test_repro_7.q - Simplest possible case
fun helper()
    puts("Helper function")
end

fun main_fn()
    puts("Main function")
    helper()  # <-- CRASHES HERE
end

main_fn()
```

**Result:** Stack overflow when `helper()` is called from within `main_fn()`.

## Expected Behavior
```
Main function
Helper function
```

## Actual Behavior
```
Main function
thread 'main' has overflowed its stack
```

## Root Cause Analysis
The infinite recursion occurs when calling user-defined functions from within other user-defined functions. Since built-in methods work fine, the bug is specifically in the user function call evaluation path.

**Likely causes:**

1. **Function Call Evaluation Loop**: When `eval_pair()` evaluates a function call to a user function, it may be re-evaluating the function definition or context infinitely instead of just executing the body.

2. **Variable Scope Re-resolution**: The function name lookup may be triggering repeated scope resolution that creates a circular reference.

3. **Function Value Handling**: When a `QValue::UserFun` is called, the evaluator may be incorrectly handling the function value, causing it to re-evaluate instead of execute.

4. **Recent Regression**: This may be related to recent changes in function handling (decorators, default parameters, variadic arguments, or keyword arguments from QEP-003, QEP-033, QEP-034, QEP-035).

## Systematic Test Results

### Test 1: Custom module with nested calls
**File:** `test_repro_1.q`
**Pattern:** Module function calling another module function
**Result:** CRASHES ✗

### Test 2: Callback without module calls
**File:** `test_repro_2.q`
**Pattern:** Module function with callback that doesn't call other functions
**Result:** CRASHES ✗ (even without nested calls!)

### Test 3: Regular function with callback
**File:** `test_repro_3.q`
**Pattern:** Non-module function taking and calling a lambda
**Result:** CRASHES ✗

### Test 4: Passing callback without calling
**File:** `test_repro_4.q`
**Pattern:** Function receives callback but doesn't call it
**Result:** WORKS ✓

### Test 5: Named function as callback
**File:** `test_repro_5.q`
**Pattern:** Calling a named function reference passed as parameter
**Result:** CRASHES ✗

### Test 6: Direct function call
**File:** `test_repro_6.q`
**Pattern:** Function directly calling another function (not through parameter)
**Result:** CRASHES ✗

### Test 7: Basic function-to-function call
**File:** `test_repro_7.q` ← **SIMPLEST CASE**
**Pattern:** Most basic case - one function calling another
**Result:** CRASHES ✗

### Test 8: Built-in methods
**File:** `test_repro_8.q`
**Pattern:** Function calling built-in string methods
**Result:** WORKS ✓

## Key Findings
- **ANY user function calling another user function crashes**
- Built-in methods work perfectly
- Functions can be passed as parameters safely
- The crash happens WHEN the function is called, not when defined or passed
- This is NOT specific to modules, lambdas, or callbacks - it's ALL user function calls

## Impact
**CATASTROPHIC** - This bug completely breaks the Quest language:
- **ALL user-defined function calls broken**: Cannot write multi-function programs
- **Test suite completely broken**: Cannot run any test files
- **Standard library broken**: Many stdlib modules use function calls internally
- **All real programs broken**: Any non-trivial code will crash
- **Language is essentially unusable** until this is fixed

## Workarounds
None. This is a fundamental breakage of function calling.

## Next Steps
1. **Git bisect to find the regression**: Use `git bisect` to find which commit introduced this bug
2. **Review recent function-related changes**: Check commits related to QEP-003, QEP-033, QEP-034, QEP-035
3. **Add debug logging**: Add tracing to `eval_pair()` in the `QValue::UserFun` call path
4. **Check function resolution**: Examine how user function names are resolved and called
5. **Compare with built-in methods**: Understand why built-in methods work but user functions don't

## Environment
- OS: Windows 10 (MSYS_NT-10.0-26100)
- Rust version: 1.89.0
- Quest version: 0.1.1
- Build: cargo build --release

## Related Files
- `src/main.rs`: Main evaluator (`eval_pair`, `eval_expression`)
- `lib/std/test.q`: Test framework module
- All test files in `test/` directory
