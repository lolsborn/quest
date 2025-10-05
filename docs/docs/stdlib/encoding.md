# Encoding

The encoding modules provide encoding and decoding functionality for Base64, hexadecimal, URL encoding, JSON, and structured binary data.

## Import

```quest
use "std/encoding/b64"
```

## Base64 Encoding

### `b64.encode(data)`
Encode data to Base64 string

**Parameters:**
- `data` - String to encode (Str)

**Returns:** Base64 encoded string (Str)

**Example:**
```quest
use "std/encoding/b64"
let encoded = b64.encode("Hello, World!")
puts(encoded)  # SGVsbG8sIFdvcmxkIQ==
```

### `b64.decode(encoded)`
Decode Base64 string to original data

**Parameters:**
- `encoded` - Base64 encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/encoding/b64"
let decoded = b64.decode("SGVsbG8sIFdvcmxkIQ==")
puts(decoded)  # Hello, World!
```

## URL-Safe Base64 Encoding

URL-safe Base64 uses `-` and `_` instead of `+` and `/`, and removes padding (`=` characters).

### `b64.encode_url(data)`
Encode data to URL-safe Base64 string (no padding)

**Parameters:**
- `data` - String to encode (Str)

**Returns:** URL-safe Base64 encoded string (Str)

**Example:**
```quest
use "std/encoding/b64"
let encoded = b64.encode_url("test")
puts(encoded)  # dGVzdA (note: no padding)
```

### `b64.decode_url(encoded)`
Decode URL-safe Base64 string

**Parameters:**
- `encoded` - URL-safe Base64 encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/encoding/b64"
let decoded = b64.decode_url("dGVzdA")
puts(decoded)  # test
```

## String Methods

Base64 and hex encoding can also be accessed via string methods:

### `.encode(format)`
Encode a string using the specified format

**Parameters:**
- `format` - Encoding format: `"b64"`, `"b64url"`, or `"hex"` (Str)

**Returns:** Encoded string (Str)

**Examples:**
```quest
# Base64 encoding
let encoded = "Hello World".encode("b64")
puts(encoded)  # SGVsbG8gV29ybGQ=

# URL-safe Base64
let url_safe = "test".encode("b64url")
puts(url_safe)  # dGVzdA

# Hex encoding
let hex = "test".encode("hex")
puts(hex)  # 74657374
```

### `.decode(format)`
Decode a string using the specified format

**Parameters:**
- `format` - Decoding format: `"b64"`, `"b64url"`, or `"hex"` (Str)

**Returns:** Decoded string (Str)

**Examples:**
```quest
# Base64 decoding
let decoded = "SGVsbG8gV29ybGQ=".decode("b64")
puts(decoded)  # Hello World

# URL-safe Base64
let url_decoded = "dGVzdA".decode("b64url")
puts(url_decoded)  # test

# Hex decoding
let hex_decoded = "74657374".decode("hex")
puts(hex_decoded)  # test
```

## Common Use Cases

### Encoding Binary Data for Text Transmission

```quest
use "std/encoding/b64"
use "std/io"

# Read file and encode for transmission
let file_data = io.read("data.bin")
let encoded = b64.encode(file_data)
puts("Encoded data: ", encoded)
```

### Decoding API Responses

```quest
use "std/encoding/b64"

# Decode Base64 data from API
let api_response = "SGVsbG8gZnJvbSBBUEk="
let decoded = b64.decode(api_response)
puts(decoded)  # Hello from API
```

### URL-Safe Tokens

```quest
use "std/encoding/b64"

# Create URL-safe token
let token_data = "user:123:session:abc"
let token = b64.encode_url(token_data)
puts("Token: ", token)

# Later, decode the token
let decoded_token = b64.decode_url(token)
puts("User data: ", decoded_token)
```

### Round-Trip Encoding

```quest
use "std/encoding/b64"

# Using module functions
let original = "Important data"
let encoded = b64.encode(original)
let decoded = b64.decode(encoded)
puts(decoded)  # Important data

# Using string methods
let data = "Test string"
let encoded2 = data.encode("b64")
let decoded2 = encoded2.decode("b64")
puts(decoded2)  # Test string
```

### Hex Encoding for Debugging

```quest
# Convert string to hex for inspection
let data = "Hello"
let hex = data.encode("hex")
puts("Hex: ", hex)  # 48656c6c6f

# Convert back
let original = hex.decode("hex")
puts("Original: ", original)  # Hello
```

### Encoding Configuration Data

