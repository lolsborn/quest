# QEP-048: Stack Depth Tracking and Recursion Limits

**Status**: Draft
**Created**: 2025-10-11
**Related**: QEP-037 (Exception System), QEP-039 (Bytecode Interpreter)

## Summary

Add native stack depth tracking to Quest's interpreter to prevent stack overflow, enable recursion limits, and provide introspection capabilities for monitoring execution depth. This includes both Quest-level call tracking and OS thread stack monitoring.

## Motivation

### Current State

Quest's evaluator uses recursive descent (`eval_pair` calling itself), which directly consumes the OS thread stack:

1. **Module loading is recursive**: `use "module"` → `load_external_module()` → `eval_pair()` for each statement
2. **Expression evaluation is recursive**: Nested expressions create deep call chains
3. **Function calls add frames**: Each user function call adds to the native stack
4. **No depth limits**: Interpreter can overflow the OS stack with deep recursion or module chains

**Call chain example**:
```rust
main()
  → eval_pair(use_statement)
    → load_external_module("module_a")
      → eval_pair(module_a_statement)
        → load_external_module("module_b")  // Nested import
          → eval_pair(module_b_statement)
            → eval_pair(complex_expression)
              → call_user_function()
                → eval_pair(function_body)
                  // ... continues deeper
```

### Problems

1. **Stack overflow risk**: Deep module chains or recursion can crash the interpreter
2. **No visibility**: Users can't monitor or debug deep call stacks
3. **No limits**: No way to configure maximum recursion depth
4. **Debugging difficulty**: Hard to diagnose "where did my stack go?"
5. **Platform differences**: Stack sizes vary (Linux: 8MB, Windows: 1MB default)

### Real-World Scenarios That Can Overflow

**Scenario 1: Deep module dependency chains**
```quest
# main.q
use "level1"  # → level2 → level3 → ... → level100
```

**Scenario 2: Complex nested expressions**
```quest
# Module initialization with deep expression trees
let result = a.method1().method2().method3()...method50()
```

**Scenario 3: Recursive functions**
```quest
fun factorial(n)
    if n <= 1
        return 1
    end
    return n * factorial(n - 1)
end

factorial(10000)  # Overflows stack
```

**Scenario 4: Mutual recursion across modules**
```quest
# module_a.q
use "module_b" as b
fun process_a(n)
    if n > 0
        b.process_b(n - 1)
    end
end

# module_b.q
use "module_a" as a
fun process_b(n)
    if n > 0
        a.process_a(n - 1)
    end
end
```

## Proposed Changes

### 1. Quest-Level Call Depth Tracking

Track interpreter recursion depth in the `Scope` struct:

```rust
// src/scope.rs
pub struct Scope {
    // ... existing fields ...

    /// Current call depth (incremented on function calls and eval recursion)
    pub call_depth: usize,

    /// Maximum allowed call depth (0 = unlimited)
    pub max_call_depth: usize,

    /// Configuration for different depth limits
    pub depth_limits: DepthLimits,
}

#[derive(Clone, Debug)]
pub struct DepthLimits {
    /// Max depth for user function calls (default: 1000)
    pub function_calls: usize,

    /// Max depth for eval_pair recursion (default: 2000)
    pub eval_recursion: usize,

    /// Max depth for module loading (default: 50)
    pub module_loading: usize,
}

impl DepthLimits {
    pub fn default() -> Self {
        DepthLimits {
            function_calls: 1000,
            eval_recursion: 2000,
            module_loading: 50,
        }
    }

    pub fn unlimited() -> Self {
        DepthLimits {
            function_calls: 0,
            eval_recursion: 0,
            module_loading: 0,
        }
    }
}
```

### 2. Depth Checking in eval_pair

```rust
// src/main.rs
pub fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    // Check eval recursion depth
    if scope.depth_limits.eval_recursion > 0 &&
       scope.call_depth >= scope.depth_limits.eval_recursion {
        return runtime_err!(
            "Maximum evaluation depth exceeded: {} (limit: {})\nConsider simplifying expressions or increasing sys.set_recursion_limit()",
            scope.call_depth,
            scope.depth_limits.eval_recursion
        );
    }

    // Increment depth
    scope.call_depth += 1;

    // Evaluate (existing code)
    let result = match pair.as_rule() {
        // ... existing evaluation logic ...
    };

    // Decrement depth before returning
    scope.call_depth -= 1;

    result
}
```

