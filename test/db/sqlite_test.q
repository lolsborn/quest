use "std/test" as test
use "std/db/sqlite" as db

test.module("SQLite Database")

test.describe("Connection", fun ()
    test.it("connects to in-memory database", fun ()
        let conn = db.connect(":memory:")
        test.assert_not_nil(conn, "Connection should not be nil")
        conn.close()
    end)

    test.it("creates and queries table", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
        cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])

        cursor.execute("SELECT * FROM users")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")
        test.assert_eq(rows[0].get("age"), 30, "Age should be 30")

        conn.close()
    end)
end)

test.describe("Cursor Operations", fun ()
    test.it("returns correct row_count after INSERT", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

        test.assert_eq(cursor.row_count(), 1, "Should have inserted 1 row")

        conn.close()
    end)

    test.it("fetch_one returns single row", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

        cursor.execute("SELECT * FROM users")
        let row1 = cursor.fetch_one()
        test.assert_eq(row1.get("name"), "Alice", "First row should be Alice")

        let row2 = cursor.fetch_one()
        test.assert_eq(row2.get("name"), "Bob", "Second row should be Bob")

        let row3 = cursor.fetch_one()
        test.assert_nil(row3, "Third fetch should return nil")

        conn.close()
    end)

    test.it("fetch_many returns limited rows", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
        cursor.execute("INSERT INTO users (name) VALUES (?)", ["Charlie"])

        cursor.execute("SELECT * FROM users")
        let rows = cursor.fetch_many(2)

        test.assert_eq(rows.len(), 2, "Should fetch 2 rows")
        test.assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
        test.assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")

        conn.close()
    end)

    test.it("description returns column metadata", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
        cursor.execute("SELECT * FROM users")

        let desc = cursor.description()
        test.assert_not_nil(desc, "Description should not be nil")
        test.assert_eq(desc.len(), 2, "Should have 2 columns")
        test.assert_eq(desc[0].get("name"), "id", "First column is id")
        test.assert_eq(desc[1].get("name"), "name", "Second column is name")

        conn.close()
    end)
end)

test.describe("Parameter Binding", fun ()
    test.it("supports positional parameters", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
        cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])

        cursor.execute("SELECT * FROM users WHERE name = ?", ["Alice"])
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should find 1 row")
        test.assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")

        conn.close()
    end)

    test.it("supports named parameters", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
        cursor.execute("INSERT INTO users (name, age) VALUES (:name, :age)", {"name": "Bob", "age": 25})

        cursor.execute("SELECT * FROM users WHERE name = :name", {"name": "Bob"})
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should find 1 row")
        test.assert_eq(rows[0].get("name"), "Bob", "Name should be Bob")
        test.assert_eq(rows[0].get("age"), 25, "Age should be 25")

        conn.close()
    end)

    test.it("handles various data types", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        cursor.execute("CREATE TABLE data (id INTEGER PRIMARY KEY, text_col TEXT, num_col REAL, blob_col BLOB)")
        cursor.execute("INSERT INTO data (text_col, num_col, blob_col) VALUES (?, ?, ?)", ["hello", 3.14, b"\xFF\x00"])

        cursor.execute("SELECT * FROM data")
        let rows = cursor.fetch_all()

        test.assert_eq(rows.len(), 1, "Should have 1 row")
        test.assert_eq(rows[0].get("text_col"), "hello", "Text should match")
        test.assert_near(rows[0].get("num_col"), 3.14, 0.001, "Number should match")

        conn.close()
    end)
end)

test.describe("Error Handling", fun ()
    test.it("raises error on invalid SQL", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        test.assert_raises("DatabaseError", fun()
            cursor.execute("INVALID SQL SYNTAX")
        end, nil)

        conn.close()
    end)

    test.it("raises error on missing table", fun ()
        let conn = db.connect(":memory:")
        let cursor = conn.cursor()

        test.assert_raises("ProgrammingError", fun()
            cursor.execute("SELECT * FROM nonexistent_table")
        end, nil)

        conn.close()
    end)
end)

test.describe("Module Functions", fun ()
    test.it("returns SQLite version", fun ()
        let version = db.version()
        test.assert_not_nil(version, "Version should not be nil")
        test.assert(version.len() > 0, "Version should not be empty")
    end)
end)
