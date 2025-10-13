# QEP-048: Stack Depth Tracking

**Status**: Draft
**Created**: 2025-10-11
**Author**: Quest Core Team
**Related**: QEP-037 (Exception System), QEP-039 (Bytecode Interpreter), Bug #019 (Stack Overflow)

## Summary

Add basic stack depth tracking to Quest's interpreter to provide introspection capabilities for monitoring execution depth via `sys.get_call_depth()`.

## Motivation

### Current State

Quest's evaluator uses recursive descent (`eval_pair` calling itself), which directly consumes the OS thread stack. Users have no visibility into current execution depth for debugging or monitoring purposes.

### Problem

**No visibility**: Users can't monitor or introspect current call depth for debugging purposes. When investigating performance issues or understanding execution patterns, there's no way to query "how deep am I in the call stack right now?"

### Use Cases

1. **Debugging recursive algorithms**: Check depth at various points to understand recursion patterns
2. **Performance monitoring**: Track depth in profiling/instrumentation code
3. **Testing**: Verify expected call depth in unit tests
4. **Development tools**: IDEs/debuggers can query depth for visualization

## Proposed Changes

### 1. Basic Depth Tracking in Scope

Add simple depth tracking to the `Scope` struct for introspection only (no enforcement):

```rust
// src/scope.rs
pub struct Scope {
    // ... existing fields ...

    /// Current eval_pair recursion depth (for introspection only)
    pub eval_depth: usize,

    /// Current module loading depth (for introspection only)
    pub module_loading_depth: usize,
}
```

**Note**: Function call depth is already tracked via `scope.call_stack.len()` (existing code).

### 2. Depth Tracking in eval_pair

```rust
// src/main.rs
pub fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    // Use RAII guard to track depth (no checking/enforcement)
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

**Why RAII guard?** Ensures `eval_depth` is always decremented when leaving `eval_pair()`, even on errors or early returns.

### 3. Depth Tracking in Module Loading

```rust
// src/module_loader.rs
pub fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
    // Use RAII guard for module depth tracking (no checking/enforcement)
    let _guard = DepthGuard::new(&mut scope.module_loading_depth);

    // Load module (existing code)
    // ...
}
```

### 4. Quest API for Stack Introspection

```quest
use "std/sys"

# Get current call depth (function calls only)
let depth = sys.get_call_depth()
puts("Current function depth: " .. depth.str())

# Get recursion limits
let limits = sys.get_depth_limits()
puts("Function call limit: " .. limits["function_calls"].str())
puts("Eval recursion limit: " .. limits["eval_recursion"].str())
puts("Module loading limit: " .. limits["module_loading"].str())
```

**Implementation**:
```rust
// src/stdlib/sys.rs

// Returns current function call depth
pub fn sys_get_call_depth(scope: &Scope) -> QValue {
    QValue::Int(scope.call_stack.len() as i64)
}

// Returns dict with recursion limits (hardcoded values)
pub fn sys_get_depth_limits(scope: &Scope) -> QValue {
    let mut dict = HashMap::new();
    dict.insert("function_calls".to_string(), QValue::Int(1000));
    dict.insert("eval_recursion".to_string(), QValue::Int(2000));
    dict.insert("module_loading".to_string(), QValue::Int(50));
    QValue::Dict(Box::new(QDict::new(dict)))
}
```


## Implementation

Single phase - add basic depth tracking:
- Add `eval_depth` and `module_loading_depth` to `Scope` (initialized to 0)
- Add RAII guards in `eval_pair` and `load_external_module`
- Implement `sys.get_call_depth()` and `sys.get_depth_limits()`
- Update documentation

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
    test.assert_gt(depth, 0)  # Should be > 0 in recursive call
  end)

  test.it("returns recursion limits via get_depth_limits", fun ()
    let limits = sys.get_depth_limits()

    # Should return the default limits
    test.assert_eq(limits["function_calls"], 1000)
    test.assert_eq(limits["eval_recursion"], 2000)
    test.assert_eq(limits["module_loading"], 50)
  end)

  test.it("depth increases during recursion", fun ()
    let depths_at_level = []

    let recursive = fun (n)
      depths_at_level.push(sys.get_call_depth())
      if n > 0
        recursive(n - 1)
      end
    end

    recursive(5)

    # Each level should have greater depth than the last
    let i = 1
    while i < depths_at_level.len()
      test.assert_gt(depths_at_level[i], depths_at_level[i - 1])
      i = i + 1
    end
  end)
end)
```

## Performance Expectations

**Overhead**: Minimal - just integer increment/decrement operations using RAII guards
- Depth increment/decrement: < 5 CPU cycles per call
- No conditionals or checks in hot path
- Target: < 0.5% overhead on typical workloads

## Documentation Updates

**docs/docs/stdlib/sys.md**:
- Document `sys.get_call_depth()` - returns current function call depth as Int
- Document `sys.get_depth_limits()` - returns Dict with recursion depth limits
  - Keys: `function_calls`, `eval_recursion`, `module_loading`
- Examples for debugging and monitoring use cases

## Future Enhancements

1. **Peak depth tracking**: Track maximum depth reached during execution
2. **Stack usage profiling**: `sys.get_stack_stats()` showing peak/average usage
3. **Recursion limits with enforcement**: Add actual depth limits if needed (separate QEP)
4. **Native stack monitoring**: Platform-specific APIs for precise OS stack tracking

## Decision

**Status**: Draft - minimal scope

**Priority**: Low - introspection only, not critical

**Scope**: Basic depth tracking for debugging/monitoring only. No enforcement, no limits, no error handling.

**Success criteria**:
- ✅ Can query current depth via `sys.get_call_depth()`
- ✅ Can query depth limits via `sys.get_depth_limits()`
- ✅ < 0.5% performance overhead
- ✅ Accurate depth tracking with RAII guards
