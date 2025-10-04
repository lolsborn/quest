# math - Mathmatical Functions

The `math` module provides mathematical constants and functions.

## Constants

### `math.pi`
Value of À (pi) - approximately 3.14159265359

### `math.tau`
Value of Ä (tau) - approximately 6.28318530718 (equal to 2À)

## Trigonometric Functions

### `math.sin(n)`
Calculate sine of angle in radians

**Parameters:**
- `n` - Angle in radians (Num)

**Returns:** Num

**Example:**
```quest
use "std/math"
math.sin(math.pi / 2)  # Returns 1.0
```

### `math.cos(n)`
Calculate cosine of angle in radians

**Parameters:**
- `n` - Angle in radians (Num)

**Returns:** Num

**Example:**
```quest
use "std/math"
math.cos(0)  # Returns 1.0
```

### `math.tan(n)`
Calculate tangent of angle in radians

**Parameters:**
- `n` - Angle in radians (Num)

**Returns:** Num

### `math.asin(n)`
Calculate arcsine (inverse sine)

**Parameters:**
- `n` - Value between -1 and 1 (Num)

**Returns:** Angle in radians (Num)

### `math.acos(n)`
Calculate arccosine (inverse cosine)

**Parameters:**
- `n` - Value between -1 and 1 (Num)

**Returns:** Angle in radians (Num)

### `math.atan(n)`
Calculate arctangent (inverse tangent)

**Parameters:**
- `n` - Value (Num)

**Returns:** Angle in radians (Num)

## Other Math Functions

### `math.abs(n)`
Calculate absolute value

**Parameters:**
- `n` - Number (Num)

**Returns:** Absolute value (Num)

**Example:**
```quest
use "std/math"
math.abs(-5)  # Returns 5
```

### `math.sqrt(n)`
Calculate square root

**Parameters:**
- `n` - Non-negative number (Num)

**Returns:** Square root (Num)

**Example:**
```quest
use "std/math"
math.sqrt(16)  # Returns 4
```

### `math.ln(n)`
Calculate natural logarithm (base e)

**Parameters:**
- `n` - Positive number (Num)

**Returns:** Natural logarithm (Num)

### `math.log10(n)`
Calculate logarithm base 10

**Parameters:**
- `n` - Positive number (Num)

**Returns:** Base-10 logarithm (Num)

### `math.exp(n)`
Calculate e raised to the power

**Parameters:**
- `n` - Exponent (Num)

**Returns:** e^n (Num)

### `math.floor(n)`
Round down to nearest integer

**Parameters:**
- `n` - Number (Num)

**Returns:** Largest integer less than or equal to n (Num)

**Example:**
```quest
use "std/math"
math.floor(3.7)  # Returns 3
```

### `math.ceil(n)`
Round up to nearest integer

**Parameters:**
- `n` - Number (Num)

**Returns:** Smallest integer greater than or equal to n (Num)

**Example:**
```quest
use "std/math"
math.ceil(3.2)  # Returns 4
```

### `math.round(n, places?)`
Round to nearest integer or to specified decimal places

**Parameters:**
- `n` - Number (Num)
- `places` - Number of decimal places (optional, defaults to 0)

**Returns:** Rounded number (Num)

**Examples:**
```quest
use "std/math"

# Round to nearest integer
math.round(3.5)     # Returns 4
math.round(3.4)     # Returns 3

# Round to decimal places
math.round(3.14159, 2)   # Returns 3.14
math.round(3.14159, 4)   # Returns 3.1416
math.round(123.456, 1)   # Returns 123.5
math.round(123.456, 0)   # Returns 123 (same as single argument)
```

**Use Cases:**
- Formatting currency: `math.round(price, 2)`
- Scientific measurements: `math.round(value, 4)`
- Percentages: `math.round(percent, 1)`
- Removing floating point errors: `math.round(0.1 + 0.2, 10)`
