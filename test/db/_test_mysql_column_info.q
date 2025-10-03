use "std/db/mysql" as db

let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

let conn = db.connect(CONN_STR)
let cursor = conn.cursor()

# Create a test table with various types
cursor.execute("DROP TABLE IF EXISTS test_col_info")
cursor.execute("CREATE TABLE test_col_info (dt DATETIME, d DATE, t TIME, n INT)")
cursor.execute("INSERT INTO test_col_info VALUES ('2025-01-15 10:30:45', '2025-01-15', '10:30:45', 42)")

cursor.execute("SELECT * FROM test_col_info")
let desc = cursor.description()

puts("Column descriptions:")
for col in desc
    puts("  ", col.get("name"), ": ", col.get("type_code"))
end

cursor.execute("DROP TABLE test_col_info")
conn.close()
