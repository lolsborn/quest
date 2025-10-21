# Vibe Quest

A vibe-coded scripting language focused on developer happiness with a REPL implementation in Rust.

**[📖 Full Documentation](https://quest.bitsetters.com/)**

## Philosophy

Everything in Quest is an object (including primitives like numbers and booleans), and all operations are method calls. Quest aims to make programming intuitive and enjoyable with clear syntax and powerful built-in capabilities.

## Features

Quest has a lot of features inspired by different languages that include:

- **Pure Object-Oriented** (Ruby): Everything is an object with methods
- **Interactive REPL** (Python): Multi-line REPL with smart indentation
- **Strong Type System** (Rust): User-defined types with traits, optional fields, and class methods
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
quest  # Start the REPL (standard library auto-extracts to ~/.quest/lib on first run)
quest path/to/script.q  # Run a script
```

**Note**: On first run, Quest automatically extracts its standard library to `~/.quest/lib/`. You can customize the stdlib by editing files in this directory.

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
# Run full test suite
quest test

# Run specific test file
quest test test/web/web_test.q
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

## Quick Examples

### Hello World

```quest
puts("Hello, World!")
```

### Variables and Functions

```quest
let name = "Alice"
let age = 30

fun greet(name)
    "Hello, " .. name
end

puts(greet(name))
```

### User-Defined Types

```quest
type Person
    name: str
    age: num?

    fun greet()
        "Hello, I'm " .. self.name
    end
end

let alice = Person.new(name: "Alice", age: 30)
puts(alice.greet())
```

## Standard Library

Quest includes a comprehensive standard library with modules for:

- **Core**: Math, time, decimal arithmetic, UUID generation
- **Encoding**: JSON, Base64, hex, URL, CSV, binary structs
- **Security**: Hashing (SHA256, MD5, bcrypt), HMAC, cryptography
- **I/O**: File operations, directory management, environment variables
- **Web**: HTTP client, URL parsing, HTML templates
- **Database**: SQLite, PostgreSQL, MySQL with prepared statements
- **Compression**: Gzip, Bzip2, Deflate, Zlib
- **Utilities**: Regex, logging, terminal styling, serial communication, random numbers
- **Testing**: Test framework with assertions and discovery

**[View full standard library documentation](https://quest.bitsetters.com/stdlib/)**

## Built-in Types

Quest provides rich built-in types, all with comprehensive method support:

- **Numbers**: Int, Float, BigInt, Decimal (arbitrary precision)
- **Text**: Str (UTF-8), Bytes (binary data)
- **Collections**: Array, Dict, Set
- **Other**: Bool, Nil, Uuid, Time types (Timestamp, Zoned, Date, Time, Span)

Every type supports method calls. For example:
```quest
let x = 42
x.plus(8)      # => 50

let s = "hello"
s.upper()      # => "HELLO"

let arr = [1, 2, 3]
arr.map(fun(x) x * 2 end)  # => [2, 4, 6]
```

## Testing

Quest includes a comprehensive testing framework with automatic test discovery:

```quest
use "std/test" as test

test.module("Math Operations")

test.describe("Addition", fun ()
    test.it("adds two numbers", fun ()
        test.assert_eq(2.plus(2), 4)
    end)
end)
```

Run tests with tag filtering for fast/slow tests, integration tests, and more.

## Documentation

**[📖 quest.bitsetters.com](https://quest.bitsetters.com/)** - Complete language documentation, tutorials, and API reference

Additional resources:
- [CLAUDE.md](CLAUDE.md) - Project documentation for contributors and AI assistants
- [docs/PROFILING.md](docs/PROFILING.md) - Performance profiling guide

## Contributing

Quest is a personal project focused on exploring language design and implementation. If you're interested in similar projects or have feedback, feel free to open an issue.

## License

See [LICENSE](LICENSE)

## Author

Steven Osborn
