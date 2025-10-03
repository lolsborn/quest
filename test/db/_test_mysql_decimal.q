use "std/db/mysql" as db

let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

let conn = db.connect(CONN_STR)
let cursor = conn.cursor()

# Test DECIMAL precision
cursor.execute("DROP TABLE IF EXISTS test_decimal")
cursor.execute("CREATE TABLE test_decimal (id INT AUTO_INCREMENT PRIMARY KEY, price DECIMAL(19,4), large_num DECIMAL(38,10))")

# Insert precise decimal values
cursor.execute("INSERT INTO test_decimal (price, large_num) VALUES (?, ?)", ["123.4567", "12345678901234567890.1234567890"])

# Query back
cursor.execute("SELECT * FROM test_decimal")
let rows = cursor.fetch_all()

puts("Row: ", rows[0])
puts("\nprice cls: ", rows[0].get("price").cls())
puts("price value: ", rows[0].get("price"))
puts("price repr: ", rows[0].get("price")._rep())

puts("\nlarge_num cls: ", rows[0].get("large_num").cls())
puts("large_num value: ", rows[0].get("large_num"))
puts("large_num repr: ", rows[0].get("large_num")._rep())

# Check if we maintain precision with Decimal type
let price = rows[0].get("price")
let large_num = rows[0].get("large_num")

# Convert to string to check exact precision
let price_str = price.to_string()
let large_num_str = large_num.to_string()

puts("\nprice as string: ", price_str)
puts("large_num as string: ", large_num_str)

# Check if precision is maintained
if price_str == "123.4567"
    puts("✓ Price precision maintained (123.4567)")
else
    puts("✗ Price precision issue: expected 123.4567, got ", price_str)
end

if large_num_str == "12345678901234567890.1234567890"
    puts("✓ Large number precision maintained!")
else
    puts("⚠ Large number: expected 12345678901234567890.1234567890, got ", large_num_str)
end

cursor.execute("DROP TABLE test_decimal")
conn.close()

puts("\n✓ DECIMAL test completed")
