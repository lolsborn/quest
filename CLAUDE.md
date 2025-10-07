# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Quest is a scripting language focused on developer happiness with a REPL implementation in Rust. Everything is an object (including primitives), and all operations are method calls.

## Build and Run

```bash
cargo build --release
./target/release/quest                           # REPL
./target/release/quest scripts/test.q test/      # Run tests (condensed)
./target/release/quest scripts/test.q -v test/   # Run tests (verbose)
./target/release/quest test/sys_test.q           # Run specific test file
```

## Architecture

### Core Components

**Parser**: Pest parser (`src/quest.pest`) - Statements (let, assignment, if/elif/else, function/type declarations), expressions (full operator precedence), postfix operations (method calls, member access)

**Evaluator**: Recursive pattern in `src/main.rs`:
- `eval_expression(input, variables)` - Entry point
- `eval_pair(pair, variables)` - Recursive evaluator
- Variables in `HashMap<String, QValue>`

**Object System**: Everything implements `QObj` trait with methods: `cls()`, `q_type()`, `is()`, `_str()`, `_rep()`, `_doc()`, `_id()`

### Type System

**Built-in Types** (wrapped in `QValue` enum):
- Int (i64, overflow checking), Float (f64), Decimal (arbitrary precision, 28-29 digits, static methods: new, from_f64, zero, one), BigInt (arbitrary precision, static methods: new, from_int, from_bytes; global constants: ZERO, ONE, TWO, TEN)
- Bool, Str (UTF-8), Bytes (binary), Nil (singleton, ID 0)
- Fun (method refs), UserFun, Type, Struct, Trait
- Array (mutable), Dict, Module, Uuid

**Number Literals**:
- Int: `42`, `0xFF`, `0b1010`, `0o755`, `1_000_000`
- Float: `3.14`, `1e10`, `3.14e-5`
- BigInt: `123n`, `0xDEADBEEFn`, `0b11111111n`, `999999999999999999n` (unlimited precision, suffix `n`)
- Type-preserving arithmetic: `Int + Int = Int`, promotion: `Int + Float = Float`
- Integer division truncates: `10 / 3 = 3`

**String Literals**: Single/double quotes, triple quotes for multi-line, f-strings: `f"Hello {name}"`, escape sequences

**Bytes Literals**: `b"..."` or `b'...'`, hex escapes: `b"\xFF\x01"`

**User-Defined Types**: Rust-inspired structs with traits
```quest
type Person
    name: str        # Required typed field
    age: int?        # Optional (defaults to nil)

    fun greet()      # Instance method (has self)
        "Hello, " .. self.name
    end

    static fun default()  # Static method (no self)
        Person.new(name: "Unknown")
    end
end
```

**Type Annotations**: int, float, num, decimal, str, bool, array, dict, uuid, bytes, nil

**Traits**: Interface system with validation at declaration time
```quest
trait Drawable
    fun draw()
end

type Circle
    impl Drawable
        fun draw() "Drawing circle" end
    end
end
```

### Method Calls vs Member Access

- `foo.method()` - Executes method, returns result
- `foo.method` - Returns `QFun` object (enables `3.plus._doc()`)

### Variables and Control Flow

- **Declaration**: `let x = 5` or `let x = 1, y = 2, z = 3` (multiple)
- **Constants**: `const PI = 3.14` (immutable, QEP-017)
- **Assignment**: `x = 10` (variable must exist), compound: `x += 1`
- **Control flow**: if/elif/else blocks, inline if (`value if cond else other`), while, for..in
- **Context managers**: `with context as var ... end` (Python-style, `_enter()`/`_exit()`)
- **Exceptions**: try/catch/ensure/raise, typed exceptions (QEP-037), hierarchical matching, stack traces

### Exception System (QEP-037)

**Built-in Exception Types** (all implement `Error` trait):
- `Err` - Base exception type (catches all exceptions)
- `IndexErr` - Sequence index out of range
- `TypeErr` - Wrong type for operation
- `ValueErr` - Invalid value for operation
- `ArgErr` - Wrong number/type of arguments
- `AttrErr` - Object has no attribute/method
- `NameErr` - Name not found in scope
- `RuntimeErr` - Generic runtime error
- `IOErr` - Input/output operation failed
- `ImportErr` - Module import failed
- `KeyErr` - Dictionary key not found

**Creating exceptions**:
```quest
raise Err.new("generic error")
raise IndexErr.new("index out of bounds: 10")
raise TypeErr.new("expected str, got int")
```

**Hierarchical catching**:
```quest
try
    risky_operation()
catch e: IndexErr
    # Catches only IndexErr
    puts("Index error: " .. e.message())
catch e: Err
    # Catches all other exception types (base type)
    puts("Other error: " .. e.type())
end
```

