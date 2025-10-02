

## String Literal
```quest
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
```quest
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

```quest
# Evaluates as: str_literal .. obj.str() .. string_literal .. expr
# expression here evaluates to a num and num.str() is accessed to provide
# the string.
"String" .. obj .. "adf" .. (3 + 4)
```

## Multi-Line Strings
```quest
"""
This is a multi-line string
   Newline and indention levels are retained
But whitespace after the opening quotes 
and whitespace after the last line are ignored.
"""
```

## Documentation Blocks

Quest has python style documentation blocks that use multi-line string syntax

```quest
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

### `capitalize()`
Returns a new string with the first character converted to upper case and the rest lower case.

**Returns:** Str

**Example:**
```quest
let text = "hello world"
puts(text.capitalize())  # Hello world

let caps = "HELLO WORLD"
puts(caps.capitalize())  # Hello world
```

### `count(substring)`
Returns the number of times a substring occurs in the string.

**Parameters:**
- `substring` - Substring to count

**Returns:** Num

**Example:**
```quest
let text = "hello world"
puts(text.count("l"))    # 3
puts(text.count("o"))    # 2
puts(text.count("ll"))   # 1
puts(text.count("x"))    # 0
```

### `encode(encoding)`
Returns an encoded version of the string.

**Parameters:**
- `encoding` - Encoding type (e.g., "utf-8", "ascii")

**Returns:** Str

**Example:**
```quest
let text = "hello"
let encoded = text.encode("utf-8")
puts(encoded)
```

### `endswith(suffix)`
Returns `true` if the string ends with the specified suffix.

**Parameters:**
- `suffix` - String to check at end

**Returns:** Bool

**Example:**
```quest
let filename = "document.txt"
puts(filename.endswith(".txt"))   # true
puts(filename.endswith(".pdf"))   # false

let path = "/home/user/"
puts(path.endswith("/"))          # true
```

### `expandtabs(tabsize)`
Replaces tab characters with spaces using the specified tab size.

**Parameters:**
- `tabsize` - Number of spaces per tab

**Returns:** Str

**Example:**
```quest
let text = "hello\tworld"
puts(text.expandtabs(4))   # hello    world
puts(text.expandtabs(8))   # hello        world
```

### `isalnum()`
Returns `true` if all characters in the string are alphanumeric (letters or numbers).

**Returns:** Bool

**Example:**
```quest
puts("abc123".isalnum())    # true
puts("hello".isalnum())     # true
puts("123".isalnum())       # true
puts("hello world".isalnum())  # false (has space)
puts("hello!".isalnum())    # false (has punctuation)
```

### `isalpha()`
Returns `true` if all characters in the string are alphabetic letters.

**Returns:** Bool

**Example:**
```quest
puts("hello".isalpha())     # true
puts("HelloWorld".isalpha()) # true
puts("hello123".isalpha())  # false (has numbers)
puts("hello world".isalpha()) # false (has space)
```

### `isascii()`
Returns `true` if all characters in the string are ASCII characters.

**Returns:** Bool

**Example:**
```quest
puts("hello".isascii())     # true
puts("hello123".isascii())  # true
puts("hello!@#".isascii())  # true
```

### `isdecimal()`
Returns `true` if all characters in the string are decimal digits.

**Returns:** Bool

**Example:**
```quest
puts("12345".isdecimal())   # true
puts("123.45".isdecimal())  # false (has decimal point)
puts("123a".isdecimal())    # false (has letter)
```

### `isdigit()`
Returns `true` if all characters in the string are digits.

**Returns:** Bool

**Example:**
```quest
puts("12345".isdigit())     # true
puts("0".isdigit())         # true
puts("123a".isdigit())      # false
puts("12.34".isdigit())     # false
```

### `islower()`
Returns `true` if all alphabetic characters in the string are lower case.

**Returns:** Bool

**Example:**
```quest
puts("hello".islower())     # true
puts("hello123".islower())  # true
puts("Hello".islower())     # false
puts("HELLO".islower())     # false
```

### `isnumeric()`
Returns `true` if all characters in the string are numeric.

**Returns:** Bool

**Example:**
```quest
puts("12345".isnumeric())   # true
puts("123".isnumeric())     # true
puts("12.34".isnumeric())   # false
puts("12a".isnumeric())     # false
```

### `isspace()`
Returns `true` if all characters in the string are whitespace.

**Returns:** Bool

**Example:**
```quest
puts("   ".isspace())       # true
puts("\t\n".isspace())      # true
puts("  a  ".isspace())     # false
puts("".isspace())          # false
```

### `istitle()`
Returns `true` if the string follows title case rules (first letter of each word capitalized).

**Returns:** Bool

**Example:**
```quest
puts("Hello World".istitle())    # true
puts("Hello world".istitle())    # false
puts("HELLO WORLD".istitle())    # false
puts("hello world".istitle())    # false
```

### `isupper()`
Returns `true` if all alphabetic characters in the string are upper case.

**Returns:** Bool

**Example:**
```quest
puts("HELLO".isupper())     # true
puts("HELLO123".isupper())  # true
puts("Hello".isupper())     # false
puts("hello".isupper())     # false
```

### `lower()`
Converts all characters in the string to lower case.

**Returns:** Str

**Example:**
```quest
let text = "HELLO WORLD"
puts(text.lower())          # hello world

