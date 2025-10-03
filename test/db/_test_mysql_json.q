use "std/db/mysql" as db
use "std/encoding/json" as json

let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

let conn = db.connect(CONN_STR)
let cursor = conn.cursor()

# Test JSON column type
cursor.execute("DROP TABLE IF EXISTS test_json")
cursor.execute("CREATE TABLE test_json (id INT AUTO_INCREMENT PRIMARY KEY, data JSON)")

# Insert JSON data
let test_obj = {"name": "Alice", "age": 30, "active": true}
let json_str = json.stringify(test_obj)
cursor.execute("INSERT INTO test_json (data) VALUES (?)", [json_str])

# Query and check what we get back
cursor.execute("SELECT * FROM test_json")
let rows = cursor.fetch_all()

puts("Row: ", rows[0])
puts("data cls: ", rows[0].get("data").cls())
puts("data value: ", rows[0].get("data"))

# Try to parse it
let parsed = json.parse(rows[0].get("data"))
puts("parsed: ", parsed)
puts("parsed.name: ", parsed.get("name"))

cursor.execute("DROP TABLE test_json")
conn.close()

puts("\n✓ JSON test completed")
