use "std/test" as test
use "std/db/mysql" as db

# Connection string - adjust if needed
let CONN_STR = "mysql://quest:quest_password@localhost:6603/quest_test"

test.module("MySQL Database")

test.describe("Connection", fun ()
    test.it("connects to database", fun ()
        let conn = db.connect(CONN_STR)
        test.assert_not_nil(conn, "Connection should not be nil")
        conn.close()
    end)

    test.it("creates and queries table", fun ()
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

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")
        test.assert_eq(rows[0].get("age"), 30, "Age should be 30")

        # Cleanup
        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)
end)

test.describe("Cursor Operations", fun ()
    test.it("returns correct row_count after INSERT", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_users")
        cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])

        test.assert_eq(cursor.row_count(), 1, "Should have inserted 1 row")

        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)

    test.it("fetch_one returns single row", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_users")
        cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])

        cursor.execute("SELECT * FROM test_users ORDER BY id")
        let row1 = cursor.fetch_one()
        test.assert_eq(row1.get("name"), "Alice", "First row should be Alice")

        let row2 = cursor.fetch_one()
        test.assert_eq(row2.get("name"), "Bob", "Second row should be Bob")

        let row3 = cursor.fetch_one()
        test.assert_nil(row3, "Third fetch should return nil")

        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)

    test.it("fetch_many returns limited rows", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_users")
        cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Charlie"])

        cursor.execute("SELECT * FROM test_users ORDER BY id")
        let rows = cursor.fetch_many(2)

        test.assert_eq(rows.len(), 2, "Should fetch 2 rows")
        test.assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
        test.assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")

        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)

    test.it("fetch_all returns all rows", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_users")
        cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Bob"])
        cursor.execute("INSERT INTO test_users (name) VALUES (?)", ["Charlie"])

        cursor.execute("SELECT * FROM test_users ORDER BY id")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 3, "Should fetch 3 rows")
        test.assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
        test.assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")
        test.assert_eq(rows[2].get("name"), "Charlie", "Third should be Charlie")

        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)

    test.it("description returns column metadata", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_users")
        cursor.execute("CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), age INT)")
        cursor.execute("INSERT INTO test_users (name, age) VALUES (?, ?)", ["Alice", 30])

        cursor.execute("SELECT id, name, age FROM test_users")
        let desc = cursor.description()

        test.assert_not_nil(desc, "Description should not be nil")
        test.assert_eq(desc.len(), 3, "Should have 3 columns")
        test.assert_eq(desc[0].get("name"), "id", "First column should be id")
        test.assert_eq(desc[1].get("name"), "name", "Second column should be name")
        test.assert_eq(desc[2].get("name"), "age", "Third column should be age")

        cursor.execute("DROP TABLE test_users")
        conn.close()
    end)
end)

