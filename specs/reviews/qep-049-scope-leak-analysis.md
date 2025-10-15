# QEP-049: Scope Leak Analysis

**Date:** 2025-10-15
**Severity:** Medium (potential memory leak in long-running REPL sessions)
**Status:** Under investigation

---

## Problem Overview

The iterative evaluator uses Quest's `Scope` system which maintains a stack of variable bindings. Control flow constructs (if/while/for/try) create new scopes via `scope.push()` and must clean them up with `scope.pop()`. If an error occurs between `push()` and `pop()`, the scope remains on the stack, causing a **scope leak**.

### What is a Scope Leak?

Each leaked scope consumes memory for:
- Variable bindings in that scope
- Parent scope references
- Metadata (scope ID, etc.)

In a long-running REPL session, repeated scope leaks can accumulate, leading to:
- Memory growth (unbounded if leaks are frequent)
- Performance degradation (scope lookups traverse more layers)
- Potential out-of-memory in extreme cases

---

## Scope Push/Pop Locations

**Total scope operations in `src/eval.rs`:**
- `scope.push()`: 7 locations
- `scope.pop()`: 20 locations (including exception handlers)

### Critical Locations

| Location | Context | Push Line | Pop Line(s) |
|----------|---------|-----------|-------------|
| 1 | Module function call | 1018 | (implicit via module_scope) |
| 2 | If statement body | 2002 | 2028, 2038, 2041, 2066, 2069 |
| 3 | Elif clause body | 2084 | 2100, 2108, 2111 |
| 4 | Else clause body | 2141 | 2157, 2165, 2168 |
| 5 | While loop body | 2233 | 2243, 2292, 2299, 2319 |
| 6 | For loop body | 2464 | 2470, 2504, 2511, 2527 |
| 7 | Try statement body | 2611 | 2616, 2657, 3422 (exception handler) |

---

## Vulnerability Analysis

### ✅ SAFE: Try/Catch Exception Handling (Lines 2611-3422)

**Code:**
```rust
// Line 2611
scope.push(); // New scope for try block

// ... try body evaluation ...

// Line 2657 - Normal success path
scope.pop(); // Close try block scope

// Line 3422 - Exception handler
if matches!(try_frame.state, EvalState::TryEvalBodyStmt(_)) {
    scope.pop(); // Close try scope - SAFE!
    // ... handle exception ...
}
```

**Analysis:** ✅ **Protected**
- Normal path: `scope.pop()` at line 2657
- Exception path: `handle_exception_in_try()` calls `scope.pop()` at line 3422
- All error paths route through exception handler

---

### ⚠️ VULNERABLE: If Statement Body (Lines 2002-2072)

**Code:**
```rust
// Line 2002
scope.push(); // New scope for if block

// Lines 2016-2031 - Body evaluation loop
for stmt in if_body {
    match crate::eval_pair_impl(stmt, scope) {
        Ok(v) => result = v,
        Err(e) if e == "__LOOP_BREAK__" => {
            should_break_loop = true;
            break;
        }
        Err(e) if e == "__LOOP_CONTINUE__" => {
            should_continue_loop = true;
            break;
        }
        Err(e) => {
            scope.pop();  // Line 2028 - CLEANUP PRESENT
            return Err(e);
        }
    }
}
```

**Analysis:** ✅ **Protected**
- Error path explicitly pops scope at line 2028
- Loop control paths (break/continue) pop scope at lines 2038/2041
- Normal completion pops scope at lines 2066/2069

**However:** Relies on `crate::eval_pair_impl()` (recursive evaluator) properly propagating errors. If the recursive evaluator has hidden error paths (early returns, panics), scope could leak.

---

### ⚠️ VULNERABLE: While Loop Body (Lines 2233-2329)

