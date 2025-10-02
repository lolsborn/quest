# Math and Operators

Quest supports standard arithmetic operations and comparisons.

## Arithmetic Operators

```quest
let x = 10
let y = 3

puts(x + y)    # Addition: 13
puts(x - y)    # Subtraction: 7
puts(x * y)    # Multiplication: 30
puts(x / y)    # Division: 3.333...
puts(x % y)    # Modulo (remainder): 1
```

## Comparison Operators

All comparison operators return boolean values (`true` or `false`).

```quest
let a = 10
let b = 5

puts(a == b)   # Equal to: false
puts(a != b)   # Not equal to: true
puts(a > b)    # Greater than: true
puts(a < b)    # Less than: false
puts(a >= b)   # Greater than or equal: true
puts(a <= b)   # Less than or equal: false
```

## Logical Operators

```quest
let x = true
let y = false

puts(x and y)  # Logical AND: false
puts(x or y)   # Logical OR: true
puts(!x)       # Logical NOT: false
```

## Bitwise Operators

Bitwise operations work on integers (numbers are converted to integers for bitwise ops).

```quest
let a = 12  # Binary: 1100
let b = 10  # Binary: 1010

puts(a & b)    # Bitwise AND: 8 (1000)
puts(a | b)    # Bitwise OR: 14 (1110)
```

## String Concatenation

Use `..` to concatenate strings:

```quest
let first = "Hello"
let last = "World"
puts(first .. " " .. last)  # Hello World

# Numbers are automatically converted to strings
let value = 42
puts("Answer: " .. value)  # Answer: 42
```

## Operator Precedence

From highest to lowest precedence:

1. Unary operators: `!`, `-`, `+`
2. Multiplication/Division: `*`, `/`, `%`
3. Addition/Subtraction: `+`, `-`
4. String concatenation: `..`
5. Comparison: `==`, `!=`, `<`, `>`, `<=`, `>=`
6. Bitwise AND: `&`
7. Bitwise OR: `|`
8. Logical AND: `and`
9. Logical OR: `or`

Use parentheses to override precedence:

```quest
let result = (5 + 3) * 2  # 16, not 11
```

## Number Methods

Numbers in Quest are floating-point values and have the following methods:

```quest
let x = 42

puts(x.plus(8))     # Add: 50
puts(x.minus(2))    # Subtract: 40
puts(x.times(2))    # Multiply: 84
puts(x.div(6))      # Divide: 7
```

Note: These methods exist for compatibility, but using operators (`+`, `-`, `*`, `/`) is more idiomatic.
