# QEP-015: Type Annotations and Enforcement

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** QEP-007 (Set Type)

## Abstract

This QEP introduces optional type annotations for variables and functions with runtime type checking enforcement. Unlike most scripting languages, Quest will enforce type annotations on assignment and function calls, catching type errors early while maintaining backwards compatibility with unannotated code.

## Rationale

Quest currently supports:
- ✅ Type annotations on struct fields (enforced at construction)
- ❌ No type annotations on variables
- ❌ No type annotations on function parameters
- ❌ No type checking on assignment or function calls

**Problems this causes:**
1. **Late error detection** - Type mismatches only discovered deep in execution
2. **Unclear APIs** - Function signatures don't show expected types
3. **Refactoring risks** - No safety net when changing code
4. **IDE limitations** - Can't provide accurate autocomplete

**Design goal:** Make Quest **strictest among scripting languages** for type safety while maintaining flexibility where needed.

## Design Philosophy

### 1. Gradual Typing

**Unannotated code works as before** (fully dynamic):
```quest
fun add(a, b)
    a + b  # No type checking
end
```

**Annotated code is strictly enforced**:
```quest
fun add(a: int, b: int) -> int
    a + b  # Type checked at call time
end

add(1, 2)      # ✓ OK
add(1.5, 2)    # ✗ Error: Expected int, got float
```

### 2. Assignment Enforcement

Once a variable has a type (explicit or inferred), **assignments are type-checked**:

```quest
# Explicit type annotation
let name: str = "Alice"
name = "Bob"          # ✓ OK (str)
name = 42             # ✗ Error: Cannot assign int to str variable

# Inferred from annotation
let count: int = 0
count = count + 1     # ✓ OK (int)
count = "text"        # ✗ Error: Cannot assign str to int variable

# No annotation = fully dynamic (current behavior)
let x = 5
x = "text"            # ✓ OK (no type constraint)
```

### 3. Strictness Level

Quest will be **stricter than Python/Ruby/JavaScript**:

| Language | Variable Types | Function Types | Assignment Check |
|----------|----------------|----------------|------------------|
| Python | Hints (ignored) | Hints (ignored) | No |
| Ruby | None | None | No |
| JavaScript | None | None | No |
| TypeScript | Required | Required | Yes (compile-time) |
| **Quest** | **Optional + Enforced** | **Optional + Enforced** | **Yes (runtime)** |

## Syntax

### Variable Type Annotations

```quest
# Explicit type annotation
let name: str = "Alice"
let age: int = 30
let score: float = 95.5
let data: array = []
let config: dict = {}

# Multiple declarations with types
let x: int = 1, y: int = 2, z: int = 3

# Type annotation without initial value (initialized to nil, checked on first assignment)
let name: str
name = "Alice"  # ✓ OK
name = 42       # ✗ Error

# Optional types (can be nil)
let age: int? = nil
age = 30        # ✓ OK
age = nil       # ✓ OK (optional)
age = "text"    # ✗ Error
```

### Function Type Annotations

```quest
# Parameter types only
fun greet(name: str, age: int)
    "Hello " .. name .. ", age " .. age._str()
end

# With return type
fun add(a: int, b: int) -> int
    a + b
end

# Optional parameters
fun greet(name: str, age: int?)
    if age != nil
        "Hello " .. name .. ", age " .. age._str()
    else
        "Hello " .. name
    end
end

# Mixed: some typed, some not (NOT ALLOWED)
fun bad(a: int, b)  # ✗ Error: All or none must be typed
    a + b
end

# All untyped (current behavior, still allowed)
fun add(a, b)
    a + b  # Fully dynamic
end
```

### Return Type Enforcement

```quest
fun get_name() -> str
    "Alice"  # ✓ OK
end

fun get_age() -> int
    "30"  # ✗ Error: Expected int, got str
end

fun maybe_value() -> int?
    if condition
        42
    else
        nil  # ✓ OK (optional)
    end
end
```

