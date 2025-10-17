use "std/test" {
    module,
    it,
    describe,
    assert_nil,
    assert_not_nil,
    assert_raises,
    assert_type,
    assert_near,
    assert,
    assert_eq
}
use "std/db/postgres" as db
use "std/uuid" as _uuid
use "std/time"

# Connection string - adjust if needed
let CONN_STR = "host=localhost port=6432 user=quest password=quest_password dbname=quest_test"

module("PostgreSQL Database")

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

    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT, age INTEGER)")
    cursor.execute("INSERT INTO test_users (name, age) VALUES ($1, $2)", ["Alice", 30])

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
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Bob"])

    assert_eq(cursor.row_count(), 1, "Should have inserted 1 row")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("fetch_one returns single row", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Alice"])
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Bob"])

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
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Alice"])
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Bob"])
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Charlie"])

    cursor.execute("SELECT * FROM test_users ORDER BY id")
    let rows = cursor.fetch_many(2)

    assert_eq(rows.len(), 2, "Should fetch 2 rows")
    assert_eq(rows[0].get("name"), "Alice", "First should be Alice")
    assert_eq(rows[1].get("name"), "Bob", "Second should be Bob")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("description returns column metadata", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("SELECT * FROM test_users")

    let desc = cursor.description()
    assert_not_nil(desc, "Description should not be nil")
    assert_eq(desc.len(), 2, "Should have 2 columns")
    assert_eq(desc[0].get("name"), "id", "First column is id")
    assert_eq(desc[1].get("name"), "name", "Second column is name")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)
end)

describe("Parameter Binding", fun ()
  it("supports positional parameters", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT, age INTEGER)")
    cursor.execute("INSERT INTO test_users (name, age) VALUES ($1, $2)", ["Alice", 30])

    cursor.execute("SELECT * FROM test_users WHERE name = $1", ["Alice"])
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 row")
    assert_eq(rows[0].get("name"), "Alice", "Name should be Alice")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("handles various data types", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_data")
    cursor.execute("CREATE TABLE test_data (id SERIAL PRIMARY KEY, text_col TEXT, num_col REAL, bool_col BOOLEAN)")
    cursor.execute("INSERT INTO test_data (text_col, num_col, bool_col) VALUES ($1, $2, $3)", ["hello", 3.14, true])

    cursor.execute("SELECT * FROM test_data")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("text_col"), "hello", "Text should match")
    assert_near(rows[0].get("num_col"), 3.14, 0.001, "Number should match")
    assert_eq(rows[0].get("bool_col"), true, "Bool should match")

    cursor.execute("DROP TABLE test_data")
    conn.close()
  end)
end)

