# UUID Module

The `std/uuid` module provides support for Universally Unique Identifiers (UUIDs), implementing RFC 4122 standard UUIDs.

## Overview

UUIDs are 128-bit identifiers that are guaranteed to be unique across space and time. They're commonly used as primary keys in databases, distributed systems identifiers, and anywhere you need globally unique IDs.

## Module Import

```quest
use "std/uuid" as uuid
```

## Functions

### uuid.v1(node_id?)

Generate a UUID version 1 (timestamp and node ID based). Includes timestamp and optionally a node identifier (like MAC address).

**Parameters:**
- `node_id` (Bytes, optional) - 6-byte node identifier. If omitted, generates random node ID.

**Returns:** `Uuid`

**Example:**
```quest
# With random node ID
let id = uuid.v1()

# With specific node ID (e.g., MAC address)
let node = b"\x01\x02\x03\x04\x05\x06"
let id_with_node = uuid.v1(node)
```

**Note:** Consider using v6 instead, which has the same features but better ordering properties.

### uuid.v3(namespace, name)

Generate a UUID version 3 (MD5 namespace-based). Creates deterministic UUIDs based on a namespace and name.

**Parameters:**
- `namespace` (Uuid) - Namespace UUID (use `NAMESPACE_DNS`, `NAMESPACE_URL`, etc.)
- `name` (Str or Bytes) - Name to hash

**Returns:** `Uuid`

**Example:**
```quest
# Generate UUID for a domain name
let id = uuid.v3(uuid.NAMESPACE_DNS, "example.com")

# Same inputs always produce same UUID
let id2 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
puts(id.eq(id2))  # true
```

**Note:** Consider using v5 instead, which uses SHA-1 instead of MD5.

### uuid.v4()

Generate a UUID version 4 (random). Uses random numbers for uniqueness. Best for general-purpose unique identifiers.

**Returns:** `Uuid`

**Example:**
```quest
let id = uuid.v4()
puts(id.to_string())  # e.g., "550e8400-e29b-41d4-a716-446655440000"
```

### uuid.v5(namespace, name)

Generate a UUID version 5 (SHA-1 namespace-based). Creates deterministic UUIDs based on a namespace and name. Preferred over v3.

**Parameters:**
- `namespace` (Uuid) - Namespace UUID (use `NAMESPACE_DNS`, `NAMESPACE_URL`, etc.)
- `name` (Str or Bytes) - Name to hash

**Returns:** `Uuid`

**Example:**
```quest
# Generate UUID for a URL
let id = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")

# Same inputs always produce same UUID
let id2 = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
puts(id.eq(id2))  # true
```

### uuid.v6(node_id?)

Generate a UUID version 6 (improved timestamp-based). Like v1 but with better ordering properties. Preferred over v1.

**Parameters:**
- `node_id` (Bytes, optional) - 6-byte node identifier. If omitted, generates random node ID.

**Returns:** `Uuid`

**Example:**
```quest
let id = uuid.v6()

# With specific node ID
let node = b"\xAA\xBB\xCC\xDD\xEE\xFF"
let id_with_node = uuid.v6(node)
```

### uuid.v7()

Generate a UUID version 7 (time-ordered). Includes Unix timestamp, making it sortable and optimal for database indexes.

**Returns:** `Uuid`

**Example:**
```quest
let id1 = uuid.v7()
let id2 = uuid.v7()

# v7 UUIDs are lexicographically sortable
puts(id1.to_string() < id2.to_string())  # true (usually)
```

**Benefits of v7:**
- **Sortable**: Can be used as sortable primary keys
- **Index-friendly**: Best database index performance
- **Time-ordered**: Contains creation timestamp
- **Sequential**: Reduces index fragmentation

### uuid.v8(data)

Generate a UUID version 8 (custom). Allows creating UUIDs from custom 16-byte data.

**Parameters:**
- `data` (Bytes) - Exactly 16 bytes of custom data

**Returns:** `Uuid`

**Example:**
```quest
let custom_data = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10"
let id = uuid.v8(custom_data)
```

### uuid.nil_uuid()

Create a nil UUID (all zeros).

**Returns:** `Uuid`

