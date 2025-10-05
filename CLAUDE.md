# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A vibe coded scripting language focused on developer happiness with a REPL implementation in Rust. Everything in Quest is an object (including primitives like numbers and booleans), and all operations are method calls.

## Build and Run Commands

```bash
# Build the project
cargo build --release

# Run the REPL
./target/release/quest
# or
cargo run --release

# Run tests
./target/release/quest scripts/test.q test/     # Run test discovery on test/ (condensed output)
./target/release/quest scripts/test.q --verbose  # Run all tests with verbose output
./target/release/quest scripts/test.q -v test/   # Verbose mode (shows all tests)
./target/release/quest test/sys_test.q           # Run sys module tests directly
./target/release/quest test/db/postgres_test.q   # Run PostgreSQL tests (includes Decimal tests)

# Test runner options:
#   --condensed, -c : Condensed output (default) - shows module summaries only
#   --verbose, -v   : Verbose output - shows all individual tests
#   --no-color      : Disable colored output

# Run individual test files by path - each test file is self-contained
```

## Architecture

### Core Components

**Parser**: Uses Pest parser generator with grammar defined in `src/quest.pest`. The grammar supports:
- Statements: `let`, assignment, if/elif/else, function declarations (partial), type declarations (grammar only)
- Expressions: Full operator precedence (logical, comparison, bitwise, arithmetic)
- Postfix operations: Method calls and member access

**Evaluator**: Single-file implementation in `src/main.rs` using recursive evaluation pattern:
- `eval_expression(input, variables)` - Entry point, parses and evaluates
- `eval_pair(pair, variables)` - Recursive evaluator matching on `Rule` enum
- Variables stored in `HashMap<String, QValue>` passed through evaluation chain

**Object System**: Ruby-like object model where everything implements the `QObj` trait:
```rust
trait QObj {
    fn cls(&self) -> String;        // Type name (e.g., "Int", "Float", "Str")
    fn q_type(&self) -> &'static str;
    fn is(&self, type_name: &str) -> bool;
    fn _str(&self) -> String;       // String representation
    fn _rep(&self) -> String;       // REPL display format
    fn _doc(&self) -> String;       // Documentation
    fn _id(&self) -> u64;           // Unique object ID
}
```

### Type System

#### Built-in Types

All values are wrapped in `QValue` enum:
- `QValue::Int(QInt)` - 64-bit signed integers (i64 internally, with overflow checking)
- `QValue::Float(QFloat)` - 64-bit floating-point numbers (f64 internally)
- `QValue::Decimal(QDecimal)` - Arbitrary-precision decimals (for PostgreSQL NUMERIC/DECIMAL, 28-29 significant digits)
- `QValue::Bool(QBool)` - Booleans
- `QValue::Str(QString)` - Strings (always valid UTF-8)
- `QValue::Bytes(QBytes)` - Binary data (raw byte sequences)
- `QValue::Nil(QNil)` - Nil/null value (singleton with ID 0)
- `QValue::Fun(QFun)` - Function/method references
- `QValue::UserFun(QUserFun)` - User-defined functions
- `QValue::Type(QType)` - User-defined type definitions
- `QValue::Struct(QStruct)` - Instances of user-defined types
- `QValue::Trait(QTrait)` - Trait definitions (interfaces)

Each type struct contains:
- Its value data
- `id: u64` - Unique object ID (from atomic counter `NEXT_ID`)

**Number type behavior**:
- Integer literals (e.g., `42`, `-5`) create `Int`
- Float literals (e.g., `3.14`, `1.0`, `1e10`) create `Float`
- Type-preserving arithmetic: `Int + Int = Int`, `Float + Float = Float`
- Type promotion: `Int + Float = Float`, `Float + Decimal = Decimal`
- Integer operations use overflow checking (addition, subtraction, multiplication)
- Integer division returns `Int` (truncates toward zero): `10 / 3 = 3`
- Float division is exact: `10.0 / 3.0 = 3.333...`
- All numeric types can be compared with each other
- Mixed operations automatically promote to the more precise type

#### User-Defined Types

Quest supports a Rust-inspired type system with structs and traits:

**Type Declaration** (lines 531-745 in main.rs):
```quest
type Person
    str: name        # Required typed field
    int?: age        # Optional int field (defaults to nil)
    float?: height   # Optional float field
    str?: email

    # Instance method (has access to self)
    fun greet()
        "Hello, " .. self.name
    end

    # Static method (no self access)
    static fun default()
        Person.new(name: "Unknown", age: 0, height: 0.0)
    end
end
```

