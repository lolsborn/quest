# QEP-020: BigInt Support

**Status:** Implemented
**Created:** 2025-10-05
**Implemented:** 2025-10-05
**Author:** Quest Language Team

## Abstract

This QEP describes Quest's arbitrary precision integer support through a first-class `BigInt` type with literal syntax. BigInts use the `n` suffix (like JavaScript) for easy creation (`123n`, `0xFFn`) and provide unlimited integer arithmetic for specialized use cases while keeping the default `Int` type as fast, fixed-size `i64`.

## Motivation

Quest currently uses 64-bit signed integers (`i64`) with overflow checking. This design is fast, predictable, and safe - but has a hard limit at ±9,223,372,036,854,775,807.

While this range is sufficient for 99% of use cases (web applications, data processing, timestamps), some domains require larger integers:

1. **Cryptography**: RSA encryption uses 2048-4096 bit numbers
2. **Scientific Computing**: Large factorials, combinatorics, number theory
3. **Project Euler Problems**: Many challenges involve 50+ digit numbers
4. **Symbolic Mathematics**: Exact integer arithmetic without bounds

Rather than making all integers arbitrary precision (which would slow down common operations by 10-100x), Quest implements BigInt as a first-class type with literal syntax (`n` suffix) and supporting module functions for explicit opt-in.

## Design Goals

1. **Keep `Int` fast**: Default integer type remains `i64` with native CPU performance
2. **Explicit opt-in**: Users explicitly choose BigInt when they need it
3. **Ergonomic syntax**: First-class literal support with `n` suffix (like JavaScript)
4. **No surprises**: Clear performance characteristics, no hidden type promotion
5. **Familiar API**: Similar to Quest's existing `Decimal` module
6. **Interoperable**: Easy conversion between `Int` and `BigInt`
7. **Complete**: Full arithmetic operations, comparisons, and conversions

## Specification

### Literal Syntax (Primary Method)

BigInt is a first-class type in Quest with dedicated literal syntax using the `n` suffix:

```quest
# Decimal literals
let x = 123n
let large = 999999999999999999999999999n

# Hexadecimal literals
let hex = 0xDEADBEEFn
let large_hex = 0xFFFFFFFFFFFFFFFFFFFFn

# Binary literals
let bin = 0b11111111n
let large_bin = 0b1111111111111111111111111111111111111111n

# Octal literals
let oct = 0o777n
let large_oct = 0o77777777777777777777n

# Negative literals
let neg = -123n

# Underscores for readability
let readable = 1_000_000_000_000n
```

**Note:** The `n` suffix can be uppercase (`N`) or lowercase (`n`). All number bases support underscores for readability.

### Module Import (For Utility Functions)

```quest
use "std/bigint"
```

The module provides utility functions for construction from strings, bytes, and conversion operations.

### Construction Functions

#### `bigint.new(value)`

Creates a BigInt from a string representation.

**Parameters:**
- `value: str` - String representation of integer (decimal, hex, binary, octal)

**Returns:** `BigInt` object

**Examples:**
```quest
let x = bigint.new("999999999999999999999999999999")
let hex = bigint.new("0xDEADBEEF123456789ABCDEF")
let bin = bigint.new("0b11111111111111111111111111111111111111111111")
let oct = bigint.new("0o777777777777777777777777")
```

#### `bigint.from_int(n)`

Creates a BigInt from a regular Quest Int.

**Parameters:**
- `n: Int` - Integer value

**Returns:** `BigInt` object

**Example:**
```quest
let x = bigint.from_int(42)
let max = bigint.from_int(9223372036854775807)
```

#### `bigint.from_bytes(bytes, signed)`

Creates a BigInt from raw bytes (big-endian).

**Parameters:**
- `bytes: bytes` - Raw byte representation
- `signed: bool` - Whether to interpret as signed (default: `true`)

**Returns:** `BigInt` object

**Example:**
```quest
let data = b"\x00\x00\x00\x00\xFF\xFF\xFF\xFF"
let x = bigint.from_bytes(data, true)
```

### Constants

```quest
bigint.ZERO   # BigInt representing 0
bigint.ONE    # BigInt representing 1
bigint.TWO    # BigInt representing 2
bigint.TEN    # BigInt representing 10
```

### Arithmetic Methods

All arithmetic methods return new `BigInt` objects (immutable).

#### `plus(other)`

Addition: `self + other`

**Parameters:**
- `other: BigInt` - Value to add

**Returns:** `BigInt`

**Example:**
```quest
let a = bigint.new("99999999999999999999")
let b = bigint.new("1")
let c = a.plus(b)  # 100000000000000000000
```

#### `minus(other)`

Subtraction: `self - other`

**Parameters:**
- `other: BigInt` - Value to subtract

