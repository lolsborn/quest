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
- **Control flow**: if/elif/else blocks, match statements (QEP-016), while, for..in
- **Match statements**: `match expr in val1 ... in val2 ... else ... end` - pattern matching for equality
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

### Function Decorators (QEP-003)

**Class-based decorators** for modifying/enhancing function behavior:
```quest
use "std/decorators" as dec

# Import decorator type into scope
let Timing = dec.Timing
let Cache = dec.Cache

@Timing
@Cache(max_size: 100, ttl: 300)
fun expensive_query(id)
    # Function implementation
end
```

**Built-in decorators** (lib/std/decorators.q):
- `Timing` - Measure execution time
- `Log` - Log function calls with args/results
- `Cache` - Memoization with TTL
- `Retry` - Automatic retry with exponential backoff
- `Once` - Execute only once
- `Deprecated` - Deprecation warnings

**Key features**:
- Bottom-to-top application order (closest to function executes first)
- Works on functions, instance methods, static methods
- Requires `*args, **kwargs` for transparent argument forwarding
- Decorators are types implementing: `_call(*args, **kwargs)`, `_name()`, `_doc()`, `_id()`
- Fields in decorated functions: `self.func()` calls the field if callable (QEP-003 fix)

**Creating custom decorators**:
```quest
type my_decorator
    func

    fun _call(*args, **kwargs)
        puts("Before")
        let result = self.func(*args, **kwargs)
        puts("After")
        return result
    end

    fun _name()
        return self.func._name()
    end

    fun _doc()
        return self.func._doc()
    end

    fun _id()
        return self.func._id()
    end
end
```

### Functions and Default Parameters (QEP-033)

**Basic syntax**:
```quest
fun greet(name, greeting = "Hello")
    greeting .. ", " .. name
end

greet("Alice")           # "Hello, Alice"
greet("Bob", "Hi")       # "Hi, Bob"
```

**Key features**:
- Parameters with defaults are optional at call sites
- Defaults evaluated at **call time** (not definition time)
- Defaults can reference earlier parameters: `fun f(x, y = x + 1)`
- Defaults can reference outer scope variables (closure capture)
- Required parameters must come before optional ones
- Works with typed parameters: `fun add(x: Int, y: Int = 10)`
- Supported in: functions, lambdas, instance methods, static methods

**Examples**:
```quest
# Multiple defaults
fun connect(host = "localhost", port = 8080, timeout = 30)
    # ...
end

# Defaults reference earlier params
fun add_with_default(x, y = x)
    x + y
end

# Lambda with defaults
let double = fun (x, factor = 2) x * factor end

# Type methods with defaults
type Point
    pub x: Int
    pub y: Int

    static fun origin(x = 0, y = 0)
        Point.new(x: x, y: y)
    end
end
```

**Validation**:
- ✅ Required before optional: `fun f(a, b = 1, c = 2)`
- ❌ Optional before required: `fun f(a = 1, b)` - Error!

### Variadic Parameters (QEP-034 MVP)

**Basic `*args` syntax**:
```quest
fun sum(*numbers)
    let total = 0
    let i = 0
    while i < numbers.len()
        total = total + numbers[i]
        i = i + 1
    end
    total
end

sum()               # 0 (empty array)
sum(1)              # 1
sum(1, 2, 3)        # 6
sum(1, 2, 3, 4, 5)  # 15
```

**Key features**:
- `*args` collects remaining positional arguments into an Array
- Works with regular and optional parameters: `fun f(required, optional = default, *args)`
- Works with lambdas: `let f = fun (*args) args.len() end`
- Works with type methods (instance and static)
- Parameter order: required → optional → `*args`

**Examples**:
```quest
# Mixed parameters
fun greet(greeting, *names)
    let result = greeting
    let i = 0
    while i < names.len()
        result = result .. " " .. names[i]
        i = i + 1
    end
    result
end

greet("Hello")                    # "Hello"
greet("Hello", "Alice")           # "Hello Alice"
greet("Hello", "Alice", "Bob")    # "Hello Alice Bob"

# With defaults and varargs
fun connect(host, port = 8080, *extra)
    host .. ":" .. port.str() .. " extras:" .. extra.len().str()
end

connect("localhost")              # "localhost:8080 extras:0"
connect("localhost", 3000)        # "localhost:3000 extras:0"
connect("localhost", 3000, "a")   # "localhost:3000 extras:1"
```

