# Database Modules

Quest provides database connectivity through three standard library modules that implement the [QEP-001 Database API](../specs/qep-001-database-api.md) specification, inspired by Python's PEP-249.

## Supported Databases

- **SQLite** - `std/db/sqlite` - Embedded SQL database
- **PostgreSQL** - `std/db/postgres` - Advanced open-source relational database
- **MySQL** - `std/db/mysql` - Popular open-source relational database

All three drivers share a common API design for consistency and ease of use.

## Common API Design

### Basic Usage Pattern

All database modules follow the same pattern:

```quest
use "std/db/sqlite" as db  # or postgres, mysql

# 1. Connect to database
let conn = db.connect(connection_string)

# 2. Get a cursor
let cursor = conn.cursor()

# 3. Execute SQL
cursor.execute("CREATE TABLE users (id INT PRIMARY KEY, name VARCHAR(255))")
cursor.execute("INSERT INTO users (id, name) VALUES (?, ?)", [1, "Alice"])

# 4. Query and fetch results
cursor.execute("SELECT * FROM users")
let rows = cursor.fetch_all()

for row in rows
    puts(row.get("id"), ": ", row.get("name"))
end

# 5. Commit and close
conn.commit()
cursor.close()
conn.close()
```

### Connection Methods

**`cursor()`**
- Returns a new cursor object for executing queries
- **Returns:** Cursor object

**`commit()`**
- Commits the current transaction
- **Returns:** Nil

**`rollback()`**
- Rolls back the current transaction
- **Returns:** Nil

**`execute(sql, params?)`**
- Convenience method to execute without cursor
- **Parameters:**
  - `sql` - SQL statement (Str)
  - `params` - Optional parameters (Array or Dict)
- **Returns:** Number of affected rows (Num)

**`close()`**
- Closes the database connection
- **Returns:** Nil

### Cursor Methods

**`execute(sql, params?)`**
- Execute a SQL statement
- **Parameters:**
  - `sql` - SQL statement (Str)
  - `params` - Optional parameters (Array or Dict)
- **Returns:** Nil

**`execute_many(sql, params_seq)`**
- Execute a SQL statement multiple times with different parameters
- **Parameters:**
  - `sql` - SQL statement (Str)
  - `params_seq` - Array of parameter arrays
- **Returns:** Nil

**`fetch_one()`**
- Fetch next row from results
- **Returns:** Row as Dict, or Nil if no more rows

**`fetch_many(size?)`**
- Fetch multiple rows from results
- **Parameters:**
  - `size` - Optional number of rows to fetch (default 10)
- **Returns:** Array of rows (as Dicts)

**`fetch_all()`**
- Fetch all remaining rows from results
- **Returns:** Array of rows (as Dicts)

**`close()`**
- Close the cursor
- **Returns:** Nil

### Cursor Attributes

**`description()`**
- Get column metadata from last query
- **Returns:** Array of column info dicts with keys: `name`, `type_code`, `display_size`, `internal_size`, `precision`, `scale`, `null_ok`

**`row_count()`**
- Get number of rows affected by last operation
- **Returns:** Number of rows (Num)

---

## SQLite

Embedded SQL database engine - perfect for local storage, prototypes, and applications.

### Importing

```quest
use "std/db/sqlite" as db
```

### Connection String

```quest
# File database
let conn = db.connect("mydata.db")

# In-memory database
let conn = db.connect(":memory:")
```

### Parameter Style

**Positional (`?`)** or **Named (`:name`)**

```quest
# Positional parameters
cursor.execute("INSERT INTO users VALUES (?, ?)", [1, "Alice"])

# Named parameters (using dict)
cursor.execute("INSERT INTO users VALUES (:id, :name)", {"id": 1, "name": "Alice"})

# Named parameters (using :name syntax)
cursor.execute("INSERT INTO users VALUES (:id, :name) WHERE id = :id", [1, "Alice"])
```

### Type Mapping

| Quest Type | SQLite Type |
|------------|-------------|
| Num | INTEGER, REAL |
| Str | TEXT |
| Bytes | BLOB |
| Bool | INTEGER (0/1) |
| Nil | NULL |

### Example

