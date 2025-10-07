# QEP-014: Enhanced Numeric Literals

**Status:** ✅ Implemented
**Author:** Quest Team
**Created:** 2025-10-05
**Implemented:** 2025-10-05
**Related:** Core language syntax

## Abstract

This QEP proposes comprehensive enhancements to Quest's numeric literal syntax, including:
- Scientific notation (e.g., `1e10`, `3.14e-5`)
- Binary literals (e.g., `0b1010`)
- Hexadecimal literals (e.g., `0xFF`, `0xDEADBEEF`)
- Octal literals (e.g., `0o777`)
- Underscores as digit separators (e.g., `1_000_000`)

These features bring Quest's numeric syntax in line with modern languages like Python and Ruby.

## Motivation

### Current Limitations

Quest currently only supports basic numeric literals:
```quest
let x = 42        # Integer
let y = 3.14      # Float
```

**Critical Bug:** Scientific notation syntax is silently misinterpreted:
```quest
quest> 1e10
1           # Parses as "1" followed by identifier "e10"
quest> 3.14e-5
3.14        # Parses as "3.14" followed by "e" minus "5"
```

The parser treats `1e10` as two separate tokens (number + identifier) instead of erroring. This creates confusing behavior and silent data loss.

This forces workarounds for common use cases:
```quest
# Scientific notation - currently requires manual calculation
let avogadro = 602214076000000000000000  # Hard to read
let planck = 0.0000000000000000000000000000000006626  # Error-prone

# Binary/hex/octal - requires conversion functions
let flags = 170   # What does this represent? (0b10101010)
let color = 16711680  # Not obvious this is #FF0000 (red)
let perms = 493   # Not clear this is 0o755 (rwxr-xr-x)

# Large numbers - hard to read without separators
let population = 7900000000  # Is this 7.9 billion?
```

### Benefits

1. **Readability** - Clear representation of intent
2. **Scientific computing** - Natural expression of large/small values
3. **Systems programming** - Direct binary/hex notation for flags, addresses
4. **Financial applications** - Readable large numbers with separators
5. **Cross-language compatibility** - Match Python/Ruby/JavaScript syntax

## Specification

### 1. Scientific Notation

**Syntax:**
```quest
<mantissa> ('e' | 'E') ['+' | '-'] <exponent>
```

**Examples:**
```quest
let avogadro = 6.022e23      # 6.022 × 10^23
let planck = 6.626e-34       # 6.626 × 10^-34
let billion = 1e9            # 1,000,000,000
let micro = 1.5E-6           # 0.0000015
let large = 1.5e10           # 15,000,000,000
```

**Type Rules:**
- Always creates `Float` type (never `Int`)
- Valid exponent range: -308 to +308 (f64 limits)
- Mantissa can be integer or decimal

**Grammar:**
```pest
scientific = @{
    ASCII_DIGIT+ ~ ("." ~ ASCII_DIGIT+)? ~
    ("e" | "E") ~ ("+" | "-")? ~ ASCII_DIGIT+
}

number = @{ scientific | float | integer }
```

### 2. Binary Literals

**Syntax:**
```quest
'0b' [01_]+
```

**Examples:**
```quest
let flags = 0b10101010       # 170
let mask = 0b1111_0000       # 240 (with separator)
let byte = 0b11111111        # 255
let empty = 0b0              # 0
```

**Type Rules:**
- Always creates `Int` type
- Maximum value: `0b111...111` (63 ones, max i64)
- Underscores allowed for readability
- Error on overflow

### 3. Hexadecimal Literals

**Syntax:**
```quest
'0x' [0-9a-fA-F_]+
```

**Examples:**
```quest
let color = 0xFF0000         # 16711680 (red)
let addr = 0xDEADBEEF        # 3735928559
let uuid_part = 0x1234_5678  # With separator
let byte = 0xff              # 255 (lowercase works)
let CAPS = 0xFF              # 255 (any case)
```

**Type Rules:**
- Always creates `Int` type
- Case-insensitive: `0xFF` == `0xff` == `0xFf`
- Maximum value: `0x7FFF_FFFF_FFFF_FFFF` (max i64)
- Underscores allowed for readability
- Error on overflow

