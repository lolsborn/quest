# Hash Module

The `hash` module provides cryptographic and non-cryptographic hashing functions.

## Cryptographic Hash Functions

### `hash.md5(data)`
Calculate MD5 hash (128-bit)

**Parameters:**
- `data` - Data to hash (Str or Bytes)

**Returns:** Hex string of hash (Str)

**Note:** MD5 is not cryptographically secure. Use for checksums only, not security.

**Example:**
```quest
let h = hash.md5("Hello, World!")
puts(h)  # 8cda2aacb2e63f99d416d3e4d82e3295
```quest

### `hash.sha1(data)`
Calculate SHA-1 hash (160-bit)

**Parameters:**
- `data` - Data to hash (Str or Bytes)

**Returns:** Hex string of hash (Str)

**Note:** SHA-1 is deprecated for security purposes. Use SHA-256 or better.

**Example:**
```quest
let h = hash.sha1("Hello, World!")
puts(h)  # 4ca9653095931ef15cb6b02d72f621e1bcbb856b
```quest

### `hash.sha256(data)`
Calculate SHA-256 hash (256-bit)

**Parameters:**
- `data` - Data to hash (Str or Bytes)

**Returns:** Hex string of hash (Str)

**Example:**
```quest
let h = hash.sha256("Hello, World!")
puts(h)  # ae97eca8f8ae1672bcc5c79e3fbafd8ee86f65f775e2250a291d3788b7a8af95
```quest

### `hash.sha512(data)`
Calculate SHA-512 hash (512-bit)

**Parameters:**
- `data` - Data to hash (Str or Bytes)

**Returns:** Hex string of hash (Str)

**Example:**
```quest
let h = hash.sha512("Hello, World!")
puts(h)  # da73ffa8c95e8f252951e3e2a21062f53ad8fc3a977da67f627c20fc2c13949f1be4fa07beed0383e79767b205c42b9f947938ba4d9eea0c8e88bf912f526011
```quest

## HMAC (Hash-based Message Authentication Code)

### `hash.hmac_sha256(data, key)`
Calculate HMAC-SHA256

**Parameters:**
- `data` - Data to authenticate (Str or Bytes)
- `key` - Secret key (Str or Bytes)

**Returns:** Hex string of HMAC (Str)

**Example:**
```quest
let secret = "my_secret_key"
let message = "Hello, World!"
let hmac = hash.hmac_sha256(message, secret)
puts(hmac)
```quest

### `hash.hmac_sha512(data, key)`
Calculate HMAC-SHA512

**Parameters:**
- `data` - Data to authenticate (Str or Bytes)
- `key` - Secret key (Str or Bytes)

**Returns:** Hex string of HMAC (Str)

## Non-Cryptographic Hash Functions

### `hash.crc32(data)`
Calculate CRC32 checksum

**Parameters:**
- `data` - Data to checksum (Str or Bytes)

**Returns:** CRC32 value (Num)

**Example:**
```quest
let checksum = hash.crc32("Hello, World!")
puts(checksum)  # 2193973375
```quest

## Password Hashing

### `hash.bcrypt(password, cost = 10)`
Hash password using bcrypt

**Parameters:**
- `password` - Password to hash (Str)
- `cost` - Cost factor 4-31 (Num, default 10, higher = slower/more secure)

**Returns:** Bcrypt hash string (Str)

**Example:**
```quest
let hashed = hash.bcrypt("user_password123")
io.write("password.hash", hashed)
```quest

### `hash.bcrypt_verify(password, hash)`
Verify password against bcrypt hash

**Parameters:**
- `password` - Password to verify (Str)
- `hash` - Bcrypt hash to check against (Str)

**Returns:** Bool (true if password matches)

**Example:**
```quest
let stored_hash = io.read("password.hash")
let password = io.read_line()

if hash.bcrypt_verify(password, stored_hash)
    puts("Password correct")
else
    puts("Password incorrect")
end
```quest

## Common Use Cases

### Password Storage
```quest
# Register user
let password = io.read_line()
let hashed = hash.bcrypt(password, 12)
io.write("users/alice.hash", hashed)

# Login verification
let input_password = io.read_line()
let stored_hash = io.read("users/alice.hash")

if hash.bcrypt_verify(input_password, stored_hash)
    puts("Login successful")
else
    puts("Invalid password")
end
```quest

### API Request Signing
```quest
# Sign API request with HMAC
let api_key = "secret_api_key"
let request_body = json.stringify({"action": "transfer", "amount": 100})
let signature = hash.hmac_sha256(request_body, api_key)

# Send request with signature
http.post("https://api.example.com/action", {
    "body": request_body,
    "headers": {"X-Signature": signature}
})
```quest