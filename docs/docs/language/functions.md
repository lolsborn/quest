# Functions

Quest supports both named user-defined functions and anonymous functions (lambdas).

## User-Defined Functions

### Basic Syntax

Functions are declared using the `fun` keyword and must end with `end`:

```quest
fun function_name(parameters)
    statement1
    statement2
    return_value
end
```

### Parameters

Functions can have zero or more parameters:

```quest
fun greet(name)
    puts("Hello, " .. name .. "!")
end

fun add(x, y)
    x + y
end

fun get_pi()
    3.14159
end
```

### Type Annotations

Parameters can have optional type annotations for documentation and runtime validation:

```quest
fun add(x: Int, y: Int)
    x + y
end

fun greet(name: str, times: Int = 1)
    let i = 0
    while i < times
        puts("Hello, " .. name)
        i = i + 1
    end
end

fun process(data: array, config: dict)
    # Type checking happens at runtime
    data.map(fun (item) item * 2 end)
end
```

**Available type annotations:**
- `int`, `float`, `num` (int or float), `decimal` (arbitrary precision)
- `str`, `bool`, `bytes`, `nil`
- `array`, `dict`, `uuid`

**Type validation:**
- Type checks happen at runtime when the function is called
- If an argument doesn't match its annotation, a `TypeErr` is raised
- Type annotations work with default parameters and variadic parameters

```quest
fun multiply(x: Int, y: Int = 2)
    x * y
end

multiply(5)       # Valid: 10
multiply(5, 3)    # Valid: 15
multiply(5, 3.0)  # TypeErr: expected int, got float
```

### Default Parameters

Parameters can have default values, making them optional at call sites:

```quest
fun greet(name, greeting = "Hello")
    puts(greeting .. ", " .. name)
end

greet("Alice")              # "Hello, Alice"
greet("Bob", "Hi")          # "Hi, Bob"
```

**Key features:**
- Parameters with defaults are optional
- Defaults are evaluated at call time (not definition time)
- Defaults can reference earlier parameters
- Defaults can reference outer scope variables (closure capture)
- Required parameters must come before optional ones

**Examples:**

```quest
# Multiple defaults
fun connect(host = "localhost", port = 8080, timeout = 30)
    puts("Connecting to " .. host .. ":" .. port.str())
end

connect()                           # localhost:8080
connect("example.com")              # example.com:8080
connect("example.com", 3000)        # example.com:3000
connect("example.com", 3000, 60)    # example.com:3000 with 60s timeout

# Defaults reference earlier parameters
fun add_with_default(x, y = x)
    x + y
end

add_with_default(5)      # 10 (5 + 5)
add_with_default(5, 3)   # 8 (5 + 3)

# Defaults with outer scope
let default_multiplier = 2
fun scale(value, multiplier = default_multiplier)
    value * multiplier
end

scale(10)      # 20
scale(10, 3)   # 30
```

**Validation:**

```quest
# ✅ Valid: required before optional
fun valid(required, optional = 10)
    required + optional
end

# ❌ Invalid: optional before required
fun invalid(optional = 10, required)
    # This raises an error at definition time!
end
```

### Variadic Parameters

Functions can accept a variable number of arguments using `*args`:

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

sum()                    # 0
sum(1)                   # 1
sum(1, 2, 3)             # 6
sum(1, 2, 3, 4, 5)       # 15
```

**Key features:**
- `*args` collects remaining positional arguments into an Array
- Must come after regular and optional parameters
- Works with lambdas
- Works with type methods

**Parameter order:**
```quest
fun example(required, optional = default, *args)
    # required: must be provided
    # optional: uses default if not provided
    # args: Array of remaining arguments
end
```

**Examples:**

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
    puts("Connecting to " .. host .. ":" .. port.str())
    puts("Extra args: " .. extra.len().str())
end

connect("localhost")              # port=8080, extra=[]
connect("localhost", 3000)        # port=3000, extra=[]
connect("localhost", 3000, "a")   # port=3000, extra=["a"]

# Varargs in lambda
let concat = fun (*items)
    let result = ""
    let i = 0
    while i < items.len()
        result = result .. items[i].str()
        i = i + 1
    end
    result
end

concat("a", "b", "c")  # "abc"
```

### Named Arguments

Functions can be called with named arguments, allowing you to specify arguments by parameter name:

