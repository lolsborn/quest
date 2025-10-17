# Bug #021: If Statement Errors Bypass Try/Catch

**Status:** Open
**Severity:** High
**Priority:** P1
**Discovered:** 2025-10-17 (While fixing Bug #020)
**Component:** Evaluator / Exception Handling
**Related:** QEP-049 (Iterative Evaluator), Bug #020 (Scope Leak)

---

## Summary

Errors that occur inside `if` statement bodies are not caught by surrounding try/catch blocks when the `if` is inside a loop. The error escapes the try/catch and propagates to the top level, causing the program to exit with an error.

This breaks the expected exception handling behavior and makes it impossible to handle errors in conditional code inside loops.

---

## Impact

**Severity: High** because:
- Breaks fundamental exception handling semantics
- Affects common code patterns (if inside loop inside try)
- No clear workaround for users (except avoiding `if` statements)
- Causes unexpected program termination

**Not P0 because:**
- Workaround exists (use `match` instead of `if`)
- Doesn't affect errors outside of `if` statements
- Only affects errors in specific nesting: if → loop → try

---

## Current Behavior

Errors in `if` statement bodies escape try/catch blocks:

```quest
try
    let i = 0
    while i < 3
        if i == 1
            raise "error"  # This error is NOT caught!
        end
        i = i + 1
    end
catch e
    puts("Caught: " .. e.message())  # Never executes
end

# Output:
# RuntimeErr: error
# (Program exits with error code 1)
```

---

## Expected Behavior

Errors should be caught by the surrounding try/catch block:

```quest
try
    let i = 0
    while i < 3
        if i == 1
            raise "error"
        end
        i = i + 1
    end
catch e
    puts("Caught: " .. e.message())  # Should execute
end

# Expected output:
# Caught: error
# (Program continues normally)
```

---

## Root Cause

The issue is in the `if` statement handler in the iterative evaluator ([src/eval.rs:2008-2014](../../src/eval.rs#L2008-L2014)):

```rust
// Execute body statements
let (result, should_break, should_continue) = match execute_block_with_control(if_body.into_iter(), scope) {
    Ok(res) => res,
    Err(e) => {
        scope.pop();
        return Err(e.into());  // ← BUG: Returns immediately, bypassing error handling
    }
};
```

When an error occurs in the `if` body:
1. `execute_block_with_control()` returns `Err(...)`
2. The error handler does `return Err(e.into())` at line 2012
3. This **returns from `eval_pair_iterative()` entirely**
4. The error bypasses the fallback error handler (line 3165)
5. The try/catch handler never sees the error
6. The error propagates to the top level and terminates the program

### Why This Happens

The `if` statement handler uses `execute_block_with_control()`, which is a **synchronous helper function** that evaluates all statements in a block and returns a result. When an error occurs, the `if` handler immediately returns with `return Err(...)`, which exits the `eval_pair_iterative()` function entirely.

This bypasses the **fallback error handler** (lines 3095-3236) that would normally:
1. Check if we're inside a try block
2. Clean up scopes
3. Transition the try frame to error handling state
4. Continue evaluation to execute the catch block

### Comparison with Working Cases

**Working: Direct raise in loop body**
```quest
try
    while true
        raise "error"  # ✅ Caught correctly
    end
catch e
    puts("Caught")  # Executes
end
```

This works because `raise` is evaluated via the fallback handler (line 3098), which catches the error and looks for a try frame.

**Broken: Raise inside if inside loop**
```quest
try
    while true
        if true
            raise "error"  # ❌ NOT caught
        end
    end
catch e
    puts("Caught")  # Never executes
end
```

This fails because the `if` handler returns the error immediately without going through the fallback handler.

---

## Affected Code Patterns

### 1. If statement in loop in try block
```quest
try
    for i in [1, 2, 3]
        if i == 2
            raise "error"  # NOT caught
        end
    end
catch e
    # Never executes
end
```

### 2. Nested if statements
```quest
try
    let x = 5
    if x > 0
        if x == 5
            raise "error"  # NOT caught
        end
    end
catch e
    # Never executes
end
```

### 3. If with else clause
```quest
try
    let x = 10
    if x < 5
        puts("small")
    else
        raise "error"  # NOT caught
    end
catch e
    # Never executes
end
```

---

## Workaround

Use `match` statements instead of `if` statements:

```quest
# Instead of:
if i == 2
    raise "error"
end

# Use:
match i
in 2
    raise "error"  # ✅ This WILL be caught
else
    # continue
end
```

**Why this works:** The `match` statement is not yet fully implemented in the iterative evaluator, so it falls back to the recursive evaluator via the fallback handler (line 3098). The fallback handler properly checks for try frames and handles exceptions.

---

## Other Affected Control Structures

The same issue likely affects other control structures that use `execute_block_with_control()` or `return Err(...)`:

### Confirmed Affected
- `if` statements (line 2012)
- `elif` clauses (line 2043)
- `else` clauses (line 2068)

### Possibly Affected (need verification)
- Any other control structure that uses `execute_block_with_control()`
- Any code path that uses `return Err(...)` instead of going through the fallback

---

## Proposed Solution

Convert `if` statement evaluation to use the **iterative evaluator's state machine** instead of the synchronous `execute_block_with_control()` helper.

### Approach 1: State Machine (Preferred)

Refactor `if` statement handling to use the state machine pattern used by `while` and `for` loops:

1. Add new states to `EvalState`:
   ```rust
   IfEvalBodyStmt(usize),    // Evaluating if body statement at index
   ElifEvalCondition(usize),  // Evaluating elif condition at index
   ElifEvalBodyStmt(usize, usize),  // Evaluating elif body
   ElseEvalBodyStmt(usize),   // Evaluating else body
   ```

2. Evaluate if/elif/else bodies **statement by statement** using the state machine

3. When an error occurs, it goes through the fallback handler which can:
   - Check for try frames
   - Clean up scopes
   - Handle exceptions properly

**Advantages:**
- ✅ Errors handled correctly through normal flow
- ✅ Consistent with while/for loop implementation
- ✅ Supports all error handling mechanisms

**Disadvantages:**
- ⚠️ Significant refactoring required (~200 lines)
- ⚠️ More complex state management

### Approach 2: Exception Propagation (Quick Fix)

Instead of `return Err(...)`, use the `handle_exception_in_try()` helper:

```rust
Err(e) => {
    scope.pop();

    // Check if we're in a try block and handle exception
    if handle_exception_in_try(&mut stack, scope, e.clone())? {
        continue 'eval_loop;  // Exception handled, continue
    }

    // Not in try block, propagate error
    return Err(e.into());
}
```

**Advantages:**
- ✅ Minimal code changes (~10 lines per location)
- ✅ Quick fix for the immediate issue
- ✅ Reuses existing exception handling infrastructure

**Disadvantages:**
- ⚠️ Still uses synchronous execution
- ⚠️ Doesn't fully integrate with state machine
- ⚠️ May have subtle edge cases

### Recommendation

**Short term:** Implement Approach 2 (Exception Propagation) as a quick fix to unblock users.

**Long term:** Implement Approach 1 (State Machine) as part of completing the iterative evaluator (QEP-049).

---

## Test Cases Required

### 1. Simple if in try block
```quest
try
    if true
        raise "error"
    end
catch e
    assert(e.message() == "error")
end
```

### 2. If in while loop in try block
```quest
try
    let i = 0
    while i < 3
        if i == 1
            raise "error"
        end
        i = i + 1
    end
catch e
    assert(e.message() == "error")
end
```

### 3. If in for loop in try block
```quest
try
    for i in [1, 2, 3]
        if i == 2
            raise "error"
        end
    end
catch e
    assert(e.message() == "error")
end
```

### 4. Nested if statements
```quest
try
    if true
        if true
            raise "error"
        end
    end
catch e
    assert(e.message() == "error")
end
```

### 5. If with elif
```quest
try
    let x = 5
    if x < 5
        puts("small")
    elif x == 5
        raise "error"
    end
catch e
    assert(e.message() == "error")
end
```

### 6. If with else
```quest
try
    let x = 10
    if x < 5
        puts("small")
    else
        raise "error"
    end
catch e
    assert(e.message() == "error")
end
```

### 7. Multiple error scenarios
```quest
let caught = 0
try
    for i in [1, 2, 3, 4, 5]
        if i == 2 or i == 4
            raise "error"
        end
    end
catch e
    caught = caught + 1
end
# Should have caught the first error at i=2
assert(caught == 1)
```

---

## Files to Modify

### For Quick Fix (Approach 2)
1. **`src/eval.rs`**
   - Line 2012: Replace `return Err(e.into())` with exception handler check
   - Line 2043: Same for elif
   - Line 2068: Same for else

### For Full Fix (Approach 1)
1. **`src/eval.rs`**
   - Lines 1969-2089: Complete refactor of if statement handling
   - Add new `EvalState` variants
   - Implement state machine transitions
   - Remove `execute_block_with_control()` usage

---

## Related Issues

- **Bug #020:** Scope Leak in Iterative Evaluator (fixed, led to discovery of this bug)
- **QEP-049:** Iterative Evaluator (parent specification)
- **Improvement:** Complete iterative evaluator implementation to eliminate fallback cases

---

## Acceptance Criteria

- [ ] All test cases above pass
- [ ] Errors in `if` bodies are caught by try/catch blocks
- [ ] Errors in `elif` bodies are caught by try/catch blocks
- [ ] Errors in `else` bodies are caught by try/catch blocks
- [ ] Nested `if` statements work correctly
- [ ] All 2655 existing tests still pass
- [ ] No regressions in error handling behavior

---

## Additional Notes

**Discovery Context:**
This bug was discovered while fixing Bug #020 (Scope Leak). During testing of the scope leak fix, I noticed that errors in `if` statements inside loops were not being caught by try/catch blocks, while direct errors (without `if`) were caught correctly.

**User Impact:**
Users writing defensive code with try/catch blocks around loops may be surprised when errors in conditional branches escape the try/catch. This could lead to unexpected program termination in production.

**Priority Justification (P1):**
- Breaks fundamental exception handling semantics
- Affects common code patterns
- High user surprise factor
- Clear fix available (either quick or full)
- Should be fixed before 1.0 release

---

**Reported by:** Claude Code (AI Assistant)
**Date:** 2025-10-17
**Related to:** Bug #020 fix
