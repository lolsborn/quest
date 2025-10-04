"""
# Cryptographic operations for secure message authentication.

This module provides HMAC (Hash-based Message Authentication Code) functions
for verifying both data integrity and authenticity.

**Example:**
```quest
use "std/crypto" as crypto

let secret = "my_secret_key"
let message = "important data"
let signature = crypto.hmac_sha256(message, secret)
```
"""

%fun hmac_sha256(message, key)
"""
## Calculate HMAC-SHA256 for message authentication.

HMAC combines a cryptographic hash function (SHA-256) with a secret key to
verify both the data integrity and authenticity of a message.

**Parameters:**
- `message` (**Str** or **Bytes**) - Data to authenticate
- `key` (**Str** or **Bytes**) - Secret key

**Returns:** **Str** - Hex string of HMAC (64 characters)

**Example:**
```quest
use "std/crypto" as crypto

let secret = "my_secret_key"
let message = "Hello, World!"
let hmac = crypto.hmac_sha256(message, secret)
puts(hmac)
```
"""

%fun hmac_sha512(message, key)
"""
## Calculate HMAC-SHA512 for message authentication.

Similar to HMAC-SHA256 but with 512-bit output for higher security.
Use when you need stronger security guarantees or longer MACs.

**Parameters:**
- `message` (**Str** or **Bytes**) - Data to authenticate
- `key` (**Str** or **Bytes**) - Secret key

**Returns:** **Str** - Hex string of HMAC (128 characters)

**Example:**
```quest
use "std/crypto" as crypto

let secret = "my_secret_key"
let message = "sensitive data"
let hmac = crypto.hmac_sha512(message, secret)
```
"""