describe("Data Types", fun ()
  it("handles INTEGER and BIGINT types", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_integers")
    cursor.execute("CREATE TABLE test_integers (id SERIAL PRIMARY KEY, int_col INTEGER, big_col BIGINT)")
    cursor.execute("INSERT INTO test_integers (int_col, big_col) VALUES ($1, $2)", [50000, 9000000000])

    cursor.execute("SELECT * FROM test_integers")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("int_col"), 50000, "INTEGER should match")
    assert_eq(rows[0].get("big_col"), 9000000000, "BIGINT should match")

    cursor.execute("DROP TABLE test_integers")
    conn.close()
  end)

  it("handles REAL (float) type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_floats")
    cursor.execute("CREATE TABLE test_floats (id SERIAL PRIMARY KEY, real_col REAL)")
    cursor.execute("INSERT INTO test_floats (real_col) VALUES ($1)", [3.14159])

    cursor.execute("SELECT * FROM test_floats")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_near(rows[0].get("real_col"), 3.14159, 0.001, "REAL should match")

    cursor.execute("DROP TABLE test_floats")
    conn.close()
  end)

  it("handles TEXT and VARCHAR", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_strings")
    cursor.execute("CREATE TABLE test_strings (id SERIAL PRIMARY KEY, text_col TEXT, varchar_col VARCHAR(50))")
    cursor.execute("INSERT INTO test_strings (text_col, varchar_col) VALUES ($1, $2)", ["Hello, World!", "Short string"])

    cursor.execute("SELECT * FROM test_strings")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("text_col"), "Hello, World!", "TEXT should match")
    assert_eq(rows[0].get("varchar_col"), "Short string", "VARCHAR should match")

    cursor.execute("DROP TABLE test_strings")
    conn.close()
  end)

  it("handles BOOLEAN", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_booleans")
    cursor.execute("CREATE TABLE test_booleans (id SERIAL PRIMARY KEY, bool_true BOOLEAN, bool_false BOOLEAN)")
    cursor.execute("INSERT INTO test_booleans (bool_true, bool_false) VALUES ($1, $2)", [true, false])

    cursor.execute("SELECT * FROM test_booleans")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("bool_true"), true, "TRUE should match")
    assert_eq(rows[0].get("bool_false"), false, "FALSE should match")

    cursor.execute("DROP TABLE test_booleans")
    conn.close()
  end)

  it("handles BYTEA (binary data)", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_binary")
    cursor.execute("CREATE TABLE test_binary (id SERIAL PRIMARY KEY, data BYTEA)")

    let binary_data = b"\xFF\xFE\xFD\x00\x01\x02"
    cursor.execute("INSERT INTO test_binary (data) VALUES ($1)", [binary_data])

    cursor.execute("SELECT * FROM test_binary")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Bytes", "Should be Bytes type")
    assert_eq(retrieved.len(), 6, "Should have 6 bytes")
    assert_eq(retrieved.get(0), 255, "First byte should be 0xFF")
    assert_eq(retrieved.get(1), 254, "Second byte should be 0xFE")

    cursor.execute("DROP TABLE test_binary")
    conn.close()
  end)

  it("handles NULL values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_nulls")
    cursor.execute("CREATE TABLE test_nulls (id SERIAL PRIMARY KEY, text_col TEXT, num_col INTEGER, bool_col BOOLEAN)")
    # Insert with mixed NULL and non-NULL values to test NULL handling
    cursor.execute("INSERT INTO test_nulls (text_col, num_col, bool_col) VALUES ($1, NULL, NULL)", ["test"])
    cursor.execute("INSERT INTO test_nulls (text_col, num_col, bool_col) VALUES (NULL, $1, NULL)", [42])
    cursor.execute("INSERT INTO test_nulls (text_col, num_col, bool_col) VALUES (NULL, NULL, $1)", [true])

    cursor.execute("SELECT * FROM test_nulls ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should have 3 rows")
    # First row: text is set, others are NULL
    assert_eq(rows[0].get("text_col"), "test", "TEXT should be 'test'")
    assert_nil(rows[0].get("num_col"), "INTEGER NULL should be nil")
    assert_nil(rows[0].get("bool_col"), "BOOLEAN NULL should be nil")
    # Second row: Num is set, others are NULL
    assert_nil(rows[1].get("text_col"), "TEXT NULL should be nil")
    assert_eq(rows[1].get("num_col"), 42, "INTEGER should be 42")
    assert_nil(rows[1].get("bool_col"), "BOOLEAN NULL should be nil")
    # Third row: Bool is set, others are NULL
    assert_nil(rows[2].get("text_col"), "TEXT NULL should be nil")
    assert_nil(rows[2].get("num_col"), "INTEGER NULL should be nil")
    assert_eq(rows[2].get("bool_col"), true, "BOOLEAN should be true")

    cursor.execute("DROP TABLE test_nulls")
    conn.close()
  end)

  it("handles CHAR and BPCHAR (blank-padded char)", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_chars")
    cursor.execute("CREATE TABLE test_chars (id SERIAL PRIMARY KEY, char_col CHAR(5), bpchar_col CHAR(10))")
    cursor.execute("INSERT INTO test_chars (char_col, bpchar_col) VALUES ($1, $2)", ["ABC", "TEST"])

    cursor.execute("SELECT * FROM test_chars")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    # PostgreSQL pads CHAR with spaces, but trims them on retrieval
    assert_eq(rows[0].get("char_col"), "ABC  ", "CHAR(5) should be padded")
    assert_eq(rows[0].get("bpchar_col"), "TEST      ", "CHAR(10) should be padded")

    cursor.execute("DROP TABLE test_chars")
    conn.close()
  end)

  it("handles mixed types in single query", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_mixed")
    cursor.execute("CREATE TABLE test_mixed (id SERIAL PRIMARY KEY, int_val INTEGER, float_val REAL, text_val TEXT, bool_val BOOLEAN, bytes_val BYTEA)")

    let test_bytes = b"\x01\x02\x03"
    cursor.execute("INSERT INTO test_mixed (int_val, float_val, text_val, bool_val, bytes_val) VALUES ($1, $2, $3, $4, $5)",
      [42, 3.14159, "Quest", true, test_bytes])

    cursor.execute("SELECT * FROM test_mixed")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("int_val"), 42, "Integer should match")
    assert_near(rows[0].get("float_val"), 3.14159, 0.00001, "Float should match")
    assert_eq(rows[0].get("text_val"), "Quest", "Text should match")
    assert_eq(rows[0].get("bool_val"), true, "Boolean should match")
    assert_eq(rows[0].get("bytes_val").len(), 3, "Bytes length should match")

    cursor.execute("DROP TABLE test_mixed")
    conn.close()
  end)

  it("handles edge cases for numeric types", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_edge_cases")
    cursor.execute("CREATE TABLE test_edge_cases (id SERIAL PRIMARY KEY, zero_val INTEGER, negative_val INTEGER, large_val BIGINT)")
    cursor.execute("INSERT INTO test_edge_cases (zero_val, negative_val, large_val) VALUES ($1, $2, $3)", [0, -12345, 9223372036854775807])

    cursor.execute("SELECT * FROM test_edge_cases")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("zero_val"), 0, "Zero should match")
    assert_eq(rows[0].get("negative_val"), -12345, "Negative should match")
    assert_eq(rows[0].get("large_val"), 9223372036854775807, "Max BIGINT should match")

    cursor.execute("DROP TABLE test_edge_cases")
    conn.close()
  end)

  it("handles empty strings", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_empty_strings")
    cursor.execute("CREATE TABLE test_empty_strings (id SERIAL PRIMARY KEY, empty_text TEXT, empty_varchar VARCHAR(50))")
    cursor.execute("INSERT INTO test_empty_strings (empty_text, empty_varchar) VALUES ($1, $2)", ["", ""])

    cursor.execute("SELECT * FROM test_empty_strings")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_eq(rows[0].get("empty_text"), "", "Empty TEXT should match")
    assert_eq(rows[0].get("empty_varchar"), "", "Empty VARCHAR should match")

    cursor.execute("DROP TABLE test_empty_strings")
    conn.close()
  end)