## Type System

### Primitive Types

```quest
int      # 64-bit signed integers
float    # 64-bit floating-point
decimal  # Arbitrary precision decimals
str      # UTF-8 strings
bytes    # Binary data
bool     # true or false
nil      # Nil value
```

### Collection Types

```quest
array           # Array of any type
array<int>      # Array of integers (future)
dict            # Dictionary with any keys/values
dict<str, int>  # Typed dictionary (future)
set             # Set of any type
set<str>        # Set of strings (future)
```

### Special Types

```quest
any      # Accepts any type (opt-out of checking)
nil      # Only nil
int?     # int or nil (optional)
str?     # str or nil (optional)
```

### User-Defined Types

```quest
type Person
    str: name
    int: age
end

fun process(p: Person) -> str
    p.name
end
```

### Type Checking Rules

**Exact match required** (no coercion):
```quest
fun needs_int(x: int)
    x + 1
end

needs_int(42)     # ✓ OK
needs_int(42.0)   # ✗ Error: Expected int, got float
```

**Optional types**:
```quest
fun maybe(x: int?)
    if x != nil
        x + 1
    else
        0
    end
end

maybe(42)    # ✓ OK
maybe(nil)   # ✓ OK
maybe("x")   # ✗ Error
```

**Any type (escape hatch)**:
```quest
fun flexible(x: any) -> any
    x._str()  # Works with anything
end

flexible(42)      # ✓ OK
flexible("text")  # ✓ OK
flexible([1, 2])  # ✓ OK
```

## Implementation Strategy

### Phase 1: Grammar Extensions

```pest
// Variable type annotation
let_statement = {
    "let" ~ typed_var ~ ("=" ~ expression)? ~ ("," ~ typed_var ~ ("=" ~ expression)?)*
}

typed_var = { identifier ~ (":" ~ type_expr)? }

// Function type annotations
function_declaration = {
    "fun" ~ identifier ~ "(" ~ typed_params? ~ ")" ~ ("->" ~ type_expr)? ~ statement* ~ "end"
}

typed_params = {
    typed_param ~ ("," ~ typed_param)*
}

typed_param = { identifier ~ (":" ~ type_expr)? }

// Type expressions
type_expr = {
    type_name ~ "?"                    // Optional: int?
    | type_name ~ "<" ~ type_list ~ ">"  // Generic: array<int> (future)
    | type_name
}

type_name = {
    "int" | "float" | "decimal" | "str" | "bytes" | "bool" | "nil" | "any"
    | "array" | "dict" | "set"
    | identifier  // User-defined types
}

type_list = { type_expr ~ ("," ~ type_expr)* }
```

### Phase 2: Runtime Type Checking

```rust
// In eval_pair for let_statement
if let Some(type_annotation) = var.type_annotation {
    let value_type = value.q_type();

    if !type_matches(&value_type, &type_annotation, value.is_nil()) {
        return Err(format!(
            "Type mismatch: Cannot assign {} to variable '{}' of type {}",
            value_type, var_name, type_annotation
        ));
    }

    // Store type constraint with variable
    scope.declare_with_type(var_name, value, type_annotation)?;
}
```

```rust
// In assignment
if let Some(var_type) = scope.get_variable_type(var_name) {
    let value_type = value.q_type();

    if !type_matches(&value_type, &var_type, value.is_nil()) {
        return Err(format!(
            "Type mismatch: Cannot assign {} to variable '{}' of type {}",
            value_type, var_name, var_type
        ));
    }
}
```

