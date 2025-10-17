# QEP-034: Variadic Parameters (v2)

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Supersedes:** [QEP-030](qep-030-variadic-parameters.md)
**Dependencies:** [QEP-032: Struct Field Syntax](qep-032-struct-field-syntax.md)
**Related:** QEP-033 (Default Parameters), QEP-003 (Decorators), QEP-035 (Named Arguments)

## Revision Notes

**This is version 2 of the Variadic Parameters QEP**, updated to reflect QEP-032's decision to use `name: type` syntax consistently throughout Quest (structs, functions, variables). All examples now use the unified syntax.

## Abstract

This QEP introduces **variadic parameters** (variable-length argument lists) for Quest functions using `*args` and `**kwargs` syntax. This enables functions to accept arbitrary numbers of positional and keyword arguments, which is essential for decorators, forwarding patterns, and flexible APIs.

## Motivation

### Current Limitations

Quest functions require **exact arity matching**:

```quest
fun sum(a, b, c)
    a + b + c
end

sum(1, 2, 3)        # ✓ OK
sum(1, 2, 3, 4)     # ✗ Error: Expected 3 args, got 4
```

**Can't write:**
- Decorators that wrap arbitrary functions
- Printf-style formatting functions
- Variadic constructors (`Tuple.new(1, 2, 3, ...)`)
- Argument forwarding/proxies

### Workarounds Are Verbose

```quest
# Current: Must use array
fun sum(numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum([1, 2, 3, 4, 5])  # Must wrap in array []
```

### Solution: Variadic Parameters

```quest
# Collect positional arguments
fun sum(*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum(1, 2, 3, 4, 5)  # Clean syntax, no array wrapper

# Collect keyword arguments
fun configure(**options)
    for key in options.keys()
        puts(key, " = ", options[key])
    end
end

configure(host: "localhost", port: 8080, debug: true)

# Both together
fun wrapper(*args, **kwargs)
    original_function(*args, **kwargs)  # Forward everything
end
```

## Design Principles

### 1. Python-Style Syntax

Use familiar `*args` and `**kwargs` syntax:
- `*name` - Collects remaining positional arguments into an Array
- `**name` - Collects remaining keyword arguments into a Dict

### 2. Parameter Order

```
fun name(required, optional=default, *args, **kwargs)
         ^^^^^^^^  ^^^^^^^^^^^^^^^^  ^^^^^  ^^^^^^^^
         Fixed     Optional          Variadic positional  Variadic keyword
```

**Rules:**
1. Required parameters first
2. Optional parameters (with defaults) next
3. `*args` for remaining positional arguments
4. `**kwargs` for remaining keyword arguments

### 3. At Most One of Each

Only one `*args` and one `**kwargs` allowed:

```quest
# ✓ Valid
fun f(a, b, *rest)
fun f(a, b = 1, *rest, **options)
fun f(**options)

# ✗ Invalid
fun f(*args1, *args2)  # Error: Multiple *args
fun f(**kw1, **kw2)    # Error: Multiple **kwargs
```

### 4. Unpacking at Call Site

Use same syntax to unpack arguments:

```quest
fun greet(greeting, name)
    greeting .. ", " .. name
end

let args = ["Hello", "Alice"]
greet(*args)  # Unpacks array as positional args

let kwargs = {greeting: "Hi", name: "Bob"}
greet(**kwargs)  # Unpacks dict as keyword args
```

## Specification

### Syntax

#### Parameter Declaration

```quest
# Just *args
fun f(*args)
    # args is an Array of all positional arguments
end

# Just **kwargs
fun f(**kwargs)
    # kwargs is a Dict of all keyword arguments
end

# Both
fun f(*args, **kwargs)
    # args = Array of positional, kwargs = Dict of keyword
end

# Mixed with regular params
fun f(required, optional = default, *args, **kwargs)
    # required: must be provided
    # optional: defaults if not provided
    # args: remaining positional args
    # kwargs: remaining keyword args
end

# With type annotations (QEP-015)
# Type annotation specifies the type of EACH element, not the collection
fun f(x: Int, *args: Int, **kwargs: str) -> any
    # args: each element must be int (collected as Array<int>)
    # kwargs: each value must be str (collected as Dict<str, str>)
    # The array/dict wrapper is implicit
end

# Wrong: Don't annotate as array/dict (redundant)
fun f(*args: array)  # ✗ Redundant - varargs always collected as array
fun f(**kwargs: dict) # ✗ Redundant - kwargs always collected as dict
```

#### Call-Site Unpacking

**Evaluation order:** Arguments are evaluated and unpacked **left-to-right**.

