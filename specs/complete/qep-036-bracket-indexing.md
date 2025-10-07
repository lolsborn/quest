# QEP-036: Bracket Indexing for Strings and Bytes

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Related:** Bug #004

## Abstract

This QEP proposes adding bracket indexing syntax (`[]`) support for `Str` and `Bytes` types to provide a consistent indexing API across all indexable types in Quest.

## Motivation

### Current State

Quest currently supports bracket indexing for **Arrays** and **Dicts** only:

```quest
# ✓ Works - Array indexing
let arr = [1, 2, 3]
puts(arr[0])        # → 1

# ✓ Works - Dict indexing
let dict = {"x": 10, "y": 20}
puts(dict["x"])     # → 10
```

**But NOT for Strings or Bytes:**

```quest
# ✗ Error: Cannot index into type Str
let s = "hello"
puts(s[0])          # Should return "h"

# ✗ Error: Cannot index into type Bytes
let b = b"hello"
puts(b[0])          # Should return 104 (byte value)
```

### Current Workarounds

Users must use different methods for each type:

```quest
# String: use slice()
let s = "hello"
puts(s.slice(0, 1))     # → "h" (returns substring)

# Bytes: use get()
let b = b"hello"
puts(b.get(0))          # → 104 (returns int)
```

### Problems This Causes

1. **Inconsistent API**: Similar operations require different syntax
2. **Cognitive overhead**: Must remember which method works for which type
3. **Less readable code**: `s.slice(0, 1)` is more verbose than `s[0]`
4. **Violates principle of least surprise**: Users expect `[]` to work on all indexable types

## Proposal

Add bracket indexing support for `Str` and `Bytes` types:

### String Indexing

```quest
let s = "hello"
puts(s[0])          # → "h" (returns single-char string)
puts(s[1])          # → "e"
puts(s[-1])         # → "o" (negative indexing from end)
puts(s[10])         # → Error: Index out of bounds
```

**Behavior:**
- Returns a single-character string (not a char code)
- Supports negative indexing (Python-style)
- Raises error on out-of-bounds access
- UTF-8 aware: indexes by Unicode code points (scalar values), not bytes or grapheme clusters
- **Performance note**: O(n) operation due to UTF-8 variable-width encoding

### Bytes Indexing

```quest
let b = b"hello"
puts(b[0])          # → 104 (returns int, ASCII 'h')
puts(b[1])          # → 101 (ASCII 'e')
puts(b[-1])         # → 111 (ASCII 'o', negative indexing)
puts(b[10])         # → Error: Index out of bounds
```

**Behavior:**
- Returns an integer (byte value 0-255)
- Supports negative indexing
- Raises error on out-of-bounds access
- Operates on raw bytes (not UTF-8 aware)

## Design Decisions

### Return Types

**Strings return strings, bytes return integers:**

```quest
"hello"[0]      # → "h" (Str type)
b"hello"[0]     # → 104 (Int type)
```

**Rationale:**
- Consistent with `.slice()` (returns string) and `.get()` (returns int)
- Strings are immutable sequences of characters, not integers
- Bytes are raw data, naturally represented as integers
- Matches common patterns in other languages (Python, Ruby)

### UTF-8 Handling

String indexing operates on **Unicode code points** (scalar values), not bytes or grapheme clusters:

```quest
let s = "hello世界"
puts(s[5])          # → "世" (Chinese character, single code point)
puts(s[6])          # → "界"
puts(s.len())       # → 7 (code point count)

# Combining characters count as separate code points
let s2 = "café"     # If 'é' is e + combining accent (2 code points)
puts(s2.len())      # → 5 (c, a, f, e, combining-acute)
puts(s2[3])         # → "e" (base character)
puts(s2[4])         # → "\u{0301}" (combining acute accent)

# Emoji with modifiers are multiple code points
let s3 = "👨‍👩‍👧‍👦"   # Family emoji (7 code points via ZWJ)
puts(s3.len())      # → 7 (not 1 grapheme cluster)
puts(s3[0])         # → "👨" (man emoji, first code point)
```

**Note**: This follows Python/JavaScript conventions. Code points are NOT the same as grapheme clusters (user-perceived characters). For grapheme-aware operations, use string methods like `.graphemes()`.

