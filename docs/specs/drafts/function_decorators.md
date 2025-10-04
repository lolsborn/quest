# Function Decorators

**Status:** Draft
**Version:** 1.0
**Last Updated:** 2025-10-03

## Overview

Quest supports **function decorators** that allow modifying or enhancing function behavior declaratively. Decorators are class-based types that implement the `Decorator` trait and wrap functions to add functionality like logging, timing, caching, validation, and more without modifying the function's core logic.

Decorators work on **any function declaration** that starts with the `fun` keyword - including standalone functions, instance methods, static methods, and methods within trait implementations.

## Motivation

**Problem:** Common function patterns require boilerplate:
1. Logging function calls and results
2. Timing/profiling function execution
3. Caching expensive function results
4. Validating function arguments
5. Implementing retry logic for failures
6. Rate limiting function calls
7. Authorization/permission checks

**Solution:** Decorators provide a clean, declarative syntax to enhance functions with cross-cutting concerns, keeping the function's core logic focused and readable.

## Prerequisites

### Variadic Arguments Support

This decorator system requires support for variadic arguments (*args) and keyword arguments (**kwargs) to properly forward arguments to wrapped functions.

**Required features:**
```quest
# Variadic positional arguments
fun my_function(*args)
    # args is an array of all positional arguments
    puts("Received ", args.len(), " arguments")
end

# Keyword arguments
fun my_function(**kwargs)
    # kwargs is a dict of all keyword arguments
    puts("Received keys: ", kwargs.keys())
end

# Combined
fun my_function(*args, **kwargs)
    # Both positional and keyword arguments
end

# Argument forwarding
fun wrapper(*args, **kwargs)
    # Forward all arguments to another function
    return original_function(*args, **kwargs)
end
```

**Note:** If variadic arguments are not yet implemented in Quest, decorators can be implemented with fixed-arity wrappers or require explicit argument specification:

```quest
# Alternative without variadic arguments
type SimpleDecorator
    fun init(func)
        self.func = func
    end

    # Manually handle different arities
    fun _call(arg1?, arg2?, arg3?)
        # Limited to 3 arguments
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

This alternative approach is less flexible but works without variadic argument support.

## Syntax

### Basic Decorator

```quest
@decorator_name
fun my_function(arg1, arg2)
    # Function body
end
```

### Decorator with Arguments

```quest
@decorator_name(arg1, arg2)
fun my_function(x)
    # Function body
end
```

### Multiple Decorators (Stacked)

```quest
@decorator_one
@decorator_two
@decorator_three(arg)
fun my_function()
    # Decorators apply from bottom to top
    # decorator_three wraps the function first
    # decorator_two wraps decorator_three's result
    # decorator_one wraps decorator_two's result
end
```

### Decorators on Methods

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

## The Decorator Trait

All decorator types must implement the `Decorator` trait, which defines the interface for wrapping and calling functions:

```quest
trait Decorator
    # Required: Make the decorator instance callable
    # Uses _call (single underscore) to prevent naming conflicts
    fun _call(*args, **kwargs)

    # Required: Preserve original function metadata
    # Single underscore follows Quest's metadata method conventions
    fun _name()
    fun _doc()
    fun _id()
end
```

**Method naming conventions:**
- `_call()` - Single underscore indicates special protocol method (Quest convention)
- `_name()`, `_doc()`, `_id()` - Single underscore for metadata methods (Quest convention from QObj trait)
- All decorator trait methods use single underscore prefix for consistency
- These prefixes prevent naming conflicts with user-defined methods

**Note:** The trait does NOT specify `init()` because:
- `init()` is a constructor, not part of the trait interface
- Different decorators have different `init()` signatures
- `init(func)` for simple decorators
- `init(func, param1, param2, ...)` for decorators with configuration

**Why a trait?**
- **Consistency:** Ensures all decorators have a standard interface
- **Type Safety:** Enables compile-time checking that types can be used as decorators
- **Explicit Intent:** Makes it clear which types are designed to be decorators
- **Runtime Checking:** Allows framework code to verify `implements_trait(type, "Decorator")`
- **Metadata Preservation:** Enforces that all decorators preserve function metadata
- **Error Messages:** Provides clear error when a non-decorator type is used with `@` syntax
- **Naming Safety:** `_call` prefix prevents conflicts with regular methods

**Example implementation:**
```quest
type MyDecorator
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
```

**Error handling:**
```quest
# Type without Decorator trait
type NotADecorator
    fun init(func)
        self.func = func
    end
end

@NotADecorator
fun my_function()
    # ...
end
# Error: Type 'NotADecorator' must implement Decorator trait to be used as decorator
```

## How Decorators Work

Decorators in Quest are **class-based** - they are types that implement the `Decorator` trait. When a decorator is applied, an instance is created and wraps the original function.

### Basic Class-Based Decorator

```quest
type MyDecorator
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

@MyDecorator
fun greet(name)
    "Hello, " .. name
end

greet("Alice")
# Output:
# Before calling greet
# After calling greet
# Returns: "Hello, Alice"
```

**How it works:**
1. `@MyDecorator` creates an instance: `decorator_instance = MyDecorator.new(greet)`
2. The `init()` method stores the original function
3. When `greet("Alice")` is called, it actually calls `decorator_instance._call("Alice")`
4. The `_call()` method wraps the original function with additional behavior
5. Metadata methods delegate to the original function

### Decorator Execution Flow

```quest
# Original declaration
@MyDecorator
fun greet(name)
    "Hello, " .. name
end

# Transformed to (conceptually):
greet = MyDecorator.new(greet_original)

# When calling
greet("Alice")
# Actually calls:
greet.call("Alice")
```

## Built-in Decorators

Quest provides several built-in decorators for common patterns:

### @cache - Memoization Decorator

Caches function results based on arguments:

```quest
use "std/decorators" as dec

