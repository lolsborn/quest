# Bug #027: Nil Does Not Support `.cls()` Method

**Status:** Open
**Severity:** Low
**Priority:** P3
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Type System / Nil Handling

---

## Summary

While most types support the `.cls()` method to get their class name, `nil` does not. Attempting to call `.cls()` on nil raises an error. This creates a minor API inconsistency.

---

## Impact

- **API inconsistency** - Other types support `.cls()`, nil doesn't
- **Low practical impact** - `== nil` is the standard way to check for nil
- **Affects generic code** - Code that calls `.cls()` on arbitrary values will fail on nil
- **Minor inconvenience** - Easy to work around

---

## Current Behavior

```quest
let x = nil
puts(x.cls())
```

**Error:**
```
AttrErr: Cannot call method 'cls' on nil
```

Compare with other types:

```quest
puts(5.cls())        # Int
puts("hello".cls())  # Str
puts([].cls())       # Array
puts({}.cls())       # Dict
puts(true.cls())     # Bool
```

---

## Expected Behavior

### Option A: Support `.cls()` on Nil

```quest
let x = nil
puts(x.cls())  # Should print: Nil
```

### Option B: Document Nil as Special Case

Make it clear that nil is a special singleton value that doesn't support method calls:

```quest
let x = nil

# Recommended: Use equality check
if x == nil
  puts("Value is nil")
end

# Or: Use .is() method (if implemented)
if x.is(Nil)
  puts("Value is nil")
end

# Not supported: Method calls on nil
# x.cls()  # Error: Cannot call methods on nil
```

---

## Root Cause

Nil is implemented as a special singleton value (`QValue::Nil`) that doesn't go through the normal method dispatch system. Most types implement methods via the `QObj` trait, but nil appears to be handled specially.

---

## Reproduction

### Minimal Test Case

```quest
let x = nil
puts(x.cls())
```

**Result:** `AttrErr: Cannot call method 'cls' on nil`

### Works: Other Types

```quest
puts(5.cls())        # Int - works
puts("hello".cls())  # Str - works
puts(true.cls())     # Bool - works
```

### Workaround: Equality Check

```quest
let x = nil
if x == nil
  puts("It's nil")
end
```

---

## Suggested Fix

### If Option A (Support `.cls()`):

Add `.cls()` method to nil:

```rust
// In method dispatch
fn call_method_on_value(value: &QValue, method: &str, args: &[QValue]) -> Result<QValue> {
  match value {
    QValue::Nil => {
      match method {
        "cls" => Ok(QValue::Str("Nil".to_string())),
        _ => Err(AttrErr::new("Cannot call methods on nil"))
      }
    }
    // ... other types
  }
}
```

### If Option B (Document Only):

Update documentation to clarify nil's special status:

```markdown
**Nil**: Singleton value representing absence of a value. Nil is special:
- Cannot call methods on nil (use `== nil` or `.is()` for checks)
- Nil is falsy in boolean contexts
- Nil has ID 0
```

---

## Related Issues

- **Fuzz Report Bug #10:** Nil does not support `.cls()` method
- **Fuzz Report Improvement #19:** Consider `.is(Nil)` support

---

## Test Coverage Required

1. `.cls()` on nil (currently fails) ✓
2. If implemented: `.cls()` returns "Nil"
3. Other methods on nil still fail appropriately
4. Nil equality checks work (`== nil`)
5. Generic code handling arbitrary types

---

## Acceptance Criteria

### If Option A (Implement `.cls()`):
- [ ] `nil.cls()` returns "Nil" string
- [ ] Other methods on nil still fail
- [ ] Documentation updated
- [ ] Tests cover nil.cls()
- [ ] All existing tests pass

### If Option B (Document only):
- [ ] Documentation clarifies nil doesn't support methods
- [ ] Examples show correct nil checking patterns
- [ ] Error message remains clear
- [ ] No code changes needed

---

## Priority Justification

**P3 (Low Priority)** because:

1. **Very low practical impact** - `== nil` is the standard pattern
2. **Edge case** - Rarely needed in practice
3. **Easy workaround** - Equality check works fine
4. **API polish** - Not a critical inconsistency
5. **Other priorities higher** - Parser and decorator issues more urgent

---

## Recommendation

**Option B** (Document as special case):
- Nil is already special in many ways (singleton, ID 0, falsy)
- Adding method dispatch for one method is overkill
- Standard pattern (`== nil`) works perfectly
- Keeps nil implementation simple
- Document clearly that nil doesn't support method calls

---

## Notes

- Python's `None` doesn't have a `.cls()` equivalent (would use `type(None).__name__`)
- Ruby's `nil.class` returns `NilClass`
- JavaScript's `null` has no methods (would throw TypeError)
- Most languages treat nil/null/None as special
- Quest's `== nil` pattern is clean and sufficient
