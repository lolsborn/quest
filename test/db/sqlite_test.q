use "std/test" {
    module,
    it,
    describe,
    assert_nil,
    assert_near,
    assert_raises,
    assert_not_nil,
    assert,
    assert_eq
}
use "std/db/sqlite" as db

module("SQLite Database")

describe("Connection", fun ()
  it("connects to in-memory database", fun ()
    let conn = db.connect(":memory:")
    assert_not_nil(conn, "Connection should not be nil")
    conn.close()
  end)

  it("creates and queries table", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
    cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])

    cursor.execute("SELECT * FROM users")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")
    assert_eq(rows[0].get("age"), 30, "Age should be 30")

    conn.close()
  end)
end)

describe("Cursor Operations", fun ()
  it("returns correct row_count after INSERT", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

    assert_eq(cursor.row_count(), 1, "Should have inserted 1 row")

    conn.close()
  end)

  it("fetch_one returns single row", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])

    cursor.execute("SELECT * FROM users")
    let row1 = cursor.fetch_one()
    assert_eq(row1.get("name"), "Alice", "First row should be Alice")

    let row2 = cursor.fetch_one()
    assert_eq(row2.get("name"), "Bob", "Second row should be Bob")

    let row3 = cursor.fetch_one()
    assert_nil(row3, "Third fetch should return nil")

    conn.close()
  end)

  it("fetch_many returns limited rows", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Alice"])
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Bob"])
    cursor.execute("INSERT INTO users (name) VALUES (?)", ["Charlie"])

    cursor.execute("SELECT * FROM users")
    let rows = cursor.fetch_many(2)

    assert_eq(rows.len(), 2, "Should fetch 2 rows")
    assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
    assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")

    conn.close()
  end)

  it("description returns column metadata", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)")
    cursor.execute("SELECT * FROM users")

    let desc = cursor.description()
    assert_not_nil(desc, "Description should not be nil")
    assert_eq(desc.len(), 2, "Should have 2 columns")
    assert_eq(desc[0].get("name"), "id", "First column is id")
    assert_eq(desc[1].get("name"), "name", "Second column is name")

    conn.close()
  end)
end)

describe("Parameter Binding", fun ()
  it("supports positional parameters", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
    cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])

    cursor.execute("SELECT * FROM users WHERE name = ?", ["Alice"])
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 row")
    assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")

    conn.close()
  end)

  it("supports named parameters", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)")
    cursor.execute("INSERT INTO users (name, age) VALUES (:name, :age)", {"name": "Bob", "age": 25})

    cursor.execute("SELECT * FROM users WHERE name = :name", {"name": "Bob"})
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 row")
    assert_eq(rows[0].get("name"), "Bob", "Name should be Bob")
    assert_eq(rows[0].get("age"), 25, "Age should be 25")

    conn.close()
  end)

  it("handles various data types", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    cursor.execute("CREATE TABLE data (id INTEGER PRIMARY KEY, text_col TEXT, num_col REAL, blob_col BLOB)")
    cursor.execute("INSERT INTO data (text_col, num_col, blob_col) VALUES (?, ?, ?)", ["hello", 3.14, b"\xFF\x00"])

    cursor.execute("SELECT * FROM data")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("text_col"), "hello", "Text should match")
    assert_near(rows[0].get("num_col"), 3.14, 0.001, "Number should match")

    conn.close()
  end)
end)

describe("Error Handling", fun ()
  it("raises error on invalid SQL", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    assert_raises(Err, fun()
      cursor.execute("INVALID SQL SYNTAX")
    end)

    conn.close()
  end)

  it("raises error on missing table", fun ()
    let conn = db.connect(":memory:")
    let cursor = conn.cursor()

    assert_raises(Err, fun()
      cursor.execute("SELECT * FROM nonexistent_table")
    end)

    conn.close()
  end)
end)

describe("Module Functions", fun ()
  it("returns SQLite version", fun ()
    let version = db.version()
    assert_not_nil(version, "Version should not be nil")
    assert(version.len() > 0, "Version should not be empty")
  end)
end)