**Returns:** `BigInt`

#### `times(other)`

Multiplication: `self * other`

**Parameters:**
- `other: BigInt` - Value to multiply

**Returns:** `BigInt`

#### `div(other)`

Integer division: `self / other` (truncates toward zero)

**Parameters:**
- `other: BigInt` - Divisor

**Returns:** `BigInt`

**Raises:** `DivisionByZeroError` if `other` is zero

#### `mod(other)`

Modulo: `self % other`

**Parameters:**
- `other: BigInt` - Modulus

**Returns:** `BigInt`

**Raises:** `DivisionByZeroError` if `other` is zero

#### `divmod(other)`

Combined division and modulo.

**Parameters:**
- `other: BigInt` - Divisor

**Returns:** `Array` of `[quotient, remainder]`

**Example:**
```quest
let result = bigint.new("17").divmod(bigint.new("5"))
# result = [3, 2]  (17 = 5*3 + 2)
```

#### `pow(exponent, modulus?)`

Exponentiation: `self ** exponent`

Optional modular exponentiation: `(self ** exponent) % modulus`

**Parameters:**
- `exponent: BigInt` - Exponent (must be non-negative)
- `modulus: BigInt?` - Optional modulus for modular exponentiation

**Returns:** `BigInt`

**Raises:** `ValueError` if exponent is negative

**Example:**
```quest
let x = bigint.new("2")
let y = x.pow(bigint.new("1000"))  # 2^1000

# Modular exponentiation (efficient for crypto)
let base = bigint.new("12345")
let exp = bigint.new("6789")
let mod = bigint.new("99999")
let result = base.pow(exp, mod)  # (12345^6789) % 99999
```

#### `abs()`

Absolute value: `|self|`

**Returns:** `BigInt`

#### `negate()`

Negation: `-self`

**Returns:** `BigInt`

### Comparison Methods

All comparison methods return `Bool`.

```quest
equals(other)      # self == other
not_equals(other)  # self != other
less_than(other)   # self < other
less_equal(other)  # self <= other
greater(other)     # self > other
greater_equal(other) # self >= other
```

### Bitwise Operations

#### `bit_and(other)`

Bitwise AND: `self & other`

**Returns:** `BigInt`

#### `bit_or(other)`

Bitwise OR: `self | other`

**Returns:** `BigInt`

#### `bit_xor(other)`

Bitwise XOR: `self ^ other`

**Returns:** `BigInt`

#### `bit_not()`

Bitwise NOT: `~self`

**Returns:** `BigInt`

#### `shl(n)`

Left shift: `self << n`

**Parameters:**
- `n: Int` - Number of bits to shift

**Returns:** `BigInt`

#### `shr(n)`

Right shift: `self >> n` (arithmetic shift, preserves sign)

**Parameters:**
- `n: Int` - Number of bits to shift

**Returns:** `BigInt`

### Utility Methods

#### `to_int()`

Converts BigInt to regular Quest Int.

**Returns:** `Int`

**Raises:** `OverflowError` if value doesn't fit in i64 range

**Example:**
```quest
let big = bigint.new("42")
let small = big.to_int()  # 42 (regular Int)

let too_big = bigint.new("99999999999999999999")
try
    let fail = too_big.to_int()  # Raises OverflowError
catch e
    puts("Can't fit in i64: " .. e.message)
end
```

#### `to_float()`

Converts BigInt to Float (may lose precision).

**Returns:** `Float`

**Example:**
```quest
let big = bigint.new("12345678901234567890")
let f = big.to_float()  # 1.2345678901234567e+19 (approximate)
```

#### `to_string(base?)`

Converts BigInt to string representation.

**Parameters:**
- `base: Int?` - Base for conversion (2-36, default: 10)

**Returns:** `Str`

**Example:**
```quest
let x = bigint.new("255")
puts(x.to_string())      # "255"
puts(x.to_string(16))    # "ff"
puts(x.to_string(2))     # "11111111"
puts(x.to_string(8))     # "377"
```

#### `to_bytes(signed?)`

Converts BigInt to raw bytes (big-endian).

**Parameters:**
- `signed: bool?` - Whether to use signed encoding (default: `true`)

**Returns:** `Bytes`

**Example:**
```quest
let x = bigint.new("65535")
let data = x.to_bytes()  # b"\x00\xFF\xFF"
```

#### `bit_length()`

Returns the number of bits needed to represent this number.

**Returns:** `Int`

**Example:**
```quest
let x = bigint.new("255")
puts(x.bit_length())  # 8

let y = bigint.new("256")
puts(y.bit_length())  # 9
```

#### `is_zero()`

Returns `true` if the value is zero.

**Returns:** `Bool`

#### `is_positive()`

Returns `true` if the value is greater than zero.

**Returns:** `Bool`