test.describe("Data Types", fun ()
    test.it("handles NULL values", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_nulls")
        cursor.execute("CREATE TABLE test_nulls (id INT AUTO_INCREMENT PRIMARY KEY, value VARCHAR(255))")
        cursor.execute("INSERT INTO test_nulls (value) VALUES (NULL)")

        cursor.execute("SELECT * FROM test_nulls")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_nil(rows[0].get("value"), "Value should be nil")

        cursor.execute("DROP TABLE test_nulls")
        conn.close()
    end)

    test.it("handles integers", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_ints")
        cursor.execute("CREATE TABLE test_ints (id INT AUTO_INCREMENT PRIMARY KEY, value INT)")
        cursor.execute("INSERT INTO test_ints (value) VALUES (?)", [42])
        cursor.execute("INSERT INTO test_ints (value) VALUES (?)", [-100])

        cursor.execute("SELECT * FROM test_ints ORDER BY id")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 2, "Should have 2 rows")
        test.assert_eq(rows[0].get("value"), 42, "First value should be 42")
        test.assert_eq(rows[1].get("value"), -100, "Second value should be -100")

        cursor.execute("DROP TABLE test_ints")
        conn.close()
    end)

    test.it("handles floats", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_floats")
        cursor.execute("CREATE TABLE test_floats (id INT AUTO_INCREMENT PRIMARY KEY, value DOUBLE)")
        cursor.execute("INSERT INTO test_floats (value) VALUES (?)", [3.14])
        cursor.execute("INSERT INTO test_floats (value) VALUES (?)", [-2.5])

        cursor.execute("SELECT * FROM test_floats ORDER BY id")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 2, "Should have 2 rows")
        test.assert_near(rows[0].get("value"), 3.14, 0.01, "First value should be 3.14")
        test.assert_near(rows[1].get("value"), -2.5, 0.01, "Second value should be -2.5")

        cursor.execute("DROP TABLE test_floats")
        conn.close()
    end)

    test.it("handles strings", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_strings")
        cursor.execute("CREATE TABLE test_strings (id INT AUTO_INCREMENT PRIMARY KEY, value VARCHAR(255))")
        cursor.execute("INSERT INTO test_strings (value) VALUES (?)", ["Hello, World!"])
        cursor.execute("INSERT INTO test_strings (value) VALUES (?)", [""])

        cursor.execute("SELECT * FROM test_strings ORDER BY id")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 2, "Should have 2 rows")
        test.assert_eq(rows[0].get("value"), "Hello, World!", "First value should be 'Hello, World!'")
        test.assert_eq(rows[1].get("value"), "", "Second value should be empty string")

        cursor.execute("DROP TABLE test_strings")
        conn.close()
    end)

    test.it("handles BLOB data", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_blobs")
        cursor.execute("CREATE TABLE test_blobs (id INT AUTO_INCREMENT PRIMARY KEY, data BLOB)")
        cursor.execute("INSERT INTO test_blobs (data) VALUES (?)", [b"\xFF\x00\x42"])

        cursor.execute("SELECT * FROM test_blobs")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        let data = rows[0].get("data")
        test.assert_eq(data.len(), 3, "Data should have 3 bytes")

        cursor.execute("DROP TABLE test_blobs")
        conn.close()
    end)
end)