end)

describe("UUID Type", fun ()
  it("handles UUID columns", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_uuids")
    cursor.execute("CREATE TABLE test_uuids (id SERIAL PRIMARY KEY, uuid_col UUID)")

    let test_uuid = _uuid.v4()
    cursor.execute("INSERT INTO test_uuids (uuid_col) VALUES ($1)", [test_uuid])

    cursor.execute("SELECT * FROM test_uuids")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_type(rows[0].get("uuid_col"), "Uuid", "Should be Uuid type")
    assert_eq(rows[0].get("uuid_col").to_string(), test_uuid.to_string(), "UUID should match")

    cursor.execute("DROP TABLE test_uuids")
    conn.close()
  end)

  it("handles UUID primary keys", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_uuid_pk")
    cursor.execute("CREATE TABLE test_uuid_pk (id UUID PRIMARY KEY, name TEXT)")

    let id1 = _uuid.v4()
    let id2 = _uuid.v4()
    cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES ($1, $2)", [id1, "Alice"])
    cursor.execute("INSERT INTO test_uuid_pk (id, name) VALUES ($1, $2)", [id2, "Bob"])

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
    cursor.execute("CREATE TABLE test_null_uuids (id SERIAL PRIMARY KEY, uuid_col UUID)")
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
    cursor.execute("CREATE TABLE test_uuid_query (id UUID PRIMARY KEY, value TEXT)")

    let target_id = _uuid.v4()
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES ($1, $2)", [_uuid.v4(), "First"])
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES ($1, $2)", [target_id, "Target"])
    cursor.execute("INSERT INTO test_uuid_query (id, value) VALUES ($1, $2)", [_uuid.v4(), "Third"])

    cursor.execute("SELECT * FROM test_uuid_query WHERE id = $1", [target_id])
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 row")
    assert_eq(rows[0].get("value"), "Target", "Should find correct row")
    assert_eq(rows[0].get("id").to_string(), target_id.to_string(), "ID should match")

    cursor.execute("DROP TABLE test_uuid_query")
    conn.close()
  end)

  it("handles all UUID versions", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_all_uuid_versions")
    cursor.execute("CREATE TABLE test_all_uuid_versions (version INT, uuid_val UUID, description TEXT)")

    # Insert all UUID versions
    let v1_id = _uuid.v1()
    let v3_id = _uuid.v3(_uuid.NAMESPACE_DNS, "example.com")
    let v4_id = _uuid.v4()
    let v5_id = _uuid.v5(_uuid.NAMESPACE_URL, "https://example.com")
    let v6_id = _uuid.v6()
    let v7_id = _uuid.v7()
    let v8_id = _uuid.v8(b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10")

    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [1, v1_id, "v1 timestamp"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [3, v3_id, "v3 MD5"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [4, v4_id, "v4 random"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [5, v5_id, "v5 SHA1"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [6, v6_id, "v6 timestamp"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [7, v7_id, "v7 unix time"])
    cursor.execute("INSERT INTO test_all_uuid_versions VALUES ($1, $2, $3)", [8, v8_id, "v8 custom"])

    # Retrieve and verify
    cursor.execute("SELECT * FROM test_all_uuid_versions ORDER BY version")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 7, "Should have 7 UUID versions")

    # Verify each version
    assert_eq(rows[0].get("uuid_val").to_string(), v1_id.to_string(), "v1 should roundtrip")
    assert_eq(rows[1].get("uuid_val").to_string(), v3_id.to_string(), "v3 should roundtrip")
    assert_eq(rows[2].get("uuid_val").to_string(), v4_id.to_string(), "v4 should roundtrip")
    assert_eq(rows[3].get("uuid_val").to_string(), v5_id.to_string(), "v5 should roundtrip")
    assert_eq(rows[4].get("uuid_val").to_string(), v6_id.to_string(), "v6 should roundtrip")
    assert_eq(rows[5].get("uuid_val").to_string(), v7_id.to_string(), "v7 should roundtrip")
    assert_eq(rows[6].get("uuid_val").to_string(), v8_id.to_string(), "v8 should roundtrip")

    cursor.execute("DROP TABLE test_all_uuid_versions")
    conn.close()
  end)

  it("UUID v7 ordering in database", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_v7_ordering")
    cursor.execute("CREATE TABLE test_v7_ordering (id UUID PRIMARY KEY, seq INT)")

    # Insert v7 UUIDs (which are time-ordered)
    let id1 = _uuid.v7()
    let id2 = _uuid.v7()
    let id3 = _uuid.v7()

    # Insert in reverse order
    cursor.execute("INSERT INTO test_v7_ordering VALUES ($1, $2)", [id3, 3])
    cursor.execute("INSERT INTO test_v7_ordering VALUES ($1, $2)", [id1, 1])
    cursor.execute("INSERT INTO test_v7_ordering VALUES ($1, $2)", [id2, 2])

    # Order by UUID should match time order
    cursor.execute("SELECT * FROM test_v7_ordering ORDER BY id")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should have 3 rows")
    assert_eq(rows[0].get("seq"), 1, "First should be seq 1")
    assert_eq(rows[1].get("seq"), 2, "Second should be seq 2")
    assert_eq(rows[2].get("seq"), 3, "Third should be seq 3")

    cursor.execute("DROP TABLE test_v7_ordering")
    conn.close()
  end)

  it("deterministic UUIDs (v5) in database", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_deterministic")
    cursor.execute("CREATE TABLE test_deterministic (email TEXT PRIMARY KEY, user_id UUID NOT NULL)")

    # Generate deterministic UUIDs from emails
    let alice_email = "alice@example.com"
    let bob_email = "bob@example.com"

    let alice_id = _uuid.v5(_uuid.NAMESPACE_DNS, alice_email)
    let bob_id = _uuid.v5(_uuid.NAMESPACE_DNS, bob_email)

    cursor.execute("INSERT INTO test_deterministic VALUES ($1, $2)", [alice_email, alice_id])
    cursor.execute("INSERT INTO test_deterministic VALUES ($1, $2)", [bob_email, bob_id])

    # Retrieve and verify determinism
    cursor.execute("SELECT * FROM test_deterministic WHERE email = $1", [alice_email])
    let rows = cursor.fetch_all()

    let retrieved_id = rows[0].get("user_id")
    let regenerated_id = _uuid.v5(_uuid.NAMESPACE_DNS, alice_email)

    assert_eq(retrieved_id.to_string(), regenerated_id.to_string(), "v5 should be deterministic")
    assert_eq(retrieved_id.to_string(), alice_id.to_string(), "Should match original ID")

    cursor.execute("DROP TABLE test_deterministic")
    conn.close()
  end)
end)

describe("Date/Time Types", fun ()
  it("handles TIMESTAMP type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_timestamps")
    cursor.execute("CREATE TABLE test_timestamps (id SERIAL PRIMARY KEY, ts TIMESTAMP)")

    let now_ts = time.now()
    cursor.execute("INSERT INTO test_timestamps (ts) VALUES ($1)", [now_ts])

    cursor.execute("SELECT * FROM test_timestamps")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("ts")
    assert_type(retrieved, "Timestamp", "Should be Timestamp type")

    cursor.execute("DROP TABLE test_timestamps")
    conn.close()
  end)

  it("handles DATE type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_dates")
    cursor.execute("CREATE TABLE test_dates (id SERIAL PRIMARY KEY, date_col DATE)")

    let today = time.date(2025, 1, 15)
    cursor.execute("INSERT INTO test_dates (date_col) VALUES ($1)", [today])

    cursor.execute("SELECT * FROM test_dates")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("date_col")
    assert_type(retrieved, "Date", "Should be Date type")
    assert_eq(retrieved.year(), 2025, "Year should match")
    assert_eq(retrieved.month(), 1, "Month should match")
    assert_eq(retrieved.day(), 15, "Day should match")

    cursor.execute("DROP TABLE test_dates")
    conn.close()
  end)

  it("handles TIME type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_times")
    cursor.execute("CREATE TABLE test_times (id SERIAL PRIMARY KEY, time_col TIME)")

    let test_time = time.time(14, 30, 45)
    cursor.execute("INSERT INTO test_times (time_col) VALUES ($1)", [test_time])

    cursor.execute("SELECT * FROM test_times")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("time_col")
    assert_type(retrieved, "Time", "Should be Time type")
    assert_eq(retrieved.hour(), 14, "Hour should match")
    assert_eq(retrieved.minute(), 30, "Minute should match")
    assert_eq(retrieved.second(), 45, "Second should match")

    cursor.execute("DROP TABLE test_times")
    conn.close()
  end)

  it("handles TIMESTAMPTZ type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_timestamptz")
    cursor.execute("CREATE TABLE test_timestamptz (id SERIAL PRIMARY KEY, ts TIMESTAMPTZ)")

    let zoned_dt = time.datetime(2025, 1, 15, 14, 30, 45, "America/New_York")
    cursor.execute("INSERT INTO test_timestamptz (ts) VALUES ($1)", [zoned_dt])

    cursor.execute("SELECT * FROM test_timestamptz")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("ts")
    assert_type(retrieved, "Zoned", "Should be Zoned type")

    cursor.execute("DROP TABLE test_timestamptz")
    conn.close()
  end)

  it("handles NULL date/time values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_datetime")
    cursor.execute("CREATE TABLE test_null_datetime (id SERIAL PRIMARY KEY, date_col DATE, time_col TIME, ts_col TIMESTAMP)")
    cursor.execute("INSERT INTO test_null_datetime (date_col, time_col, ts_col) VALUES (NULL, NULL, NULL)")

    cursor.execute("SELECT * FROM test_null_datetime")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("date_col"), "DATE NULL should be nil")
    assert_nil(rows[0].get("time_col"), "TIME NULL should be nil")
    assert_nil(rows[0].get("ts_col"), "TIMESTAMP NULL should be nil")

    cursor.execute("DROP TABLE test_null_datetime")
    conn.close()
  end)

  it("handles date/time queries with WHERE clauses", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_events")
    cursor.execute("CREATE TABLE test_events (id SERIAL PRIMARY KEY, event_date DATE, event_name TEXT)")

    let date1 = time.date(2025, 1, 10)
    let date2 = time.date(2025, 1, 15)
    let date3 = time.date(2025, 1, 20)

    cursor.execute("INSERT INTO test_events (event_date, event_name) VALUES ($1, $2)", [date1, "Event 1"])
    cursor.execute("INSERT INTO test_events (event_date, event_name) VALUES ($1, $2)", [date2, "Event 2"])
    cursor.execute("INSERT INTO test_events (event_date, event_name) VALUES ($1, $2)", [date3, "Event 3"])

    cursor.execute("SELECT * FROM test_events WHERE event_date = $1", [date2])
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should find 1 event")
    assert_eq(rows[0].get("event_name"), "Event 2", "Should find Event 2")

    cursor.execute("DROP TABLE test_events")
    conn.close()
  end)

  it("handles mixed date/time types in single table", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_mixed_datetime")
    cursor.execute("CREATE TABLE test_mixed_datetime (id SERIAL PRIMARY KEY, date_col DATE, time_col TIME, ts_col TIMESTAMP)")

    let test_date = time.date(2025, 1, 15)
    let test_time = time.time(14, 30, 45)
    let test_ts = time.now()

    cursor.execute("INSERT INTO test_mixed_datetime (date_col, time_col, ts_col) VALUES ($1, $2, $3)",
      [test_date, test_time, test_ts])

    cursor.execute("SELECT * FROM test_mixed_datetime")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_type(rows[0].get("date_col"), "Date", "date_col should be Date")
    assert_type(rows[0].get("time_col"), "Time", "time_col should be Time")
    assert_type(rows[0].get("ts_col"), "Timestamp", "ts_col should be Timestamp")

    cursor.execute("DROP TABLE test_mixed_datetime")
    conn.close()
  end)