**Constructor Calls**:
- Positional: `Person.new("Alice", 30)`
- Named: `Person.new(name: "Alice", age: 30)` (order independent)
- Mixed optional: `Person.new(name: "Bob")` (age and email become nil)

**Type Components** (types.rs lines 1578-1818):
- `QType`: Type definition with fields, methods, static_methods, implemented_traits
- `FieldDef`: Field with name, type_annotation (see below), optional flag
- `QStruct`: Instance with type_name, type_id, fields HashMap, unique id

**Supported Type Annotations** (for field declarations):
- `int` - 64-bit integers
- `float` - 64-bit floating-point numbers
- `num` - any numeric type (int, float, or legacy num)
- `decimal` - high-precision decimal numbers
- `str` - UTF-8 strings
- `bool` - boolean values
- `array` - arrays
- `dict` - dictionaries
- `uuid` - UUIDs
- `bytes` - binary data
- `nil` - nil values

**Trait System** (lines 715-756 in main.rs):
```quest
trait Drawable
    fun draw()
    fun describe(detail_level)
end

type Circle
    num: radius

    impl Drawable
        fun draw()
            "Drawing circle"
        end

        fun describe(detail_level)
            "Circle with radius " .. self.radius
        end
    end
end
```

**Trait Validation** (lines 711-741 in main.rs):
- Happens at type declaration time
- Checks all required trait methods are implemented
- Validates parameter counts match trait signatures
- Errors: missing methods, parameter mismatches, undefined traits

### Method Call vs Member Access Distinction

Critical architectural decision: `foo.method()` vs `foo.method`
- **With parentheses** `foo.method()`: Executes method, returns result
- **Without parentheses** `foo.method`: Returns `QFun` object representing the method
- Implementation: Postfix handler checks original source string for `()` after identifier span

This enables: `3.plus._doc()` → access method metadata

### Method Implementation Pattern

Each type has `call_method(&self, method_name: &str, args: Vec<QValue>)` that matches on method name:
```rust
fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match method_name {
        "plus" => { /* validate args, compute, return QValue */ }
        "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
        _ => Err(format!("Unknown method"))
    }
}
```

### Literals

Quest supports several literal syntaxes for creating values:

**String literals**: `"Hello, World!"`
- Always valid UTF-8
- Support escape sequences: `\n`, `\r`, `\t`, `\\`, `\"`
- Support Unicode characters

**Bytes literals**: `b"..."`
- Python-style syntax for binary data
- Support hex escapes: `b"\xFF\x01\x42"` for arbitrary byte values
- Support common escapes: `b"\n"`, `b"\r"`, `b"\t"`, `b"\0"`, `b"\\"`, `b"\""`
- Can only contain ASCII characters (non-ASCII must use hex escapes)
- Examples:
  - `b"Hello"` - ASCII text as bytes
  - `b"\xFF\xFE"` - Binary data with specific byte values
  - `b"GET /\r\n"` - Protocol messages with control characters

**Number literals**:
- Integer literals (create `Int`): `42`, `-5`, `1000`
- Float literals (create `Float`): `3.14`, `1.0`, `-2.5`, `1.5e10`
- Scientific notation: `1e10`, `3.14e-5`

**Boolean literals**: `true`, `false`

**Nil literal**: `nil`

**Array literals**: `[1, 2, 3]`, `["a", "b", "c"]`

**Dict literals**: `{"key": "value", "count": 42}`

### Variables and Scoping

- **Declaration**: Requires `let` keyword: `let x = 5`
- **Multiple declaration**: `let x = 1, y = 2, z = 3` - comma-separated assignments in single statement
- **Assignment**: Only works on existing variables: `x = 10`
- **Scope**: Single global HashMap in REPL, passed through all evaluation functions
- **Error handling**: Attempting `x = 5` without prior `let x` gives clear error message

**Multiple let examples**:
```quest
let a = 1, b = 2, c = 3                 # Multiple simple assignments
let x = 5, y = x * 2, z = y - 1        # Can reference earlier vars in same statement
let name = "Alice", age = 30            # Different types
```

### Control Flow

**Block if/elif/else**:
```
if condition
    statements
elif condition
    statements
else
    statements
end
```

**Inline if** (ternary):
```
value if condition else other_value
```

Implementation distinguishes by presence of `elif_clause`, `else_clause`, or `statement` rules in parse tree.

### Exception Handling

Quest supports try/catch/ensure/raise for error handling:

**Basic try/catch**:
```quest
try
    raise "something went wrong"
catch e
    puts("Error: " .. e.message())
end
```

**With ensure block** (always executes):
```quest
try
    risky_operation()
catch e
    handle_error(e)
ensure
    cleanup()  # Always runs, even after error
end
```

