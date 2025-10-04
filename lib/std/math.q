"""
Mathematical functions and constants.

This module provides trigonometric functions, rounding operations,
and mathematical constants like pi and tau.

All angles are in radians. Use degrees() and radians() to convert.

Example:
  use "std/math" as math

  # Trigonometry
  let angle = math.pi / 4
  let result = math.sin(angle)  # ~0.707

  # Unit conversion
  let deg = math.degrees(math.pi)  # 180
  let rad = math.radians(180)      # π

  # Rounding
  let x = math.floor(3.7)  # 3
  let y = math.ceil(3.2)   # 4
  let z = math.round(3.5, 0)  # 4
"""

# =============================================================================
# Documentation for Rust-implemented constants
# =============================================================================

%const pi
"""
The mathematical constant π (pi) ≈ 3.14159265359

The ratio of a circle's circumference to its diameter.

**Example:**
```quest
let circumference = 2 * math.pi * radius
let area = math.pi * radius * radius
```
"""

%const tau
"""
The mathematical constant τ (tau) ≈ 6.28318530718

Equal to 2π. Represents one full turn in radians.

**Example:**
```quest
let full_circle = math.tau
let half_circle = math.tau / 2
```
"""

# =============================================================================
# Documentation for Rust-implemented trigonometric functions
# =============================================================================

%fun sin(x)
"""
## Calculate the sine of x (in radians).

**Parameters:**
- `x` (**Num**) - Angle in radians

**Returns:** **Num** - Sine value between -1 and 1

**Example:**
```quest
math.sin(0)              # 0.0
math.sin(math.pi / 2)    # 1.0
math.sin(math.pi)        # ~0.0 (floating point)
math.sin(3 * math.pi / 2)  # -1.0
```
"""

%fun cos(x)
"""
## Calculate the cosine of x (in radians).

**Parameters:**
- `x` (**Num**) - Angle in radians

**Returns:** **Num** - Cosine value between -1 and 1

**Example:**
```quest
math.cos(0)           # 1.0
math.cos(math.pi / 2) # ~0.0 (floating point)
math.cos(math.pi)     # -1.0
```
"""

%fun tan(x)
"""
## Calculate the tangent of x (in radians).

**Parameters:**
- `x` (**Num**) - Angle in radians

**Returns:** **Num** - Tangent value (can be very large near π/2)

**Example:**
```quest
math.tan(0)           # 0.0
math.tan(math.pi / 4) # ~1.0
```

**Warning:** tan(π/2) and tan(3π/2) are undefined (return very large values)
"""

%fun asin(x)
"""
## Calculate the arcsine (inverse sine) of x.

**Parameters:**
- `x` (**Num**) - Value between -1 and 1

**Returns:** **Num** - Angle in radians between -π/2 and π/2

**Example:**
```quest
math.asin(0)    # 0.0
math.asin(1)    # π/2 (≈1.5708)
math.asin(-1)   # -π/2 (≈-1.5708)
math.asin(0.5)  # π/6 (≈0.5236)
```

**Raises:** Error if x is outside [-1, 1]
"""

%fun acos(x)
"""
## Calculate the arccosine (inverse cosine) of x.

**Parameters:**
- `x` (**Num**) - Value between -1 and 1

**Returns:** **Num** - Angle in radians between 0 and π

**Example:**
```quest
math.acos(1)    # 0.0
math.acos(0)    # π/2 (≈1.5708)
math.acos(-1)   # π (≈3.14159)
math.acos(0.5)  # π/3 (≈1.0472)
```

**Raises:** Error if x is outside [-1, 1]
"""

%fun atan(x)
"""
## Calculate the arctangent (inverse tangent) of x.

**Parameters:**
- `x` (**Num**) - Any real number

**Returns:** **Num** - Angle in radians between -π/2 and π/2

**Example:**
```quest
math.atan(0)  # 0.0
math.atan(1)  # π/4 (≈0.7854)
math.atan(-1) # -π/4 (≈-0.7854)
```

**See also:** atan2(y, x) for two-argument arctangent
"""

# =============================================================================
# Documentation for Rust-implemented mathematical functions
# =============================================================================