### 3. Depth Checking in Function Calls

```rust
// src/function_call.rs
pub fn call_user_function(
    func: &QUserFun,
    args: Vec<QValue>,
    kwargs: HashMap<String, QValue>,
    scope: &mut Scope,
) -> Result<QValue, String> {
    // Check function call depth
    if scope.depth_limits.function_calls > 0 &&
       scope.call_stack.len() >= scope.depth_limits.function_calls {
        return runtime_err!(
            "Maximum function call depth exceeded: {} (limit: {})\nFunction: {}\nConsider using iteration or increasing sys.set_recursion_limit()",
            scope.call_stack.len(),
            scope.depth_limits.function_calls,
            func.name
        );
    }

    // Add stack frame (existing code)
    let frame = StackFrame::new(func.name.clone());
    scope.call_stack.push(frame);

    // Execute function (existing code)
    let result = /* ... */;

    // Remove stack frame
    scope.call_stack.pop();

    result
}
```

### 4. Depth Checking in Module Loading

```rust
// src/module_loader.rs
pub fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
    // Count current module loading depth
    let module_depth = scope.call_stack.iter()
        .filter(|frame| frame.function_name == "<module>")
        .count();

    if scope.depth_limits.module_loading > 0 &&
       module_depth >= scope.depth_limits.module_loading {
        return import_err!(
            "Maximum module import depth exceeded: {} (limit: {})\nModule: {}\nCheck for circular imports or deeply nested module chains",
            module_depth,
            scope.depth_limits.module_loading,
            path
        );
    }

    // Add module frame
    scope.call_stack.push(StackFrame::new("<module>".to_string()));

    // Load module (existing code)
    let result = /* ... */;

    // Remove module frame
    scope.call_stack.pop();

    result
}
```

### 5. Quest API for Stack Introspection

Add `sys` module functions for runtime introspection and configuration:

```quest
use "std/sys"

# Get current call depth
let depth = sys.get_call_depth()
puts("Current depth: " .. depth.str())  # 3

# Get maximum limits
let limits = sys.get_recursion_limits()
puts("Function limit: " .. limits["function_calls"].str())  # 1000
puts("Eval limit: " .. limits["eval_recursion"].str())      # 2000
puts("Module limit: " .. limits["module_loading"].str())    # 50

# Set new limits (returns old limits)
let old_limits = sys.set_recursion_limit(
    function_calls: 5000,
    eval_recursion: 10000,
    module_loading: 100
)

# Disable all limits (use with caution!)
sys.set_recursion_limit(
    function_calls: 0,
    eval_recursion: 0,
    module_loading: 0
)

# Get call stack (already exists via exception system)
let stack = sys.get_call_stack()
for frame in stack
    puts(frame["function"] .. " at " .. frame["file"])
end
```

### 6. Configuration via Constants

Define default limits as constants in `src/main.rs`:

```rust
// src/main.rs

/// Maximum allowed function call depth (0 = unlimited)
/// Can be changed at runtime via sys.set_recursion_limit()
pub const DEFAULT_MAX_FUNCTION_DEPTH: usize = 1000;

/// Maximum allowed eval_pair recursion depth (0 = unlimited)
pub const DEFAULT_MAX_EVAL_DEPTH: usize = 2000;

/// Maximum allowed module loading depth (0 = unlimited)
pub const DEFAULT_MAX_MODULE_DEPTH: usize = 50;

impl Scope {
    pub fn new() -> Self {
        let depth_limits = DepthLimits {
            function_calls: DEFAULT_MAX_FUNCTION_DEPTH,
            eval_recursion: DEFAULT_MAX_EVAL_DEPTH,
            module_loading: DEFAULT_MAX_MODULE_DEPTH,
        };

        Scope {
            // ... existing initialization ...
            call_depth: 0,
            depth_limits,
        }
    }
}
```

**To customize limits**:

**Option 1: Edit constants in `src/main.rs` and rebuild**
```rust
pub const DEFAULT_MAX_FUNCTION_DEPTH: usize = 5000;  // Increased
pub const DEFAULT_MAX_EVAL_DEPTH: usize = 10000;     // Increased
pub const DEFAULT_MAX_MODULE_DEPTH: usize = 100;     // Increased
```