**Exception objects** have methods:
- `e.exc_type()` - Exception type name (e.g., "Error")
- `e.message()` - Error message
- `e.stack()` - Stack trace (array of strings)
- `e.line()` - Line number where error occurred (or nil)
- `e.file()` - File where error occurred (or nil)
- `e.cause()` - Chained exception (or nil)

**Typed catch clauses**:
```quest
catch e: ValueError
    # Only catches ValueError
end
```

**Re-raising**:
```quest
try
    operation()
catch e
    log(e)
    raise  # Re-raise same exception
end
```

Implementation details:
- Exception type: `QValue::Exception(QException)` added to QValue enum
- Scope tracks current exception for bare `raise` re-raising
- Parse error messages to extract exception type/message
- Ensure blocks execute via deferred execution after try/catch
- **Stack traces**: Fully implemented! Each function call pushes a `StackFrame` onto `Scope.call_stack`, which is captured when exceptions are created. Stack includes function names and is accessible via `e.stack()` method.

### Multi-line REPL

REPL tracks nesting level:
- `if` and `fun` keywords increment nesting
- `end` keyword decrements nesting
- Evaluates complete statement when nesting returns to 0
- Shows continuation prompt (`.>`, `..>`, etc.) based on depth

### ID Generation

Thread-safe unique IDs via `AtomicU64::fetch_add()`:
- Every object gets unique ID on construction via `next_object_id()`
- Nil always has ID 0 (singleton)
- Accessible via `obj._id()` method

## Currently Implemented Features

- **Built-in Types**: Int (64-bit signed integers with overflow checking), Float (64-bit floats), Decimal (arbitrary precision decimals), Bool, Str (always valid UTF-8), Bytes (binary data), Uuid (UUIDs), Nil, Fun (method references), UserFun, Module, Array, Dict
- **User-Defined Types**:
  - Type declarations with typed and optional fields
  - Constructors with positional and named arguments
  - Instance methods with `self` access
  - Static methods with `static fun` keyword
  - Traits and `impl` blocks
  - Runtime type validation
  - Trait method validation at definition time
- **Operators**: All arithmetic, comparison, logical (`and`, `or`, `not`), bitwise operations, string concat (`..`)
- **Methods**:
  - Int: plus, minus, times, div, mod, comparison methods (eq, neq, gt, lt, gte, lte), abs, to_f64, to_string, _id, _str, _rep
  - Float: plus, minus, times, div, mod, comparison methods (eq, neq, gt, lt, gte, lte), abs, floor, ceil, round, to_int, to_string, is_nan, is_infinite, is_finite, _id, _str, _rep
  - Decimal: plus, minus, times, div, mod, eq, neq, gt, lt, gte, lte, to_f64, to_string, _id, _str, _rep
  - Str: 30+ methods including len, concat, upper, lower, capitalize, title, trim, is* checks, encode, split, slice, replace, bytes, etc.
  - Bytes: len, get, slice, decode (utf-8, hex, ascii), to_array, concatenation with `..`
  - Uuid: to_string, to_hyphenated, to_simple, to_urn, to_bytes, version, variant, is_nil, eq, neq, _id
  - Bool: eq, neq, _id
  - Fun: _doc, _str, _rep, _id
  - Array: Mutable arrays with 40+ methods
    - Mutating: push, pop, shift, unshift, reverse, sort, clear, insert, remove, remove_at (modify in place)
    - Non-mutating: sorted, reversed, slice, concat, map, filter, each, reduce, find, find_index, any, all (return new arrays/values)
    - Query: len, get, first, last, contains, index_of, count, empty, join
  - Dict: Full CRUD operations, each, keys, values, contains, etc.
  - Struct: Field access, method calls
  - Type: Constructor (.new), static methods
