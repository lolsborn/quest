# UUID (Universally Unique Identifier) Module
# Wrapper for the std/uuid module

use "uuid" as uuid

# Generate a random UUID v4
fun v4()
    uuid.v4()
end

# Generate a time-ordered UUID v7 (sortable, includes timestamp)
fun v7()
    uuid.v7()
end

# Create a nil UUID (all zeros)
fun nil_uuid()
    uuid.nil_uuid()
end

# Parse a UUID from a string
# Returns a Uuid object or raises an error if invalid
fun parse(str)
    uuid.parse(str)
end

# Create a UUID from 16 bytes
# Returns a Uuid object or raises an error if not exactly 16 bytes
fun from_bytes(bytes)
    uuid.from_bytes(bytes)
end

# Generate a UUID v1 (timestamp and node ID based)
# Optional node_id parameter (6 bytes) - if not provided, generates random
fun v1(node_id?)
    if node_id == nil
        uuid.v1()
    else
        uuid.v1(node_id)
    end
end

# Generate a UUID v3 (MD5 namespace-based)
# namespace: Uuid object (use NAMESPACE_DNS, NAMESPACE_URL, etc.)
# name: String or Bytes to hash
fun v3(namespace, name)
    uuid.v3(namespace, name)
end

# Generate a UUID v5 (SHA1 namespace-based, preferred over v3)
# namespace: Uuid object (use NAMESPACE_DNS, NAMESPACE_URL, etc.)
# name: String or Bytes to hash
fun v5(namespace, name)
    uuid.v5(namespace, name)
end

# Generate a UUID v6 (timestamp-based, improved v1)
# Optional node_id parameter (6 bytes) - if not provided, generates random
fun v6(node_id?)
    if node_id == nil
        uuid.v6()
    else
        uuid.v6(node_id)
    end
end

# Generate a UUID v8 (custom user-defined data)
# data: 16 bytes of custom data
fun v8(data)
    uuid.v8(data)
end

# Namespace constants
let NAMESPACE_DNS = uuid.NAMESPACE_DNS
let NAMESPACE_URL = uuid.NAMESPACE_URL
let NAMESPACE_OID = uuid.NAMESPACE_OID
let NAMESPACE_X500 = uuid.NAMESPACE_X500