```rust
// In function call
if let Some(param_types) = function.param_types {
    for (i, (arg, expected_type)) in args.iter().zip(param_types.iter()).enumerate() {
        let arg_type = arg.q_type();

        if !type_matches(&arg_type, expected_type, arg.is_nil()) {
            return Err(format!(
                "Type mismatch: Argument {} expected {}, got {}",
                i + 1, expected_type, arg_type
            ));
        }
    }
}

// Check return type
if let Some(return_type) = function.return_type {
    let actual_type = return_value.q_type();

    if !type_matches(&actual_type, &return_type, return_value.is_nil()) {
        return Err(format!(
            "Return type mismatch: Expected {}, got {}",
            return_type, actual_type
        ));
    }
}
```

### Phase 3: Scope Enhancements

Scope needs to track variable types:

```rust
pub struct Scope {
    variables: HashMap<String, QValue>,
    variable_types: HashMap<String, TypeConstraint>,  // NEW
    // ... existing fields
}

pub struct TypeConstraint {
    type_name: String,
    is_optional: bool,  // int? vs int
    generic_params: Vec<TypeConstraint>,  // array<int> (future)
}

impl Scope {
    pub fn declare_with_type(
        &mut self,
        name: String,
        value: QValue,
        type_constraint: TypeConstraint
    ) -> Result<(), String> {
        self.variables.insert(name.clone(), value);
        self.variable_types.insert(name, type_constraint);
        Ok(())
    }

    pub fn get_variable_type(&self, name: &str) -> Option<&TypeConstraint> {
        self.variable_types.get(name)
    }
}
```

## Complete Examples

### Example 1: Basic Type Safety

```quest
# Variable annotations
let name: str = "Alice"
let age: int = 30
let score: float = 95.5

# These work
name = "Bob"
age = 31
score = 96.0

# These fail at runtime
name = 42           # ✗ Error: Cannot assign int to str variable
age = "thirty"      # ✗ Error: Cannot assign str to int variable
score = "high"      # ✗ Error: Cannot assign str to float variable
```

### Example 2: Function Type Checking

```quest
fun calculate_total(price: float, quantity: int) -> float
    price * quantity.to_f64()
end

# Valid calls
let total = calculate_total(19.99, 3)  # ✓ OK

# Invalid calls
calculate_total("19.99", 3)     # ✗ Error: Argument 1 expected float, got str
calculate_total(19.99, "three") # ✗ Error: Argument 2 expected int, got str

# Return type checked
fun broken() -> int
    "not an int"  # ✗ Error: Expected int, got str
end
```

### Example 3: Optional Types

```quest
fun find_user(id: int) -> Person?
    # May return Person or nil
    if user_exists(id)
        load_user(id)
    else
        nil
    end
end

let user: Person? = find_user(123)

if user != nil
    puts(user.name)
end
```

### Example 4: Working with Collections

```quest
fun process_names(names: array) -> int
    names.len()
end

# Future: Generic types
fun sum_numbers(numbers: array<int>) -> int
    let total: int = 0
    numbers.each(fun (n: int)
        total = total + n
    end)
    total
end
```

### Example 5: User-Defined Types

```quest
type Point
    float: x
    float: y
end

fun distance(p1: Point, p2: Point) -> float
    let dx = p2.x - p1.x
    let dy = p2.y - p1.y
    math.sqrt(dx * dx + dy * dy)
end

let origin = Point.new(x: 0.0, y: 0.0)
let point = Point.new(x: 3.0, y: 4.0)

distance(origin, point)  # ✓ OK: 5.0
distance(origin, "text") # ✗ Error: Expected Point, got str
```

### Example 6: Mixed Typed and Untyped

```quest
# Typed function
fun strict_add(a: int, b: int) -> int
    a + b
end

# Untyped function (fully dynamic)
fun flexible_add(a, b)
    a + b
end

strict_add(1, 2)        # ✓ OK
strict_add(1.0, 2.0)    # ✗ Error

flexible_add(1, 2)      # ✓ OK
flexible_add(1.0, 2.0)  # ✓ OK
flexible_add("a", "b")  # ✓ OK
```

### Example 7: Type Inference on Let

