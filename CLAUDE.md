# CLAUDE.md

This file provides guidance to Claude Code when working with code in this repository.

## Project Overview

Quest is a scripting language focused on developer happiness with a REPL implementation in Rust. Everything is an object (including primitives), and all operations are method calls.

**Code Style**: Quest source files use **2-space indentation** (not tabs). All `.q` files should follow this convention.

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

**Evaluator**: Hybrid iterative/recursive pattern:
- **Iterative** (`src/eval.rs`): Literals, comparisons, if statements - uses explicit heap stack, no recursion limits
- **Recursive** (`src/main.rs`): Complex operators, method calls - traditional recursive evaluation
- `eval_pair(pair, scope)` - Routing function (checks rule type, delegates to iterative or recursive)
- `eval_pair_impl(pair, scope)` - Recursive implementation (public for fallbacks)
- `eval_pair_iterative(pair, scope)` - Iterative implementation with state machine (QEP-049)
- Variables in `Scope` with nested scopes

**Object System**: Everything implements `QObj` trait with methods: `cls()`, `q_type()`, `is()`, `_str()`, `_rep()`, `_doc()`, `_id()`

### Type System

**Built-in Types** (wrapped in `QValue` enum):
- Int (i64, overflow checking), Float (f64), Decimal (arbitrary precision, 28-29 digits, static methods: new, from_f64, zero, one), BigInt (arbitrary precision, static methods: new, from_int, from_bytes; global constants: ZERO, ONE, TWO, TEN)
- Bool, Str (UTF-8), Bytes (binary), Nil (singleton, ID 0)
- Fun (method refs), UserFun, Type, Struct, Trait
- Array (mutable, static methods: new), Dict, Module, Uuid

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
    age: Int?        # Optional (defaults to nil)

    fun greet()      # Instance method (has self)
        "Hello, " .. self.name
    end

    static fun default()  # Static method (no self)
        Person.new(name: "Unknown")
    end
end
```

**Type Annotations**: Int, float, num, decimal, str, bool, array, dict, uuid, bytes, nil

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

**Array Bulk Initialization** (Ruby-style):
```quest
# Empty array
Array.new()              # []

# Array of nil values
Array.new(5)             # [nil, nil, nil, nil, nil]

# Array of repeated values
Array.new(3, "hello")    # [hello, hello, hello]
Array.new(10, false)     # [false, false, false, ...]
Array.new(1000000, 0)    # Efficient for large arrays (milliseconds vs seconds)
```

Performance: `Array.new(5_000_000, false)` takes ~0.4s (vs ~17s with manual loops). Uses Rust's `vec![value; count]` for optimal memory pre-allocation.

**Array Growth Optimization** (QEP-042 #6): Empty arrays pre-allocate capacity 16. Push operations use aggressive growth: 4x for arrays <1024 elements, 2x for larger arrays. This reduces reallocations from ~10 to ~4 for 1000-element arrays, providing 20-30% speedup on array-building code.

### Method Calls vs Member Access

- `foo.method()` - Executes method, returns result
- `foo.method` - Returns `QFun` object (enables `3.plus._doc()`)

### Variables and Control Flow

- **Declaration**: `let x = 5` or `let x = 1, y = 2, z = 3` (multiple)
- **Typed declaration**: `let count: Int = 42`, `let name: Str = "Alice"` (optional type annotations, not enforced)
  - Supports: `Int`, `Float`, `Num`, `Decimal`, `BigInt`, `Bool`, `Str`, `Bytes`, `Uuid`, `Nil`, `Array`, `Dict`, custom types
  - Multiple: `let x: Int = 1, y: Str = "test", z = 42` (mix typed and untyped)
  - Note: Type annotations are documentation only (no runtime validation yet)
- **Constants**: `const PI = 3.14` (immutable, QEP-017)
- **Assignment**: `x = 10` (variable must exist), compound: `x += 1`
- **Indexed assignment** (QEP-041): `arr[0] = 10`, `dict["key"] = "value"`, `grid[i][j] = x` (nested)
- **Control flow**: if/elif/else blocks, match statements (QEP-016, QEP-058), while, for..in
- **Match statements**: Pattern matching with discrete values and ranges
  - Discrete values: `match expr in val1, val2 ... in val3 ... else ... end`
  - Range patterns (QEP-058): `in 0 to 10` (inclusive), `in 0 until 10` (exclusive)
  - Step patterns: `in 0 to 100 step 2` (even numbers), `in 1 to 100 step 2` (odd numbers)
  - Mixed patterns: Combine ranges and discrete values in separate arms
  - Type support: Int, Float (with promotion), BigInt, Decimal
- **Context managers**: `with context as var ... end` (Python-style, `_enter()`/`_exit()`)
- **Exceptions**: try/catch/ensure/raise, typed exceptions (QEP-037), hierarchical matching, stack traces

### Indexed Assignment (QEP-041)

**Direct mutation of collection elements**:
```quest
let arr = [1, 2, 3]
arr[0] = 10          # Simple assignment
arr[1] += 5          # Compound assignment (+=, -=, *=, /=, %=)

