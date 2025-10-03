#!/usr/bin/env quest
# Comprehensive example of all UUID versions

use "std/uuid" as uuid

puts("=== All UUID Versions ===")
puts("")

# v1: Timestamp + Node ID
puts("UUID v1 (timestamp + node ID):")
let v1 = uuid.v1()
puts("  Random node: " .. v1.to_string())
let v1_custom = uuid.v1(b"\x01\x02\x03\x04\x05\x06")
puts("  Custom node: " .. v1_custom.to_string())
puts("  Version: " .. v1.version())
puts("")

# v3: MD5 namespace-based (deterministic)
puts("UUID v3 (MD5 namespace-based, deterministic):")
let v3_dns = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
let v3_same = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
puts("  Domain name: " .. v3_dns.to_string())
puts("  Same input:  " .. v3_same.to_string())
puts("  Deterministic: " .. v3_dns.eq(v3_same))
puts("")

# v4: Random (most common)
puts("UUID v4 (random, general purpose):")
let v4_1 = uuid.v4()
let v4_2 = uuid.v4()
puts("  Random #1: " .. v4_1.to_string())
puts("  Random #2: " .. v4_2.to_string())
puts("  Different: " .. v4_1.neq(v4_2))
puts("")

# v5: SHA-1 namespace-based (deterministic, preferred over v3)
puts("UUID v5 (SHA-1 namespace-based, deterministic, preferred):")
let v5_url = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
let v5_same = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
puts("  URL:        " .. v5_url.to_string())
puts("  Same input: " .. v5_same.to_string())
puts("  Deterministic: " .. v5_url.eq(v5_same))
puts("")

# Compare v3 vs v5
let v3_test = uuid.v3(uuid.NAMESPACE_DNS, "test")
let v5_test = uuid.v5(uuid.NAMESPACE_DNS, "test")
puts("  v3 and v5 differ: " .. v3_test.neq(v5_test))
puts("")

# v6: Improved timestamp-based (preferred over v1)
puts("UUID v6 (improved timestamp-based, preferred over v1):")
let v6 = uuid.v6()
puts("  Random node: " .. v6.to_string())
let v6_custom = uuid.v6(b"\xAA\xBB\xCC\xDD\xEE\xFF")
puts("  Custom node: " .. v6_custom.to_string())
puts("  Version: " .. v6.version())
puts("")

# v7: Unix timestamp (best for databases)
puts("UUID v7 (Unix timestamp, best for databases):")
let v7_1 = uuid.v7()
let v7_2 = uuid.v7()
let v7_3 = uuid.v7()
puts("  Sequential #1: " .. v7_1.to_string())
puts("  Sequential #2: " .. v7_2.to_string())
puts("  Sequential #3: " .. v7_3.to_string())
puts("  Sortable: " .. (v7_1.to_string() < v7_2.to_string() and v7_2.to_string() < v7_3.to_string()))
puts("")

# v8: Custom data
puts("UUID v8 (custom 16-byte data):")
let custom_data = b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF"
let v8 = uuid.v8(custom_data)
puts("  Custom: " .. v8.to_string())
puts("  Version: " .. v8.version())
puts("")

# Namespace constants
puts("=== Namespace Constants ===")
puts("NAMESPACE_DNS:  " .. uuid.NAMESPACE_DNS.to_string())
puts("NAMESPACE_URL:  " .. uuid.NAMESPACE_URL.to_string())
puts("NAMESPACE_OID:  " .. uuid.NAMESPACE_OID.to_string())
puts("NAMESPACE_X500: " .. uuid.NAMESPACE_X500.to_string())
puts("")

# Use cases
puts("=== Recommended Use Cases ===")
puts("")

puts("Database Primary Keys (sortable, index-friendly):")
puts("  Use v7: " .. uuid.v7().to_string())
puts("")

puts("General Unique IDs (unpredictable):")
puts("  Use v4: " .. uuid.v4().to_string())
puts("")

puts("Deterministic IDs (idempotent operations):")
let user_email = "alice@example.com"
let user_uuid = uuid.v5(uuid.NAMESPACE_DNS, user_email)
puts("  Use v5: " .. user_uuid.to_string())
puts("  Same email always gives same UUID")
puts("")

puts("Content-Addressable Storage:")
let content = "Hello, World!"
let content_uuid = uuid.v5(uuid.NAMESPACE_OID, content)
puts("  Use v5: " .. content_uuid.to_string())
puts("")

# Nil UUID
puts("=== Special UUID ===")
let null_id = uuid.nil_uuid()
puts("Nil UUID: " .. null_id.to_string())
puts("Is nil: " .. null_id.is_nil())