```quest
# No type annotation = no constraint (dynamic)
let x = 5
x = "text"   # ✓ OK (no type declared)

# With annotation = strict
let y: int = 5
y = 10       # ✓ OK (int)
y = "text"   # ✗ Error (type mismatch)

# Type annotation without initializer
let count: int
count = 42   # ✓ OK (first assignment)
count = "x"  # ✗ Error (subsequent assignments checked)
```

## Type Matching Rules

### Exact Match Required

No implicit coercion:

```quest
let x: int = 42
x = 42.0        # ✗ Error: float is not int
x = true        # ✗ Error: bool is not int

let s: str = "hello"
s = 123         # ✗ Error: int is not str
```

### Optional Types

`type?` accepts `type` or `nil`:

```quest
let age: int? = nil
age = 30        # ✓ OK (int matches int?)
age = nil       # ✓ OK (nil matches int?)
age = "text"    # ✗ Error (str doesn't match int?)
```

### Any Type

`any` accepts everything (escape hatch):

```quest
let x: any = 42
x = "text"      # ✓ OK
x = []          # ✓ OK
x = nil         # ✓ OK
```

### Nil Type

`nil` type only accepts nil:

```quest
let nothing: nil = nil
nothing = 42    # ✗ Error: Only nil allowed
```

## Function All-or-Nothing Rule

**Functions must be fully typed or fully untyped:**

```quest
# ✓ OK: All typed
fun add(a: int, b: int) -> int
    a + b
end

# ✓ OK: All untyped
fun add(a, b)
    a + b
end

# ✗ ERROR: Mixed typing not allowed
fun bad(a: int, b)  # Error: Either all parameters typed or none
    a + b
end

# ✗ ERROR: Return type requires parameter types
fun bad(a, b) -> int  # Error: Can't annotate return without parameters
    a + b
end
```

**Rationale:** Prevents confusion and enforces clear intent. Either a function is type-safe (fully annotated) or fully dynamic (no annotations).

## Type Checking Algorithm

```rust
fn type_matches(
    actual: &str,
    expected: &TypeConstraint,
    is_nil_value: bool
) -> bool {
    // Handle optional types
    if expected.is_optional {
        if is_nil_value {
            return true;  // nil is always ok for optional types
        }
    } else {
        if is_nil_value {
            return false;  // nil not allowed for non-optional types
        }
    }

    // Handle 'any' type
    if expected.type_name == "any" {
        return true;
    }

    // Handle 'nil' type
    if expected.type_name == "nil" {
        return is_nil_value;
    }

    // Exact type match required
    actual == expected.type_name
}
```

## Error Messages

**Variable assignment:**
```
Error: Type mismatch: Cannot assign float to variable 'count' of type int
  at line 15: count = 3.14
  Variable 'count' was declared with type int at line 10
```

**Function call:**
```
Error: Type mismatch in call to 'add'
  Argument 1: Expected int, got str
  at line 20: add("1", 2)
  Function 'add' declared at line 5
```

**Return type:**
```
Error: Return type mismatch in function 'get_name'
  Expected str, got int
  at line 12: return 42
  Function declared with return type str at line 8
```

## Backwards Compatibility

**All existing Quest code continues to work:**

```quest
# Existing untyped code (no changes needed)
let x = 5
fun add(a, b)
    a + b
end

# Can gradually add types
let y: int = 10
fun typed_add(a: int, b: int) -> int
    a + b
end
```

## Integration with Existing Features

### Struct Fields (Already Typed)

```quest
type Person
    str: name      # Already enforced at construction
    int: age
end

# Function can reference struct types
fun greet(p: Person) -> str
    "Hello " .. p.name
end
```

### Type Literals

```quest
# Check if type annotation matches type literal
fun get_type() -> Type
    Person  # Returns the type itself
end
```

### Trait Types (Future)