%fun sqrt(x)
"""
## Calculate the square root of x.

**Parameters:**
- `x` (**Num**) - Non-negative number

**Returns:** **Num** - Square root of x

**Example:**
```quest
math.sqrt(4)   # 2.0
math.sqrt(9)   # 3.0
math.sqrt(2)   # ~1.4142
math.sqrt(0)   # 0.0
```

**Raises:** Error if x < 0
"""

%fun abs(x)
"""
## Calculate the absolute value of x.

**Parameters:**
- `x` (**Num**) - Any number

**Returns:** **Num** - Non-negative absolute value

**Example:**
```quest
math.abs(5)    # 5
math.abs(-5)   # 5
math.abs(0)    # 0
math.abs(-3.7) # 3.7
```
"""

%fun floor(x)
"""
## Round x down to the nearest integer.

**Parameters:**
- `x` (**Num**) - Any number

**Returns:** **Num** - Largest integer ≤ x

**Example:**
```quest
math.floor(3.7)   # 3
math.floor(3.2)   # 3
math.floor(-2.3)  # -3
math.floor(5)     # 5
```
"""

%fun ceil(x)
"""
## Round x up to the nearest integer.

**Parameters:**
- `x` (**Num**) - Any number

**Returns:** **Num** - Smallest integer ≥ x

**Example:**
```quest
math.ceil(3.2)   # 4
math.ceil(3.7)   # 4
math.ceil(-2.3)  # -2
math.ceil(5)     # 5
```
"""

%fun round(x, decimals)
"""
## Round x to the specified number of decimal places.

**Parameters:**
- `x` (**Num**) - Number to round
- `decimals` (**Num**) - Number of decimal places (can be negative)

**Returns:** **Num** - Rounded value

**Example:**
```quest
math.round(3.14159, 2)   # 3.14
math.round(3.14159, 0)   # 3
math.round(1234.5, -1)   # 1230
math.round(1234.5, -2)   # 1200
```

**Note:** Uses "round half away from zero" strategy
"""

%fun ln(x)
"""
## Calculate the natural logarithm (base e) of x.

**Parameters:**
- `x` (**Num**) - Positive number

**Returns:** **Num** - Natural logarithm of x

**Example:**
```quest
math.ln(1)      # 0.0
math.ln(2.718)  # ~1.0 (where e ≈ 2.71828)
math.ln(10)     # ~2.3026
```

**Raises:** Error if x ≤ 0
"""

%fun log10(x)
"""
## Calculate the base-10 logarithm of x.

**Parameters:**
- `x` (**Num**) - Positive number

**Returns:** **Num** - Base-10 logarithm of x

**Example:**
```quest
math.log10(1)     # 0.0
math.log10(10)    # 1.0
math.log10(100)   # 2.0
math.log10(1000)  # 3.0
```

**Raises:** Error if x ≤ 0
"""

%fun exp(x)
"""
## Calculate e raised to the power of x (e^x).

**Parameters:**
- `x` (**Num**) - Any number

**Returns:** **Num** - e^x

**Example:**
```quest
math.exp(0)  # 1.0
math.exp(1)  # e ≈ 2.71828
math.exp(2)  # e² ≈ 7.389
math.exp(-1) # 1/e ≈ 0.368
```
"""

# =============================================================================
# Quest-implemented convenience functions
# =============================================================================

# Capture values for use in Quest functions (closure workaround)
let _pi = __builtin__.pi

fun degrees(radians)
    """
    Convert radians to degrees.

    Parameters:
      radians: Num - Angle in radians

    Returns: Num - Angle in degrees

    Example:
      math.degrees(math.pi)      # 180
      math.degrees(math.pi / 2)  # 90
      math.degrees(0)            # 0
      math.degrees(math.tau)     # 360
    """
    radians * 180 / _pi
end

fun radians(degrees_val)
    """
    Convert degrees to radians.

    Parameters:
      degrees_val: Num - Angle in degrees

    Returns: Num - Angle in radians

    Example:
      math.radians(180)  # π (≈3.14159)
      math.radians(90)   # π/2 (≈1.5708)
      math.radians(0)    # 0
      math.radians(360)  # τ (≈6.28318)
    """
    degrees_val * _pi / 180
end