**Code:**
```rust
// Line 2233
scope.push(); // New scope for loop iteration

// Lines 2241-2243 - Empty body case
if body_stmts.is_empty() {
    scope.pop();  // SAFE
    // ... continue loop ...
}

// Lines 2291-2294 - Break case
if loop_state.should_break {
    scope.pop();  // SAFE
    push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
    continue 'eval_loop;
}

// Lines 2297-2312 - Continue case
if loop_state.should_continue {
    scope.pop();  // SAFE
    // ... continue loop ...
}

// Lines 2317-2319 - Loop completion
if stmt_idx >= loop_state.body_pairs.len() {
    scope.pop();  // SAFE
    // ... continue loop ...
}
```

**Analysis:** ⚠️ **POTENTIAL LEAK**

**Vulnerable Path Identified:**
```rust
// Line 2293
scope.pop();
push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
//                                                                       ^^^
//                                                      Early return here if error!
```

**Scenario:** If `push_result_to_parent()` returns an error:
1. `scope.push()` executed at line 2233
2. `scope.pop()` executed at line 2292
3. `push_result_to_parent()` fails and returns `Err(...)`
4. Control returns to caller **without additional cleanup**
5. **However:** The scope was already popped, so this is actually SAFE!

**Verdict:** ✅ **Actually Protected** - Pop happens before fallible operation

---

### 🔴 VULNERABLE: Nested Early Returns (Lines 2333-2345)

**Code:**
```rust
// Line 2333 (inside WhileEvalBody handler)
let next_stmt = loop_state.body_pairs[stmt_idx].clone();

stack.push(EvalFrame {
    pair: frame.pair.clone(),
    state: EvalState::WhileEvalBody(stmt_idx + 1),
    partial_results: Vec::new(),
    context: Some(context),
});

stack.push(EvalFrame::new(next_stmt));
```

**Analysis:** 🔴 **LEAK POSSIBLE**

**Scenario:**
1. While loop iteration starts → `scope.push()` at line 2233
2. Statement evaluation begins → `EvalFrame::new(next_stmt)` pushed
3. If `next_stmt` evaluation triggers an unhandled error (not in try block):
   - Error propagates up through `'eval_loop`
   - Default fallback at line ~3250 catches it
   - **Scope remains pushed!**

**Example Vulnerable Code:**
```quest
let i = 0
while i < 10
    # New scope pushed here
    let x = 1
    if x == 1
        undefined_function()  # Error here!
    end
    i = i + 1
end
```

**Trace:**
1. Line 2233: `scope.push()` for iteration 0
2. Statement `undefined_function()` evaluated
3. Error: `NameErr: Undefined variable: undefined_function`
4. Error propagates through fallback at line ~3250
5. Returns `Err(...)` to caller
6. **Scope never popped!**

---

### 🔴 VULNERABLE: For Loop Body (Lines 2464-2527)

**Similar pattern to while loops:**

```rust
// Line 2464
scope.push();

// Lines 2470-2527 - Multiple pop locations
if loop_state.should_break {
    scope.pop();  // Line 2470
}
if loop_state.should_continue {
    scope.pop();  // Line 2504
}
if elem_idx >= collection.len() {
    scope.pop();  // Line 2511
}
if stmt_idx >= loop_state.body_pairs.len() {
    scope.pop();  // Line 2527
}
```

**Analysis:** 🔴 **LEAK POSSIBLE**

**Same vulnerability:** Statement evaluation between lines 2480-2550 can trigger unhandled errors that bypass scope cleanup.

---

## Root Cause Analysis

### The Fundamental Issue

The iterative evaluator uses **manual scope management** with explicit `push()`/`pop()` calls. This is error-prone because:

1. **Multiple exit paths** - Normal completion, break, continue, return, exceptions
2. **Nested evaluations** - Recursive fallbacks to `eval_pair_impl()` can error
3. **Indirect errors** - Errors from helper functions (`push_result_to_parent()`, etc.)
4. **No automatic cleanup** - Rust's ownership doesn't track scope stack depth