@dec.Cache
fun fibonacci(n)
    if n <= 1
        return n
    end
    fibonacci(n - 1) + fibonacci(n - 2)
end

fibonacci(100)  # Computed once, cached for subsequent calls
```

**With options:**
```quest
@dec.Cache(max_size: 128, ttl: 3600)
fun expensive_query(query_id)
    # Results cached with max 128 entries, 1 hour TTL
end
```

**Implementation:**
```quest
type Cache
    dict?: cache_storage
    num?: max_size
    num?: ttl

    fun init(func, max_size, ttl)
        self.func = func
        self.cache_storage = {}
        self.max_size = max_size
        self.ttl = ttl
    end

    fun _call(*args, **kwargs)
        let key = self.make_key(args, kwargs)

        if self.cache_storage.has(key)
            let entry = self.cache_storage[key]

            # Check TTL if set
            if self.ttl != nil
                if ticks_ms() - entry.timestamp > self.ttl * 1000
                    # Expired
                    del self.cache_storage[key]
                else
                    return entry.value
                end
            else
                return entry.value
            end
        end

        # Cache miss - compute result
        let result = self.func(*args, **kwargs)

        # Store in cache
        self.cache_storage[key] = {
            value: result,
            timestamp: ticks_ms()
        }

        # Evict if over max_size (LRU)
        if self.max_size != nil and self.cache_storage.len() > self.max_size
            self.evict_oldest()
        end

        return result
    end

    fun make_key(args, kwargs)
        # Generate cache key from arguments
        json.stringify([args, kwargs])
    end

    fun evict_oldest()
        # LRU eviction logic
    end
end
```

### @Timing - Execution Time Measurement

Measures and logs function execution time:

```quest
@dec.Timing
fun expensive_operation()
    # ... complex computation ...
end

expensive_operation()
# [TIMING] expensive_operation: 1.234s
```

**With options:**
```quest
@dec.Timing(label: "Database query", threshold: 1.0)
fun query_database(query)
    # Only logs if execution takes > 1 second
end
```

**Implementation:**
```quest
type Timing
    str?: label
    num?: threshold

    fun init(func, label, threshold)
        self.func = func
        self.label = label or func._name()
        self.threshold = threshold
    end

    fun _call(*args, **kwargs)
        let start = ticks_ms()
        let result = self.func(*args, **kwargs)
        let duration = (ticks_ms() - start) / 1000.0

        if self.threshold == nil or duration > self.threshold
            puts("[TIMING] ", self.label, ": ", duration, "s")
        end

        return result
    end
end
```

### @Log - Function Call Logging

Logs function calls with arguments and results:

```quest
@dec.Log
fun calculate(x, y)
    x + y
end

calculate(5, 3)
# [LOG] calculate(5, 3) -> 8
```

**With options:**
```quest
@dec.Log(level: "debug", include_result: false)
fun process_data(items)
    # Logs call but not result
end
```

**Implementation:**
```quest
type Log
    str: level
    bool: include_args
    bool: include_result

    fun init(func, level, include_args, include_result)
        self.func = func
        self.level = level or "info"
        self.include_args = include_args != false  # Default true
        self.include_result = include_result != false  # Default true
    end

    fun _call(*args, **kwargs)
        let func_name = self.func._name()

        # Log call
        if self.include_args
            puts("[", self.level.upper(), "] ", func_name, "(", args, ")")
        else
            puts("[", self.level.upper(), "] ", func_name, "()")
        end

        # Execute function
        let result = self.func(*args, **kwargs)

        # Log result
        if self.include_result
            puts("[", self.level.upper(), "] ", func_name, " -> ", result)
        end

        return result
    end
end
```

### @Retry - Automatic Retry Logic

Retries function on failure with exponential backoff:

```quest
@dec.Retry(max_attempts: 3, delay: 1.0)
fun fetch_data(url)
    # May fail due to network issues
    http.get(url)
end

fetch_data("https://api.example.com/data")
# Retries up to 3 times with 1 second delay between attempts
```

**With all options:**
```quest
@dec.Retry(
    max_attempts: 5,
    delay: 1.0,
    backoff: 2.0,              # Exponential backoff multiplier
    exceptions: [NetworkError] # Only retry on specific exceptions
)
fun api_request(endpoint)
    # Sophisticated retry logic
end
```

**Implementation:**
```quest
use "std/time" as time

type Retry
    num: max_attempts
    num: delay
    num: backoff
    array?: exceptions

    fun init(func, max_attempts, delay, backoff, exceptions)
        self.func = func
        self.max_attempts = max_attempts or 3
        self.delay = delay or 1.0
        self.backoff = backoff or 1.0
        self.exceptions = exceptions
    end

    fun _call(*args, **kwargs)
        let attempt = 0
        let current_delay = self.delay

        while attempt < self.max_attempts
            try
                return self.func(*args, **kwargs)
            catch e
                attempt = attempt + 1

                # Check if we should retry this exception
                if self.exceptions != nil and not self.should_retry(e)
                    raise
                end

                # Last attempt - don't retry
                if attempt >= self.max_attempts
                    raise
                end

                # Wait before retry
                puts("[RETRY] Attempt ", attempt, " failed: ", e.message())
                puts("[RETRY] Retrying in ", current_delay, "s...")
                time.sleep(current_delay)

                # Exponential backoff
                current_delay = current_delay * self.backoff
            end
        end
    end

    fun should_retry(exception)
        for exc_type in self.exceptions
            if exception.is(exc_type)
                return true
            end
        end
        return false
    end
end
```

### @validate

Validates function arguments using type system:

```quest
use "std/validate" as v

@dec.validate(
    x: v.range(0, 100),
    y: v.range(0, 100)
)
fun plot_point(x, y)
    puts("Plotting at (", x, ", ", y, ")")