Then rebuild: `cargo build --release`

**Option 2: Change at runtime via Quest API** (most flexible)
```quest
use "std/sys"
sys.set_recursion_limit(function_calls: 5000)
```

### 7. OS Stack Size Monitoring (Advanced)

For truly paranoid stack monitoring, track native stack usage:

```rust
// src/scope.rs
use std::thread;

pub struct Scope {
    // ... existing fields ...

    /// Approximate remaining OS stack space (bytes)
    pub estimated_stack_remaining: Option<usize>,
}

impl Scope {
    /// Estimate remaining stack space (platform-specific)
    pub fn check_native_stack(&self) -> Result<(), String> {
        #[cfg(target_os = "linux")]
        {
            // Use pthread_getattr_np and pthread_attr_getstack
            // to get current stack bounds
            // Compare current stack pointer to bounds
        }

        #[cfg(target_os = "windows")]
        {
            // Use GetCurrentThreadStackLimits or
            // VirtualQuery to get stack info
        }

        #[cfg(not(any(target_os = "linux", target_os = "windows")))]
        {
            // Fallback: rely on Quest-level depth tracking only
        }

        Ok(())
    }
}
```

**Note**: Native stack monitoring is complex and platform-specific. Phase 1 will use Quest-level tracking only. Native monitoring can be added in Phase 2 if needed.

## Implementation Phases

### Phase 1: Basic Depth Tracking (Immediate)
- Add `call_depth` and `depth_limits` to `Scope`
- Implement depth checking in `eval_pair` and `call_user_function`
- Add depth checking in `load_external_module`
- Default limits: 1000 (functions), 2000 (eval), 50 (modules)
- Error messages with actionable advice

### Phase 2: Quest API (Near-term)
- Add `sys.get_call_depth()`
- Add `sys.get_recursion_limits()`
- Add `sys.set_recursion_limit()`
- Update documentation

### Phase 3: Advanced Monitoring (Future)
- Native stack size monitoring (platform-specific)
- Stack usage statistics (`sys.get_stack_stats()`)
- Warnings at 80% capacity
- Integration with profiling tools

## Error Messages

### Function Call Depth Exceeded

```
RuntimeErr: Maximum function call depth exceeded: 1000 (limit: 1000)
Function: factorial
Consider using iteration or increasing sys.set_recursion_limit()

Stack trace:
  at factorial (test.q:5)
  at factorial (test.q:5)
  at factorial (test.q:5)
  ... (997 more frames)
```

### Eval Recursion Depth Exceeded

```
RuntimeErr: Maximum evaluation depth exceeded: 2000 (limit: 2000)
Consider simplifying expressions or increasing sys.set_recursion_limit()

This usually occurs with deeply nested expressions or operators.
Try breaking complex expressions into smaller steps.
```

### Module Loading Depth Exceeded

```
ImportErr: Maximum module import depth exceeded: 50 (limit: 50)
Module: deeply/nested/module/path.q
Check for circular imports or deeply nested module chains

Module loading chain:
  main.q
  → lib/level1.q
    → lib/level2.q
      → lib/level3.q
        ... (47 more levels)
```

## Default Limits Rationale

### Function Calls: 1000
- **Reasoning**: Python uses 1000 by default (sys.getrecursionlimit())
- **Covers**: Most legitimate recursive algorithms (factorial, fibonacci, tree traversal)
- **Stack usage**: ~100-500 bytes/frame × 1000 = 100-500KB (safe on all platforms)

### Eval Recursion: 2000
- **Reasoning**: Eval frames are lighter than function calls (no captured scope setup)
- **Covers**: Complex nested expressions, operator chains
- **Stack usage**: Similar to function calls, but each frame is smaller

### Module Loading: 50
- **Reasoning**: 50 levels of nested imports indicates architectural problem
- **Covers**: Reasonable module organization (most projects: 5-10 levels)
- **Stack usage**: Module loading adds 2-3 frames per level (100-150 frames total)

### Combined Safety Margin

Worst case: 50 modules × 3 frames + 1000 functions + 2000 eval = 3150 frames total

At 500 bytes/frame: ~1.5MB stack usage (safe on 1MB Windows stack with headroom)

## Pitfalls and Challenges

### 1. Performance Overhead

**Problem**: Depth checking on every eval/call adds overhead.

