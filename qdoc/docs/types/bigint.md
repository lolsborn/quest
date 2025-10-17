# BigInt

BigInt provides arbitrary-precision integer arithmetic in Quest. Unlike the standard `Int` type which is limited to 64-bit signed integers (roughly ±9 quintillion), BigInt can represent integers of unlimited size, making it ideal for cryptography, mathematical computations, and working with very large numbers.

## Literals

BigInt literals are created by appending `n` to an integer:

```quest
let small = 42n
let large = 999999999999999999999999999999n
```

BigInt literals support the same numeric base prefixes as regular integers:

```quest
let hex = 0xDEADBEEFn        # Hexadecimal
let binary = 0b11111111n     # Binary
let octal = 0o755n           # Octal
let decimal = 1_000_000n     # With digit separators
```

## Creating BigInt Values

### BigInt.new(str: String) → BigInt

Creates a BigInt from a string representation:

```quest
let big = BigInt.new("123456789012345678901234567890")
```

### BigInt.from_int(i: Int) → BigInt

Converts an Int to BigInt:

```quest
let regular = 42
let big = BigInt.from_int(regular)
```

### BigInt.from_bytes(bytes: Bytes) → BigInt

Creates a BigInt from a byte array (big-endian):

```quest
let bytes = b"\x01\x00\x00\x00"
let big = BigInt.from_bytes(bytes)  # 16777216
```

## Global Constants

Quest provides convenient BigInt constants:

- `ZERO` - BigInt value 0
- `ONE` - BigInt value 1
- `TWO` - BigInt value 2
- `TEN` - BigInt value 10

```quest
let zero = ZERO
let one = ONE
```

## Arithmetic Operations

BigInt supports all standard arithmetic operators:

```quest
let a = 999999999999999999n
let b = 888888888888888888n

let sum = a + b
let difference = a - b
let product = a * b
let quotient = a / b
let remainder = a % b
```

### Type Preservation

BigInt arithmetic preserves the BigInt type:

- `BigInt + BigInt = BigInt`
- `BigInt - BigInt = BigInt`
- `BigInt * BigInt = BigInt`
- `BigInt / BigInt = BigInt`

### Division

Integer division with BigInt truncates toward zero, just like Int:

```quest
let result = 10n / 3n  # 3n
```

## Comparison Operations

BigInt supports all comparison operators:

```quest
let a = 100n
let b = 200n

a == b   # false
a != b   # true
a < b    # true
a <= b   # true
a > b    # false
a >= b   # false
```

## Methods

### to_int() → Int

Converts a BigInt to Int. Raises an error if the value is outside Int range:

```quest
let big = 42n
let regular = big.to_int()  # 42
```

### to_string() → String

Converts a BigInt to its string representation:

```quest
let big = 123456789n
puts(big.to_string())  # "123456789"
```

### _str() → String

Returns the string representation (same as to_string()):

```quest
let big = 999n
puts(big.str())  # "999"
```

### abs() → BigInt

Returns the absolute value:

```quest
let negative = -100n
let positive = negative.abs()  # 100n
```

### pow(exponent: BigInt) → BigInt

Raises the BigInt to the specified power:

```quest
let base = 2n
let result = base.pow(10n)  # 1024n
```

### sqrt() → BigInt

Returns the integer square root (rounded down):

```quest
let num = 100n
let root = num.sqrt()  # 10n
```

### gcd(other: BigInt) → BigInt

Returns the greatest common divisor:

```quest
let a = 48n
let b = 18n
let divisor = a.gcd(b)  # 6n
```

### lcm(other: BigInt) → BigInt

Returns the least common multiple:

```quest
let a = 12n
let b = 18n
let multiple = a.lcm(b)  # 36n
```

### mod_pow(exponent: BigInt, modulus: BigInt) → BigInt

Performs modular exponentiation (efficient for cryptography):

```quest
let base = 3n
let exp = 100n
let mod = 7n
let result = base.mod_pow(exp, mod)
```

### is_even() → Bool

Returns true if the BigInt is even:

```quest
let num = 42n
num.is_even()  # true
```

### is_odd() → Bool

Returns true if the BigInt is odd:

```quest
let num = 43n
num.is_odd()  # true
```

## Use Cases

### Cryptography

BigInt is essential for cryptographic operations:

```quest
# RSA-style key generation (simplified)
let p = 999999999999999999999999999999n
let q = 888888888888888888888888888888n
let n = p * q
```

### Large Number Computation

Calculate factorials beyond Int limits:

```quest
fun factorial(n)
    if n <= 1
        return ONE
    end
    let result = ONE
    let i = 2n
    while i <= n
        result = result * i
        i = i + ONE
    end
    result
end

let large_fact = factorial(100n)
```

### Financial Calculations

Work with very large monetary values without precision loss:

```quest
let total_pennies = 999999999999999999n  # 10 quadrillion dollars
let price_per_share = 12345n
let shares = total_pennies / price_per_share
```

## Mixed-Type Arithmetic

BigInt does **not** automatically promote from Int. You must explicitly convert:

```quest
let regular = 42
let big = 100n

# This raises a TypeErr:
# let sum = regular + big

# Instead, convert first:
let sum = BigInt.from_int(regular) + big  # 142n
```

## Performance Considerations

- BigInt operations are slower than Int operations due to arbitrary precision
- For numbers that fit in 64 bits, use Int for better performance
- BigInt memory usage grows with the magnitude of the number
- Modular exponentiation (`mod_pow`) is optimized for cryptographic use

## See Also

- [Int, Float, Decimal](number.md) - Standard numeric types
- [String](string.md) - String conversion
- [Bytes](bytes.md) - Binary representation
