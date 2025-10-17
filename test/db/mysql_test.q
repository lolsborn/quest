use "std/test" {
    module,
    it,
    describe,
    assert_type,
    assert_not_nil,
    assert_near,
    assert_nil,
    assert_raises,
    assert,
    assert_eq
}
use "std/db/mysql" as db
use "std/uuid" as _uuid

# Connection string - adjust if needed
let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

module("MySQL Database")

describe("Connection", fun ()
  it("connects to database", fun ()
    let conn = db.connect(CONN_STR)
    assert_not_nil(conn, "Connection should not be nil")
    conn.close()
  end)

  it("creates and queries table", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    # Drop table if exists
    try
      cursor.execute("DROP TABLE IF EXISTS test_users")
    catch e
      # Ignore errors
    end

    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), age INT)")
    cursor.execute("INSERT INTO test_users (name, age) VALUES (?, ?)", ["Alice", 30])

    cursor.execute("SELECT * FROM test_users")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")
    assert_eq(rows[0].get("age"), 30, "Age should be 30")

    # Cleanup
    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)
end)

describe("Cursor Operations", fun ()
  it("returns correct row_count after INSERT", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])

    assert_eq(cursor.row_count(), 1, "Should have inserted 1 row")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("fetch_one returns single row", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])

    cursor.execute("SELECT * FROM test_users ORDER BY id")
    let row1 = cursor.fetch_one()
    assert_eq(row1.get("name"), "Alice", "First row should be Alice")

    let row2 = cursor.fetch_one()
    assert_eq(row2.get("name"), "Bob", "Second row should be Bob")

    let row3 = cursor.fetch_one()
    assert_nil(row3, "Third fetch should return nil")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("fetch_many returns limited rows", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Charlie"])

    cursor.execute("SELECT * FROM test_users ORDER BY id")
    let rows = cursor.fetch_many(2)

    assert_eq(rows.len(), 2, "Should fetch 2 rows")
    assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
    assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("fetch_all returns all rows", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])
    cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Charlie"])

    cursor.execute("SELECT * FROM test_users ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should fetch 3 rows")
    assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
    assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")
    assert_eq(rows[2].get("name"), "Charlie", "Third should be Charlie")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("description returns column metadata", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), age INT)")
    cursor.execute("INSERT INTO test_users (name, age) VALUES (?, ?)", ["Alice", 30])

    cursor.execute("SELECT id, name, age FROM test_users")
    let desc = cursor.description()

    assert_not_nil(desc, "Description should not be nil")
    assert_eq(desc.len(), 3, "Should have 3 columns")
    assert_eq(desc[0].get("name"), "id", "First column should be id")
    assert_eq(desc[1].get("name"), "name", "Second column should be name")
    assert_eq(desc[2].get("name"), "age", "Third column should be age")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)
end)

