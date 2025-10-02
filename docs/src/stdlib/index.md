# Standard Library

Quest includes a carefully curated standard library with modules for common tasks.

## Importing Modules

Use the `use` statement to import modules:

```quest
use "std/math" as math
puts(math.pi)  # 3.141592653589793
```quest

## Available Modules

### Mathematics and Numerics

- **[math](./math.md)** - Mathematical functions (sin, cos, sqrt, etc.) and constants (pi, e)

### String Processing

- **[str](./str.md)** - String manipulation utilities

### Data Formats

- **[json](./json.md)** - JSON encoding and decoding
- **[b64](./b64.md)** - Base64 encoding and decoding

### Cryptography

- **[hash](./hash.md)** - Cryptographic hash functions (MD5, SHA1, SHA256, SHA512)
- **[crypto](./crypto.md)** - HMAC and other cryptographic functions

### Input/Output

- **[io](./io.md)** - File and stream I/O operations

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
```quest

### Multiple Imports

```quest
use "std/json" as json
use "std/io" as io

let data = {"name": "Quest", "version": "1.0"}
let text = json.stringify(data)
io.write_file("data.json", text)
```quest

### Module Members

Modules can contain:
- **Functions**: Callable operations
- **Constants**: Read-only values (like `math.pi`)

Access members using dot notation:

```quest
use "std/math" as m

puts(m.pi)           # Constant
puts(m.sin(m.pi))    # Function call
```quest

## Creating Your Own Modules

Quest modules are simply `.q` files that export values:

```quest
# mymodule.q
let version = "1.0"

fun greet(name)
    "Hello, " .. name
end

# Export by having them in scope
```quest

Import your module:

```quest
use "mymodule" as mine
puts(mine.greet("World"))
```quest

See [Modules](../language/modules.md) for more details on creating and organizing modules.