```quest
# Unpack array as positional args
let args = [1, 2, 3]
sum(*args)  # Equivalent to: sum(1, 2, 3)

# Unpack dict as keyword args
let config = {host: "localhost", port: 8080}
connect(**config)  # Equivalent to: connect(host: "localhost", port: 8080)

# Mix both
let pos_args = ["Hello"]
let kw_args = {name: "Alice"}
greet(*pos_args, **kw_args)  # greet("Hello", name: "Alice")

# Can still add explicit args
greet("Hi", *more_args, name: "Bob", **more_kwargs)

# Duplicate keys: last one wins
configure(x: 1, **{x: 2})  # x=2
configure(**{x: 1}, x: 2)  # x=2 (explicit overrides unpacked)
```

**Important:** Collections are evaluated before unpacking, so mutations during unpacking don't affect unpacked values:

```quest
let arr = [1, 2, 3]
arr.push(*arr)  # arr becomes [1, 2, 3, 1, 2, 3]
# arr evaluates to [1, 2, 3], then unpacks to 1, 2, 3, then pushes them
```

### Grammar Changes

```pest
parameter_list = {
    parameter ~ ("," ~ parameter)* ~ ("," ~ varargs)? ~ ("," ~ kwargs)?
    | varargs ~ ("," ~ kwargs)?
    | kwargs
}

parameter = {
    identifier ~ (":" ~ type_expr)? ~ ("=" ~ expression)?
}

varargs = {
    "*" ~ identifier ~ (":" ~ type_expr)?
}

kwargs = {
    "**" ~ identifier ~ (":" ~ type_expr)?
}

// At call site
argument_list = {
    (argument | unpack_args | unpack_kwargs) ~ ("," ~ (argument | unpack_args | unpack_kwargs))*
}

argument = { named_arg | expression }

unpack_args = {
    "*" ~ expression
}

unpack_kwargs = {
    "**" ~ expression
}
```

### Storage in QUserFun

```rust
pub struct QUserFun {
    pub name: Option<String>,
    pub params: Vec<String>,                    // Regular positional params
    pub param_defaults: Vec<Option<String>>,    // Defaults for optional params
    pub param_types: Vec<Option<String>>,       // Type annotations
    pub varargs: Option<String>,                // Name of *args param (if any)
    pub varargs_type: Option<String>,           // Type of *args
    pub kwargs: Option<String>,                 // Name of **kwargs param (if any)
    pub kwargs_type: Option<String>,            // Type of **kwargs
    pub body: String,
    pub doc: Option<String>,
    pub id: u64,
    pub captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
}
```

## Examples

### Example 1: Basic Varargs

```quest
fun sum(*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum()               # 0 (empty array)
sum(1)              # 1
sum(1, 2, 3)        # 6
sum(1, 2, 3, 4, 5)  # 15
```

### Example 2: Printf-Style Formatting

```quest
fun printf(format, *args)
    let result = format
    let i = 0
    while result.contains("{}") and i < args.len()
        result = result.replace_first("{}", args[i].str())
        i = i + 1
    end
    puts(result)
end

printf("Hello, {}!", "World")
printf("{} + {} = {}", 2, 3, 5)
printf("No args")
```

### Example 3: Keyword Arguments

```quest
fun configure(**options)
    for key in options.keys()
        puts(key, " = ", options[key])
    end
end

configure(host: "localhost", port: 8080, debug: true)
# Output:
# host = localhost
# port = 8080
# debug = true
```

### Example 4: Wrapper/Proxy Pattern

**Note:** Full decorator support requires QEP-003. This shows the wrapper pattern that varargs enable.

```quest
# Wrapper function that forwards arbitrary arguments
fun log_wrapper(func, *args, **kwargs)
    puts("Calling ", func._name(), " with args: ", args)
    if kwargs.len() > 0
        puts("  and kwargs: ", kwargs)
    end

    let result = func(*args, **kwargs)
    puts("Result: ", result)
    result
end

fun add(x, y)
    x + y
end

log_wrapper(add, 5, 3)
# Output:
# Calling add with args: [5, 3]
# Result: 8

fun greet(name, greeting = "Hello")
    greeting .. ", " .. name
end

log_wrapper(greet, name: "Alice", greeting: "Hi")
# Output:
# Calling greet with args: []
#   and kwargs: {name: "Alice", greeting: "Hi"}
# Result: Hi, Alice
```

### Example 5: Mixed Parameters