**Use Cases:**
- Color codes: `0xFF0000`, `0x00FF00`, `0x0000FF`
- Memory addresses: `0x1000`, `0xDEADBEEF`
- Bit patterns: `0xFFFF`, `0x8000`
- Protocol constants: `0x0800` (IPv4 EtherType)

### 4. Octal Literals

**Syntax:**
```quest
'0o' [0-7_]+
```

**Examples:**
```quest
let perms = 0o755            # 493 (rwxr-xr-x)
let umask = 0o022            # 18
let full = 0o777             # 511 (rwxrwxrwx)
let readonly = 0o444         # 292 (r--r--r--)
```

**Type Rules:**
- Always creates `Int` type
- Only digits 0-7 allowed
- Maximum value: `0o777_777_777_777_777_777_777` (max i64)
- Underscores allowed for readability
- Error on overflow

**Use Cases:**
- File permissions: `0o755`, `0o644`, `0o777`
- Unix umask: `0o022`, `0o002`

### 5. Digit Separators (Underscores)

**Syntax:**
- Underscores (`_`) allowed between digits
- Cannot start or end with underscore
- Cannot have consecutive underscores

**Examples:**
```quest
# Decimal
let million = 1_000_000
let billion = 7_900_000_000
let pi = 3.141_592_653

# Binary (group by 4 or 8)
let word = 0b1111_0000_1010_0101
let byte = 0b1010_1010

# Hex (group by 2 or 4)
let color = 0xFF_00_00
let uuid = 0x550e_8400_e29b_41d4

# Octal (group by 3)
let perms = 0o755_644

# Scientific
let avogadro = 6.022_140_76e23
```

**Rules:**
- Underscores ignored during parsing (pure visual separator)
- Works with all numeric literal types
- Cannot appear:
  - Before prefix (`_0xFF` invalid)
  - After prefix (`0x_FF` invalid)
  - Before/after decimal point (`1_.0` or `1._0` invalid)
  - Before/after exponent (`1e_5` or `1_e5` invalid)
  - At start/end of number
  - Consecutively (`1__000` invalid)

## Error Handling and Validation

### Invalid Numeric Literals Must Error

The grammar must ensure that malformed numeric literals produce clear parse errors, not silent misinterpretation:

**Examples that should fail:**
```quest
1p00        # Invalid: 'p' is not a valid exponent marker (should error, not parse as "1" + "p00")
1x100       # Invalid: lowercase 'x' after digit (should error, not parse as "1" + "x100")
0xGHI       # Invalid: G, H, I not hex digits
0b102       # Invalid: '2' not a binary digit
0o789       # Invalid: '8', '9' not octal digits
1e         # Invalid: exponent with no digits
1e+        # Invalid: exponent with no digits after sign
0x         # Invalid: hex prefix with no digits
0b         # Invalid: binary prefix with no digits
1.2.3      # Invalid: multiple decimal points
1e5e2      # Invalid: multiple exponents
```

**Current Bug:**
The existing grammar allows `1e10` to parse as two separate tokens:
```quest
number = @{ ASCII_DIGIT+ ~ ("." ~ ASCII_DIGIT+)? }
identifier = @{ (ASCII_ALPHA | "_") ~ (ASCII_ALPHANUMERIC | "_")* }
```

This means `1e10` becomes `1` (number) followed by `e10` (identifier), which silently fails.

**Solution:**
The grammar must be ordered so numbers are parsed greedily:
```pest
number = @{
    scientific | hex_literal | binary_literal | octal_literal | decimal_literal
}
```

With negative lookaheads to prevent partial matches:
```pest
hex_literal = @{
    "0x" ~ (ASCII_HEX_DIGIT | "_")+ ~ !(ASCII_ALPHANUMERIC)
}
```

The `!(ASCII_ALPHANUMERIC)` ensures that `0xGHI` fails to parse rather than parsing as `0x` with leftover `GHI`.

### Validation Tests Required