end

plot_point(50, 75)   # OK
plot_point(150, 75)  # ValidationError: x must be between 0 and 100
```

### @deprecated

Marks function as deprecated:

```quest
@dec.deprecated(
    reason: "Use new_function() instead",
    version: "2.0.0"
)
fun old_function()
    # Legacy implementation
end

old_function()
# [WARN] old_function is deprecated (since 2.0.0): Use new_function() instead
```

### @rate_limit

Limits function call rate:

```quest
@dec.rate_limit(calls: 10, period: 60)  # 10 calls per 60 seconds
fun api_request(endpoint)
    http.get("https://api.example.com" .. endpoint)
end

# After 10 calls in 60 seconds, raises RateLimitError
```

### @once

Ensures function executes only once:

```quest
@dec.once
fun initialize()
    puts("Initializing system...")
    # Expensive one-time setup
end

initialize()  # Runs
initialize()  # Does nothing (returns cached result)
initialize()  # Does nothing
```

### @synchronized

Ensures thread-safe execution (if Quest adds threading):

```quest
@dec.synchronized
fun update_counter()
    # Only one thread can execute at a time
    counter = counter + 1
end
```

## Method Decorators

Decorators work on **any function declaration** - including methods inside types. Any function that starts with `fun` can be decorated, whether it's a standalone function, an instance method, or a static method.

### Instance Methods

Decorators work seamlessly with instance methods. The decorator's `_call()` receives `self` as the first argument automatically:

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
        # Cache per instance - different UserService instances have separate caches
        puts("Fetching user ", user_id, " with key ", self.api_key)
        return http.get("https://api.example.com/users/" .. user_id)
    end

    @dec.Timing
    @dec.Retry(max_attempts: 3)
    fun update_user(user_id, data)
        # Can access self.api_key inside decorator chain
        return http.put(
            "https://api.example.com/users/" .. user_id,
            data,
            {Authorization: "Bearer " .. self.api_key}
        )
    end
end

let service = UserService.new("my-api-key")
service.get_user(123)  # Decorated method call works naturally
service.get_user(123)  # Cache hit!
```

**How it works:**
1. When `service.get_user(123)` is called, Quest automatically passes `service` as the first argument
2. The decorator's `_call(*args, **kwargs)` receives `[service, 123]` as args
3. When calling `self.func(*args, **kwargs)`, it forwards all arguments including self
4. The original method executes with proper `self` binding

### Static Methods

Decorators also work on static methods:

```quest
type MathUtils
    @dec.Cache(max_size: 100)
    static fun fibonacci(n)
        if n <= 1
            return n
        end
        return MathUtils.fibonacci(n - 1) + MathUtils.fibonacci(n - 2)
    end

    @dec.Timing(threshold: 0.1)
    static fun expensive_calculation(x, y)
        # Complex computation
        return result
    end
end

# Call static methods normally
MathUtils.fibonacci(50)  # Cached
MathUtils.fibonacci(50)  # Cache hit
```

### Practical Example: Database Repository

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
        cursor.execute(
            "SELECT * FROM users WHERE id = $1",
            [user_id]
        )
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

let repo = UserRepository.new("postgresql://localhost/mydb")
let user = repo.find_by_id(1)      # Cached per instance
let all_users = repo.find_all()     # Timed
```

### Method Decorator Caveats

**1. Cache scope is per instance:**

```quest
type Service
    @dec.Cache
    fun get_data(id)
        # ...
    end
end

let service1 = Service.new()
let service2 = Service.new()

service1.get_data(1)  # Cache miss
service2.get_data(1)  # Cache miss (different cache)
service1.get_data(1)  # Cache hit (same instance)
```

**2. Decorating methods in trait implementations:**

```quest
trait Fetchable
    fun fetch(id)
end

type User
    impl Fetchable
        @dec.Cache
        @dec.Retry(max_attempts: 3)
        fun fetch(id)
            # Decorators work inside impl blocks
            return api.get_user(id)
        end
    end
end
```

**3. Private/internal methods can be decorated:**

```quest
type Calculator
    @dec.Cache
    fun _expensive_helper(n)
        # Private method (convention: underscore prefix)
        # Still benefits from caching
        return complex_computation(n)
    end

    fun calculate(x)
        return self._expensive_helper(x) * 2
    end
end
```

## User-Defined Decorators

### Simple Decorator

```quest
type UppercaseResult
    impl Decorator
        fun _call(*args, **kwargs)
            let result = self.func(*args, **kwargs)
            return result.upper()
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

@UppercaseResult
fun greet(name)
    "hello, " .. name
end

puts(greet("alice"))  # "HELLO, ALICE"
```

### Decorator with Parameters

Decorator types can accept configuration parameters in their `init()` method:

```quest
type Repeat
    num: times

    impl Decorator
        fun _call(*args, **kwargs)
            let results = []
            for i in range(self.times)
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

@Repeat(times: 3)
fun roll_dice()
    random(1, 6)
end

puts(roll_dice())  # [4, 2, 6] (example)
```

### Decorator with State

Decorators naturally maintain state between calls:

```quest
type CountCalls
    num: call_count

    fun init(func)
        self.func = func
        self.call_count = 0
    end

    fun _call(*args, **kwargs)
        self.call_count = self.call_count + 1
        puts("Call #", self.call_count, " to ", self.func._name())
        return self.func(*args, **kwargs)
    end

    # Method to access state
    fun get_count()
        self.call_count
    end
end

@CountCalls
fun process_item(item)
    puts("Processing: ", item)
end

process_item("A")
process_item("B")
process_item("C")
puts("Total calls: ", process_item.get_count())