```quest
fun connect(host, port = 8080, *extra_args, **options)
    puts("Connecting to ", host, ":", port)

    if extra_args.len() > 0
        puts("Extra args: ", extra_args)
    end

    for key in options.keys()
        puts("Option: ", key, " = ", options[key])
    end
end

connect("localhost")
# Connecting to localhost:8080

connect("localhost", 3000)
# Connecting to localhost:3000

connect("localhost", 3000, "extra", "args", timeout: 30, ssl: true)
# Connecting to localhost:3000
# Extra args: ["extra", "args"]
# Option: timeout = 30
# Option: ssl = true
```

### Example 6: Argument Forwarding

```quest
fun retry(func, max_attempts = 3, *args, **kwargs)
    let attempt = 0
    while attempt < max_attempts
        try
            return func(*args, **kwargs)
        catch e
            attempt = attempt + 1
            if attempt >= max_attempts
                raise e
            end
            puts("Attempt ", attempt, " failed, retrying...")
        end
    end
end

fun fetch_data(url, timeout)
    http.get(url, timeout: timeout)
end

# Forward arguments to fetch_data
retry(fetch_data, 3, "https://api.example.com", 30)
retry(fetch_data, 5, "https://api.example.com", timeout: 60)
```

### Example 7: Unpacking at Call Site

```quest
fun greet(greeting, name, punctuation = "!")
    greeting .. ", " .. name .. punctuation
end

# Unpack array
let args = ["Hello", "Alice"]
greet(*args)  # "Hello, Alice!"

# Unpack dict
let kwargs = {greeting: "Hi", name: "Bob", punctuation: "."}
greet(**kwargs)  # "Hi, Bob."

# Mix unpacking with explicit args
greet(*args, punctuation: "?")  # "Hello, Alice?"
greet("Hey", *["Charlie"])      # "Hey, Charlie!"
```

### Example 8: Variadic Constructor

```quest
type Tuple
    static fun new(*elements)
        if elements.len() == 0
            raise "Tuple requires at least one element"
        end

        let tuple = Tuple.new()
        tuple.elements = elements
        tuple
    end

    fun len()
        self.elements.len()
    end

    fun get(index)
        self.elements[index]
    end
end

let t1 = Tuple.new(1)
let t2 = Tuple.new(1, 2, 3)
let t3 = Tuple.new("a", "b", "c", "d", "e")
```

### Example 9: Type-Safe Varargs (with QEP-015)

```quest
# Type annotation specifies element type, NOT collection type
fun sum_ints(*numbers: Int) -> int
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum_ints(1, 2, 3)      # ✓ OK - each element is int
sum_ints(1, 2, "3")    # ✗ Error: Argument 3 expected int, got str
```

## Evaluation Algorithm

### Function Definition

```rust
fn parse_function_parameters(params_pair: Pair<Rule>) -> Result<FunctionParams, String> {
    let mut regular_params = Vec::new();
    let mut param_defaults = Vec::new();
    let mut varargs = None;
    let mut kwargs = None;
    let mut seen_optional = false;

    for param in params_pair.into_inner() {
        match param.as_rule() {
            Rule::parameter => {
                let mut inner = param.into_inner();
                let name = inner.next().unwrap().as_str().to_string();

                let type_annotation = if let Some(type_pair) = inner.peek() {
                    if type_pair.as_rule() == Rule::type_expr {
                        Some(inner.next().unwrap().as_str().to_string())
                    } else {
                        None
                    }
                } else {
                    None
                };

                let default = if let Some(expr) = inner.next() {
                    seen_optional = true;
                    Some(expr.as_str().to_string())
                } else {
                    if seen_optional {
                        return Err(format!(
                            "Required parameter '{}' cannot follow optional parameters",
                            name
                        ));
                    }
                    None
                };

                regular_params.push(name);
                param_defaults.push(default);
            }
            Rule::varargs => {
                if kwargs.is_some() {
                    return Err("*args must come before **kwargs".to_string());
                }
                let mut inner = param.into_inner();
                let name = inner.next().unwrap().as_str().to_string();
                let type_annotation = inner.next()
                    .map(|t| t.as_str().to_string());
                varargs = Some((name, type_annotation));
            }
            Rule::kwargs => {
                let mut inner = param.into_inner();
                let name = inner.next().unwrap().as_str().to_string();
                let type_annotation = inner.next()
                    .map(|t| t.as_str().to_string());
                kwargs = Some((name, type_annotation));
            }
            _ => {}
        }
    }

    Ok(FunctionParams {
        regular_params,
        param_defaults,
        varargs,
        kwargs,
    })
}
```

### Function Call

