# QEP-049: Postfix Implementation Status

**Date:** 2025-10-13
**Status:** In Progress - Member Access Complete, Method Calls Pending

## Summary

Successfully implemented iterative evaluation for `Rule::postfix` with working member access support. Method calls and index access still fall back to recursive evaluation due to complexity.

## Implementation Details

### Completed: Member Access

**File:** `src/eval.rs` lines 526-659

**State Machine:**
1. `PostfixEvalBase` - Evaluate base expression (primary)
2. `PostfixApplyOperation(index)` - Apply operations sequentially

**Supported:**
- ✅ Struct field access: `person.name`
- ✅ Module member access: `module.function`
- ✅ Error handling for undefined attributes

**Example:**
```quest
let person = Person.new(name: "Alice", age: 30)
let name = person.name  # Iterative evaluation
```

### Pending: Method Calls

**Why Complex:**
Method calls require:
1. **Argument parsing and evaluation**
   - Positional args: `obj.method(1, 2, 3)`
   - Named/keyword args: `obj.method(x: 1, y: 2)` (QEP-035)
   - Array unpacking: `obj.method(*args)` (QEP-034)
   - Dict unpacking: `obj.method(**kwargs)` (QEP-034)
   - Mixed args: `obj.method(1, x: 2, *rest, **opts)`

2. **Method dispatch complexity**
   - Built-in methods (Int.plus, Array.push, etc.)
   - User-defined methods (Type methods)
   - Module functions
   - Special methods (.is(), .does(), ._doc(), etc.)
   - Fast paths for common methods (QEP-042 optimizations)

3. **Scope management**
   - Binding `self` for instance methods
   - Module scope sharing (Rc<RefCell<>> semantics)
   - I/O redirection inheritance
   - Exception handling

**Current Fallback:**
```rust
if has_parens || has_args {
    // METHOD CALL - fall back to recursive
    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
    push_result_to_parent(&mut stack, result, &mut final_result)?;
}
```

**Required Implementation:**

1. **Argument Evaluation State Machine:**
   ```rust
   enum EvalState {
       // ... existing states ...
       CallEvalArg(usize),         // Evaluate positional arg at index
       CallEvalKwarg(usize),       // Evaluate keyword arg at index
       CallEvalArrayUnpack(usize), // Evaluate *expr
       CallEvalDictUnpack(usize),  // Evaluate **expr
       CallExecute,                // Execute with all args evaluated
   }
   ```

2. **CallState Context:**
   ```rust
   struct CallState<'i> {
       function: Option<QValue>,       // Method to call
       args: Vec<QValue>,              // Evaluated positional args
       kwargs: HashMap<String, QValue>,// Evaluated keyword args
       arg_pairs: Vec<Pair<'i, Rule>>, // Unevaluated arg expressions
       // ... unpacking state ...
   }
   ```

3. **Method Dispatch Logic:**
   - Check for built-in methods first (fast paths)
   - Handle special methods (.is(), .does(), etc.)
   - Look up user-defined methods in type definitions
   - Handle module function calls
   - Execute with proper scope setup

**Estimated Complexity:** ~500-800 lines

### Pending: Index Access

**Why Complex:**
Index access requires:
1. Evaluating index expression: `arr[i + 1]`
2. Multi-dimensional indexing: `grid[x][y]`
3. Multiple indices: `tensor[1, 2, 3]`
4. Type-specific behavior (Array, Dict, String, Bytes)

**Current Fallback:**
```rust
Rule::index_access => {
    // Fall back to recursive
    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
    push_result_to_parent(&mut stack, result, &mut final_result)?;
}
```

**Required Implementation:**
1. Parse index expressions from `index_access` rule
2. Evaluate each index expression iteratively
3. Apply indexing with type-specific logic
4. Handle chained indexing: `arr[i][j]`

**Estimated Complexity:** ~200-300 lines

## Test Results

All 2504 tests passing with current implementation (member access + recursive fallback for method calls/indexing).

## Routing Status

**Current Routing:**
```rust
let use_iterative = matches!(rule,
    Rule::nil | Rule::boolean | Rule::number |
    Rule::bytes_literal | Rule::type_literal |
    Rule::if_statement
);
```

**Cannot Route:**
Despite all operators implemented (Phase 7 complete), cannot route full expression chain due to hybrid evaluation mismatch:

```
[x + 1].len()  // Expression
    ↓
Array literal with expression (iterative)
    ↓
.len() method call (recursive fallback)
    ↓
MISMATCH: Parent iterative, child recursive → fails
```

**Blocker:** Must implement method calls iteratively before routing expression chain.

## Next Steps

### Option A: Full Iterative Implementation (User-Requested)
Implement method calls and index access fully iteratively, then route complete expression chain.

**Benefits:**
- Complete iterative evaluation (QEP-049 goal)
- Foundation for bytecode interpreter (user's long-term goal)
- No hybrid evaluation mismatches

**Effort:** ~800-1100 lines, 3-5 days

**Steps:**
1. Implement argument evaluation state machine (~300 lines)
2. Implement method dispatch in iterative context (~400 lines)
3. Implement index access iteratively (~200 lines)
4. Test with full routing (~100 lines)

### Option B: Incremental Approach
Start with simple cases (zero-arg methods, single-index access) and gradually add complexity.

**Benefits:**
- Can route simple expressions immediately
- Incremental testing
- Lower risk of breaking changes

**Effort:** ~400-600 lines for simple cases, expand later

### Option C: Enhanced Hybrid Routing
Accept that some cases use recursive fallback, improve routing to minimize mismatches.

**Benefits:**
- Faster to implement (~100 lines)
- Still gets most benefits of iterative evaluation

**Drawbacks:**
- Doesn't achieve full iterative goal
- Complex routing logic
- Hybrid evaluation harder to reason about

## Recommendation

Per user direction: **Option A** - "complete the iterative router, eventually remove the recursive one and at some point build a bytecode interpreter"

Start with argument evaluation state machine, as this unblocks both method calls and general function calls.

## Files Modified

- `src/eval.rs`: +130 lines, -27 lines
  - Added `PostfixApplyOperation` handler
  - Implemented member access
  - Removed duplicate postfix implementation

## References

- QEP-049: Iterative Evaluator Spec
- QEP-034: Variadic Parameters (\*args, \*\*kwargs)
- QEP-035: Named Arguments
- QEP-042: Performance Optimizations (fast paths to preserve)
- src/main.rs:2787-3500: Current recursive postfix implementation (~714 lines)
- src/main.rs:444-529: parse_call_arguments function (argument parsing logic)
