# Quick test for MySQL UUID handling
# Run manually: ./target/release/quest test/db/_test_mysql_uuid.q

use "std/db/mysql" as db
use "std/uuid" as uuid

puts("Testing MySQL UUID handling...")

let conn = db.connect("mysql://quest:quest_password@localhost:6603/quest_test")
let cursor = conn.cursor()

# Create table with BINARY(16) for UUID storage
try
    cursor.execute("DROP TABLE IF EXISTS test_uuid_handling")
catch e
    # Ignore
end

cursor.execute("CREATE TABLE test_uuid_handling (id BINARY(16) PRIMARY KEY, name VARCHAR(255))")

# Test UUID v4
let test_uuid = uuid.v4()
puts("Original UUID: " .. test_uuid.to_string())

cursor.execute("INSERT INTO test_uuid_handling (id, name) VALUES (?, ?)", [test_uuid, "Test User"])

cursor.execute("SELECT * FROM test_uuid_handling")
let rows = cursor.fetch_all()

puts("Rows retrieved: " .. rows.len()._str())
if rows.len() > 0
    let retrieved_uuid = rows[0].get("id")
    puts("Retrieved type: " .. retrieved_uuid.cls())
    puts("Retrieved UUID: " .. retrieved_uuid.to_string())

    if retrieved_uuid.cls() == "Uuid"
        puts("✓ UUID type correctly preserved!")

        if retrieved_uuid.to_string() == test_uuid.to_string()
            puts("✓ UUID value matches!")
        else
            puts("✗ UUID value mismatch!")
        end
    else
        puts("✗ UUID not recognized as Uuid type, got: " .. retrieved_uuid.cls())
    end
end

# Cleanup
cursor.execute("DROP TABLE test_uuid_handling")
conn.close()

puts("Test complete!")
