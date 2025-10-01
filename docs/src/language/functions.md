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
```quest

### Parameters

Functions can have zero or more parameters. Parameters are untyped:

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
```quest

### Return Values

The last expression in a function body is automatically returned. No explicit `return` statement is needed:

```quest
fun add(x, y)
    x + y
end

let result = add(5, 3)  # result = 8
```quest

### Calling Functions

Functions are called using parentheses with arguments:

```quest
greet("World")           # Prints: Hello, World!
let sum = add(10, 20)    # sum = 30
let pi = get_pi()        # pi = 3.14159
```quest

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
```quest

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
```quest

## Anonymous Functions (Lambdas)

Anonymous functions, also called lambdas, are functions without a name. They use the same syntax as named functions, but without the function name.

### Syntax

```quest
fun (param1, param2) body end
```quest

### Examples

```quest
# Single expression
fun (x) x * 2 end

# Multiple parameters
fun (x, y) x + y end

# String concatenation
fun (name) "Hello, " .. name end
```quest

### Multi-Statement Lambdas

For lambdas with multiple statements:

```quest
fun (x, y)
    let sum = x + y
    let product = x * y
    sum + product
end
```quest

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
```quest

### Parameterless Lambdas

Lambdas can have zero parameters:

```quest
let greet = fun () "Hello, World!" end
puts(greet())
```quest

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
```quest

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
```quest

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
```quest

### Lambdas as Variables

```quest
let operations = [
    fun (x) x + 1 end,
    fun (x) x * 2 end,
    fun (x) x * x end
]

# Future: when we have array iteration
# operations[0](5)  # Would return 6
```quest

## Best Practices

1. **Use named functions** for reusable, well-defined operations
2. **Use lambdas** for short, one-off operations or when passing functions as data
3. **Keep functions focused** - each function should do one thing well
4. **Use descriptive names** for named functions
5. **Keep lambdas simple** - if it's complex, use a named function instead

## Limitations (Current Implementation)

- No default parameter values
- No variable number of arguments (varargs)
- No explicit `return` statement (last expression is always returned)
- No function overloading
- No type annotations on parameters or return values (planned but not enforced)