- **Control flow**: if/elif/else blocks, inline if expressions, while loops, for..in loops with ranges
- **Exception Handling**: try/catch/ensure/raise with exception objects, typed catch clauses, re-raising
- **Variables**: let declaration (single and multiple: `let x = 1, y = 2`), assignment, compound assignment (+=, -=, etc.), scoping, `del` statement
- **Functions**: Named functions, lambdas, closures, user-defined functions
- **Modules**: Import system with `use`, module member access, runtime module loading via `sys.load_module(path)`
- **Built-in functions**: puts(), print(), len(), ticks_ms()
- **Module Namespace Policy**: All module functions MUST be called with their module prefix (e.g., `io.read()`, `hash.md5()`, `term.red()`, `json.stringify()`). Unprefixed versions are not available to keep the global namespace clean. This applies to all standard library modules.
- **Standard Library Modules**:
  - `std/math`: Trigonometric functions (sin, cos, tan, asin, acos, atan), rounding (floor, ceil, round with decimal places), constants (pi, tau)
  - `std/encoding/json`: JSON parsing (parse, stringify) with pretty-printing support
  - `std/hash`: Cryptographic hashing (md5, sha1, sha256, sha512, crc32, bcrypt, hmac_sha256, hmac_sha512)
  - `std/encoding/b64`: Base64 encoding/decoding (encode, decode, encode_url, decode_url)
  - `std/crypto`: HMAC operations (hmac_sha256, hmac_sha512)
  - `std/regex`: Regular expressions (match, find, find_all, captures, captures_all, replace, replace_all, split, is_valid)
  - `std/decimal`: Arbitrary precision decimal numbers for financial and scientific calculations
    - `decimal.new(value)` - Create Decimal from string or number (e.g., `decimal.new("123.45")` or `decimal.new(100.5)`)
    - `decimal.from_f64(value)` - Create Decimal from 64-bit float
    - `decimal.zero()` - Create Decimal representing zero
    - `decimal.one()` - Create Decimal representing one
    - Decimal methods: `plus()`, `minus()`, `times()`, `div()`, `mod()`, `eq()`, `neq()`, `gt()`, `lt()`, `gte()`, `lte()`, `to_f64()`, `to_string()`
    - Supports operations with both Decimal, Int, and Float types
    - Preserves precision for financial calculations (avoids floating-point rounding errors)
    - Used automatically for DECIMAL/NUMERIC columns in PostgreSQL and MySQL
  - `std/uuid`: UUID (Universally Unique Identifier) generation and manipulation - supports all RFC 4122 versions
    - `uuid.v1(node_id?)` - Generate timestamp + node ID based UUID (optional 6-byte node_id)
    - `uuid.v3(namespace, name)` - Generate MD5 namespace-based UUID (deterministic)
    - `uuid.v4()` - Generate random UUID (unpredictable, general purpose)
    - `uuid.v5(namespace, name)` - Generate SHA1 namespace-based UUID (deterministic, preferred over v3)
    - `uuid.v6(node_id?)` - Generate improved timestamp-based UUID (preferred over v1)
    - `uuid.v7()` - Generate time-ordered UUID (sortable, timestamp-based, ideal for database primary keys)
    - `uuid.v8(data)` - Generate custom UUID from 16 bytes of data
    - `uuid.nil_uuid()` - Create nil UUID (all zeros)
    - `uuid.parse(string)` - Parse UUID from string (hyphenated or simple format)
    - `uuid.from_bytes(bytes)` - Create UUID from 16 bytes
    - Namespace constants: `NAMESPACE_DNS`, `NAMESPACE_URL`, `NAMESPACE_OID`, `NAMESPACE_X500`
    - Uuid methods: `to_string()`, `to_hyphenated()`, `to_simple()`, `to_urn()`, `to_bytes()`, `version()`, `variant()`, `is_nil()`, `eq()`, `neq()`
    - Integrates with PostgreSQL UUID type
    - Recommendations: v7 for database primary keys, v4 for general unique IDs, v5 for deterministic IDs from names
  - `std/io`: File operations:
    - `io.read(path)` - Read entire file as string
    - `io.write(path, content)` - Write string to file (overwrites)
    - `io.append(path, content)` - Append string to file
    - `io.remove(path)` - Remove file or directory
    - `io.exists(path)` - Check if file/directory exists (returns bool)
    - `io.is_file(path)` - Check if path is a file (returns bool)
    - `io.is_dir(path)` - Check if path is a directory (returns bool)
    - `io.size(path)` - Get file size in bytes (returns num)
    - `io.glob(pattern)` - Find files matching glob pattern (returns array)
    - `io.glob_match(path, pattern)` - Check if path matches glob pattern (returns bool)
  - `std/term`: Terminal styling (colors, formatting)
  - `std/serial`: Serial port communication for Arduino, microcontrollers, and devices
    - `serial.available_ports()` - List all serial ports (returns array of dicts with port_name and type)
    - `serial.open(port, baud_rate)` - Open serial port (returns SerialPort object)
    - SerialPort methods: `read(size)` returns Bytes, `write(data)` accepts String or Bytes, `flush()`, `close()`, `bytes_available()`, `clear_input()`, `clear_output()`, `clear_all()`
  - `std/db/sqlite`: SQLite database interface (QEP-001 compliant)
    - `sqlite.connect(path)` - Open database connection (use ":memory:" for in-memory)
    - `sqlite.version()` - Get SQLite library version
    - Connection methods: `cursor()`, `close()`, `commit()`, `rollback()`, `execute(sql, params?)`
    - Cursor methods: `execute(sql, params?)`, `execute_many(sql, params_seq)`, `fetch_one()`, `fetch_many(size?)`, `fetch_all()`, `close()`
    - Cursor attributes: `description()` (column metadata), `row_count()` (rows affected)
    - Parameter styles: Positional (`?`) and named (`:name` or dict keys)
    - Type mapping: Int/Float ↔ INTEGER/REAL, Str ↔ TEXT, Bytes ↔ BLOB, Bool ↔ INTEGER, Nil ↔ NULL
    - Error hierarchy: DatabaseError, IntegrityError, ProgrammingError, DataError, OperationalError
  - `std/db/postgres`: PostgreSQL database interface (QEP-001 compliant)
    - `postgres.connect(connection_string)` - Open database connection with connection string
    - Connection methods: `cursor()`, `close()`, `commit()`, `rollback()`, `execute(sql, params?)`
    - Cursor methods: `execute(sql, params?)`, `execute_many(sql, params_seq)`, `fetch_one()`, `fetch_many(size?)`, `fetch_all()`, `close()`
    - Cursor attributes: `description()` (column metadata), `row_count()` (rows affected)
    - Parameter style: Positional only (`$1`, `$2`, etc.)
    - Type mapping:
      - Int/Float ↔ INTEGER/REAL
      - Decimal ↔ NUMERIC/DECIMAL
      - Str ↔ TEXT/VARCHAR
      - Bytes ↔ BYTEA
      - Bool ↔ BOOLEAN
      - Uuid ↔ UUID
      - Timestamp ↔ TIMESTAMP (without timezone)
      - Zoned ↔ TIMESTAMPTZ (with timezone)
      - Date ↔ DATE
      - Time ↔ TIME
      - Nil ↔ NULL
    - Date/Time handling: Full support for PostgreSQL date/time types with timezone-aware conversions
    - Error hierarchy: DatabaseError, IntegrityError, ProgrammingError, DataError, OperationalError
    - Connection string format: `host=HOST port=PORT user=USER password=PASSWORD dbname=DATABASE`
  - `std/db/mysql`: MySQL database interface (QEP-001 compliant)
    - `mysql.connect(connection_string)` - Open database connection with connection string
    - Connection methods: `cursor()`, `close()`, `commit()`, `rollback()`, `execute(sql, params?)`
    - Cursor methods: `execute(sql, params?)`, `execute_many(sql, params_seq)`, `fetch_one()`, `fetch_many(size?)`, `fetch_all()`, `close()`
    - Cursor attributes: `description()` (column metadata), `row_count()` (rows affected)
    - Parameter style: `qmark` - Question mark style (`?` placeholders)
    - Type mapping:
      - Int/Float ↔ INT/BIGINT/FLOAT/DOUBLE
      - Decimal ↔ DECIMAL/NUMERIC (full precision maintained with rust_decimal)
      - Str ↔ VARCHAR/TEXT
      - Bytes ↔ BLOB/BINARY/VARBINARY
      - Bool ↔ BOOLEAN (stored as 0/1)
      - Uuid ↔ BINARY(16)
      - Timestamp ↔ DATETIME/TIMESTAMP (includes microsecond precision)
      - Date ↔ DATE
      - Time ↔ TIME
      - Nil ↔ NULL
    - UUID handling: Stored as BINARY(16), automatically converted to/from Quest Uuid type (any BINARY(16) column is treated as UUID)
    - Date/Time handling: Automatically converts MySQL date/time types to Quest time types with full microsecond precision support
    - Decimal precision: MySQL DECIMAL/NUMERIC columns are automatically converted to Quest Decimal type, preserving full precision (up to 28-29 significant digits)
    - Transaction support: Autocommit disabled by default for proper transaction handling
    - Error hierarchy: DatabaseError, IntegrityError, ProgrammingError, DataError, OperationalError
    - Connection string format: `mysql://user:password@host:port/database`
  - `std/test`: Testing framework with assertions, test discovery, and tag-based filtering
    - `test.find_tests(paths)` - Discover test files from array of file/directory paths
    - `test.tag(tags)` - Set tags for next describe() or it() call (accepts string or array)
    - `test.set_filter_tags(tags)` - Only run tests with these tags
    - `test.set_skip_tags(tags)` - Skip tests with these tags
    - Tag inheritance: describe block tags are inherited by all tests within that block
    - Tag merging: individual test tags merge with describe block tags
    - Automatically filters out helper files (starting with `_` or `.`)
    - Supports mixed arrays: `["test/arrays", "test/bool/basic.q"]`
    - Used in `discover_tests.q` for pytest-style test discovery
  - `std/html/templates`: HTML templating with Tera (Jinja2-like syntax)
    - `templates.create()` - Create empty template engine instance
    - `templates.from_dir(pattern)` - Load templates from directory glob pattern (e.g., "templates/**/*.html")
    - HtmlTemplate methods:
      - `render(name, context)` - Render named template with Dict context
      - `render_str(template, context)` - Render template string directly
      - `add_template(name, content)` - Register template from string
      - `add_template_file(name, path)` - Register template from file
      - `get_template_names()` - List all registered template names
    - Template syntax features:
      - Variables: `{{ variable }}`, `{{ user.name }}`, `{{ items.0 }}`
      - Conditionals: `{% if condition %}...{% elif %}...{% else %}...{% endif %}`
      - Loops: `{% for item in items %}...{% endfor %}` with loop.index, loop.first, loop.last
      - Filters: `{{ text | upper }}`, `{{ price | round }}`, `{{ html | safe }}`
      - Template inheritance: `{% extends "base.html" %}` with `{% block name %}...{% endblock %}`
      - Comments: `{# This won't appear in output #}`
    - Common filters: upper, lower, length, round, truncate, default, safe, escape
    - Use cases: Web pages, email templates, reports, forms, dynamic HTML generation
    - Automatic HTML escaping for security (disable with `safe` filter for trusted content)
    - Example: `tmpl.add_template("page", "<h1>{{ title }}</h1>"); tmpl.render("page", {"title": "Hello"})`
  - `std/http/client`: HTTP client for making web requests (REST APIs, web scraping, integrations)
    - Module functions: `http.client()`, `http.get(url)`, `http.post(url)`, `http.put(url)`, `http.delete(url)`, `http.patch(url)`, `http.head(url)`, `http.options(url)`
    - HttpClient methods:
      - `get(url)`, `post(url)`, `put(url)`, `delete(url)`, `patch(url)`, `head(url)`, `options(url)` - Perform HTTP requests
      - `request(method, url)` - Create custom request builder
      - `timeout()` - Get current timeout setting
      - `headers()` - Get default headers
      - `set_timeout(seconds)` - Set default timeout for all requests
      - `set_header(name, value)` - Set default header for all requests
    - HttpResponse methods:
      - Status: `status()`, `ok()`, `is_success()`, `is_redirect()`, `is_client_error()`, `is_server_error()`, `is_informational()`
      - Headers: `header(name)`, `headers()`, `has_header(name)`, `content_type()`, `content_length()`
      - Body: `text()` (UTF-8 string), `json()` (parsed Dict/Array), `bytes()` (raw Bytes), `body()` (alias for bytes)
      - Content type detection: `is_json()`, `is_html()`, `is_text()`
      - URL: `url()` - Final URL after redirects
      - Cookies: `cookie(name)`, `cookies()`
    - HttpRequest builder methods (chainable):
      - `header(name, value)`, `headers(dict)` - Set request headers
      - `query(key, value)`, `queries(dict)` - Add query parameters
      - `body(data)`, `json(data)`, `form(dict)`, `text(string)`, `bytes(bytes)` - Set request body
      - `timeout(seconds)` - Set timeout for this request
      - `send()` - Execute the request and return HttpResponse
    - Features:
      - Connection pooling (automatic with client reuse)
      - Automatic redirect following
      - Cookie handling
      - Gzip compression
      - JSON serialization/deserialization
      - UTF-8 text encoding
      - Binary data support
      - Case-insensitive header access
      - Response body caching (multiple calls to text()/json() return cached result)
    - Example: `let resp = http.get("https://api.github.com/users/octocat"); let user = resp.json(); puts(user["name"])`
  - `std/settings`: Configuration management via `.settings.toml` files (automatically loaded on interpreter startup from current working directory, access via `settings.get(path)`, `settings.contains(path)`, `settings.section(name)`, `settings.all()`)
  - `std/sys`: System module (must be imported with `use "std/sys"`):
    - `sys.load_module(path)` - Load and execute a Quest module at runtime
    - `sys.version` - Quest version string
    - `sys.platform` - OS platform (darwin, linux, win32, etc.)
    - `sys.executable` - Path to quest executable
    - `sys.argc` - Command-line argument count
    - `sys.argv` - Array of command-line arguments
    - `sys.builtin_module_names` - Array of built-in module names
    - `sys.exit(code)` - Exit the program with status code (default 0)
    - `sys.fail(message)` - Raise an exception with the given message
  - `std/settings`: Configuration management module:
    - Automatically loads `.settings.toml` from current working directory on interpreter startup
    - `settings.get(path)` - Get setting value by dot-notation path (e.g., "database.pool_size")
    - `settings.contains(path)` - Check if setting exists at path
    - `settings.section(name)` - Get entire section as Dict
    - `settings.all()` - Get all settings as Dict
    - Special `[os.environ]` section sets environment variables on startup (applied to process env, not accessible via settings)
    - Type conversion: TOML types automatically converted to Quest types (String→Str, Integer→Int, Float→Float, Boolean→Bool, Array→Array, Table→Dict)
    - Missing settings return `nil` (use `settings.get("key") or default` pattern)
    - Settings loaded once at startup (no hot-reloading)
    - Example: `.settings.toml` with `[app]` section and `name = "MyApp"` → `settings.get("app.name")` returns `"MyApp"`
  - `std/log`: Python-inspired logging framework (QEP-004 compliant)
    - Hierarchical loggers with level inheritance and handler propagation
    - Five log levels: DEBUG (10), INFO (20), WARNING (30), ERROR (40), CRITICAL (50)
    - Root logger convenience functions: `log.debug()`, `log.info()`, `log.warning()`, `log.error()`, `log.critical()`, `log.exception()`
    - Named loggers: `log.get_logger("app.db")` creates hierarchical logger
    - Logger methods: `debug()`, `info()`, `warning()`, `error()`, `critical()`, `exception(message, exc)`, `set_level()`, `add_handler()`, `is_enabled_for()`
    - Handlers: StreamHandler (console output), FileHandler (file output)
    - Handler methods: `emit()`, `handle()`, `set_level()`, `set_formatter()`, `add_filter()`
    - Formatters: Customize log output format with templates
    - Formatter fields: `format_string`, `date_format`, `use_colors`
    - Filters: Filter log records by logger name hierarchy
    - Settings type: Configure logging via `.settings.toml` with `[log]` section
    - Settings fields: `level`, `use_colors`, `date_format`, `format`, `root_level`, `auto_configure`, `default_log_file`, `default_file_mode`
    - LogRecord: Dict-based data structure with keys: `name`, `level_no`, `level_name`, `message`, `created`, `relative_created`, `pathname`, `filename`, `module_name`, `line_no`, `func_name`
    - Colored console output: DEBUG (grey), INFO (cyan), WARNING (yellow), ERROR (red), CRITICAL (bold red)
    - Exception logging: Automatically includes exception type, message, and stack trace
    - Handler propagation: Messages bubble up logger hierarchy to parent handlers (can be disabled with `logger.propagate = false`)
    - Level inheritance: Child loggers inherit level from parent if not explicitly set
    - Examples: See `examples/logging/` for usage patterns
    - Known limitations: Simplified formatting (Quest lacks `string.replace()`), timestamp formatting limited (no `time.from_timestamp()`)