### Why Try/Catch is Protected

The try/catch handler (lines 3419-3442) explicitly checks for `TryEvalBodyStmt` state and pops scope:

```rust
if matches!(try_frame.state, EvalState::TryEvalBodyStmt(_)) {
    scope.pop(); // Close try scope
    // ... handle exception ...
}
```

**But:** This only works for try blocks. Other constructs lack similar protection.

---

## Impact Assessment

### Severity: Medium

**In typical usage:**
- Most errors occur during parsing or immediate evaluation
- Scope leaks only accumulate if errors occur repeatedly inside loops
- Single error → single leaked scope (few bytes)

**In adversarial usage:**
```quest
# Deliberately trigger 10,000 scope leaks
let i = 0
while i < 10000
    try
        let x = 1
        undefined_var  # Error on every iteration
    catch e
        # Swallow error, continue leaking
    end
    i = i + 1
end
```

**Result:** 10,000 leaked scopes × ~100 bytes each = ~1 MB leaked

**In long-running REPL:** Could accumulate over hours/days if user frequently writes buggy loop code.

---

## Proposed Fixes

### Option 1: RAII Scope Guard (Recommended)

**Implement automatic scope cleanup:**

```rust
/// RAII guard for automatic scope cleanup
pub struct ScopeGuard<'a> {
    scope: &'a mut Scope,
    active: bool,
}

impl<'a> ScopeGuard<'a> {
    pub fn new(scope: &'a mut Scope) -> Self {
        scope.push();
        Self { scope, active: true }
    }

    pub fn dismiss(mut self) {
        self.active = false;
    }
}

impl Drop for ScopeGuard<'_> {
    fn drop(&mut self) {
        if self.active {
            self.scope.pop();
        }
    }
}
```

**Usage:**
```rust
// Line 2233 - While loop
{
    let _guard = ScopeGuard::new(scope);

    // ... loop body evaluation ...

    // Scope automatically popped when _guard drops (even on error!)
}
```

**Pros:**
- Automatic cleanup on all exit paths (including panics!)
- Impossible to forget cleanup
- Rust idiom (similar to `MutexGuard`, `Drop`)

**Cons:**
- Requires refactoring all scope.push/pop sites
- Need to handle explicit `dismiss()` for normal completion paths
- Borrow checker complexity (scope borrowed for entire block)

---

### Option 2: Centralized Exception Handler

**Extend `handle_exception_in_try()` to handle all control flow:**

```rust
fn handle_exception_and_cleanup<'i>(
    stack: &mut Vec<EvalFrame<'i>>,
    scope: &mut Scope,
    error: String,
) -> Result<bool, String> {
    // Find the innermost frame with a pushed scope
    for frame in stack.iter().rev() {
        match frame.state {
            EvalState::WhileEvalBody(_) |
            EvalState::ForEvalBody(_, _) |
            EvalState::IfEvalBranch(_) |
            EvalState::TryEvalBodyStmt(_) => {
                scope.pop(); // Clean up scope
                break;
            }
            _ => {}
        }
    }

    // Then handle exception as normal
    handle_exception_in_try(stack, scope, error)
}
```

**Pros:**
- Centralized cleanup logic
- Minimal refactoring needed
- Works with existing code structure

**Cons:**
- Fragile (must remember to add new states)
- Doesn't handle all error paths (only exception propagation)
- Could pop wrong scope if state tracking is incorrect

---

### Option 3: Explicit Cleanup in Fallback Handler

**Add cleanup to default fallback at line ~3250:**

