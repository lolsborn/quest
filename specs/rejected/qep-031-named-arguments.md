# QEP-031: Named Arguments for Functions

**Status:** ❌ REJECTED - Superseded by QEP-035
**Author:** Quest Language Team
**Created:** 2025-10-06
**Rejected:** 2025-10-06
**Superseded By:** [QEP-035: Named Arguments v2](qep-035-named-arguments.md)
**Rejection Reason:** QEP-032 changed struct field syntax from `type: name` to `name: type`. This QEP was written before that decision and shows struct constructors using the old field syntax while proposing functions use the new syntax. QEP-035 is a clean version with consistent `name: type` syntax throughout.
**Related:** QEP-029 (Default Parameters), QEP-030 (Variadic Parameters), QEP-015 (Type Annotations), QEP-032 (Struct Field Syntax)

## Abstract

This QEP extends **named argument** support from struct constructors to all function calls. Named arguments improve code readability, allow skipping optional parameters, and enable argument reordering at call sites.

## Motivation

### Current State

Quest already supports named arguments for **struct constructors only**:

```quest
type Person
    str: name
    int: age
end

# ✓ Works - named args for constructor
let p = Person.new(name: "Alice", age: 30)
let q = Person.new(age: 30, name: "Alice")  # Order doesn't matter
```

**But NOT for regular functions:**

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

# ✗ Doesn't work
greet(name: "Alice", greeting: "Hello")  # Parse error or ignored

# Must use positional
greet("Alice", "Hello")  # Which order? Hard to remember
```

### Problems This Causes

1. **Poor readability** - Unclear what arguments mean
   ```quest
   connect("localhost", 8080, 30, false, true, 100)
   # What do these numbers/bools mean? Must check function signature
   ```

2. **Argument order errors** - Easy to swap parameters
   ```quest
   fun resize(image, width, height)
   resize(img, 300, 400)  # Is it width, height or height, width?
   ```

3. **Can't skip optional parameters** - Must provide all or none
   ```quest
   fun connect(host, port = 8080, timeout = 30, debug = false)
   connect("localhost", 8080, 30, true)  # Want debug but not timeout
   # Can't skip timeout to get to debug
   ```

4. **Inconsistent DX** - Works for constructors but not functions
   ```quest
   Person.new(name: "Alice", age: 30)  # ✓ Clear
   greet("Alice", "Hello")              # Unclear which is which
   ```

### Solution: Named Arguments for All Functions

```quest
fun connect(host, port = 8080, timeout = 30, debug = false)
    # Implementation
end

# Clear, self-documenting calls
connect(host: "localhost", port: 3000)
connect(host: "localhost", debug: true)  # Skip port and timeout
connect(host: "localhost", timeout: 60, debug: true)  # Skip port

# Can reorder
connect(debug: true, host: "localhost")

# Mix positional and named
connect("localhost", debug: true)  # First positional, rest named
```

## Design Principles

### 1. Backward Compatible

All existing positional calls continue to work:

```quest
fun add(x, y)
    x + y
end

add(5, 3)                # ✓ Still works (positional)
add(x: 5, y: 3)          # ✓ Now also works (named)
add(y: 3, x: 5)          # ✓ Reordered (named)
add(5, y: 3)             # ✓ Mixed
```

### 2. Names Match Parameters

Argument names must **exactly match** parameter names:

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

greet(name: "Alice", greeting: "Hi")    # ✓ OK
greet(n: "Alice", g: "Hi")              # ✗ Error: unknown params n, g
greet(NAME: "Alice", greeting: "Hi")    # ✗ Error: unknown param NAME
```

### 3. Positional Before Named

Once you use a named argument, remaining arguments must also be named:

```quest
fun f(a, b, c, d)
    # ...
end

# ✓ Valid
f(1, 2, 3, 4)              # All positional
f(a: 1, b: 2, c: 3, d: 4)  # All named
f(1, 2, c: 3, d: 4)        # Positional then named

# ✗ Invalid
f(a: 1, 2, 3, 4)           # Positional after named
f(1, b: 2, 3, d: 4)        # Positional after named
```

**Rationale:** Prevents ambiguity about which positional slot to fill.

### 4. No Duplicate Bindings

Can't specify the same parameter twice:

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

# ✗ Error
greet("Alice", name: "Bob")
# Parameter 'name' specified both positionally and by keyword
```

### 5. Integration with Defaults

Named arguments shine with default parameters:

```quest
fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
    # ...
end