**Mitigation**:
- Simple integer comparison (< 5 CPU cycles)
- Only check when limits > 0 (branch prediction friendly)
- Negligible compared to actual evaluation work

**Benchmark target**: < 1% overhead on typical workloads

### 2. Decremented Depth on Error

**Problem**: If evaluation throws an error, must decrement depth correctly.

**Solution**: Use Rust's drop guards or ensure decrements in error paths:

```rust
pub fn eval_pair(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    scope.call_depth += 1;

    // Use a guard to ensure decrement on error
    let _guard = DepthGuard::new(scope);

    // Evaluation (may error)
    match pair.as_rule() {
        // ...
    }
}

struct DepthGuard<'a> {
    scope: &'a mut Scope,
}

impl<'a> DepthGuard<'a> {
    fn new(scope: &'a mut Scope) -> Self {
        DepthGuard { scope }
    }
}

impl<'a> Drop for DepthGuard<'a> {
    fn drop(&mut self) {
        self.scope.call_depth -= 1;
    }
}
```

### 3. Circular Module Imports

**Problem**: Circular imports (A imports B imports A) can cause infinite loops.

**Current state**: Module cache prevents infinite loops (cached modules return immediately)

**Enhancement**: Detect cycles and provide better error message:

```rust
// Track "currently loading" modules to detect cycles
pub struct Scope {
    pub loading_modules: Vec<String>,  // Stack of module paths being loaded
}

// In load_external_module:
if scope.loading_modules.contains(&resolved_path) {
    return import_err!(
        "Circular import detected: {}\nImport chain: {}",
        path,
        scope.loading_modules.join(" → ")
    );
}
```

### 4. Different Limits for Different Contexts

**Problem**: Some contexts legitimately need deeper recursion (e.g., compilers, parsers).

**Solution**: Allow per-context limit overrides:

```quest
# Temporarily increase limit for specific operation
let old = sys.set_recursion_limit(function_calls: 10000)
deep_recursive_operation()
sys.set_recursion_limit(function_calls: old["function_calls"])

# Or use context manager (future)
with sys.recursion_limit(function_calls: 10000)
    deep_recursive_operation()
end
```

### 5. Stack Traces in Errors

**Problem**: Stack traces can be truncated if depth is very large.

**Solution**: Limit stack trace output (already implemented):

```rust
// Show first 10 and last 10 frames with "... N more frames ..." in between
```

## Alternatives Considered

### 1. No Limits (Status Quo)

**Pros**: No overhead, no false positives
**Cons**: Risk of crashes, poor debugging experience
**Decision**: Rejected - safety is more important than avoiding overhead

### 2. Only Native Stack Monitoring

**Pros**: Catches all overflows (even from Rust code)
**Cons**: Platform-specific, complex, higher overhead
**Decision**: Consider for Phase 3, but start with Quest-level tracking

### 3. Trampoline/Continuation-Passing Style

**Pros**: Eliminates recursion entirely (constant stack usage)
**Cons**: Major rewrite of evaluator, performance impact
**Decision**: Rejected - too invasive. Consider for QEP-039 (bytecode interpreter)

### 4. Stack Size Detection at Startup

**Pros**: Can warn users with small stacks
**Cons**: Doesn't prevent overflow, just warns
**Decision**: Complement (not replacement) for depth tracking

## Backwards Compatibility

**Breaking changes**: None by default

**Behavior changes**:
- Programs that previously overflowed the stack will now raise a `RuntimeErr` before crashing
- Programs with > 1000 recursive calls will fail (can be increased)

**Migration path**:
- Most programs unaffected (< 1000 recursion depth)
- Deep recursion users: Edit constants in `src/main.rs` or call `sys.set_recursion_limit()` at runtime
- Test suites: May need to adjust limits for stress tests

**Recommendation**: Ship with limits enabled by default, document in changelog

## Testing Strategy

