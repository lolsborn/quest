# Vibe Quest

A vibe-coded scripting language focused on developer happiness with a REPL implementation in Rust.

## Philosophy

Everything in Quest is an object (including primitives like numbers and booleans), and all operations are method calls. Quest aims to make programming intuitive and enjoyable with clear syntax and powerful built-in capabilities.

## Features

Quest has a lot of features inspired by different languages that include:

- **Pure Object-Oriented** (Ruby): Everything is an object with methods
- **Interactive REPL** (Python): Multi-line REPL with smart indentation
- **Strong Type System** (Rust): User-defined types with traits, optional fields, and static methods
- **Doc Strings** (Python): Built-in documentation for functions and methods
- **String Interpolation** (Python): f-string and b-string interpolation for dynamic content
- **Functional Programming** (JavaScript/Ruby): Lambdas, closures, and higher-order functions
- **Rich Standard Library** (Python): Modules for math, JSON, hashing, file I/O, terminal styling, regex, serial communication, and more
- **Clean Module System** (Golang): Import with `use`, namespace isolation

## Installation

### From crates.io (Recommended)

Install the latest stable release from crates.io:

```bash
cargo install vibequest
```

The `quest` command will be available after installation:

```bash
quest  # Start the REPL
quest path/to/script.q  # Run a script
```

### Nightly Builds