# Skip middle parameters easily
connect("localhost", ssl: true)         # Use defaults for port, timeout
connect("localhost", debug: true)       # Use defaults for port, timeout, ssl
connect("localhost", timeout: 60, ssl: true)  # Use default for port
```

## Specification

### Syntax

```quest
# All positional
function_call(value1, value2, value3)

# All named
function_call(param1: value1, param2: value2, param3: value3)

# Mixed (positional first)
function_call(value1, param2: value2, param3: value3)

# Named allows reordering
function_call(param3: value3, param1: value1, param2: value2)
```

### Named Arguments vs Type Annotations: Colon Disambiguation

**Important:** Quest uses colons (`:`) in two different contexts, which can be confusing at first.

#### 1. Function Declaration - Type Annotations

In function **declarations**, colons indicate type annotations with **`type: name`** syntax:

```quest
fun connect(str: host, int: port, bool: ssl)
    # ^^^^^ ^^^^  ^^^^ ^^^^  ^^^^^ ^^^
    # type  name  type name  type  name
    # host, port, ssl are the parameter names
end
```

This matches Quest's field declaration syntax in types:

```quest
type Config
    str: host    # type: field_name
    int: port
end
```

#### 2. Function Call - Named Arguments

In function **calls**, colons indicate named arguments with **`name: value`** syntax:

```quest
connect(host: "localhost", port: 8080, ssl: true)
    # ^^^^  ^^^^^^^^^^^  ^^^^  ^^^^  ^^^  ^^^^
    # name  value        name  value name value
```

#### Context Disambiguates

The parser distinguishes these based on context:
- **In parameter lists** (declarations): `type: identifier` → type annotation
- **In argument lists** (calls): `identifier: expression` → named argument

#### Complete Example

```quest
# Declaration: type: name syntax
fun create_server(
    str: host,              # Type annotation: str type, host name
    int: port = 8080,       # Type annotation with default
    bool: ssl = false       # Type annotation with default
) -> Server
    Server.new(host: host, port: port, ssl: ssl)
    # ^^^ In call ^^^: name: value syntax for constructor
end

# Call: name: value syntax
create_server(host: "localhost", ssl: true)
    # parameter_name: argument_value
```

#### Quick Reference

| Context | Syntax | Example | Meaning |
|---------|--------|---------|---------|
| Declaration | `type: name` | `int: x` | Parameter x has type int |
| Call | `name: value` | `x: 42` | Pass 42 to parameter x |
| Type field | `type: name` | `str: host` | Field host has type str |
| Dict literal | `key: value` | `{x: 1}` | Dict entry with key x |

### Grammar (Already Exists!)

The grammar already supports named arguments (used for constructors):

```pest
argument_list = {
    named_arg ~ ("," ~ named_arg)*      // All named: name: "Alice", age: 30
    | (named_arg | expression) ~ ("," ~ (named_arg | expression))*  // Mixed
}

named_arg = { identifier ~ ":" ~ expression }
```

**Current limitation:** Named args only processed in `Type.new()` calls, not regular functions.

### Evaluation Algorithm

```rust
pub struct CallArguments {
    pub positional: Vec<QValue>,
    pub keyword: HashMap<String, QValue>,
}

fn parse_call_arguments(
    args_pair: Pair<Rule>,
    scope: &mut Scope
) -> Result<CallArguments, String> {
    let mut positional = Vec::new();
    let mut keyword = HashMap::new();
    let mut seen_named = false;

    for arg in args_pair.into_inner() {
        match arg.as_rule() {
            Rule::expression => {
                if seen_named {
                    return Err(
                        "Positional argument cannot follow keyword argument".to_string()
                    );
                }
                positional.push(eval_pair(arg, scope)?);
            }
            Rule::named_arg => {
                seen_named = true;
                let mut inner = arg.into_inner();
                let name = inner.next().unwrap().as_str().to_string();
                let value = eval_pair(inner.next().unwrap(), scope)?;

                if keyword.contains_key(&name) {
                    return Err(format!("Duplicate keyword argument '{}'", name));
                }

                keyword.insert(name, value);
            }
            Rule::unpack_args => {
                // Handle *args unpacking (QEP-030)
                if seen_named {
                    return Err(
                        "Positional unpacking (*args) cannot follow keyword argument".to_string()
                    );
                }
                let expr = arg.into_inner().next().unwrap();
                let value = eval_pair(expr, scope)?;

                match value {
                    QValue::Array(arr) => positional.extend(arr.elements.clone()),
                    _ => return Err("Can only unpack arrays with *".to_string())
                }
            }
            Rule::unpack_kwargs => {
                // Handle **kwargs unpacking (QEP-030)
                seen_named = true;
                let expr = arg.into_inner().next().unwrap();
                let value = eval_pair(expr, scope)?;

                match value {
                    QValue::Dict(dict) => {
                        for (k, v) in dict.map.iter() {
                            if let QValue::Str(key_str) = k {
                                if keyword.contains_key(&key_str.value) {
                                    return Err(format!(
                                        "Duplicate keyword argument '{}'",
                                        key_str.value
                                    ));
                                }
                                keyword.insert(key_str.value.clone(), v.clone());
                            } else {
                                return Err(format!(
                                    "Dict keys must be strings for ** unpacking, got {}",
                                    k.q_type()
                                ));
                            }
                        }
                    }
                    _ => return Err("Can only unpack dicts with **".to_string())
                }
            }
            _ => {}
        }
    }

    Ok(CallArguments { positional, keyword })
}

