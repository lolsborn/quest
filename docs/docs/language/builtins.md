# Built-in Functions

Quest provides several built-in functions that are always available without needing to import any modules.

## Output Functions

### `puts(args...)`

Prints values to stdout, followed by a newline. Multiple arguments are printed without separators.

**Arguments:** Any number of values

**Returns:** `nil`

**Example:**
```quest
puts("Hello, World!")           # Hello, World!
puts("Answer:", 42)             # Answer:42
puts("x =", 5, "y =", 10)      # x =5y =10
```

### `print(args...)`

Prints values to stdout without a trailing newline.

**Arguments:** Any number of values

**Returns:** `nil`

**Example:**
```quest
print("Loading")
print(".")
print(".")
print(".")
puts(" Done!")
# Output: Loading... Done!
```

## Utility Functions

### `len(value)`

Returns the length of a collection or string.

**Arguments:**
- `value` - An array, dict, or string

**Returns:** Number - the length/size

**Example:**
```quest
let arr = [1, 2, 3, 4, 5]
puts(len(arr))              # 5

let text = "hello"
puts(len(text))             # 5

let dict = {"a": 1, "b": 2}
puts(len(dict))             # 2
```

### `chr(codepoint)`

Converts a Unicode codepoint (integer) to a character string.

**Arguments:**
- `codepoint` - Integer Unicode codepoint (0-1114111)

**Returns:** Str - Single character string

**Raises:** Error if codepoint is invalid

**Example:**
```quest
# ASCII characters
puts(chr(65))           # A
puts(chr(90))           # Z
puts(chr(97))           # a

# Build strings from codepoints
let hello = chr(72) .. chr(101) .. chr(108) .. chr(108) .. chr(111)
puts(hello)             # Hello

# Special characters
puts(chr(32))           # (space)
puts(chr(10))           # (newline)
puts(chr(9))            # (tab)

# Unicode characters
puts(chr(8364))         # €
puts(chr(9731))         # ☃
puts(chr(128077))       # 👍

# Character arithmetic (Caesar cipher)
let shifted = chr(ord("A") + 3)
puts(shifted)           # D

# Invalid codepoint
try
    chr(0xFFFFFFFF)     # Error: Invalid Unicode codepoint
catch e
    puts(e.message())
end
```

### `ord(string)`

Returns the Unicode codepoint of the first character in a string.

**Arguments:**
- `string` - Non-empty string

**Returns:** Int - Unicode codepoint of first character

**Raises:** Error if string is empty

**Example:**
```quest
# ASCII characters
puts(ord("A"))          # 65
puts(ord("Z"))          # 90
puts(ord("a"))          # 97

# Unicode characters
puts(ord("€"))          # 8364
puts(ord("👍"))         # 128077

# Multi-character strings (takes first char)
puts(ord("Hello"))      # 72 (H)

# Roundtrip with chr()
puts(chr(ord("A")))     # A

# Character ranges
let a_code = ord("A")
let z_code = ord("Z")
puts(z_code - a_code)   # 25 (26 letters)

# Empty string error
try
    ord("")
catch e
    puts(e.message())   # ord expects non-empty string
end
```

**Note:** `ord()` is also available as a String method: `"A".ord()` returns `65`.


## Type Checking

Quest is dynamically typed, but you can check types at runtime:

```quest
let x = 5
puts(x.cls())  # "Num"

let s = "hello"
puts(s.cls())  # "Str"
```

## See Also

- [Standard Library](../stdlib/index.md) - Additional functions in modules
- [time module](../stdlib/time.md) - Calendar and timezone-aware time operations
- [sys module](../stdlib/sys.md) - System information and script metadata
