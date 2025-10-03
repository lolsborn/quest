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
puts("price cls: ", rows[0].get("price").cls())
puts("price value: ", rows[0].get("price"))
puts("large_num cls: ", rows[0].get("large_num").cls())
puts("large_num value: ", rows[0].get("large_num"))

# Check if we lose precision
let price = rows[0].get("price")
let large_num = rows[0].get("large_num")

puts("\nAs Num, price: ", price)
puts("As Num, large_num: ", large_num)

# Check actual precision
if price == 123.4567
    puts("✓ Price precision maintained")
else
    puts("✗ Price precision lost: expected 123.4567, got ", price)
end

cursor.execute("DROP TABLE test_decimal")
conn.close()

puts("\n✓ DECIMAL test completed")
