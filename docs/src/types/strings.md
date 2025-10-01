

## String Literal
```
"This is a string literal"
```

## String Interpolation

Quest supports three styles of string formatting, inspired by Python and Rust:

### 1. F-Strings (Python-style)

Use `f"..."` prefix for automatic variable interpolation from the current scope:

```quest
let name = "Alice"
let age = 30
puts(f"Hello {name}, you are {age} years old")
# Output: Hello Alice, you are 30 years old
```

F-strings are the simplest form - just prefix your string with `f` and reference variables directly. Plain strings (`"..."` without the `f` prefix) do NOT interpolate - `"Hello {name}"` is a literal string containing braces.

### 2. Explicit Formatting with .fmt()

For more control, use the `.fmt()` method with positional or named arguments.

#### Positional Arguments

```quest
"Welcome to {} in room {}".fmt("Biology", 202)
# Output: Welcome to Biology in room 202

"Item {0} costs ${1:.2}".fmt("Apple", 3.5)
# Output: Item Apple costs $3.50
```

#### Named Arguments

**Note**: Named arguments are not yet implemented in Quest. Use positional arguments or f-strings instead.

### Format Specifiers (Rust-style)

Format specifiers control how values are displayed.

#### Number Formatting

```quest
# Decimal precision
"{:.2}".fmt(3.14159)           # 3.14
"{:.0}".fmt(3.14159)           # 3

# Hexadecimal
"{:x}".fmt(255)                # ff
"{:X}".fmt(255)                # FF
"{:#x}".fmt(255)               # 0xff

# Binary
"{:b}".fmt(10)                 # 1010
"{:#b}".fmt(10)                # 0b1010

# Octal
"{:o}".fmt(8)                  # 10
"{:#o}".fmt(8)                 # 0o10

# Scientific notation
"{:e}".fmt(1000.0)             # 1e3
"{:E}".fmt(1000.0)             # 1E3
```

#### Width and Alignment

```quest
# Width (minimum characters)
"{:5}".fmt("x")                # "    x" (right-aligned by default)
"{:5}".fmt(42)                 # "   42"

# Left align
"{:<5}".fmt("x")               # "x    "

# Right align (explicit)
"{:>5}".fmt("x")               # "    x"

# Center align
"{:^5}".fmt("x")               # "  x  "
```

#### Fill Characters

```quest
# Zero-padding for numbers
"{:05}".fmt(42)                # "00042"
"{:0>5}".fmt(42)               # "00042"

# Custom fill character
"{:->5}".fmt("x")              # "----x"
"{:-<5}".fmt("x")              # "x----"
"{:-^5}".fmt("x")              # "--x--"
```

#### Sign Control

```quest
# Always show sign
"{:+}".fmt(42)                 # "+42"
"{:+}".fmt(-42)                # "-42"

# Space for positive numbers
"{: }".fmt(42)                 # " 42"
"{: }".fmt(-42)                # "-42"
```

#### Combined Specifiers

```quest
# Width + precision
"{:8.2}".fmt(3.14159)          # "    3.14"

# Fill + align + width + precision
"{:0>8.2}".fmt(3.14)           # "00003.14"

# Sign + width + precision
"{:+8.2}".fmt(3.14)            # "   +3.14"
```

#### Escaped Braces

To include literal braces in the output, double them:

```quest
"Use {{}} for braces".fmt()    # "Use {} for braces"
"{{name}}".fmt()               # "{name}"
"Set: {{1, 2, 3}}".fmt()       # "Set: {1, 2, 3}"
```

### Format Specifier Syntax

The full format syntax is:
```
{[argument]:[fill][align][sign][#][0][width][.precision][type]}
```

Where:
- `argument`: Position (0, 1, ...) or name (optional)
- `fill`: Any character (default is space)
- `align`: `<` (left), `>` (right), `^` (center)
- `sign`: `+` (always), `-` (negative only, default), ` ` (space for positive)
- `#`: Alternate form (0x, 0b, 0o prefixes)
- `0`: Zero-padding (shorthand for `:0>`)
- `width`: Minimum width in characters
- `precision`: Number of decimal places for floats
- `type`: `x` (hex), `X` (HEX), `b` (binary), `o` (octal), `e` (scientific), `E` (SCIENTIFIC)

## String concatenation

```
# Evaluates as: str_literal .. obj.str() .. string_literal .. expr
# expression here evaluates to a num and num.str() is accessed to provide
# the string.
"String" .. obj .. "adf" .. (3 + 4)
```

## Multi-Line Strings
```
"""
This is a multi-line string
   Newline and indention levels are retained
But whitespace after the opening quotes 
and whitespace after the last line are ignored.
"""
```

## Documentation Blocks

Quest has python style documentation blocks that use multi-line string syntax

```
type Cat {
    """
    Soft kitty
    Warm kitty
    Little ball of fur
    """
}
puts(Cat._doc())
# Output:
# Soft kitty
# Warm kitty
# Little ball of fur
```

## String Methods
capitalize() Returns a new string with the first character to upper case 
count()	Returns the number of times a specified value occurs in a string
encode() Returns an encoded version of the string
endswith() Returns true if the string ends with the specified value
expandtabs() Sets the tab size of the string
isalnum()	Returns True if all characters in the string are alphanumeric
isalpha()	Returns True if all characters in the string are in the alphabet
isascii()	Returns True if all characters in the string are ascii characters
isdecimal()	Returns True if all characters in the string are decimals
isdigit()	Returns True if all characters in the string are digits
islower()	Returns True if all characters in the string are lower case
isnumeric()	Returns True if all characters in the string are numeric
isspace()	Returns True if all characters in the string are whitespaces
istitle()	Returns True if the string follows the rules of a title
isupper()	Returns True if all characters in the string are upper case
lower()	Converts a string into lower case
ltrim()	Returns a left trim version of the string
rtrim()	Returns a right trim version of the string
trim()	Returns a trimmed version of the string
title()	Converts the first character of each word to upper case
upper()	Converts a string into upper case