test.describe("UUID Type", fun ()
    test.it("handles UUID columns stored as BINARY(16)", fun ()
        use "std/uuid" as uuid
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_uuids")
        cursor.execute("CREATE TABLE test_uuids (id INT AUTO_INCREMENT PRIMARY KEY, uuid_col BINARY(16))")

        let test_uuid = uuid.v4()
        cursor.execute("INSERT INTO test_uuids (uuid_col) VALUES (?)", [test_uuid])

        cursor.execute("SELECT * FROM test_uuids")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_type(rows[0].get("uuid_col"), "Uuid", "Should be Uuid type")
        test.assert_eq(rows[0].get("uuid_col").to_string(), test_uuid.to_string(), "UUID should match")

        cursor.execute("DROP TABLE test_uuids")
        conn.close()
    end)

    test.it("handles UUID primary keys", fun ()
        use "std/uuid" as uuid
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_uuid_pk")
        cursor.execute("CREATE TABLE test_uuid_pk (id BINARY(16) PRIMARY KEY, name VARCHAR(255))")

        let id1 = uuid.v4()
        let id2 = uuid.v4()
        cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES (?, ?)", [id1, "Alice"])
        cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES (?, ?)", [id2, "Bob"])

        cursor.execute("SELECT * FROM test_uuid_pk ORDER BY name")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 2, "Should have 2 rows")
        test.assert_eq(rows[0].get("id").to_string(), id1.to_string(), "First UUID should match")
        test.assert_eq(rows[1].get("id").to_string(), id2.to_string(), "Second UUID should match")

        cursor.execute("DROP TABLE test_uuid_pk")
        conn.close()
    end)

    test.it("handles NULL UUID values", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_null_uuids")
        cursor.execute("CREATE TABLE test_null_uuids (id INT AUTO_INCREMENT PRIMARY KEY, uuid_col BINARY(16))")
        cursor.execute("INSERT INTO test_null_uuids (uuid_col) VALUES (NULL)")

        cursor.execute("SELECT * FROM test_null_uuids")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_nil(rows[0].get("uuid_col"), "NULL UUID should be nil")

        cursor.execute("DROP TABLE test_null_uuids")
        conn.close()
    end)

    test.it("queries by UUID", fun ()
        use "std/uuid" as uuid
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_uuid_query")
        cursor.execute("CREATE TABLE test_uuid_query (id BINARY(16) PRIMARY KEY, value VARCHAR(255))")

        let target_id = uuid.v4()
        cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [uuid.v4(), "First"])
        cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [target_id, "Target"])
        cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES (?, ?)", [uuid.v4(), "Third"])

        cursor.execute("SELECT * FROM test_uuid_query WHERE id = ?", [target_id])
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should find 1 row")
        test.assert_eq(rows[0].get("value"), "Target", "Should find correct row")
        test.assert_eq(rows[0].get("id").to_string(), target_id.to_string(), "ID should match")

        cursor.execute("DROP TABLE test_uuid_query")
        conn.close()
    end)

    test.it("handles UUID v7 for time-ordered keys", fun ()
        use "std/uuid" as uuid
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_v7_uuids")
        cursor.execute("CREATE TABLE test_v7_uuids (id BINARY(16) PRIMARY KEY, seq INT)")

        # Insert v7 UUIDs (which are time-ordered)
        let id1 = uuid.v7()
        let id2 = uuid.v7()
        let id3 = uuid.v7()

        cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id1, 1])
        cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id2, 2])
        cursor.execute("INSERT INTO test_v7_uuids VALUES (?, ?)", [id3, 3])

        cursor.execute("SELECT * FROM test_v7_uuids ORDER BY id")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 3, "Should have 3 rows")
        test.assert_eq(rows[0].get("seq"), 1, "First should be seq 1")
        test.assert_eq(rows[1].get("seq"), 2, "Second should be seq 2")
        test.assert_eq(rows[2].get("seq"), 3, "Third should be seq 3")

        cursor.execute("DROP TABLE test_v7_uuids")
        conn.close()
    end)
end)

test.describe("Transactions", fun ()
    test.it("commits transaction", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        cursor.execute("DROP TABLE IF EXISTS test_txn")
        cursor.execute("CREATE TABLE test_txn (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))")

        cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO test_txn (name) VALUES (?)", ["Bob"])
        conn.commit()

        cursor.execute("SELECT COUNT(*) as count FROM test_txn")
        let rows = cursor.fetch_all()
        test.assert_eq(rows[0].get("count"), 2, "Should have 2 rows after commit")

        cursor.execute("DROP TABLE test_txn")
        conn.close()
    end)

    test.it("rolls back transaction", fun ()
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
        test.assert_eq(rows[0].get("count"), 1, "Should have 1 row after rollback")

        cursor.execute("DROP TABLE test_txn")
        conn.close()
    end)
end)

test.describe("Execute Many", fun ()
    test.it("executes multiple inserts", fun ()
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

        test.assert_eq(rows.len(), 3, "Should have 3 rows")
        test.assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
        test.assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")
        test.assert_eq(rows[2].get("name"), "Charlie", "Third should be Charlie")

        cursor.execute("DROP TABLE test_many")
        conn.close()
    end)
end)

test.describe("Error Handling", fun ()
    test.it("raises error on invalid SQL", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        test.assert_raises("ProgrammingError", fun ()
            cursor.execute("THIS IS INVALID SQL")
        end, nil)

        conn.close()
    end)

    test.it("raises error on missing table", fun ()
        let conn = db.connect(CONN_STR)
        let cursor = conn.cursor()

        test.assert_raises("ProgrammingError", fun ()
            cursor.execute("SELECT * FROM nonexistent_table")
        end, nil)

        conn.close()
    end)
end)