## Grammar vs Implementation Gap

The grammar in `quest.pest` now closely matches implementation:
- ✅ Type declarations with optional fields
- ✅ Trait declarations
- ✅ Impl blocks
- ✅ Static function declarations
- ✅ Named arguments
- ✅ Function declarations (user-defined functions)
- ✅ Iteration (for..in, while)
- ⚠️ Some advanced features in grammar but not fully implemented (lambdas, exception handling)

## Key Implementation Notes

1. **Clone requirement**: `QValue` must be `Clone` because variables store owned copies and methods return new objects
2. **Number handling**: Integer literals create `Int`, float literals create `Float`. Type-preserving arithmetic with automatic promotion.
3. **Nil suppression**: REPL doesn't print `QValue::Nil` results (statements return nil)
4. **Grammar ordering**: In `quest.pest`, statement alternatives must have `let_statement` before `assignment` (both start with identifier)
5. **Span checking**: For method call detection, check original source string via `pair.as_str()` since Pest doesn't expose parentheses as separate tokens

## Test Organization

Quest uses the `std/test` framework for all tests. Tests are automatically discovered by the test runner.

### Test Discovery

The `test.find_tests()` function discovers test files using these patterns:
- **test/\*\*/\*.q** - Any `.q` file in `test/` directory (recursively)
- **tests/\*\*/\*.q** - Any `.q` file in `tests/` directory (recursively)
- **\*\*/test_\*.q** - Any `test_*.q` file anywhere (recursively)