#### `is_negative()`

Returns `true` if the value is less than zero.

**Returns:** `Bool`

#### `is_even()`

Returns `true` if the value is even.

**Returns:** `Bool`

#### `is_odd()`

Returns `true` if the value is odd.

**Returns:** `Bool`

### Standard Object Methods

BigInt implements all standard Quest object methods:

```quest
_str()   # String representation (decimal)
_rep()   # Representation: "BigInt(value)"
_type()  # Returns "BigInt"
_id()    # Unique object ID
```

## Usage Examples

### Example 1: Large Factorial

```quest
fun factorial(n)
    let result = 1n
    let i = 2n
    let limit = bigint.from_int(n)  # Convert regular int to BigInt

    while i.less_equal(limit)
        result = result.times(i)
        i = i.plus(1n)
    end

    result
end

let fact_100 = factorial(100)
puts(fact_100.to_string())
# 93326215443944152681699238856266700490715968264381621468592963895217599993229915608941463976156518286253697920827223758251185210916864000000000000000000000000
```

### Example 2: Project Euler Problem 16

Sum of digits of 2^1000:

```quest
# No imports needed - BigInt literals are first-class!
let power = 2n.pow(1000n)
let str = power.to_string()
let sum = 0

for digit in str.chars()
    if digit.is_digit()
        sum += digit.to_int()
    end
end

puts("Sum of digits of 2^1000: " .. sum)
# 1366
```

### Example 3: Modular Exponentiation (Crypto)

```quest
use "std/bigint"  # For parsing large number strings

# Simulating RSA-style computation
let message = bigint.new("12345")
let exponent = bigint.new("65537")
let modulus = bigint.new("9876543210987654321")

# Efficient modular exponentiation
let encrypted = message.pow(exponent, modulus)
puts("Encrypted: " .. encrypted.to_string())

# Or with literals for smaller numbers:
let small_msg = 123n
let small_exp = 17n
let small_mod = 999n
let result = small_msg.pow(small_exp, small_mod)
```

### Example 4: Fibonacci with Large Numbers

```quest
fun fib(n)
    if n <= 1
        return bigint.from_int(n)
    end

    let a = 0n
    let b = 1n

    for i in 2 to n
        let temp = a.plus(b)
        a = b
        b = temp
    end

    b
end

let fib_1000 = fib(1000)
puts("Fibonacci(1000) has " .. fib_1000.to_string().length() .. " digits")
# Fibonacci(1000) has 209 digits
```

### Example 5: Large Prime Testing

```quest
fun is_prime_trial(n)
    if n.less_than(2n)
        return false
    end
    if n.equals(2n)
        return true
    end
    if n.is_even()
        return false
    end

    let i = 3n
    let sqrt_n = n  # Simplified - would need actual sqrt for real implementation

    while i.times(i).less_equal(n)
        if n.mod(i).is_zero()
            return false
        end
        i = i.plus(2n)
    end

    true
end
```

## Implementation Notes

### Rust Implementation

The implementation uses the `num-bigint` Rust crate and integrates BigInt as a first-class type in Quest:

**Parser Integration** (`src/quest.pest`):
- Grammar rules for `bigint_literal` with support for all number bases
- Suffix `n`/`N` distinguishes BigInt from regular Int literals
- Handles hex (`0xFFn`), binary (`0b1111n`), octal (`0o777n`), and decimal (`123n`)

**Type System** (`src/types/bigint.rs`):
- `QBigInt` struct wrapping `num_bigint::BigInt`
- Full `QObj` trait implementation for Quest object system
- Complete method dispatch for arithmetic, comparison, and utility operations

**Module Functions** (`src/modules/bigint.rs`):
- Factory functions for construction from strings and bytes
- Constants (ZERO, ONE, TWO, TEN) for common values

**Benefits from `num-bigint`**:
- Efficient arbitrary precision arithmetic
- Optimized algorithms (Karatsuba multiplication, etc.)
- Well-tested implementation
- Memory-efficient representation

### Performance Characteristics

Users should be aware of performance tradeoffs:

| Operation | i64 (Int) | BigInt (Small) | BigInt (Large) |
|-----------|-----------|----------------|----------------|
| Addition | ~1 cycle | ~10-50 cycles | O(n) digits |
| Multiplication | ~3 cycles | ~100 cycles | O(n²) digits |
| Division | ~10 cycles | ~200 cycles | O(n²) digits |
| Power | Fast | Medium | Can be slow |

**Small BigInt:** Values that fit in 1-2 machine words (~128 bits)
**Large BigInt:** Values requiring many machine words

### Memory Usage

- Small integers (<= 64 bits): ~24-32 bytes (vs 8 bytes for `i64`)
- Large integers: Proportional to number of digits
- No automatic promotion: BigInt stays BigInt