**Example:**
```quest
let nil_id = uuid.nil_uuid()
puts(nil_id.to_string())  # "00000000-0000-0000-0000-000000000000"
puts(nil_id.is_nil())     # true
```

### uuid.parse(string)

Parse a UUID from a string. Accepts both hyphenated and non-hyphenated formats.

**Parameters:**
- `string` (Str) - UUID string to parse

**Returns:** `Uuid`

**Raises:** Error if the string is not a valid UUID

**Example:**
```quest
# With hyphens
let id1 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")

# Without hyphens
let id2 = uuid.parse("550e8400e29b41d4a716446655440000")

# Both produce the same UUID
puts(id1.to_string())  # "550e8400-e29b-41d4-a716-446655440000"
puts(id2.to_string())  # "550e8400-e29b-41d4-a716-446655440000"
```

### uuid.from_bytes(bytes)

Create a UUID from exactly 16 bytes.

**Parameters:**
- `bytes` (Bytes) - 16-byte sequence

**Returns:** `Uuid`

**Raises:** Error if bytes length is not exactly 16

**Example:**
```quest
let id = uuid.v4()
let bytes = id.to_bytes()
let reconstructed = uuid.from_bytes(bytes)
puts(id.to_string() == reconstructed.to_string())  # true
```

## Namespace Constants

The UUID module provides standard namespace UUIDs for use with v3 and v5:

### uuid.NAMESPACE_DNS

Namespace for domain names (DNS).

**Example:**
```quest
let id = uuid.v5(uuid.NAMESPACE_DNS, "example.com")
```

### uuid.NAMESPACE_URL

Namespace for URLs.

**Example:**
```quest
let id = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
```

### uuid.NAMESPACE_OID

Namespace for ISO Object Identifiers (OID).

**Example:**
```quest
let id = uuid.v5(uuid.NAMESPACE_OID, "1.3.6.1.4.1")
```

### uuid.NAMESPACE_X500

Namespace for X.500 Distinguished Names.

**Example:**
```quest
let id = uuid.v5(uuid.NAMESPACE_X500, "CN=example,DC=com")
```

## UUID Methods

### id.to_string() / id.str()

Convert UUID to its standard hyphenated lowercase string representation.

**Returns:** `Str`

**Example:**
```quest
let id = uuid.v4()
puts(id.to_string())  # "550e8400-e29b-41d4-a716-446655440000"
```

### id.to_hyphenated()

Convert UUID to hyphenated format (same as `to_string()`).

**Returns:** `Str`

**Example:**
```quest
let id = uuid.v4()
puts(id.to_hyphenated())  # "550e8400-e29b-41d4-a716-446655440000"
```

### id.to_simple()

Convert UUID to simple format without hyphens.

**Returns:** `Str`

**Example:**
```quest
let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
puts(id.to_simple())  # "550e8400e29b41d4a716446655440000"
```

### id.to_urn()

Convert UUID to URN format.

**Returns:** `Str`

**Example:**
```quest
let id = uuid.v4()
puts(id.to_urn())  # "urn:uuid:550e8400-e29b-41d4-a716-446655440000"
```

### id.to_bytes()

Convert UUID to its 16-byte representation.

**Returns:** `Bytes`

**Example:**
```quest
let id = uuid.v4()
let bytes = id.to_bytes()
puts(bytes.len())  # 16
```

### id.version()

Get the UUID version number.

**Returns:** `Num` - Version number (e.g., 4 for UUIDv4)

**Example:**
```quest
let id = uuid.v4()
puts(id.version())  # 4
```

### id.variant()

Get the UUID variant as a string.

**Returns:** `Str` - Variant name (e.g., "RFC4122")

**Example:**
```quest
let id = uuid.v4()
puts(id.variant())  # "RFC4122"
```

### id.is_nil()

Check if the UUID is the nil UUID (all zeros).

**Returns:** `Bool`

**Example:**
```quest
let nil_id = uuid.nil_uuid()
let normal_id = uuid.v4()

puts(nil_id.is_nil())    # true
puts(normal_id.is_nil()) # false
```

### id.eq(other)

Check if two UUIDs are equal.

