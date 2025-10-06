# QEP 3 - Function Decorators

## Abstract

This QEP (Quest Enhancement Proposal) describes function decorators for Quest - a declarative syntax for modifying or enhancing function behavior. Decorators are class-based types that implement the `Decorator` trait and wrap functions to add functionality like logging, timing, caching, validation, and more without modifying the function's core logic.

Decorators work on any function declaration that starts with the `fun` keyword - including standalone functions, instance methods, static methods, and methods within trait implementations.

## Status

**Status:** Proposed
**Version:** 1.0
**Last Updated:** 2025-10-04

## Motivation

### Problem

Common function patterns require boilerplate code that obscures the function's core logic:

1. **Logging** - Every function call needs logging statements
2. **Timing/Profiling** - Performance measurement clutters implementation
3. **Caching** - Memoization logic mixes with business logic
4. **Validation** - Argument checks duplicate across functions
5. **Retry Logic** - Error handling for network/database failures
6. **Rate Limiting** - Throttling API calls
7. **Authorization** - Permission checks before function execution

**Example without decorators:**
```quest
fun fetch_user(user_id)
    # Logging
    puts("[INFO] Calling fetch_user with id: ", user_id)

    # Timing
    let start_time = ticks_ms()

    # Cache check
    let cache_key = "user:" .. user_id.to_string()
    if cache.contains(cache_key)
        return cache.get(cache_key)
    end

    # Retry logic
    let attempts = 0
    while attempts < 3
        try
            # Actual business logic (buried in boilerplate)
            let result = http.get("https://api.example.com/users/" .. user_id)

            # Cache storage
            cache.set(cache_key, result)

            # Timing
            puts("[TIMING] fetch_user took ", (ticks_ms() - start_time) / 1000.0, "s")

            # Logging
            puts("[INFO] fetch_user returned successfully")

            return result
        catch e
            attempts = attempts + 1
            if attempts >= 3
                raise
            end
            time.sleep(1.0)
        end
    end
end
```

### Solution

Decorators provide a clean, declarative syntax to enhance functions with cross-cutting concerns:

```quest
use "std/decorators" as dec

@dec.Log(level: "info")
@dec.Timing
@dec.Cache(ttl: 3600)
@dec.Retry(max_attempts: 3, delay: 1.0)
fun fetch_user(user_id)
    # Only business logic - no boilerplate
    return http.get("https://api.example.com/users/" .. user_id)
end
```

**Benefits:**
- **Separation of Concerns** - Cross-cutting concerns separated from business logic
- **Reusability** - Same decorator used across many functions
- **Readability** - Function intent clear from decorator names
- **Maintainability** - Change behavior by modifying decorator, not every function
- **Composability** - Stack multiple decorators to combine behaviors

## Rationale

### Why Class-Based Decorators?

Quest uses **class-based decorators** (types implementing the `Decorator` trait) rather than function-based decorators:

**Advantages:**
1. **State Management** - Decorator instances naturally maintain state (e.g., cache storage, call counts)
2. **Type Safety** - Trait implementation enforces required methods
3. **Clear Contract** - `Decorator` trait makes decorator interface explicit
4. **Introspection** - Instance-based approach enables runtime inspection
5. **Consistency** - Aligns with Quest's object-oriented type system

### Why a Decorator Trait?

The `Decorator` trait ensures all decorators implement a standard interface:

```quest
trait Decorator
    fun _call(*args, **kwargs)  # Execute the decorated function
    fun _name()                  # Preserve original function name
    fun _doc()                   # Preserve original function documentation
    fun _id()                    # Preserve original function ID
end
```

**Benefits:**
- **Consistency** - All decorators work the same way
- **Type Checking** - Compile-time verification that types can be decorators
- **Error Messages** - Clear error when non-decorator used with `@` syntax
- **Metadata Preservation** - Enforces that decorated functions preserve identity
- **Runtime Validation** - Framework can verify `implements_trait(type, "Decorator")`

### Design Decisions

#### 1. Single Underscore Prefix for Trait Methods

Uses `_call()`, `_name()`, `_doc()`, `_id()` (single underscore) following Quest's existing conventions:
- Matches `QObj` trait methods (`_str()`, `_rep()`, `_doc()`, `_id()`)
- Single underscore indicates special protocol methods
- Prevents naming conflicts with user-defined methods

#### 2. Decorator Application Order

Decorators apply **bottom to top**:

```quest
@decorator_a
@decorator_b
@decorator_c
fun my_function()
    # ...
end

# Equivalent to: decorator_a(decorator_b(decorator_c(my_function)))
```

This matches most languages (Python, TypeScript) and creates intuitive nesting where decorators closest to the function execute first.

#### 3. Works on All Function Declarations

Any declaration starting with `fun` keyword can be decorated:
- Standalone functions
- Instance methods
- Static methods
- Methods in trait implementations

