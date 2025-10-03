# Standard Library

Quest includes a carefully curated standard library with modules for common tasks.

## Importing Modules

Use the `use` statement to import modules:

```quest
use "std/math" as math
puts(math.pi)  # 3.141592653589793
```

## Available Modules

### Mathematics and Numerics

- **[math](./math.md)** - Mathematical functions (sin, cos, sqrt, etc.) and constants (pi, e)

### String Processing

- **[str](./str.md)** - String manipulation utilities
- **[regex](./regex.md)** - Regular expression pattern matching and text manipulation

### Data Encoding

- **[json](./json.md)** - JSON encoding and decoding (`std/encoding/json`)
- **[base64](./encode.md)** - Base64 encoding and decoding (`std/encoding/b64`)

### Data Types

- **[uuid](./uuid.md)** - Universally Unique Identifiers (UUIDs) for globally unique IDs

### Database

- **[database](./database.md)** - Database connectivity for SQLite, PostgreSQL, and MySQL

### Cryptography

- **[hash](./hash.md)** - Cryptographic hash functions (MD5, SHA1, SHA256, SHA512)
- **[crypto](./crypto.md)** - HMAC and other cryptographic functions

### Input/Output

- **[io](./io.md)** - File and stream I/O operations
- **[serial](./serial.md)** - Serial port communication for Arduino, microcontrollers, and devices

### System Integration

- **[sys](./sys.md)** - System information and command-line arguments
- **[os](./os.md)** - Operating system interfaces
- **[time](./time.md)** - Date and time operations

### Terminal

- **[term](./term.md)** - Terminal colors and text formatting

### Development

- **[test](./test.md)** - Unit testing framework

## Module Usage Patterns

### Basic Import

```quest
use "std/math" as math
let result = math.sqrt(16)  # 4
```

### Multiple Imports

```quest
use "std/encoding/json" as json
use "std/io" as io

let data = {"name": "Quest", "version": "1.0"}
let text = json.stringify(data)
io.write("data.json", text)
```

### Module Members

Modules can contain:
- **Functions**: Callable operations
- **Constants**: Read-only values (like `math.pi`)

Access members using dot notation:

```quest
use "std/math" as m

puts(m.pi)           # Constant
puts(m.sin(m.pi))    # Function call
```

## Creating Your Own Modules

Quest modules are simply `.q` files that export values:

```quest
# mymodule.q
let version = "1.0"

fun greet(name)
    "Hello, " .. name
end

# Export by having them in scope
```

Import your module:

```quest
use "mymodule" as mine
puts(mine.greet("World"))
```

See [Modules](../language/modules.md) for more details on creating and organizing modules.