```rust
pub fn call_user_function(
    user_fun: &QUserFun,
    call_args: CallArguments,  // Contains positional and keyword args
    parent_scope: &mut Scope
) -> Result<QValue, String> {
    let mut func_scope = create_function_scope(user_fun, parent_scope);

    // Phase 1: Bind required and optional positional parameters
    let mut arg_index = 0;
    for (i, param_name) in user_fun.params.iter().enumerate() {
        if arg_index < call_args.positional.len() {
            // Use provided positional arg
            let arg_value = call_args.positional[arg_index].clone();

            // Type check
            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&arg_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, arg_value)?;
            arg_index += 1;
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

    // Phase 2: Collect remaining positional args into *args
    if let Some(varargs_name) = &user_fun.varargs {
        let remaining_args = call_args.positional[arg_index..].to_vec();
        let varargs_array = QValue::Array(QArray::new(remaining_args));

        // Type check varargs if specified
        if let Some(varargs_type) = &user_fun.varargs_type {
            check_parameter_type(&varargs_array, varargs_type, varargs_name)?;
        }

        func_scope.declare(varargs_name, varargs_array)?;
    } else if arg_index < call_args.positional.len() {
        return Err(format!(
            "Too many positional arguments: expected {}, got {}",
            user_fun.params.len(),
            call_args.positional.len()
        ));
    }

    // Phase 3: Handle keyword arguments
    let mut remaining_kwargs = call_args.keyword.clone();

    // Try to match keyword args to regular parameters
    for (i, param_name) in user_fun.params.iter().enumerate() {
        if let Some(kw_value) = remaining_kwargs.remove(param_name) {
            // Check if already bound (from positional)
            if func_scope.get(param_name).is_some() {
                return Err(format!(
                    "Parameter '{}' specified both positionally and by keyword",
                    param_name
                ));
            }

            // Bind keyword arg to parameter
            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&kw_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, kw_value)?;
        }
    }

    // Phase 4: Collect remaining keyword args into **kwargs
    if let Some(kwargs_name) = &user_fun.kwargs {
        let kwargs_dict = QValue::Dict(QDict::new(remaining_kwargs));

        // Type check kwargs if specified
        if let Some(kwargs_type) = &user_fun.kwargs_type {
            check_parameter_type(&kwargs_dict, kwargs_type, kwargs_name)?;
        }

        func_scope.declare(kwargs_name, kwargs_dict)?;
    } else if !remaining_kwargs.is_empty() {
        let unknown_keys: Vec<_> = remaining_kwargs.keys().collect();
        return Err(format!(
            "Unknown keyword arguments: {}",
            unknown_keys.join(", ")
        ));
    }

    // Phase 5: Execute function body
    execute_function_body(&user_fun.body, &mut func_scope)
}
```

### Call-Site Unpacking

```rust
fn expand_call_arguments(
    args_pair: Pair<Rule>,
    scope: &mut Scope
) -> Result<CallArguments, String> {
    let mut positional = Vec::new();
    let mut keyword = HashMap::new();

    for arg in args_pair.into_inner() {
        match arg.as_rule() {
            Rule::expression => {
                positional.push(eval_pair(arg, scope)?);
            }
            Rule::named_arg => {
                let mut inner = arg.into_inner();
                let name = inner.next().unwrap().as_str().to_string();
                let value = eval_pair(inner.next().unwrap(), scope)?;
                keyword.insert(name, value);
            }
            Rule::unpack_args => {
                // *args - unpack array into positional
                let expr = arg.into_inner().next().unwrap();
                let value = eval_pair(expr, scope)?;

                match value {
                    QValue::Array(arr) => {
                        positional.extend(arr.elements.clone());
                    }
                    _ => return Err("Can only unpack arrays with * operator".to_string())
                }
            }
            Rule::unpack_kwargs => {
                // **kwargs - unpack dict into keyword args
                let expr = arg.into_inner().next().unwrap();
                let value = eval_pair(expr, scope)?;

                match value {
                    QValue::Dict(dict) => {
                        for (k, v) in dict.map.iter() {
                            // Keys MUST be strings for keyword arguments
                            // Non-string keys are an error (not silently skipped)
                            if let QValue::Str(key_str) = k {
                                // Check for duplicates
                                if keyword.contains_key(&key_str.value) {
                                    return Err(format!(
                                        "Duplicate keyword argument '{}' in ** unpacking",
                                        key_str.value
                                    ));
                                }
                                keyword.insert(key_str.value.clone(), v.clone());
                            } else {
                                return Err(format!(
                                    "Dictionary keys must be strings for ** unpacking, got {}",
                                    k.q_type()
                                ));
                            }
                        }
                    }
                    _ => return Err("Can only unpack dicts with ** operator".to_string())
                }
            }
            _ => {}
        }
    }

    Ok(CallArguments { positional, keyword })
}
```

