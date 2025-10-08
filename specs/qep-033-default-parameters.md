# QEP-033: Default Parameter Values (v2)

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Supersedes:** [QEP-029](qep-029-default-parameters.md)
**Dependencies:** [QEP-032: Struct Field Syntax](qep-032-struct-field-syntax.md)
**Related:** QEP-015 (Type Annotations), QEP-003 (Decorators), QEP-034 (Variadic Parameters), QEP-035 (Named Arguments)

## Revision Notes

**This is version 2 of the Default Parameters QEP**, updated to reflect QEP-032's decision to use `name: type` syntax consistently throughout Quest (structs, functions, variables). All examples now use the unified syntax.

## Abstract

This QEP introduces **default parameter values** for Quest functions, allowing parameters to be optional at call sites. Default values are evaluated **at call time** in the parameter scope, enabling dynamic defaults and references to earlier parameters.

**Rating:** 9.5/10 ⭐ **Status:** APPROVED

### What's New in This Revision

This revision addresses critical feedback and adds:

1. **Closure scope capture semantics** - Detailed explanation of how defaults interact with closures
2. **Side effects policy** - Guidelines on when side effects in defaults are appropriate
3. **Circular reference detection** - Strategy for preventing infinite recursion
4. **Method defaults clarification** - Explicit rule that `self` is unavailable in defaults
5. **Named arguments algorithm** - Step-by-step evaluation order when mixing defaults and named args
6. **FAQ section** - 10 common questions with detailed answers
7. **Scope evaluation diagram** - Visual representation of scope chain for default evaluation
8. **Edge case tests** - Comprehensive test checklist for unusual scenarios
9. **Performance quantification** - Benchmark estimates and mitigation strategies
10. **Migration guide** - Practical examples for converting existing code

## Motivation

### Current Limitations

Quest currently requires **exact arity matching**:

```quest
fun connect(host, port, timeout)
    # Must provide all 3 arguments
end

connect("localhost", 8080, 30)     # ✓ OK
connect("localhost", 8080)          # ✗ Error: Expected 3 args, got 2
```

**Workarounds are verbose:**

```quest
# Manual nil checking
fun connect(host, port, timeout)
    if timeout == nil
        timeout = 30
    end
    # ...
end

connect("localhost", 8080, nil)  # Caller must pass nil explicitly
```

### Problems This Causes

1. **Poor API ergonomics** - Common parameters require boilerplate
2. **Can't add parameters** - Adding a new param breaks all existing calls
3. **No sensible defaults** - Everything must be explicit
4. **Verbose call sites** - Must pass values even when defaults are obvious

### Solution

```quest
fun connect(host: str, port: Int = 8080, timeout: Int = 30) -> Connection
    # Implementation
end

# Clean call sites
connect("localhost")                    # Uses port=8080, timeout=30
connect("localhost", 3000)              # Uses timeout=30
connect("localhost", 3000, 60)          # All explicit
connect("localhost", timeout: 60)       # Named args skip port
```

## Design Principles

### 1. Call-Time Evaluation

Defaults are evaluated **each time the function is called**, not at definition time:

```quest
fun log(msg, timestamp = now())
    puts("[", timestamp, "] ", msg)
end

log("first")   # [2025-10-06 10:00:00] first
log("second")  # [2025-10-06 10:00:01] second  <- Fresh timestamp!
```

**Rationale:**
- Enables dynamic defaults (time, UUID, config lookup)
- Consistent with Quest's eager evaluation model
- Avoids Python's mutable default gotcha
- Principle of least surprise

### 2. Left-to-Right Scope

Defaults can reference **earlier parameters** (left of them):

```quest
fun slice(array, start = 0, end = array.len())
    # Implementation using array.get(index)
    let result = []
    for i in start to end - 1
        result.push(array.get(i))
    end
    result
end

# Evaluation order:
# 1. Bind array
# 2. Evaluate start default (if not provided)
# 3. Evaluate end default (can see array and start)
```

**Scope Rules:**
- Default expressions evaluate in **function parameter scope**
- Can reference: earlier parameters, outer scope variables, module functions
- **Cannot reference:** later parameters, `self` (for methods), the function itself (circular)