Files are deduplicated if they match multiple patterns.

### Skipping Test Discovery

To prevent files in test directories from being run by the test runner:
- **Use underscore prefix**: `_helper.q`, `_fixtures.q`, `_manual_test.q`
- Files starting with `_` are ignored by test discovery
- Useful for: helper modules, fixtures, manual testing scripts, work-in-progress tests

### Test Structure

```quest
use "std/test"

test.module("Module Name")

test.describe("Feature group", fun ()
    test.it("does something specific", fun ()
        test.assert_eq(actual, expected, nil)
    end)

    test.it("can be skipped", fun ()
        test.skip("Not ready yet")
    end)

    test.it("conditionally skipped", fun ()
        test.skip_if(condition, "Reason for skipping")
    end)
end)
```

### Test Tags

Tests can be tagged for selective execution. Tags enable filtering tests by category (e.g., "slow", "fast", "db", "integration").

**Tagging describe blocks** (all tests inherit the tag):
```quest
test.tag("slow")
test.describe("HTTP tests", fun ()
    test.it("fetches data", fun () ... end)  # Has tag: [slow]
    test.it("posts data", fun () ... end)    # Has tag: [slow]
end)
```

**Tagging individual tests**:
```quest
test.describe("Mixed tests", fun ()
    test.tag("fast")
    test.it("quick test", fun () ... end)  # Has tag: [fast]

    test.tag(["slow", "db"])  # Multiple tags as array
    test.it("database test", fun () ... end)  # Has tags: [slow, db]

    test.it("no tag", fun () ... end)  # No tags
end)
```