```quest
use "std/test"
use "std/sys"

test.describe("Stack depth tracking", fun ()
  test.it("tracks function call depth", fun ()
    let depth_at_level = fun (n)
      if n <= 0
        return sys.get_call_depth()
      end
      return depth_at_level(n - 1)
    end

    let depth = depth_at_level(10)
    test.assert_eq(depth, 10)
  end)

  test.it("enforces function call limit", fun ()
    sys.set_recursion_limit(function_calls: 10)

    let infinite = fun (n)
      infinite(n + 1)
    end

    test.assert_raises(RuntimeErr, fun ()
      infinite(0)
    end)
  end)

  test.it("enforces module loading limit", fun ()
    sys.set_recursion_limit(module_loading: 5)

    # Create chain of 10 modules (module_0 → module_1 → ... → module_9)
    # Should fail at depth 5
    test.assert_raises(ImportErr, fun ()
      use "module_chain_10"
    end)
  end)

  test.it("resets depth after error", fun ()
    let depth_before = sys.get_call_depth()

    test.assert_raises(RuntimeErr, fun ()
      sys.set_recursion_limit(function_calls: 5)
      let infinite = fun (n) infinite(n + 1) end
      infinite(0)
    end)

    let depth_after = sys.get_call_depth()
    test.assert_eq(depth_before, depth_after)
  end)

  test.it("allows configuring limits at runtime", fun ()
    let old_limits = sys.set_recursion_limit(function_calls: 5000)
    let limits = sys.get_recursion_limits()
    test.assert_eq(limits["function_calls"], 5000)

    # Restore old limits
    sys.set_recursion_limit(function_calls: old_limits["function_calls"])
  end)

  test.it("provides stack trace on overflow", fun ()
    sys.set_recursion_limit(function_calls: 10)

    fun recursive(n)
      recursive(n + 1)
    end

    try
      recursive(0)
    catch e: RuntimeErr
      let stack = e.stack()
      test.assert(stack.contains("recursive"))
      test.assert_eq(stack.split("\n").len(), 10)
    end
  end)
end)
```

## Performance Expectations

**Overhead targets**:
- Depth increment/decrement: < 5 CPU cycles per call
- Depth check: < 10 CPU cycles per call (single branch + comparison)
- Total overhead: < 1% on typical workloads
- Zero overhead when limits disabled (0 = unlimited)

**Benchmark workloads**:
1. Deep recursion (fibonacci 30): Measure overhead vs. no checking
2. Module loading (50 nested imports): Measure overhead vs. no checking
3. Complex expressions: Measure eval_pair overhead
4. Normal scripts: Ensure < 1% impact on real-world code

## Documentation Updates

### User Documentation

**docs/docs/language/recursion.md** (new):
- Explanation of recursion limits
- How to configure limits
- When to use iteration vs. recursion
- Tail call optimization (not implemented, future)

**docs/docs/stdlib/sys.md**:
- Document `get_call_depth()`
- Document `get_recursion_limits()`
- Document `set_recursion_limit()`
- Examples for common scenarios

**CLAUDE.md**:
- Add section on stack depth tracking
- Document default limits
- Note architecture decision (recursive descent)

### Developer Documentation

**docs/architecture.md** (new):
- Explain eval_pair recursion
- Document DepthGuard pattern
- Platform-specific stack considerations

## Future Enhancements

1. **Tail Call Optimization**: Detect and optimize tail calls to avoid stack growth
2. **Stack usage profiling**: `sys.get_stack_stats()` showing peak usage
3. **Automatic limit tuning**: Detect available stack size and set limits accordingly
4. **Per-function limits**: Decorators like `@max_depth(100)`
5. **Trampoline execution mode**: Opt-in CPS for deeply recursive code
6. **Stack visualization**: Debugging tool to visualize call stack
7. **Native stack monitoring**: Platform-specific APIs for precise tracking

## References

- Python sys.setrecursionlimit(): https://docs.python.org/3/library/sys.html#sys.setrecursionlimit
- Ruby stack level too deep: https://bugs.ruby-lang.org/issues/10449
- JavaScript call stack size: https://2ality.com/2014/04/call-stack-size.html
- Rust stack overflow protection: https://doc.rust-lang.org/std/thread/struct.Builder.html#method.stack_size

## Decision

**Status**: Draft - awaiting review

**Next steps**:
1. Implement Phase 1 (basic depth tracking)
2. Add comprehensive tests for overflow scenarios
3. Benchmark overhead on typical workloads
4. Add sys module API (Phase 2)
5. Document in user guide

**Success criteria**:
- ✅ No stack overflows on reasonable code
- ✅ Clear error messages with actionable advice
- ✅ < 1% performance overhead
- ✅ Easy to configure limits
- ✅ Works across platforms (Windows, Linux, macOS)