pub fn call_user_function(
    user_fun: &QUserFun,
    call_args: CallArguments,
    parent_scope: &mut Scope
) -> Result<QValue, String> {
    let mut func_scope = create_function_scope(user_fun, parent_scope);
    let mut param_index = 0;

    // Phase 1: Bind positional arguments
    for pos_value in call_args.positional.iter() {
        if param_index >= user_fun.params.len() {
            if user_fun.varargs.is_some() {
                break;  // Excess positional go to *args
            } else {
                return Err(format!(
                    "Too many positional arguments: expected {}, got {}",
                    user_fun.params.len(),
                    call_args.positional.len()
                ));
            }
        }

        let param_name = &user_fun.params[param_index];

        // Check if also specified by keyword
        if call_args.keyword.contains_key(param_name) {
            return Err(format!(
                "Parameter '{}' specified both positionally and by keyword",
                param_name
            ));
        }

        // Type check
        if let Some(param_type) = &user_fun.param_types[param_index] {
            check_parameter_type(pos_value, param_type, param_name)?;
        }

        func_scope.declare(param_name, pos_value.clone())?;
        param_index += 1;
    }

    // Phase 2: Bind keyword arguments to remaining parameters
    let mut unmatched_kwargs = call_args.keyword.clone();

    for i in param_index..user_fun.params.len() {
        let param_name = &user_fun.params[i];

        if let Some(kw_value) = unmatched_kwargs.remove(param_name) {
            // Keyword arg provided for this param
            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&kw_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, kw_value)?;
        } else if let Some(default_expr) = &user_fun.param_defaults[i] {
            // Use default value
            let default_value = eval_expression(default_expr, &mut func_scope)?;

            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&default_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, default_value)?;
        } else {
            return Err(format!("Missing required parameter '{}'", param_name));
        }
    }

    // Phase 3: Handle varargs (if any)
    if let Some(varargs_name) = &user_fun.varargs {
        let remaining_positional = call_args.positional[param_index..].to_vec();
        let varargs_array = QValue::Array(QArray::new(remaining_positional));
        func_scope.declare(varargs_name, varargs_array)?;
    }

    // Phase 4: Handle kwargs (if any)
    if let Some(kwargs_name) = &user_fun.kwargs {
        let kwargs_dict = QValue::Dict(QDict::new(unmatched_kwargs));
        func_scope.declare(kwargs_name, kwargs_dict)?;
    } else if !unmatched_kwargs.is_empty() {
        let unknown: Vec<_> = unmatched_kwargs.keys().collect();
        return Err(format!(
            "Unknown keyword arguments: {}",
            unknown.join(", ")
        ));
    }

    // Phase 5: Execute function body
    execute_function_body(&user_fun.body, &mut func_scope)
}
```

## Examples

### Example 1: Basic Named Arguments

```quest
fun greet(greeting, name, punctuation)
    greeting .. ", " .. name .. punctuation
end

# All positional
greet("Hello", "Alice", "!")

# All named
greet(greeting: "Hello", name: "Alice", punctuation: "!")

# Reordered
greet(name: "Alice", punctuation: "!", greeting: "Hello")

# Mixed
greet("Hello", name: "Alice", punctuation: "!")
```

### Example 2: Skipping Optional Parameters

```quest
fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
    puts("Connecting to ", host, ":", port)
    puts("  timeout=", timeout, " ssl=", ssl, " debug=", debug)
end

# Skip middle parameters
connect("localhost", ssl: true)
# Connecting to localhost:8080
#   timeout=30 ssl=true debug=false