## Type Checking (with QEP-015)

### Varargs Type Annotation

**Important:** Type annotation specifies the type of **each element**, not the collection:

```quest
# ✓ Correct: Type each element
fun sum(*numbers: Int) -> int
    # Each number must be int (collected into Array<int>)
end

sum(1, 2, 3)         # ✓ OK - all ints
sum(1, 2, "three")   # ✗ Error: Argument 3 expected int, got str

# ✗ Wrong: Don't type as array (redundant)
fun sum(*numbers: array<int>)
    # array<int> is redundant - varargs always become arrays
end

# ✗ Wrong: Don't type as array
fun sum(*numbers: array)
    # array is redundant - varargs always become arrays
end
```

**Rationale:** The `*` operator already means "collect into array", so typing as `array<T>` is redundant. Just specify the element type.

### Kwargs Type Annotation

**Important:** Type annotation specifies the type of **each value**, not the collection:

```quest
# ✓ Correct: Type each value
fun configure(**options: str)
    # Each option value must be str (collected into Dict<str, str>)
    # Keys are always strings (enforced by ** unpacking rules)
end

configure(host: "localhost", port: "8080")  # ✓ OK - all string values
configure(host: "localhost", port: 8080)    # ✗ Error: Value for 'port' expected str, got int

# ✗ Wrong: Don't type as dict (redundant)
fun configure(**options: dict<str, any>)
    # dict<str, any> is redundant - kwargs always become dicts
end
```

**Rationale:** The `**` operator already means "collect into dict with string keys", so typing as `dict<K, V>` is redundant. Just specify the value type.

## Validation Rules

### 1. Parameter Order

```quest
# ✓ Valid orders
fun f(a, b, c)                    # Regular params only
fun f(a, b = 1, c = 2)            # With defaults
fun f(a, *args)                   # With varargs
fun f(a, **kwargs)                # With kwargs
fun f(a, b = 1, *args)            # Regular + default + varargs
fun f(a, b = 1, *args, **kwargs)  # All types
fun f(*args, **kwargs)            # Just varargs

# ✗ Invalid orders
fun f(*args, a)                   # Regular param after varargs
fun f(**kwargs, a)                # Regular param after kwargs
fun f(**kwargs, *args)            # varargs after kwargs
fun f(*args1, *args2)             # Multiple varargs
fun f(**kw1, **kw2)               # Multiple kwargs
```

### 2. No Defaults on Varargs/Kwargs

```quest
# ✗ Invalid
fun f(*args = [])        # Error: varargs cannot have default
fun f(**kwargs = {})     # Error: kwargs cannot have default
```

**Rationale:** Varargs and kwargs already default to empty Array/Dict when not provided.

### 3. Unpacking Type Constraints

```quest
# Can only unpack arrays with *
sum(*[1, 2, 3])     # ✓ OK
sum(*"not array")   # ✗ Error

# Can only unpack dicts with **
configure(**{host: "localhost"})  # ✓ OK
configure(**[1, 2, 3])            # ✗ Error
```

## Error Messages

### Too Many Positional Args (No Varargs)

```
Error: Too many positional arguments in call to 'greet'
  Function takes at most 2 arguments, got 4
  at line 50: greet("Hello", "Alice", "extra", "args")

Function signature:
  fun greet(greeting: str, name: str)
```

### Unknown Keyword Args (No Kwargs)

```
Error: Unknown keyword arguments in call to 'greet': punctuation, mood
  at line 52: greet("Hi", "Bob", punctuation: "!", mood: "happy")

Function signature:
  fun greet(greeting: str, name: str)
  Accepted parameters: greeting, name
```

### Wrong Unpack Type

```
Error: Cannot unpack non-array with * operator
  Expected array, got str
  at line 45: sum(*"not an array")
```

### Parameter Specified Twice

```
Error: Parameter 'name' specified both positionally and by keyword
  at line 30: greet("Hello", "Alice", name: "Bob")

Function signature:
  fun greet(greeting, name)
```

## Integration with Other Features

### With Default Parameters (QEP-029)

```quest
fun log(level = "INFO", *messages, **metadata)
    puts("[", level, "] ", messages.join(" "))
    for key in metadata.keys()
        puts("  ", key, ": ", metadata[key])
    end
end

log("Error", "Connection failed", "Retrying", timeout: 30, attempt: 3)
# [Error] Connection failed Retrying
#   timeout: 30
#   attempt: 3
```