let dict = {a: 1, b: 2}
dict["a"] = 100      # Update existing key
dict["c"] = 3        # Insert new key
```

**Nested indexing**:
```quest
let grid = [[1, 2], [3, 4], [5, 6]]
grid[0][1] = 20      # Multi-dimensional arrays
grid[1][0] += 10     # Compound ops on nested elements
```

**Immutability enforcement**:
- ✅ Arrays and Dicts: Mutable - indexed assignment allowed
- ❌ Strings and Bytes: Immutable - raises `TypeErr`

**Error handling**:
- `IndexErr`: Array out of bounds (`arr[10] = x` when array has 3 elements)
- `TypeErr`: Attempt to mutate immutable types (`str[0] = "x"`)

### Match Range Patterns (QEP-058)

Range matching with `to` (inclusive), `until` (exclusive), and optional `step`:
```quest
match age
in 0 to 12        # inclusive: 0..12
  "child"
in 13 until 20    # exclusive: 13..19
  "teenager"
in 20 to 64 step 2  # even numbers 20..64
  "adult-even"
else
  "senior"
end
```

Features: Numeric types (Int/Float/BigInt/Decimal), type promotion (Int/Float), step patterns (Int/BigInt only), mix ranges and discrete values

### Function Decorators (QEP-003)

Class-based decorators (bottom-to-top application):
```quest
use "std/decorators" as dec
@dec.Timing
@dec.Cache(max_size: 100, ttl: 300)
fun expensive_query(id) ... end
```

Built-in: Timing, Log, Cache, Retry, Once, Deprecated. Custom decorators are types implementing `_call(*args, **kwargs)`, `_name()`, `_doc()`, `_id()`

### Functions and Default Parameters (QEP-033)

```quest
fun greet(name, greeting = "Hello")  # greeting is optional
  greeting .. ", " .. name
end
```

Defaults evaluated at call time, can reference earlier params (`fun f(x, y = x + 1)`), required params must come first. Works in functions/lambdas/methods

### Variadic Parameters (QEP-034 MVP)

```quest
fun sum(*numbers)  # *args collects into Array
  let total = 0
  for num in numbers
    total += num
  end
  total
end
```

Order: required → optional → `*args`. Works in functions/lambdas/methods

### Named Arguments (QEP-035)

```quest
greet(greeting: "Hello", name: "Alice")  # Named args
greet(name: "Alice", greeting: "Hello")  # Can reorder
greet("Hello", name: "Alice")            # Mix positional + named
connect("localhost", ssl: true)          # Skip optional params
```

Rules: Once named, all following must be named. No duplicate parameters

### Keyword Arguments (**kwargs) (QEP-034 Phase 2)

```quest
fun configure(host, port = 8080, **options)  # **kwargs collects to Dict
  # options = {ssl: true, timeout: 60, ...}
end