```quest
use "std/encoding/b64"
use "std/encoding/json"
use "std/io"

# Encode config for storage
let config = json.stringify({"host": "localhost", "port": 8080})
let encoded_config = b64.encode(config)
io.write("config.b64", encoded_config)

# Decode config when loading
let loaded = io.read("config.b64")
let config_str = b64.decode(loaded)
let config_obj = json.parse(config_str)
puts("Host: ", config_obj["host"])
```

## Notes

- Base64 encoding increases data size by approximately 33%
- URL-safe Base64 is ideal for use in URLs and file names
- Hex encoding doubles the data size but is human-readable
- All encoding functions work with UTF-8 strings
- Invalid encoded data will result in an error when decoding

---

# hex - Hexadecimal Encoding

The hex module provides hexadecimal encoding and decoding functionality for binary data.

## Import

```quest
use "std/encoding/hex"
```

## Functions

### `hex.encode(data)`
Encode bytes to lowercase hexadecimal string

**Parameters:**
- `data` - Binary data to encode (Bytes)

**Returns:** Hexadecimal encoded string (Str)

**Example:**
```quest
use "std/encoding/hex"
let data = b"\xFF\x00\xAB"
let encoded = hex.encode(data)
puts(encoded)  # ff00ab
```

### `hex.encode_upper(data)`
Encode bytes to uppercase hexadecimal string

**Parameters:**
- `data` - Binary data to encode (Bytes)

**Returns:** Uppercase hexadecimal encoded string (Str)

**Example:**
```quest
use "std/encoding/hex"
let data = b"\xFF\x00\xAB"
let encoded = hex.encode_upper(data)
puts(encoded)  # FF00AB
```

### `hex.encode_with_sep(data, separator)`
Encode bytes to hexadecimal string with custom separator

**Parameters:**
- `data` - Binary data to encode (Bytes)
- `separator` - Separator string between hex pairs (Str)

**Returns:** Hexadecimal encoded string with separators (Str)

**Example:**
```quest
use "std/encoding/hex"
let data = b"\xFF\x00\xAB"
let encoded = hex.encode_with_sep(data, ":")
puts(encoded)  # ff:00:ab

let encoded2 = hex.encode_with_sep(data, " ")
puts(encoded2)  # ff 00 ab
```

### `hex.decode(encoded)`
Decode hexadecimal string to bytes

**Parameters:**
- `encoded` - Hexadecimal encoded string (Str), supports separators like `:`, `-`, spaces

**Returns:** Decoded binary data (Bytes)

**Example:**
```quest
use "std/encoding/hex"
let decoded = hex.decode("ff00ab")
puts(decoded)  # (bytes: ff00ab)

# Works with separators
let decoded2 = hex.decode("ff:00:ab")
let decoded3 = hex.decode("FF-00-AB")
```

### `hex.is_valid(encoded)`
Check if string is valid hexadecimal

**Parameters:**
- `encoded` - String to validate (Str)

**Returns:** True if valid hex string (Bool)

**Example:**
```quest
use "std/encoding/hex"
puts(hex.is_valid("ff00ab"))      # true
puts(hex.is_valid("FF:00:AB"))    # true
puts(hex.is_valid("gg00ab"))      # false
puts(hex.is_valid("ff0"))         # false (odd length)
```

## Common Use Cases

### Encoding Binary Data for Display
```quest
use "std/encoding/hex"

let data = b"\x48\x65\x6c\x6c\x6f"
let hex_str = hex.encode(data)
puts("Hex: " .. hex_str)  # Hex: 48656c6c6f
```

### Decoding Hex Strings
```quest
use "std/encoding/hex"

# Decode various hex formats
let data1 = hex.decode("48656c6c6f")
let data2 = hex.decode("48:65:6c:6c:6f")
let data3 = hex.decode("48-65-6c-6c-6f")
puts(data1.decode("utf-8"))  # Hello
```

### MAC Address Formatting
```quest
use "std/encoding/hex"

let mac_bytes = b"\x00\x1A\x2B\x3C\x4D\x5E"
let mac_addr = hex.encode_with_sep(mac_bytes, ":")
puts(mac_addr)  # 00:1a:2b:3c:4d:5e
```

### Validating Hex Input
```quest
use "std/encoding/hex"

fun parse_hex_color(color_str)
    if not hex.is_valid(color_str)
        raise "Invalid hex color: " .. color_str
    end
    hex.decode(color_str)
end

let color = parse_hex_color("FF5733")
puts("Color bytes: " .. hex.encode_upper(color))
```

---

# url - URL Encoding

The url module provides URL encoding/decoding and query string manipulation.

## Import

```quest
use "std/encoding/url"
```

## Functions

### `url.encode(text)`
Encode text for use in URL query values

**Parameters:**
- `text` - Text to encode (Str)