```quest
# test/types/invalid_numeric_literals_test.q
use "std/test"

test.module("Invalid Numeric Literals")

test.describe("Malformed literals should error", fun ()
    test.it("rejects invalid exponent markers", fun ()
        test.assert_raises(fun ()
            eval("let x = 1p00")  # 'p' is not valid
        end, nil, nil)
    end)

    test.it("rejects incomplete scientific notation", fun ()
        test.assert_raises(fun ()
            eval("let x = 1e")  # Missing exponent
        end, nil, nil)
    end)

    test.it("rejects non-hex digits in hex", fun ()
        test.assert_raises(fun ()
            eval("let x = 0xGHI")
        end, nil, nil)
    end)

    test.it("rejects non-binary digits in binary", fun ()
        test.assert_raises(fun ()
            eval("let x = 0b102")  # '2' invalid
        end, nil, nil)
    end)

    test.it("rejects non-octal digits in octal", fun ()
        test.assert_raises(fun ()
            eval("let x = 0o789")  # '8', '9' invalid
        end, nil, nil)
    end)

    test.it("rejects hex prefix without digits", fun ()
        test.assert_raises(fun ()
            eval("let x = 0x")
        end, nil, nil)
    end)

    test.it("rejects multiple decimal points", fun ()
        test.assert_raises(fun ()
            eval("let x = 1.2.3")
        end, nil, nil)
    end)

    test.it("rejects multiple exponents", fun ()
        test.assert_raises(fun ()
            eval("let x = 1e5e2")
        end, nil, nil)
    end)
end)
```

### Error Messages

Good error messages help developers understand what went wrong:

```
Parse error: Invalid exponent in numeric literal at line 5
  let x = 1p00
          ^^^^
Expected: 'e' or 'E' for scientific notation

Parse error: Invalid digit 'G' in hexadecimal literal at line 3
  let color = 0xGHI
              ^^^^^
Hexadecimal digits must be 0-9, A-F, or a-f

Parse error: Binary literal '0b102' contains invalid digit '2' at line 7
  let flags = 0b102
              ^^^^^
Binary digits must be 0 or 1
```

## Grammar Changes

### Current Grammar (quest.pest)
```pest
number = @{
    ASCII_DIGIT+ ~ ("." ~ ASCII_DIGIT+)?
}
```

### Proposed Grammar
```pest
number = @{
    scientific | hex_literal | binary_literal | octal_literal | decimal_literal
}

scientific = @{
    decimal_literal ~ ("e" | "E") ~ ("+" | "-")? ~ ASCII_DIGIT+ ~ ("_" ~ ASCII_DIGIT+)*
}

hex_literal = @{
    "0x" ~ (ASCII_HEX_DIGIT | "_")+ ~ !(ASCII_ALPHANUMERIC)
}

binary_literal = @{
    "0b" ~ (ASCII_BIN_DIGIT | "_")+ ~ !(ASCII_ALPHANUMERIC)
}

octal_literal = @{
    "0o" ~ (ASCII_OCT_DIGIT | "_")+ ~ !(ASCII_ALPHANUMERIC)
}

decimal_literal = @{
    ASCII_DIGIT ~ (ASCII_DIGIT | "_")* ~
    ("." ~ ASCII_DIGIT ~ (ASCII_DIGIT | "_")*)?
}
```

## Implementation Strategy

### Phase 1: Scientific Notation (Priority: High)
1. Update `quest.pest` grammar to recognize scientific notation
2. Modify number parsing in `eval_pair()` to handle exponent
3. Use Rust's `parse::<f64>()` after removing underscores
4. Add tests for positive/negative exponents, edge cases
5. Update documentation

**Estimated effort:** 2-3 hours

### Phase 2: Binary/Hex/Octal Literals (Priority: High)
1. Add prefix patterns to grammar (`0b`, `0x`, `0o`)
2. Parse and validate digit ranges
3. Use `i64::from_str_radix()` for conversion
4. Handle overflow errors gracefully
5. Add comprehensive tests
6. Update documentation

**Estimated effort:** 3-4 hours