connect("localhost", debug: true, ssl: true)
# Connecting to localhost:8080
#   timeout=30 ssl=true debug=true

connect("localhost", 3000, ssl: true)
# Connecting to localhost:3000
#   timeout=30 ssl=true debug=false
```

### Example 3: Self-Documenting API Calls

```quest
fun create_server(
    host: str,
    port: int,
    workers: int = 4,
    timeout: int = 30,
    max_connections: int = 100,
    ssl_cert: str? = nil,
    ssl_key: str? = nil,
    debug: bool = false
) -> Server
    # Implementation
end

# Crystal clear what each value means
let server = create_server(
    host: "0.0.0.0",
    port: 8080,
    workers: 8,
    max_connections: 1000,
    ssl_cert: "/etc/ssl/cert.pem",
    ssl_key: "/etc/ssl/key.pem",
    debug: true
)

# vs unclear positional
let server = create_server("0.0.0.0", 8080, 8, 30, 1000, "/etc/ssl/cert.pem", "/etc/ssl/key.pem", true)
```

### Example 4: Working with Booleans

Boolean arguments especially benefit from names:

```quest
fun resize(image, width, height, keep_aspect = true, crop = false, upscale = false)
    # Implementation
end

# ✗ Unclear
resize(img, 200, 300, true, false, true)  # Which bool is which?

# ✓ Clear
resize(
    image: img,
    width: 200,
    height: 300,
    keep_aspect: false,
    upscale: true
)
```

### Example 5: Mixed Positional and Named

```quest
fun log(level, message, timestamp = now(), source = "app")
    puts("[", timestamp, "] [", level, "] [", source, "] ", message)
end

# Common case: first args positional, then named for options
log("ERROR", "Connection failed", source: "database")
log("INFO", "Server started", timestamp: custom_time, source: "server")

# All positional still works
log("DEBUG", "Processing request", now(), "api")
```

### Example 6: Integration with Varargs

```quest
fun printf(format, *args, **options)
    let result = format
    # ... formatting logic
    if options.contains("color")
        result = colorize(result, options["color"])
    end
    puts(result)
end

# Named options with varargs
printf("User {} logged in at {}", "alice", now(), color: "green")
printf("Count: {}", 42, color: "blue", bold: true)
```

### Example 7: Dict as Keyword Arguments

```quest
fun configure(host, port, timeout)
    # Setup configuration
end

# Can unpack dict as keyword args (QEP-030)
let config = {
    host: "localhost",
    port: 8080,
    timeout: 30
}

configure(**config)  # Equivalent to: configure(host: "localhost", port: 8080, timeout: 30)
```

**Note:** To override specific values from unpacked dicts, see QEP-030 which specifies that later values win:

```quest
# From QEP-030: Last value wins in unpacking
configure(**config, port: 3000)  # port=3000 (overrides config["port"])
configure(port: 3000, **config)  # port=8080 (config overrides explicit)
```

### Example 8: Builder Pattern Alternative

Instead of verbose builders, use named arguments:

```quest
# Instead of builder:
let server = ServerBuilder.new()
    .host("0.0.0.0")
    .port(8080)
    .workers(4)
    .build()

# Use named arguments:
let server = Server.new(
    host: "0.0.0.0",
    port: 8080,
    workers: 4
)
```

### Example 9: Configuration Templates

```quest
fun connect(host, port = 8080, timeout = 30, ssl = false)
    # Implementation
end

# Store common configurations
let default_config = {timeout: 60, ssl: true}
let local_config = {host: "localhost", port: 3000}

# Apply configurations (last value wins per QEP-030)
connect(**default_config, host: "production.com")
# timeout=60, ssl=true, host="production.com" (explicit overrides)

connect(**local_config, **default_config)
# host="localhost", port=3000 (from local_config)
# timeout=60, ssl=true (from default_config, no conflict)
```

## Validation Rules

### 1. Positional Before Named

```quest
fun f(a, b, c)
    a + b + c
end

# ✓ Valid
f(1, 2, 3)              # All positional
f(a: 1, b: 2, c: 3)     # All named
f(1, b: 2, c: 3)        # Positional then named

# ✗ Invalid
f(a: 1, 2, 3)           # Error: Positional after keyword
f(1, b: 2, 3)           # Error: Positional after keyword
```

### 2. No Duplicate Parameters

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

# ✗ Invalid
greet("Alice", name: "Bob")
# Error: Parameter 'name' specified both positionally and by keyword

greet(name: "Alice", name: "Bob")
# Error: Duplicate keyword argument 'name'
```