**Returns:** URL encoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let encoded = url.encode("Hello World!")
puts(encoded)  # Hello%20World%21
```

### `url.encode_component(text)`
Encode text with stricter rules for URL components

**Parameters:**
- `text` - Text to encode (Str)

**Returns:** URL encoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let encoded = url.encode_component("user@example.com")
puts(encoded)  # user%40example.com
```

### `url.encode_path(text)`
Encode text for use in URL paths (preserves `/`)

**Parameters:**
- `text` - Text to encode (Str)

**Returns:** URL encoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let encoded = url.encode_path("/path/to/file name.txt")
puts(encoded)  # /path/to/file%20name.txt
```

### `url.encode_query(text)`
Encode text for query strings (preserves `=` and `&`)

**Parameters:**
- `text` - Text to encode (Str)

**Returns:** URL encoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let encoded = url.encode_query("a=1&b=2")
puts(encoded)  # a=1&b=2
```

### `url.decode(encoded)`
Decode URL encoded string (treats `+` as space)

**Parameters:**
- `encoded` - URL encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let decoded = url.decode("Hello%20World%21")
puts(decoded)  # Hello World!

let decoded2 = url.decode("Hello+World")
puts(decoded2)  # Hello World
```

### `url.decode_component(encoded)`
Decode URL encoded string (does not treat `+` as space)

**Parameters:**
- `encoded` - URL encoded string (Str)

**Returns:** Decoded string (Str)

**Example:**
```quest
use "std/encoding/url"
let decoded = url.decode_component("user%40example.com")
puts(decoded)  # user@example.com
```

### `url.build_query(params)`
Build URL query string from dictionary

**Parameters:**
- `params` - Dictionary of query parameters (Dict)

**Returns:** URL encoded query string (Str)

**Example:**
```quest
use "std/encoding/url"
let params = {
    "name": "John Doe",
    "email": "john@example.com",
    "age": "30"
}
let query = url.build_query(params)
puts(query)  # name=John%20Doe&email=john%40example.com&age=30
```

### `url.parse_query(query)`
Parse URL query string into dictionary

**Parameters:**
- `query` - URL query string (Str), with or without leading `?`

**Returns:** Dictionary of query parameters (Dict)

**Example:**
```quest
use "std/encoding/url"
let query = "name=John%20Doe&email=john%40example.com&age=30"
let params = url.parse_query(query)
puts(params["name"])   # John Doe
puts(params["email"])  # john@example.com
puts(params["age"])    # 30

# Also works with leading ?
let params2 = url.parse_query("?foo=bar&baz=qux")
puts(params2["foo"])   # bar
```

## Common Use Cases

### Building API URLs
```quest
use "std/encoding/url"

let base_url = "https://api.example.com/search"
let params = {
    "q": "Quest language",
    "limit": "10",
    "offset": "0"
}
let query = url.build_query(params)
let full_url = base_url .. "?" .. query
puts(full_url)
# https://api.example.com/search?q=Quest%20language&limit=10&offset=0
```

### Parsing Query Parameters
```quest
use "std/encoding/url"

let url_string = "https://example.com/page?user=alice&action=edit&id=42"
# Extract query part (simplified)
let query = "user=alice&action=edit&id=42"
let params = url.parse_query(query)

if params["action"] == "edit"
    puts("Editing item " .. params["id"])
end
```

### Encoding Path Components
```quest
use "std/encoding/url"

let username = "user@domain.com"
let encoded = url.encode_component(username)
let profile_url = "https://example.com/users/" .. encoded
puts(profile_url)
# https://example.com/users/user%40domain.com
```

### Form Data Encoding
```quest
use "std/encoding/url"