### Named Arguments (QEP-035)

**Call functions with named arguments**:
```quest
fun greet(greeting, name)
    greeting .. ", " .. name
end

# All positional (still works)
greet("Hello", "Alice")              # "Hello, Alice"

# All named
greet(greeting: "Hello", name: "Alice")    # "Hello, Alice"

# Named arguments can be reordered
greet(name: "Alice", greeting: "Hello")    # "Hello, Alice"

# Mixed: positional then named
greet("Hello", name: "Alice")        # "Hello, Alice"
```

**Skip optional parameters with named args**:
```quest
fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
    # ...
end

# Skip middle parameters
connect("localhost", ssl: true)                # Use defaults for port, timeout
connect("localhost", debug: true, ssl: true)   # Skip port, timeout
```

**Rules**:
- Once you use a named argument, remaining arguments must also be named
- Named arguments must match parameter names exactly
- Can't specify same parameter both positionally and by keyword

### Keyword Arguments (**kwargs) (QEP-034 Phase 2)

**`**kwargs` collects extra named arguments**:
```quest
fun configure(host, port = 8080, **options)
    let opts_count = options.len()
    host .. ":" .. port.str() .. " (" .. opts_count.str() .. " options)"
end

configure(host: "localhost", ssl: true, timeout: 60, debug: true)
# "localhost:8080 (3 options)" - options = {ssl: true, timeout: 60, debug: true}

# Full signature with all parameter types
fun connect(host, port = 8080, *extra, **options)
    # host: required
    # port: optional with default
    # extra: Array of extra positional args
    # options: Dict of extra keyword args
end

# Works in functions, lambdas, instance methods, and static methods
type Handler
    fun process(*args, **kwargs)
        # Fully functional in all method types
    end
end
```

### Unpacking Arguments (QEP-034 Phase 3)

**Array unpacking with `*expr`**:
```quest
fun add(x, y, z)
    x + y + z
end

let args = [1, 2, 3]
add(*args)  # 6 - unpacks array to positional args

# Mix with regular args
add(1, *[2, 3])  # 6
```

**Dict unpacking with `**expr`**:
```quest
fun greet(greeting, name)
    greeting .. ", " .. name
end

let kwargs = {greeting: "Hello", name: "Alice"}
greet(**kwargs)  # "Hello, Alice"

# Mix with explicit named args (last value wins)
greet(**kwargs, name: "Bob")  # "Hello, Bob"
```

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

**Exception object methods**: `.type()`, `.message()`, `.stack()`, `.str()`

**Backwards compatibility**: String-based `raise "error"` still works (treated as `RuntimeErr`)

### Multi-line REPL

Tracks nesting level with continuation prompts (`.>`, `..>`). Evaluates when nesting returns to 0.

## Web Framework

Quest provides a unified web framework via `std/web` (QEP-051):

```quest
use "std/web" as web

# Configure static files
web.add_static('/assets', './public')

# Configure CORS
web.set_cors(origins: ["*"], methods: ["GET", "POST"])

# Add middleware hooks
web.before_request(fun (req)
    puts("[LOG] " .. req["method"] .. " " .. req["path"])
    return req
end)

web.after_request(fun (req, resp)
    resp["headers"]["X-Powered-By"] = "Quest"
    return resp
end)

# Add redirects and default headers
web.redirect("/old", "/new", 301)
web.set_default_headers({"X-Frame-Options": "DENY"})

fun handle_request(request)
    {"status": 200, "body": "Hello"}
end

# Run with: quest serve app.q
```

**Key Features:**
- Multiple static file directories with custom mount points
- CORS configuration for API development
- Before/after request hooks (middleware)
- Error handlers for custom 404/500 pages
- Redirects (permanent/temporary)
- Default response headers
- Configuration from quest.toml (via QEP-053)

