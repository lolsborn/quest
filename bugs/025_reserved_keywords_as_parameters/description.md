# Bug #025: Reserved Keywords Cannot Be Used as Parameter Names

**Status:** Open
**Severity:** Medium
**Priority:** P2
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Parser / Keywords

---

## Summary

Reserved keywords like `step`, `end`, `in`, `to`, `until` cannot be used as parameter names, causing confusing parse errors. The error messages don't mention that the identifier is a reserved keyword or suggest alternatives, making it difficult for users to understand what went wrong.

---

## Impact

- **Confusing errors** - Generic "expected parameter" error doesn't explain the real problem
- **Surprising behavior** - Common parameter names like `start`, `end`, `step` are unexpectedly invalid
- **Poor developer experience** - Users must guess which words are reserved
- **No clear documentation** - No comprehensive list of reserved keywords

---

## Current Behavior

```quest
fun make_range(start, step = 1)
  start + step
end
```

**Error:**
```
Parse error:  --> 1:23
  |
1 | fun make_range(start, step = 1)
  |                       ^---
  |
  = expected parameter, varargs, or kwargs
```

Similar error for `end`:

```quest
fun make_range(start, end = 10)
  start + end
end
```

**Error:**
```
Parse error:  --> 1:23
  |
1 | fun make_range(start, end = 10)
  |                       ^---
  |
  = expected parameter, varargs, or kwargs
```

---

## Expected Behavior

### Option 1: Contextual Keywords (Recommended)

Allow keywords to be used as identifiers in contexts where they're unambiguous:

```quest
# 'step' and 'end' are only keywords in specific contexts
fun make_range(start, end = 10, step = 1)
  # 'end' keyword only matters for block termination
  start + end + step
end
```

This approach is used by many modern languages (Rust, Python with soft keywords, etc.)

### Option 2: Better Error Messages

If contextual keywords are too complex, at least provide helpful error messages:

```
Parse error: 'step' is a reserved keyword and cannot be used as a parameter name
       --> 1:23
         |
       1 | fun make_range(start, step = 1)
         |                       ^---
         |
       Suggestion: Use an alternative name like 'increment', 'stride', or 'delta'
```

---

## Known Reserved Keywords

Based on testing and documentation:

- `end` - Block terminator
- `step` - Range step (match patterns, for loops)
- `in` - Membership test, for loops, match patterns
- `to` - Range operator (inclusive)
- `until` - Range operator (exclusive)
- `if`, `elif`, `else` - Conditionals
- `fun` - Function declaration
- `let`, `const` - Variable declaration
- `type`, `trait`, `impl` - Type system
- `pub` - Visibility modifier
- `match` - Pattern matching
- `while`, `for` - Loops
- `try`, `catch`, `ensure`, `raise` - Exceptions
- `with`, `as` - Imports and context managers
- `use` - Module imports
- `and`, `or`, `not` - Logical operators
- `true`, `false`, `nil` - Literals
- `return`, `break`, `continue` - Flow control

**Note:** This list should be documented in the official documentation.

---

## Root Cause

The parser treats these words as globally reserved keywords rather than context-sensitive keywords. This is simpler to implement but less flexible for users.

---

## Reproduction

### Minimal Test Cases

```quest
# Fails: 'step' as parameter
fun make_range(start, step = 1)
  start + step
end

# Fails: 'end' as parameter
fun make_range(start, end = 10)
  start + end
end

# Works: Alternative names
fun make_range(start, finish = 10, increment = 1)
  start + finish + increment
end
```

---

## Suggested Fix

### Option 1: Implement Contextual Keywords

Modify the parser to allow keywords as identifiers in parameter positions:

```pest
// In quest.pest
parameter = { contextual_ident ~ (":" ~ type_annotation)? ~ default_value? }

contextual_ident = {
  // Allow keywords that can't be confused in this context
  (!"fun" ~ !"let" ~ !"const" ~ !"type" ~ keyword)
  | ident
}
```

### Option 2: Improve Error Messages

Add better error detection and messages:

```rust
// In parser error handling
if is_reserved_keyword(token) {
  return Err(format!(
    "'{}' is a reserved keyword and cannot be used as a parameter name\n\
     Suggestion: Use an alternative like '{}'",
    token,
    suggest_alternative(token)
  ));
}
```

---

## Workarounds

Use alternative parameter names:

| Reserved | Alternatives |
|----------|--------------|
| `step` | `increment`, `stride`, `delta` |
| `end` | `finish`, `stop`, `limit` |
| `in` | `input`, `inside`, `included` |
| `to` | `dest`, `target`, `until_val` |

---

## Related Issues

- **Fuzz Report Bug #5:** Reserved keyword `step` cannot be used as parameter
- **Fuzz Report Bug #6:** Reserved keyword `end` cannot be used as parameter
- **Fuzz Report Improvement #5:** Support contextual keywords
- **Fuzz Report Improvement #9:** Better error messages for reserved keywords

---

## Test Coverage Required

1. All reserved keywords rejected as parameters ✓
2. Error messages mention keyword status
3. Error messages suggest alternatives
4. Alternative names work correctly
5. Keywords still work in their intended contexts

If contextual keywords implemented:
6. Keywords work as parameter names
7. Keywords still reserved in original contexts
8. Ambiguous cases handled correctly

---

## Acceptance Criteria

### Minimum (Option 2):
- [ ] Error messages identify reserved keywords
- [ ] Error messages suggest alternatives
- [ ] Documentation lists all reserved keywords
- [ ] All existing tests pass

### Ideal (Option 1):
- [ ] Context-sensitive keyword parsing
- [ ] Common parameter names (step, end) work
- [ ] Keywords still reserved in original contexts
- [ ] Clear documentation of behavior
- [ ] All existing tests pass

---

## Priority Justification

**P2 (Medium Priority)** because:

1. **Developer experience impact** - Frustrating error messages
2. **Common use case** - Range/iteration functions naturally use these names
3. **Easy improvement** - Better errors can be added quickly
4. **Not blocking** - Workaround available (rename parameters)
5. **Documentation gap** - Should document reserved words regardless

---

## Notes

- Python uses contextual keywords for `match` and `case` (added in 3.10)
- Rust has contextual keywords (e.g., `union` is only reserved in some contexts)
- Even if contextual keywords aren't implemented, better error messages are essential
- This affects user-facing API design (libraries must avoid these parameter names)