# Output:
# Call #1 to process_item
# Processing: A
# Call #2 to process_item
# Processing: B
# Call #3 to process_item
# Processing: C
# Total calls: 3
```

## Preserving Function Metadata

Decorators should preserve original function metadata by delegating metadata methods:

```quest
type MyDecorator
    fun init(func)
        self.func = func
    end

    fun _call(*args, **kwargs)
        return self.func(*args, **kwargs)
    end

    # Delegate metadata methods to original function
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

@MyDecorator
fun important_function()
    """This function does important things."""
    # Implementation
end

puts(important_function._name())  # "important_function"
puts(important_function._doc())   # "This function does important things."
```

**Best Practice:** All decorator types should implement these metadata methods:
- `_name()` - Return original function name
- `_doc()` - Return original documentation
- `_id()` - Return original function ID
- `_signature()` - Return parameter information (if applicable)

## Complete Examples

### Example 1: API Client with Retry and Logging

```quest
use "std/decorators" as dec
use "std/http" as http

@dec.log(level: "info")
@dec.retry(max_attempts: 3, delay: 1.0, backoff: 2.0)
@dec.timing
fun fetch_user(user_id)
    let response = http.get("https://api.example.com/users/" .. user_id)
    return json.parse(response.body)
end

try
    let user = fetch_user(123)
    puts("User: ", user.name)
catch e: NetworkError
    puts("Failed to fetch user after retries: ", e.message())
end

# Output (example):
# [TIMING] fetch_user: 0.234s
# [LOG] fetch_user(123) -> {"id": 123, "name": "Alice", ...}
# User: Alice
```

### Example 2: Authorization Decorator

```quest
use "std/decorators" as dec

fun require_auth(required_role)
    fun decorator(func)
        fun wrapper(*args, **kwargs)
            # Get current user from context (implementation-specific)
            let current_user = get_current_user()

            if current_user == nil
                raise AuthorizationError("Authentication required")
            end

            if not current_user.has_role(required_role)
                raise AuthorizationError("Insufficient permissions")
            end

            return func(*args, **kwargs)
        end
        return wrapper
    end
    return decorator
end

@require_auth("admin")
fun delete_user(user_id)
    # Only admins can delete users
    database.delete("users", user_id)
end

@require_auth("moderator")
fun ban_user(user_id)
    # Moderators and admins can ban users
    database.update("users", user_id, {banned: true})
end
```

### Example 3: Database Transaction Decorator

```quest
use "std/db/postgres" as db

fun transaction(func)
    fun wrapper(*args, **kwargs)
        let conn = db.connect(CONNECTION_STRING)

        try
            let result = func(conn, *args, **kwargs)
            conn.commit()
            return result
        catch e
            conn.rollback()
            raise
        ensure
            conn.close()
        end
    end
    return wrapper
end

@transaction
fun transfer_funds(conn, from_account, to_account, amount)
    # Automatically wrapped in transaction
    let cursor = conn.cursor()

    cursor.execute(
        "UPDATE accounts SET balance = balance - $1 WHERE id = $2",
        [amount, from_account]
    )

    cursor.execute(
        "UPDATE accounts SET balance = balance + $1 WHERE id = $2",
        [amount, to_account]
    )

    cursor.close()
end

transfer_funds(account_a, account_b, 100.0)
```

### Example 4: Caching with Custom Key Function

```quest
use "std/decorators" as dec

fun cached_by(key_func)
    let cache = {}

    fun decorator(func)
        fun wrapper(*args, **kwargs)
            let key = key_func(*args, **kwargs)

            if cache.has(key)
                puts("Cache hit for key: ", key)
                return cache[key]
            end

            puts("Cache miss for key: ", key)
            let result = func(*args, **kwargs)
            cache[key] = result
            return result
        end
        return wrapper
    end
    return decorator
end

@cached_by(fun(user_id, _options) user_id end)
fun fetch_user_profile(user_id, options)
    # Options don't affect cache key, only user_id does
    puts("Fetching profile for user: ", user_id)
    # ... fetch from database ...
end

fetch_user_profile(123, {include_posts: true})   # Cache miss
fetch_user_profile(123, {include_posts: false})  # Cache hit (ignores options)
fetch_user_profile(456, {include_posts: true})   # Cache miss (different user)
```

## Implementation Details

### Grammar Changes

Add decorator syntax to all function declarations (standalone functions, instance methods, static methods):

```pest
# Standalone function declarations
function_declaration = {
    decorator* ~ "fun" ~ identifier ~ parameter_list ~ statement* ~ "end"
}

# Static method declarations
static_method = {
    decorator* ~ "static" ~ "fun" ~ identifier ~ parameter_list ~ statement* ~ "end"
}

# Instance method declarations (inside type or impl blocks)
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

**Note:** Decorators can appear on any function declaration starting with `fun` keyword, regardless of context (standalone, inside type definition, inside impl block).

### Decorator Application Order

Decorators apply from bottom to top:

```quest
@decorator_a
@decorator_b
@decorator_c
fun my_function()
    # Original implementation
end

# Equivalent to:
# my_function = decorator_a(decorator_b(decorator_c(my_function)))
```

### Evaluation Timing

Decorators are applied at function definition time:

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

### Decorator Application

Class-based decorators are applied by instantiating the decorator type:

```rust
fn apply_decorator(
    decorator_expr: &DecoratorExpr,
    func: QValue,
    scope: &mut Scope
) -> Result<QValue, String> {
    // Evaluate decorator expression to get type or instance
    match decorator_expr {
        // @DecoratorType
        DecoratorExpr::Simple(type_name) => {
            // Look up decorator type
            let decorator_type = scope.get(type_name)
                .ok_or(format!("Decorator '{}' not found", type_name))?;

            // Call constructor: DecoratorType.new(func)
            construct_decorator(decorator_type, func, vec![])
        }

        // @DecoratorType(arg1, arg2, ...)
        DecoratorExpr::WithArgs(type_name, args) => {
            // Look up decorator type
            let decorator_type = scope.get(type_name)
                .ok_or(format!("Decorator '{}' not found", type_name))?;

            // Evaluate arguments
            let arg_values: Vec<QValue> = args.iter()
                .map(|arg| eval_expression(arg, scope))
                .collect::<Result<Vec<_>, _>>()?;

            // Call constructor: DecoratorType.new(func, arg1, arg2, ...)
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
                    "Type '{}' must implement Decorator trait to be used as decorator",
                    type_def.name
                ));
            }

            // Build constructor arguments: [func, ...other_args]
            let mut constructor_args = vec![func];
            constructor_args.extend(args);

            // Call Type.new(func, ...args)
            let instance = construct_type_instance(&type_def, constructor_args)?;

            // Verify Decorator trait methods are present
            // (Should be guaranteed by trait implementation, but double-check)
            if let QValue::Struct(struct_inst) = &instance {
                for required_method in &["_call", "_name", "_doc", "_id"] {
                    if !has_method(&type_def, required_method) {
                        return Err(format!(
                            "Decorator type '{}' is missing required method '{}' from Decorator trait",
                            type_def.name,
                            required_method
                        ));
                    }
                }
            }

            Ok(instance)
        }
        _ => Err("Decorator must be a type".to_string())
    }
}

fn implements_trait(type_def: &QType, trait_name: &str) -> bool {
    type_def.implemented_traits.contains(&trait_name.to_string())
}
```

### Making Instances Callable

When a decorated function is called, Quest invokes the `_call()` method on the decorator instance:

```rust
fn call_value(value: &QValue, args: Vec<QValue>) -> Result<QValue, String> {
    match value {
        QValue::UserFun(func) => {
            // Regular function call
            execute_user_function(func, args)
        }

        QValue::Fun(native_func) => {
            // Native Rust function call
            native_func.call(args)
        }

        QValue::Struct(struct_inst) => {
            // Check if struct has _call() method
            // This makes decorator instances callable
            if let Some(call_method) = get_method(struct_inst, "_call") {
                call_method.call_with_self(struct_inst, args)
            } else {
                Err(format!(
                    "Type '{}' is not callable (missing _call() method)",
                    struct_inst.type_name
                ))
            }
        }

        _ => Err(format!("Value of type '{}' is not callable", value.cls()))
    }
}
```

## Standard Library Support

The `std/decorators` module provides all built-in decorator types:

### Built-in Decorator Types

```quest
use "std/decorators" as dec

# All decorator types available as dec.TypeName
@dec.Cache(max_size: 100, ttl: 3600)
@dec.Timing(threshold: 1.0)
@dec.Log(level: "debug")
@dec.Retry(max_attempts: 3, delay: 1.0)
fun my_function(x, y)
    # ...
end
```

### Available Decorators

- `dec.Cache` - Memoization with LRU and TTL support
- `dec.Timing` - Execution time measurement
- `dec.Log` - Function call logging
- `dec.Retry` - Automatic retry with backoff
- `dec.Validate` - Argument validation
- `dec.Deprecated` - Deprecation warnings
- `dec.RateLimit` - Rate limiting
- `dec.Once` - Execute only once
- `dec.Synchronized` - Thread-safe execution (future)

## Best Practices

### 1. Always Implement the Decorator Trait

```quest
# Good: Explicitly implements Decorator trait
type MyDecorator
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

# Bad: No trait implementation
type MyDecorator
    fun init(func)
        self.func = func
    end

    fun _call(*args, **kwargs)
        return self.func(*args, **kwargs)
    end

    # Will fail at decoration time - missing Decorator trait
end
```

### 2. Preserve Function Metadata by Delegating

All decorators must delegate metadata methods to preserve the original function's identity:

```quest
# Good: All metadata methods delegate to original function
impl Decorator
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

# Bad: Missing metadata methods (won't implement Decorator trait)
impl Decorator
    fun _call(*args, **kwargs)
        self.func(*args, **kwargs)
    end
    # Missing _name(), _doc(), _id()
end
```

### 3. Order Decorators Carefully

```quest
# Correct: Log after retry completes
@dec.Log
@dec.Retry(max_attempts: 3)
fun fetch_data()
    # Logs final result after all retries
end

# Wrong: Log every retry attempt
@dec.Retry(max_attempts: 3)
@dec.Log
fun fetch_data()
    # Logs each retry attempt (may be noisy)
end
```

### 4. Use Meaningful Names

```quest
# Good: Clear purpose and naming
@dec.Cache(ttl: 3600)
@RequireAuthentication
fun get_user_profile(user_id)
    # ...
end

# Bad: Unclear purpose
@Cached
@Auth
fun gup(uid)
    # ...
end
```

### 5. Document Decorator Side Effects

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

1. **Requires variadic arguments** - Full decorator functionality requires `*args` and `**kwargs` support for transparent argument forwarding. Without this, decorators must explicitly handle different arities or use alternative patterns (see Prerequisites section).

2. **No decorator on lambdas** - Decorators only work on function declarations that start with `fun` keyword (standalone functions, instance methods, static methods). Anonymous lambdas cannot be decorated.

3. **No class/type decorators** - Only function decorators are supported (types use different mechanisms like traits and validation).

4. **Performance overhead** - Each decorator adds function call overhead through the `_call()` method dispatch.

5. **Debugging complexity** - Stack traces include decorator wrappers, making it harder to trace errors to original function.

6. **No decorator composition helpers** - Cannot easily combine multiple decorators into a single decorator without manual implementation.

## Future Enhancements

1. **Variadic arguments** - Full `*args` and `**kwargs` support for transparent argument forwarding (prerequisite for full decorator functionality)

2. **Property decorators** - Define computed properties with decorator syntax (e.g., `@property`, `@computed`)

