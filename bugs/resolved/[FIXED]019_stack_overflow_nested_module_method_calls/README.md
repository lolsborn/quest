# Bug #019 Test Suite

This directory contains a comprehensive test suite that systematically narrows down Bug #019.

## Quick Start

Run the simplest case:
```bash
./target/release/quest.exe bugs/019_stack_overflow_nested_module_method_calls/example.q
```

Expected: Stack overflow crash

## Test Files

### example.q
**The simplest possible reproduction** - One function calling another function. START HERE.

### test_repro_1.q
Custom module with nested method calls (the original hypothesis)

### test_repro_2.q
Module function with callback that doesn't call other functions
**Key finding:** Crashes even without nested calls!

### test_repro_3.q
Regular (non-module) function taking and calling a lambda
**Key finding:** Not specific to modules!

### test_repro_4.q
Function receives callback but doesn't call it
**Key finding:** This WORKS - proves the crash happens when calling, not passing

### test_repro_5.q
Named function reference as callback
**Key finding:** Named functions crash too, not just lambdas

### test_repro_6.q
Function directly calling another function (not through parameter)
**Key finding:** Direct calls also crash

### test_repro_7.q
Most basic case - one function calling another (same as example.q)
**Key finding:** The absolute simplest case that triggers the bug

### test_repro_8.q
Function calling built-in string methods
**Key finding:** This WORKS - built-in methods are fine

### test_module.q
Simple custom module used by test_repro_1.q and test_repro_2.q

## Key Findings

1. **ANY user function calling another user function crashes**
2. Built-in methods work perfectly
3. Functions can be passed as parameters safely
4. The crash happens WHEN calling, not when defining or passing
5. This is NOT specific to:
   - Modules
   - Lambdas
   - Callbacks
   - Nested calls

   It's ALL user function calls.

## Impact

This is a **CATASTROPHIC** bug that makes Quest completely unusable. No multi-function programs can run.
