#!/usr/bin/env quest
# UUID Examples - Demonstrates UUID generation and usage

use "std/uuid" as uuid

puts("=== UUID Generation ===")

# Generate random v4 UUID (unpredictable)
let id1 = uuid.v4()
puts("Generated v4 UUID: " .. id1.to_string())

# Generate another to show they're different
let id2 = uuid.v4()
puts("Another v4 UUID:   " .. id2.to_string())

# Generate v7 UUID (time-ordered, sortable)
let id_v7_1 = uuid.v7()
puts("Generated v7 UUID: " .. id_v7_1.to_string())

let id_v7_2 = uuid.v7()
puts("Another v7 UUID:   " .. id_v7_2.to_string())

# v7 UUIDs are lexicographically sortable
puts("v7 ordering: " .. id_v7_1.to_string() .. " < " .. id_v7_2.to_string() .. " = " .. (id_v7_1.to_string() < id_v7_2.to_string()))

puts("")
puts("=== UUID Formats ===")

let sample_id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")

# Different string representations
puts("Hyphenated: " .. sample_id.to_hyphenated())
puts("Simple:     " .. sample_id.to_simple())
puts("URN:        " .. sample_id.to_urn())

puts("")
puts("=== UUID Metadata ===")

puts("Version:    " .. id1.version())
puts("Variant:    " .. id1.variant())
puts("Is nil?     " .. id1.is_nil())

# Nil UUID
let null_id = uuid.nil_uuid()
puts("Nil UUID:   " .. null_id.to_string())
puts("Is nil?     " .. null_id.is_nil())

puts("")
puts("=== UUID Comparison ===")

let id_a = uuid.v4()
let id_b = uuid.v4()
let id_c = uuid.parse(id_a.to_string())

puts("id_a == id_b: " .. id_a.eq(id_b))  # false (different)
puts("id_a == id_c: " .. id_a.eq(id_c))  # true (same value)
puts("id_a != id_b: " .. id_a.neq(id_b)) # true

puts("")
puts("=== Bytes Conversion ===")

let original = uuid.v4()
puts("Original:      " .. original.to_string())

# Convert to bytes
let bytes = original.to_bytes()
puts("Bytes length:  " .. bytes.len())

# Reconstruct from bytes
let reconstructed = uuid.from_bytes(bytes)
puts("Reconstructed: " .. reconstructed.to_string())
puts("Match:         " .. original.eq(reconstructed))

puts("")
puts("=== Parsing UUIDs ===")

# Parse with hyphens
let uuid1 = uuid.parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
puts("Parsed (hyphenated): " .. uuid1.to_string())

# Parse without hyphens
let uuid2 = uuid.parse("6ba7b8109dad11d180b400c04fd430c8")
puts("Parsed (simple):     " .. uuid2.to_string())

# Both produce the same UUID
puts("Are equal: " .. uuid1.eq(uuid2))

puts("")
puts("=== Error Handling ===")

try
    # Try to parse invalid UUID
    uuid.parse("not-a-valid-uuid")
    puts("Should not reach here!")
catch e
    puts("Caught error: " .. e.message())
end

try
    # Try to create UUID from wrong byte count
    uuid.from_bytes(b"\x01\x02\x03")
    puts("Should not reach here!")
catch err
    puts("Caught error: " .. err.message())
end

puts("")
puts("=== Use Case: ID Generation ===")

# v4 for general purposes (unpredictable IDs)
puts("Using v4 for API keys (unpredictable):")
let api_keys = [uuid.v4(), uuid.v4(), uuid.v4()]
api_keys.each(fun (key)
    puts("  API Key: " .. key.to_string())
end)

puts("")
puts("Using v7 for database primary keys (sortable, timestamp-based):")
# v7 for database primary keys (sortable, better index performance)
let users = [
    {"id": uuid.v7(), "name": "Alice"},
    {"id": uuid.v7(), "name": "Bob"},
    {"id": uuid.v7(), "name": "Charlie"},
    {"id": uuid.v7(), "name": "Diana"},
    {"id": uuid.v7(), "name": "Eve"}
]

puts("Generated " .. users.len() .. " users with v7 IDs:")
users.each(fun (user)
    puts("  " .. user.get("name") .. ": " .. user.get("id").to_string())
end)
