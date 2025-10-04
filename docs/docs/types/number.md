# Numbers

Quest provides distinct types for integers and floating-point numbers, each with their own characteristics and behaviors.

## Number Types

### Int - 64-bit Signed Integers
- **Storage**: `i64` (64-bit signed integer)
- **Range**: -9,223,372,036,854,775,807 to 9,223,372,036,854,775,807
- **Overflow**: Checked (raises error on overflow)
- **Division**: Integer division (truncates)

### Float - 64-bit Floating Point
- **Storage**: `f64` (64-bit floating-point)
- **Precision**: ~15-17 decimal digits
- **Special values**: NaN, Infinity, -Infinity
- **Division**: Exact floating-point division

### Num - Legacy Float Type
- **Note**: Legacy type for backward compatibility
- **Storage**: Same as Float (f64)
- **Usage**: Prefer using Float for new code

### Decimal - Arbitrary Precision
- **Storage**: 28-29 significant digits
- **Usage**: PostgreSQL NUMERIC/DECIMAL columns, financial calculations
- **See**: [Decimal documentation](decimal.md)

## Number Literals

```quest
# Integer literals (create Int)
let age = 42
let negative = -17
let zero = 0
let big = 9223372036854775807

# Float literals (create Float)
let pi = 3.14159
let temp = -2.5
let one = 1.0                    # Float, not Int
let scientific = 1.5e10          # Scientific notation
let small = 3.14e-5
```

## Type Behavior

### Type Preservation
Arithmetic operations preserve types when possible:

```quest
let a = 5        # Int
let b = 10       # Int
let c = a + b    # Int (15)

let x = 3.14     # Float
let y = 2.5      # Float
let z = x + y    # Float (5.64)
```

### Type Promotion
Mixed operations promote to the more general type:

```quest
let int_val = 5          # Int
let float_val = 2.5      # Float

let result = int_val + float_val   # Float (7.5)
```

**Promotion rules:**
- `Int + Int = Int`
- `Int + Float = Float`
- `Float + Float = Float`
- `Float + Decimal = Decimal`

### Integer Division
Integer division truncates toward zero:

```quest
puts(10 / 3)      # 3 (Int)
puts(10 / 4)      # 2 (Int)
puts(-10 / 3)     # -3 (Int)

puts(10.0 / 3.0)  # 3.3333... (Float)
```

## Type Conversion

### Int Methods
```quest
let num = 42
puts(num.to_f64())       # Convert to Float: 42.0
puts(num.to_num())       # Convert to Num: 42.0
puts(num.to_string())    # Convert to String: "42"
```

### Float Methods
```quest
let pi = 3.14159
puts(pi.to_int())        # Convert to Int: 3 (truncates)
puts(pi.floor())         # Round down to Int: 3
puts(pi.ceil())          # Round up to Int: 4
puts(pi.round())         # Round to nearest Int: 3
puts(pi.to_string())     # Convert to String: "3.14159"
```

### To Boolean
```quest
# Zero is falsy, all other numbers are truthy
if 0
    puts("won't print")
end

if 42
    puts("will print")      # prints
end

if -5
    puts("negative is truthy")  # prints
end
```

## Arithmetic Operations

Quest supports standard arithmetic operators:

```quest
let a = 10
let b = 3

puts(a + b)   # 13 - addition
puts(a - b)   # 7  - subtraction
puts(a * b)   # 30 - multiplication
puts(a / b)   # 3  - division (integer division for Int)
puts(a % b)   # 1  - modulo/remainder

# Unary operators
puts(-a)      # -10 - negation
puts(+a)      # 10  - unary plus (no-op)
```

### Overflow Detection (Int only)

Integer operations check for overflow:

```quest
let big = 9223372036854775807  # i64::MAX
try
    let overflow = big + 1
catch e
    puts("Integer overflow detected!")
end
```

## Comparison Operations

```quest
let x = 10
let y = 20

puts(x == y)  # false - equality
puts(x != y)  # true  - inequality
puts(x < y)   # true  - less than
puts(x > y)   # false - greater than
puts(x <= y)  # true  - less than or equal
puts(x >= y)  # false - greater than or equal

# Mixed type comparisons work
puts(10 == 10.0)    # true
puts(5 < 5.5)       # true
```

## Int Methods

### Arithmetic Methods

All arithmetic operations available as methods:

```quest
let a = 10
let b = 3

puts(a.plus(b))    # 13
puts(a.minus(b))   # 7
puts(a.times(b))   # 30
puts(a.div(b))     # 3
puts(a.mod(b))     # 1
```

### Comparison Methods