```quest
fun greet(greeting, name)
    greeting .. ", " .. name
end

# All positional (traditional)
greet("Hello", "Alice")              # "Hello, Alice"

# All named
greet(greeting: "Hello", name: "Alice")    # "Hello, Alice"

# Named arguments can be reordered
greet(name: "Alice", greeting: "Hello")    # "Hello, Alice"

# Mixed: positional then named
greet("Hello", name: "Alice")        # "Hello, Alice"
```

**Key features:**
- Named arguments use `name: value` syntax
- Can specify arguments in any order when using names
- Can mix positional and named (positional must come first)
- Once you use a named argument, remaining arguments must also be named
- Especially useful for skipping optional parameters

**Skipping optional parameters:**

```quest
fun connect(host, port = 8080, timeout = 30, ssl = false, debug = false)
    # ...
end

# Skip middle parameters using named args
connect("localhost", ssl: true)                # Use defaults for port, timeout
connect("localhost", debug: true, ssl: true)   # Skip port, timeout
connect("localhost", 3000, ssl: true)          # Specify port, skip timeout
```

**With variadic parameters:**

```quest
fun configure(host, port = 8080, *extra, **options)
    # host: required
    # port: optional with default
    # extra: Array of extra positional args
    # options: Dict of extra keyword args
    puts("Host: " .. host)
    puts("Port: " .. port.str())
    puts("Extra args: " .. extra.len().str())
    puts("Options: " .. options.len().str())
end

configure("localhost", ssl: true, timeout: 60)
# Host: localhost
# Port: 8080
# Extra args: 0
# Options: 2 (ssl and timeout)
```

**Rules:**
- Named arguments must match parameter names exactly
- Can't specify same parameter both positionally and by keyword
- Duplicate keyword arguments are not allowed

**Array and Dict unpacking:**

```quest
# Array unpacking with *
fun add(x, y, z)
    x + y + z
end

let args = [1, 2, 3]
add(*args)  # 6 - unpacks array to positional args

# Dict unpacking with **
fun greet(greeting, name)
    greeting .. ", " .. name
end

let kwargs = {greeting: "Hello", name: "Alice"}
greet(**kwargs)  # "Hello, Alice"

# Override unpacked values (last value wins)
greet(**kwargs, name: "Bob")  # "Hello, Bob"
```

### Return Values

The last expression in a function body is automatically returned:

```quest
fun add(x, y)
    x + y
end

let result = add(5, 3)  # result = 8
```

You can also use explicit `return` statements to exit early:

```quest
fun find_first_even(numbers)
    let i = 0
    while i < numbers.len()
        if numbers[i] % 2 == 0
            return numbers[i]  # Exit early, return the value
        end
        i = i + 1
    end
    nil  # Return nil if no even number found
end

puts(find_first_even([1, 3, 5, 8, 9]))  # Prints: 8
```

### Calling Functions

Functions are called using parentheses with arguments:

```quest
greet("World")           # Prints: Hello, World!
let sum = add(10, 20)    # sum = 30
let pi = get_pi()        # pi = 3.14159
```

**Note:** Parentheses are required even for zero-parameter functions.

### Multiple Statements

Functions can contain multiple statements. Only the last expression is returned:

```quest
fun calculate(x, y)
    let doubled = x * 2
    let sum = doubled + y
    sum
end

let result = calculate(5, 3)  # result = 13
```

### Examples

```quest
# Simple greeting
fun greet(name)
    puts("Hello, " .. name .. "!")
end

greet("Alice")
greet("Bob")

# Function with return value
fun square(n)
    n * n
end

puts("5 squared is ", square(5))

# Function with multiple statements
fun describe(value)
    puts("The value is: ", value)
    let doubled = value * 2
    puts("Doubled: ", doubled)
    doubled
end

let result = describe(7)
puts("Returned: ", result)

# Parameterless function
fun random_greeting()
    "Hello!"
end

puts(random_greeting())
```

## Anonymous Functions (Lambdas)

Anonymous functions, also called lambdas, are functions without a name. They use the same syntax as named functions, but without the function name.

### Syntax

```quest
fun (param1, param2) body end
```

### Examples

```quest
# Single expression
fun (x) x * 2 end

# Multiple parameters
fun (x, y) x + y end

# String concatenation
fun (name) "Hello, " .. name end
```

### Multi-Statement Lambdas

For lambdas with multiple statements:

```quest
fun (x, y)
    let sum = x + y
    let product = x * y
    sum + product
end
```

### Using Lambdas

Anonymous functions can be:
- Assigned to variables
- Passed as arguments to other functions
- Called immediately

