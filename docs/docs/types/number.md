# numbers

Numbers in Quest can represent both integers and floating point values using a single `Num` type backed by 64-bit floats (f64). Numbers display as integers when they have no fractional part.

## Number Literals

```quest
let integer = 42
let negative = -17
let float = 3.14159
let scientific = 1.5e10
let zero = 0
```

## Type Conversion

Quest automatically converts numbers to appropriate types in different contexts:

### To String
```quest
let num = 42
puts(num._str())        # "42"
puts((3.14)._str())     # "3.14"
```

### To Boolean
```quest
# Zero is falsy, all other numbers are truthy
if 0
    puts("won't print")
end

if 42
    puts("will print")  # prints
end
```

### From String
```quest
let text = "123"
let num = text.as_num()  # Note: Check implementation for actual method name
```

## Arithmetic Operations

Quest supports standard arithmetic operators:

```quest
let a = 10
let b = 3

puts(a + b)   # 13 - addition
puts(a - b)   # 7  - subtraction
puts(a * b)   # 30 - multiplication
puts(a / b)   # 3  - division (note: integer division if no remainder)
puts(a % b)   # 1  - modulo/remainder
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
```

## Number Methods

### Arithmetic Methods

#### `plus(other)`
Adds another number to this number.

**Parameters:**
- `other` - Number to add

**Returns:** Num

**Example:**
```quest
let result = 5.plus(3)
puts(result)  # 8
```

#### `minus(other)`
Subtracts another number from this number.

**Parameters:**
- `other` - Number to subtract

**Returns:** Num

**Example:**
```quest
let result = 10.minus(4)
puts(result)  # 6
```

#### `times(other)`
Multiplies this number by another number.

**Parameters:**
- `other` - Number to multiply by

**Returns:** Num

**Example:**
```quest
let result = 7.times(6)
puts(result)  # 42
```

#### `div(other)`
Divides this number by another number.

**Parameters:**
- `other` - Number to divide by

**Returns:** Num

**Raises:** Error if dividing by zero

**Example:**
```quest
let result = 20.div(4)
puts(result)  # 5

# Division by zero raises error
try
    let bad = 10.div(0)
catch e
    puts("Cannot divide by zero")
end
```

#### `mod(other)`
Returns the remainder of dividing this number by another number.

**Parameters:**
- `other` - Number to divide by (modulus)

**Returns:** Num

**Example:**
```quest
let result = 10.mod(3)
puts(result)  # 1

let even = 8.mod(2)
puts(even)    # 0
```

### Comparison Methods

#### `eq(other)`
Tests if this number equals another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(5.eq(5))   # true
puts(5.eq(3))   # false
```

#### `neq(other)`
Tests if this number does not equal another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(5.neq(3))  # true
puts(5.neq(5))  # false
```

#### `gt(other)`
Tests if this number is greater than another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(10.gt(5))  # true
puts(5.gt(10))  # false
puts(5.gt(5))   # false
```

#### `lt(other)`
Tests if this number is less than another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(3.lt(7))   # true
puts(7.lt(3))   # false
puts(5.lt(5))   # false
```

#### `gte(other)`
Tests if this number is greater than or equal to another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(10.gte(5))  # true
puts(5.gte(5))   # true
puts(3.gte(7))   # false
```

#### `lte(other)`
Tests if this number is less than or equal to another number.

**Parameters:**
- `other` - Number to compare

**Returns:** Bool

**Example:**
```quest
puts(3.lte(7))   # true
puts(5.lte(5))   # true
puts(10.lte(5))  # false
```

## Mathematical Operations

For advanced mathematical operations, use the `std/math` module:

```quest
use "std/math" as math

puts(math.sin(math.pi / 2))    # 1.0 - sine
puts(math.cos(0))               # 1.0 - cosine
puts(math.sqrt(16))             # 4.0 - square root
puts(math.pow(2, 3))            # 8.0 - power
puts(math.abs(-42))             # 42  - absolute value
puts(math.floor(3.7))           # 3   - round down
puts(math.ceil(3.2))            # 4   - round up
puts(math.round(3.5))           # 4   - round to nearest
```

See the [math module documentation](/docs/stdlib/math) for the complete list of mathematical functions.

## Number Formatting

For formatted output, use string formatting:

```quest
let pi = 3.14159

# Using f-strings (if implemented)
puts(f"Pi is approximately {pi}")

# Using format methods
puts("Pi is {:.2}".fmt(pi))         # Pi is 3.14
puts("Value: {:5}".fmt(42))         # "Value:    42"
puts("Padded: {:05}".fmt(42))       # "Padded: 00042"
puts("Hex: {:x}".fmt(255))          # "Hex: ff"
puts("Binary: {:b}".fmt(10))        # "Binary: 1010"
```

See the [strings documentation](/docs/types/strings) for complete formatting options.

## Integer vs Float Display

Numbers are stored as 64-bit floats but display as integers when appropriate:

```quest
puts(42)       # displays as: 42 (not 42.0)
puts(42.0)     # displays as: 42
puts(42.5)     # displays as: 42.5
puts(1e10)     # displays as: 10000000000
puts(1e11)     # displays as: 1e11 (too large for integer display)
```

**Display rule**: A number displays as an integer if:
- Its fractional part is zero (`value.fract() == 0.0`)
- AND its absolute value is less than 10 billion (`value.abs() < 1e10`)

## Ranges

Numbers work with ranges for iteration:

```quest
# Iterate from 1 to 5 (inclusive)
for i in 1..5
    puts(i)
end
# Output: 1, 2, 3, 4, 5

# Iterate from 0 to 9 (inclusive)
for i in 0..9
    puts(i)
end

# Use with arrays
let indices = 0..(arr.len() - 1)
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

### Absolute Value (via math module)
```quest
use "std/math" as math
let value = -42
puts(math.abs(value))  # 42
```

### Min/Max
```quest
let a = 10
let b = 20
let min = if a < b then a else b end
let max = if a > b then a else b end
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

## Notes

- Numbers in Quest are **64-bit floating point** (f64 in Rust)
- Integer operations with no remainder display as integers
- Division by zero raises an error
- All arithmetic and comparison operators have equivalent methods
- Use the `std/math` module for advanced mathematical operations
- Very large numbers may display in scientific notation
- Numbers are **immutable** - operations return new number values