**Tag merging** (describe + individual tags combine):
```quest
test.tag("integration")
test.describe("Integration tests", fun ()
    test.tag("critical")
    test.it("critical test", fun () ... end)  # Has tags: [integration, critical]

    test.it("regular test", fun () ... end)  # Has tag: [integration]
end)
```

**State-based behavior**: `test.tag()` sets tags for the **next** `describe()` or `it()` call, then automatically resets. Tags don't leak between tests.

**Command-line filtering**:
- `--tag=<name>`: Run only tests with this tag
- `--skip-tag=<name>`: Skip tests with this tag
- Can use multiple times: `--tag=fast --skip-tag=db`

**Examples**:
```bash
# Run only fast tests
./target/release/quest scripts/qtest --tag=fast

# Skip slow tests
./target/release/quest scripts/qtest --skip-tag=slow

# Run integration tests but skip database ones
./target/release/quest scripts/qtest --tag=integration --skip-tag=db
```

**Available assertions**: `assert`, `assert_eq`, `assert_neq`, `assert_gt`, `assert_lt`, `assert_gte`, `assert_lte`, `assert_nil`, `assert_not_nil`, `assert_type`, `assert_near`, `assert_raises`

**Test control**: `skip(reason)`, `skip_if(condition, reason)`, `fail(message)`