```quest
puts(5.eq(5))      # true
puts(5.neq(3))     # true
puts(10.gt(5))     # true
puts(3.lt(7))      # true
puts(10.gte(5))    # true
puts(3.lte(7))     # true
```

### Other Methods

```quest
let num = -42
puts(num.abs())         # 42 - absolute value
puts(num.to_f64())      # -42.0 - convert to Float
puts(num.to_string())   # "-42" - convert to String
puts(num.cls())         # "Int" - type name
puts(num._id())         # unique object ID
```

## Float Methods

### Arithmetic Methods

```quest
let x = 3.14
let y = 2.5

puts(x.plus(y))    # 5.64
puts(x.minus(y))   # 0.64
puts(x.times(y))   # 7.85
puts(x.div(y))     # 1.256
puts(x.mod(y))     # 0.64
```

### Rounding Methods

```quest
let value = 3.7

puts(value.floor())     # 3 - round down (returns Int)
puts(value.ceil())      # 4 - round up (returns Int)
puts(value.round())     # 4 - round to nearest (returns Int)
```

### Special Value Checks

```quest
let x = 3.14
let nan = 0.0 / 0.0
let inf = 1.0 / 0.0

puts(x.is_nan())        # false
puts(x.is_infinite())   # false
puts(x.is_finite())     # true

puts(nan.is_nan())      # true
puts(inf.is_infinite()) # true
```

### Other Methods

```quest
let pi = 3.14159
puts(pi.abs())          # 3.14159 - absolute value
puts(pi.to_int())       # 3 - convert to Int (truncates)
puts(pi.to_string())    # "3.14159" - convert to String
puts(pi.cls())          # "Float" - type name
```

## Mathematical Operations

For advanced mathematical operations, use the `std/math` module:

```quest
use "std/math" as math

puts(math.sin(math.pi / 2))    # 1.0 - sine
puts(math.cos(0))               # 1.0 - cosine
puts(math.sqrt(16.0))           # 4.0 - square root
puts(math.pow(2.0, 3.0))        # 8.0 - power
puts(math.floor(3.7))           # 3.0 - round down
puts(math.ceil(3.2))            # 4.0 - round up
puts(math.round(3.5))           # 4.0 - round to nearest
```

See the [math module documentation](/docs/stdlib/math) for the complete list of mathematical functions.

## Display Formatting

### Int Display
Integers always display without decimal point:

```quest
puts(42)       # 42
puts(-17)      # -17
puts(0)        # 0
```

### Float Display
Floats display as integers when the fractional part is zero and value is small enough:

```quest
puts(42.0)     # 42 (displays as integer)
puts(42.5)     # 42.5
puts(3.14)     # 3.14
puts(1.0e10)   # 10000000000
puts(1.0e11)   # 1e11 (scientific notation)
```

**Display rule**: A float displays as an integer if:
- Its fractional part is zero (`value.fract() == 0.0`)
- AND its absolute value is less than 10 billion (`value.abs() < 1e10`)

## Ranges

Numbers work with ranges for iteration:

```quest
# Iterate from 1 to 5 (inclusive)
for i in 1 to 5
    puts(i)
end
# Output: 1, 2, 3, 4, 5

# Iterate from 0 to 9 (exclusive)
for i in 0 until 10
    puts(i)
end
# Output: 0, 1, 2, ..., 9

# With step
for i in 0 to 10 step 2
    puts(i)
end
# Output: 0, 2, 4, 6, 8, 10
```

## Common Patterns

### Check if Even/Odd
```quest
let num = 42
if num % 2 == 0
    puts("even")
else
    puts("odd")
end
```

### Absolute Value
```quest
let value = -42
puts(value.abs())  # 42
```

### Min/Max
```quest
let a = 10
let b = 20
let min = if a < b then a else b
let max = if a > b then a else b
```

### Clamping
```quest
# Clamp value between min and max
let value = 150
let min = 0
let max = 100
let clamped = if value < min
    min
elif value > max
    max
else
    value
end
puts(clamped)  # 100
```

### Type Checking
```quest
let x = 42
let y = 3.14

puts(x.cls())   # "Int"
puts(y.cls())   # "Float"

# Check type at runtime
if x.cls() == "Int"
    puts("x is an integer")
end
```

## Notes

- **Int** operations check for overflow and raise errors
- **Float** operations follow IEEE 754 floating-point standard
- Integer division truncates: `10 / 3 = 3`
- Float division is exact: `10.0 / 3.0 = 3.333...`
- Division by zero raises an error for both types
- All arithmetic and comparison operators have equivalent methods
- Use the `std/math` module for advanced mathematical operations
- Numbers are **immutable** - operations return new number values
- Mixed-type operations automatically promote to the more general type