### Phase 3: Digit Separators (Priority: Medium)
1. Update all number patterns to allow `_` between digits
2. Add validation rules (no leading/trailing/consecutive)
3. Strip underscores before parsing
4. Add tests for all numeric types
5. Update documentation

**Estimated effort:** 2-3 hours

## Examples

### Scientific Notation Use Cases

```quest
# Physics constants
use "std/math"

let c = 2.998e8              # Speed of light (m/s)
let G = 6.674e-11            # Gravitational constant
let h = 6.626e-34            # Planck constant
let k = 1.381e-23            # Boltzmann constant

# Chemistry
let avogadro = 6.022e23      # Avogadro's number
let molar_mass_h2o = 1.8e-2  # kg/mol

# Astronomy
let earth_mass = 5.972e24    # kg
let sun_radius = 6.96e8      # meters
```

### Binary Literals Use Cases

```quest
# Bit flags
let READ = 0b001
let WRITE = 0b010
let EXECUTE = 0b100
let RW = 0b011
let RWX = 0b111

# Network protocols
let IPv4 = 0b10101010_00000000_00000001_00000001  # 170.0.1.1
let subnet_mask = 0b11111111_11111111_11111111_00000000  # 255.255.255.0

# Bit manipulation
let flags = 0b1010_1010
let mask = 0b1111_0000
let result = flags & mask    # 0b1010_0000
```

### Hexadecimal Literals Use Cases

```quest
# Colors
let red = 0xFF0000
let green = 0x00FF00
let blue = 0x0000FF
let white = 0xFFFFFF
let black = 0x000000

# Memory and addresses
let base_addr = 0x1000
let offset = 0x0100
let target = base_addr + offset  # 0x1100

# Unicode code points
let emoji_heart = 0x2764
let emoji_rocket = 0x1F680
```

### Digit Separators Use Cases

```quest
# Financial
let million = 1_000_000
let billion = 1_000_000_000
let national_debt = 31_400_000_000_000

# Scientific
let pi = 3.141_592_653_589_793
let e = 2.718_281_828_459_045

# Credit card
let card = 1234_5678_9012_3456

# Binary grouping
let ipv4 = 0b11000000_10101000_00000001_00000001
let permissions = 0o755

# Hex grouping (UUID-like)
let id = 0x550e8400_e29b_41d4_a716_446655440000
```

## Compatibility

### Breaking Changes
None. All existing numeric literals remain valid.

### Migration
No migration needed. New syntax is purely additive.

### Version
Requires parser changes. Suggest including in Quest 0.2.0.

## Testing Strategy

### Scientific Notation Tests
```quest
# test/types/scientific_notation_test.q
use "std/test"

test.module("Scientific Notation")

test.describe("Basic scientific notation", fun ()
    test.it("parses positive exponent", fun ()
        let x = 1e3
        test.assert_eq(x, 1000.0)    end)

    test.it("parses negative exponent", fun ()
        let x = 1e-3
        test.assert_eq(x, 0.001)    end)

    test.it("parses with decimal mantissa", fun ()
        let x = 3.14e2
        test.assert_eq(x, 314.0)    end)

    test.it("handles large exponents", fun ()
        let x = 1e100
        test.assert(x > 0.0, "Should be positive")
        test.assert(not x.is_infinite(), "Should be finite")
    end)
end)
```

### Binary/Hex/Octal Tests
```quest
# test/types/numeric_bases_test.q
use "std/test"

test.module("Numeric Bases")

test.describe("Binary literals", fun ()
    test.it("parses binary", fun ()
        test.assert_eq(0b1010, 10)        test.assert_eq(0b11111111, 255)    end)

    test.it("supports underscores", fun ()
        test.assert_eq(0b1111_0000, 240)    end)
end)

test.describe("Hexadecimal literals", fun ()
    test.it("parses hex", fun ()
        test.assert_eq(0xFF, 255)        test.assert_eq(0xDEADBEEF, 3735928559)    end)

    test.it("is case-insensitive", fun ()
        test.assert_eq(0xff, 0xFF)        test.assert_eq(0xAbCd, 0xABCD)    end)
end)

test.describe("Octal literals", fun ()
    test.it("parses octal", fun ()
        test.assert_eq(0o755, 493)        test.assert_eq(0o777, 511)    end)
end)
```