Download pre-compiled binaries from the [nightly releases](https://github.com/lolsborn/quest/releases/tag/nightly) page. Nightly builds are automatically created daily from the latest `main` branch.

**Linux (x86_64)**:
```bash
wget https://github.com/lolsborn/quest/releases/download/nightly/vibequest-nightly-linux-x86_64.tar.gz
tar xzf vibequest-nightly-linux-x86_64.tar.gz
chmod +x quest
sudo mv quest /usr/local/bin/
```

**macOS (Apple Silicon)**:
```bash
curl -L https://github.com/lolsborn/quest/releases/download/nightly/vibequest-nightly-macos-aarch64.tar.gz -o vibequest.tar.gz
tar xzf vibequest.tar.gz
chmod +x quest
sudo mv quest /usr/local/bin/
```

**Windows**: Download `vibequest-nightly-windows-x86_64.exe.zip` and extract to your PATH.

See the [nightly releases page](https://github.com/lolsborn/quest/releases/tag/nightly) for all available platforms including ARM64.

### Building from Source

```bash
git clone https://github.com/lolsborn/quest.git
cd quest
cargo build --release
./target/release/quest
```

## Quick Start

### Running the REPL

```bash
quest
```

### Running a Script

```bash
quest path/to/script.q
```

### Running Tests

```bash
# Run all tests (791 tests)
quest scripts/qtest

# Run specific test file
quest test/arrays/basic.q
```

### Profiling

Quest includes comprehensive profiling tools for performance analysis:

```bash
# CPU profiling (with samply)
./scripts/profile-cpu.sh

# Memory profiling (with dhat)
./scripts/profile-memory.sh

# Generate flame graphs
./scripts/profile-flamegraph.sh
```

See [docs/PROFILING.md](docs/PROFILING.md) for detailed profiling instructions.

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
    name: str
    age: num?        # Optional field

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
    radius: num

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

### I/O Redirection

```quest
use "std/sys"
use "std/io"

# Capture output to buffer
let buffer = io.StringIO.new()
with sys.redirect_stream(sys.stdout, buffer)
    puts("This goes to the buffer")
    puts("So does this")
end  # Automatic restoration

puts("Captured output:")
puts(buffer.get_value())

# Redirect stderr to stdout (like shell 2>&1)
let buf = io.StringIO.new()
let g1 = sys.redirect_stream(sys.stdout, buf)
let g2 = sys.redirect_stream(sys.stderr, sys.stdout)
puts("Normal")
sys.stderr.write("Error\n")
g2.restore()
g1.restore()
puts("Combined: " .. buf.get_value())
```

## Standard Library

Quest includes a comprehensive standard library:

- **math**: Trigonometric functions (sin, cos, tan), rounding (floor, ceil, round), constants (pi, tau)
- **time**: Comprehensive date/time handling (timestamps, timezones, dates, times, spans, formatting)
- **decimal**: Arbitrary precision decimals for financial calculations
- **uuid**: UUID generation (v1, v3, v4, v5, v6, v7, v8) and manipulation
- **encoding/json**: JSON parsing and stringification with pretty-printing
- **encoding/b64**: Base64 encoding/decoding (standard and URL-safe)
- **encoding/hex**: Hexadecimal encoding/decoding
- **encoding/url**: URL encoding/decoding
- **encoding/csv**: CSV parsing and generation
- **encoding/struct**: Binary data packing/unpacking
- **hash**: Cryptographic hashing (MD5, SHA1, SHA256, SHA512, CRC32, bcrypt)
- **crypto**: HMAC operations (HMAC-SHA256, HMAC-SHA512)
- **io**: File operations (read, write, append, remove, exists, glob, StringIO in-memory buffers)
- **os**: Operating system interfaces (directory operations, environment variables)
- **sys**: System module (argv, exit, load_module, version, platform, I/O redirection)
- **settings**: Configuration management via .settings.toml files
- **term**: Terminal styling (colors, bold, italic, underline)
- **regex**: Pattern matching, search, replace, split, capture groups
- **serial**: Serial port communication for Arduino and microcontrollers
- **rand**: Random number generation (secure and fast RNGs, distributions)
- **compress/gzip**: Gzip compression and decompression
- **compress/bzip2**: Bzip2 compression (better compression ratio)
- **compress/deflate**: Raw deflate compression
- **compress/zlib**: Zlib compression with checksums
- **db/sqlite**: SQLite database interface with full CRUD support
- **db/postgres**: PostgreSQL database interface with prepared statements
- **db/mysql**: MySQL database interface with transaction support
- **html/templates**: Tera-based HTML templating (Jinja2-like syntax)
- **http/client**: HTTP client for REST APIs and web requests
- **http/urlparse**: URL parsing and manipulation
- **log**: Python-inspired logging framework with handlers and formatters
- **test**: Testing framework with assertions and test discovery

See [docs/stdlib/](docs/docs/stdlib/) for detailed module documentation.

## Built-in Types

All types support method calls:

### Int, Float, and Decimal
```quest
let x = 42           # Int
x.plus(8)            # => 50 (Int)
x.times(2)           # => 84 (Int)
x.mod(5)             # => 2 (Int)

let y = 3.14         # Float
y.plus(1.0)          # => 4.14 (Float)
y.round()            # => 3.0 (Float)
x.plus(y)            # => 45.14 (promoted to Float)

use "std/decimal"
let d = decimal.new("123.456789")  # Decimal (arbitrary precision)
d.plus(decimal.new("0.000001"))    # No floating-point errors
d.times(decimal.new("2"))          # Exact multiplication
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

### Set
```quest
let s = Set.new([1, 2, 3, 2, 1])
s.len()          # => 3 (duplicates removed)
s.contains(2)    # => true
s.add(4)         # => Set{1, 2, 3, 4}
s.remove(1)      # => Set{2, 3, 4}
s.union(Set.new([3, 4, 5]))        # => Set{2, 3, 4, 5}
s.intersection(Set.new([2, 3]))    # => Set{2, 3}
```

### Uuid
```quest
use "std/uuid"

let id = uuid.v4()                 # Random UUID
id.to_string()                     # "550e8400-e29b-41d4-a716-446655440000"

let sorted_id = uuid.v7()          # Time-ordered UUID (best for DB keys)
sorted_id.version()                # => 7
```

### Time Types
```quest
use "std/time"

let now = time.now()               # Timestamp (UTC)
let local = time.now_local()       # Zoned (with timezone)
let today = time.today()           # Date

local.year()                       # => 2025
local.month()                      # => 10
local.format("%Y-%m-%d %H:%M")     # => "2025-10-05 14:30"

let span = time.hours(2)           # Span (duration)
let later = local.add(span)        # Add 2 hours
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

### Test Tags

Tests can be tagged for selective execution. Tags can be applied to entire describe blocks or individual tests:

```quest
# Tag entire describe block (all tests inherit the tag)
test.tag("slow")
test.describe("HTTP tests", fun ()
    test.it("fetches data", fun () ... end)
    test.it("posts data", fun () ... end)
end)

# Tag individual tests
test.describe("Mixed tests", fun ()
    test.tag("fast")
    test.it("quick test", fun () ... end)

    test.tag(["slow", "db"])  # Multiple tags
    test.it("database test", fun () ... end)
end)

# Tags merge: describe + individual
test.tag("integration")
test.describe("Integration tests", fun ()
    test.tag("critical")
    test.it("critical test", fun () ... end)  # Has both: [integration, critical]
end)
```

Run tests with tag filtering:
```bash
# Run only tests tagged as "fast"
./target/release/quest scripts/qtest --tag=fast

# Skip tests tagged as "slow"
./target/release/quest scripts/qtest --skip-tag=slow
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
