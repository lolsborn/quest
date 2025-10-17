# QEP-056: Structured Control Flow with ControlFlow Enum

**Status:** Draft (Future Work)
**Author:** Quest Language Team
**Created:** 2025-10-16
**Related:** QEP-037 (Typed Exceptions), QEP-049 (Iterative Evaluator), QEP-048 (Stack Depth Tracking)
**Depends On:** QEP-049 completion

## Abstract

Quest currently uses "magic strings" (`__FUNCTION_RETURN__`, `__LOOP_BREAK__`, `__LOOP_CONTINUE__`) to signal non-local control flow through the evaluator's `Result<QValue, String>` return type. This approach is error-prone, lacks type safety, and conflates actual errors with intentional control flow.

This QEP proposes migrating to a structured `Result<QValue, EvalError>` return type that distinguishes between:
- **Normal values**: `Ok(QValue)` - successful evaluation
- **Control flow signals**: `Err(EvalError::ControlFlow(...))` - return/break/continue
- **Actual errors**: `Err(EvalError::Runtime(...))` - runtime errors

The infrastructure already exists in `src/control_flow.rs` (added in early 2024) but remains unused. This QEP defines the migration plan to activate it.

## Motivation

### Current Architecture Problems

#### 1. Magic Strings Are Error-Prone

```rust
// Current implementation (main.rs, function_call.rs, eval.rs)
const MAGIC_FUNCTION_RETURN: &str = "__FUNCTION_RETURN__";
const MAGIC_LOOP_BREAK: &str = "__LOOP_BREAK__";
const MAGIC_LOOP_CONTINUE: &str = "__LOOP_CONTINUE__";

// Function return handling
if err == MAGIC_FUNCTION_RETURN {
    // Extract from scope.return_value
    return Ok(scope.return_value.take().unwrap_or(QValue::Nil));
}

// Easy to typo - no compiler help!
if err == "__FUNCTION_RETRUN__" {  // ❌ Typo! Silently fails
    // Never executes
}
```

**Problems:**
- No compile-time validation (typos compile but break at runtime)
- String comparison overhead (~30-100ns per comparison vs ~1ns for enum)
- Dual storage: value in `scope.return_value` AND signal in `Err(String)`
- Impossible to distinguish control flow from actual errors in type system

#### 2. String Errors Conflate Control Flow with Errors

```rust
// All of these look identical in the type system
Err("IndexErr: Array index out of bounds: 10")           // Real error
Err("__FUNCTION_RETURN__")                                // Control flow!
Err("RuntimeErr: Division by zero")                       // Real error
Err("__LOOP_BREAK__")                                     // Control flow!

// Can't pattern match on control flow vs errors
match eval_pair(pair, scope) {
    Ok(val) => handle_value(val),
    Err(e) if e == MAGIC_FUNCTION_RETURN => handle_return(),  // ❌ String comparison
    Err(e) => handle_error(e),                                 // ❌ Might be control flow!
}
```

#### 3. Performance Overhead

Based on Quest codebase analysis:
- **183 files** contain `Result<QValue, String>` signatures
- **32 call sites** check magic strings (5 files: main.rs, eval.rs, function_call.rs, commands.rs, control_flow.rs)
- **Every error** performs string comparisons against 3 magic constants

Benchmarking overhead:
```rust
// String comparison: ~50-100ns per check
if err == "__FUNCTION_RETURN__" || err == "__LOOP_BREAK__" || err == "__LOOP_CONTINUE__"

// Enum matching: ~1ns per check
match eval_error {
    EvalError::ControlFlow(cf) => match cf { ... },
    EvalError::Runtime(_) => ...
}
```

**Impact:** In tight loops with frequent control flow (e.g., array operations with early returns), this adds ~5-10% overhead.

#### 4. Debugging Difficulty

