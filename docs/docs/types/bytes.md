# Bytes

The `Bytes` type represents immutable sequences of raw bytes (8-bit unsigned integers). Unlike strings, which must always contain valid UTF-8, bytes can hold arbitrary binary data. This makes them ideal for binary protocols, file I/O, cryptography, and interfacing with hardware like serial ports.

## Bytes Literal

Use the `b"..."` prefix to create bytes literals:

```quest
let data = b"Hello"
puts(data)  # b"Hello"
```

Bytes literals are displayed with the `b"..."` notation, with non-printable bytes shown as hex escapes.

## String vs Bytes

Quest maintains a clear distinction between text (strings) and binary data (bytes):

- **Strings** (`"..."`) - Always valid UTF-8 text. Used for human-readable content.
- **Bytes** (`b"..."`) - Raw binary data. Can contain any byte values.

```quest
let text = "Hello"    # String - valid UTF-8
let data = b"Hello"   # Bytes - raw bytes [72, 101, 108, 108, 111]
```

## Escape Sequences

Bytes literals support escape sequences for special characters and arbitrary byte values:

### Common Escapes

```quest
b"\n"     # Newline (byte 10)
b"\r"     # Carriage return (byte 13)
b"\t"     # Tab (byte 9)
b"\0"     # Null byte (byte 0)
b"\\"     # Backslash (byte 92)
b"\""     # Quote (byte 34)
```

### Hex Escapes

Use `\xFF` syntax to specify arbitrary byte values:

```quest
b"\xFF"           # Single byte: 255
b"\x00"           # Null byte: 0
b"\xFF\x01\x42"   # Multiple bytes: [255, 1, 66]
```

Hex escapes require exactly two hex digits (0-9, a-f, A-F).

### Example: Binary Protocol

```quest
# Create a binary packet with header and payload
let packet = b"\xFF\xFF"    # Start marker (2 bytes)
packet = packet .. b"\x01"  # Command ID (1 byte)
packet = packet .. b"\x05"  # Payload length (1 byte)
packet = packet .. b"Hello" # Payload (5 bytes)

puts(packet)  # b"\xff\xff\x01\x05Hello"
```

## Creating Bytes

### From String

Convert a string to its UTF-8 byte representation:

```quest
let text = "Hello"
let data = text.bytes()
puts(data)  # b"Hello"

# Works with Unicode
let emoji = "👋"
let bytes = emoji.bytes()
puts(bytes)  # b"\xf0\x9f\x91\x8b"
```

### From Array

```quest
# Create bytes from array of numbers
let numbers = [72, 101, 108, 108, 111]
let data = Bytes.from_array(numbers)  # Note: Not yet implemented
```

## Bytes Methods

### len()

Get the number of bytes:

```quest
let data = b"Hello"
puts(data.len())  # 5

let binary = b"\xFF\x01\x42"
puts(binary.len())  # 3
```

### get(index)

Get a single byte at the specified index (0-based). Returns a number 0-255:

```quest
let data = b"Hello"
puts(data.get(0))  # 72 (ASCII 'H')
puts(data.get(1))  # 101 (ASCII 'e')

let binary = b"\xFF\x01\x42"
puts(binary.get(0))  # 255
puts(binary.get(1))  # 1
puts(binary.get(2))  # 66
```

Errors if index is out of bounds:

```quest
let data = b"Hi"
data.get(10)  # Error: Index 10 out of bounds for bytes of length 2
```

### slice(start, end)

Extract a subsequence of bytes. Returns a new `Bytes` object:

```quest
let data = b"Hello World"
let sub = data.slice(0, 5)
puts(sub)  # b"Hello"

let rest = data.slice(6, 11)
puts(rest)  # b"World"
```

The slice includes bytes from `start` (inclusive) to `end` (exclusive).

```quest
let data = b"ABCDEF"
puts(data.slice(0, 3))  # b"ABC"
puts(data.slice(2, 5))  # b"CDE"
puts(data.slice(3, 6))  # b"DEF"
```

Errors if the range is invalid:

```quest
let data = b"Hello"
data.slice(10, 20)  # Error: Invalid slice range
```

### decode(encoding="utf-8")

Decode bytes to a string using the specified encoding:

#### UTF-8 Decoding (Default)

```quest
let data = b"Hello"
puts(data.decode())  # "Hello"

# With explicit encoding
puts(data.decode("utf-8"))  # "Hello"
```

Errors if bytes are not valid UTF-8:

```quest
let invalid = b"\xFF\xFE"
invalid.decode()  # Error: Invalid UTF-8 in bytes
```

#### Hex Encoding

Convert bytes to hexadecimal string:

```quest
let data = b"\xFF\x01\x42"
puts(data.decode("hex"))  # "ff0142"

let hello = b"Hello"
puts(hello.decode("hex"))  # "48656c6c6f"
```

#### ASCII Decoding

```quest
let data = b"Hello"
puts(data.decode("ascii"))  # "Hello"
```

### to_array()

Convert bytes to an array of numbers (0-255):

```quest
let data = b"Hi"
let arr = data.to_array()
puts(arr)  # [72, 105]

let binary = b"\xFF\x01\x42"
let numbers = binary.to_array()
puts(numbers)  # [255, 1, 66]
```

Useful for byte-by-byte processing:

```quest
let data = b"ABC"
let arr = data.to_array()
arr.each(fun (byte)
    puts("Byte: " .. byte._str())
end)
# Output:
# Byte: 65
# Byte: 66
# Byte: 67
```

### Concatenation

Concatenate bytes using the `..` operator:

```quest
let header = b"\xFF\xFF"
let body = b"DATA"
let packet = header .. body
puts(packet)  # b"\xff\xffDATA"
```

## Truthiness

Bytes follow Quest's truthiness rules:

- Empty bytes (`b""`) are **falsy**
- Non-empty bytes are **truthy**

```quest
if b""
    puts("This won't print")
end

if b"data"
    puts("This will print")
end

# Common pattern: check if data received
let data = port.read(100)
if data
    puts("Received: " .. data.decode())
else
    puts("No data received")
end
```

## Common Use Cases

### Binary File I/O

```quest
use "std/io" as io

# Read binary file
let data = io.read_bytes("image.png")
puts("Read " .. data.len()._str() .. " bytes")

# Write binary file
let pixels = b"\xFF\x00\x00\xFF"  # Red and blue pixels
io.write_bytes("data.bin", pixels)
```

### Serial Communication

```quest
use "std/serial" as serial

let port = serial.open("/dev/ttyUSB0", 9600)

# Send binary command
port.write(b"\xFF\x01\x42")

# Read binary response
let response = port.read(10)  # Returns Bytes
if response.len() > 0
    let first_byte = response.get(0)
    if first_byte == 255
        puts("Got acknowledgment")
    end
end

# Text protocol (decode bytes to string)
port.write("AT\r\n")
let text_response = port.read(100).decode()
puts("Response: " .. text_response)
```

### Cryptographic Hashing

```quest
use "std/hash" as hash

let data = b"Hello, World!"
let digest = hash.sha256(data)
puts("SHA256: " .. digest.decode("hex"))
```

### Network Protocols

```quest
# Build HTTP-like request
let request = b"GET /api HTTP/1.1\r\n"
request = request .. b"Host: example.com\r\n"
request = request .. b"\r\n"

# Parse response
let response = receive_data()
let header_end = response.find(b"\r\n\r\n")
if header_end != nil
    let headers = response.slice(0, header_end)
    let body = response.slice(header_end + 4, response.len())
    puts("Body: " .. body.decode())
end
```

### Encoding Detection

```quest
# Check for UTF-8 BOM (Byte Order Mark)
let data = io.read_bytes("file.txt")
if data.len() >= 3
    if data.get(0) == 0xEF and data.get(1) == 0xBB and data.get(2) == 0xBF
        puts("File has UTF-8 BOM")
        data = data.slice(3, data.len())  # Skip BOM
    end
end
```

## Working with Binary Data

### Inspecting Bytes

```quest
let data = b"Hi\xFF"

# Get length
puts(data.len())  # 3

# Inspect each byte
let i = 0
while i < data.len()
    let byte = data.get(i)
    puts("Byte " .. i._str() .. ": " .. byte._str())
    i = i + 1
end
# Output:
# Byte 0: 72
# Byte 1: 105
# Byte 2: 255

# Convert to hex for display
puts(data.decode("hex"))  # "4869ff"
```

### Building Binary Data

```quest
# Build packet incrementally
let packet = b"\xFF\xFF"      # Start marker
packet = packet .. b"\x01"    # Command
packet = packet .. b"\x00\x05" # Length (5 bytes)
packet = packet .. b"Hello"   # Payload

# Or use slicing to modify
let header = packet.slice(0, 4)
let payload = packet.slice(4, packet.len())
```

### Byte Comparison

```quest
let data1 = b"Hello"
let data2 = b"Hello"
let data3 = b"World"

if data1 == data2
    puts("Equal")  # This prints
end

if data1 != data3
    puts("Different")  # This prints
end
```

## Error Handling

### Invalid UTF-8

```quest
try
    let invalid = b"\xFF\xFE"
    invalid.decode()  # Will raise error
catch e
    puts("Decode error: " .. e.message())
end
```

### Out of Bounds

```quest
try
    let data = b"Hi"
    data.get(100)  # Will raise error
catch e
    puts("Index error: " .. e.message())
end
```

### Safe Decoding

```quest
fun try_decode(data)
    try
        return data.decode()
    catch e
        return nil
    end
end

let data = b"\xFF\xFE"
let text = try_decode(data)
if text == nil
    puts("Could not decode as UTF-8")
    puts("Hex: " .. data.decode("hex"))
end
```

## Performance Notes

- Bytes are **immutable** - operations like concatenation create new objects
- For building large byte sequences, consider collecting components and concatenating once
- Use `slice()` instead of repeated concatenation when possible
- The `get()` method is O(1) - efficient for random access

## Limitations

Currently not supported (may be added in future):

- `Bytes.from_array(array)` - Create bytes from array of numbers
- Mutable byte buffers
- In-place modifications
- Memory-mapped bytes for large files
- Additional encodings (base64 encoding/decoding is in `std/encoding/b64`)

## See Also

- [String Type](./string.md) - For text data
- [Array Type](./array.md) - For sequences of values
- [std/io](../stdlib/io.md) - File I/O with bytes
- [std/serial](../stdlib/serial.md) - Serial port communication
- [std/hash](../stdlib/hash.md) - Cryptographic hashing
- [std/encoding/b64](../stdlib/encoding.md) - Base64 encoding