This unified approach keeps the feature consistent across all contexts.

## Prerequisites

### Variadic Arguments Support

Decorators require **variadic arguments** (`*args`, `**kwargs`) for transparent argument forwarding:

```quest
# Required features
fun wrapper(*args, **kwargs)
    # Forward all arguments to wrapped function
    return original_function(*args, **kwargs)
end
```

**Without variadic support**, decorators must use fixed-arity wrappers:

```quest
type simple_decorator
    fun init(func)
        self.func = func
    end

    # Limited to 3 arguments
    fun _call(arg1?, arg2?, arg3?)
        if arg3 != nil
            return self.func(arg1, arg2, arg3)
        elif arg2 != nil
            return self.func(arg1, arg2)
        elif arg1 != nil
            return self.func(arg1)
        else
            return self.func()
        end
    end
end
```

This alternative works but limits flexibility.

## Specification

### Syntax

#### Basic Decorator

```quest
@decorator_name
fun my_function(arg1, arg2)
    # Function body
end
```

#### Decorator with Arguments

```quest
@decorator_name(arg1, arg2)
fun my_function(x)
    # Function body
end
```

#### Multiple Decorators (Stacked)

```quest
@decorator_one
@decorator_two
@decorator_three(arg)
fun my_function()
    # Decorators apply bottom to top
end
```

#### Decorators on Methods

```quest
type MyClass
    @cache
    @timing
    fun my_method(arg)
        # Instance method with decorators
    end

    @validate(x: positive)
    static fun my_static_method(x)
        # Static method with decorator
    end
end
```

### The Decorator Trait

All decorator types must implement this trait:

```quest
trait Decorator
    # Required: Make the decorator instance callable
    fun _call(*args, **kwargs)

    # Required: Preserve original function metadata
    fun _name()
    fun _doc()
    fun _id()
end
```

### Decorator Implementation

#### Basic Decorator Example

```quest
type logging_decorator
    impl Decorator
        fun _call(*args, **kwargs)
            puts("Before calling ", self.func._name())
            let result = self.func(*args, **kwargs)
            puts("After calling ", self.func._name())
            return result
        end

        fun _name()
            self.func._name()
        end

        fun _doc()
            self.func._doc()
        end

        fun _id()
            self.func._id()
        end
    end

    fun init(func)
        self.func = func
    end
end

@logging_decorator
fun greet(name)
    "Hello, " .. name
end

greet("Alice")
# Output:
# Before calling greet
# After calling greet
# Returns: "Hello, Alice"
```

#### Decorator with Configuration

```quest
type repeat_decorator
    num: times

    impl Decorator
        fun _call(*args, **kwargs)
            let results = []
            for i in 0 to self.times
                results.push(self.func(*args, **kwargs))
            end
            return results
        end

        fun _name()
            self.func._name()
        end

        fun _doc()
            self.func._doc()
        end

        fun _id()
            self.func._id()
        end
    end

    fun init(func, times)
        self.func = func
        self.times = times
    end
end

@repeat_decorator(times: 3)
fun roll_dice()
    random(1, 6)
end

puts(roll_dice())  # [4, 2, 6] (example)
```

### Decorator Execution Flow

**Declaration:**
```quest
@my_decorator
fun greet(name)
    "Hello, " .. name
end
```

**Transformation (conceptual):**
```quest
greet = my_decorator.new(greet_original)
```

**Function call:**
```quest
greet("Alice")
# Actually calls:
# greet._call("Alice")
```

### Method Decorators

#### Instance Methods

Decorators work seamlessly with instance methods - `self` is automatically passed:

```quest
use "std/decorators" as dec

type UserService
    str: api_key

    fun init(api_key)
        self.api_key = api_key
    end

    @dec.Cache(ttl: 300)
    @dec.Log
    fun get_user(user_id)
        puts("Fetching user ", user_id, " with key ", self.api_key)
        return http.get("https://api.example.com/users/" .. user_id)
    end

    @dec.Timing
    @dec.Retry(max_attempts: 3)
    fun update_user(user_id, data)
        return http.put(
            "https://api.example.com/users/" .. user_id,
            data,
            {Authorization: "Bearer " .. self.api_key}
        )
    end
end

let service = UserService.new("my-api-key")
service.get_user(123)  # Decorated method call works naturally
```

**How it works:**
1. `service.get_user(123)` automatically passes `service` as first argument
2. Decorator's `_call(*args, **kwargs)` receives `[service, 123]` as args
3. `self.func(*args, **kwargs)` forwards all arguments including self
4. Original method executes with proper `self` binding

#### Static Methods