describe("Data Types", fun ()
  it("handles NULL values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_nulls")
    cursor.execute("CREATE TABLE test_nulls (id INT AUTO_INCREMENT PRIMARY KEY, value VARCHAR(255))")
    cursor.execute("INSERT INTO test_nulls (value) VALUES (NULL)")

    cursor.execute("SELECT * FROM test_nulls")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("value"), "Value should be nil")

    cursor.execute("DROP TABLE test_nulls")
    conn.close()
  end)

  it("handles integers", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_ints")
    cursor.execute("CREATE TABLE test_ints (id INT AUTO_INCREMENT PRIMARY KEY, value INT)")
    cursor.execute("INSERT INTO test_ints (value) VALUES (?)", [42])
    cursor.execute("INSERT INTO test_ints (value) VALUES (?)", [-100])

    cursor.execute("SELECT * FROM test_ints ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 2, "Should have 2 rows")
    assert_eq(rows[0].get("value"), 42, "First value should be 42")
    assert_eq(rows[1].get("value"), -100, "Second value should be -100")

    cursor.execute("DROP TABLE test_ints")
    conn.close()
  end)

  it("handles floats", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_floats")
    cursor.execute("CREATE TABLE test_floats (id INT AUTO_INCREMENT PRIMARY KEY, value DOUBLE)")
    cursor.execute("INSERT INTO test_floats (value) VALUES (?)", [3.14])
    cursor.execute("INSERT INTO test_floats (value) VALUES (?)", [-2.5])

    cursor.execute("SELECT * FROM test_floats ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 2, "Should have 2 rows")
    assert_near(rows[0].get("value"), 3.14, 0.01, "First value should be 3.14")
    assert_near(rows[1].get("value"), -2.5, 0.01, "Second value should be -2.5")

    cursor.execute("DROP TABLE test_floats")
    conn.close()
  end)

  it("handles strings", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_strings")
    cursor.execute("CREATE TABLE test_strings (id INT AUTO_INCREMENT PRIMARY KEY, value VARCHAR(255))")
    cursor.execute("INSERT INTO test_strings (value) VALUES (?)", ["Hello, World!"])
    cursor.execute("INSERT INTO test_strings (value) VALUES (?)", [""])

    cursor.execute("SELECT * FROM test_strings ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 2, "Should have 2 rows")
    assert_eq(rows[0].get("value"), "Hello, World!", "First value should be 'Hello, World!'")
    assert_eq(rows[1].get("value"), "", "Second value should be empty string")

    cursor.execute("DROP TABLE test_strings")
    conn.close()
  end)

  it("handles BLOB data", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_blobs")
    cursor.execute("CREATE TABLE test_blobs (id INT AUTO_INCREMENT PRIMARY KEY, data BLOB)")
    cursor.execute("INSERT INTO test_blobs (data) VALUES (?)", [b"\xFF\x00\x42"])

    cursor.execute("SELECT * FROM test_blobs")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let data = rows[0].get("data")
    assert_eq(data.len(), 3, "Data should have 3 bytes")

    cursor.execute("DROP TABLE test_blobs")
    conn.close()
  end)
end)

describe("UUID Type", fun ()
  it("handles UUID columns stored as BINARY(16)", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_uuids")
    cursor.execute("CREATE TABLE test_uuids (id INT AUTO_INCREMENT PRIMARY KEY, uuid_col BINARY(16))")

    let test_uuid = _uuid.v4()
    cursor.execute("INSERT INTO test_uuids (uuid_col) VALUES (?)", [test_uuid])

    cursor.execute("SELECT * FROM test_uuids")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_type(rows[0].get("uuid_col"), "Uuid", "Should be Uuid type")
    assert_eq(rows[0].get("uuid_col").to_string(), test_uuid.to_string(), "UUID should match")

    cursor.execute("DROP TABLE test_uuids")
    conn.close()
  end)

  it("handles UUID primary keys", fun ()
    use "std/uuid" as _uuid
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_uuid_pk")
    cursor.execute("CREATE TABLE test_uuid_pk (id BINARY(16) PRIMARY KEY, name VARCHAR(255))")

    let id1 = _uuid.v4()
    let id2 = _uuid.v4()
    cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES (?, ?)", [id1, "Alice"])
    cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES (?, ?)", [id2, "Bob"])

    cursor.execute("SELECT * FROM test_uuid_pk ORDER BY name")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 2, "Should have 2 rows")
    assert_eq(rows[0].get("id").to_string(), id1.to_string(), "First UUID should match")
    assert_eq(rows[1].get("id").to_string(), id2.to_string(), "Second UUID should match")

    cursor.execute("DROP TABLE test_uuid_pk")
    conn.close()
  end)

  it("handles NULL UUID values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_uuids")
    cursor.execute("CREATE TABLE test_null_uuids (id INT AUTO_INCREMENT PRIMARY KEY, uuid_col BINARY(16))")
    cursor.execute("INSERT INTO test_null_uuids (uuid_col) VALUES (NULL)")

    cursor.execute("SELECT * FROM test_null_uuids")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("uuid_col"), "NULL UUID should be nil")

    cursor.execute("DROP TABLE test_null_uuids")
    conn.close()
  end)

  it("queries by UUID", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_uuid_query")
    cursor.execute("CREATE TABLE test_uuid_query (id BINARY(16) PRIMARY KEY, value VARCHAR(255))")

    let target_id = _uuid.v4()
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [_uuid.v4(), "First"])
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [target_id, "Target"])
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [_uuid.v4(), "Third"])

    cursor.execute("SELECT * FROM test_uuid_query WHERE id = ?", [target_id])
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 row")
    assert_eq(rows[0].get("value"), "Target", "Should find correct row")
    assert_eq(rows[0].get("id").to_string(), target_id.to_string(), "ID should match")

    cursor.execute("DROP TABLE test_uuid_query")
    conn.close()
  end)

  it("handles UUID v7 for time-ordered keys", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_v7_uuids")
    cursor.execute("CREATE TABLE test_v7_uuids (id BINARY(16) PRIMARY KEY, seq INT)")

    # Insert v7 UUIDs (which are time-ordered)
    let id1 = _uuid.v7()
    let id2 = _uuid.v7()
    let id3 = _uuid.v7()

    cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id1, 1])
    cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id2, 2])
    cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id3, 3])

    cursor.execute("SELECT * FROM test_v7_uuids ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should have 3 rows")
    assert_eq(rows[0].get("seq"), 1, "First should be seq 1")
    assert_eq(rows[1].get("seq"), 2, "Second should be seq 2")
    assert_eq(rows[2].get("seq"), 3, "Third should be seq 3")

    cursor.execute("DROP TABLE test_v7_uuids")
    conn.close()
  end)
end)

describe("Transactions", fun ()
  it("commits transaction", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_txn")
    cursor.execute("CREATE TABLE test_txn (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")

    cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Bob"])
    conn.commit()

    cursor.execute("SELECT COUNT(*) as count FROM test_txn")
    let rows = cursor.fetch_all()
    assert_eq(rows[0].get("count"), 2, "Should have 2 rows after commit")

    cursor.execute("DROP TABLE test_txn")
    conn.close()
  end)

  it("rolls back transaction", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_txn")
    cursor.execute("CREATE TABLE test_txn (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
    cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Alice"])
    conn.commit()

    cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Bob"])
    conn.rollback()

    cursor.execute("SELECT COUNT(*) as count FROM test_txn")
    let rows = cursor.fetch_all()
    assert_eq(rows[0].get("count"), 1, "Should have 1 row after rollback")

    cursor.execute("DROP TABLE test_txn")
    conn.close()
  end)
end)

describe("Execute Many", fun ()
  it("executes multiple inserts", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_many")
    cursor.execute("CREATE TABLE test_many (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), age INT)")

    let data = [
      ["Alice", 30],
      ["Bob", 25],
      ["Charlie", 35]
    ]
    cursor.execute_many("INSERT INTO test_many (name, age) VALUES (?, ?)", data)

    cursor.execute("SELECT * FROM test_many ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should have 3 rows")
    assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
    assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")
    assert_eq(rows[2].get("name"), "Charlie", "Third should be Charlie")

    cursor.execute("DROP TABLE test_many")
    conn.close()
  end)
end)

describe("Error Handling", fun ()
  it("raises error on invalid SQL", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    assert_raises(Err, fun ()
      cursor.execute("THIS IS INVALID SQL")
    end)

    conn.close()
  end)

  it("raises error on missing table", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    assert_raises(Err, fun ()
      cursor.execute("SELECT * FROM nonexistent_table")
    end)

    conn.close()
  end)
end)