For byte-level access to UTF-8 strings:

```quest
let s = "hello世界"
let bytes = s.bytes()
puts(bytes[5])      # → Byte value of first byte in "世"
```

### Negative Indexing

Both types support negative indexing from the end:

```quest
"hello"[-1]         # → "o" (last character)
"hello"[-2]         # → "l"
b"hello"[-1]        # → 111 (last byte)
```

### Out-of-Bounds Behavior

Both types raise errors on invalid indices:

```quest
"hello"[10]         # Error: String index out of bounds: 10 (valid: 0..4 or -5..-1)
b"hello"[10]        # Error: Bytes index out of bounds: 10 (valid: 0..4 or -5..-1)
"hello"[-10]        # Error: String index out of bounds: -10 (valid: 0..4 or -5..-1)
""[0]               # Error: String index out of bounds: 0 (string is empty)
```

**Rationale:**
- Consistent with Array behavior (raises errors, not `nil`)
- Fails fast instead of returning `nil`
- Prevents silent bugs from invalid indices
- Error messages include valid range for debugging

**Note**: This differs from `.get()` method which returns `nil` on invalid indices. Use `.get()` when `nil` fallback is desired.

## Implementation

### Parser Changes

The parser already supports bracket indexing via the `index` rule in `quest.pest`. No grammar changes needed.

### Evaluator Changes

In `src/main.rs`, modify the `Rule::index` handling to support `QValue::Str` and `QValue::Bytes`:

```rust
Rule::index => {
    // ... existing Array and Dict handling ...

    // Add String indexing
    QValue::Str(s) => {
        let idx = normalize_index(index_val, s.chars().count())?;
        let ch = s.chars().nth(idx)
            .ok_or_else(|| format!("String index out of bounds: {}", original_idx))?;
        QValue::Str(ch.to_string())
    }

    // Add Bytes indexing
    QValue::Bytes(b) => {
        let idx = normalize_index(index_val, b.len())?;
        let byte = b.get(idx)
            .ok_or_else(|| format!("Bytes index out of bounds: {}", original_idx))?;
        QValue::Int(*byte as i64)
    }
}
```

Helper function for negative indexing:

```rust
fn normalize_index(idx: i64, len: usize, type_name: &str) -> Result<usize, String> {
    if idx < 0 {
        let abs_idx = idx.abs() as usize;
        if abs_idx > len {
            return Err(format!(
                "{} index out of bounds: {} (valid: 0..{} or -{}..{})",
                type_name, idx, len.saturating_sub(1), len, -1
            ));
        }
        Ok(len - abs_idx)
    } else {
        let idx_usize = idx as usize;
        if idx_usize >= len {
            return Err(format!(
                "{} index out of bounds: {} (valid: 0..{} or -{}..{})",
                type_name, idx, len.saturating_sub(1), len, -1
            ));
        }
        Ok(idx_usize)
    }
}
```

**Index Type Validation:**

Only `Int` types are valid indices. Other types raise errors:

```rust
let index_val = match eval_pair(index_pair, variables)? {
    QValue::Int(i) => i,
    QValue::BigInt(ref n) => {
        // Convert to i64, error if too large
        n.to_i64().ok_or_else(|| "Index too large (must fit in Int)".to_string())?
    }
    other => return Err(format!("Index must be Int, got: {}", other.q_type())),
};
```

## Examples

### Basic Usage

```quest
# String indexing
let name = "Alice"
puts(name[0])           # → "A"
puts(name[4])           # → "e"
puts(name[-1])          # → "e"

# Bytes indexing
let data = b"\x48\x65\x6C\x6C\x6F"  # "Hello" in hex
puts(data[0])           # → 72 (0x48, 'H')
puts(data[-1])          # → 111 (0x6F, 'o')
```

### Iteration Pattern

```quest
# Before: Using slice
let s = "hello"
let i = 0
while i < s.len()
    puts(s.slice(i, i + 1))
    i = i + 1
end

# After: Using bracket indexing
let s = "hello"
let i = 0
while i < s.len()
    puts(s[i])
    i = i + 1
end
```