### 3. All Names Must Match Parameters

```quest
fun add(x, y)
    x + y
end

# ✗ Invalid
add(a: 5, b: 3)
# Error: Unknown keyword arguments: a, b
# Function 'add' has parameters: x, y
```

### 4. Can't Skip Required Params

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

# ✗ Invalid
greet(greeting: "Hello")
# Error: Missing required parameter 'name'
```

## Error Messages

### Positional After Named

```
Error: Positional argument cannot follow keyword argument
  at line 42: greet(name: "Alice", "Hello")

Hint: Place all positional arguments before keyword arguments
```

### Parameter Specified Twice

```
Error: Parameter 'name' specified both positionally and by keyword
  at line 50: greet("Alice", name: "Bob")

Function signature:
  fun greet(str: name, str: greeting)
```

### Unknown Keyword Arguments

```
Error: Unknown keyword arguments: msg, lvl
  at line 30: log(msg: "Error", lvl: "ERROR")

Function 'log' signature:
  fun log(str: level, str: message, str: source = "app")
  Valid parameters: level, message, source

Hint: Did you mean 'message' and 'level'?
```

### Missing Required Parameter

```
Error: Missing required parameter 'host'
  at line 45: connect(port: 8080, timeout: 30)

Function signature:
  fun connect(str: host, int: port = 8080, int: timeout = 30)
  Required parameters: host
```

## Integration with Other Features

### With Default Parameters (QEP-029)

Perfect synergy - named args let you skip defaults:

```quest
fun f(a, b = 1, c = 2, d = 3)
    a + b + c + d
end

f(10)                  # Uses all defaults
f(10, d: 5)            # Skip b and c, override d
f(10, c: 4, d: 5)      # Skip b, override c and d
```

### With Variadic Parameters (QEP-030)

```quest
fun wrapper(*args, **kwargs)
    original(*args, **kwargs)
end

# Named args go to **kwargs, positional to *args
wrapper(1, 2, 3, option: "value", debug: true)
# args = [1, 2, 3]
# kwargs = {option: "value", debug: true}
```

### With Type Annotations (QEP-015)

```quest
fun connect(str: host, int: port = 8080, bool: ssl = false) -> Connection
    # Types checked regardless of positional/named
end

connect("localhost", port: 3000)       # ✓ Types match
connect("localhost", port: "3000")     # ✗ Type error: expected int
connect(host: "localhost", ssl: "yes") # ✗ Type error: expected bool
```

### With Struct Constructors (Current)

Already works! Just extend the mechanism:

```quest
type Person
    str: name
    int: age
    str: email
end

# Constructor (already works)
Person.new(name: "Alice", age: 30, email: "alice@example.com")

# Regular functions (this QEP enables)
fun create_person(str: name, int: age, str: email) -> Person
    Person.new(name: name, age: age, email: email)
end

create_person(name: "Alice", age: 30, email: "alice@example.com")
```

### With Instance Methods

For instance methods, `self` is **not** a parameter and cannot be specified by keyword:

```quest
type Person
    str: name

    fun greet(greeting = "Hello")
        puts(greeting, ", ", self.name)
    end
end

let p = Person.new(name: "Alice")

# ✓ Valid
p.greet()                      # Use default
p.greet("Hi")                  # Positional
p.greet(greeting: "Hi")        # Named

# ✗ Invalid
p.greet(self: p, greeting: "Hi")
# Error: 'self' is implicit for instance methods and cannot be specified
```

**Rationale:** `self` is automatically bound by the method call syntax (`object.method()`), not by parameter passing.

## Built-In Function Support

Built-in functions (defined in Rust) can opt into named arguments by:

1. **Declaring parameter metadata** in the function definition
2. **Using CallArguments struct** instead of `Vec<QValue>`
3. **Handling keyword lookups** in Rust code

### Example: Built-in with Named Args

```rust
// In src/modules/http/client.rs

pub fn http_get(args: CallArguments) -> Result<QValue, String> {
    // Get required 'url' parameter (positional or named)
    let url = args.get_required_param(0, "url")?;

    // Get optional named parameters with defaults
    let timeout = args.get_keyword_or("timeout", QValue::Int(QInt::new(30)))?;
    let headers = args.get_keyword_or("headers", QValue::Dict(QDict::new()))?;
    let follow_redirects = args.get_keyword_or("follow_redirects", QValue::Bool(QBool::new(true)))?;

    // ... HTTP request logic
}
```

### Quest Usage

```quest
use "std/http/client" as http

