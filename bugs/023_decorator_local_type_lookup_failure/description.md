# Bug #023: Decorator Type Lookup Fails for Local Types

**Status:** Open
**Severity:** High
**Priority:** P1
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Decorator System / Scope Resolution

---

## Summary

When using `@TypeName.new()` decorator syntax where `TypeName` is defined in the same file, the decorator system fails with "Decorator not found". This prevents users from defining custom decorator types in their own code, forcing all decorators to be imported from the standard library.

---

## Impact

- **Cannot define custom decorators** - All decorators must be in stdlib or imported modules
- **Breaks decorator composition** - Cannot build project-specific decorator patterns
- **Limits decorator system usability** - Decorators are meant to be user-extensible
- **Inconsistent scope resolution** - Other Quest features resolve local types correctly

---

## Current Behavior

```quest
type LogArgs
  func
  fun _call(*args, **kwargs)
    self.func(*args, **kwargs)
  end
  fun _name() self.func._name() end
  fun _doc() self.func._doc() end
  fun _id() self.func._id() end
end

@LogArgs.new()
fun test_func()
  "hello"
end
```

**Error:**
```
Error: Decorator 'LogArgs.new' not found
```

---

## Expected Behavior

Decorators should resolve types from the current scope, just like any other expression:

```quest
type LogArgs
  func
  fun _call(*args, **kwargs)
    puts(f"Calling {self.func._name()}")
    self.func(*args, **kwargs)
  end
  fun _name() self.func._name() end
  fun _doc() self.func._doc() end
  fun _id() self.func._id() end
end

@LogArgs.new()
fun test_func()
  "hello"
end

puts(test_func())
# Output:
# Calling test_func
# hello
```

---

## Root Cause

The decorator resolution system likely:
1. Evaluates decorator expressions during an early phase (parsing or type definition)
2. Only looks in a global decorator registry or imported module scope
3. Doesn't have access to the current file's type definitions

This suggests decorator resolution happens before type definitions are fully registered in the scope.

---

## Reproduction

### Minimal Test Case

```quest
type LogArgs
  func
  fun _call(*args, **kwargs)
    self.func(*args, **kwargs)
  end
  fun _name() self.func._name() end
  fun _doc() self.func._doc() end
  fun _id() self.func._id() end
end

@LogArgs.new()
fun test_func()
  "hello"
end

puts(test_func())
```

**Result:** `Error: Decorator 'LogArgs.new' not found`

### Works: Imported Decorators

```quest
use "std/decorators" as dec
let Timing = dec.Timing

@Timing  # Works - imported from module
fun test_func()
  "hello"
end
```

### Also Fails: Decorator Instance Reuse

```quest
type LogArgs
  func
  # ... methods ...
end

let log1 = LogArgs.new()  # Create instance

@log1  # Also fails - different error (Bug #8)
fun test()
  "test"
end
```

---

## Suggested Fix

Allow decorator expressions to resolve types from the current scope:

### Option 1: Defer Decorator Resolution

Resolve decorator expressions at function definition time, when all types in the file are available:

```rust
// Pseudocode
fn apply_decorators(func: QValue, decorators: Vec<Expr>, scope: &Scope) -> Result<QValue> {
  for decorator_expr in decorators.iter().rev() {
    // Evaluate decorator expression in current scope
    let decorator = eval_expression(decorator_expr, scope)?;
    func = apply_decorator(func, decorator)?;
  }
  Ok(func)
}
```

### Option 2: Two-Phase Processing

1. First pass: Register all type definitions in scope
2. Second pass: Process function definitions and resolve decorators

---

## Workaround

Define decorators in a separate module and import them:

```quest
# decorators.q
type LogArgs
  func
  fun _call(*args, **kwargs)
    self.func(*args, **kwargs)
  end
  # ... other methods ...
end

pub let LogArgs = LogArgs
```

```quest
# main.q
use "./decorators" as dec

@dec.LogArgs.new()
fun test_func()
  "hello"
end
```

**Note:** This workaround is verbose and defeats the purpose of inline decorator definitions.

---

## Related Issues

- **Bug #8:** Decorator instance creation with required fields
- **Fuzz Report Bug #2:** Decorator type lookup fails for local types
- **Fuzz Report Improvement #4:** Allow decorators to reference local types

---

## Test Coverage Required

1. Local type used as decorator with `.new()` ✓
2. Local type stored in variable used as decorator
3. Decorator defined in same file as decorated function
4. Multiple decorators, mix of local and imported
5. Nested decorator calls (decorator returning decorator)
6. Decorator in type definition file (mutual reference)

---

## Acceptance Criteria

- [ ] Decorators can reference types defined in the same file
- [ ] `@TypeName.new()` syntax works for local types
- [ ] Decorator resolution uses same scope rules as other expressions
- [ ] Error messages indicate actual problem (not "not found")
- [ ] All existing decorator tests pass
- [ ] Documentation updated with local decorator examples

---

## Priority Justification

**P1 (High Priority)** because:

1. **Critical for decorator usability** - Users need custom decorators
2. **Breaks expected behavior** - Decorators should use normal scope rules
3. **Blocks real-world usage** - Forces stdlib-only decorators
4. **Clear user pain point** - Reported in fuzz testing
5. **Enables other patterns** - Unblocks Bug #8 (decorator instance reuse)

---

## Notes

- This is a scope resolution issue, not a decorator implementation issue
- The decorator implementation itself appears sound (stdlib decorators work)
- Similar to Bug #8 but different root cause (lookup vs. field initialization)
- May be related to order of evaluation in the AST processing