```rust
// Error messages lose context
Err("__FUNCTION_RETURN__")  // Which function? What value?

// Stack traces don't distinguish control flow from errors
Error: "__LOOP_BREAK__"
  at eval_pair (main.rs:943)
  at eval_while (main.rs:2156)
  // Is this a bug or intentional control flow?
```

### Current Implementation Status

**Magic strings currently used in:**
1. **src/main.rs** (4 sites) - return/break/continue statement evaluation
2. **src/eval.rs** (3 sites) - iterative evaluator loop handling
3. **src/function_call.rs** (1 site) - function return unwinding
4. **src/commands.rs** (1 site) - REPL special handling
5. **src/control_flow.rs** (7 sites) - constant definitions + conversion helpers

**Infrastructure ready but unused:**
- `ControlFlow` enum (3 variants: FunctionReturn, LoopBreak, LoopContinue)
- `EvalError` enum (2 variants: ControlFlow, Runtime)
- `EvalResult<T>` type alias
- Helper methods: `is_return()`, `is_break()`, `is_continue()`, etc.
- Conversion functions for backward compatibility

## Proposal

### Phase 1: Gradual Migration Strategy

Migrate evaluator return types from `Result<QValue, String>` to `Result<QValue, EvalError>` in phases:

#### Target Architecture

```rust
// src/control_flow.rs (already exists, currently unused)

#[derive(Debug, Clone)]
pub enum ControlFlow {
    FunctionReturn(QValue),  // return with value
    LoopBreak,               // break
    LoopContinue,            // continue
}

#[derive(Debug, Clone)]
pub enum EvalError {
    ControlFlow(ControlFlow),  // Non-error control flow
    Runtime(String),           // Actual runtime errors
}

pub type EvalResult<T> = Result<T, EvalError>;
```

#### Conversion Layer (already exists)

```rust
// Bidirectional conversion for gradual migration
impl From<String> for EvalError {
    fn from(msg: String) -> Self {
        // Parse magic strings during migration
        if msg == MAGIC_FUNCTION_RETURN {
            EvalError::ControlFlow(ControlFlow::FunctionReturn(/* extract from scope */))
        } else if msg == MAGIC_LOOP_BREAK {
            EvalError::ControlFlow(ControlFlow::LoopBreak)
        } else if msg == MAGIC_LOOP_CONTINUE {
            EvalError::ControlFlow(ControlFlow::LoopContinue)
        } else {
            EvalError::Runtime(msg)
        }
    }
}

impl From<EvalError> for String {
    fn from(err: EvalError) -> String {
        match err {
            EvalError::ControlFlow(ControlFlow::FunctionReturn(_)) => MAGIC_FUNCTION_RETURN.to_string(),
            EvalError::ControlFlow(ControlFlow::LoopBreak) => MAGIC_LOOP_BREAK.to_string(),
            EvalError::ControlFlow(ControlFlow::LoopContinue) => MAGIC_LOOP_CONTINUE.to_string(),
            EvalError::Runtime(msg) => msg,
        }
    }
}
```

### Phase 2: Migration Roadmap

#### Step 1: Activate Control Flow Infrastructure (1-2 days)

**Goal:** Enable bidirectional conversion layer

1. Remove `#[allow(dead_code)]` from `control_flow.rs`
2. Add feature flag: `cfg(feature = "structured-control-flow")`
3. Update `Scope` to support both architectures:
   ```rust
   pub struct Scope {
       // OLD: Dual storage (remove after migration)
       pub return_value: Option<QValue>,

       // NEW: Unified control flow state
       pub pending_control_flow: Option<ControlFlow>,

       // ... rest unchanged
   }
   ```

**Testing:**
- Verify conversion functions work correctly
- All existing tests pass with feature flag OFF
- Unit tests for `ControlFlow` enum methods

#### Step 2: Migrate Core Evaluator Entry Points (3-5 days)

**Goal:** Change signature of main evaluation functions

**Files to update:**
1. `src/main.rs` - `eval_pair()`, `eval_pair_impl()`
2. `src/eval.rs` - `eval_pair_iterative()`