# All valid:
http.get("https://example.com")
http.get("https://example.com", timeout: 60)
http.get(url: "https://example.com", timeout: 60, follow_redirects: false)
```

### Current Status

**Currently supported** (already uses named args):
- Struct constructors: `Person.new(name: "Alice", age: 30)`

**Not yet supported** (fixed arity):
- Most built-in methods: `array.slice(start, end)` not `array.slice(start: 2, end: 5)`
- Module functions need updates

**Implementation Priority:** Update stdlib functions in phases:
1. Phase 1: New APIs use named args by default
2. Phase 2: Update frequently-used functions (`http.get`, `db.connect`)
3. Phase 3: Update remaining stdlib

## Performance Considerations

### Lookup Overhead

Named arguments require parameter name lookup:
- Store parameter names in order
- HashMap lookup for each keyword arg
- Validate all names exist

**Mitigation:** Small overhead (single HashMap lookup per keyword arg)

### Memory

Store parameter names in function object:
- Already stored for introspection
- No additional memory needed

## Benefits

1. **Readability** - Self-documenting call sites
2. **Flexibility** - Skip optional parameters easily
3. **Safety** - Harder to swap arguments accidentally
4. **Refactoring** - Can reorder parameters without breaking named calls
5. **Consistency** - Same syntax as constructors

## Performance Impact

**Benchmark: Positional vs Named Arguments**

```quest
fun add(x, y) x + y end

# Positional call
add(1, 2)  # ~10ns baseline

# Named call
add(x: 1, y: 2)  # ~15ns (+50% overhead)
```

**Overhead sources:**
- Parameter name lookup: ~3ns per arg (HashMap)
- Validation: ~2ns total

**Recommendation:**
- Use positional for hot paths (loops, tight recursion)
- Use named for APIs, configuration, and readability

## Limitations

### 1. Verbosity

Named calls are longer but clearer:

```quest
# Shorter but unclear
resize(img, 300, 400, true, false, true)

# Longer but self-documenting
resize(
    image: img,
    width: 300,
    height: 400,
    keep_aspect: true,
    crop: false,
    upscale: true
)
```

### 2. Parameter Names are Part of Public API

**Breaking change:** Renaming parameters breaks callers using named arguments

```quest
# v1.0
fun connect(host, port)
    # ...
end

connect(host: "localhost", port: 8080)  # Users depend on 'host' name

# v2.0: want to rename 'host' → 'hostname'
fun connect(hostname, port)  # ✗ Breaks existing code!
    # ...
end
```

**Migration strategies:**

1. **Major version bumps only** - Only rename in breaking releases
2. **Deprecation period** - Support both names temporarily (future: parameter aliases)
3. **Documentation** - Clearly mark parameter names as stable API
4. **Provide migration tool** - Help users update named arg calls

**Future enhancement:** Parameter aliases (see Future Enhancements #3)

### 3. No Short Names

Can't use abbreviated names for parameters:

```quest
fun configure(cfg)  # Parameter is 'cfg', not 'config'
    # ...
end

configure(config: {})  # ✗ Error: unknown parameter 'config'
configure(cfg: {})     # ✓ Must use exact name
```

## Future Enhancements

### 1. Keyword-Only Parameters

Force certain parameters to be named:

```quest
fun f(a, b, *, c, d)
    # c and d MUST be passed by name
end

f(1, 2, c: 3, d: 4)  # ✓ OK
f(1, 2, 3, 4)        # ✗ Error: c and d must be named
```

### 2. Positional-Only Parameters

Force certain parameters to be positional:

```quest
fun f(a, b, /, c, d)
    # a and b MUST be positional
end

f(1, 2, c: 3, d: 4)  # ✓ OK
f(a: 1, b: 2, c: 3, d: 4)  # ✗ Error: a and b must be positional
```

### 3. Parameter Aliases

Allow short names:

```quest
fun log(message | msg, level | lvl = "INFO")
    # Accept either 'message' or 'msg', 'level' or 'lvl'
end

log(msg: "Hello")       # ✓ OK
log(message: "Hello")   # ✓ OK
```

### 4. Strict Named Mode (Opt-in)

**Note:** This is NOT Python behavior. Python allows positional for defaults.

Optional strict mode where parameters with defaults must be named:

```quest
"use strict named"  # Opt-in pragma

fun f(a, b, c = 1, d = 2)
    # In strict mode: c and d are implicitly keyword-only
end