```rust
// Line 3247 in eval.rs
_ => {
    // Unimplemented in iterative evaluator - fall back to recursive
    match crate::eval_pair_impl(frame.pair.clone(), scope) {
        Ok(result) => {
            push_result_to_parent(&mut stack, result, &mut final_result)?;
        }
        Err(e) => {
            // NEW: Check if we're in a scope-creating state
            let should_pop_scope = matches!(
                stack.last().map(|f| &f.state),
                Some(EvalState::WhileEvalBody(_)) |
                Some(EvalState::ForEvalBody(_, _)) |
                Some(EvalState::IfEvalBranch(_))
            );

            if should_pop_scope {
                scope.pop(); // Clean up leaked scope
            }

            return Err(e);
        }
    }
}
```

**Pros:**
- Surgical fix at error propagation point
- Low risk (only affects error paths)

**Cons:**
- Incomplete (doesn't catch all leak scenarios)
- Still relies on manual tracking

---

## Recommended Solution

**Hybrid approach:**

1. **Short-term (quick fix):** Implement Option 3 (explicit cleanup in fallback)
   - Low risk, easy to test
   - Fixes most common leak scenarios
   - **Effort:** 30 minutes

2. **Medium-term (proper fix):** Implement Option 1 (RAII ScopeGuard)
   - Refactor loop/if/try scope management
   - Add comprehensive tests
   - **Effort:** 4-6 hours

3. **Long-term (best practice):** Audit all error paths
   - Use static analysis to verify scope balance
   - Add runtime assertions in debug builds
   - **Effort:** Ongoing

---

## Test Cases

### Test 1: Error in While Loop Body
```quest
use "std/test"

test.describe("Scope Leak Prevention", fun ()
    test.it("no scope leak on error in while loop", fun ()
        let initial_depth = get_scope_depth()  # Helper function needed

        try
            let i = 0
            while i < 5
                let x = 1
                undefined_variable  # Trigger error
                i = i + 1
            end
        catch e
            # Error caught
        end

        let final_depth = get_scope_depth()
        test.assert_eq(final_depth, initial_depth, "Scope depth should be restored")
    end)
end)
```

### Test 2: Nested Loop Error
```quest
test.it("no scope leak on nested loop error", fun ()
    let initial_depth = get_scope_depth()

    try
        let i = 0
        while i < 3
            let j = 0
            while j < 3
                if i == 1 and j == 1
                    undefined_function()  # Error in nested loop
                end
                j = j + 1
            end
            i = i + 1
        end
    catch e
        # Swallow error
    end

    let final_depth = get_scope_depth()
    test.assert_eq(final_depth, initial_depth)
end)
```

### Test 3: Error in For Loop
```quest
test.it("no scope leak on error in for loop", fun ()
    let initial_depth = get_scope_depth()

    try
        for item in [1, 2, 3, 4, 5]
            let x = item * 2
            if x == 6
                raise "intentional error"
            end
        end
    catch e
        # Swallow
    end

    let final_depth = get_scope_depth()
    test.assert_eq(final_depth, initial_depth)
end)
```

---

## Action Items

### High Priority
- [ ] Implement scope depth introspection (`sys.get_scope_depth()` or similar)
- [ ] Add test cases for loop error scenarios
- [ ] Implement Option 3 (explicit cleanup in fallback handler)
- [ ] Validate tests pass with fix

### Medium Priority
- [ ] Design RAII ScopeGuard API
- [ ] Refactor loop bodies to use ScopeGuard
- [ ] Add fuzzing tests (random errors in random loop positions)

### Low Priority
- [ ] Static analysis to detect scope imbalance
- [ ] Runtime assertions in debug builds
- [ ] Audit recursive evaluator for similar issues

---

## Conclusion

The scope leak vulnerability is **real but low severity** in typical usage. Most concerning for:
- Long-running REPL sessions
- Code that repeatedly triggers errors in loops
- Adversarial/fuzzing scenarios

**Recommended immediate action:** Implement explicit cleanup in fallback handler (30 min fix, high safety improvement).

**Follow-up:** Migrate to RAII-based scope management for long-term correctness.

---

**Analysis by:** Claude Code
**Date:** 2025-10-15
**Status:** Awaiting implementation
