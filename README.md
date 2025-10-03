# Vibe Quest

A vibe-coded scripting language focused on developer happiness with a REPL implementation in Rust.

## Philosophy

Everything in Quest is an object (including primitives like numbers and booleans), and all operations are method calls. Quest aims to make programming intuitive and enjoyable with clear syntax and powerful built-in capabilities.

## Features

Quest has a lot of features inspired by different languages that include:

- **Pure Object-Oriented** (Ruby): Everything is an object with methods
- **Interactive REPL** (Python): Multi-line REPL with smart indentation
- **Strong Type System** (Rust): User-defined types with traits, optional fields, and static methods
- **Exception Handling** (Ruby): try/catch/ensure/raise with full stack traces
- **Rich Standard Library** (Python): Modules for math, JSON, hashing, file I/O, terminal styling, regex, serial communication, and more
- **Functional Programming** (JavaScript/Ruby): Lambdas, closures, and higher-order functions
- **Clean Module System** (Golang): Import with `use`, namespace isolation
- **Doc Strings** (Python): Built-in documentation for functions and methods
- **String Interpolation** (Python): f-string and b-string interpolation for dynamic content

## Quick Start

### Building

```bash
cargo build --release
```

### Running the REPL

```bash
./target/release/quest
# or
cargo run --release
```

### Running a Script

```bash
./target/release/quest path/to/script.q
```

### Running Tests

```bash
# Run all tests (508 tests)
./test_all.sh

# Run main test suite (501 tests)
./target/release/quest test/run.q

# Run sys module tests (7 tests)
./target/release/quest test/sys/basic.q
```

## Language Examples

### Hello World

```quest
puts("Hello, World!")
```

### Variables and Types

```quest
let name = "Alice"
let age = 30
let is_admin = true
let data = b"\xFF\x01\x42"  # Bytes literal

puts("Name: " .. name)
puts("Age: " .. age.plus(1)._str())
```

### Control Flow

```quest
# Block if/elif/else
if age < 18
    puts("Minor")
elif age < 65
    puts("Adult")
else
    puts("Senior")
end

# Inline if (ternary)
let status = "admin" if is_admin else "user"

# Loops
while age < 100
    age = age + 1
end

for i in 0..10
    puts(i)
end
```

### Functions

```quest
fun greet(name)
    "Hello, " .. name
end

puts(greet("Bob"))

# Lambda
let double = fun(x) x * 2 end
puts(double(5))
```

### User-Defined Types

```quest
type Person
    str: name
    num?: age        # Optional field

    fun greet()
        "Hello, I'm " .. self.name
    end

    static fun default()
        Person.new(name: "Unknown")
    end
end

let alice = Person.new(name: "Alice", age: 30)
puts(alice.greet())

let stranger = Person.default()
```

### Traits

```quest
trait Drawable
    fun draw()
end

type Circle
    num: radius

    impl Drawable
        fun draw()
            "Drawing circle with radius " .. self.radius
        end
    end
end

let c = Circle.new(radius: 5.0)
puts(c.draw())
```

### Exception Handling

```quest
try
    risky_operation()
catch e
    puts("Error: " .. e.message())
    puts("Stack: " .. e.stack()._str())
ensure
    cleanup()  # Always runs
end
```

### Modules

```quest
use "std/math" as math
use "std/encoding/json" as json
use "std/hash" as hash
use "std/io" as io

puts(math.pi)
puts(math.sin(math.pi / 2))

let data = {"name": "Alice", "age": 30}
let json_str = json.stringify(data)
puts(json_str)

let hash_val = hash.sha256("Hello")
puts(hash_val)

io.write("test.txt", "Hello, World!")
let content = io.read("test.txt")
puts(content)
```

## Standard Library

Quest includes a comprehensive standard library:

- **math**: Trigonometric functions (sin, cos, tan), rounding (floor, ceil, round), constants (pi, tau)
- **encoding/json**: JSON parsing and stringification with pretty-printing
- **encoding/b64**: Base64 encoding/decoding (standard and URL-safe)
- **hash**: Cryptographic hashing (MD5, SHA1, SHA256, SHA512, CRC32, bcrypt)
- **crypto**: HMAC operations (HMAC-SHA256, HMAC-SHA512)
- **io**: File operations (read, write, append, remove, exists, glob)
- **term**: Terminal styling (colors, bold, italic, underline)
- **regex**: Pattern matching, search, replace, split, capture groups
- **serial**: Serial port communication for Arduino and microcontrollers
- **test**: Testing framework with assertions and test discovery

See [docs/stdlib/](docs/docs/stdlib/) for detailed module documentation.

## Built-in Types

All types support method calls:

### Num
```quest
let x = 42
x.plus(8)        # => 50
x.times(2)       # => 84
x.mod(5)         # => 2
x._str()         # => "42"
```

### Str
```quest
let s = "hello"
s.upper()        # => "HELLO"
s.len()          # => 5
s.slice(0, 2)    # => "he"
s.split("l")     # => ["he", "", "o"]
s.concat(" world")  # => "hello world"
```

### Bytes
```quest
let b = b"\xFF\x00"
b.len()          # => 2
b.get(0)         # => 255
b.decode("hex")  # => "ff00"
b.to_array()     # => [255, 0]
```

### Bool
```quest
let t = true
t.eq(false)      # => false
t._str()         # => "true"
```

### Array
```quest
let arr = [1, 2, 3]
arr.map(fun(x) x * 2 end)     # => [2, 4, 6]
arr.filter(fun(x) x > 1 end)  # => [2, 3]
arr.reduce(fun(a, b) a + b end, 0)  # => 6
arr.push(4)      # => [1, 2, 3, 4]
```

### Dict
```quest
let d = {"x": 10, "y": 20}
d.get("x")       # => 10
d.set("z", 30)   # => {"x": 10, "y": 20, "z": 30}
d.keys()         # => ["x", "y", "z"]
d.values()       # => [10, 20, 30]
```

## Testing

Quest uses the `std/test` framework. Tests are automatically discovered from files matching `test_*.q` or `*_test.q`:

```quest
use "std/test" as test

test.module("Math Operations")

test.describe("Addition", fun ()
    test.it("adds two numbers", fun ()
        test.assert_eq(2.plus(2), 4, nil)
    end)

    test.it("handles negatives", fun ()
        test.assert_eq((-5).plus(3), -2, nil)
    end)
end)
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Comprehensive project documentation for AI assistants
- [docs/docs/stdlib/](docs/docs/stdlib/) - Standard library module documentation
- [docs/docs/language/](docs/docs/language/) - Language features and syntax
- [docs/docs/types/](docs/docs/types/) - Type system documentation

## Contributing

Quest is a personal project focused on exploring language design and implementation. If you're interested in similar projects or have feedback, feel free to open an issue.

## License

See [LICENSE](LICENSE)

## Author

Steven Osborn