f(1, 2)           # ✓ OK
f(1, 2, 3, 4)     # ✗ Error in strict mode: c and d must be named
f(1, 2, c: 3)     # ✓ OK
```

**Without pragma:** Quest follows Python - defaults can be positional or named (backward compatible)

**Rationale:** Provides optional safety without breaking existing code patterns.

## Implementation Checklist

### Phase 1: Parse Arguments
- [x] Grammar already supports named_arg (done for constructors)
- [ ] Extend argument parsing to track positional vs named
- [ ] Validate positional-before-named rule
- [ ] Build CallArguments struct

### Phase 2: Function Calls
- [ ] Modify call_user_function to accept CallArguments
- [ ] Bind positional args to params in order
- [ ] Bind keyword args by name lookup
- [ ] Check for duplicate bindings
- [ ] Check for unknown keyword args

### Phase 3: Integration
- [ ] Work with default parameters
- [ ] Work with varargs/kwargs
- [ ] Work with type checking
- [ ] Handle unpacking (**dict)

### Phase 4: Built-in Functions
- [ ] Extend to built-in function calls
- [ ] Update module functions to support named args
- [ ] Document which stdlib functions support named args

### Phase 5: Error Handling
- [ ] Positional after named error
- [ ] Duplicate parameter error
- [ ] Unknown keyword error
- [ ] Missing required parameter error
- [ ] Helpful suggestions (did you mean?)

### Phase 6: Testing
- [ ] `test/function/named_args_test.q` - Basic named args
- [ ] `test/function/named_args_mixed_test.q` - Mixed positional/named
- [ ] `test/function/named_args_defaults_test.q` - With defaults
- [ ] `test/function/named_args_varargs_test.q` - With varargs
- [ ] `test/function/named_args_errors_test.q` - Error cases

### Phase 7: Documentation
- [ ] Update `docs/docs/language/functions.md`
- [ ] Add examples to CLAUDE.md
- [ ] Update all QEPs that reference named args
- [ ] Document stdlib functions with named args

## Alternatives Considered

### Alternative 1: Auto-Collect to Dict

**Considered:** All arguments auto-collected to dict
```quest
fun f(args)
    args["x"] + args["y"]
end
f(x: 1, y: 2)
```
**Rejected:** Loses type safety, no clear parameter list

### Alternative 2: Require Keyword-Only for Defaults

**Considered:** All parameters with defaults must be named
```quest
fun f(a, b = 1)
f(1)        # ✓ OK
f(1, 2)     # ✗ Error: b must be named
f(1, b: 2)  # ✓ OK
```
**Rejected:** Too restrictive, breaks Python/Ruby idioms

### Alternative 3: Arrow Syntax

**Considered:** `=>` instead of `:`
```quest
greet(name => "Alice", greeting => "Hello")
```
**Rejected:** Non-standard, `:` more widely used

## Common Patterns

### Pattern 1: Configuration Functions

```quest
fun create_server(
    host: str = "0.0.0.0",
    port: int = 8080,
    workers: int = 4,
    timeout: int = 30,
    debug: bool = false
) -> Server
    # ...
end

# Clear, self-documenting
let server = create_server(
    port: 3000,
    workers: 8,
    debug: true
)
```

### Pattern 2: Boolean Flags

**Always use named arguments for booleans:**

```quest
# ✗ Unclear
resize(img, 300, 400, true, false, true)

# ✓ Clear
resize(
    image: img,
    width: 300,
    height: 400,
    keep_aspect: true,
    crop: false,
    upscale: true
)
```

### Pattern 3: Skipping Optional Parameters

```quest
fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
    # ...
end

# Skip middle parameters
connect("localhost", debug: true)
connect("localhost", ssl: true, debug: true)
```

### Pattern 4: Configuration Merging

```quest
let defaults = {timeout: 30, retries: 3}
let overrides = {retries: 5}

# Merge configurations
fetch(url: "...", **defaults, **overrides)
# timeout=30 (from defaults), retries=5 (from overrides, last wins)
```

## Style Guide

### When to Use Named Arguments

✅ **Use named arguments for:**
- Functions with 3+ parameters
- Boolean parameters (always)
- Skipping optional parameters
- Configuration/setup functions
- Parameters that aren't self-evident

✅ **Positional is fine for:**
- 1-2 obvious parameters (`add(x, y)`, `max(a, b)`)
- Hot code paths (performance-critical)
- Mathematical operations
- Parameters with clear conventional order

### Examples

```quest
# ✓ Good: 1-2 obvious params
add(5, 3)
max(10, 20)
concat("Hello", "World")