let mixed = "HeLLo WoRLd"
puts(mixed.lower())         # hello world
```

### `ltrim()`
Removes whitespace from the left (beginning) of the string.

**Returns:** Str

**Example:**
```quest
let text = "   hello world"
puts(text.ltrim())          # hello world

let tabs = "\t\thello"
puts(tabs.ltrim())          # hello
```

### `rtrim()`
Removes whitespace from the right (end) of the string.

**Returns:** Str

**Example:**
```quest
let text = "hello world   "
puts(text.rtrim())          # hello world

let newlines = "hello\n\n"
puts(newlines.rtrim())      # hello
```

### `trim()`
Removes whitespace from both ends of the string.

**Returns:** Str

**Example:**
```quest
let text = "   hello world   "
puts(text.trim())           # hello world

let mixed = "\t\nhello\n\t"
puts(mixed.trim())          # hello
```

### `title()`
Converts the first character of each word to upper case.

**Returns:** Str

**Example:**
```quest
let text = "hello world"
puts(text.title())          # Hello World

let lower = "the quick brown fox"
puts(lower.title())         # The Quick Brown Fox
```

### `upper()`
Converts all characters in the string to upper case.

**Returns:** Str

**Example:**
```quest
let text = "hello world"
puts(text.upper())          # HELLO WORLD

let mixed = "HeLLo WoRLd"
puts(mixed.upper())         # HELLO WORLD
```

### `split(delimiter)`
Splits the string by delimiter and returns an array of substrings.

**Parameters:**
- `delimiter` - String to split on (empty string splits into characters)

**Returns:** Array

**Example:**
```quest
let text = "hello,world,quest"
let parts = text.split(",")
puts(parts)                 # [hello, world, quest]

let sentence = "hello world"
let words = sentence.split(" ")
puts(words)                 # [hello, world]

# Split into characters
let chars = "hello".split("")
puts(chars)                 # [h, e, l, l, o]
```

### `slice(start, end)`
Extracts a substring from start index to end index (exclusive). Supports negative indices.

**Parameters:**
- `start` - Starting index (negative counts from end)
- `end` - Ending index, exclusive (negative counts from end)

**Returns:** Str

**Example:**
```quest
let text = "hello world"
puts(text.slice(0, 5))      # hello
puts(text.slice(6, 11))     # world
puts(text.slice(0, -6))     # hello
puts(text.slice(-5, 11))    # world
```