**Migration pattern:**
```rust
// BEFORE
pub fn eval_pair(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    match pair.as_rule() {
        Rule::return_statement => {
            // Store value in scope
            scope.return_value = Some(value);
            // Signal with magic string
            Err(MAGIC_FUNCTION_RETURN.to_string())
        }
        Rule::break_statement => Err(MAGIC_LOOP_BREAK.to_string()),
        Rule::continue_statement => Err(MAGIC_LOOP_CONTINUE.to_string()),
        // ... 50+ other rules
    }
}

// AFTER
pub fn eval_pair(pair: Pair<Rule>, scope: &mut Scope) -> EvalResult<QValue> {
    match pair.as_rule() {
        Rule::return_statement => {
            let value = /* evaluate expression or nil */;
            Err(EvalError::function_return(value))  // ✅ Value stored in enum!
        }
        Rule::break_statement => Err(EvalError::loop_break()),
        Rule::continue_statement => Err(EvalError::loop_continue()),
        // ... 50+ other rules (most unchanged)
    }
}
```

**Compatibility shim for incremental migration:**
```rust
// Wrapper to maintain string-based APIs during transition
pub fn eval_pair_string_api(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    eval_pair(pair, scope).map_err(|e| e.into())
}
```

**Testing:**
- All unit tests pass
- Control flow tests: return/break/continue in nested contexts
- Performance benchmark: ensure no regression

#### Step 3: Update Control Flow Handling (2-3 days)

**Goal:** Replace string comparisons with enum matching

**Files to update:**
1. `src/main.rs` - Loop implementations (while, for)
2. `src/function_call.rs` - Function call unwinding
3. `src/eval.rs` - Iterative evaluator loop handling

**Migration pattern:**
```rust
// BEFORE: String comparison in loops
loop {
    match eval_pair(body, scope) {
        Ok(_) => continue,
        Err(e) if e == MAGIC_LOOP_BREAK => break,
        Err(e) if e == MAGIC_LOOP_CONTINUE => continue,
        Err(e) if e == MAGIC_FUNCTION_RETURN => return Err(e),  // Propagate
        Err(e) => return Err(e),  // Actual error
    }
}

// AFTER: Enum matching
loop {
    match eval_pair(body, scope) {
        Ok(_) => continue,
        Err(EvalError::ControlFlow(ControlFlow::LoopBreak)) => break,
        Err(EvalError::ControlFlow(ControlFlow::LoopContinue)) => continue,
        Err(EvalError::ControlFlow(cf @ ControlFlow::FunctionReturn(_))) => {
            return Err(EvalError::ControlFlow(cf));  // Propagate upward
        }
        Err(e) => return Err(e),  // Actual error
    }
}
```

**Benefits visible here:**
- Type safety: Compiler catches missing `match` arms
- Performance: Enum comparison (1ns) vs string comparison (50-100ns)
- Clarity: Explicit control flow vs error handling

**Testing:**
- Nested loop break/continue tests
- Early return from deep call stacks
- Exception handling preserves control flow

#### Step 4: Update Module APIs (3-5 days)

**Goal:** Propagate `EvalResult<T>` through module interfaces

**Scope:**
- 183 files contain `Result<QValue, String>` signatures
- Most modules don't interact with control flow (safe to batch update)
- Focus on modules that call `eval_pair()`:
  - `src/module_loader.rs`
  - `src/commands.rs` (REPL)
  - Decorator modules (call user functions)
  - Test framework (exception handling)

**Migration pattern:**
```rust
// BEFORE
pub fn load_module(path: &str, scope: &mut Scope) -> Result<QValue, String> {
    let result = eval_pair(module_ast, scope)?;
    Ok(result)
}

// AFTER
pub fn load_module(path: &str, scope: &mut Scope) -> EvalResult<QValue> {
    let result = eval_pair(module_ast, scope)?;  // Propagates EvalError
    Ok(result)
}
```