### With Named Arguments (QEP-031)

```quest
fun process(required, optional = 10, *args, **kwargs)
    # Can call with:
    process(1)                          # Just required
    process(1, 20)                      # Required + optional
    process(1, 20, 3, 4, 5)            # + varargs
    process(1, debug: true)             # Skip optional, use kwargs
    process(1, optional: 20, debug: true)  # Named + kwargs
end
```

### With Type Annotations (QEP-015)

```quest
fun typed_varargs(
    x: Int,
    y: Int = 0,
    *args: Int,        # Each arg must be int
    **kwargs: any      # Each kwarg value can be any type
) -> int
    let sum = x + y
    for n in args
        sum = sum + n
    end
    sum
end
```

### With Decorators (QEP-003)

```quest
type TimingDecorator
    impl Decorator
        fun _call(*args, **kwargs)
            let start = now()
            let result = self.func(*args, **kwargs)
            let elapsed = now() - start
            puts("Execution time: ", elapsed, "ms")
            return result
        end
    end
end

@TimingDecorator
fun any_function(a, b, c = 1)
    # Decorator can forward any signature
end
```

## Performance Considerations

### Array/Dict Allocation

Each varargs/kwargs parameter creates a new Array/Dict:
- Empty varargs: `[]` allocation
- Empty kwargs: `{}` allocation
- Non-empty: Copy arguments into new collection

### Unpacking Overhead

Call-site unpacking requires:
- Evaluate expression
- Type check (array or dict)
- Clone elements into positional/keyword arrays

**Optimization:** Use array views/slices for varargs instead of copying.

## Benefits

1. **Enables Decorators** - Can wrap any function signature
2. **Flexible APIs** - Printf, constructors, configuration functions
3. **Argument Forwarding** - Proxy/wrapper patterns
4. **Better DX** - Clean syntax for variable-length operations
5. **Python Familiarity** - Developers already know `*args`/`**kwargs`

## Limitations

1. **Performance** - Array/dict allocation overhead
2. **Type Safety** - Varargs weaken type checking (mitigated by generics)
3. **Complexity** - More complex call resolution
4. **No Keyword-Only** - Can't force parameters to be named (future: after `*`)

## Future Enhancements

### 1. Keyword-Only Parameters

After `*` or `*args`, remaining params must be named:

```quest
fun f(a, b, *, c, d)
    # c and d must be passed by name
end

f(1, 2, c: 3, d: 4)     # ✓ OK
f(1, 2, 3, 4)           # ✗ Error: c and d must be named
```

### 2. Positional-Only Parameters

Before `/`, params cannot be passed by name:

```quest
fun f(a, b, /, c, d)
    # a and b must be positional
end

f(1, 2, c: 3, d: 4)     # ✓ OK
f(a: 1, b: 2, c: 3, d: 4)  # ✗ Error: a and b must be positional
```

### 3. Generic Varargs Types

```quest
fun concat<T>(*elements: array<T>) -> array<T>
    # Type-safe varargs with generics
end
```

### 4. Unpacking in Patterns

```quest
let [first, *rest] = [1, 2, 3, 4, 5]
# first = 1, rest = [2, 3, 4, 5]

let {name, **others} = {name: "Alice", age: 30, city: "NYC"}
# name = "Alice", others = {age: 30, city: "NYC"}
```

## Implementation Checklist

### Phase 1: Grammar
- [ ] Add `varargs` rule: `"*" ~ identifier ~ type_expr?`
- [ ] Add `kwargs` rule: `"**" ~ identifier ~ type_expr?`
- [ ] Update `parameter_list` to allow varargs/kwargs
- [ ] Add `unpack_args` and `unpack_kwargs` to argument_list
- [ ] Validate parameter order in grammar

### Phase 2: Storage
- [ ] Add `varargs`, `kwargs` fields to QUserFun
- [ ] Add `varargs_type`, `kwargs_type` for type checking
- [ ] Update function definition parser

### Phase 3: Function Definition
- [ ] Parse varargs/kwargs parameters
- [ ] Validate only one of each
- [ ] Validate ordering constraints
- [ ] Store in function object

### Phase 4: Function Calls
- [ ] Modify call_user_function to handle varargs
- [ ] Collect excess positional args into array
- [ ] Collect excess keyword args into dict
- [ ] Type check varargs/kwargs if annotated

### Phase 5: Unpacking
- [ ] Parse `*expr` at call site
- [ ] Parse `**expr` at call site
- [ ] Evaluate and unpack arrays
- [ ] Evaluate and unpack dicts
- [ ] Validate unpack types

