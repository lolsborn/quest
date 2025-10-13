# QEP-049: Iterative Evaluator with Explicit Stack

**Status:** In Progress
**Created:** 2025-10-11
**Related:** Bug #019 (Stack overflow in nested module method calls), QEP-048 (Stack depth tracking)

## Problem

Quest's recursive evaluator (`eval_pair`) uses Rust's call stack, which has fixed size limits (~8MB on most systems). This causes stack overflow in legitimate programs with:

1. Deep method chains: `obj.a().b().c()...` (Bug #019)
2. Deeply nested loops with complex bodies
3. Recursive functions (>1000 calls)
4. Complex expression nesting

Current mitigation (QEP-048) tracks depth limits (2000 eval, 1000 function calls) but still uses Rust stack, limiting practical recursion depth.

## Solution

Replace recursive `eval_pair` with iterative evaluation using explicit heap-allocated stack.

### Architecture

```rust
// Explicit evaluation stack frame
struct EvalFrame {
    pair: Pair<Rule>,              // AST node to evaluate
    state: EvalState,              // Current evaluation state
    partial_results: Vec<QValue>,  // Intermediate results
    context: Option<EvalContext>,  // Additional state (loops, postfix ops)
}

// State machine for each Rule type
enum EvalState {
    // Universal states
    Initial,
    Complete,

    // Binary operators
    EvalLeft,
    EvalRight,
    ApplyOp,

    // Control flow
    IfEvalCondition,
    IfEvalBranch(usize),

    WhileCheckCondition,
    WhileEvalBody,

    ForEvalCollection,
    ForIterateBody(usize),

    // Postfix chains (most complex)
    PostfixEvalBase,
    PostfixEvalOperation(usize),
    PostfixApplyOperation(usize),

    // Function calls
    CallEvalArgs(usize),
    CallExecute,

    // Exception handling
    TryEvalBody,
    TryEvalCatch(usize),
    TryEvalEnsure,
}

// Additional context for complex evaluations
enum EvalContext {
    Loop(LoopState),
    Postfix(PostfixState),
    FunctionCall(CallState),
}

struct LoopState {
    iterator: Box<dyn Iterator<Item = QValue>>,
    loop_var: String,
    body_statements: Vec<Pair<Rule>>,
    current_iteration: usize,
}

struct PostfixState {
    operations: Vec<Pair<Rule>>,
    current_op: usize,
}

struct CallState {
    function: QValue,
    args: Vec<QValue>,
    kwargs: HashMap<String, QValue>,
}
```

### Core Algorithm

```rust
pub fn eval_pair_iterative(
    initial_pair: Pair<Rule>,
    scope: &mut Scope
) -> Result<QValue, String> {
    let mut stack: Vec<EvalFrame> = vec![
        EvalFrame {
            pair: initial_pair,
            state: EvalState::Initial,
            partial_results: vec![],
            context: None,
        }
    ];

    while let Some(mut frame) = stack.pop() {
        match (frame.pair.as_rule(), &frame.state) {
            // State machine for each Rule
            // Each case pushes new frames or returns results

            // Example: Terminal case
            (Rule::nil, EvalState::Initial) => {
                push_result_to_parent(&mut stack, QValue::Nil(QNil))?;
            }

            // Example: Binary operator
            (Rule::addition, EvalState::Initial) => {
                // Push continuation + left evaluation
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                stack.push(EvalFrame {
                    pair: frame.pair,
                    state: EvalState::EvalLeft,
                    partial_results: vec![],
                    context: None,
                });

                stack.push(EvalFrame::new(left));
            }

            (Rule::addition, EvalState::EvalLeft) => {
                // Left result in partial_results, evaluate right
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // skip left
                let right = inner.next().unwrap();

                stack.push(EvalFrame {
                    pair: frame.pair,
                    state: EvalState::EvalRight,
                    partial_results: frame.partial_results,
                    context: None,
                });

                stack.push(EvalFrame::new(right));
            }

            (Rule::addition, EvalState::EvalRight) => {
                // Both results available, apply operator
                let right = frame.partial_results.pop().unwrap();
                let left = frame.partial_results.pop().unwrap();

                let result = call_method_on_value(&left, "plus", vec![right], scope)?;
                push_result_to_parent(&mut stack, result)?;
            }

            // ... 50+ more Rule cases ...
        }
    }

    Err("Stack exhausted without result".to_string())
}

fn push_result_to_parent(
    stack: &mut Vec<EvalFrame>,
    result: QValue
) -> Result<(), String> {
    if let Some(parent) = stack.last_mut() {
        parent.partial_results.push(result);
        Ok(())
    } else {
        // Top-level result - should be returned by main loop
        Ok(())
    }
}
```

## Implementation Plan

### Phase 1: Foundation (Days 1-2)
- Create `EvalFrame`, `EvalState`, context structs
- Implement skeleton `eval_pair_iterative` with stack loop
- Add helper functions for frame management

### Phase 2: Simple Rules (Days 3-4)
- Implement terminal cases (literals, nil, boolean, etc.)
- Implement unary operators (logical_not, unary, etc.)
- Implement binary operators (addition, multiplication, comparison, etc.)
- **Test:** Run arithmetic and logic tests

### Phase 3: Control Flow (Days 5-7)
- Implement if_statement state machine
- Implement match_statement state machine
- Implement while_statement with iteration
- Implement for_statement with collection iteration
- **Test:** Run control flow tests

### Phase 4: Postfix Chains (Days 8-11)
- Implement PostfixState for operation tracking
- Implement postfix base evaluation
- Implement method call evaluation (with arg evaluation)
- Implement field access
- Implement indexing
- Handle nested postfix operations
- **Test:** Run method call and property access tests

### Phase 5: Complex Features (Days 12-14)
- Implement function_declaration capture
- Implement type_declaration parsing
- Implement try/catch/ensure state machine
- Implement with_statement (context managers)
- Implement assignment (including indexed assignment)
- **Test:** Run full feature tests

### Phase 6: Integration (Days 15-16)
- Replace all `eval_pair` call sites with `eval_pair_iterative`
- Update function call integration
- Update module loading
- Maintain call_stack for debugging
- **Test:** Run full test suite

### Phase 7: Testing & Optimization (Days 17-18)
- Run full test suite: `./target/release/quest scripts/qtest test/`
- Create deep nesting stress tests
- Verify Bug #019 is fixed
- Profile performance vs recursive version
- Fix any regressions

## Benefits

1. **No Rust stack limit** - Only limited by heap memory
2. **Supports thousands of function calls** - Practical limit ~100k+
3. **Better debugging** - Explicit stack is inspectable
4. **Clearer control flow** - State machines are explicit
5. **Exception handling** - Stack unwinding is explicit

## Drawbacks

1. **Complexity** - ~3,000 lines to refactor
2. **State explosion** - 52 Rules × multiple states each
3. **Performance** - Slight overhead vs direct recursion (mitigated by avoiding stack overflow)
4. **Maintenance** - State machines harder to modify than recursive code

## Alternatives Considered

### 1. Increase Rust stack size
**Rejected:** Requires recompilation, not portable, doesn't solve fundamental issue

### 2. Trampoline pattern
**Rejected:** Still uses Rust stack, just delays overflow

### 3. Hybrid approach (recursive + iterative for hot paths)
**Considered:** Use iterative only for postfix chains and loops
- **Pros:** 40% of work, 80% of benefit
- **Cons:** Two evaluation paths to maintain

### 4. Keep recursive with better limits
**Rejected:** Current approach (QEP-048) still hits Rust stack limits

## Testing

### Unit Tests
- Test each state machine independently
- Test state transitions
- Test partial result accumulation

### Integration Tests
- Run full existing test suite
- Add deep nesting tests:
  ```quest
  # Deep method chains
  obj.a().b().c()...(x1000)

  # Deep loop nesting
  for i in 1 to 100
    for j in 1 to 100
      for k in 1 to 100
        # 1M iterations
      end
    end
  end

  # Deep recursion
  fun fib(n)
    if n <= 1 then return n end
    return fib(n-1) + fib(n-2)
  end
  fib(10000)
  ```

### Bug Verification
- Run Bug #019 reproduction case
- Verify no stack overflow

## Current Evaluator Analysis

**File:** `src/main.rs`
**Lines:** 960-4232 (~3,272 lines)
**Total Rules:** 52
**Recursive Rules:** 31

**Deepest cases:**
1. **postfix** (~637 lines) - Method chains, field access, indexing
2. **type_declaration** (~429 lines) - Struct parsing
3. **for_statement** (~204 lines) - Iteration with scopes

**Most recursive rules:**
- Control flow: if/match/while/for
- Operators: all binary/unary ops
- Postfix: method calls, field access
- Expressions: nested evaluation

## Timeline

- **Phase 1-2:** 4 days (Foundation + Simple Rules)
- **Phase 3:** 3 days (Control Flow)
- **Phase 4:** 4 days (Postfix Chains)
- **Phase 5:** 3 days (Complex Features)
- **Phase 6:** 2 days (Integration)
- **Phase 7:** 2 days (Testing)

**Total:** ~18 days focused development

## References

- Bug #019: Stack overflow in nested module method calls
- QEP-048: Stack depth tracking (current mitigation)
- `src/main.rs`: Current recursive evaluator
- `src/scope.rs`: Scope management with depth tracking