```quest
type MathUtils
    @dec.Cache(max_size: 100)
    static fun fibonacci(n)
        if n <= 1
            return n
        end
        return MathUtils.fibonacci(n - 1) + MathUtils.fibonacci(n - 2)
    end
end

MathUtils.fibonacci(50)  # Cached
```

## Built-in Decorators

The `std/decorators` module provides standard decorator types:

### Cache - Memoization

```quest
use "std/decorators" as dec

@dec.Cache(max_size: 128, ttl: 3600)
fun expensive_query(query_id)
    # Results cached with max 128 entries, 1 hour TTL
end
```

### Timing - Execution Measurement

```quest
@dec.Timing(threshold: 1.0)
fun expensive_operation()
    # Only logs if execution takes > 1 second
end
```

### Log - Function Call Logging

```quest
@dec.Log(level: "debug", include_result: false)
fun process_data(items)
    # Logs call but not result
end
```

### Retry - Automatic Retry Logic

```quest
@dec.Retry(max_attempts: 3, delay: 1.0, backoff: 2.0)
fun fetch_data(url)
    # Retries up to 3 times with exponential backoff
end
```

### Other Built-in Decorators

- `dec.Validate` - Argument validation
- `dec.Deprecated` - Deprecation warnings
- `dec.RateLimit` - Call rate limiting
- `dec.Once` - Execute only once
- `dec.Synchronized` - Thread-safe execution (future)