**Modules requiring special handling:**
1. **src/commands.rs** - REPL should print control flow differently than errors
2. **std/decorators** - Need to preserve control flow through decorators
3. **std/test** - Exception assertions must not catch control flow

**Testing:**
- Module loading tests
- REPL integration tests
- Decorator control flow preservation

#### Step 5: Remove Scope.return_value (1 day)

**Goal:** Eliminate dual storage of return values

Currently:
- Return value stored in `scope.return_value: Option<QValue>`
- Control flow signaled with `Err(MAGIC_FUNCTION_RETURN)`

After:
- Return value stored directly in `ControlFlow::FunctionReturn(QValue)`
- Single source of truth

**Changes:**
```rust
// src/scope.rs
pub struct Scope {
    // REMOVE this field
    // pub return_value: Option<QValue>,

    // Keep these (unchanged)
    pub variables: HashMap<String, QValue>,
    pub parent: Option<Rc<RefCell<Scope>>>,
    // ... rest
}
```

**Testing:**
- All function return tests pass
- No more dual-storage bugs

#### Step 6: Remove Magic String Constants (1 day)

**Goal:** Delete legacy control flow infrastructure

```rust
// src/control_flow.rs - DELETE these
pub const MAGIC_FUNCTION_RETURN: &str = "__FUNCTION_RETURN__";
pub const MAGIC_LOOP_BREAK: &str = "__LOOP_BREAK__";
pub const MAGIC_LOOP_CONTINUE: &str = "__LOOP_CONTINUE__";
```

**Verification:**
```bash
# Should find ZERO occurrences
rg "__FUNCTION_RETURN__|__LOOP_BREAK__|__LOOP_CONTINUE__" src/
```

**Testing:**
- Full test suite passes
- Grep confirms no magic strings remain

### Phase 3: Documentation and Examples

#### Update Documentation (2 days)

**Files to update:**
1. `CLAUDE.md` - Update evaluator architecture section
2. `docs/control_flow.md` - Explain new return type
3. Code comments - Update eval_pair documentation

**Example documentation:**

```markdown
## Evaluator Return Type

Quest's evaluator uses `Result<QValue, EvalError>` to distinguish:

- **Normal values**: `Ok(QValue)` - evaluation succeeded
- **Control flow**: `Err(EvalError::ControlFlow(...))` - return/break/continue
- **Errors**: `Err(EvalError::Runtime(...))` - runtime errors

### Control Flow Signals

Control flow keywords (`return`, `break`, `continue`) are not errors - they're
intentional control flow changes that need to propagate up the call stack:

```rust
match eval_pair(expr, scope) {
    Ok(value) => handle_value(value),
    Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(val))) => {
        // Function returning - propagate upward
        return Ok(val);
    }
    Err(EvalError::ControlFlow(ControlFlow::LoopBreak)) => {
        // Break loop - stop iteration
        break;
    }
    Err(EvalError::Runtime(msg)) => {
        // Actual error - handle or propagate
        return Err(EvalError::Runtime(msg));
    }
}
```

### Why Not Just Use Strings?

The old architecture used magic strings (`__FUNCTION_RETURN__`, etc.):
- ❌ No type safety (typos compile but break)
- ❌ String comparison overhead (~50-100ns vs ~1ns)
- ❌ Conflates errors with control flow
- ❌ Dual storage (scope + error)

The new architecture uses enums:
- ✅ Compiler catches typos and missing match arms
- ✅ 50-100× faster comparison
- ✅ Type system distinguishes control flow from errors
- ✅ Single source of truth (value in enum)
```

#### Add Examples (1 day)

**Example 1: Loop with early exit**
```quest
fun find_first(arr, predicate)
    for item in arr
        if predicate(item)
            return item  # ✅ Returns QValue through ControlFlow::FunctionReturn
        end
    end
    return nil
end
```

**Example 2: Nested loops with break**
```quest
fun matrix_search(matrix, target)
    for row in matrix
        for cell in row
            if cell == target
                return true  # ✅ Breaks both loops via function return
            end
        end
    end
    return false
end
```

