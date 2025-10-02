# Base64 Encoding Module

The base64 encoding module provides encoding and decoding functionality for Base64, URL-safe Base64, and hexadecimal formats.

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