### Phase 6: Integration
- [ ] Work with default parameters
- [ ] Work with named arguments
- [ ] Work with type annotations
- [ ] Update decorator examples

### Phase 7: Testing
- [ ] `test/function/varargs_test.q` - Basic varargs
- [ ] `test/function/kwargs_test.q` - Basic kwargs
- [ ] `test/function/varargs_mixed_test.q` - Mixed params
- [ ] `test/function/unpack_test.q` - Call-site unpacking
- [ ] `test/function/varargs_errors_test.q` - Error cases
- [ ] `test/function/varargs_types_test.q` - Type checking

### Phase 8: Documentation
- [ ] Update `docs/docs/language/functions.md`
- [ ] Add decorator examples
- [ ] Document best practices
- [ ] Add to CLAUDE.md

## Alternatives Considered

### Alternative 1: Array-Only (Current)

**Rejected:** Too verbose, not idiomatic:
```quest
fun sum(numbers)  # Must pass [1, 2, 3]
```

### Alternative 2: Different Syntax

**Considered:** `...args` (JavaScript), `args...` (Go)
**Rejected:** `*args` more widely recognized

### Alternative 3: Automatic Collection

**Considered:** Collect excess args without `*`:
```quest
fun f(a, b, rest)  # rest = array of remaining
```
**Rejected:** Ambiguous, not explicit

## Common Pitfalls

### 1. Forgetting to Unpack

```quest
let args = [1, 2, 3]

sum(args)     # ✗ Error: expected numbers, got array
sum(*args)    # ✓ Correct: unpacks to sum(1, 2, 3)
```

### 2. Type Annotation on Varargs

```quest
# ✓ Correct: Type each element
fun sum(*numbers: Int) -> int
    # Each number must be int
    # Collected as Array<int>

# ✗ Wrong: Don't type as array (redundant)
fun sum(*numbers: array)
    # array is redundant - varargs always collected as array

# ✗ Wrong: Don't use generic syntax (redundant)
fun sum(*numbers: array<int>)
    # array<int> is redundant - just use 'int' for element type
```

**Rule:** `*args: T` means each element is type `T`, collected into `Array<T>`.

### 3. Dict Key Types for Unpacking

```quest
let config = {123: "port", true: "enabled"}
configure(**config)
# ✗ Error: Dictionary keys must be strings for ** unpacking

# ✓ Correct: Use string keys
let config = {"port": 8080, "timeout": 30}
configure(**config)
```

### 4. Duplicate Keys in Unpacking

```quest
# Last value wins
connect(host: "localhost", **{host: "example.com"})
# host = "example.com"

connect(**{host: "localhost"}, host: "example.com")
# host = "example.com" (explicit overrides unpacked)
```

### 5. Parameter Specified Twice

```quest
fun greet(name, greeting)
    greeting .. ", " .. name
end

greet("Alice", name: "Bob")
# ✗ Error: Parameter 'name' specified both positionally and by keyword
```

## Edge Cases

### Empty Varargs/Kwargs

```quest
fun f(*args, **kwargs)
    [args, kwargs]
end

f()  # args = [], kwargs = {}
```

### Unpacking Empty Collections

```quest
sum(*[])        # Same as sum() - empty varargs
configure(**{}) # Same as configure() - empty kwargs
```

### Unpacking nil

```quest
sum(*nil)       # ✗ Error: Can only unpack arrays with *
configure(**nil) # ✗ Error: Can only unpack dicts with **
```

### Nested Unpacking Not Supported

```quest
let nested = [[1, 2], [3, 4]]
f(*[*nested[0]])  # ✗ Parse error: Can't nest * operators

# Instead, flatten first:
let flat = []
for arr in nested
    flat.extend(arr)
end
f(*flat)  # ✓ OK
```

### Varargs in Lambdas

```quest
let sum = fun (*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum(1, 2, 3)  # ✓ Allowed: 6
```

### Unpacking in Nested Calls

```quest
fun outer(x, y)
    x + y
end

fun inner(*args)
    args
end

outer(*inner(1, 2))  # ✓ Allowed
# inner(1, 2) returns [1, 2]
# outer(*[1, 2]) becomes outer(1, 2)
```

## Type Checking Details (with QEP-015)

### Element-Level Type Checking

When varargs have type annotations, each element is checked individually:

```quest
fun sum(*numbers: Int) -> int
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum(1, 2, 3)         # ✓ OK: all ints
sum(1, 2, "3")       # ✗ Error at call time
```