# Full signature: required, optional, *args, **kwargs
fun connect(host, port = 8080, *extra, **options) ... end
```

### Unpacking Arguments (QEP-034 Phase 3)

```quest
add(*[1, 2, 3])           # *expr unpacks Array to positional
greet(**{name: "Alice"})  # **expr unpacks Dict to named
```

### Exception System (QEP-037, QEP-038)

Built-in types (all implement `Error` trait): Err (base), IndexErr, TypeErr, ValueErr, ArgErr, AttrErr, NameErr, RuntimeErr, IOErr, ImportErr, KeyErr

```quest
try
  risky_operation()
catch e: IndexErr      # Specific type
  puts(e.message())
catch e: Err           # Catches all
  puts(e.type())
ensure
  cleanup()
end
```

Custom exceptions must implement `Error` trait (`.message()`, `.str()`). Legacy `raise "string"` still works (as RuntimeErr)

### Multi-line REPL

Tracks nesting level with continuation prompts (`.>`, `..>`). Evaluates when nesting returns to 0.

## Web Framework (QEP-051, QEP-061, QEP-062)

```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Flexible routing with path parameters (QEP-062)
router.get("/post/{slug}", fun (req)
    let slug = req["params"]["slug"]  # Auto URL-decoded
    return {status: 200, body: f"Post: {slug}"}
end)

router.post("/user/{id<int>}", fun (req)
    let user_id = req["params"]["id"]  # Type-converted to Int
    return {status: 201, json: {id: user_id}}
end)

router.get("/files/{path<path>}", fun (req)
    let file_path = req["params"]["path"]  # Greedy capture
    return {status: 200, body: "Serving " .. file_path}
end)

# Register router as middleware
web.use(router.dispatch_middleware)

# Static files
web.add_static('/assets', './public')

# CORS
web.set_cors(origins: ["*"], methods: ["GET", "POST"])

# Request middleware (QEP-061) - runs for ALL requests (static + dynamic)
web.middleware(fun (req)
    req["_start_time"] = time.now()
    return req
end)

# Response middleware (QEP-061) - runs for ALL responses
web.after(fun (req, resp)
    if resp["headers"] == nil
        resp["headers"] = {}
    end
    resp["headers"]["X-Custom"] = "value"
    return resp
end)

# Legacy hooks (now aliases to middleware)
web.before_request(fun (req) ... end)  # Deprecated: use web.middleware()
web.after_request(fun (req, resp) ... end)  # Deprecated: use web.after()

# Error handlers, redirects, etc.
web.redirect("/old", "/new", 301)
web.set_default_headers({...})

# Run: quest serve app.q
```

**QEP-051 Features**: Static files, CORS, redirects, error handlers, quest.toml config

**QEP-061 Features**:
- Request middleware via `web.middleware(fun (req) -> req | response_dict end)`
- Response middleware via `web.after(fun (req, resp) -> resp end)`
- Runs for **ALL requests** (static files + dynamic routes), unlike QEP-051 hooks
- Short-circuiting: middleware can return response dict with `status` field to bypass handler
- Built-in middleware library: `std/web/middleware/logging.q`, `cors.q`, `security.q`, `static_cache.q`

**QEP-062 Features (NEW - Flexible Routing)**:
- Path parameter patterns: `/post/{slug}`, `/user/{id}/posts/{post_id}`
- Automatic URL decoding: `%20` → space, `%40` → @, etc.
- Type conversion: `{id<int>}`, `{id<uuid>}`, `{id<float>}`
- Greedy path capture: `{path<path>}` captures remaining path segments
- Router methods: `router.get()`, `router.post()`, `router.put()`, `router.delete()`, `router.patch()`
- Router instances: `Router.new()` for modular/mounted routes
- Priority-based matching: Static routes matched before dynamic, specific types before generic
- Parameters injected into `req["params"]` dict with automatic type conversion

## Module System and Imports

Traditional: `use "std/math" as math` → `math.sin(0)`

**Scoped Imports (QEP-043)**: Import specific items without prefix
```quest
use "std/math" {sin, cos, pi}       # Selective import
use "std/hash" {md5 as hash_md5}    # Rename
use "std/hash" as hash {md5, sha256}  # Combo: alias + selective
```

Explicit imports only, conflict detection, file-scoped, pub members only

## Standard Library

**Module Policy**: Module functions traditionally use prefix (e.g., `io.read()`, `hash.md5()`), but can be imported directly with QEP-043 selective imports

**Module Search Path** (in priority order):
1. Current directory (`.`)
2. Development `lib/` directory (if exists)
3. `os.search_path` (runtime modifications)
4. `QUEST_INCLUDE` environment variable
5. `~/.quest/lib/` (auto-extracted on first run after `cargo install`)

**Installation**: When Quest runs for the first time, the standard library is automatically extracted from the embedded binary to `~/.quest/lib/`. Users can customize these files. Developers working in the repo use `lib/` which takes precedence.

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
- `std/sys`: System info (version, platform, argv), load_module, eval (dynamic code execution - QEP-018), exit, I/O redirection (redirect_stream), stack depth introspection (get_call_depth, get_depth_limits - QEP-048)

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
- `std/conf`: Module configuration system (QEP-053) - register schemas, load from quest.toml with environment overrides, validation
- `std/toml`: Native TOML parsing - parse() converts TOML strings to dictionaries
- `std/log`: Python-inspired hierarchical logging, 5 levels, handlers (Stream, File), formatters, colored output

**Configuration System** (QEP-053): Declare schemas, load from quest.toml with environment overrides
```quest
conf.register_schema("my.module", Configuration)
pub let config = conf.get_config("my.module")
```
Precedence: quest.toml < quest.<env>.toml < quest.local.toml

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
    test.assert_eq(actual, expected)
  end)
end)
```