See full documentation in the [Built-in Decorators](#built-in-decorators-full) section.

## Implementation Details

### Grammar Changes

Add decorator syntax to function declarations:

```pest
# Standalone function declarations
function_declaration = {
    decorator* ~ "fun" ~ identifier ~ parameter_list ~ statement* ~ "end"
}

# Static method declarations
static_method = {
    decorator* ~ "static" ~ "fun" ~ identifier ~ parameter_list ~ statement* ~ "end"
}

# Instance method declarations
method_declaration = {
    decorator* ~ "fun" ~ identifier ~ parameter_list ~ statement* ~ "end"
}

decorator = {
    "@" ~ decorator_expression
}

decorator_expression = {
    identifier ~ ("." ~ identifier)* ~ decorator_args?
}

decorator_args = {
    "(" ~ (expression ~ ("," ~ expression)*)? ~ ")"
}
```

### Decorator Application Algorithm

```rust
fn eval_function_declaration(
    decorators: Vec<DecoratorExpr>,
    func_name: &str,
    params: Vec<String>,
    body: Vec<Statement>,
    scope: &mut Scope
) -> Result<(), String> {
    // 1. Create the original function
    let func = QUserFun::new(func_name.to_string(), params, body);
    let mut func_value = QValue::UserFun(func);

    // 2. Apply decorators in reverse order (bottom to top)
    for decorator in decorators.iter().rev() {
        func_value = apply_decorator(decorator, func_value, scope)?;
    }

    // 3. Store decorated function in scope
    scope.set(func_name, func_value);

    Ok(())
}
```

### Decorator Instantiation

```rust
fn apply_decorator(
    decorator_expr: &DecoratorExpr,
    func: QValue,
    scope: &mut Scope
) -> Result<QValue, String> {
    match decorator_expr {
        // @decorator_type
        DecoratorExpr::Simple(type_name) => {
            let decorator_type = scope.get(type_name)?;
            construct_decorator(decorator_type, func, vec![])
        }

        // @decorator_type(arg1, arg2, ...)
        DecoratorExpr::WithArgs(type_name, args) => {
            let decorator_type = scope.get(type_name)?;
            let arg_values = eval_args(args, scope)?;
            construct_decorator(decorator_type, func, arg_values)
        }
    }
}

fn construct_decorator(
    decorator_type: QValue,
    func: QValue,
    args: Vec<QValue>
) -> Result<QValue, String> {
    match decorator_type {
        QValue::Type(type_def) => {
            // Verify type implements Decorator trait
            if !implements_trait(&type_def, "Decorator") {
                return Err(format!(
                    "Type '{}' must implement Decorator trait",
                    type_def.name
                ));
            }

            // Build constructor arguments: [func, ...other_args]
            let mut constructor_args = vec![func];
            constructor_args.extend(args);

            // Call Type.new(func, ...args)
            construct_type_instance(&type_def, constructor_args)
        }
        _ => Err("Decorator must be a type".to_string())
    }
}
```

### Making Instances Callable

When a decorated function is called, Quest invokes `_call()` on the decorator instance:

```rust
fn call_value(value: &QValue, args: Vec<QValue>) -> Result<QValue, String> {
    match value {
        QValue::UserFun(func) => {
            execute_user_function(func, args)
        }

        QValue::Struct(struct_inst) => {
            // Check if struct has _call() method
            if let Some(call_method) = get_method(struct_inst, "_call") {
                call_method.call_with_self(struct_inst, args)
            } else {
                Err(format!(
                    "Type '{}' is not callable",
                    struct_inst.type_name
                ))
            }
        }

        _ => Err(format!("Value is not callable"))
    }
}
```

## Best Practices

### 1. Always Implement the Decorator Trait

```quest
# Good: Explicit trait implementation
type my_decorator
    impl Decorator
        fun _call(*args, **kwargs)
            return self.func(*args, **kwargs)
        end

        fun _name()
            self.func._name()
        end

        fun _doc()
            self.func._doc()
        end

        fun _id()
            self.func._id()
        end
    end

    fun init(func)
        self.func = func
    end
end
```

### 2. Order Decorators Carefully

```quest
# Correct: Log final result after all retries
@dec.Log
@dec.Retry(max_attempts: 3)
fun fetch_data()
    # Logs final result
end

# Wrong: Log every retry attempt (may be noisy)
@dec.Retry(max_attempts: 3)
@dec.Log
fun fetch_data()
    # Logs each attempt
end
```

### 3. Preserve Function Metadata

All decorators must delegate metadata methods to preserve original function identity.

### 4. Document Decorator Side Effects

```quest
"""
Fetch user data from API.

@dec.Cache: Results cached for 1 hour
@dec.Retry: Retries up to 3 times on network errors
"""
@dec.Cache(ttl: 3600)
@dec.Retry(max_attempts: 3)
fun fetch_user(user_id)
    # ...
end
```

## Limitations

1. **Requires variadic arguments** - Full functionality needs `*args`/`**kwargs` support
2. **No decorator on lambdas** - Only works on `fun` declarations
3. **No type/class decorators** - Only function decorators supported
4. **Performance overhead** - Each decorator adds method dispatch overhead
5. **Debugging complexity** - Stack traces include decorator wrappers

## Future Enhancements

1. **Variadic arguments** - Full `*args`/`**kwargs` support (prerequisite)
2. **Property decorators** - `@property`, `@computed` for class properties
3. **Async decorators** - Support for async functions (if Quest adds async/await)
4. **Decorator composition** - Built-in helpers to combine decorators
5. **Built-in profiler integration** - Automatic profiling support
6. **IDE support** - Autocomplete and type checking for decorators

## Open Questions

See the [Open Questions](#open-questions-full) section in the appendix for detailed discussion of:

1. Function-based vs class-based decorators
2. Decorator factory pattern
3. Type/class decorators
4. Accessing decorator instance members
5. Unwrapping and introspection
6. Module-qualified decorators
7. Testing decorators
8. Lambda and closure decoration
9. Error handling and stack traces
10. Decorator composition and reusability

## Complete Examples

### API Client with Retry and Logging

```quest
use "std/decorators" as dec
use "std/http" as http

@dec.Log(level: "info")
@dec.Retry(max_attempts: 3, delay: 1.0, backoff: 2.0)
@dec.Timing
fun fetch_user(user_id)
    let response = http.get("https://api.example.com/users/" .. user_id)
    return json.parse(response.body)
end

try
    let user = fetch_user(123)
    puts("User: ", user.name)
catch e: NetworkError
    puts("Failed after retries: ", e.message())
end
```

### Database Repository with Decorators

```quest
use "std/decorators" as dec
use "std/db/postgres" as db

type UserRepository
    connection: conn

    fun init(connection_string)
        self.conn = db.connect(connection_string)
    end

    @dec.Cache(ttl: 60)
    @dec.Log(level: "debug")
    fun find_by_id(user_id)
        let cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM users WHERE id = $1", [user_id])
        let result = cursor.fetch_one()
        cursor.close()
        return result
    end

    @dec.Log(level: "info")
    @dec.Retry(max_attempts: 2)
    fun create(user_data)
        let cursor = self.conn.cursor()
        cursor.execute(
            "INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id",
            [user_data.name, user_data.email]
        )
        let result = cursor.fetch_one()
        cursor.close()
        self.conn.commit()
        return result
    end

    @dec.Timing
    fun find_all()
        let cursor = self.conn.cursor()
        cursor.execute("SELECT * FROM users")
        let results = cursor.fetch_all()
        cursor.close()
        return results
    end
end
```

## Appendix

### Built-in Decorators (Full)

[Full implementations of Cache, Timing, Log, Retry, and other decorators from the original spec...]

### Open Questions (Full)

[Complete open questions section from the original spec covering decorator factories, composition, introspection, etc...]

## See Also

- [Functions](../docs/functions.md) - Function declaration and usage
- [Type System](../docs/types.md) - Quest type system
- [Validation](validation.md) - Validation system (uses similar patterns)

## References

This QEP draws inspiration from decorator implementations in:
- Python PEP 318 - Decorators for Functions and Methods
- TypeScript Decorators
- Java Annotations
- C# Attributes

## Copyright

This document is placed in the public domain.