**Invalid:**
```quest
fun bad(x = y + 1, y = 5)  # ✗ Error: 'y' not defined
    x + y
end
```

### 3. Optional = Has Default

A parameter is **optional** if and only if it has a default value:

```quest
fun greet(name, greeting = "Hello")  # name required, greeting optional
    greeting .. ", " .. name
end

greet("Alice")              # ✓ OK
greet("Alice", "Hi")        # ✓ OK
greet()                     # ✗ Error: Missing required parameter 'name'
```

### 4. Required Before Optional

All required parameters must come before optional ones:

```quest
# ✓ OK
fun f(a, b, c = 1, d = 2)

# ✗ Error: Required parameter 'd' after optional parameter 'c'
fun bad(a, b = 1, c, d = 2)
```

### 5. Side Effects Policy

**Side effects in defaults are ALLOWED but DISCOURAGED.**

```quest
# ✓ Allowed - but caller beware!
let counter = 0
fun log(msg, id = (counter = counter + 1))
    puts("[", id, "] ", msg)
end

# ⚠️ Better - explicit side effects in function body
fun log_better(msg, id = nil)
    if id == nil
        counter = counter + 1
        id = counter
    end
    puts("[", id, "] ", msg)
end
```

**Guidelines:**
- **Dynamic values (UUIDs, timestamps):** ✅ Excellent use case
- **Pure computations:** ✅ Safe and clear
- **Mutations/IO:** ⚠️ Avoid - makes call semantics unpredictable
- **Circular recursion:** ❌ Detected and rejected

## Specification

### Syntax

```quest
fun function_name(
    required_param: type,
    optional_param: type = default_expr,
    another_optional: type = default_expr
) -> return_type
    # body
end
```

**Components:**
- `required_param` - No default, must be provided
- `optional_param` - Has default, can be omitted
- `default_expr` - Any valid Quest expression
- Type annotations optional but recommended

**Note:** Quest uses `name: type` syntax for parameter declarations (per QEP-032), not `type: name`.

### Grammar Changes

```pest
parameter = {
    identifier ~ (":" ~ type_expr)? ~ ("=" ~ expression)?
}

parameter_list = {
    parameter ~ ("," ~ parameter)*
}

// Examples that should parse:
// x                -> required, no type
// x: Int           -> required, with type
// x = 10           -> optional, no type
// x: Int = 10      -> optional, with type
```

### Storage in QUserFun

```rust
pub struct QUserFun {
    pub name: Option<String>,
    pub params: Vec<String>,                    // ["host", "port", "timeout"]
    pub param_defaults: Vec<Option<String>>,    // [None, Some("8080"), Some("30")]
    pub param_types: Vec<Option<String>>,       // [Some("str"), Some("int"), Some("int")]
    pub body: String,
    pub doc: Option<String>,
    pub id: u64,
    pub captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
}
```

### Evaluation Algorithm

```rust
pub fn call_user_function(
    user_fun: &QUserFun,
    args: Vec<QValue>,
    parent_scope: &mut Scope
) -> Result<QValue, String> {
    // Validate argument count
    let required_count = user_fun.param_defaults.iter()
        .filter(|d| d.is_none())
        .count();

    if args.len() < required_count {
        return Err(format!(
            "Function {} requires at least {} arguments, got {}",
            user_fun.name.as_deref().unwrap_or("<anonymous>"),
            required_count,
            args.len()
        ));
    }

    if args.len() > user_fun.params.len() {
        return Err(format!(
            "Function {} takes at most {} arguments, got {}",
            user_fun.name.as_deref().unwrap_or("<anonymous>"),
            user_fun.params.len(),
            args.len()
        ));
    }

    // Create function scope
    let mut func_scope = create_function_scope(user_fun, parent_scope);

    // Phase 1: Bind provided arguments
    for (i, arg_value) in args.iter().enumerate() {
        // Type check if parameter has annotation
        if let Some(param_type) = &user_fun.param_types[i] {
            check_parameter_type(arg_value, param_type, &user_fun.params[i])?;
        }

        func_scope.declare(&user_fun.params[i], arg_value.clone())?;
    }

    // Phase 2: Evaluate defaults for omitted parameters
    for i in args.len()..user_fun.params.len() {
        let default_expr = user_fun.param_defaults[i]
            .as_ref()
            .ok_or_else(|| format!("Missing required parameter '{}'", user_fun.params[i]))?;

        // Evaluate default in function scope (can see earlier params)
        let default_value = eval_expression(default_expr, &mut func_scope)?;

        // Type check default value
        if let Some(param_type) = &user_fun.param_types[i] {
            check_parameter_type(&default_value, param_type, &user_fun.params[i])?;
        }

        func_scope.declare(&user_fun.params[i], default_value)?;
    }

    // Phase 3: Execute function body
    execute_function_body(&user_fun.body, &mut func_scope)
}
```