end)

describe("INTERVAL Type", fun ()
  it("handles INTERVAL type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_intervals")
    cursor.execute("CREATE TABLE test_intervals (id SERIAL PRIMARY KEY, duration INTERVAL)")

    let span1 = time.hours(5)
    cursor.execute("INSERT INTO test_intervals (duration) VALUES ($1)", [span1])

    cursor.execute("SELECT * FROM test_intervals")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("duration")
    assert_type(retrieved, "Span", "Should be Span type")
    assert_eq(retrieved.hours(), 5, "Should have 5 hours")

    cursor.execute("DROP TABLE test_intervals")
    conn.close()
  end)

  it("handles complex INTERVAL values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_complex_intervals")
    cursor.execute("CREATE TABLE test_complex_intervals (id SERIAL PRIMARY KEY, duration INTERVAL)")

    let span1 = time.days(5).add(time.hours(3)).add(time.minutes(30))
    cursor.execute("INSERT INTO test_complex_intervals (duration) VALUES ($1)", [span1])

    cursor.execute("SELECT * FROM test_complex_intervals")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("duration")
    assert_type(retrieved, "Span", "Should be Span type")
    assert_eq(retrieved.days(), 5, "Should have 5 days")
    assert_eq(retrieved.hours(), 3, "Should have 3 hours")
    assert_eq(retrieved.minutes(), 30, "Should have 30 minutes")

    cursor.execute("DROP TABLE test_complex_intervals")
    conn.close()
  end)

  it("handles NULL INTERVAL values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_intervals")
    cursor.execute("CREATE TABLE test_null_intervals (id SERIAL PRIMARY KEY, duration INTERVAL)")
    cursor.execute("INSERT INTO test_null_intervals (duration) VALUES (NULL)")

    cursor.execute("SELECT * FROM test_null_intervals")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("duration"), "Should be nil")

    cursor.execute("DROP TABLE test_null_intervals")
    conn.close()
  end)

  it("handles INTERVAL with seconds", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_second_intervals")
    cursor.execute("CREATE TABLE test_second_intervals (id SERIAL PRIMARY KEY, duration INTERVAL)")

    let span1 = time.seconds(90)
    cursor.execute("INSERT INTO test_second_intervals (duration) VALUES ($1)", [span1])

    cursor.execute("SELECT * FROM test_second_intervals")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("duration")
    assert_type(retrieved, "Span", "Should be Span type")
    assert_eq(retrieved.minutes(), 1, "Should have 1 minute")
    assert_eq(retrieved.seconds(), 30, "Should have 30 seconds")
    assert_eq(retrieved.as_seconds(), 90, "Total should be 90 seconds")

    cursor.execute("DROP TABLE test_second_intervals")
    conn.close()
  end)
