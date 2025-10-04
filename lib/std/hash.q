"""
#Cryptographic and non-cryptographic hashing functions.

This module provides various hash algorithms for checksums, data integrity,
and message authentication.

**Example:**
```quest
  use "std/hash" as hash

  let h = hash.sha256("Hello, World!")
  puts(h)

  let hmac = hash.hmac_sha256("message", "secret_key")
```
"""

%fun md5(data)
"""
## Calculate MD5 hash (128-bit).

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to hash

**Returns:** **Str** - Hex string of hash (32 characters)

**Note:** MD5 is not cryptographically secure. Use for checksums only, not security.

**Example:**
```quest
let h = hash.md5("Hello, World!")
puts(h)  # 65a8e27d8879283831b664bd8b7f0ad4
```
"""

%fun sha1(data)
"""
## Calculate SHA-1 hash (160-bit).

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to hash

**Returns:** **Str** - Hex string of hash (40 characters)

**Note:** SHA-1 is deprecated for security purposes. Use SHA-256 or better.

**Example:**
```quest
let h = hash.sha1("Hello, World!")
puts(h)  # 0a0a9f2a6772942557ab5355d76af442f8f65e01
```
"""

%fun sha256(data)
"""
## Calculate SHA-256 hash (256-bit).

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to hash

**Returns:** **Str** - Hex string of hash (64 characters)

**Example:**
```quest
let h = hash.sha256("Hello, World!")
puts(h)
```
"""

%fun sha512(data)
"""
## Calculate SHA-512 hash (512-bit).

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to hash

**Returns:** **Str** - Hex string of hash (128 characters)

**Example:**
```quest
let h = hash.sha512("Hello, World!")
puts(h)
```

**Note:** SHA-512 provides higher security than SHA-256 at the cost of longer output.
"""

# =============================================================================
# HMAC (Hash-based Message Authentication Code)
# =============================================================================

%fun hmac_sha256(data, key)
"""
## Calculate HMAC-SHA256 for message authentication.

HMAC is used to verify both the data integrity and authenticity of a message.
It combines a cryptographic hash function with a secret key.

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to authenticate
- `key` (**Str** or **Bytes**) - Secret key

**Returns:** **Str** - Hex string of HMAC

**Example:**
```quest
let secret = "my_secret_key"
let message = "Hello, World!"
let hmac = hash.hmac_sha256(message, secret)
puts(hmac)
```
"""

%fun hmac_sha512(data, key)
"""
## Calculate HMAC-SHA512 for message authentication.

Similar to HMAC-SHA256 but with 512-bit output for higher security.

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to authenticate
- `key` (**Str** or **Bytes**) - Secret key

**Returns:** **Str** - Hex string of HMAC

**Example:**
```quest
let secret = "my_secret_key"
let message = "sensitive data"
let hmac = hash.hmac_sha512(message, secret)
```
"""

# =============================================================================
# Non-Cryptographic Hash Functions
# =============================================================================

%fun crc32(data)
"""
## Calculate CRC32 checksum (fast, non-cryptographic).

CRC32 is a fast checksum algorithm for detecting accidental data corruption.
Do NOT use for security purposes.

**Parameters:**
- `data` (**Str** or **Bytes**) - Data to checksum

**Returns:** **Num** - CRC32 value (unsigned 32-bit integer)

**Example:**
```quest
let checksum = hash.crc32("Hello, World!")
puts(checksum)  # 2193973375
```
"""