```quest
trait Drawable
    fun draw()
end

# Function accepts any type implementing Drawable
fun render(obj: Drawable)
    obj.draw()
end
```

## Performance Considerations

**Type checking overhead:**
- Variable assignment: 1 HashMap lookup + type string comparison
- Function call: N comparisons (N = parameter count)
- Return: 1 comparison

**Mitigation:**
- Checks only run on annotated code
- Unannotated code has zero overhead
- Type information stored efficiently (strings, not objects)

**Future optimization:**
- Cache type check results
- JIT compilation based on type info
- Inline type checks

## Migration Path

### Step 1: Add Types Incrementally

```quest
# Start with critical functions
fun parse_config(path: str) -> dict
    # ...
end

# Leave helpers untyped for now
fun internal_helper(x, y)
    x + y
end
```

### Step 2: Type Your APIs

```quest
# Public API functions should be typed
pub fun connect(host: str, port: int) -> Connection
    # ...
end

# Internal implementation can be dynamic
fun retry_connect(cfg)
    # ...
end
```

### Step 3: Enable Strict Mode (Future QEP)

```quest
"use strict types"  # File-level pragma

# Now all functions must be typed
fun add(a, b)  # ✗ Error: Must add type annotations in strict mode
    a + b
end
```

## Testing Type Annotations

```quest
use "std/test"

test.describe("Type checking", fun ()
    test.it("enforces variable type on assignment", fun ()
        let x: int = 5

        test.assert_raises("Type mismatch", fun ()
            x = "text"
        end, "Should reject str assignment to int variable")
    end)

    test.it("enforces function parameter types", fun ()
        fun strict(x: int)
            x + 1
        end

        test.assert_raises("Type mismatch", fun ()
            strict("not int")
        end, "Should reject wrong argument type")
    end)

    test.it("enforces return types", fun ()
        test.assert_raises("Return type mismatch", fun ()
            fun bad() -> int
                "not int"
            end
            bad()
        end, "Should reject wrong return type")
    end)
end)
```

## Error Handling

### Type Error Exception

```quest
try
    let x: int = "text"
catch e
    puts(e.type())    # "TypeError"
    puts(e.message())     # "Cannot assign str to int variable 'x'"
    puts(e.line())        # Line number
    puts(e.file())        # File path
end
```

## Named Arguments + Type Annotations

Type annotations and named arguments work beautifully together - they're complementary, not redundant.

### Clean Call Sites

```quest
# Function definition has types (documentation + enforcement)
fun create_user(name: str, email: str, age: int, active: bool) -> User
    User.new(name: name, email: email, age: age, active: active)
end

# Call site stays clean (named arguments provide clarity)
let user = create_user(
    name: "Alice",
    email: "alice@example.com",
    age: 30,
    active: true
)
```