### Closure Scope Capture

Default expressions capture outer scope at **function definition time**, but evaluate at **call time**:

```quest
fun outer()
    let local = 50

    # Closure captures outer scope
    fun inner(x = local)
        x * 2
    end

    inner  # Return closure
end

let f = outer()
f()      # ✓ Returns 100 (local = 50 captured, evaluated at call time)
f(10)    # ✓ Returns 20 (explicit arg)
```

**Implementation:** Store captured scopes in `QUserFun.captured_scopes` (already exists). Default expressions evaluate with:
1. Function parameter scope (for earlier params)
2. Captured scopes (from closure creation)
3. Parent scope (fallback)

**Scope Precedence:**
```
Default Expression Evaluation Scope:
├─ 1. Function parameters (earlier params only)
├─ 2. Captured closures (if any)
└─ 3. Parent/global scope
```

### Circular Reference Detection

Prevent infinite recursion in default expressions:

```quest
# ✗ Error: Circular reference detected
fun f(x = f(5))
    x * 2
end

# ✗ Error: Circular reference through helper
fun helper(n = helper(10))
    n
end
```

**Detection Strategy:**
1. **Parse-time:** Check for self-reference in literal defaults
2. **Call-time:** Use recursion depth limit (Quest's existing stack check)
3. **Error message:** "Circular reference detected in default expression for parameter 'x'"

## Examples

### Example 1: Basic Defaults

```quest
fun greet(name, greeting = "Hello", punctuation = "!")
    greeting .. ", " .. name .. punctuation
end

greet("Alice")                          # "Hello, Alice!"
greet("Bob", "Hi")                      # "Hi, Bob!"
greet("Charlie", "Hey", ".")            # "Hey, Charlie."
```

### Example 2: Dynamic Defaults

```quest
fun create_user(name, id = uuid.v4(), created_at = now())
    {
        name: name,
        id: id,
        created_at: created_at
    }
end

let user1 = create_user("Alice")
let user2 = create_user("Bob")
# Each gets unique ID and timestamp
```

### Example 3: Defaults Reference Earlier Params

```quest
fun create_email(username, domain = "example.com", email = username .. "@" .. domain)
    {username: username, email: email}
end

create_email("alice")
# {username: "alice", email: "alice@example.com"}

create_email("bob", "company.com")
# {username: "bob", email: "bob@company.com"}

create_email("charlie", "test.com", "custom@other.com")
# {username: "charlie", email: "custom@other.com"}
```

### Example 4: Array Operations

```quest
fun slice(array, start = 0, end = array.len())
    let result = []
    for i in start to end - 1
        result.push(array.get(i))
    end
    result
end

let data = [1, 2, 3, 4, 5]
slice(data)           # [1, 2, 3, 4, 5] (full array)
slice(data, 2)        # [3, 4, 5] (from index 2)
slice(data, 1, 4)     # [2, 3, 4] (range)
```

### Example 5: Configuration with Types

```quest
fun start_server(
    host: str = "0.0.0.0",
    port: Int = 8080,
    workers: Int = 4,
    timeout: Int = 30,
    debug: bool = false
) -> Server
    Server.new(
        host: host,
        port: port,
        workers: workers,
        timeout: timeout,
        debug: debug
    )
end

# Use all defaults
let server1 = start_server()

# Override specific values
let server2 = start_server(port: 3000, debug: true)

# Fully explicit
let server3 = start_server("localhost", 8000, 2, 60, true)
```

### Example 6: Computed Defaults

```quest
fun paginate(items: array, page: Int = 1, per_page: Int = 10)
    let offset = (page - 1) * per_page
    let limit = per_page
    # Use array.slice(start, end) when available
    let result = []
    for i in offset to offset + limit - 1
        if i < items.len()
            result.push(items.get(i))
        end
    end
    result
end

paginate(data)              # Page 1, 10 items
paginate(data, 3)           # Page 3, 10 items
paginate(data, 2, 20)       # Page 2, 20 items
```

### Example 7: Side Effects in Defaults

```quest
let request_counter = 0

fun log_request(endpoint, request_id = (request_counter = request_counter + 1))
    puts("[", request_id, "] ", endpoint)
end

log_request("/api/users")      # [1] /api/users
log_request("/api/posts")      # [2] /api/posts
log_request("/api/comments", 99)  # [99] /api/comments (explicit)
log_request("/api/likes")      # [3] /api/likes (counter continues)
```

## Type Checking

### Runtime Type Checking

When QEP-015 (Type Annotations) is implemented, default values are type-checked:

```quest
fun connect(host: str, port: Int = 8080) -> Connection
    # ...
end

# Type checking happens when default is used:
connect("localhost")     # ✓ port default (8080) matches int
```

### Definition-Time Validation (Literals)

For better UX, check **literal** defaults at definition time:

```quest
# ✗ Error immediately at definition
fun bad(port: Int = "8080")
    # Type error: default "8080" (str) doesn't match parameter type int
end

# ✓ OK - can't check until call time
fun good(port: Int = get_default_port())
    # get_default_port() might return int
end
```

### Implementation

```rust
// During function definition parsing
fn validate_parameter_defaults(
    params: &[String],
    param_types: &[Option<String>],
    param_defaults: &[Option<String>]
) -> Result<(), String> {
    for (i, default_expr) in param_defaults.iter().enumerate() {
        if let Some(expr) = default_expr {
            if let Some(param_type) = &param_types[i] {
                // Try to evaluate as literal
                if let Ok(literal_value) = try_parse_literal(expr) {
                    // Check type immediately
                    if !type_matches(&literal_value, param_type) {
                        return Err(format!(
                            "Default value for parameter '{}' has wrong type: expected {}, got {}",
                            params[i], param_type, literal_value.q_type()
                        ));
                    }
                }
                // If not a literal, defer check to call time
            }
        }
    }
    Ok(())
}
```

## Interaction with Named Arguments

Default parameters work beautifully with named arguments (see QEP-031):

```quest
fun connect(host: str, port: Int = 8080, timeout: Int = 30, ssl: bool = false)
    # ...
end

# Positional with defaults
connect("localhost")                 # Uses all defaults
connect("localhost", 3000)           # Override port only

# Named arguments skip defaults
connect("localhost", ssl: true)      # Use default port and timeout
connect("localhost", timeout: 60, ssl: true)  # Skip port default

# Mix positional and named
connect("localhost", 3000, ssl: true)  # port positional, timeout default, ssl named
```

**Evaluation Algorithm with Named Args:**

1. **Bind positional arguments** left-to-right to parameters
2. **Bind named arguments** to their specific parameters
3. **Evaluate defaults** for remaining unbound parameters (left-to-right)
4. **Validate** all required parameters are bound

**Example:**
```quest
fun f(a, b = 10, c = 20, d = 30)
    [a, b, c, d]
end

f(1, d: 40)
# 1. Bind a = 1
# 2. Bind d = 40 (named)
# 3. Evaluate b default: 10
# 4. Evaluate c default: 20
# Result: [1, 10, 20, 40]
```

## Error Messages

### Missing Required Parameter

```
Error: Missing required parameter 'host' in call to 'connect'
  at line 42: connect()

Function 'connect' signature:
  fun connect(host: str, port: Int = 8080, timeout: Int = 30)
  Required parameters: host
```

### Type Mismatch in Default

```
Error: Type mismatch for parameter 'port' in function 'connect'
  Default value "8080" (str) doesn't match parameter type int
  at line 15: fun connect(host: str, port: Int = "8080")

Hint: Did you mean port: Int = 8080 (without quotes)?
```

### Default References Later Parameter

```
Error: Invalid default expression for parameter 'x'
  Cannot reference parameter 'y' which comes after 'x'
  at line 8: fun bad(x = y + 1, y = 5)

Hint: Default expressions can only reference parameters to their left
```

### Too Many Arguments

```
Error: Too many arguments in call to 'connect'
  Function takes at most 3 arguments, got 4
  at line 50: connect("localhost", 8080, 30, true)

Function signature:
  fun connect(host: str, port: Int = 8080, timeout: Int = 30)
```

## Validation Rules

### 1. Required Parameters First

```quest
# ✓ Valid
fun f(a, b, c = 1, d = 2)

# ✗ Invalid
fun f(a, b = 1, c, d = 2)
# Error: Required parameter 'c' cannot follow optional parameter 'b'
```

### 2. No Forward References

```quest
# ✓ Valid - reference earlier param
fun f(x, y = x + 1)

# ✗ Invalid - reference later param
fun f(x = y + 1, y)
# Error: Default for 'x' references 'y' which is not yet defined
```

### 3. Default Must Be Valid Expression

```quest
# ✓ Valid
fun f(x = 1 + 2)
fun f(x = now())
fun f(x = [1, 2, 3])

# ✗ Invalid - syntax error
fun f(x = 1 +)
# Error: Invalid default expression: syntax error
```

### 4. Method Defaults Cannot Use `self`

For type instance methods, `self` is **not available** in default expressions:

```quest
type User
    name: str
    age: Int

    # ✗ Invalid - self not in scope for defaults
    fun greet(greeting = "Hello, " .. self.name)
        greeting
    end

    # ✓ Valid - use parameter
    fun greet_better(greeting = "Hello")
        greeting .. ", " .. self.name
    end
end
```

**Rationale:** Defaults evaluate before `self` is bound. Use the function body instead.

## Frequently Asked Questions

### Q1: When are defaults evaluated - definition time or call time?

**Answer:** Call time. Each function invocation evaluates defaults fresh.

```quest
let counter = 0
fun f(x = (counter = counter + 1))
    x
end

f()  # Returns 1
f()  # Returns 2 (evaluated again!)
```

### Q2: Can defaults reference outer scope variables?

**Answer:** Yes, through closure capture.

```quest
let config = {port: 8080}

fun connect(host, port = config.port)  # ✓ OK
    # ...
end
```

### Q3: Can defaults call other functions?

**Answer:** Yes, any expression is valid.

```quest
fun get_timestamp() now() end

fun log(msg, timestamp = get_timestamp())  # ✓ OK
    # ...
end
```

### Q4: Can defaults use `self` in methods?

**Answer:** No. `self` is not bound until after parameters are bound.

```quest
type T
    fun method(x = self.field)  # ✗ Error: 'self' not available
end
```

### Q5: What if a default expression throws an error?

**Answer:** The error propagates to the caller at call time.

```quest
fun f(x = 1 / 0)  # No error at definition
    x
end

f()  # ✗ Runtime error: Division by zero
f(5) # ✓ OK - default not evaluated
```

### Q6: Can I reference the function itself in defaults?

**Answer:** No. This creates circular references.

```quest
fun factorial(n = factorial(5))  # ✗ Error: Circular reference
    # ...
end
```

### Q7: Are defaults parsed once or per call?

**Answer:** Parsed once (at definition), evaluated per call.

Default expressions are stored as strings in `QUserFun` and re-evaluated each call.

### Q8: How do defaults interact with recursion?

**Answer:** Each recursive call evaluates its own defaults.

```quest
fun countdown(n = 10)
    if n > 0
        puts(n)
        countdown(n - 1)
    end
end

countdown()    # Starts at 10
countdown(5)   # Starts at 5
```

### Q9: Can defaults be mutable objects?

**Answer:** Yes, but each call creates a fresh instance (unlike Python).

```quest
fun f(x = [])  # ✓ Safe - new array each call
    x.push(1)
    x
end

f()  # [1]
f()  # [1] (fresh array, not [1, 1])
```

### Q10: How are defaults displayed in function introspection?

**Answer:** Use `_signature()` or `_doc()` (future):

```quest
fun connect(host: str, port: Int = 8080) Connection
    # ...
end

connect._signature()
# "fun connect(host: str, port: Int = 8080) -> Connection"
```

## Scope Evaluation Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ fun outer()                                                 │
│   let config = {port: 8080}                                 │
│                                                             │
│   fun inner(host, port = config.port, timeout = 30)        │
│     # Function body scope                                   │
│   end                                                       │
│                                                             │
│   inner                                                     │
│ end                                                         │
└─────────────────────────────────────────────────────────────┘

When inner is called: inner("localhost")

Scope Chain for Default Evaluation:
┌────────────────────────────────────┐
│ 1. Function Parameter Scope        │ <- port, timeout being bound
│    - host: "localhost" (bound)     │
│    - port: <evaluating default>    │
│    - timeout: <not yet reached>    │
├────────────────────────────────────┤
│ 2. Captured Closure Scope          │ <- Captured from outer()
│    - config: {port: 8080}          │
├────────────────────────────────────┤
│ 3. Parent/Global Scope             │
│    - Built-in functions            │
│    - Module imports                │
└────────────────────────────────────┘

Evaluation Order:
1. host = "localhost" (provided)
2. port = config.port → Looks up:
   - Not in params (only host bound so far)
   - Found in captured scope → 8080
3. timeout = 30 (literal)
```

## Implementation Checklist

### Phase 1: Grammar and Parsing
- [ ] Update `parameter` rule in quest.pest to allow `= expression`
- [ ] Parse default expressions and store as strings
- [ ] Validate required-before-optional rule at parse time
- [ ] Add tests for grammar parsing

### Phase 2: Storage
- [ ] Add `param_defaults: Vec<Option<String>>` to QUserFun
- [ ] Update function definition to populate defaults
- [ ] Ensure defaults are captured during function creation

### Phase 3: Evaluation
- [ ] Modify `call_user_function` to handle missing arguments
- [ ] Implement two-phase binding (provided args, then defaults)
- [ ] Evaluate defaults in parameter scope (left-to-right)
- [ ] Handle type checking of default values

### Phase 4: Validation
- [ ] Check required-before-optional at definition time
- [ ] Validate literal defaults match types (if QEP-015 implemented)
- [ ] Detect forward references in defaults
- [ ] Generate helpful error messages

### Phase 5: Integration
- [ ] Work with named arguments (allow skipping positional defaults)
- [ ] Update function introspection (`_doc()`, `_signature()`)
- [ ] Ensure closures capture scope for default evaluation

### Phase 6: Testing
- [ ] `test/function/default_params_test.q` - Basic defaults
- [ ] `test/function/default_params_scope_test.q` - Reference earlier params, closures
- [ ] `test/function/default_params_dynamic_test.q` - Side effects, timestamps
- [ ] `test/function/default_params_errors_test.q` - Error cases, validation
- [ ] `test/function/default_params_types_test.q` - Type checking
- [ ] `test/function/default_params_edge_cases_test.q` - Edge cases:
  - [ ] Nil defaults (`x = nil`)
  - [ ] Recursive functions with defaults
  - [ ] Shadowing outer variables in defaults
  - [ ] Circular reference detection
  - [ ] Method defaults (no self access)
  - [ ] Closure scope capture
  - [ ] Default expressions that error
  - [ ] Named arguments with defaults (requires QEP-031)

### Phase 7: Documentation
- [ ] Update `docs/docs/language/functions.md`
- [ ] Add examples to CLAUDE.md
- [ ] Document in language spec
- [ ] Update stdlib function signatures to use defaults

## Benefits

1. **Better APIs** - Sensible defaults reduce call-site verbosity
2. **Backward Compatible** - Can add optional parameters without breaking existing code
3. **Type Safe** - Defaults are type-checked (with QEP-015)
4. **Flexible** - Dynamic defaults enable powerful patterns
5. **Intuitive** - Call-time evaluation matches user expectations

## Limitations

1. **No positional-only parameters** - Can't prevent named usage of required params
2. **No keyword-only parameters** - Can't require named arguments after defaults
3. **Performance** - Each omitted arg requires expression evaluation (see performance note below)
4. **Complexity** - Default scope rules can be surprising for complex cases

## Performance Considerations

**Default evaluation overhead:**
- **Literal defaults** (e.g., `= 10`, `= "hello"`): ~100ns overhead (negligible)
- **Simple expressions** (e.g., `= x + 1`): ~500ns overhead
- **Function calls** (e.g., `= now()`): Cost of function execution

**Mitigation strategies:**
1. Use literals when possible
2. Avoid expensive computations in hot paths
3. Consider making expensive defaults explicit required params

**Benchmark example:**
```quest
# Baseline: explicit args
fun f(x, y) x + y end
f(1, 2)  # ~50ns per call

# With simple default
fun f(x, y = 2) x + y end
f(1)     # ~150ns per call (+100ns)

# With computed default
fun f(x, y = expensive()) x + y end
f(1)     # ~150ns + cost of expensive()
```

For most use cases, the ergonomic benefit far outweighs the minimal overhead.

## Migration Guide

### Converting Existing Functions

**Before (manual nil checking):**
```quest
fun connect(host, port, timeout)
    if port == nil
        port = 8080
    end
    if timeout == nil
        timeout = 30
    end
    # ...
end

connect("localhost", nil, nil)  # Awkward
```

**After (with defaults):**
```quest
fun connect(host, port = 8080, timeout = 30)
    # ...
end

connect("localhost")  # Clean!
```

### Adding Parameters to Existing APIs

**Problem:** Adding a new parameter breaks all existing calls
```quest
# Version 1
fun start_server(host, port)
    # ...
end

# All existing code
start_server("0.0.0.0", 8080)

# Version 2 - BREAKING CHANGE
fun start_server(host, port, workers)
    # ...
end

# All existing code breaks!
```

**Solution:** Add new parameters with defaults
```quest
# Version 2 - backward compatible
fun start_server(host, port, workers = 4)
    # ...
end

# Existing code still works
start_server("0.0.0.0", 8080)

# New code can use new parameter
start_server("0.0.0.0", 8080, 8)
```

### Stdlib Migration Plan

1. Audit all stdlib functions for common optional parameters
2. Add defaults to appropriate functions (e.g., `io.read(path, encoding = "utf8")`)
3. Mark old signatures as deprecated (use `@deprecated` decorator from QEP-003)
4. Remove deprecated signatures in next major version

## Future Enhancements

1. **Keyword-only parameters** (after `*`)
   ```quest
   fun f(a, b = 1, *, c, d = 2)  # c required but must be named
   ```

2. **Positional-only parameters** (before `/`)
   ```quest
   fun f(a, b, /, c = 1)  # a, b must be positional
   ```

3. **Memoization of pure defaults**
   ```quest
   @pure
   fun expensive_default()
       # Heavy computation
   end

   fun f(x = expensive_default())  # Could cache if marked pure
   ```

4. **Better introspection**
   ```quest
   f._signature()  # "fun f(a: Int, b: Int = 10, c: str = \"default\")"
   f._defaults()   # {b: 10, c: "default"} (after evaluation)
   ```

## Alternatives Considered

### Alternative 1: Definition-Time Evaluation

**Rejected:** Would prevent dynamic defaults and cause confusion:
```quest
fun f(x = now())  # When is now() called?
f()  # Different timestamp each call? Or same?
```

### Alternative 2: Separate Optional Syntax

**Rejected:** Redundant with default values:
```quest
fun f(int?: x, y: Int = 10)  # x optional (defaults to nil)
# vs
fun f(x: Int = nil, y: Int = 10)  # Clearer
```

### Alternative 3: Overloading

**Rejected:** More complex, less flexible:
```quest
fun connect(host)
    connect(host, 8080, 30)
end

fun connect(host, port)
    connect(host, port, 30)
end

fun connect(host, port, timeout)
    # Implementation
end
```

## See Also

- [QEP-015: Type Annotations](qep-015-type-annotations.md) - Parameter type checking
- [QEP-003: Function Decorators](qep-003-function-decorators.md) - Requires variadic parameters
- [Functions Documentation](../docs/language/functions.md) - User-facing docs

## References

- Python PEP 3102 - Keyword-Only Arguments
- Ruby optional parameters
- JavaScript default parameters (ES6)
- Rust default trait methods
- Swift default parameter values

## Copyright

This document is placed in the public domain.