# ✗ Bad: Unclear what numbers mean
connect("localhost", 8080, 30, false, true, 100)

# ✓ Good: Self-documenting
connect(
    host: "localhost",
    port: 8080,
    timeout: 30,
    ssl: false,
    debug: true,
    max_connections: 100
)

# ✓ Good: Mix positional (obvious) with named (clarity)
connect("localhost", timeout: 60, debug: true)
```

## Edge Cases

### Empty Calls with All Defaults

```quest
fun f(a = 1, b = 2, c = 3)
    [a, b, c]
end

f()  # ✓ Valid: [1, 2, 3]
```

### All Named, Wrong Order

```quest
fun greet(greeting, name, punctuation)
    greeting .. ", " .. name .. punctuation
end

# ✓ Order doesn't matter with named args
greet(punctuation: "!", name: "Alice", greeting: "Hello")
# "Hello, Alice!"
```

### Named Args in Nested Calls

```quest
fun outer(x, y)
    x + y
end

fun inner(a, b)
    [a, b]
end

outer(x: inner(b: 2, a: 1)[0], y: 5)
# inner returns [1, 2], [0] is 1, outer(1, 5) = 6
```

### Lambda Expressions

```quest
let greet = fun (name, greeting = "Hello")
    greeting .. ", " .. name
end

greet(name: "Alice")  # ✓ Lambdas support named args
greet(greeting: "Hi", name: "Bob")  # ✓ Can reorder
```

### Recursive Calls

```quest
fun fib(n, memo = {})
    if n <= 1
        return n
    end

    if memo.contains_key(n._str())
        return memo[n._str()]
    end

    # ✓ Recursive call with named args
    let result = fib(n: n - 1, memo: memo) + fib(n: n - 2, memo: memo)
    memo[n._str()] = result
    result
end

fib(n: 10)
```

### Parameter Name Shadowing

```quest
let host = "default.com"

fun connect(host, port)
    puts(host)  # Uses parameter, not outer variable
end

connect(host: "example.com", port: 8080)
# Prints: example.com
```

## Migration Guide

### Updating Existing Functions

**Before:**
```quest
fun resize(image, width, height, keep_aspect, crop, upscale)
    # 6 positional params - hard to remember order
end

resize(img, 300, 400, true, false, true)
```

**After:**
```quest
fun resize(
    image,
    width,
    height,
    keep_aspect = true,
    crop = false,
    upscale = false
)
    # Clear defaults, supports named args
end

# Backward compatible - positional still works
resize(img, 300, 400, true, false, true)

# New style - clear and flexible
resize(image: img, width: 300, height: 400, upscale: true)
resize(img, 300, 400, upscale: true)  # Mix positional/named
```

### Adding Named Args to Existing Codebase

1. **Start with new functions** - Use named args in new APIs
2. **Update frequently-called functions** - Add defaults for existing params
3. **Document parameter names** - Mark them as stable API
4. **Gradual migration** - Both styles work during transition

## Error Message Improvements

### "Did You Mean" Suggestions

```rust
fn suggest_parameter(unknown: &str, valid: &[String]) -> Option<String> {
    use strsim::levenshtein;  // Levenshtein distance

    valid.iter()
        .map(|p| (p, levenshtein(unknown, p)))
        .filter(|(_, dist)| *dist <= 2)  // Max 2 edits
        .min_by_key(|(_, dist)| *dist)
        .map(|(param, _)| param.clone())
}
```

**Example error:**
```
Error: Unknown keyword argument 'msg'
  at line 30: log(msg: "Error", lvl: "ERROR")

Function 'log' has parameters: level, message, source

Hint: Did you mean 'message'?
```

### Type Mismatch with Named Args

```quest
fun connect(str: host, int: port)
end

connect(host: "localhost", port: "8080")
```

**Error:**
```
Error: Type mismatch for parameter 'port'
  Expected int, got str
  at line 42: connect(host: "localhost", port: "8080")

Function signature:
  fun connect(str: host, int: port)

Hint: Did you mean port: 8080 (without quotes)?
```

## See Also

- [QEP-029: Default Parameters](qep-029-default-parameters.md)
- [QEP-030: Variadic Parameters](qep-030-variadic-parameters.md)
- [QEP-015: Type Annotations](qep-015-type-annotations.md)
- [Functions Documentation](../docs/language/functions.md)

## References

- Python keyword arguments
- Ruby keyword arguments
- Swift labeled parameters
- Kotlin named arguments
- C# named arguments

## Copyright

This document is placed in the public domain.