**Parameters:**
- `other` (Uuid) - UUID to compare with

**Returns:** `Bool`

**Example:**
```quest
let id1 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
let id2 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
let id3 = uuid.v4()

puts(id1.eq(id2))  # true
puts(id1.eq(id3))  # false
```

### id.neq(other)

Check if two UUIDs are not equal.

**Parameters:**
- `other` (Uuid) - UUID to compare with

**Returns:** `Bool`

**Example:**
```quest
let id1 = uuid.v4()
let id2 = uuid.v4()

puts(id1.neq(id2))  # true (v4 UUIDs are random)
```

## Database Integration

UUIDs work seamlessly with PostgreSQL's native UUID type:

```quest
use "std/db/postgres" as db
use "std/uuid" as uuid

let conn = db.connect("host=localhost user=myuser dbname=mydb")
let cursor = conn.cursor()

# Create table with UUID primary key
cursor.execute("CREATE TABLE users (id UUID PRIMARY KEY, name TEXT)")

# Insert with UUID (v7 recommended for better index performance)
let user_id = uuid.v7()
cursor.execute("INSERT INTO users (id, name) VALUES ($1, $2)", [user_id, "Alice"])

# Query by UUID
cursor.execute("SELECT * FROM users WHERE id = $1", [user_id])
let rows = cursor.fetch_all()
puts(rows[0].get("name"))  # "Alice"

# Retrieved UUID is a Uuid type
let retrieved_id = rows[0].get("id")
puts(retrieved_id.cls())          # "Uuid"
puts(retrieved_id.to_string())    # Same as user_id
```

## Common Patterns

### Using UUIDs as Primary Keys

**With v7 (recommended for databases)**:
```quest
use "std/db/postgres" as db
use "std/uuid" as uuid

fun create_user(conn, name, email)
    let cursor = conn.cursor()
    # v7 UUIDs are sortable and index-friendly
    let user_id = uuid.v7()

    cursor.execute(
        "INSERT INTO users (id, name, email) VALUES ($1, $2, $3)",
        [user_id, name, email]
    )

    user_id
end

# Usage
let conn = db.connect("...")
let new_user_id = create_user(conn, "Alice", "alice@example.com")
puts("Created user: " .. new_user_id.to_string())
```

**With v4 (when unpredictability is important)**:
```quest
# Use v4 when you need random, unpredictable IDs
let api_key_id = uuid.v4()
```

### UUID Validation

```quest
use "std/uuid" as uuid

fun is_valid_uuid(str)
    try
        uuid.parse(str)
        true
    catch e
        false
    end
end

puts(is_valid_uuid("550e8400-e29b-41d4-a716-446655440000"))  # true
puts(is_valid_uuid("not-a-uuid"))                            # false
```

### Storing UUIDs as Strings

If your database doesn't support UUID types, you can convert to strings:

```quest
use "std/db/sqlite" as db
use "std/uuid" as uuid

let conn = db.connect(":memory:")
let cursor = conn.cursor()

cursor.execute("CREATE TABLE items (id TEXT PRIMARY KEY, name TEXT)")

let item_id = uuid.v4()
cursor.execute("INSERT INTO items VALUES (?, ?)", [item_id.to_string(), "Item 1"])

cursor.execute("SELECT id FROM items")
let rows = cursor.fetch_all()
let retrieved_id = uuid.parse(rows[0].get("id"))  # Convert back to UUID
```

### Comparing UUIDs

```quest
use "std/uuid" as uuid

let id1 = uuid.v4()
let id2 = uuid.v4()
let id3 = uuid.parse(id1.to_string())

# Direct comparison using methods
puts(id1.eq(id2))   # false (different UUIDs)
puts(id1.eq(id3))   # true (same UUID)

# String comparison
puts(id1.to_string() == id2.to_string())  # false
puts(id1.to_string() == id3.to_string())  # true
```

### Deterministic UUIDs for Idempotency

Use v5 (or v3) to create deterministic UUIDs from known data:

