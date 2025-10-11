# QEP-048: Stack Depth Tracking and Recursion Limits

**Status**: Draft
**Created**: 2025-10-11
**Author**: Quest Core Team
**Related**: QEP-037 (Exception System), QEP-039 (Bytecode Interpreter), Bug #019 (Stack Overflow)

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

1. **Stack overflow risk**: Deep module chains or recursion can crash the interpreter (see Bug #019)
2. **No visibility**: Users can't monitor or debug deep call stacks
3. **No limits**: No way to configure maximum recursion depth
4. **Debugging difficulty**: Hard to diagnose "where did my stack go?"
5. **Platform differences**: Stack sizes vary (Linux: 8MB, Windows: 1MB default)
6. **Infinite recursion bugs**: No safety net when evaluator has recursion bugs (Bug #019)

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

**Scenario 5: Nested module method calls (Bug #019)**
```quest
# Infinite recursion bug in evaluator
use "std/test" as test

test.describe("Feature", fun ()
    test.it("case", fun ()     # Nested module method call
        test.assert(true)      # Causes infinite recursion
    end)
end)
```

**Note**: This QEP provides a safety net for both legitimate deep recursion (scenarios 1-4) and evaluator bugs (scenario 5). Even if the interpreter has recursion bugs, depth limits prevent crashes.

## Proposed Changes

### 1. Quest-Level Call Depth Tracking

Track interpreter recursion depth in the `Scope` struct:

```rust
// src/scope.rs
pub struct Scope {
    // ... existing fields ...

    /// Current eval_pair recursion depth
    /// Incremented on every eval_pair() call
    pub eval_depth: usize,

    /// Current module loading depth
    /// Incremented during load_external_module()
    pub module_loading_depth: usize,

    /// Configuration for different depth limits
    pub depth_limits: DepthLimits,
}
```

**Note**: Function call depth is tracked via `scope.call_stack.len()` (already exists).

**Tracking mechanisms explained**:
1. **`scope.eval_depth`**: Tracks `eval_pair()` recursion depth
   - Incremented on every `eval_pair()` entry
   - Used for eval_recursion limit
   - Independent of function calls

2. **`scope.call_stack.len()`**: Tracks user function calls
   - Managed via StackFrame push/pop (existing code)
   - Used for function_calls limit
   - A single function call may result in many eval_pair calls

3. **`scope.module_loading_depth`**: Tracks nested module imports
   - Incremented during `load_external_module()`
   - Used for module_loading limit
   - Separate from call_stack to avoid filtering overhead

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
       scope.eval_depth >= scope.depth_limits.eval_recursion {
        return runtime_err!(
            "Maximum evaluation depth exceeded: {} (limit: {})\nConsider simplifying expressions or increasing sys.set_recursion_limit()",
            scope.eval_depth,
            scope.depth_limits.eval_recursion
        );
    }

    // Use RAII guard to ensure depth is decremented on error/panic
    let _guard = DepthGuard::new(&mut scope.eval_depth);

    // Evaluate (existing code)
    match pair.as_rule() {
        // ... existing evaluation logic ...
    }
}

// RAII guard for exception-safe depth tracking
struct DepthGuard<'a> {
    depth: &'a mut usize,
}

impl<'a> DepthGuard<'a> {
    fn new(depth: &'a mut usize) -> Self {
        *depth += 1;
        DepthGuard { depth }
    }
}

impl<'a> Drop for DepthGuard<'a> {
    fn drop(&mut self) {
        *self.depth -= 1;
    }
}
```

**Why RAII guard?** If evaluation raises an error (via `runtime_err!` macro), the guard's `Drop` implementation ensures `eval_depth` is decremented. This prevents depth counter drift after exceptions.

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
    // Check module loading depth
    if scope.depth_limits.module_loading > 0 &&
       scope.module_loading_depth >= scope.depth_limits.module_loading {
        return import_err!(
            "Maximum module import depth exceeded: {} (limit: {})\nModule: {}\nCheck for circular imports or deeply nested module chains",
            scope.module_loading_depth,
            scope.depth_limits.module_loading,
            path
        );
    }

    // Use RAII guard for module depth tracking
    let _guard = DepthGuard::new(&mut scope.module_loading_depth);

    // Add module frame to call stack (for stack traces)
    scope.call_stack.push(StackFrame::new("<module>".to_string()));

    // Load module (existing code)
    let result = /* ... */;

    // Remove module frame
    scope.call_stack.pop();

    result
}
```

**Note**: We use a dedicated `module_loading_depth` counter instead of filtering `call_stack` for performance. The `call_stack` still gets `<module>` frames for stack traces, but depth checking uses the separate counter.

### 5. Depth Tracking in sys.eval()

**Important**: `sys.eval()` (QEP-018) must inherit the current depth, not reset it.

```rust
// src/stdlib/sys.rs
pub fn sys_eval(code: &str, scope: &mut Scope) -> Result<QValue, String> {
    // Parse code
    let pairs = QuestParser::parse(Rule::program, code)?;

    // Evaluate with CURRENT scope (inherits eval_depth, call_stack, etc.)
    for pair in pairs {
        eval_pair(pair, scope)?;  // Uses current depth counters
    }

    Ok(QValue::Nil)
}
```

**Why inherit depth?** Safer default - prevents eval'd code from bypassing limits:

```quest
# Malicious or buggy code
fun exploit()
    # Try to bypass limits by eval'ing deep recursion
    sys.eval("exploit()")  # Would fail - inherits current depth
end
```

If eval reset depth, it could be used to bypass recursion limits.

### 6. Quest API for Stack Introspection

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

# Set new limits (returns Dict with ALL limits, showing old values)
let old_limits = sys.set_recursion_limit(
    function_calls: 5000,
    eval_recursion: 10000,
    module_loading: 100
)
# Returns: {
#   "function_calls": 1000,      # Old value
#   "eval_recursion": 2000,      # Old value
#   "module_loading": 50         # Old value
# }

# Set individual limit (others unchanged)
sys.set_recursion_limit(function_calls: 5000)
# Returns: {
#   "function_calls": 1000,      # Old value
#   "eval_recursion": 2000,      # Current (unchanged)
#   "module_loading": 50         # Current (unchanged)
# }

# Disable all limits (use with caution!)
sys.set_recursion_limit(
    function_calls: 0,
    eval_recursion: 0,
    module_loading: 0
)

# Disable individual limit
sys.set_recursion_limit(function_calls: 0)  # Only function_calls unlimited

# Get call stack (already exists via exception system)
let stack = sys.get_call_stack()
for frame in stack
    puts(frame["function"] .. " at " .. frame["file"])
end
```

### 7. Configuration via Constants

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
            eval_depth: 0,
            module_loading_depth: 0,
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

### 8. OS Stack Size Monitoring (Advanced)

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

**Solution**: Use RAII DepthGuard pattern (already implemented in sections 2, 4):

```rust
// See section 2 for full DepthGuard implementation
let _guard = DepthGuard::new(&mut scope.eval_depth);
```

The guard's `Drop` trait ensures cleanup on error/panic/return.

### 3. Circular Module Imports

**Problem**: Circular imports (A imports B imports A) can cause infinite loops.

**Current state**: Module cache prevents infinite loops (cached modules return immediately)

**Interaction with module depth tracking**:

Quest's module cache already prevents infinite loops at runtime:
1. First `use "module_a"` → loads module, caches it, then processes
2. If module_a does `use "module_b"` → loads and caches module_b
3. If module_b does `use "module_a"` → returns cached module_a (no recursion)

The `module_loading_depth` counter tracks imports **during initial load only**. Once cached, subsequent imports don't increment depth.

**Enhancement**: Detect cycles **during initial load** for better error messages:

```rust
// Track "currently loading" modules to detect cycles
pub struct Scope {
    pub loading_modules: Vec<String>,  // Stack of module paths being loaded
}

// In load_external_module (before checking cache):
if scope.loading_modules.contains(&resolved_path) {
    return import_err!(
        "Circular import detected: {}\nImport chain: {}",
        path,
        scope.loading_modules.join(" → ")
    );
}

scope.loading_modules.push(resolved_path.clone());
// ... load module ...
scope.loading_modules.pop();
```

This provides clearer error messages than relying on depth limits alone.

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

  test.it("tracks eval and function depth independently", fun ()
    # Test that eval_depth and function_depth are separate

    # Deep expression (uses eval_depth)
    let expr = 1 + 2 + 3  # Nested + operations

    fun recursive(n)
      if n <= 0
        # Evaluate deep expression inside recursion
        return expr + expr + expr + expr
      end
      recursive(n - 1)
    end

    # Should succeed: both depths tracked separately
    # Function calls use call_stack.len()
    # Expression evaluation uses eval_depth
    let result = recursive(100)
    test.assert(result > 0)
  end)

  test.it("sys.eval inherits current depth", fun ()
    # sys.eval should continue from current depth (not reset)
    sys.set_recursion_limit(function_calls: 10)

    fun recursive(n)
      if n <= 0
        # This eval happens at depth ~10
        # Should fail if it tries to recurse more
        sys.eval("recursive(5)")  # Would need depth 15 total
      end
      recursive(n - 1)
    end

    test.assert_raises(RuntimeErr, fun ()
      recursive(9)  # Gets to depth 9, then eval needs 5 more
    end)
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
- Example conversion patterns (see below)

**docs/docs/stdlib/sys.md**:
- Document `get_call_depth()`
- Document `get_recursion_limits()`
- Document `set_recursion_limit()`
- Examples for common scenarios

**CLAUDE.md**:
- Add section on stack depth tracking
- Document default limits
- Note architecture decision (recursive descent)

**Example content for docs/docs/language/recursion.md**:

```markdown
## Common Patterns

### When to Use Iteration vs Recursion

**Use recursion** for:
- Tree/graph traversal (naturally recursive structure)
- Divide-and-conquer algorithms (merge sort, quicksort)
- Backtracking (parsing, game AI)
- Algorithms with depth < 100

**Use iteration** for:
- Simple counting/accumulation
- Array/list processing
- When depth might exceed 100
- When performance is critical (iteration is faster)

### Converting Recursion to Iteration

**Recursive factorial** (may hit limit at n=1000):
```quest
fun factorial(n)
  if n <= 1
    return 1
  end
  return n * factorial(n - 1)
end

factorial(5000)  # RuntimeErr: Maximum function call depth exceeded
```

**Iterative factorial** (no depth limit):
```quest
fun factorial(n)
  let result = 1
  let i = 2
  while i <= n
    result = result * i
    i = i + 1
  end
  return result
end

factorial(5000)  # Works! (returns large number)
```

**Recursive sum** (deep recursion):
```quest
fun sum(arr, index = 0)
  if index >= arr.len()
    return 0
  end
  return arr[index] + sum(arr, index + 1)
end
```

**Iterative sum** (no recursion):
```quest
fun sum(arr)
  let total = 0
  for item in arr
    total = total + item
  end
  return total
end
```

### Configuring Recursion Limits

If you genuinely need deep recursion (e.g., parsing, tree traversal):

```quest
use "std/sys"

# Increase limits for this operation
let old = sys.set_recursion_limit(function_calls: 5000)

# Do deep recursive work
process_deep_tree(root)

# Restore old limits
sys.set_recursion_limit(function_calls: old["function_calls"])
```
```

### Developer Documentation

**docs/architecture.md** (new):
- Explain eval_pair recursion
- Document DepthGuard pattern
- Platform-specific stack considerations

## Future Enhancements

1. **Tail Call Optimization**: Detect and optimize tail calls to avoid stack growth
   - **Interaction with depth tracking**: Tail calls should NOT increment depth counters since they don't consume stack space
   - Requires detecting tail position during eval_pair

2. **Stack usage profiling**: `sys.get_stack_stats()` showing peak usage

3. **Automatic limit tuning**: Detect available stack size and set limits accordingly

4. **Per-function limits**: Decorators like `@max_depth(100)`

5. **Trampoline execution mode**: Opt-in CPS for deeply recursive code

6. **Stack visualization**: Debugging tool to visualize call stack

7. **Native stack monitoring**: Platform-specific APIs for precise tracking

8. **Multi-threading support**: When Quest adds threading, each thread needs separate depth tracking
   - Each thread should get its own `Scope` instance
   - Thread-local depth counters prevent interference
   - Naturally handled if threading uses separate `Scope` per thread

## References

- Python sys.setrecursionlimit(): https://docs.python.org/3/library/sys.html#sys.setrecursionlimit
- Ruby stack level too deep: https://bugs.ruby-lang.org/issues/10449
- JavaScript call stack size: https://2ality.com/2014/04/call-stack-size.html
- Rust stack overflow protection: https://doc.rust-lang.org/std/thread/struct.Builder.html#method.stack_size

## Relationship to Bug #019

**Important Note**: This QEP provides a **safety net** for stack overflows, but does NOT fix the root cause of Bug #019.

**Bug #019**: Infinite recursion bug where user-defined functions calling other user-defined functions causes infinite `eval_pair()` recursion.

**This QEP**: Adds depth limits to prevent stack overflow crashes, converting crashes into `RuntimeErr` exceptions with actionable messages.

**Benefits**:
1. **Immediate relief**: Prevents interpreter crashes, shows helpful error instead
2. **Debugging aid**: Error messages reveal infinite recursion patterns
3. **Long-term safety**: Even after Bug #019 is fixed, protects against future recursion bugs

**Bug #019 must still be fixed** to allow normal function-to-function calls. This QEP is complementary, not a replacement.

## Decision

**Status**: Draft - awaiting review

**Priority**: High - Provides critical safety net while Bug #019 is investigated

**Next steps**:
1. **Implement Phase 1 (basic depth tracking)** - URGENT, helps with Bug #019 diagnosis
2. Add comprehensive tests for overflow scenarios
3. Benchmark overhead on typical workloads
4. Add sys module API (Phase 2)
5. Document in user guide

**Success criteria**:
- ✅ No stack overflows on reasonable code
- ✅ Clear error messages with actionable advice (helps debug Bug #019)
- ✅ < 1% performance overhead
- ✅ Easy to configure limits
- ✅ Works across platforms (Windows, Linux, macOS)