**Benefits:**
- ✅ Function signature is self-documenting (types show what's expected)
- ✅ Call site is readable (names show what each value means)
- ✅ Types are enforced (wrong types caught immediately)
- ✅ No redundancy (types only in definition, not at call site)

### Comparison with Other Approaches

**❌ Bad: Types at call site (redundant)**
```quest
// Don't do this - hypothetical bad design
create_user(
    name: "Alice": str,     // Redundant and verbose
    email: "alice@example.com": str,
    age: 30: int,
    active: true: bool
)
```

**✅ Good: Types in definition only (Quest's approach)**
```quest
fun create_user(name: str, email: str, age: int, active: bool) -> User
    # ...
end

create_user(name: "Alice", email: "alice@example.com", age: 30, active: true)
```

### Type Checking with Named Arguments

**Positional calls:**
```quest
fun greet(name: str, age: int) -> str
    "Hello " .. name
end

greet("Alice", 30)  # ✓ OK - positional, types checked by position
greet(30, "Alice")  # ✗ Error: Argument 1 expected str, got int
```

**Named calls:**
```quest
greet(name: "Alice", age: 30)  # ✓ OK - named, types checked by name
greet(age: 30, name: "Alice")  # ✓ OK - order doesn't matter with names
greet(name: 42, age: 30)       # ✗ Error: Parameter 'name' expected str, got int
```

### Optional Parameters with Types

```quest
fun connect(host: str, port: int, timeout: int?) -> Connection
    # timeout can be nil
end

# All these work
connect(host: "localhost", port: 8080, timeout: 30)
connect(host: "localhost", port: 8080, timeout: nil)
connect(host: "localhost", port: 8080)  # timeout defaults to nil

# These fail
connect(host: "localhost", port: 8080, timeout: "30s")  # ✗ Error: Expected int?, got str
```

### Configuration Objects

Named arguments + types = perfect for configuration:

```quest
fun start_server(
    host: str,
    port: int,
    workers: int,
    timeout: int?,
    ssl_cert: str?,
    ssl_key: str?,
    debug: bool
) -> Server
    # Type-safe configuration
end

# Crystal clear call site
let server = start_server(
    host: "0.0.0.0",
    port: 8080,
    workers: 4,
    timeout: 30,
    ssl_cert: "/etc/ssl/cert.pem",
    ssl_key: "/etc/ssl/key.pem",
    debug: false
)
```

**Advantages:**
1. Function signature documents all options and their types
2. Call site is self-documenting (no need to look up parameter order)
3. Type checker ensures all values are correct types
4. Optional types (`?`) make optional parameters explicit

### Builder Pattern

Type annotations enhance the builder pattern:

```quest
type ServerBuilder
    str?: host
    int?: port
    bool: debug

    static fun new() -> ServerBuilder
        ServerBuilder.new(host: nil, port: nil, debug: false)
    end

    fun with_host(h: str) -> ServerBuilder
        self.host = h
        self
    end

    fun with_port(p: int) -> ServerBuilder
        self.port = p
        self
    end

    fun build() -> Server
        if self.host == nil or self.port == nil
            raise "Host and port required"
        end
        Server.new(host: self.host, port: self.port, debug: self.debug)
    end
end

# Type-safe builder chain
let server = ServerBuilder.new()
    .with_host("localhost")
    .with_port(8080)
    .build()
```

### Error Messages with Named Arguments

```quest
fun create_user(name: str, email: str, age: int) -> User
    # ...
end

create_user(name: "Alice", email: "alice@example.com", age: "thirty")
```

**Error:**
```
Error: Type mismatch in call to 'create_user'
  Parameter 'age': Expected int, got str
  at line 42: age: "thirty"
  Function 'create_user' declared at line 5
```

Clear, actionable error message pointing to exactly which parameter is wrong.

## Examples by Use Case

### Use Case 1: API Development

```quest
# Clear contract for API users
pub fun create_user(name: str, email: str, age: int) -> User
    User.new(name: name, email: email, age: age)
end

# Self-documenting and enforced
```

### Use Case 2: Data Processing Pipeline

```quest
fun load_csv(path: str) -> array
    # ...
end

fun filter_valid(rows: array) -> array
    # ...
end

fun save_results(data: array, output: str) -> nil
    # ...
end

# Type-safe pipeline
let data = load_csv("input.csv")
let valid = filter_valid(data)
save_results(valid, "output.csv")
```

### Use Case 3: Configuration

```quest
type Config
    str: host
    int: port
    int?: timeout
end

fun load_config(path: str) -> Config
    let data = json.parse(io.read(path))
    Config.new(
        host: data["host"],
        port: data["port"],
        timeout: data.get("timeout")
    )
end

# Config structure is enforced
let cfg: Config = load_config("app.json")
connect(cfg.host, cfg.port)  # Type-safe
```

### Use Case 4: Numerical Computing

```quest
fun matrix_multiply(a: array, b: array) -> array
    # Type ensures inputs are arrays
    # (Future: array<array<float>> for full type safety)
end

fun calculate_mean(values: array) -> float
    let sum: float = 0.0
    values.each(fun (v)
        sum = sum + v.to_f64()
    end)
    sum / values.len().to_f64()
end
```

## Implementation Checklist

### Grammar (quest.pest)
- [ ] Add `type_expr` rule for type annotations
- [ ] Add optional type annotations to `let_statement`
- [ ] Add optional type annotations to function parameters
- [ ] Add optional return type annotation to functions
- [ ] Add `?` suffix for optional types
- [ ] Add generic type syntax `type<param>` (future phase)

### Type System (types.rs or new types/type_checker.rs)
- [ ] `TypeConstraint` struct (type name, optional flag, generics)
- [ ] `type_matches()` function
- [ ] Type constraint parsing from grammar
- [ ] Type name validation

### Scope (scope.rs)
- [ ] Add `variable_types: HashMap<String, TypeConstraint>`
- [ ] `declare_with_type()` method
- [ ] `get_variable_type()` method
- [ ] Store function type signatures

### Evaluator (main.rs)
- [ ] Parse type annotations in let_statement
- [ ] Check type on variable assignment
- [ ] Parse function type annotations
- [ ] Check parameter types on function call
- [ ] Check return type on function return
- [ ] Enforce all-or-nothing rule for function annotations

### Error Handling
- [ ] Add TypeError exception type
- [ ] Rich error messages with line numbers
- [ ] Show declaration location in errors

### Testing
- [ ] `test/types/annotations_test.q` - Variable annotations
- [ ] `test/types/function_annotations_test.q` - Function annotations
- [ ] `test/types/optional_types_test.q` - Optional (?) types
- [ ] `test/types/type_errors_test.q` - Error cases
- [ ] `test/types/mixed_typed_test.q` - Typed + untyped code

### Documentation
- [ ] Update CLAUDE.md with type annotation syntax
- [ ] Create `docs/docs/language/type-annotations.md`
- [ ] Add examples to stdlib modules
- [ ] Migration guide for existing code


**Runtime enforcement** makes Quest unique:
- Safer than Python (enforced)
- More flexible than TypeScript (no compilation needed)
- Gradual adoption (optional annotations)
- REPL-friendly (immediate feedback)

## Open Questions

1. **Type inference on let?**
   ```quest
   let x: int = 42  # Explicit
   let y = 42       # Infer as int? Or stay dynamic?
   ```
   **Recommendation:** Stay dynamic unless annotated (explicit opt-in)

2. **Structural vs nominal typing?**
   ```quest
   type Point { float: x, float: y }
   type Vector { float: x, float: y }
   # Should Point be assignable to Vector parameter?
   ```
   **Recommendation:** Nominal (types must match by name)

3. **Method type annotations?**
   ```quest
   type Person
       fun greet(other: Person) -> str  # Types on methods?
   ```
   **Recommendation:** Yes, same rules as functions

## Conclusion

Type annotations make Quest the **strictest scripting language** for type safety while maintaining:
- ✅ Backwards compatibility (optional annotations)
- ✅ REPL friendliness (runtime checking)
- ✅ Gradual adoption (add types incrementally)
- ✅ Clear errors (caught early with good messages)

This positions Quest uniquely:
- **More type-safe than:** Python, Ruby, JavaScript, Lua
- **More flexible than:** TypeScript, Rust (no compilation needed)
- **Similar to:** Typed Racket, Sorbet (Ruby), mypy strict mode

**Next steps:** Implement Phase 1 (grammar + basic enforcement) and gather feedback before adding advanced features.

## References

- Python Type Hints: https://peps.python.org/pep-0484/
- TypeScript Handbook: https://www.typescriptlang.org/docs/handbook/
- Typed Racket: https://docs.racket-lang.org/ts-guide/
- Crystal Language: https://crystal-lang.org/reference/syntax_and_semantics/type_annotations.html
