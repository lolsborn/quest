# crypto - Cryptography Functions

The `crypto` module provides cryptographic functions, including HMAC (Hash-based Message Authentication Code) implementations.

## Usage

```quest
use "std/crypto" as crypto
```

## Functions

### `crypto.hmac_sha256(message, key)`

Computes HMAC-SHA256 of a message with a given key.

**Parameters:**
- `message` - The message string to authenticate
- `key` - The secret key string

**Returns:** Hex-encoded HMAC-SHA256 string

**Example:**

```quest
use "std/crypto" as crypto

let message = "Hello, World!"
let key = "my-secret-key"
let hmac = crypto.hmac_sha256(message, key)
puts(hmac)
# Output: 2b3419da0c9dbd5e28bd701ffa92f0dfaae50a3f2ae5df1f751f6f0331df9305
```

### `crypto.hmac_sha512(message, key)`

Computes HMAC-SHA512 of a message with a given key.

**Parameters:**
- `message` - The message string to authenticate
- `key` - The secret key string

**Returns:** Hex-encoded HMAC-SHA512 string

**Example:**

```quest
use "std/crypto" as crypto

let data = "sensitive data"
let secret = "secret123"
let mac = crypto.hmac_sha512(data, secret)
puts(mac)
# Output: (128-character hex string)
```

## Security Notes

- HMAC provides message authentication and integrity verification
- Keep your secret keys secure and never hardcode them in source code
- HMAC-SHA256 is suitable for most applications
- Use HMAC-SHA512 for applications requiring stronger security guarantees
- HMAC is commonly used for:
  - API authentication
  - JWT token signing
  - Webhook signature verification
  - Message integrity checks

## Use Cases

### API Signature

```quest
use "std/crypto" as crypto

let api_key = "your-api-key"
let payload = "user_id=123&action=update"
let signature = crypto.hmac_sha256(payload, api_key)

puts(f"X-Signature: {signature}")
```

### Data Integrity

```quest
use "std/crypto" as crypto

let data = "important data"
let secret = "shared-secret"

# Sender computes HMAC
let mac = crypto.hmac_sha256(data, secret)

# Receiver verifies by recomputing
let received_data = "important data"
let verified_mac = crypto.hmac_sha256(received_data, secret)

if mac == verified_mac
    puts("Data integrity verified!")
else
    puts("Warning: Data may be tampered!")
end
```