3. **Async decorators** - Support for async functions if Quest adds async/await

4. **Decorator composition** - Built-in helpers to combine multiple decorators into one

5. **Built-in profiler integration** - Automatic profiling with decorators

6. **IDE support** - Autocomplete and type checking for decorators

7. **Parameter inspection** - Runtime introspection of decorated function parameters for smarter decorators

## Open Questions

### 1. Function-Based Decorators vs Class-Based

The spec focuses entirely on class-based decorators (types implementing `Decorator` trait), but some examples (lines 837-917) show function-based decorator patterns:

```quest
fun require_auth(required_role)
    fun decorator(func)
        fun wrapper(*args, **kwargs)
            # ...
        end
        return wrapper
    end
    return decorator
end
```

**Questions:**
- Should function-based decorators be supported as an alternative?
- Should these examples be removed or converted to class-based?
- Are there use cases where function-based decorators are simpler/better?
- Should the `Decorator` trait be optional for simple use cases?

### 2. Decorator Factory Pattern

The spec shows various invocation styles but doesn't clarify the differences:

```quest
@dec.Timing              # No parentheses
@dec.Timing()            # Empty parentheses
@dec.Timing(threshold: 1.0)  # With arguments
```

**Questions:**
- How do `@Decorator` vs `@Decorator()` differ?
- Does `@Decorator` call `Decorator.new(func)` directly?
- Does `@Decorator()` call `Decorator.new(func)` or `Decorator().call(func)`?
- Should empty parentheses be required, optional, or disallowed?
- How do optional constructor parameters work with decorator syntax?

### 3. Type/Class Decorators