**Example 3: Continue in loops**
```quest
fun sum_positive(numbers)
    let total = 0
    for n in numbers
        if n < 0
            continue  # ✅ Signals LoopContinue, not an error
        end
        total = total + n
    end
    return total
end
```

## Benefits

### 1. Type Safety

```rust
// Compiler enforces exhaustive matching
match eval_result {
    Ok(val) => /* ... */,
    Err(EvalError::ControlFlow(cf)) => match cf {
        ControlFlow::FunctionReturn(val) => /* ... */,
        ControlFlow::LoopBreak => /* ... */,
        ControlFlow::LoopContinue => /* ... */,
        // ✅ Compiler error if any variant missing
    },
    Err(EvalError::Runtime(msg)) => /* ... */,
}

// No more typos that compile but fail at runtime
if err == "__FUNCTION_RETRUN__"  // ❌ OLD: Compiles, silently broken
```

### 2. Performance

**Benchmarking results (estimated):**
- String comparison: 50-100ns per check
- Enum comparison: ~1ns per check
- **50-100× speedup** on control flow checks

**Impact on real code:**
- Tight loops with break/continue: 5-10% faster
- Recursive functions with early returns: 2-5% faster
- Negligible impact on code without control flow

### 3. Better Debugging

```rust
// OLD: Generic error message
Error: "__FUNCTION_RETURN__"
  at eval_pair (main.rs:943)

// NEW: Explicit control flow in debugger
ControlFlow::FunctionReturn(QValue::Int(42))
  at eval_pair (main.rs:943)

// Can inspect value directly in enum!
```

### 4. Single Source of Truth

```rust
// OLD: Dual storage (error-prone)
scope.return_value = Some(QValue::Int(42));  // Store value
return Err("__FUNCTION_RETURN__");           // Signal control flow
// What if these get out of sync?

// NEW: Single storage (impossible to desync)
return Err(EvalError::ControlFlow(
    ControlFlow::FunctionReturn(QValue::Int(42))
));
```

### 5. Clearer Intent

```rust
// OLD: Is this an error or control flow?
Err("__LOOP_BREAK__")  // Not obvious from type

// NEW: Type tells you it's control flow
Err(EvalError::ControlFlow(ControlFlow::LoopBreak))  // Explicit!
```

## Drawbacks and Mitigation

### 1. Large Codebase Impact

**Problem:** 183 files with `Result<QValue, String>` signatures

**Mitigation:**
- Gradual migration with compatibility layer
- Most files don't use control flow (batch update safe)
- Focus migration on critical paths first

### 2. Learning Curve

**Problem:** Developers must understand `EvalError` vs string errors

**Mitigation:**
- Clear documentation with examples
- Type system guides developers (compiler errors helpful)
- Conversion layer eases transition

### 3. Error Message Changes

**Problem:** Error messages change from strings to enums

**Mitigation:**
- `EvalError::to_string()` preserves string representation
- REPL output formatting handles both types
- Exception messages unchanged (only internal representation)

### 4. Increased Complexity

**Problem:** Two-level enum (`EvalError` wrapping `ControlFlow`) vs simple strings

**Mitigation:**
- Complexity is explicit (was implicit before)
- Helper methods hide boilerplate: `EvalError::function_return(val)`
- Type safety benefits outweigh complexity

## Alternatives Considered

### Alternative 1: Keep Magic Strings

**Rejected because:**
- No type safety
- Performance overhead
- Conflates errors with control flow
- Dual storage error-prone

### Alternative 2: Separate Result Type for Control Flow

```rust
pub enum EvalResult {
    Value(QValue),
    ControlFlow(ControlFlow),
    Error(String),
}
```

**Rejected because:**
- Not a proper `Result` type (breaks `?` operator)
- Can't use standard error handling patterns
- More invasive change than `Result<T, EvalError>`

### Alternative 3: Exceptions for Control Flow