```quest
# Assign to variable
let double = fun (x) x * 2 end
puts(double(5))  # Prints: 10

# Multi-parameter lambda
let add = fun (x, y) x + y end
puts(add(3, 4))  # Prints: 7

# Lambda with multiple statements
let compute = fun (x, y)
    let a = x * 2
    let b = y * 3
    a + b
end

puts(compute(5, 10))  # Prints: 40
```

### Parameterless Lambdas

Lambdas can have zero parameters:

```quest
let greet = fun () "Hello, World!" end
puts(greet())
```

## Function Scope

Functions create their own scope and have access to:
1. Their own parameters
2. Variables from the parent scope (closure behavior)

```quest
let multiplier = 10

fun scale(n)
    n * multiplier
end

puts(scale(5))  # Prints: 50
```

## Differences Between Named and Anonymous Functions

| Feature | Named Functions | Anonymous Functions |
|---------|----------------|---------------------|
| Syntax | `fun name(params) ... end` | `fun (params) ... end` |
| Name | Required | None (assigned to variable) |
| Declaration | Statement | Expression |
| Multi-line | Always uses `end` | Always uses `end` |
| Usage | Direct call by name | Call via variable or immediate invocation |

## Common Patterns

### Helper Functions

```quest
fun is_even(n)
    n % 2 == 0
end

fun is_odd(n)
    n % 2 != 0
end

if is_even(42)
    puts("42 is even")
end
```

### Function Composition

```quest
fun double(x)
    x * 2
end

fun square(x)
    x * x
end

fun double_then_square(x)
    square(double(x))
end

puts(double_then_square(3))  # Prints: 36 (3 * 2 = 6, 6 * 6 = 36)
```

### Lambdas as Variables

```quest
let operations = [
    fun (x) x + 1 end,
    fun (x) x * 2 end,
    fun (x) x * x end
]

# Call function stored in array
operations[0](5)   # Returns 6
operations[1](5)   # Returns 10
operations[2](5)   # Returns 25

# Store functions in dictionaries
let handlers = {
    greet: fun (name) "Hello, " .. name end,
    farewell: fun (name) "Goodbye, " .. name end
}

handlers["greet"]("Alice")     # "Hello, Alice"
handlers["farewell"]("Bob")    # "Goodbye, Bob"
```

### Higher-Order Functions and Closures

Quest supports higher-order functions - functions that return other functions. This enables powerful patterns like currying, function factories, and lazy evaluation.

**Functions returning functions:**

```quest
# Simple function factory
let make_adder = fun (n)
    fun (x) x + n end
end

let add_five = make_adder(5)
add_five(10)           # 15
add_five(20)           # 25

# Factory with state capture
let make_counter = fun (start)
    fun ()
        start += 1
        start
    end
end

let counter = make_counter(0)
counter()              # 1
counter()              # 2
counter()              # 3
```

**Chained function calls - `f(x)()`:**

Quest supports the syntax `f(x)()` for calling a function, passing arguments, and immediately invoking the returned function:

```quest
# Triple nested function
let f = fun (a)
    fun (b)
        fun (c)
            a + b + c
        end
    end
end

f(1)(2)(3)             # 6

# Array element returning a function
let arr = [
    fun (x) fun () x * 2 end end
]

arr[0](5)()            # 10 (multiplies by 2)

# Dict element returning a function
let dict = {
    multiply: fun (n) fun (x) x * n end end
}

dict["multiply"](3)(10)    # 30
```

**Advanced patterns:**

```quest
# Map with function factories
let multipliers = [2, 3, 4]
let make_multiplier = fun (n)
    fun (x) x * n end
end

let results = multipliers.map(fun (n)
    make_multiplier(n)(10)
end)

results                # [20, 30, 40]

# Closure capturing outer variables
let multiplier = 5

let scale = fun (value)
    value * multiplier
end

scale(10)              # 50 (multiplier = 5)

multiplier = 10
scale(10)              # 100 (multiplier = 10, closure captures reference)
```

## Best Practices

1. **Use named functions** for reusable, well-defined operations
2. **Use lambdas** for short, one-off operations or when passing functions as data
3. **Keep functions focused** - each function should do one thing well
4. **Use descriptive names** for named functions
5. **Keep lambdas simple** - if it's complex, use a named function instead

## Limitations (Current Implementation)

- No function overloading
- Type annotations on parameters exist but are not enforced at runtime
