#!/usr/bin/env quest
# Quest Syntax Highlighting Test File
# This file demonstrates all syntax elements for testing vim highlighting

# ============================================================================
# KEYWORDS
# ============================================================================

let x = 10
const PI = 3.14159

if x > 5
    puts("greater")
elif x < 5
    puts("less")
else
    puts("equal")
end

while x > 0
    x = x - 1
end

for item in [1, 2, 3]
    puts(item)
end

for i in 0 until 10
    continue if i == 5
    break if i == 8
end

# ============================================================================
# FUNCTIONS
# ============================================================================

fun simple_function(a, b)
    return a + b
end

fun with_types(int: x, str: name, bool?: optional)
    puts(f"x={x}, name={name}")
end

fun class_method()
    return 42
end

# ============================================================================
# TYPES AND TRAITS
# ============================================================================

type Point
    pub x: Int
    pub y: Int

    fun distance()
        ((self.x ** 2) + (self.y ** 2)) ** 0.5
    end

    fun self.origin()
        Point.new(x: 0, y: 0)
    end
end

trait Drawable
    fun draw()
end

type Circle
    radius: Int

    impl Drawable
        fun draw()
            puts("Drawing circle")
        end
    end
end

# ============================================================================
# NUMBERS
# ============================================================================

# Integers
let dec = 42
let hex = 0xFF
let bin = 0b11111111
let oct = 0o755
let underscore = 1_000_000

# Floats
let f1 = 3.14
let f2 = 1e10
let f3 = 2.5e-3

# BigInt
let big = 999999999999999999999999n
let big_hex = 0xDEADBEEFn
let big_bin = 0b11111111n

# ============================================================================
# STRINGS
# ============================================================================

# Regular strings
let s1 = "double quotes"
let s2 = 'single quotes'

# F-strings (interpolation)
let name = "Alice"
let greeting = f"Hello {name}!"

# Triple-quoted
let multi = """
    This is a
    multi-line string
    with "quotes" inside
"""

# Escape sequences
let escaped = "Line 1\nLine 2\tTabbed"
let hex_escape = "\x41\x42\x43"

# Bytes
let b1 = b"bytes literal"
let b2 = b"\xFF\x00\xAB"

# ============================================================================
# OPERATORS AND EXPRESSIONS
# ============================================================================

# Arithmetic
let add = 1 + 2
let sub = 10 - 5
let mul = 3 * 4
let div = 20 / 4
let mod = 17 % 5
let pow = 2 ** 8

# Comparison
let eq = (a == b)
let neq = (a != b)
let lt = (a < b)
let gt = (a > b)
let lte = (a <= b)
let gte = (a >= b)

# Logical
let and_op = true and false
let or_op = true or false
let not_op = not false

# String concatenation
let concat = "hello" .. " " .. "world"

# Elvis operator (optional chaining)
let safe = user?.profile?.email

# Safe assignment (if implemented)
let err, value = ?= risky_operation()

# ============================================================================
# COLLECTIONS
# ============================================================================

# Arrays
let arr = [1, 2, 3, 4, 5]
let nested = [[1, 2], [3, 4], [5, 6]]
let mixed = [1, "two", 3.0, true, nil]

# Dictionaries
let dict = {
    "name": "Alice",
    "age": 30,
    "active": true
}

# Sets (if implemented)
let set = Set.new([1, 2, 3])

# ============================================================================
# EXCEPTION HANDLING
# ============================================================================

try
    let result = risky_operation()
    raise "Something went wrong" if result == nil
catch IOError as e
    puts("IO Error: " .. e.message())
catch e
    puts("Error: " .. e.message())
ensure
    cleanup()
end

# ============================================================================
# CONTEXT MANAGERS
# ============================================================================

with file_handle as f
    f.write("data")
end

# ============================================================================
# MODULE USAGE
# ============================================================================

use "std/ndarray" as np
use "std/io"
use "std/hash"

let m = np.zeros([3, 3])
let data = io.read("file.txt")
let digest = hash.md5("data")

# ============================================================================
# BUILT-IN TYPES AND CONSTANTS
# ============================================================================

# Type checking
let is_int = value.is(Int)
let is_array = value.is(Array)

# BigInt constants
let zero = ZERO
let one = ONE
let two = TWO
let ten = TEN

# ============================================================================
# SPECIAL SYNTAX
# ============================================================================

# Named arguments
let p = Point.new(x: 10, y: 20)

# Multiple assignment
let a, b, c = [1, 2, 3]

# Inline if
let result = value if condition else default

# Range
for i in 0 until 10
    puts(i)
end

# ============================================================================
# COMMENTS AND TODO
# ============================================================================

# TODO: Implement this feature
# FIXME: This needs to be fixed
# XXX: Dangerous code here
# NOTE: Important information

# This is a regular comment
## Nested comment style (still just a comment)

# End of syntax test file