```quest
use "std/uuid" as uuid

fun get_user_uuid(email)
    # Always returns same UUID for same email
    uuid.v5(uuid.NAMESPACE_DNS, email)
end

let alice_id = get_user_uuid("alice@example.com")
let also_alice = get_user_uuid("alice@example.com")

puts(alice_id.eq(also_alice))  # true - same UUID

# Useful for:
# - Idempotent operations
# - Content-addressable storage
# - Deduplication
# - Consistent IDs across systems
```

### Custom UUID Data (v8)

Create UUIDs with custom embedded data:

```quest
use "std/uuid" as uuid

# Embed custom application data in UUID
fun create_sharded_id(shard_num, seq_num)
    let data = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
    # Customize the data bytes as needed
    uuid.v8(data)
end
```

## Type Information

UUIDs are first-class Quest objects:

```quest
use "std/uuid" as uuid

let id = uuid.v4()

puts(id.cls())      # "Uuid"
puts(id._doc())     # "UUID (Universally Unique Identifier) value"
puts(id._id())      # Unique object ID (number)
```

## Format Details

### Hyphenated Format (Standard)
```
550e8400-e29b-41d4-a716-446655440000
```
- 8-4-4-4-12 hexadecimal digits
- Lowercase
- Standard representation

### Simple Format
```
550e8400e29b41d4a716446655440000
```
- 32 hexadecimal digits
- No hyphens
- Useful for compact storage

### URN Format
```
urn:uuid:550e8400-e29b-41d4-a716-446655440000
```
- RFC 4122 URN format
- Prefixed with `urn:uuid:`

## UUID Versions

Quest supports generating all standard UUID versions:

### Time-based UUIDs
- **UUIDv1** (`uuid.v1()`) - Timestamp + node ID. Contains timestamp and node identifier (like MAC address).
- **UUIDv6** (`uuid.v6()`) - Improved v1. Same as v1 but with better ordering properties. **Preferred over v1.**
- **UUIDv7** (`uuid.v7()`) - Unix timestamp-based. Best for database primary keys due to excellent ordering. **Recommended for most time-based use cases.**

### Name-based UUIDs (Deterministic)
- **UUIDv3** (`uuid.v3(namespace, name)`) - MD5 namespace-based. Generates same UUID for same namespace+name.
- **UUIDv5** (`uuid.v5(namespace, name)`) - SHA-1 namespace-based. Same as v3 but uses SHA-1. **Preferred over v3.**

### Other UUIDs
- **UUIDv4** (`uuid.v4()`) - Random. Best for general-purpose unique identifiers where unpredictability matters.
- **UUIDv8** (`uuid.v8(data)`) - Custom. Create UUIDs from custom 16-byte data for specialized use cases.
- **Nil UUID** (`uuid.nil_uuid()`) - All zeros. Use to represent "no value".

### Which Version to Use?

**For database primary keys:** Use **v7** (best index performance, sortable)

**For distributed unique IDs:** Use **v4** (unpredictable, no coordination needed)

**For deterministic IDs from names:** Use **v5** with appropriate namespace (same input = same UUID)

**For timestamp-based IDs:** Use **v7** (modern) or **v6** (legacy systems)

**For custom binary data:** Use **v8**

All UUID versions can be parsed from strings using `uuid.parse()`.

## Performance Notes

- UUID generation is very fast (random number generation)
- UUID parsing is optimized for both hyphenated and simple formats
- UUIDs are 128 bits (16 bytes) in memory
- String representation is 36 bytes (with hyphens) or 32 bytes (without)

## Best Practices

1. **Use UUIDs for distributed systems** where you need globally unique identifiers without coordination
2. **Choose the right version**:
   - Use **v7** for database primary keys and when you need sortability
   - Use **v4** when you need unpredictability and have no ordering requirements
3. **Store as native UUID type in PostgreSQL** rather than strings for better performance and indexing
4. **Use hyphenated format for display** but consider simple format for API responses or compact storage
5. **Use v7 for time-series data** - the built-in timestamp makes them perfect for logs, events, and audit trails
6. **Use nil UUID** to represent "no value" rather than empty strings

## See Also

- [PostgreSQL Database Module](./db/postgres.md) - PostgreSQL integration with UUID support
- [Bytes Type](../types/bytes.md) - Binary data representation
- [String Module](./string.md) - String operations