end)

describe("JSON/JSONB Types", fun ()
  it("handles JSON type with dict", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_json")
    cursor.execute("CREATE TABLE test_json (id SERIAL PRIMARY KEY, data JSON)")

    let test_dict = {"name": "Alice", "age": 30, "active": true}
    cursor.execute("INSERT INTO test_json (data) VALUES ($1)", [test_dict])

    cursor.execute("SELECT * FROM test_json")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Dict", "Should be Dict type")
    assert_eq(retrieved.get("name"), "Alice", "Name should match")
    assert_eq(retrieved.get("age"), 30, "Age should match")
    assert_eq(retrieved.get("active"), true, "Active should match")

    cursor.execute("DROP TABLE test_json")
    conn.close()
  end)

  it("handles JSONB type with dict", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_jsonb")
    cursor.execute("CREATE TABLE test_jsonb (id SERIAL PRIMARY KEY, data JSONB)")

    let test_dict = {"city": "San Francisco", "population": 874961, "coordinates": {"lat": 37.7749, "lng": -122.4194}}
    cursor.execute("INSERT INTO test_jsonb (data) VALUES ($1)", [test_dict])

    cursor.execute("SELECT * FROM test_jsonb")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Dict", "Should be Dict type")
    assert_eq(retrieved.get("city"), "San Francisco", "City should match")
    assert_eq(retrieved.get("population"), 874961, "Population should match")
    let coords = retrieved.get("coordinates")
    assert_type(coords, "Dict", "Coordinates should be Dict")
    assert_eq(coords.get("lat"), 37.7749, "Latitude should match")

    cursor.execute("DROP TABLE test_jsonb")
    conn.close()
  end)

  it("handles JSON with array", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_json_array")
    cursor.execute("CREATE TABLE test_json_array (id SERIAL PRIMARY KEY, data JSON)")

    let test_array = [1, 2, 3, 4, 5]
    cursor.execute("INSERT INTO test_json_array (data) VALUES ($1)", [test_array])

    cursor.execute("SELECT * FROM test_json_array")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Array", "Should be Array type")
    assert_eq(retrieved.len(), 5, "Should have 5 elements")
    assert_eq(retrieved[0], 1, "First element should be 1")
    assert_eq(retrieved[4], 5, "Last element should be 5")

    cursor.execute("DROP TABLE test_json_array")
    conn.close()
  end)

  it("handles NULL JSON values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_json")
    cursor.execute("CREATE TABLE test_null_json (id SERIAL PRIMARY KEY, data JSON, extra JSONB)")
    cursor.execute("INSERT INTO test_null_json (data, extra) VALUES (NULL, NULL)")

    cursor.execute("SELECT * FROM test_null_json")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("data"), "data should be nil")
    assert_nil(rows[0].get("extra"), "extra should be nil")

    cursor.execute("DROP TABLE test_null_json")
    conn.close()
  end)

  it("handles nested JSON structures", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_nested_json")
    cursor.execute("CREATE TABLE test_nested_json (id SERIAL PRIMARY KEY, data JSONB)")

    let test_data = {
      "user": {"name": "Bob", "email": "bob@example.com"},
      "tags": ["developer", "rust", "postgres"],
      "metadata": {"created": "2025-01-01", "version": 2}
    }
    cursor.execute("INSERT INTO test_nested_json (data) VALUES ($1)", [test_data])

    cursor.execute("SELECT * FROM test_nested_json")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Dict", "Should be Dict type")

    let user = retrieved.get("user")
    assert_eq(user.get("name"), "Bob", "User name should match")

    let tags = retrieved.get("tags")
    assert_eq(tags.len(), 3, "Should have 3 tags")
    assert_eq(tags[0], "developer", "First tag should match")

    cursor.execute("DROP TABLE test_nested_json")
    conn.close()
  end)
