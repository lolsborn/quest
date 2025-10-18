# Bug #024: Lambdas Don't Support **kwargs

**Status:** Open
**Severity:** Medium
**Priority:** P2
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Lambda Evaluation / Parameter Handling

---

## Summary

Lambda functions cannot accept `**kwargs` parameter even though regular functions fully support it. The lambda parses successfully but fails at runtime with "Unknown keyword arguments" error. This creates an inconsistency between lambda and function capabilities.

---

## Impact

- **Limits functional programming patterns** - Cannot create higher-order functions that accept arbitrary keyword arguments
- **Lambda/function parity gap** - Users expect feature parity between `fun` functions and `fun` lambdas
- **Breaks decorator patterns** - Cannot write lambda-based decorator wrappers
- **Confusing behavior** - Parses without error but fails at runtime

---

## Current Behavior

```quest
let lambda_kwargs = fun (**opts)
  opts.len()
end

puts(lambda_kwargs(a: 1, b: 2, c: 3))
```

**Error:**
```
ArgErr: Unknown keyword arguments: b, c, a
```

---

## Expected Behavior

Lambdas should support `**kwargs` just like regular functions:

```quest
let lambda_kwargs = fun (**opts)
  opts.len()
end

puts(lambda_kwargs(a: 1, b: 2, c: 3))  # Should print: 3

# Common use case: lambda decorator wrapper
let with_logging = fun (func)
  fun (*args, **kwargs)
    puts(f"Calling function")
    func(*args, **kwargs)
  end
end
```

---

## Root Cause

The lambda evaluation code is missing the `**kwargs` handling logic that exists for regular functions. This appears to be a runtime evaluation issue, not a parser issue (since the lambda parses successfully).

Likely location: Lambda evaluation in parameter binding phase.

---

## Reproduction

### Minimal Test Case

```quest
let lambda_kwargs = fun (**opts)
  opts.len()
end

puts(lambda_kwargs(a: 1, b: 2, c: 3))
```

**Result:** `ArgErr: Unknown keyword arguments: b, c, a`

### Works: Regular Functions

```quest
fun func_kwargs(**opts)
  opts.len()
end

puts(func_kwargs(a: 1, b: 2, c: 3))  # Works: prints 3
```

### Works: Other Lambda Features

```quest
# *args works in lambdas
let lambda_varargs = fun (*args)
  args.len()
end
puts(lambda_varargs(1, 2, 3))  # Works: prints 3

# Default params work in lambdas
let lambda_default = fun (x = 5)
  x
end
puts(lambda_default())  # Works: prints 5

# Named args work in lambdas (receiving side)
let lambda_named = fun (a, b)
  a + b
end
puts(lambda_named(a: 1, b: 2))  # Works: prints 3
```

---

## Suggested Fix

Add `**kwargs` support to lambda evaluation. The implementation should mirror the regular function parameter handling:

```rust
// Pseudocode for lambda evaluation
fn eval_lambda_call(lambda: &QLambda, args: &[QValue], kwargs: &HashMap<String, QValue>) -> Result<QValue> {
  // ... existing parameter binding ...

  // NEW: Handle **kwargs if lambda has kwargs parameter
  if let Some(kwargs_param) = &lambda.kwargs_param {
    // Collect remaining kwargs into a dict
    let kwargs_dict = QDict::from_hashmap(remaining_kwargs);
    scope.set(kwargs_param, kwargs_dict);
  }

  // Execute lambda body
  eval_body(&lambda.body, &scope)
}
```

---

## Test Coverage Required

1. Lambda with `**kwargs` only ✓
2. Lambda with required params + `**kwargs`
3. Lambda with default params + `**kwargs`
4. Lambda with `*args` + `**kwargs`
5. Lambda with all parameter types: required, default, `*args`, `**kwargs`
6. Nested lambdas with `**kwargs`
7. Lambda stored and called later
8. Lambda as decorator wrapper (higher-order function pattern)

---

## Acceptance Criteria

- [ ] Lambdas accept `**kwargs` parameter
- [ ] Keyword arguments collected into dict
- [ ] Works with other parameter types (required, default, `*args`)
- [ ] Parameter ordering rules enforced (required → default → `*args` → `**kwargs`)
- [ ] Error messages consistent with function behavior
- [ ] All existing lambda tests pass

---

## Priority Justification

**P2 (Medium Priority)** because:

1. **Feature completeness** - Lambda/function parity expected
2. **Enables functional patterns** - Higher-order functions, decorators
3. **Clear implementation path** - Copy logic from regular functions
4. **Relatively isolated change** - Lambda evaluation only
5. **Not blocking** - Workaround exists (use regular functions)

---

## Related Issues

- **Fuzz Report Bug #4:** Lambdas don't support `**kwargs`
- **Fuzz Report Improvement #2:** Support `**kwargs` in lambda functions
- **QEP-034 Phase 2:** Keyword arguments (`**kwargs`)

---

## Workaround

Use regular functions instead of lambdas when `**kwargs` is needed:

```quest
# Instead of:
# let make_config = fun (**opts) opts end

# Use:
fun make_config(**opts)
  opts
end

let config = make_config(host: "localhost", port: 8080)
```

---

## Notes

- Parser already supports `**kwargs` syntax in lambdas (no parse error)
- This is purely a runtime evaluation gap
- Regular functions have complete `**kwargs` implementation
- Fuzz testing confirms regular function `**kwargs` works flawlessly