Run full suite: `./target/release/quest test`
Assertions: assert, assert_eq, assert_neq, assert_gt/lt/gte/lte, assert_nil, assert_not_nil, assert_type, assert_near, assert_raises

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
7. **Struct semantics**: User-defined structs use **reference semantics** (`Rc<RefCell<QStruct>>`) - mutations are visible across all references, matching Python/Ruby/JS behavior (Bug #016 fix)
8. **Array method optimization** (QEP-042): Hot-path methods (`len`, `push`, `pop`, `get`) are inlined in `call_method_on_value()` to bypass HashMap lookup and method dispatch overhead, significantly improving loop performance
9. **Integer arithmetic optimization** (QEP-042): Fast paths for Int+Int, Int-Int, Int*Int, Int/Int, Int%Int operations inline the arithmetic directly without method dispatch, providing 2-3x speedup in loops with counters
10. **Comparison operator optimization** (QEP-042): Fast paths for Int comparisons (`<`, `>`, `<=`, `>=`, `==`, `!=`) inline the comparison directly, eliminating function call overhead in loop conditions
11. **Array pre-allocation optimization** (QEP-042 #6): Empty arrays start with capacity 16; push uses aggressive growth (4x for <1024 elements, 2x for >=1024), reducing reallocations by 60% for typical arrays
12. **Iterative evaluator** (QEP-049): Implemented in `src/eval.rs` (~1,100 lines). Uses explicit heap-allocated stack instead of Rust's call stack, preventing stack overflow in deeply nested expressions. Currently handles: literals (nil, boolean, number, bytes, type_literal), comparison operators (==, !=, <, >, <=, >=), and if statements (if/elif/else). Uses hybrid approach with intelligent fallbacks to recursive eval for unimplemented operators. All 2504 tests pass. See `reports/qep-049-phase1-4-complete.md` for details.
13. **Scope management** (Bug #020): Iterative evaluator uses manual `scope.push()`/`scope.pop()` with careful tracking via `scope_pushed` flags in loop state. Exception handlers (lines 3226-3233, 3315-3323 in `src/eval.rs`) clean up pushed scopes when errors occur in loop bodies. Scope depth introspection via `sys.get_scope_depth()` for testing. Bug #020 (scope leaks) and Bug #021 (exceptions in if statements) both fixed.

## Documentation

Main: `docs/docs/` (Docusaurus). Build: `cd docs && npm run build`. Sidebar in `docs/sidebars.ts`
Legacy: `docs/{obj,string,types,control_flow}.md`, `TEST_SUITE_STATUS.md`, `bugs/`

## Rules

- Quest files end in `.q` and use **2-space indentation**
- Never comment out or skip tests to pass tests
