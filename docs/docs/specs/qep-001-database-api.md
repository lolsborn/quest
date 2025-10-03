# QEP 1 - Quest Database API Specification v1.0

## Abstract

This QEP (Quest Enhancement Proposal) describes the Quest Database API Specification. The purpose of this specification is to encourage similarity between Quest database modules by defining a standard interface for database connectivity.

This specification is adapted from [PEP 249 - Python Database API Specification v2.0](https://peps.python.org/pep-0249/), authored by Marc-André Lemburg, and modified to conform to Quest's syntax and language features.

## Rationale

Quest's extensibility makes it ideal for database programming. However, different database modules have historically used different interfaces, making it difficult to write portable database code. This specification defines a standard interface to promote consistency across database implementations.

## Module Interface

Database modules conforming to this specification must provide the following:

### Global Module Functions

#### `db.connect()`

Constructor for creating a connection to the database.

**Parameters**: Database-specific (e.g., `host`, `port`, `database`, `user`, `password`)

**Returns**: `Connection` object

**Example**:
```quest
use "std/db/postgres" as db

let conn = db.connect(
    host: "localhost",
    port: 5432,
    database: "mydb",
    user: "admin",
    password: "secret"
)
```

### Module Attributes

Database modules should expose the following attributes:

#### `db.api_level`

String constant stating the supported DB API level (`"1.0"`).

#### `db.thread_safety`

Number constant indicating thread safety level:
- `0` - Threads may not share the module
- `1` - Threads may share the module, but not connections
- `2` - Threads may share the module and connections
- `3` - Threads may share the module, connections, and cursors

#### `db.param_style`

String constant stating the type of parameter marker formatting:
- `"qmark"` - Question mark style, e.g., `...WHERE name = ?`
- `"numeric"` - Numeric positional style, e.g., `...WHERE name = $1`
- `"named"` - Named style, e.g., `...WHERE name = :name`
- `"format"` - ANSI C printf format codes, e.g., `...WHERE name = %s`
- `"pyformat"` - Python extended format codes, e.g., `...WHERE name = %(name)s`

## Exception Hierarchy

All database exceptions should inherit from a common base. The exception hierarchy:

```
Exception
  |
  +-- Warning
  |
  +-- Error
       |
       +-- InterfaceError
       |
       +-- DatabaseError
            |
            +-- DataError
            |
            +-- OperationalError
            |
            +-- IntegrityError
            |
            +-- InternalError
            |
            +-- ProgrammingError
            |
            +-- NotSupportedError
```

### Exception Descriptions

- **`Warning`**: Raised for important warnings (e.g., data truncations)
- **`Error`**: Base class for all database errors
- **`InterfaceError`**: Errors related to the database interface
- **`DatabaseError`**: Errors related to the database itself
- **`DataError`**: Errors due to problems with processed data
- **`OperationalError`**: Database operational errors (disconnect, memory allocation, etc.)
- **`IntegrityError`**: Database integrity errors (foreign key check fails, etc.)
- **`InternalError`**: Internal database errors (cursor not valid, transaction out of sync)
- **`ProgrammingError`**: Programming errors (table not found, syntax error, wrong parameter count)
- **`NotSupportedError`**: Method or API not supported by the database

## Connection Objects

Connection objects represent a database connection and provide the following methods:

### `conn.close()`

Close the connection. The connection will be unusable from this point forward.

**Returns**: `nil`

**Example**:
```quest
conn.close()
```

### `conn.commit()`

Commit any pending transaction to the database.

**Returns**: `nil`

**Example**:
```quest
conn.commit()
```

### `conn.rollback()`

Roll back any pending transaction. This method is optional since not all databases provide transaction support.

**Returns**: `nil`

**Example**:
```quest
conn.rollback()
```

### `conn.cursor()`

Return a new `Cursor` object using the connection.

**Returns**: `Cursor` object

**Example**:
```quest
let cursor = conn.cursor()
```

## Cursor Objects

Cursor objects represent a database cursor, used to manage the context of fetch operations.

### Cursor Attributes

#### `cursor.description`

Read-only attribute describing the result columns. Returns an array of dicts, where each dict contains:
- `name` (str) - Column name
- `type_code` (str) - Column type
- `display_size` (num or nil) - Display size
- `internal_size` (num or nil) - Internal size
- `precision` (num or nil) - Precision
- `scale` (num or nil) - Scale
- `null_ok` (bool or nil) - Whether NULL values are allowed

Returns `nil` for operations that do not return rows.

**Example**:
```quest
let desc = cursor.description
for col in desc
    puts("Column: " .. col.get("name") .. ", Type: " .. col.get("type_code"))
end
```

#### `cursor.row_count`

Read-only attribute specifying the number of rows that the last `execute()` produced (for SELECT statements) or affected (for UPDATE, INSERT, DELETE).

Returns `-1` if no `execute()` has been performed or the row count cannot be determined.

**Example**:
```quest
puts("Rows affected: " .. cursor.row_count._str())
```

### Cursor Methods

#### `cursor.execute(operation, params?)`

Execute a database operation (query or command).

**Parameters**:
- `operation` (str) - SQL statement to execute
- `params` (array or dict, optional) - Parameters for the operation

**Returns**: `nil` or `Cursor` (for method chaining)

**Example**:
```quest
# Without parameters
cursor.execute("SELECT * FROM users")

# With positional parameters (qmark style)
cursor.execute("SELECT * FROM users WHERE id = ?", [42])

# With named parameters (named style)
cursor.execute("SELECT * FROM users WHERE name = :name", {"name": "Alice"})
```

#### `cursor.execute_many(operation, params_seq)`

Execute a database operation against all parameter sequences in `params_seq`.

**Parameters**:
- `operation` (str) - SQL statement to execute
- `params_seq` (array of arrays or dicts) - Sequence of parameters

**Returns**: `nil` or `Cursor`

**Example**:
```quest
let users = [
    ["Alice", 30],
    ["Bob", 25],
    ["Charlie", 35]
]
cursor.execute_many("INSERT INTO users (name, age) VALUES (?, ?)", users)
```

#### `cursor.fetch_one()`

Fetch the next row of a query result set.

**Returns**: Dict representing a row, or `nil` when no more data is available

**Example**:
```quest
cursor.execute("SELECT * FROM users")
let row = cursor.fetch_one()
if row != nil
    puts(row.get("name"))
end
```

#### `cursor.fetch_many(size?)`

Fetch the next `size` rows of a query result set.

**Parameters**:
- `size` (num, optional) - Number of rows to fetch (default: cursor's array size)

**Returns**: Array of dicts (rows). Empty array when no more rows are available.

**Example**:
```quest
cursor.execute("SELECT * FROM users")
let rows = cursor.fetch_many(10)
for row in rows
    puts(row.get("name"))
end
```

#### `cursor.fetch_all()`

Fetch all remaining rows of a query result set.

**Returns**: Array of dicts (rows). Empty array when no rows are available.

**Example**:
```quest
cursor.execute("SELECT * FROM users")
let all_rows = cursor.fetch_all()
puts("Total rows: " .. all_rows.len()._str())
```

#### `cursor.close()`

Close the cursor. The cursor will be unusable from this point forward.

**Returns**: `nil`

**Example**:
```quest
cursor.close()
```

## Type Objects and Constructors

Database modules should provide constructor functions for SQL type objects:

### Date and Time Constructors

#### `db.date(year, month, day)`

Construct a date value.

**Example**:
```quest
let d = db.date(2024, 10, 3)
```

#### `db.time(hour, minute, second)`

Construct a time value.

**Example**:
```quest
let t = db.time(14, 30, 0)
```

#### `db.timestamp(year, month, day, hour, minute, second)`

Construct a timestamp value.

**Example**:
```quest
let ts = db.timestamp(2024, 10, 3, 14, 30, 0)
```

#### `db.date_from_ticks(ticks)`

Construct a date value from UNIX timestamp (seconds since epoch).

**Example**:
```quest
let d = db.date_from_ticks(1696348800)
```

#### `db.time_from_ticks(ticks)`

Construct a time value from UNIX timestamp.

**Example**:
```quest
let t = db.time_from_ticks(1696348800)
```

#### `db.timestamp_from_ticks(ticks)`

Construct a timestamp value from UNIX timestamp.

**Example**:
```quest
let ts = db.timestamp_from_ticks(1696348800)
```

### Binary Constructor

#### `db.binary(bytes)`

Construct a binary value from bytes.

**Example**:
```quest
let bin = db.binary(b"\x00\x01\x02")
```

### Type Objects

Modules should provide type objects for comparison with column types in `cursor.description`:

- `db.STRING` - String-based columns (CHAR, VARCHAR, TEXT)
- `db.BINARY` - Binary columns (BLOB, BYTEA)
- `db.NUMBER` - Numeric columns (INTEGER, FLOAT, DECIMAL)
- `db.DATETIME` - Date/time columns (DATE, TIME, TIMESTAMP)
- `db.ROWID` - Row ID columns

**Example**:
```quest
let desc = cursor.description
for col in desc
    if col.get("type_code") == db.STRING
        puts("String column: " .. col.get("name"))
    end
end
```

## Implementation Hints

### Parameter Binding

Modules should use bound parameters rather than string interpolation to prevent SQL injection:

**Good**:
```quest
cursor.execute("SELECT * FROM users WHERE name = ?", ["Alice"])
```

**Bad**:
```quest
let name = "Alice"
cursor.execute("SELECT * FROM users WHERE name = '" .. name .. "'")
```

### Resource Management

Connections and cursors should be closed when no longer needed:

```quest
let conn = db.connect(database: "mydb")
try
    let cursor = conn.cursor()
    try
        cursor.execute("SELECT * FROM users")
        let rows = cursor.fetch_all()
        # Process rows...
    ensure
        cursor.close()
    end
ensure
    conn.close()
end
```

### Transaction Handling

For databases that support transactions, changes should be committed explicitly:

```quest
let conn = db.connect(database: "mydb")
try
    let cursor = conn.cursor()
    cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Alice", 30])
    cursor.execute("INSERT INTO users (name, age) VALUES (?, ?)", ["Bob", 25])
    conn.commit()
catch e
    conn.rollback()
    puts("Transaction failed: " .. e.message())
ensure
    conn.close()
end
```

## Optional Extensions

The following extensions are optional but recommended:

### `cursor.next_set()`

Move to the next available result set (for procedures returning multiple result sets).

**Returns**: `true` if another result set is available, `false` otherwise

### `cursor.set_input_sizes(sizes)`

Predefine memory areas for operation parameters (performance optimization).

**Parameters**:
- `sizes` (array) - Sequence of type objects or integers for parameter types

### `cursor.set_output_size(size, column?)`

Set column buffer size for fetches of large columns (LONG, BLOB).

**Parameters**:
- `size` (num) - Maximum size
- `column` (num, optional) - Column index (nil for all columns)

### Two-Phase Commit

For databases supporting two-phase commit:

#### `conn.xid(format_id, global_transaction_id, branch_qualifier)`

Create a transaction ID object.

#### `conn.tpc_begin(xid)`

Begin a TPC transaction with the given transaction ID.

#### `conn.tpc_prepare()`

Prepare the transaction for commit.

#### `conn.tpc_commit(xid?)`

Commit the prepared transaction.

#### `conn.tpc_rollback(xid?)`

Roll back the prepared transaction.

#### `conn.tpc_recover()`

Return a list of pending transaction IDs.

## Complete Example

```quest
use "std/db/postgres" as db

# Connect to database
let conn = db.connect(
    host: "localhost",
    database: "myapp",
    user: "admin",
    password: "secret"
)

try
    # Create cursor
    let cursor = conn.cursor()

    try
        # Execute query
        cursor.execute("SELECT id, name, age FROM users WHERE age > ?", [18])

        # Fetch results
        puts("Column descriptions:")
        for col in cursor.description
            puts("  " .. col.get("name") .. " (" .. col.get("type_code") .. ")")
        end

        puts("\nResults:")
        let rows = cursor.fetch_all()
        for row in rows
            puts("ID: " .. row.get("id")._str() ..
                 ", Name: " .. row.get("name") ..
                 ", Age: " .. row.get("age")._str())
        end

        puts("\nTotal rows: " .. cursor.row_count._str())

        # Insert new user
        cursor.execute(
            "INSERT INTO users (name, age) VALUES (?, ?)",
            ["Charlie", 28]
        )
        conn.commit()
        puts("Inserted " .. cursor.row_count._str() .. " row(s)")

    catch e
        conn.rollback()
        puts("Error: " .. e.message())
    ensure
        cursor.close()
    end
ensure
    conn.close()
end
```

## Future Considerations

- Connection pooling interfaces
- Asynchronous query execution
- Streaming result sets
- Prepared statement caching
- Schema introspection methods

## References

This specification is adapted from Python's PEP 249 (Database API Specification v2.0) for use with the Quest programming language.

## Copyright

This document is placed in the public domain.