Currently only function decorators are supported (limitation #3). But should Quest support decorating entire types?

```quest
@serializable
@validated
@deprecated(since: "2.0")
type User
    str: name
    num: age
end
```

**Questions:**
- Should type decorators be a separate feature or use same `@` syntax?
- What would a type decorator return? (Modified type definition?)
- How would this interact with traits and validation?
- Use cases: auto-generate methods, add validation, serialization, etc.?

### 4. Accessing Decorator Instance Members

The `CountCalls` example (line 751) shows calling methods on the decorated function:

```quest
@CountCalls
fun process_item(item)
    # ...
end

puts("Total calls: ", process_item.get_count())  # How does this work?
```

**Questions:**
- How does `process_item.get_count()` work if `process_item` is a `CountCalls` instance?
- Does method call syntax check decorator instance methods before function methods?
- Can decorated functions expose both function methods (`_name`, `_doc`) and decorator methods (`get_count`)?
- What if there's a naming conflict between function and decorator methods?
- Should decorators expose a standard way to access their state?

### 5. Unwrapping and Introspection

No mechanism is specified for accessing the original function or decorator instance:

**Questions:**
- Should decorated functions expose `._wrapped` or `._original` to access wrapped function?
- Should they expose `._decorator` to access the decorator instance?
- How do you introspect the decorator chain for stacked decorators?
- Should there be a standard `unwrap()` function or method?
- Use cases: testing, debugging, conditional unwrapping, accessing original signatures

Example API:
```quest
@dec.Cache
@dec.Timing
fun my_function(x)
    return x * 2
end

my_function._wrapped        # Get Timing-decorated function
my_function._decorator      # Get Cache decorator instance
my_function._original       # Get original undecorated function
my_function._decorator_chain  # Get array of all decorators
```

### 6. Module-Qualified Decorators

The spec shows `@dec.Cache` but doesn't explain the resolution rules:

**Questions:**
- How does `@Cache` differ from `@dec.Cache` differ from `@my_module.MyDecorator`?
- Does decorator lookup follow normal variable scoping rules?
- Can decorators be imported: `use "std/decorators" as dec`?
- Can you use member access: `@my_module.nested.MyDecorator`?
- What about relative imports in decorator expressions?

### 7. Testing Decorators

No guidance provided on testing decorator implementations in isolation:

**Questions:**
- How do you unit test a decorator without applying it to real functions?
- Should decorators be testable as standalone callables?
- Best practices for testing decorator side effects (caching, logging, etc.)?
- How to test decorator metadata preservation?

Example testing approach:
```quest
use "std/test" as test

test.describe("Cache decorator", fun()
    test.it("caches function results", fun()
        let cache_decorator = Cache.new(simple_func, 100, nil)
        let result1 = cache_decorator._call(5)
        let result2 = cache_decorator._call(5)
        # How to verify cache was used?
    end)
end)
```

### 8. Lambda and Closure Decoration

Limitation #2 states "no decorator on lambdas". But what about workarounds?

**Questions:**
- Can you manually wrap lambdas: `let decorated = MyDecorator.new(fun(x) x * 2 end)`?
- Should Quest provide a decorator application function: `decorate(my_lambda, Cache.new)`?
- What about decorating closures that capture variables?
- Use cases: decorating callbacks, event handlers, inline functions?

Example:
```quest
# Can't do this:
@cache
let my_lambda = fun(x) x * 2 end  # Syntax error

# But could this work?
let my_lambda = Cache.new(fun(x) x * 2 end)
# or
let my_lambda = decorate(fun(x) x * 2 end, Cache)
```

### 9. Error Handling and Stack Traces

Limitation #5 mentions "debugging complexity" but doesn't detail error behavior:

**Questions:**
- What does a stack trace look like for decorated functions?
- Can decorators modify or suppress exceptions from wrapped functions?
- How are exceptions from `_call()` itself distinguished from wrapped function exceptions?
- Should decorator wrappers be hidden from stack traces (like Python's `@functools.wraps`)?
- How do multiple stacked decorators appear in error messages?

Example stack trace format:
```
Error: Division by zero
  at divide (line 45)
  at Timing._call (line 12)  # Should this appear?
  at Log._call (line 8)      # Should this appear?
  at main (line 100)
```

### 10. Decorator Composition and Reusability

Limitation #6 mentions no composition helpers. This becomes critical for real-world applications where you want to reuse common decorator configurations across multiple functions.

#### The Problem: Repetitive Decorator Configuration

Without decorator factories, you must repeat configuration parameters everywhere:

```quest
use "std/decorators" as dec

# Every function needs the same cache configuration repeated
@dec.Cache(max_size: 1000, ttl: 3600)
@dec.Retry(max_attempts: 3, delay: 1.0, backoff: 2.0)
@dec.Log(level: "info")
fun fetch_user(id)
    # ...
end

@dec.Cache(max_size: 1000, ttl: 3600)  # Repeated!
@dec.Retry(max_attempts: 3, delay: 1.0, backoff: 2.0)  # Repeated!
@dec.Log(level: "info")  # Repeated!
fun fetch_product(id)
    # ...
end

@dec.Cache(max_size: 1000, ttl: 3600)  # Repeated!
@dec.Retry(max_attempts: 3, delay: 1.0, backoff: 2.0)  # Repeated!
@dec.Log(level: "info")  # Repeated!
fun fetch_order(id)
    # ...
end
```

**Problems:**
- DRY violation: same configuration repeated everywhere
- Hard to maintain: changing cache TTL requires updating dozens of functions
- Error-prone: easy to use inconsistent configurations
- Verbose: three decorators per function adds 3+ lines of boilerplate

#### What is a Decorator Factory?

A **decorator factory** is a function or mechanism that creates pre-configured decorators for reuse. It allows you to define common decorator patterns once and apply them consistently.

**Key benefits:**
- **Configuration reuse:** Define once, use everywhere
- **Consistency:** All functions use the same settings
- **Maintainability:** Change configuration in one place
- **Abstraction:** Hide implementation details behind meaningful names
- **Composability:** Combine multiple decorators into semantic units

#### Proposed Solutions

**Solution 1: Static Factory Methods**

Add a standard `.with()` or `.configure()` method to all decorator types:

```quest
use "std/decorators" as dec

# Create pre-configured decorator instances
let api_cache = dec.Cache.with(max_size: 1000, ttl: 3600)
let api_retry = dec.Retry.with(max_attempts: 3, delay: 1.0, backoff: 2.0)
let api_log = dec.Log.with(level: "info")

# Use pre-configured decorators
@api_cache
@api_retry
@api_log
fun fetch_user(id)
    # ...
end

@api_cache
@api_retry
@api_log
fun fetch_product(id)
    # ...
end
```

**Implementation approach:**
```quest
type Cache
    # ... existing implementation ...

    static fun with(max_size, ttl)
        # Return a partially applied decorator type
        # This is a factory that creates Cache decorators with these settings
        return fun(func)
            Cache.new(func, max_size, ttl)
        end
    end
end
```

**Trade-offs:**
- ✅ Simple and intuitive
- ✅ Works with existing type system
- ❌ Requires each decorator to implement `.with()` method
- ❌ Doesn't compose multiple decorators

**Solution 2: Decorator Composition Function**

Provide a built-in `compose()` function that chains decorators:

```quest
use "std/decorators" as dec

# Compose multiple decorators into one
let api_decorator = dec.compose(
    dec.Cache.with(max_size: 1000, ttl: 3600),
    dec.Retry.with(max_attempts: 3, delay: 1.0),
    dec.Log.with(level: "info")
)

@api_decorator
fun fetch_user(id)
    # All three decorators applied
end

@api_decorator
fun fetch_product(id)
    # Same configuration
end
```

**Implementation approach:**
```quest
# In std/decorators module
fun compose(*decorators)
    # Return a decorator that applies all decorators in order
    return type ComposedDecorator
        array: decorators

        impl Decorator
            fun _call(*args, **kwargs)
                let func = self.func
                # Apply each decorator in sequence
                for decorator in self.decorators
                    func = decorator.new(func)
                end
                # Call the fully decorated function
                return func(*args, **kwargs)
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
            self.decorators = decorators
        end
    end
end
```

**Trade-offs:**
- ✅ Combines multiple decorators into one
- ✅ Clean application syntax
- ❌ More complex implementation
- ❌ Still requires `.with()` methods for configuration

**Solution 3: Partial Application Syntax**

Allow decorators to be partially applied with parentheses but no function:

```quest
use "std/decorators" as dec

# Partial application: calling decorator without a function returns a factory
let api_cache = dec.Cache(max_size: 1000, ttl: 3600)
let api_retry = dec.Retry(max_attempts: 3, delay: 1.0)

@api_cache
@api_retry
fun fetch_user(id)
    # ...
end
```

**How it works:**
- `dec.Cache(max_size: 1000, ttl: 3600)` doesn't provide a function, so it returns a decorator factory
- The factory waits to receive the function when `@api_cache` is applied
- This is essentially currying the decorator constructor

**Implementation approach:**
```quest
type Cache
    num?: max_size
    num?: ttl

    fun init(func_or_max_size, ttl?)
        # Detect if first arg is a function or a configuration parameter
        if func_or_max_size.is("Fun") or func_or_max_size.is("UserFun")
            # Called as: Cache.new(func) - immediate decoration
            self.func = func_or_max_size
            self.max_size = nil
            self.ttl = nil
        else
            # Called as: Cache.new(max_size, ttl) - returns factory
            # But how do we return a factory from init?
            # This doesn't work with current type system
        end
    end
end
```

**Trade-offs:**
- ✅ Very clean syntax
- ✅ Familiar from other languages (Python, JavaScript)
- ❌ Requires special syntax support or type system changes
- ❌ Doesn't compose multiple decorators
- ❌ May be confusing: same syntax has different behavior based on arguments

**Solution 4: Configuration Objects**

Define reusable configuration objects that decorators can consume:

```quest
use "std/decorators" as dec

# Define named configurations
let api_config = {
    cache: {max_size: 1000, ttl: 3600},
    retry: {max_attempts: 3, delay: 1.0, backoff: 2.0},
    log: {level: "info"}
}

@dec.Cache.from_config(api_config.cache)
@dec.Retry.from_config(api_config.retry)
@dec.Log.from_config(api_config.log)
fun fetch_user(id)
    # ...
end
```

**Trade-offs:**
- ✅ Separates configuration from code
- ✅ Easy to load from external config files
- ❌ Verbose application syntax
- ❌ Requires `.from_config()` methods on all decorators
- ❌ Still doesn't compose multiple decorators

**Solution 5: Decorator Builder Pattern**

Provide a fluent builder API for constructing complex decorators:

```quest
use "std/decorators" as dec

# Build a composite decorator with fluent API
let api_decorator = dec.builder()
    .cache(max_size: 1000, ttl: 3600)
    .retry(max_attempts: 3, delay: 1.0)
    .log(level: "info")
    .build()

@api_decorator
fun fetch_user(id)
    # ...
end

# Can create variations
let long_cache_api = dec.builder()
    .cache(max_size: 1000, ttl: 7200)  # Longer TTL
    .retry(max_attempts: 3)
    .log(level: "info")
    .build()

@long_cache_api
fun fetch_large_dataset(id)
    # ...
end
```

**Implementation approach:**
```quest
# In std/decorators module
type DecoratorBuilder
    array: decorators

    fun init()
        self.decorators = []
    end

    fun cache(max_size, ttl)
        self.decorators.push({
            type: Cache,
            config: {max_size: max_size, ttl: ttl}
        })
        return self  # Return self for chaining
    end

    fun retry(max_attempts, delay, backoff)
        self.decorators.push({
            type: Retry,
            config: {max_attempts: max_attempts, delay: delay, backoff: backoff}
        })
        return self
    end

    fun log(level)
        self.decorators.push({
            type: Log,
            config: {level: level}
        })
        return self
    end

    fun build()
        # Return a composite decorator
        return compose(*self.decorators)
    end
end

fun builder()
    DecoratorBuilder.new()
end
```

**Trade-offs:**
- ✅ Very clean and expressive API
- ✅ Easy to create variations
- ✅ Self-documenting configuration
- ✅ Composable by design
- ❌ Requires significant framework code
- ❌ More indirection to understand

#### Recommendation

A **hybrid approach** combining Solutions 1, 2, and 5 would be most powerful:

1. **Static factory methods** (`.with()`) for simple cases
2. **Composition function** (`compose()`) for combining decorators
3. **Builder pattern** for complex, reusable decorator chains

**Example of hybrid approach:**
```quest
use "std/decorators" as dec

# Simple case: single decorator with config
let basic_cache = dec.Cache.with(ttl: 300)

@basic_cache
fun simple_function()
    # ...
end

# Medium case: compose pre-configured decorators
let api_decorator = dec.compose(
    dec.Cache.with(max_size: 1000, ttl: 3600),
    dec.Retry.with(max_attempts: 3),
    dec.Log.with(level: "info")
)

@api_decorator
fun api_function()
    # ...
end

# Complex case: builder for custom combinations
let complex_decorator = dec.builder()
    .cache(max_size: 1000, ttl: 3600)
    .timing(threshold: 1.0)
    .retry(max_attempts: 5, delay: 2.0, backoff: 1.5)
    .log(level: "debug", include_args: true)
    .rate_limit(calls: 100, period: 60)
    .build()

@complex_decorator
fun complex_function()
    # ...
end

# Can define application-wide decorator standards
let standard_api = dec.builder()
    .cache(max_size: 1000, ttl: 3600)
    .retry(max_attempts: 3)
    .log(level: "info")
    .build()

let standard_db = dec.builder()
    .timing(threshold: 0.5)
    .retry(max_attempts: 2, exceptions: [DatabaseError])
    .log(level: "debug")
    .build()

# Use throughout application
@standard_api
fun fetch_from_api(endpoint)
    # ...
end

@standard_db
fun query_database(sql)
    # ...
end
```

#### Related Considerations

**Global decorator registry:**
```quest
# Should Quest allow registering named decorator configurations?
dec.register("api", dec.compose(
    dec.Cache.with(max_size: 1000, ttl: 3600),
    dec.Retry.with(max_attempts: 3),
    dec.Log.with(level: "info")
))

@dec.get("api")  # Look up by name
fun fetch_user(id)
    # ...
end
```

**Decorator inheritance/extension:**
```quest
# Should decorators be extensible?
type MyCache
    extends: Cache  # Inherit from built-in Cache

    # Override or extend behavior
    fun _call(*args, **kwargs)
        # Custom caching logic
        puts("Custom cache behavior")
        return super._call(*args, **kwargs)
    end
end
```

**Configuration validation:**
```quest
# Should decorator configurations be validated at creation time?
let invalid_cache = dec.Cache.with(max_size: -100)  # Error: negative size
let invalid_retry = dec.Retry.with(max_attempts: 0)  # Error: must be positive
```

#### Questions to Resolve

1. Should factory creation be built into the language or a library pattern?
2. What's the right balance between flexibility and simplicity?
3. Should Quest provide one standard pattern or support multiple approaches?
4. How do decorator factories interact with type checking and IDE support?
5. Should configurations be validated at factory creation time or decoration time?
6. Can decorators be serialized/deserialized for remote execution or persistence?
7. Should there be a standard configuration file format for decorators?

## See Also

- [Functions](../docs/functions.md) - Function declaration and usage
- [Type System](../docs/types.md) - Quest type system
- [Validation](validation.md) - Validation system (uses similar patterns)