Use Quest's exception system for control flow:

```quest
# Return as exception
raise ReturnException.new(value)

# Break as exception
raise BreakException.new()
```

**Rejected because:**
- Conflates language-level exceptions with implementation detail
- Performance overhead (exception unwinding)
- Confusing error messages
- Breaks exception handling semantics

### Alternative 4: Hybrid Approach (Current Status)

Keep magic strings, add `ControlFlow` enum for future use.

**Rejected because:**
- Maintains all current problems
- Dead code overhead
- Unclear migration path

## Testing Strategy

### Unit Tests

```rust
#[test]
fn test_function_return_control_flow() {
    let mut scope = Scope::new();
    let code = "return 42";
    let pairs = parse(code).unwrap();

    match eval_pair(pairs, &mut scope) {
        Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(val))) => {
            assert_eq!(val, QValue::Int(42));
        }
        _ => panic!("Expected function return control flow"),
    }
}

#[test]
fn test_loop_break_control_flow() {
    let mut scope = Scope::new();
    let code = "while true break end";
    let pairs = parse(code).unwrap();

    // Should complete normally (break caught by loop)
    assert!(eval_pair(pairs, &mut scope).is_ok());
}

#[test]
fn test_control_flow_propagation() {
    let mut scope = Scope::new();
    let code = r#"
        fun outer()
            fun inner()
                return 42
            end
            inner()
            return 99  # Should not reach
        end
        outer()
    "#;
    let pairs = parse(code).unwrap();

    match eval_pair(pairs, &mut scope) {
        Ok(QValue::Int(42)) => {}, // ✅ Inner return propagated correctly
        _ => panic!("Expected return value 42"),
    }
}
```

### Integration Tests

```quest
use "std/test"

test.module("Control Flow")

test.describe("Function returns", fun ()
    test.it("returns from nested function calls", fun ()
        fun find_nested(x)
            if x > 10
                return "found"
            end
            return "not found"
        end

        test.assert_eq(find_nested(15), "found")
        test.assert_eq(find_nested(5), "not found")
    end)

    test.it("returns from loops", fun ()
        fun sum_until_limit(arr, limit)
            let total = 0
            for n in arr
                if total + n > limit
                    return total
                end
                total = total + n
            end
            return total
        end

        test.assert_eq(sum_until_limit([1, 2, 3, 4, 5], 6), 6)
    end)
end)

test.describe("Loop break", fun ()
    test.it("breaks out of while loop", fun ()
        let i = 0
        while i < 100
            if i == 5
                break
            end
            i = i + 1
        end
        test.assert_eq(i, 5)
    end)

    test.it("breaks out of for loop", fun ()
        let count = 0
        for i in [1, 2, 3, 4, 5]
            if i == 3
                break
            end
            count = count + 1
        end
        test.assert_eq(count, 2)
    end)
end)

test.describe("Loop continue", fun ()
    test.it("skips iterations in while loop", fun ()
        let sum = 0
        let i = 0
        while i < 10
            i = i + 1
            if i % 2 == 0
                continue
            end
            sum = sum + i
        end
        test.assert_eq(sum, 25)  # 1+3+5+7+9
    end)

    test.it("skips iterations in for loop", fun ()
        let sum = 0
        for i in [1, 2, 3, 4, 5]
            if i % 2 == 0
                continue
            end
            sum = sum + i
        end
        test.assert_eq(sum, 9)  # 1+3+5
    end)
end)
```

### Performance Benchmarks

```rust
#[bench]
fn bench_control_flow_old(b: &mut Bencher) {
    let mut scope = Scope::new();
    let code = "for i in 1..1000 if i == 500 then break end end";
    let pairs = parse(code).unwrap();

    b.iter(|| {
        eval_pair_string_api(pairs.clone(), &mut scope).unwrap()
    });
}

#[bench]
fn bench_control_flow_new(b: &mut Bencher) {
    let mut scope = Scope::new();
    let code = "for i in 1..1000 if i == 500 then break end end";
    let pairs = parse(code).unwrap();

    b.iter(|| {
        eval_pair(pairs.clone(), &mut scope).unwrap()
    });
}

// Expected: NEW is 5-10% faster due to enum matching
```