### Error Messages

When users hit i64 overflow, suggest BigInt literals:

```quest
let x = 9223372036854775807
let y = x + 1
# Error: Integer overflow in addition
# Hint: For arbitrary precision integers, use BigInt literals with 'n' suffix: 123n
```

## Alternatives Considered

### Alternative 1: Automatic Promotion (Python/Ruby Style)

Make all integers automatically promote to BigInt on overflow.

**Rejected because:**
- 10-100x performance penalty for all integer operations
- Unpredictable performance (varies with magnitude)
- Type instability (Int changes to BigInt at runtime)
- Complexity in implementation and testing

### Alternative 2: Add Int128 Type

Add fixed-size 128-bit integer type as middle ground.

**Rejected because:**
- Still overflows (just at higher limit)
- Doesn't solve crypto/scientific use cases
- Adds another integer type (Int, Int128, BigInt = confusing)
- 2x memory, slower than i64, not unlimited like BigInt

### Alternative 3: Config-Based Overflow Behavior

Allow users to choose overflow behavior per-file or per-project.

**Rejected because:**
- Inconsistent behavior across codebases
- Hard to reason about library code
- Surprising behavior when modes differ

## Backward Compatibility

This implementation is 100% backward compatible:
- Adds new type and literal syntax (`n` suffix) that didn't exist before
- Adds new module `std/bigint` for utility functions
- Default `Int` type remains `i64`
- No breaking changes to existing code
- The `n` suffix is unambiguous (not previously valid syntax)

## Future Extensions

### Possible Future Additions

1. **Operator overloading**: If Quest adds operator overloading, allow `+`, `-`, `*`, etc. on BigInt
2. **Rational numbers**: `std/rational` for exact fractions using BigInt numerator/denominator
3. **Performance optimizations**: JIT compilation, inline small values
4. **Prime number utilities**: Miller-Rabin, trial division, factorization
5. **GCD/LCM**: Greatest common divisor, least common multiple

## References

- Python `int` documentation: https://docs.python.org/3/library/stdtypes.html#numeric-types-int-float-complex
- Java `BigInteger` documentation: https://docs.oracle.com/javase/8/docs/api/java/math/BigInteger.html
- Rust `num-bigint` crate: https://docs.rs/num-bigint/
- JavaScript `BigInt`: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt

## Appendix: Complete API Summary

```quest
# Literal Syntax (Primary)
123n                    # Decimal BigInt
0xDEADBEEFn            # Hex BigInt
0b11111111n            # Binary BigInt
0o777n                 # Octal BigInt
-123n                  # Negative BigInt
1_000_000n             # With underscores

# Module Construction Functions
use "std/bigint"
bigint.new(str) -> BigInt
bigint.from_int(int) -> BigInt
bigint.from_bytes(bytes, signed?) -> BigInt

# Module Constants
bigint.ZERO
bigint.ONE
bigint.TWO
bigint.TEN

# Arithmetic
plus(other) -> BigInt
minus(other) -> BigInt
times(other) -> BigInt
div(other) -> BigInt
mod(other) -> BigInt
divmod(other) -> [BigInt, BigInt]
pow(exp, mod?) -> BigInt
abs() -> BigInt
negate() -> BigInt

# Comparison
equals(other) -> Bool
not_equals(other) -> Bool
less_than(other) -> Bool
less_equal(other) -> Bool
greater(other) -> Bool
greater_equal(other) -> Bool

# Bitwise
bit_and(other) -> BigInt
bit_or(other) -> BigInt
bit_xor(other) -> BigInt
bit_not() -> BigInt
shl(n) -> BigInt
shr(n) -> BigInt

# Conversion
to_int() -> Int (may raise OverflowError)
to_float() -> Float
to_string(base?) -> Str
to_bytes(signed?) -> Bytes

# Utility
bit_length() -> Int
is_zero() -> Bool
is_positive() -> Bool
is_negative() -> Bool
is_even() -> Bool
is_odd() -> Bool

# Standard Object Methods
_str() -> Str
_rep() -> Str
_type() -> Str
_id() -> Int
```

## Status

**Implemented** - This QEP has been fully implemented and merged.

### Implementation Summary

- **First-class literal syntax**: BigInt literals with `n` suffix (`123n`, `0xFFn`, etc.)
- **Parser integration**: Complete grammar rules in `src/quest.pest`
- **Type system**: Full `QBigInt` type in `src/types/bigint.rs`
- **Module functions**: Utility functions in `src/modules/bigint.rs`
- **Test coverage**: Comprehensive test suite in `test/bigint_test.q` (400+ lines)

The implementation exceeds the original proposal by adding first-class literal syntax, making BigInt a true first-class citizen of Quest rather than just a library module.
