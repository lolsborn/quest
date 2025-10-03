use "std/db/mysql" as db
use "std/time" as time

let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

let conn = db.connect(CONN_STR)
let cursor = conn.cursor()

# Create table with various date/time types
cursor.execute("DROP TABLE IF EXISTS test_datetime")
cursor.execute("CREATE TABLE test_datetime (id INT AUTO_INCREMENT PRIMARY KEY, date_col DATE, time_col TIME, datetime_col DATETIME, timestamp_col TIMESTAMP)")

# Insert some data using strings
cursor.execute("INSERT INTO test_datetime (date_col, time_col, datetime_col, timestamp_col) VALUES (?, ?, ?, ?)",
    ["2025-01-15", "14:30:45", "2025-01-15 14:30:45", "2025-01-15 14:30:45"])

# Query and check types
cursor.execute("SELECT * FROM test_datetime")
let rows = cursor.fetch_all()

puts("Row count: ", rows.len())
puts("First row: ", rows[0])

# Check what types we get back
puts("\ndate_col cls: ", rows[0].get("date_col").cls())
puts("date_col value: ", rows[0].get("date_col"))

puts("\ntime_col cls: ", rows[0].get("time_col").cls())
puts("time_col value: ", rows[0].get("time_col"))

puts("\ndatetime_col cls: ", rows[0].get("datetime_col").cls())
puts("datetime_col value: ", rows[0].get("datetime_col"))

puts("\ntimestamp_col cls: ", rows[0].get("timestamp_col").cls())
puts("timestamp_col value: ", rows[0].get("timestamp_col"))

# Try inserting using Quest time types
puts("\n=== Testing Quest time type insertion ===")
let now = time.now()
puts("Current timestamp: ", now)

cursor.execute("INSERT INTO test_datetime (datetime_col) VALUES (?)", [now])
cursor.execute("SELECT * FROM test_datetime WHERE id = LAST_INSERT_ID()")
let result = cursor.fetch_one()
puts("Retrieved timestamp: ", result.get("datetime_col"))
puts("Retrieved cls: ", result.get("datetime_col").cls())

# Clean up
cursor.execute("DROP TABLE test_datetime")
conn.close()

puts("\n✓ Date/time tests completed!")