See [QEP-051 spec](specs/qep-051-web-framework.md) for full details.

## Standard Library

**Module Policy**: All module functions MUST use prefix (e.g., `io.read()`, `hash.md5()`, `json.stringify()`)

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
- `std/conf`: Module configuration system (QEP-053) - register schemas, load from quest.toml with environment overrides, validation
- `std/toml`: Native TOML parsing - parse() converts TOML strings to dictionaries
- `std/log`: Python-inspired hierarchical logging, 5 levels, handlers (Stream, File), formatters, colored output

**Configuration System** (QEP-053):
Modules can declare Configuration types with schemas:
```quest
use "std/conf" as conf

pub type Configuration
    setting1: Str?
    setting2: Int? = 42

    static fun from_dict(dict)
        let config = Configuration._new()
        if dict.contains("setting1")
            config.setting1 = dict["setting1"]
        end
        return config
    end
end

conf.register_schema("my.module", Configuration)
pub let config = conf.get_config("my.module")
```

Configuration files (precedence: quest.toml < quest.<env>.toml < quest.local.toml):
```toml
# quest.toml
[my.module]
setting1 = "value"
setting2 = 100
```

Key functions: `register_schema()`, `get_config()`, `load_module_config()`, `merge()`, `list_modules()`, `clear_cache()`

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

**Full Test Suite**: 
To run the full test suite use:
`./target/release/quest test`

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
7. **Struct semantics**: User-defined structs use **reference semantics** (`Rc<RefCell<QStruct>>`) - mutations are visible across all references, matching Python/Ruby/JS behavior (Bug #016 fix)
8. **Array method optimization** (QEP-042): Hot-path methods (`len`, `push`, `pop`, `get`) are inlined in `call_method_on_value()` to bypass HashMap lookup and method dispatch overhead, significantly improving loop performance
9. **Integer arithmetic optimization** (QEP-042): Fast paths for Int+Int, Int-Int, Int*Int, Int/Int, Int%Int operations inline the arithmetic directly without method dispatch, providing 2-3x speedup in loops with counters
10. **Comparison operator optimization** (QEP-042): Fast paths for Int comparisons (`<`, `>`, `<=`, `>=`, `==`, `!=`) inline the comparison directly, eliminating function call overhead in loop conditions
11. **Array pre-allocation optimization** (QEP-042 #6): Empty arrays start with capacity 16; push uses aggressive growth (4x for <1024 elements, 2x for >=1024), reducing reallocations by 60% for typical arrays
12. **Iterative evaluator** (QEP-049): Implemented in `src/eval.rs` (~1,100 lines). Uses explicit heap-allocated stack instead of Rust's call stack, preventing stack overflow in deeply nested expressions. Currently handles: literals (nil, boolean, number, bytes, type_literal), comparison operators (==, !=, <, >, <=, >=), and if statements (if/elif/else). Uses hybrid approach with intelligent fallbacks to recursive eval for unimplemented operators. All 2504 tests pass. See `reports/qep-049-phase1-4-complete.md` for details.

## Documentation

Main documentation is in `docs/docs/` (Docusaurus site):
- Build: `cd docs && npm run build`
- Sidebar: `docs/sidebars.ts` - organized into Language Reference, Built-in Types, and Modules
- Type pages: Complete coverage including BigInt, Bool, Nil, Bytes
- Module pages: 24 stdlib modules organized by category (Core, Encoding, Database, Web, etc.)
- Language pages: Functions (with default/variadic params), Exceptions (typed), Control Flow, etc.

Legacy docs:
- `docs/obj.md` - Object system spec
- `docs/string.md` - String method specs
- `docs/types.md` - Type system docs
- `docs/control_flow.md` - Control flow structures
- `TEST_SUITE_STATUS.md` - Test suite status
- `bugs/` - Bug reports with reproduction cases

## Rules

- Quest code files end in `.q`
- Do not comment out or skip tests just to get tests passing