### Digit Separator Tests
```quest
# test/types/digit_separators_test.q
use "std/test"

test.module("Digit Separators")

test.describe("Underscores in numbers", fun ()
    test.it("works in integers", fun ()
        test.assert_eq(1_000_000, 1000000)    end)

    test.it("works in floats", fun ()
        test.assert_eq(3.141_592, 3.141592)    end)

    test.it("works in all bases", fun ()
        test.assert_eq(0b1111_0000, 240)        test.assert_eq(0xFF_00, 65280)        test.assert_eq(0o7_5_5, 493)    end)
end)
```

## Documentation Updates

### CLAUDE.md
Add to literals section:
```markdown
**Number literals**:
- Integer literals (create `Int`): `42`, `-5`, `1000`, `1_000_000`
- Float literals (create `Float`): `3.14`, `1.0`, `-2.5`
- Scientific notation (create `Float`): `1e10`, `3.14e-5`, `6.022e23`
- Binary literals (create `Int`): `0b1010`, `0b1111_0000`
- Hexadecimal literals (create `Int`): `0xFF`, `0xDEADBEEF`, `0xFF_00_00`
- Octal literals (create `Int`): `0o755`, `0o644`
- Digit separators: Use `_` for readability in any numeric literal
```

### LANGUAGE_FEATURE_COMPARISON.md
Update from ❌ to ✅:
- Scientific notation
- Binary literals
- Hex literals (full support, not just byte strings)
- Octal literals
- Underscores in numbers

## Alternatives Considered

### 1. Julia-style underscore suffix for types
```quest
let x = 1_000_000_i64  # Explicit type
let y = 3.14_f32       # 32-bit float
```
**Rejected:** Adds complexity. Quest's type inference is sufficient.

### 2. Swift-style hexadecimal floats
```quest
let x = 0x1.8p3  # 1.5 × 2^3 = 12.0
```
**Rejected:** Too specialized. Scientific notation covers this use case.

### 3. Rust-style suffixes for numeric types
```quest
let x = 1_000u64
let y = 3.14f32
```
**Rejected:** Quest doesn't have sized integer types like u64/i32.

## Future Extensions

### 1. Arbitrary Precision Integers
Python-style automatic bigint promotion:
```quest
let huge = 10 ** 100  # Automatic BigInt
```

### 2. Rational Numbers
```quest
let half = 1//2       # Rational(1, 2)
let third = 1//3      # Rational(1, 3)
```

## References

- Python PEP 515: Underscores in Numeric Literals
- Python PEP 3141: A Type Hierarchy for Numbers
- Ruby numeric literals documentation
- JavaScript numeric separators proposal
- Rust numeric literals documentation

## Open Questions

1. **Should scientific notation support underscores in exponent?**
   - `1e1_000` - is this allowed?
   - **Proposed:** No, for simplicity

2. **Should hex literals support uppercase X?**
   - `0xFF` vs `0XFF`
   - **Proposed:** Allow both for consistency

## Status

- [x] Grammar design
- [x] Phase 1: Scientific notation implementation
- [x] Phase 2: Binary/hex/octal implementation
- [x] Phase 3: Digit separators implementation
- [x] Tests
- [x] Documentation
- [x] CLAUDE.md updates
- [x] LANGUAGE_FEATURE_COMPARISON.md updates

**Status:** ✅ **Implemented** (2025-10-05)

All phases complete! Quest now supports:
- Scientific notation: `1e10`, `3.14e-5`, `6.022e23`
- Binary literals: `0b1010`, `0b1111_0000`
- Hexadecimal literals: `0xFF`, `0xDEADBEEF`, `0xFF_00_00`
- Octal literals: `0o755`, `0o644`
- Digit separators: `1_000_000`, `3.141_592`

## Conclusion

Enhanced numeric literals significantly improve Quest's expressiveness for scientific, systems, and financial programming. The phased implementation allows incremental delivery of value while maintaining backward compatibility.