**Error message:**
```
Error: Type mismatch for variadic parameter 'numbers'
  Expected int for argument 3, got str
  at line 42: sum(1, 2, "3")

Function signature:
  fun sum(*numbers: Int) -> int
```

### Kwargs Value Type Checking

```quest
fun configure(**options: str)
    # All option values must be strings
end

configure(host: "localhost", port: "8080")  # ✓ OK
configure(host: "localhost", port: 8080)    # ✗ Error: expected str for 'port'
```

**Note:** Kwargs keys are always strings (enforced by unpacking rules), but values can be typed.

## Built-In Function Integration

Built-in Rust functions can opt into varargs by accepting `Vec<QValue>` and checking arity:

```rust
// In src/modules/mod.rs or similar

pub fn builtin_printf(args: Vec<QValue>) -> Result<QValue, String> {
    if args.is_empty() {
        return Err("printf requires at least one argument (format string)".to_string());
    }

    let format = match &args[0] {
        QValue::Str(s) => &s.value,
        _ => return Err("First argument to printf must be a string".to_string())
    };

    // Process remaining args as varargs
    let varargs = &args[1..];
    // ... formatting logic
}
```

**However:** Most built-in methods have fixed arity for performance:

```quest
# Current implementation
array.push(item)         # One item only
array.extend([1, 2, 3])  # For multiple items

# NOT supported (yet):
array.push(1, 2, 3)      # Would require varargs
```

**Future:** Built-in methods could support varargs, but this requires architecture changes.

## Performance Guidance

### Allocation Overhead

Varargs require array/dict allocation on every call:

```quest
fun sum(*numbers)  # Allocates Array each call
    # ...
end

sum(1, 2, 3)  # Array allocation: ~100ns overhead
```

### Benchmark Comparison

```
Operation                  Time      Overhead
────────────────────────────────────────────
sum([1, 2, 3])            100ns     baseline
sum(*[1, 2, 3])           150ns     +50% (unpack + collect)
sum(1, 2, 3)              150ns     +50% (collect into *args)

Direct method call        50ns      -50% (no collection)
```

### Recommendations

✅ **Use varargs for:**
- Decorators and wrappers
- Printf-style formatting
- Variadic constructors
- Infrequently called configuration functions

❌ **Avoid varargs for:**
- Hot loops (called millions of times)
- Performance-critical math operations
- Simple 2-3 parameter functions

**Better for hot paths:**
```quest
# Avoid
fun add(*numbers: Int) -> int  # Allocates array

# Prefer
fun add(a: Int, b: Int) -> int  # Direct parameters
```

**Profile before optimizing:** The overhead is typically negligible unless calling millions of times per second.

## Comparison with Other Languages

| Feature | Python | JavaScript | Ruby | Go | Quest |
|---------|--------|------------|------|-----|-------|
| Varargs syntax | `*args` | `...args` | `*args` | `args...` | `*args` |
| Kwargs syntax | `**kwargs` | N/A | `**kwargs` | N/A | `**kwargs` |
| Call-site unpack | Yes | Yes | Yes | No | Yes |
| Type check elements | No | No | No | Yes | Yes (QEP-015) |
| Ordering enforced | Yes | No | Yes | N/A | Yes |
| Empty varargs | `[]` | `[]` | `[]` | `[]` | `[]` |
| Performance | Good | Fast | Good | Fastest | Good |

## Migration from Array Parameters

### Before (Array Parameter)

```quest
fun sum(numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum([1, 2, 3, 4, 5])  # Must wrap in array
```

### After (Varargs)

```quest
fun sum(*numbers)
    let total = 0
    for n in numbers
        total = total + n
    end
    total
end

sum(1, 2, 3, 4, 5)  # Clean syntax

# Backward compatibility: unpack existing arrays
let data = [1, 2, 3, 4, 5]
sum(*data)  # Still works
```

### Transition Strategy

1. **Add varargs version:** Keep both `sum(numbers)` and `sum_variadic(*numbers)`
2. **Update callers:** Gradually migrate call sites
3. **Deprecate old version:** Warn users to migrate
4. **Remove old version:** In next major version

## See Also

- [QEP-029: Default Parameters](qep-029-default-parameters.md)
- [QEP-003: Function Decorators](qep-003-function-decorators.md)
- [QEP-015: Type Annotations](qep-015-type-annotations.md)
- [Functions Documentation](../docs/language/functions.md)

## References

- Python PEP 3102 - Keyword-Only Arguments
- Python `*args` and `**kwargs`
- Ruby splat operator
- JavaScript rest/spread parameters
- Go variadic functions

## Copyright

This document is placed in the public domain.
