# Bug #022: Function Return Value Lost When Returning from Inside Try Block

## Status
**ACTIVE** - Discovered during QEP-056 (Structured Control Flow) implementation

## Summary
When a function executes a `return` statement inside a `try` block, the return value is lost and the function either returns `nil` or continues executing subsequent statements. The `return` is being caught by the `catch` block as if it were an exception, instead of properly propagating as control flow.

## Impact
- **Severity**: HIGH - Breaks basic control flow semantics
- **Scope**: Affects any function with early returns inside try blocks
- **Test Suite**: Causes 2655 → 13 test failures
- **Specific Failure**: `std/conf` module's `load_toml_file()` returns nil, breaking configuration loading

## Steps to Reproduce

### Minimal Example
```quest
fun test_with_try()
    try
        return {success: true}
    catch e
        puts("Error: " .. e.str())
    end
    return {fallback: true}
end

let result = test_with_try()
puts("Result: " .. result.str())
```

**Expected Output**:
```
Result: {success: true}
```

**Actual Output**:
```
Error: ControlFlow::FunctionReturn(Dict(...))
Result: {fallback: true}
```

### Real-World Example
From `lib/std/conf.q`:
```quest
fun load_toml_file(path)
    if not io.exists(path)
        return {}  # ✅ This works correctly
    end

    try
        let content = io.read(path)
        return toml.parse(content)  # ❌ This returns nil
    catch e
        raise ConfigurationErr.new("...")
    end
end
```

Result: Calling `conf.load_module_config()` fails with "AttrErr: Cannot call method 'keys' on nil"

## Root Cause

### Context: QEP-056 Changes
During QEP-056 Step 5, we removed `scope.return_value` dual storage. Return values are now stored ONLY in `ControlFlow::FunctionReturn(val)`. This exposed a latent bug in try/catch handling.

### The Bug
1. Return statement creates `Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(val)))`
2. Try block's `?` operator propagates it: `try_result = Err(EvalError::ControlFlow(...))`
3. **BUG**: The try/catch handler matches on `try_result` and goes to the `Err` arm
4. Code checks `if error_msg.is_control_flow()` and should propagate it (src/main.rs:4641)
5. **BUT**: The debug shows this check never executes - the catch block runs instead

### Expected Behavior
Control flow signals (return, break, continue) should propagate through try/catch blocks transparently, not be caught as exceptions.

## Investigation Notes

### Debug Output
```
[DEBUG load_toml_file] path=quest.toml
[DEBUG load_toml_file] exists=true
[DEBUG call_user_function] About to return, result type=Nil, nil=true  ← Returns nil!

[DEBUG load_toml_file] path=quest.local.toml
[DEBUG load_toml_file] exists=false
[DEBUG load_toml_file] returning {}
[DEBUG load_toml_file] empty_dict created, nil=false
[DEBUG call_user_function] FunctionReturn caught, val type=Dict, nil=false
[DEBUG call_user_function] result set, result type=Dict, nil=false
[DEBUG call_user_function] About to return, result type=Dict, nil=false  ← Returns {} correctly!
```

**Key Observation**:
- Early return from `if` block (line 9-12): ✅ Works
- Early return from `try` block (line 1-3): ❌ Returns nil

### Why the Check Doesn't Execute
The debug statement on line 4640 (`eprintln!("[DEBUG try/catch] Got error...")`) never prints, which means either:
1. The `Err` arm isn't being reached (try_result is somehow Ok)
2. There's a different code path being taken
3. The code is being optimized away (unlikely in --release)

### Related Code
- **src/main.rs:4636-4644** - Try/catch error handling with is_control_flow() check
- **src/function_call.rs:191-226** - Function execution loop with early_return flag
- **src/control_flow.rs:144-146** - is_control_flow() implementation

## Files Changed During QEP-056 (Potentially Related)
- `src/scope.rs` - Removed `return_value` field
- `src/main.rs` - Removed `scope.return_value = Some(val)` assignments
- `src/function_call.rs` - Removed dual storage checks, added early_return flag
- `src/module_loader.rs` - Added top-level return handling

## Workaround
Avoid using `return` statements inside `try` blocks. Move returns outside:

```quest
# Instead of:
fun load_toml_file(path)
    try
        return toml.parse(io.read(path))
    catch e
        raise ConfigurationErr.new(e.str())
    end
end

# Use:
fun load_toml_file(path)
    let result = nil
    try
        result = toml.parse(io.read(path))
    catch e
        raise ConfigurationErr.new(e.str())
    end
    return result
end
```

## Next Steps
1. Add more debug to understand why is_control_flow() check isn't executing
2. Verify that try_result actually contains Err(EvalError::ControlFlow(...))
3. Check if there's an intermediate conversion that's losing the control flow type
4. Fix try/catch to properly propagate control flow signals
5. Add regression test to ensure returns from try blocks work correctly

## Related Issues
- QEP-056: Structured Control Flow
- QEP-037: Typed Exceptions (added try/catch in Quest)

## Discovery Date
2025-10-17

## Discovered By
QEP-056 implementation, specifically Step 5 (removing scope.return_value dual storage)