let form_data = {
    "username": "alice",
    "password": "secret123!",
    "remember": "true"
}
let encoded_form = url.build_query(form_data)
puts(encoded_form)
# username=alice&password=secret123%21&remember=true
```

## Notes

- `url.encode()` and `url.decode()` are suitable for most query string use cases
- `url.encode_component()` provides stricter encoding for individual URL components
- `url.encode_path()` preserves forward slashes for encoding file paths in URLs
- `url.decode()` treats `+` as space (standard for query strings)
- `url.decode_component()` does not treat `+` as space
- `url.build_query()` and `url.parse_query()` handle complete query strings
- All functions follow RFC 3986 URL encoding standards

---

# struct - Binary Data Packing

The struct module provides Python-style binary data packing and unpacking for working with binary file formats, network protocols, and low-level data structures.

## Import

```quest
use "std/encoding/struct"
```

## Format Strings

Format strings control how data is packed/unpacked using format characters:

### Byte Order Prefix

First character specifies byte order (optional, defaults to native):

- `@` - Native byte order, native size (default)
- `=` - Native byte order, standard size
- `<` - Little-endian
- `>` - Big-endian
- `!` - Network (big-endian)

### Format Characters

- `x` - Pad byte (no value)
- `c` - Char (1 byte, single-character string)
- `b` - Signed byte (1 byte, -128 to 127)
- `B` - Unsigned byte (1 byte, 0 to 255)
- `?` - Bool (1 byte, true/false)
- `h` - Signed short (2 bytes, -32768 to 32767)
- `H` - Unsigned short (2 bytes, 0 to 65535)
- `i` / `l` - Signed int (4 bytes, -2147483648 to 2147483647)
- `I` / `L` - Unsigned int (4 bytes, 0 to 4294967295)
- `q` - Signed long long (8 bytes)
- `Q` - Unsigned long long (8 bytes)
- `f` - Float (4 bytes, 32-bit)
- `d` - Double (8 bytes, 64-bit)
- `s` - String (fixed length, null-padded)
- `p` - Pascal string (not yet fully implemented)

### Repeat Counts

Prefix format characters with numbers to repeat:
- `3i` - Three signed ints
- `10s` - 10-byte string
- `5B` - Five unsigned bytes

## Functions

### `struct.calcsize(format)`
Calculate size in bytes for a format string

**Parameters:**
- `format` - Format string (Str)

**Returns:** Size in bytes (Int)

**Example:**
```quest
use "std/encoding/struct"
let size = struct.calcsize("<3i")
puts(size)  # 12 (3 ints × 4 bytes each)

let size2 = struct.calcsize(">hhl")
puts(size2)  # 8 (2+2+4 bytes)
```

### `struct.pack(format, ...values)`
Pack values into bytes according to format string

**Parameters:**
- `format` - Format string (Str)
- `...values` - Values to pack (must match format)

**Returns:** Packed binary data (Bytes)

**Example:**
```quest
use "std/encoding/struct"

# Pack three integers (little-endian)
let data = struct.pack("<3i", 1, 2, 3)
puts(data)  # (bytes: 01000000 02000000 03000000)

# Pack mixed types
let data2 = struct.pack(">hhl", 100, 200, 300)

# Pack string (10 bytes, null-padded)
let data3 = struct.pack("10s", "Hello")
```

### `struct.unpack(format, data)`
Unpack bytes into values according to format string

**Parameters:**
- `format` - Format string (Str)
- `data` - Binary data to unpack (Bytes)

**Returns:** Array of unpacked values (Array)

**Example:**
```quest
use "std/encoding/struct"

# Pack and unpack integers
let packed = struct.pack("<3i", 10, 20, 30)
let values = struct.unpack("<3i", packed)
puts(values[0])  # 10
puts(values[1])  # 20
puts(values[2])  # 30

# Unpack mixed types
let data = struct.pack(">hhl", 100, 200, 300)
let result = struct.unpack(">hhl", data)
puts(result[0])  # 100
puts(result[1])  # 200
puts(result[2])  # 300
```

### `struct.unpack_from(format, data, offset)`
Unpack bytes from specific offset

**Parameters:**
- `format` - Format string (Str)
- `data` - Binary data to unpack (Bytes)
- `offset` - Byte offset to start unpacking (Int)

**Returns:** Array of unpacked values (Array)

**Example:**
```quest
use "std/encoding/struct"

# Pack multiple integers
let data = struct.pack("<5i", 1, 2, 3, 4, 5)

# Unpack from offset 4 (skip first int)
let values = struct.unpack_from("<3i", data, 4)
puts(values[0])  # 2
puts(values[1])  # 3
puts(values[2])  # 4
```

### `struct.pack_into(format, buffer, offset, ...values)`
Pack values into existing buffer at offset (not yet fully implemented)

**Parameters:**
- `format` - Format string (Str)
- `buffer` - Mutable buffer (Bytes)
- `offset` - Byte offset (Int)
- `...values` - Values to pack

**Note:** Currently returns error as bytes are immutable in Quest

## Common Use Cases

### Network Protocol Headers

```quest
use "std/encoding/struct"

# Pack TCP-like header
fun create_tcp_header(src_port, dst_port, seq_num, ack_num)
    struct.pack(
        "!HHII",
        src_port,   # Source port (unsigned short)
        dst_port,   # Destination port (unsigned short)
        seq_num,    # Sequence number (unsigned int)
        ack_num     # Acknowledgment number (unsigned int)
    )
end

let header = create_tcp_header(8080, 80, 1000, 2000)
puts("Header size: " .. header.len())  # 12 bytes