end)

describe("ARRAY Types", fun ()
  it("handles INTEGER[] arrays with SQL ARRAY constructor", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_int_arrays")
    cursor.execute("CREATE TABLE test_int_arrays (id SERIAL PRIMARY KEY, data INTEGER[])")

    cursor.execute("INSERT INTO test_int_arrays (data) VALUES (ARRAY[1, 2, 3, 4, 5])")

    cursor.execute("SELECT * FROM test_int_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Array", "Should be Array type")
    assert_eq(retrieved.len(), 5, "Should have 5 elements")
    assert_eq(retrieved[0], 1, "First element should be 1")
    assert_eq(retrieved[4], 5, "Last element should be 5")

    cursor.execute("DROP TABLE test_int_arrays")
    conn.close()
  end)

  it("handles TEXT[] arrays", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_text_arrays")
    cursor.execute("CREATE TABLE test_text_arrays (id SERIAL PRIMARY KEY, tags TEXT[])")

    cursor.execute("INSERT INTO test_text_arrays (tags) VALUES (ARRAY['rust', 'postgres', 'database', 'arrays'])")

    cursor.execute("SELECT * FROM test_text_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("tags")
    assert_type(retrieved, "Array", "Should be Array type")
    assert_eq(retrieved.len(), 4, "Should have 4 elements")
    assert_eq(retrieved[0], "rust", "First element should be 'rust'")
    assert_eq(retrieved[3], "arrays", "Last element should be 'arrays'")

    cursor.execute("DROP TABLE test_text_arrays")
    conn.close()
  end)

  it("handles BOOLEAN[] arrays", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_bool_arrays")
    cursor.execute("CREATE TABLE test_bool_arrays (id SERIAL PRIMARY KEY, flags BOOLEAN[])")

    cursor.execute("INSERT INTO test_bool_arrays (flags) VALUES (ARRAY[true, false, true, true, false])")

    cursor.execute("SELECT * FROM test_bool_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("flags")
    assert_type(retrieved, "Array", "Should be Array type")
    assert_eq(retrieved.len(), 5, "Should have 5 elements")
    assert_eq(retrieved[0], true, "First element should be true")
    assert_eq(retrieved[1], false, "Second element should be false")

    cursor.execute("DROP TABLE test_bool_arrays")
    conn.close()
  end)

  it("reads PostgreSQL arrays back as Quest arrays", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_array_read")
    cursor.execute("CREATE TABLE test_array_read (id SERIAL PRIMARY KEY, nums INTEGER[], texts TEXT[])")

    cursor.execute("INSERT INTO test_array_read (nums, texts) VALUES (ARRAY[10, 20, 30], ARRAY['a', 'b', 'c'])")

    cursor.execute("SELECT * FROM test_array_read")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let nums = rows[0].get("nums")
    let texts = rows[0].get("texts")

    assert_type(nums, "Array", "nums should be Array")
    assert_eq(nums.len(), 3, "nums should have 3 elements")
    assert_eq(nums[1], 20, "Second number should be 20")

    assert_type(texts, "Array", "texts should be Array")
    assert_eq(texts.len(), 3, "texts should have 3 elements")
    assert_eq(texts[1], "b", "Second text should be 'b'")

    cursor.execute("DROP TABLE test_array_read")
    conn.close()
  end)

  it("handles NULL array values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_arrays")
    cursor.execute("CREATE TABLE test_null_arrays (id SERIAL PRIMARY KEY, data INTEGER[])")
    cursor.execute("INSERT INTO test_null_arrays (data) VALUES (NULL)")

    cursor.execute("SELECT * FROM test_null_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("data"), "data should be nil")

    cursor.execute("DROP TABLE test_null_arrays")
    conn.close()
  end)

  it("handles empty arrays", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_empty_arrays")
    cursor.execute("CREATE TABLE test_empty_arrays (id SERIAL PRIMARY KEY, data TEXT[])")

    cursor.execute("INSERT INTO test_empty_arrays (data) VALUES (ARRAY[]::TEXT[])")

    cursor.execute("SELECT * FROM test_empty_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let retrieved = rows[0].get("data")
    assert_type(retrieved, "Array", "Should be Array type")
    assert_eq(retrieved.len(), 0, "Should be empty array")

    cursor.execute("DROP TABLE test_empty_arrays")
    conn.close()
  end)
end)

describe("Error Handling", fun ()
  it("raises error on invalid SQL", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    assert_raises(Err, fun()
      cursor.execute("INVALID SQL SYNTAX")
    end)

    conn.close()
  end)

  it("raises error on missing table", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    assert_raises(Err, fun()
      cursor.execute("SELECT * FROM nonexistent_table_xyz")
    end)

    conn.close()
  end)
end)

describe("NUMERIC/DECIMAL Type", fun ()
  it("handles NUMERIC type", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_numeric")
    cursor.execute("CREATE TABLE test_numeric (id SERIAL PRIMARY KEY, price NUMERIC(10, 2))")
    cursor.execute("INSERT INTO test_numeric (price) VALUES (CAST('123.45' AS NUMERIC))")

    cursor.execute("SELECT * FROM test_numeric")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let price = rows[0].get("price")
    assert_type(price, "Decimal", "Should be Decimal type")
    assert_eq(price.to_string(), "123.45", "Price should match")

    cursor.execute("DROP TABLE test_numeric")
    conn.close()
  end)

  it("handles high precision NUMERIC", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_high_precision")
    cursor.execute("CREATE TABLE test_high_precision (id SERIAL PRIMARY KEY, value NUMERIC(30, 10))")
    # Test with high precision value - NUMERIC(30,10) means up to 30 digits total, 10 after decimal
    cursor.execute("INSERT INTO test_high_precision (value) VALUES (CAST('1234567890.1234567890' AS NUMERIC(30, 10)))")

    cursor.execute("SELECT * FROM test_high_precision")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let value = rows[0].get("value")
    assert_type(value, "Decimal", "Should be Decimal type")
    # PostgreSQL preserves the scale, so we get exactly 10 decimal places
    assert_eq(value.to_string(), "1234567890.1234567890", "High precision value should match")

    cursor.execute("DROP TABLE test_high_precision")
    conn.close()
  end)

  it("handles NUMERIC arithmetic", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_numeric_math")
    cursor.execute("CREATE TABLE test_numeric_math (id SERIAL PRIMARY KEY, a NUMERIC(10, 2), b NUMERIC(10, 2))")
    cursor.execute("INSERT INTO test_numeric_math (a, b) VALUES (CAST('10.50' AS NUMERIC), CAST('5.25' AS NUMERIC))")

    cursor.execute("SELECT * FROM test_numeric_math")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let a = rows[0].get("a")
    let b = rows[0].get("b")

    # Test decimal arithmetic methods
    let sum = a.plus(b)
    assert_eq(sum.to_string(), "15.75", "Addition should work")

    let diff = a.minus(b)
    assert_eq(diff.to_string(), "5.25", "Subtraction should work")

    let product = a.times(b)
    assert_eq(product.to_string(), "55.1250", "Multiplication should work")

    cursor.execute("DROP TABLE test_numeric_math")
    conn.close()
  end)

  it("handles NULL NUMERIC values", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_null_numeric")
    cursor.execute("CREATE TABLE test_null_numeric (id SERIAL PRIMARY KEY, value NUMERIC)")
    cursor.execute("INSERT INTO test_null_numeric (value) VALUES (NULL)")

    cursor.execute("SELECT * FROM test_null_numeric")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    assert_nil(rows[0].get("value"), "NULL NUMERIC should be nil")

    cursor.execute("DROP TABLE test_null_numeric")
    conn.close()
  end)

  it("handles NUMERIC comparison", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_numeric_compare")
    cursor.execute("CREATE TABLE test_numeric_compare (id SERIAL PRIMARY KEY, value NUMERIC(10, 2))")
    cursor.execute("INSERT INTO test_numeric_compare (value) VALUES (CAST('10.00' AS NUMERIC))")
    cursor.execute("INSERT INTO test_numeric_compare (value) VALUES (CAST('20.00' AS NUMERIC))")
    cursor.execute("INSERT INTO test_numeric_compare (value) VALUES (CAST('15.00' AS NUMERIC))")

    cursor.execute("SELECT * FROM test_numeric_compare ORDER BY value")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 3, "Should have 3 rows")
    assert_eq(rows[0].get("value").to_string(), "10.00", "First should be 10.00")
    assert_eq(rows[1].get("value").to_string(), "15.00", "Second should be 15.00")
    assert_eq(rows[2].get("value").to_string(), "20.00", "Third should be 20.00")

    # Test comparison methods
    let val1 = rows[0].get("value")
    let val2 = rows[1].get("value")

    assert_eq(val1.lt(val2), true, "10 < 15 should be true")
    assert_eq(val2.gt(val1), true, "15 > 10 should be true")

    cursor.execute("DROP TABLE test_numeric_compare")
    conn.close()
  end)

  it("handles NUMERIC[] arrays", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_numeric_arrays")
    cursor.execute("CREATE TABLE test_numeric_arrays (id SERIAL PRIMARY KEY, values NUMERIC[])")
    cursor.execute("INSERT INTO test_numeric_arrays (values) VALUES (ARRAY[CAST('1.5' AS NUMERIC), CAST('2.5' AS NUMERIC), CAST('3.5' AS NUMERIC)])")

    cursor.execute("SELECT * FROM test_numeric_arrays")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let values = rows[0].get("values")
    assert_type(values, "Array", "Should be Array type")
    assert_eq(values.len(), 3, "Should have 3 elements")
    assert_type(values[0], "Decimal", "Elements should be Decimal type")
    assert_eq(values[0].to_string(), "1.5", "First element should be 1.5")
    assert_eq(values[1].to_string(), "2.5", "Second element should be 2.5")
    assert_eq(values[2].to_string(), "3.5", "Third element should be 3.5")

    cursor.execute("DROP TABLE test_numeric_arrays")
    conn.close()
  end)

  it("handles DECIMAL conversion to f64", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_decimal_conversion")
    cursor.execute("CREATE TABLE test_decimal_conversion (id SERIAL PRIMARY KEY, value NUMERIC)")
    cursor.execute("INSERT INTO test_decimal_conversion (value) VALUES (CAST('42.5' AS NUMERIC))")

    cursor.execute("SELECT * FROM test_decimal_conversion")
    let rows = cursor.fetch_all()

    assert_eq(rows.len(), 1, "Should have 1 row")
    let decimal_val = rows[0].get("value")
    assert_type(decimal_val, "Decimal", "Should be Decimal type")

    let float_val = decimal_val.to_f64()
    assert_type(float_val, "Float", "Should convert to Float")
    assert_near(float_val, 42.5, 0.001, "Should be 42.5")

    cursor.execute("DROP TABLE test_decimal_conversion")
    conn.close()
  end)
end)

describe("Transactions", fun ()
  it("supports commit", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Alice"])
    conn.commit()

    cursor.execute("SELECT COUNT(*) as count FROM test_users")
    let rows = cursor.fetch_all()
    assert_eq(rows[0].get("count"), 1, "Should have 1 row after commit")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)

  it("supports rollback", fun ()
    let conn = db.connect(CONN_STR)
    let cursor = conn.cursor()

    cursor.execute("DROP TABLE IF EXISTS test_users")
    cursor.execute("CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)")
    cursor.execute("BEGIN")
    cursor.execute("INSERT INTO test_users (name) VALUES ($1)", ["Bob"])
    conn.rollback()

    cursor.execute("SELECT COUNT(*) as count FROM test_users")
    let rows = cursor.fetch_all()
    assert_eq(rows[0].get("count"), 0, "Should have 0 rows after rollback")

    cursor.execute("DROP TABLE test_users")
    conn.close()
  end)
end)