**Performance Warning**: String indexing is O(n) per access due to UTF-8 encoding. For full iteration, prefer `.chars()` iterator:

```quest
# Preferred for full iteration: O(n) total
for ch in "hello".chars()
    puts(ch)
end

# Avoid: O(n²) due to repeated scanning
let i = 0
while i < "hello".len()
    puts("hello"[i])  # Each access scans from start
    i = i + 1
end
```

### Checking First/Last Characters

```quest
# Before
fun starts_with(s, prefix)
    s.slice(0, prefix.len()) == prefix
end

# After (simplified first char check)
fun is_uppercase_first(s)
    s.len() > 0 and s[0] == s[0].upper()
end

fun get_extension(filename)
    let i = filename.len() - 1
    while i >= 0
        if filename[i] == "."
            return filename.slice(i + 1, filename.len())
        end
        i = i - 1
    end
    return ""
end
```

### Byte-Level Operations

```quest
# Parse binary protocol header
let header = b"\x00\x01\x02\x03"
let version = header[0]
let flags = header[1]
let length = header[2] * 256 + header[3]

puts(f"Version: {version}, Flags: {flags}, Length: {length}")
```

## Backwards Compatibility

This change is **100% backwards compatible**:
- Adds new functionality without breaking existing code
- `.slice()` and `.get()` methods remain available
- No changes to existing behavior

## Mutation and Assignment

Bracket indexing is **read-only**. Strings and bytes are immutable in Quest:

```quest
let s = "hello"
s[0] = "H"          # ✗ Error: Cannot assign to string index

let b = b"hello"
b[0] = 72           # ✗ Error: Cannot assign to bytes index

# Arrays support assignment (already implemented)
let arr = [1, 2, 3]
arr[0] = 99         # ✓ Works - arrays are mutable
```

For string modifications, use string methods:

```quest
let s = "hello"
let s2 = "H" .. s.slice(1, s.len())  # → "Hello"
```

## Alternatives Considered

### Alternative 1: Keep Current API

**Rejected because:**
- Inconsistent with Array/Dict indexing
- Forces verbose workarounds
- Less intuitive for new users

### Alternative 2: Make `s[i]` Return Character Code

```quest
"hello"[0]  # → 104 (like bytes)
```

**Rejected because:**
- Inconsistent with `.slice()` which returns strings
- Forces conversion back to string for common use cases
- Most string operations work with substrings, not char codes
- Languages like Python/Ruby return strings for this reason

### Alternative 3: Return `nil` for Out-of-Bounds

**Rejected because:**
- Inconsistent with Array behavior (which raises errors)
- Silences bugs from typos or logic errors
- Forces defensive checks everywhere
- Quest philosophy: fail fast on errors

## Testing

Add to test suite:

```quest
use "std/test"

test.describe("String bracket indexing", fun ()
    test.it("returns single character", fun ()
        test.assert_eq("hello"[0], "h")
        test.assert_eq("hello"[4], "o")
    end)

    test.it("supports negative indexing", fun ()
        test.assert_eq("hello"[-1], "o")
        test.assert_eq("hello"[-5], "h")
    end)

    test.it("handles boundary indices", fun ()
        # First and last valid indices
        test.assert_eq("hello"[0], "h")
        test.assert_eq("hello"[4], "o")
        test.assert_eq("hello"[-1], "o")
        test.assert_eq("hello"[-5], "h")
    end)

    test.it("handles UTF-8 code points correctly", fun ()
        test.assert_eq("hello世界"[5], "世")
        test.assert_eq("hello世界"[6], "界")
        test.assert_eq("hello世界".len(), 7)
    end)

    test.it("handles combining characters as separate code points", fun ()
        # 'é' as e + combining acute = 2 code points
        let s = "cafe\u{0301}"  # café with combining accent
        test.assert_eq(s.len(), 5)
        test.assert_eq(s[3], "e")
        test.assert_eq(s[4], "\u{0301}")  # Combining acute
    end)

    test.it("handles emoji as code points", fun ()
        let s = "👨‍👩‍👧‍👦"  # Family emoji (multiple code points)
        test.assert_eq(s[0], "👨")  # First code point (man)
        # Note: Full emoji is multiple code points, not a single grapheme
    end)

    test.it("raises error on out of bounds", fun ()
        test.assert_raises(fun () "hello"[5] end)   # len=5, max=4
        test.assert_raises(fun () "hello"[10] end)
        test.assert_raises(fun () "hello"[-6] end)  # len=5, min=-5
        test.assert_raises(fun () "hello"[-10] end)
    end)

    test.it("raises error on empty string", fun ()
        test.assert_raises(fun () ""[0] end)
        test.assert_raises(fun () ""[-1] end)
    end)

    test.it("raises error on non-int indices", fun ()
        test.assert_raises(fun () "hello"[1.5] end)
        test.assert_raises(fun () "hello"["0"] end)
        test.assert_raises(fun () "hello"[nil] end)
    end)

    test.it("supports BigInt indices if they fit", fun ()
        test.assert_eq("hello"[0n], "h")  # Converts to Int
        test.assert_raises(fun () "hello"[9999999999999999n] end)  # Too large
    end)
end)

test.describe("Bytes bracket indexing", fun ()
    test.it("returns byte value as int", fun ()
        test.assert_eq(b"hello"[0], 104)
        test.assert_eq(b"hello"[1], 101)
    end)

    test.it("supports negative indexing", fun ()
        test.assert_eq(b"hello"[-1], 111)
        test.assert_eq(b"hello"[-5], 104)
    end)

    test.it("handles boundary indices", fun ()
        test.assert_eq(b"hello"[0], 104)
        test.assert_eq(b"hello"[4], 111)
        test.assert_eq(b"hello"[-1], 111)
        test.assert_eq(b"hello"[-5], 104)
    end)

    test.it("raises error on out of bounds", fun ()
        test.assert_raises(fun () b"hello"[5] end)
        test.assert_raises(fun () b"hello"[10] end)
        test.assert_raises(fun () b"hello"[-6] end)
        test.assert_raises(fun () b"hello"[-10] end)
    end)

    test.it("raises error on empty bytes", fun ()
        test.assert_raises(fun () b""[0] end)
        test.assert_raises(fun () b""[-1] end)
    end)

    test.it("raises error on non-int indices", fun ()
        test.assert_raises(fun () b"hello"[1.5] end)
        test.assert_raises(fun () b"hello"["0"] end)
        test.assert_raises(fun () b"hello"[nil] end)
    end)
end)
```

## Documentation Updates

Update the following docs:

1. **docs/string.md** - Add bracket indexing section
2. **docs/types.md** - Document Bytes indexing behavior
3. **CLAUDE.md** - Update type system notes
4. **Standard library examples** - Use `s[i]` where appropriate

## Migration Guide

No migration needed. This is a pure addition. Existing code using `.slice()` and `.get()` continues to work unchanged.

Optional cleanup:

```quest
# Old style (still works)
let first = s.slice(0, 1)
let byte_val = b.get(0)

# New style (preferred)
let first = s[0]
let byte_val = b[0]
```

## Summary

This QEP adds bracket indexing for `Str` and `Bytes` types, making Quest's indexing API consistent across all indexable types. The feature is intuitive, backwards compatible, and reduces verbosity for common operations.

**Benefits:**
- ✓ Consistent API across all indexable types
- ✓ More readable and concise code
- ✓ Matches user expectations and common patterns
- ✓ 100% backwards compatible
- ✓ UTF-8 aware (code point indexing) for strings
- ✓ Clear error messages with valid ranges
- ✓ Type-safe index validation

**Key Design Decisions:**
- Strings return single-character strings, bytes return integers
- Indexing by Unicode code points (not grapheme clusters)
- Negative indices supported (Python-style)
- Out-of-bounds raises errors (not `nil`)
- Read-only (no assignment support)
- O(n) performance for string indexing (documented)

**Edge Cases Addressed:**
- Empty strings/bytes
- Combining characters and emoji (multiple code points)
- Boundary conditions (first/last valid indices)
- Non-integer indices (Float, Str, nil)
- BigInt indices (converted if they fit)
- Clear distinction from `.get()` method behavior

**Next Steps:**
1. Implement parser/evaluator changes
2. Add comprehensive test suite (including edge cases)
3. Update documentation
4. Mark Bug #004 as resolved
