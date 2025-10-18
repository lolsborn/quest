# Bug #026: Exception `.type()` Returns Type Object Instead of String

**Status:** Open
**Severity:** Low
**Priority:** P3
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Exception System / API Consistency

---

## Summary

The `.type()` method on exception objects returns a Type object instead of a string, making string comparisons fail. This is inconsistent with common patterns in other languages where exception type checking uses strings.

---

## Impact

- **Confusing API** - `.type()` displays as "ValueErr" but isn't equal to the string "ValueErr"
- **Makes programmatic type checking awkward** - Must compare Type objects or use typed catch blocks
- **Low practical impact** - Typed catch blocks are the preferred pattern anyway
- **API inconsistency** - Users expect `.type()` to return a string

---

## Current Behavior

```quest
try
  raise ValueErr.new("test")
catch e: ValueErr
  let t = e.type()
  puts(t)  # Prints: ValueErr

  if t == "ValueErr"  # FAILS - Type != String
    puts("String match works")
  else
    puts("Not a string - it's a Type object")
  end
end
```

**Output:**
```
ValueErr
Not a string - it's a Type object
```

---

## Expected Behavior

### Option A: Make `.type()` Return String

```quest
try
  raise ValueErr.new("test")
catch e: ValueErr
  let t = e.type()
  puts(t)  # Prints: ValueErr (as string)

  if t == "ValueErr"  # Works - string comparison
    puts("String match works")
  end
end
```

### Option B: Add `.type_name()` Method

Keep `.type()` returning Type object, add new method for string:

```quest
try
  raise ValueErr.new("test")
catch e: ValueErr
  let t_obj = e.type()      # Type object
  let t_str = e.type_name() # "ValueErr" string

  if t_str == "ValueErr"    # Works
    puts("String match works")
  end
end
```

### Option C: Document Current Behavior

Make it clear that `.type()` returns a Type object and typed catch blocks are preferred:

```quest
# Recommended pattern - typed catch
try
  risky_operation()
catch e: ValueErr
  # Handle value errors
catch e: IndexErr
  # Handle index errors
catch e: Err
  # Catch all others
end

# If you need the type for logging
try
  risky_operation()
catch e: Err
  # Use ._str() or string interpolation
  puts(f"Error type: {e.type()}")
end
```

---

## Root Cause

Exception objects store their type as a Type object internally. The `.type()` method returns this Type object directly rather than converting it to a string.

---

## Reproduction

### Minimal Test Case

```quest
try
  raise ValueErr.new("test")
catch e: ValueErr
  let t = e.type()
  puts(t)
  if t == "ValueErr"
    puts("String match works")
  else
    puts("Not a string - it's a Type object")
  end
end
```

**Output:**
```
ValueErr
Not a string - it's a Type object
```

---

## Current Workaround

Use typed catch blocks instead of string comparisons:

```quest
try
  risky_operation()
catch e: ValueErr
  # Type checking done by catch
  handle_value_error(e)
catch e: IndexErr
  handle_index_error(e)
catch e: Err
  handle_generic_error(e)
end
```

For logging, use string interpolation which calls the Type's display method:

```quest
try
  risky_operation()
catch e: Err
  puts(f"Error type: {e.type()}")  # Works - interpolation handles Type
end
```

---

## Suggested Fix

### Recommended: Option B (Add `.type_name()`)

This preserves backward compatibility while adding the convenience method:

```rust
impl Exception {
  // Existing - returns Type object
  fn type(&self) -> QValue {
    QValue::Type(self.exception_type.clone())
  }

  // NEW - returns string
  fn type_name(&self) -> QValue {
    QValue::Str(self.exception_type.name().to_string())
  }
}
```

### Alternative: Option A (Change `.type()` to return string)

More intuitive but potentially breaking:

```rust
impl Exception {
  fn type(&self) -> QValue {
    QValue::Str(self.exception_type.name().to_string())
  }
}
```

**Breaking change assessment:** Low risk since:
- Typed catch blocks are the documented pattern
- Direct `.type()` usage is uncommon
- Could add deprecation warning first

---

## Related Issues

- **Fuzz Report Bug #7:** Exception `.type()` returns Type object instead of string
- **Fuzz Report Improvement #17:** Add `.type_name()` method to exceptions
- **Fuzz Report Improvement #16:** Document exception object methods

---

## Test Coverage Required

1. `.type()` behavior (current or changed) ✓
2. If Option B: `.type_name()` returns string
3. String comparisons work as expected
4. Typed catch blocks still work (must not break)
5. Exception hierarchy reflection works
6. Type object methods available if `.type()` returns Type

---

## Acceptance Criteria

### If Option A (Change to string):
- [ ] `.type()` returns string like "ValueErr"
- [ ] String comparisons work
- [ ] Documentation updated
- [ ] All existing tests updated
- [ ] Deprecation period if needed

### If Option B (Add `.type_name()`):
- [ ] `.type()` still returns Type object (unchanged)
- [ ] New `.type_name()` returns string
- [ ] Documentation clarifies both methods
- [ ] Examples show `.type_name()` usage
- [ ] All existing tests pass

### If Option C (Document only):
- [ ] Documentation clarifies `.type()` returns Type
- [ ] Examples show typed catch pattern
- [ ] Examples show string interpolation for logging
- [ ] No code changes needed

---

## Priority Justification

**P3 (Low Priority)** because:

1. **Low practical impact** - Typed catch blocks work perfectly
2. **Workaround exists** - String interpolation for logging
3. **API polish** - Not a blocker, just a convenience
4. **Documentation fix possible** - Can clarify expected usage
5. **Other priorities higher** - Parser and decorator issues more urgent

---

## Recommendation

**Implement Option B** (add `.type_name()` method):
- Preserves backward compatibility
- Adds convenience for users who need strings
- Documents both patterns clearly
- Low implementation cost
- No breaking changes

---

## Notes

- Python's exception system has `type(e).__name__` returning string
- Ruby's exception system has `e.class.name` returning string
- JavaScript's `Error` has `.name` property as string
- Most languages prefer strings for exception type identification
- Quest's typed catch blocks are actually more elegant than string checking