# Unpack header
let values = struct.unpack("!HHII", header)
puts("Source port: " .. values[0])
puts("Dest port: " .. values[1])
```

### Binary File Format

```quest
use "std/encoding/struct"
use "std/io"

# Write binary file with header
fun save_data_file(filename, version, count, data)
    # File header: magic (4 bytes) + version (2 bytes) + count (2 bytes)
    let magic = "DATA"
    let header = struct.pack("4sHH", magic, version, count)

    # Write header + data
    io.write(filename, header .. data)
end

# Read binary file
fun load_data_file(filename)
    let content = io.read(filename).bytes()

    # Unpack header
    let header = struct.unpack_from("4sHH", content, 0)
    let magic = header[0]
    let version = header[1]
    let count = header[2]

    # Get data (skip 8-byte header)
    let data_start = struct.calcsize("4sHH")
    let data = content.slice(data_start, content.len())

    {"magic": magic, "version": version, "count": count, "data": data}
end
```

### Little-Endian vs Big-Endian

```quest
use "std/encoding/struct"

let num = 0x12345678

# Little-endian (Intel/AMD)
let le_data = struct.pack("<I", num)
puts(le_data)  # 78 56 34 12

# Big-endian (network order)
let be_data = struct.pack(">I", num)
puts(be_data)  # 12 34 56 78

# Native (depends on system)
let native_data = struct.pack("I", num)
```

### Parsing Binary Data

```quest
use "std/encoding/struct"

# Parse BMP file header (simplified)
fun parse_bmp_header(data)
    # BMP header: signature (2 bytes) + size (4 bytes) + reserved (4 bytes) + offset (4 bytes)
    let header = struct.unpack("<2sIIII", data)

    {
        "signature": header[0],  # Should be "BM"
        "file_size": header[1],
        "reserved1": header[2],
        "reserved2": header[3],
        "data_offset": header[4]
    }
end
```

### Floating-Point Data

```quest
use "std/encoding/struct"

# Pack floats and doubles
let data = struct.pack("<fd", 3.14, 2.71828)

# Unpack
let values = struct.unpack("<fd", data)
puts("Float: " .. values[0])   # 3.14
puts("Double: " .. values[1])  # 2.71828
```

### Fixed-Length Strings

```quest
use "std/encoding/struct"

# Pack 20-character string (null-padded)
let data = struct.pack("20s", "Hello")

# Unpack
let result = struct.unpack("20s", data)
puts(result[0])  # "Hello" (trailing nulls removed)
```

### Working with Sensor Data

```quest
use "std/encoding/struct"
use "std/serial"

# Read sensor data from serial port
let port = serial.open("/dev/ttyUSB0", 9600)
let raw_data = port.read(8)

# Unpack sensor readings (4 × 16-bit unsigned values)
let readings = struct.unpack("<4H", raw_data)
puts("Temperature: " .. readings[0])
puts("Humidity: " .. readings[1])
puts("Pressure: " .. readings[2])
puts("Light: " .. readings[3])
```

## Format Examples

```quest
use "std/encoding/struct"

# Single values
struct.pack("i", 42)           # Signed int
struct.pack("f", 3.14)         # Float
struct.pack("d", 2.71828)      # Double
struct.pack("?", true)         # Bool

# Multiple values
struct.pack("3i", 1, 2, 3)     # Three ints
struct.pack("if", 42, 3.14)    # Int + float
struct.pack("4B", 1, 2, 3, 4)  # Four unsigned bytes

# Byte order
struct.pack("<i", 42)          # Little-endian int
struct.pack(">i", 42)          # Big-endian int
struct.pack("!H", 8080)        # Network order short

# Strings
struct.pack("10s", "Hello")    # 10-byte string (null-padded)
struct.pack("c", "A")          # Single char

# Padding
struct.pack("ix", 42)          # Int followed by padding byte
struct.pack("3x", )            # Three padding bytes (no values)

# Complex formats
struct.pack("<HHI", 1, 2, 3)   # Two shorts + int (little-endian)
struct.pack("!BBHH", 1, 2, 3, 4)  # Two bytes + two shorts (network)
```

## Notes

- Format strings are case-sensitive
- Byte order prefix applies to entire format string
- Repeat counts apply to single format character only
- String formats (`s`) are fixed-length and null-padded
- Pad bytes (`x`) consume no values in `pack()` and produce no values in `unpack()`
- Values must match format exactly (count and type)
- Out-of-range values raise errors
- Default byte order is native (system-dependent)
- Network byte order (`!`) is always big-endian
- Useful for: binary file formats, network protocols, hardware communication, data serialization
