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

All values are wrapped in `QValue` enum:
- `QValue::Num(QNum)` - Numbers (f64 internally, displays as int when appropriate)
- `QValue::Bool(QBool)` - Booleans
- `QValue::Str(QString)` - Strings
- `QValue::Nil(QNil)` - Nil/null value (singleton with ID 0)
- `QValue::Fun(QFun)` - Function/method references

Each type struct contains:
- Its value data
- `id: u64` - Unique object ID (from atomic counter `NEXT_ID`)

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

- **Types**: Num (integers and floats), Bool, Str, Nil, Fun (method references)
- **Operators**: All arithmetic, comparison, logical (`and`, `or`, `not`), bitwise operations
- **Methods**:
  - Num: plus, minus, times, div, mod, comparison methods, _id
  - Str: len, concat, upper, lower, capitalize, title, trim, ltrim, rtrim, is* checks, count, startswith, endswith, _id
  - Bool: eq, neq, _id
  - Fun: _doc, _str, _rep, _id
- **Control flow**: if/elif/else blocks, inline if expressions
- **Variables**: let declaration, assignment, lookup
- **Built-in functions**: puts(), print()

## Grammar vs Implementation Gap

The grammar in `quest.pest` is more complete than the implementation:
- Grammar has: function declarations, type declarations, impl blocks, iteration, lambdas
- Implementation has: Only basic expressions, if statements, let/assignment
- When adding features, grammar rules likely already exist

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