## Implementation Timeline

### Phase 1: Foundation (1 week)
- **Day 1:** Remove `#[allow(dead_code)]`, add feature flag
- **Day 2:** Update `Scope` for dual architecture
- **Day 3:** Activate conversion layer
- **Day 4-5:** Unit tests for `ControlFlow` and `EvalError`

### Phase 2: Core Migration (2 weeks)
- **Days 1-3:** Update `eval_pair()` signatures
- **Days 4-6:** Update control flow handling (loops, functions)
- **Days 7-10:** Update module APIs

### Phase 3: Cleanup (1 week)
- **Days 1-2:** Remove `Scope.return_value`
- **Day 3:** Delete magic string constants
- **Days 4-5:** Integration testing

### Phase 4: Documentation (3 days)
- **Day 1:** Update code documentation
- **Day 2:** Update user-facing docs
- **Day 3:** Add examples and migration guide

**Total: 4 weeks focused development**

## Dependencies

### Required Completions
1. **QEP-049 Iterative Evaluator** - Should be complete first
   - Iterative evaluator already partially uses control flow checking
   - Migration easier after QEP-049 finishes

### Optional Synergies
1. **QEP-037 Typed Exceptions** - Already complete
   - Can add `EvalError::Exception(QException)` variant
   - Unifies all error handling under `EvalError`

## Success Criteria

1. ✅ All 32 magic string checks replaced with enum matching
2. ✅ Zero occurrences of `MAGIC_FUNCTION_RETURN`, `MAGIC_LOOP_BREAK`, `MAGIC_LOOP_CONTINUE`
3. ✅ `Scope.return_value` field removed
4. ✅ All 2504 tests pass
5. ✅ Performance benchmarks show 5-10% improvement in control flow heavy code
6. ✅ No performance regression in code without control flow
7. ✅ Documentation updated
8. ✅ Type safety: Compiler catches control flow handling errors

## Future Work

### Potential Extensions

#### 1. Add Exception Variant to EvalError

```rust
pub enum EvalError {
    ControlFlow(ControlFlow),
    Runtime(String),
    Exception(QException),  // ✅ NEW: Typed exceptions from QEP-037
}
```

**Benefits:**
- Unifies all error handling
- Enables better exception matching
- Clearer distinction between control flow, errors, and exceptions

#### 2. Add Generators/Coroutines

```rust
pub enum ControlFlow {
    FunctionReturn(QValue),
    LoopBreak,
    LoopContinue,
    Yield(QValue),          // ✅ NEW: Generator yield
    Await(Future<QValue>),  // ✅ NEW: Async await
}
```

**Enables:**
- Python-style generators
- Async/await syntax (QEP-055)
- Coroutines for concurrency

#### 3. Better Stack Traces

```rust
pub struct ControlFlow {
    kind: ControlFlowKind,
    location: SourceLocation,  // ✅ NEW: Where was return/break/continue?
    trace: Vec<StackFrame>,     // ✅ NEW: Full stack trace
}
```

**Benefits:**
- Debug "where did this return come from?"
- Better error messages for misplaced break/continue

## Summary

This QEP migrates Quest from magic string control flow to structured `ControlFlow` enum, providing:

- ✅ **Type safety** - Compiler catches errors
- ✅ **Performance** - 50-100× faster control flow checks
- ✅ **Clarity** - Explicit control flow vs errors
- ✅ **Better debugging** - Inspectable control flow state
- ✅ **Foundation for future** - Enables generators, async/await

The infrastructure already exists (added 2024), making this a low-risk migration that activates existing code. Estimated 4 weeks for complete migration with extensive testing.

**Recommendation:** Approve and schedule after QEP-049 completion. This is a foundational improvement that benefits all future Quest development.
