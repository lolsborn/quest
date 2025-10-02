# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Quest is a Ruby-inspired programming language with a REPL implementation in Rust. Everything in Quest is an object (including primitives like numbers and booleans), and all operations are method calls.

## Build and Run Commands

```bash
# Build the project
cargo build --release

# Run the REPL
./target/release/quest
# or
cargo run --release

# Run test scripts
./test_repl.sh
./target/release/quest < test_comprehensive.q
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
    fn cls(&self) -> String;        // Type name (e.g., "Num", "Str")
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
- `QValue::Num(QNum)` - Numbers (f64 internally, displays as int when appropriate)
- `QValue::Bool(QBool)` - Booleans
- `QValue::Str(QString)` - Strings
- `QValue::Nil(QNil)` - Nil/null value (singleton with ID 0)
- `QValue::Fun(QFun)` - Function/method references
- `QValue::UserFun(QUserFun)` - User-defined functions
- `QValue::Type(QType)` - User-defined type definitions
- `QValue::Struct(QStruct)` - Instances of user-defined types
- `QValue::Trait(QTrait)` - Trait definitions (interfaces)

Each type struct contains:
- Its value data
- `id: u64` - Unique object ID (from atomic counter `NEXT_ID`)

#### User-Defined Types

Quest supports a Rust-inspired type system with structs and traits:

**Type Declaration** (lines 531-745 in main.rs):
```quest
type Person
    str: name        # Required typed field
    num?: age        # Optional field (defaults to nil)
    str?: email

    # Instance method (has access to self)
    fun greet()
        "Hello, " .. self.name
    end

    # Static method (no self access)
    static fun default()
        Person.new(name: "Unknown", age: 0)
    end
end
```

**Constructor Calls**:
- Positional: `Person.new("Alice", 30)`
- Named: `Person.new(name: "Alice", age: 30)` (order independent)
- Mixed optional: `Person.new(name: "Bob")` (age and email become nil)

**Type Components** (types.rs lines 1578-1818):
- `QType`: Type definition with fields, methods, static_methods, implemented_traits
- `FieldDef`: Field with name, type_annotation (`num`, `str`, `bool`, etc.), optional flag
- `QStruct`: Instance with type_name, type_id, fields HashMap, unique id

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
        "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
        _ => Err(format!("Unknown method"))
    }
}
```

Documentation for methods stored in `get_method_doc(parent_type, method_name)` - used when creating `QFun` objects.

### Variables and Scoping

- **Declaration**: Requires `let` keyword: `let x = 5`
- **Assignment**: Only works on existing variables: `x = 10`
- **Scope**: Single global HashMap in REPL, passed through all evaluation functions
- **Error handling**: Attempting `x = 5` without prior `let x` gives clear error message

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

- **Built-in Types**: Num (integers and floats), Bool, Str, Nil, Fun (method references), UserFun, Module, Array, Dict
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
  - Num: plus, minus, times, div, mod, comparison methods, _id
  - Str: 30+ methods including len, concat, upper, lower, capitalize, title, trim, is* checks, encode, etc.
  - Bool: eq, neq, _id
  - Fun: _doc, _str, _rep, _id
  - Array: 34 methods including map, filter, each, reduce, push, pop, etc.
  - Dict: Full CRUD operations, each, keys, values, etc.
  - Struct: Field access, method calls
  - Type: Constructor (.new), static methods
- **Control flow**: if/elif/else blocks, inline if expressions, while loops, for..in loops with ranges
- **Variables**: let declaration, assignment, compound assignment (+=, -=, etc.), scoping
- **Functions**: Named functions, lambdas, closures, user-defined functions
- **Modules**: Import system with `use`, module member access
- **Built-in functions**: puts(), print(), len(), and many module functions
- **Standard Library Modules**:
  - `std/math`: Trigonometric functions (sin, cos, tan, asin, acos, atan), constants (pi, tau)
  - `std/json`: JSON parsing (parse, stringify) with pretty-printing support
  - `std/hash`: Cryptographic hashing (md5, sha1, sha256, sha512, crc32, bcrypt, hmac_sha256, hmac_sha512)
  - `std/b64`: Base64 encoding/decoding (encode, decode, encode_url, decode_url)
  - `std/crypto`: HMAC operations (hmac_sha256, hmac_sha512)
  - `std/io`: File operations:
    - `io.read(path)` - Read entire file as string
    - `io.write(path, content)` - Write string to file (overwrites)
    - `io.append(path, content)` - Append string to file
    - `io.remove(path)` - Remove file or directory
    - `io.exists(path)` - Check if file/directory exists (returns bool)
    - `io.size(path)` - Get file size in bytes (returns num)
    - `io.glob(pattern)` - Find files matching glob pattern (returns array)
    - `io.glob_match(path, pattern)` - Check if path matches glob pattern (returns bool)
  - `std/term`: Terminal styling (colors, formatting)
  - `std/test`: Testing framework (module, describe, it, assert_eq)

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
2. **Float handling**: `QNum` stores f64 but displays as integer when `fract() == 0.0 && abs() < 1e10`
3. **Nil suppression**: REPL doesn't print `QValue::Nil` results (statements return nil)
4. **Grammar ordering**: In `quest.pest`, statement alternatives must have `let_statement` before `assignment` (both start with identifier)
5. **Span checking**: For method call detection, check original source string via `pair.as_str()` since Pest doesn't expose parentheses as separate tokens

## Documentation Structure

- `docs/obj.md` - Object system specification
- `docs/string.md` - String method specifications
- `docs/types.md` - Type system documentation
- `docs/control_flow.md` - Control flow structures
- Other docs are specs for unimplemented features

## Other
quest code files end in .q extension
do not comment out or skip tests just to get tests passing. 


