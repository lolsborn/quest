#!/usr/bin/env quest
# PostgreSQL UUID Example - All UUID versions with PostgreSQL

use "std/db/postgres" as db
use "std/uuid" as uuid

puts("=== PostgreSQL UUID Integration ===")
puts("")

# Connection string - adjust as needed
let conn_str = "host=localhost port=6432 user=quest password=quest_password dbname=quest_test"
let conn = db.connect(conn_str)
let cursor = conn.cursor()

puts("1. Creating table with UUID columns...")
cursor.execute("DROP TABLE IF EXISTS uuid_examples")
cursor.execute("CREATE TABLE uuid_examples (id UUID PRIMARY KEY, version INT, name TEXT, created_at TIMESTAMP DEFAULT NOW())")
puts("   Table created")
puts("")

puts("2. Inserting all UUID versions...")

# v1: Timestamp-based
let v1_id = uuid.v1()
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v1_id, 1, "v1 - Timestamp + Node ID"])

# v3: MD5 namespace-based (deterministic)
let v3_id = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v3_id, 3, "v3 - MD5 namespace (deterministic)"])

# v4: Random
let v4_id = uuid.v4()
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v4_id, 4, "v4 - Random"])

# v5: SHA-1 namespace-based (deterministic, preferred over v3)
let v5_id = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v5_id, 5, "v5 - SHA-1 namespace (deterministic)"])

# v6: Improved timestamp-based
let v6_id = uuid.v6()
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v6_id, 6, "v6 - Improved timestamp"])

# v7: Unix timestamp (best for databases)
let v7_id = uuid.v7()
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v7_id, 7, "v7 - Unix timestamp (RECOMMENDED)"])

# v8: Custom data
let v8_data = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10"
let v8_id = uuid.v8(v8_data)
cursor.execute("INSERT INTO uuid_examples (id, version, name) VALUES ($1, $2, $3)",
    [v8_id, 8, "v8 - Custom data"])

puts("   Inserted 7 UUID versions")
puts("")

puts("3. Retrieving all UUIDs...")
cursor.execute("SELECT * FROM uuid_examples ORDER BY version")
let rows = cursor.fetch_all()

rows.each(fun (row)
    puts("   v" .. row.get("version") .. ": " .. row.get("id").to_string() .. " - " .. row.get("name"))
end)
puts("")

puts("4. Demonstrating v7 UUID ordering (best for indexes)...")
cursor.execute("DROP TABLE IF EXISTS events")
cursor.execute("CREATE TABLE events (id UUID PRIMARY KEY, event_name TEXT)")

# Insert v7 UUIDs in random order
let events = [
    {"id": uuid.v7(), "name": "Event C"},
    {"id": uuid.v7(), "name": "Event A"},
    {"id": uuid.v7(), "name": "Event D"},
    {"id": uuid.v7(), "name": "Event B"}
]

events.each(fun (event)
    cursor.execute("INSERT INTO events VALUES ($1, $2)", [event.get("id"), event.get("name")])
end)

# Query ordered by UUID - should match insertion time order
cursor.execute("SELECT * FROM events ORDER BY id")
let event_rows = cursor.fetch_all()

puts("   Events ordered by v7 UUID (automatically time-ordered):")
event_rows.each(fun (event)
    puts("     " .. event.get("event_name") .. ": " .. event.get("id").to_string())
end)
puts("")

puts("5. Demonstrating deterministic UUIDs (v5)...")
puts("   Same input always produces same UUID - useful for idempotency")

let email1 = "alice@example.com"
let email2 = "bob@example.com"

# Generate UUIDs from emails
let alice_id_1 = uuid.v5(uuid.NAMESPACE_DNS, email1)
let alice_id_2 = uuid.v5(uuid.NAMESPACE_DNS, email1)  # Same email
let bob_id = uuid.v5(uuid.NAMESPACE_DNS, email2)

puts("   Alice UUID #1: " .. alice_id_1.to_string())
puts("   Alice UUID #2: " .. alice_id_2.to_string())
puts("   Same? " .. alice_id_1.eq(alice_id_2))
puts("")
puts("   Bob UUID:      " .. bob_id.to_string())
puts("   Different from Alice? " .. alice_id_1.neq(bob_id))
puts("")

puts("6. Querying by UUID...")
cursor.execute("SELECT * FROM uuid_examples WHERE id = $1", [v7_id])
let found = cursor.fetch_one()
puts("   Found: " .. found.get("name"))
puts("")

# Cleanup
puts("Cleaning up...")
cursor.execute("DROP TABLE uuid_examples")
cursor.execute("DROP TABLE events")
conn.close()

puts("")
puts("=== Recommendations ===")
puts("• Use v7 for database primary keys (best index performance)")
puts("• Use v4 for general unique identifiers")
puts("• Use v5 for deterministic/idempotent operations")
puts("• PostgreSQL handles all UUID versions seamlessly")
