"""
#Binary data packing and unpacking (Python struct module equivalent).

This module provides functions to convert between Quest values and C structs
represented as Bytes objects. It uses format strings to describe the binary layout.

**Format Characters:**
- `x` - Pad byte (no value)
- `c` - Char (1 byte, converted to/from 1-char string)
- `b` - Signed char (1 byte integer, -128 to 127)
- `B` - Unsigned char (1 byte integer, 0 to 255)
- `?` - Bool (1 byte, 0 = false, non-zero = true)
- `h` - Short (2 bytes, -32768 to 32767)
- `H` - Unsigned short (2 bytes, 0 to 65535)
- `i` - Int (4 bytes, -2147483648 to 2147483647)
- `I` - Unsigned int (4 bytes, 0 to 4294967295)
- `l` - Long (4 bytes, same as i)
- `L` - Unsigned long (4 bytes, same as I)
- `q` - Long long (8 bytes, -9223372036854775808 to 9223372036854775807)
- `Q` - Unsigned long long (8 bytes, 0 to 18446744073709551615)
- `f` - Float (4 bytes)
- `d` - Double (8 bytes)
- `s` - Char array (string, requires count like "10s")

**Byte Order Prefixes:**
- `@` - Native byte order, native size (default)
- `=` - Native byte order, standard size
- `<` - Little-endian
- `>` - Big-endian
- `!` - Network byte order (big-endian)

**Repeat Counts:**
Format characters can be prefixed with a count: `"3i"` = three ints, `"10s"` = 10-byte string

**Example:**
```quest
use "std/bin/struct"

# Pack integers into binary format
let data = struct.pack("<HHI", 1, 2, 3)
puts(data.len())  # 8 bytes: 2 + 2 + 4

# Unpack binary data
let values = struct.unpack("<HHI", data)
puts(values)  # [1, 2, 3]

# Calculate struct size
let size = struct.calcsize("<HHI")
puts(size)  # 8

# Working with strings
let msg = struct.pack("10s", "Hello")
let unpacked = struct.unpack("10s", msg)
puts(unpacked[0])  # "Hello\x00\x00\x00\x00\x00"

# Network protocols (big-endian)
let packet = struct.pack("!HHI", 1, 2, 3)
```
"""

%fun pack(format)
"""
## Pack values into binary data according to format string.

**Parameters:**
- `format` (**Str**) - Format string describing binary layout
- Additional variadic arguments - Values to pack (count must match format)

**Returns:** **Bytes** - Packed binary data

**Raises:** Error if values don't match format or are out of range

**Example:**
```quest
let data = struct.pack("<HI", 42, 1000000)
let data2 = struct.pack("3i", 1, 2, 3)
let str_data = struct.pack("10s", "Hello")
```
"""

%fun unpack(format, data)
"""
## Unpack binary data according to format string.

**Parameters:**
- `format` (**Str**) - Format string describing binary layout
- `data` (**Bytes**) - Binary data to unpack

**Returns:** **Array** - Array of unpacked values

**Raises:** Error if data size doesn't match format

**Example:**
```quest
let data = b"\x01\x00\x02\x00\x03\x00\x00\x00"
let values = struct.unpack("<HHI", data)
puts(values)  # [1, 2, 3]
```
"""

%fun unpack_from(format, data, offset)
"""
## Unpack binary data from buffer at given offset.

**Parameters:**
- `format` (**Str**) - Format string describing binary layout
- `data` (**Bytes**) - Binary data buffer
- `offset` (**Int**) - Byte offset to start unpacking from (default 0)

**Returns:** **Array** - Array of unpacked values

**Raises:** Error if data size from offset doesn't match format

**Example:**
```quest
let data = b"\xFF\xFF\x01\x00\x02\x00"
let values = struct.unpack_from("<HH", data, 2)
puts(values)  # [1, 2]
```
"""

%fun calcsize(format)
"""
## Calculate size in bytes of struct described by format.

**Parameters:**
- `format` (**Str**) - Format string

**Returns:** **Int** - Size in bytes

**Example:**
```quest
let size = struct.calcsize("<HHI")
puts(size)  # 8
let size2 = struct.calcsize("10s")
puts(size2)  # 10
```
"""

%fun pack_into(format, buffer, offset)
"""
## Pack values into existing buffer at given offset.

**Parameters:**
- `format` (**Str**) - Format string describing binary layout
- `buffer` (**Bytes**) - Existing buffer to pack into (must be mutable)
- `offset` (**Int**) - Byte offset to start packing at
- Additional variadic arguments - Values to pack (count must match format)

**Returns:** **Nil**

**Raises:** Error if values don't match format or buffer is too small

**Note:** This function modifies the buffer in-place.

**Example:**
```quest
# Create a buffer
let buf = b"\x00\x00\x00\x00\x00\x00\x00\x00"
struct.pack_into("<HH", buf, 0, 1, 2)
puts(buf)  # Modified buffer with values
```
"""