```quest
use "std/db/sqlite" as db

let conn = db.connect(":memory:")
let cursor = conn.cursor()

# Create table
cursor.execute("CREATE TABLE tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    completed INTEGER DEFAULT 0
)")

# Insert data
cursor.execute("INSERT INTO tasks (title, completed) VALUES (?, ?)",
    ["Write docs", 1])
cursor.execute("INSERT INTO tasks (title) VALUES (?)",
    ["Test code"])

# Query
cursor.execute("SELECT * FROM tasks WHERE completed = 0")
let pending = cursor.fetch_all()

puts("Pending tasks:")
for task in pending
    puts("- ", task.get("title"))
end

conn.commit()
conn.close()
```

### Special Features

- **Full-text search** - Use SQLite's FTS5 extension
- **JSON support** - SQLite's JSON1 extension
- **Lightweight** - No server required, bundled with Quest

---

## PostgreSQL

Advanced open-source database with rich features and strong standards compliance.

### Importing

```quest
use "std/db/postgres" as db
```

### Connection String

```quest
let conn = db.connect("host=localhost port=5432 user=myuser password=mypass dbname=mydb")
```

**Format:** `host=HOST port=PORT user=USER password=PASSWORD dbname=DATABASE`

### Parameter Style

**Positional (`$1`, `$2`, etc.)**

```quest
cursor.execute("INSERT INTO users (id, name) VALUES ($1, $2)", [1, "Alice"])
cursor.execute("SELECT * FROM users WHERE name = $1", ["Alice"])
```

### Type Mapping

| Quest Type | PostgreSQL Type |
|------------|-----------------|
| Num | INTEGER, BIGINT, REAL, DOUBLE PRECISION, NUMERIC |
| Decimal | NUMERIC, DECIMAL |
| Str | TEXT, VARCHAR, CHAR |
| Bytes | BYTEA |
| Bool | BOOLEAN |
| Uuid | UUID |
| Timestamp | TIMESTAMP (without timezone) |
| Zoned | TIMESTAMPTZ (with timezone) |
| Date | DATE |
| Time | TIME |
| Array | ARRAY types (INTEGER[], TEXT[], etc.) |
| Nil | NULL |

### Example

```quest
use "std/db/postgres" as db
use "std/uuid" as uuid

let conn = db.connect("host=localhost port=5432 user=myuser password=mypass dbname=mydb")
let cursor = conn.cursor()

# Create table with UUID primary key
cursor.execute("CREATE TABLE users (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE,
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT NOW()
)")

# Insert with UUID
let user_id = uuid.v4()
cursor.execute(
    "INSERT INTO users (id, name, email, tags) VALUES ($1, $2, $3, $4)",
    [user_id, "Alice", "alice@example.com", ["admin", "verified"]]
)

# Query with array support
cursor.execute("SELECT * FROM users WHERE 'admin' = ANY(tags)")
let admins = cursor.fetch_all()

for admin in admins
    puts(admin.get("name"), " - ", admin.get("email"))
    puts("Tags: ", admin.get("tags"))
end

conn.commit()
conn.close()
```

### Special Features

- **Native UUID support** - First-class UUID type
- **Array types** - Native arrays for integers, strings, UUIDs, etc.
- **Timezone-aware timestamps** - `Zoned` type for TIMESTAMPTZ
- **JSON/JSONB** - Structured data support
- **Advanced indexing** - GiST, GIN, BRIN indexes

---

## MySQL

Popular open-source relational database, widely used for web applications.

### Importing

```quest
use "std/db/mysql" as db
```

### Connection String

```quest
let conn = db.connect("mysql://user:password@localhost:3306/database")
```

**Format:** `mysql://user:password@host:port/database`

### Parameter Style

**Question marks (`?`)**

```quest
cursor.execute("INSERT INTO users (id, name) VALUES (?, ?)", [1, "Alice"])
cursor.execute("SELECT * FROM users WHERE name = ?", ["Alice"])
```

### Type Mapping

| Quest Type | MySQL Type |
|------------|------------|
| Num | INT, BIGINT, FLOAT, DOUBLE |
| Decimal | DECIMAL, NUMERIC |
| Str | VARCHAR, TEXT, CHAR |
| Bytes | BLOB, BINARY, VARBINARY |
| Bool | BOOLEAN (stored as TINYINT 0/1) |
| Uuid | BINARY(16) |
| Timestamp | DATETIME, TIMESTAMP |
| Date | DATE |
| Time | TIME |
| Nil | NULL |

### Example

