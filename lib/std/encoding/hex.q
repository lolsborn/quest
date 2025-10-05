"""
#Hexadecimal encoding and decoding for binary data.

This module provides functions to convert between binary data (Bytes) and
hexadecimal string representations.

**Example:**
```quest
use "std/encoding/hex"

# Encode bytes to hex string
let data = b"\x01\x02\xff\xfe"
let hex_str = hex.encode(data)
puts(hex_str)  # "0102fffe"

# Decode hex string to bytes
let decoded = hex.decode("deadbeef")
puts(decoded.len())  # 4

# With separator
let formatted = hex.encode_with_sep(data, ":")
puts(formatted)  # "01:02:ff:fe"
```
"""

%fun encode(data)
"""
## Encode binary data to lowercase hexadecimal string.

**Parameters:**
- `data` (**Bytes**) - Binary data to encode

**Returns:** **Str** - Lowercase hexadecimal string (e.g., "deadbeef")

**Example:**
```quest
let data = b"\xde\xad\xbe\xef"
let hex_str = hex.encode(data)
puts(hex_str)  # "deadbeef"
```
"""

%fun encode_upper(data)
"""
## Encode binary data to uppercase hexadecimal string.

**Parameters:**
- `data` (**Bytes**) - Binary data to encode

**Returns:** **Str** - Uppercase hexadecimal string (e.g., "DEADBEEF")

**Example:**
```quest
let data = b"\xde\xad\xbe\xef"
let hex_str = hex.encode_upper(data)
puts(hex_str)  # "DEADBEEF"
```
"""

%fun encode_with_sep(data, separator)
"""
## Encode binary data to hex string with separator between bytes.

**Parameters:**
- `data` (**Bytes**) - Binary data to encode
- `separator` (**Str**) - Separator string (e.g., ":", " ", "-")

**Returns:** **Str** - Hexadecimal string with separators (e.g., "de:ad:be:ef")

**Example:**
```quest
let data = b"\xde\xad\xbe\xef"
puts(hex.encode_with_sep(data, ":"))   # "de:ad:be:ef"
puts(hex.encode_with_sep(data, " "))   # "de ad be ef"
puts(hex.encode_with_sep(data, "-"))   # "de-ad-be-ef"
```
"""

%fun decode(hex_str)
"""
## Decode hexadecimal string to binary data.

Accepts both lowercase and uppercase hex digits. Ignores whitespace and common
separators (colons, hyphens, spaces).

**Parameters:**
- `hex_str` (**Str**) - Hexadecimal string to decode

**Returns:** **Bytes** - Decoded binary data

**Raises:** Error if string contains invalid hex characters or odd number of hex digits

**Example:**
```quest
let data = hex.decode("deadbeef")
let data2 = hex.decode("de:ad:be:ef")    # Separators ignored
let data3 = hex.decode("de ad be ef")    # Whitespace ignored
let data4 = hex.decode("DEADBEEF")       # Uppercase accepted
```
"""

%fun is_valid(hex_str)
"""
## Check if string is valid hexadecimal.

**Parameters:**
- `hex_str` (**Str**) - String to validate

**Returns:** **Bool** - True if valid hex string (even number of hex digits)

**Example:**
```quest
puts(hex.is_valid("deadbeef"))    # true
puts(hex.is_valid("DEADBEEF"))    # true
puts(hex.is_valid("de:ad"))       # true (separators ignored)
puts(hex.is_valid("xyz"))         # false (invalid chars)
puts(hex.is_valid("abc"))         # false (odd length)
```
"""