**Exception object methods**: `.type()`, `.message()`, `.stack()`, `._str()`

**Backwards compatibility**: String-based `raise "error"` still works (treated as `RuntimeErr`)

### Multi-line REPL

Tracks nesting level with continuation prompts (`.>`, `..>`). Evaluates when nesting returns to 0.

## Standard Library

**Module Policy**: All module functions MUST use prefix (e.g., `io.read()`, `hash.md5()`, `json.stringify()`)

**Core Modules**:
- `std/math`: Trig (sin, cos, tan), rounding, constants (pi, tau)
- `std/encoding/json`: parse, stringify (pretty-printing)
- `std/encoding/b64`: encode, decode, encode_url, decode_url
- `std/hash`: md5, sha1, sha256, sha512, crc32, bcrypt, hmac_sha256, hmac_sha512
- `std/compress/*`: gzip, bzip2, deflate, zlib (levels 0-9)
- `std/regex`: match, find, find_all, captures, replace, split, is_valid
- `std/uuid`: v1-v8 generation, parse, from_bytes, to_string variants
- `std/io`: File ops (read, write, append, remove, exists, glob), StringIO (in-memory buffers)
- `std/os`: Directory ops (getcwd, chdir, listdir, mkdir), env vars (getenv, setenv, environ)
- `std/term`: Terminal styling (colors, formatting)
- `std/serial`: Serial port communication (available_ports, open, read/write)
- `std/sys`: System info (version, platform, argv), load_module, eval (dynamic code execution - QEP-018), exit, I/O redirection (redirect_stream)
- `std/process/expect`: Interactive program automation (QEP-022) - spawn(), expect() pattern matching, timeout/EOF handling, control chars

**Database Modules** (QEP-001 compliant):
- `std/db/sqlite`: SQLite with :memory: support, positional/named params (`?`, `:name`)
- `std/db/postgres`: PostgreSQL, positional params (`$1`), full date/time support, DECIMAL → Decimal
- `std/db/mysql`: MySQL, qmark params (`?`), UUID as BINARY(16), DECIMAL → Decimal
- All: cursor(), execute(), fetch_one/many/all(), commit(), rollback(), error hierarchy

**Web Modules**:
- `std/http/client`: REST client (get, post, put, delete), request builder, json/text/bytes responses
- `std/http/urlparse`: URL parsing (urlparse, urljoin, parse_qs, urlencode, quote/unquote)
- `std/html/templates`: Tera templating (Jinja2-like), inheritance, filters, auto-escaping

**Configuration & Logging**:
- `std/settings`: Auto-loads `.settings.toml`, get/contains/section/all, dot-notation paths
- `std/log`: Python-inspired hierarchical logging, 5 levels, handlers (Stream, File), formatters, colored output

**Testing**:
- `std/test`: Test discovery (test/**/*.q, test_*.q), describe/it blocks, assertions, tags, skip
- Tag filtering: `--tag=fast`, `--skip-tag=slow`
- Files with `_` prefix ignored by discovery (helpers, fixtures)

## Test Organization

```quest
use "std/test"
test.module("Module Name")
test.describe("Feature", fun ()
    test.it("does something", fun ()
        test.assert_eq(actual, expected, nil)
    end)
end)
```

**Tags**: `test.tag("slow")` before describe/it, command-line: `--tag=fast --skip-tag=db`

**Assertions**: assert, assert_eq, assert_neq, assert_gt/lt/gte/lte, assert_nil, assert_not_nil, assert_type, assert_near, assert_raises

## Bug Tracking

Structured system in `bugs/` directory:
- Format: `bugs/NNN_description/` (prefix `[FIXED]` when resolved)
- Required files: `description.md` (full report), `example.q` (reproduction)
- See `TEST_SUITE_STATUS.md` for current status

## Key Implementation Notes

1. **Clone requirement**: `QValue` must be `Clone` (variables store owned copies)
2. **Number handling**: Type-preserving arithmetic with automatic promotion
3. **Nil suppression**: REPL doesn't print `QValue::Nil` results
4. **Grammar ordering**: `let_statement` before `assignment` in `quest.pest`
5. **Method detection**: Check source string for `()` (Pest doesn't expose parens as tokens)
6. **ID generation**: Thread-safe via `AtomicU64::fetch_add()`, Nil always ID 0

## Documentation

- `docs/obj.md` - Object system spec
- `docs/string.md` - String method specs
- `docs/types.md` - Type system docs
- `docs/control_flow.md` - Control flow structures
- `TEST_SUITE_STATUS.md` - Test suite status
- `bugs/` - Bug reports with reproduction cases

## Rules

- Quest code files end in `.q`
- Do not comment out or skip tests just to get tests passing