```quest
use "std/db/mysql" as db
use "std/uuid" as uuid
use "std/time" as time

let conn = db.connect("mysql://quest:password@localhost:3306/myapp")
let cursor = conn.cursor()

# Create table with DECIMAL for money
cursor.execute("CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    order_id BINARY(16) NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    created_at DATETIME NOT NULL,
    UNIQUE KEY (order_id)
)")

# Insert with UUID and Decimal
let order_id = uuid.v4()
cursor.execute(
    "INSERT INTO orders (order_id, amount, created_at) VALUES (?, ?, ?)",
    [order_id, "1234.5678", time.now()]
)

# Query
cursor.execute("SELECT * FROM orders WHERE amount > ?", ["1000.00"])
let large_orders = cursor.fetch_all()

for order in large_orders
    puts("Order: ", order.get("order_id"))
    puts("Amount: ", order.get("amount"))  # Returns as Decimal with full precision
    puts("Created: ", order.get("created_at"))  # Returns as Timestamp
end

conn.commit()
conn.close()
```

### Special Features

- **High-precision decimals** - `Decimal` type preserves up to 28-29 digits
- **Microsecond precision** - Full microsecond support for timestamps
- **UUID as BINARY(16)** - Automatic conversion to/from Quest UUID
- **Transaction support** - Autocommit disabled by default
- **JSON columns** - Native JSON type (returned as strings, parse with `json.parse()`)

---

## Transactions

All three databases support transactions with commit and rollback:

```quest
use "std/db/sqlite" as db

let conn = db.connect("mydata.db")
let cursor = conn.cursor()

try
    cursor.execute("INSERT INTO accounts (id, balance) VALUES (?, ?)", [1, 1000])
    cursor.execute("UPDATE accounts SET balance = balance - 100 WHERE id = ?", [1])
    cursor.execute("INSERT INTO transactions (account_id, amount) VALUES (?, ?)", [1, -100])

    conn.commit()
    puts("Transaction committed")
catch e
    conn.rollback()
    puts("Transaction rolled back: ", e.message())
end

conn.close()
```

## Error Handling

All database modules use a consistent error hierarchy:

- **DatabaseError** - Base class for all database errors
- **IntegrityError** - Constraint violations (duplicate keys, foreign keys)
- **ProgrammingError** - SQL syntax errors, missing tables/columns
- **DataError** - Data type issues, value too long
- **OperationalError** - Connection issues, transaction errors

```quest
use "std/db/mysql" as db

let conn = db.connect("mysql://user:pass@localhost:3306/mydb")
let cursor = conn.cursor()

try
    cursor.execute("INSERT INTO users (id, name) VALUES (?, ?)", [1, "Alice"])
    cursor.execute("INSERT INTO users (id, name) VALUES (?, ?)", [1, "Bob"])  # Duplicate!
catch e: IntegrityError
    puts("Duplicate key error: ", e.message())
catch e: DatabaseError
    puts("Database error: ", e.message())
end

conn.close()
```

## Best Practices

### 1. Always Use Parameterized Queries

❌ **Don't:**
```quest
let name = "Alice"
cursor.execute("SELECT * FROM users WHERE name = '" .. name .. "'")  # SQL injection risk!
```

✅ **Do:**
```quest
cursor.execute("SELECT * FROM users WHERE name = ?", [name])  # Safe
```

### 2. Close Resources

Always close cursors and connections when done:

```quest
let conn = db.connect("mydata.db")
try
    let cursor = conn.cursor()
    # ... do work ...
    conn.commit()
ensure
    cursor.close()
    conn.close()
end
```

### 3. Use Transactions for Related Operations

```quest
# Good: All or nothing
try
    cursor.execute("INSERT INTO orders ...")
    cursor.execute("INSERT INTO order_items ...")
    cursor.execute("UPDATE inventory ...")
    conn.commit()
catch e
    conn.rollback()
    raise
end
```

### 4. Fetch in Batches for Large Results

Instead of `fetch_all()` for millions of rows:

```quest
cursor.execute("SELECT * FROM large_table")
while true
    let rows = cursor.fetch_many(1000)  # Process 1000 at a time
    if rows.len() == 0
        break
    end

    for row in rows
        process(row)
    end
end
```

### 5. Use the Right Type

- Use `Decimal` for money/financial data (not `Num`)
- Use `Uuid` for identifiers (not strings)
- Use `Timestamp`/`Date`/`Time` for temporal data
- Use `Bytes` for binary data (not strings)

## See Also

- [QEP-001: Database API Specification](../specs/qep-001-database-api.md)
- [UUID Module](uuid.md)
- [Time Module](time.md)
- [JSON Module](json.md)