## Bug Tracking System

Quest uses a structured bug tracking system in the `bugs/` directory.

### Bug Directory Structure

Each bug gets its own numbered directory with descriptive name:
```
bugs/
├── 003_nested_exception/
├── 004_string_bytes_bracket_indexing/
├── [FIXED] 005_literal_keyword_prefix_identifiers/
└── 006_stack_trace_depth/
```

Bugs are prefixed with `[FIXED]` when resolved.

### Required Files in Each Bug Directory

1. **description.md** - Detailed bug description with:
   - Issue summary
   - Current behavior
   - Expected behavior
   - Root cause (if known)
   - Impact and severity
   - Related code locations
   - Status
2. **example.q** - Minimal reproduction case

### Bug Report Template

```markdown
# Bug Title

## Issue
Brief description of the problem

## Current Behavior
What actually happens

## Expected Behavior
What should happen

## Failing Tests (if applicable)
- test/path/to/test.q:line - "test name"

## Example Code
```quest
# Minimal reproduction
```

## Root Cause
Technical explanation (if known)

## Impact
- **Severity**: Low/Medium/High/Critical
- **Tests Affected**: X out of Y
- **User Impact**: How users are affected

## Related Code
- File paths and line numbers

## Workaround
Steps users can take (if any)

## Status
**Open/In Progress/Fixed** - Date
```

### Creating a New Bug Report

1. Find the next available bug number (e.g., 007)
2. Create directory: `bugs/007_descriptive_name/`
3. Add required files: README.md, description.md, _reproduce.q
4. Update TEST_SUITE_STATUS.md if it affects test results
5. Prefix with `[FIXED]` when resolved

### Current Known Bugs

See `TEST_SUITE_STATUS.md` for current test suite status and `bugs/` directory for detailed bug reports.

## Documentation Structure

- `docs/obj.md` - Object system specification
- `docs/string.md` - String method specifications
- `docs/types.md` - Type system documentation
- `docs/control_flow.md` - Control flow structures
- `TEST_SUITE_STATUS.md` - Current test suite status and known issues
- `bugs/` - Structured bug reports with reproduction cases
- Other docs are specs for unimplemented features

## Other
quest code files end in .q extension
do not comment out or skip tests just to get tests passing. 


