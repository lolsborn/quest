# Variable Scoping in Quest

Quest uses lexical scoping with block-level scope for variables. Understanding how variables are scoped is essential for writing correct programs.

## Variable Declaration

Variables are declared using the `let` keyword:

```quest
let x = 10
let name = "Alice"
let items = [1, 2, 3]
```

## Global Scope

Variables declared at the top level of a program or REPL session exist in the global scope:

```quest
let global_var = 100

fun print_global()
    puts(global_var)  # Can access global variable
end

print_global()  # Prints: 100
```

## Function Scope

Variables declared inside a function are local to that function:

```quest
let x = 10  # Global

fun example()
    let x = 20  # Local to example()
    puts(x)     # Prints: 20
end

example()
puts(x)  # Prints: 10 (global x unchanged)
```

### Parameter Scope

Function parameters create local variables:

```quest
fun greet(name)
    # 'name' is a local variable (parameter)
    puts("Hello, ", name)
end

greet("Bob")  # Prints: Hello, Bob
# puts(name)  # Error: name is not defined here
```

## Shadowing

Inner scopes can shadow (hide) variables from outer scopes:

```quest
let x = 1

fun outer()
    let x = 2
    puts("outer x: ", x)  # Prints: outer x: 2

    fun inner()
        let x = 3
        puts("inner x: ", x)  # Prints: inner x: 3
    end

    inner()
    puts("outer x again: ", x)  # Prints: outer x again: 2
end

outer()
puts("global x: ", x)  # Prints: global x: 1
```

## Deleting Variables

You can remove a variable from the current scope using `del`:

```quest
let x = 10
puts(x)  # Prints: 10

del x
# puts(x)  # Error: x is not defined
```

### Use Cases for `del`

**1. Free up memory for large data structures:**

```quest
let large_data = read_large_file("data.csv")
process(large_data)
del large_data  # Free memory after processing
```

**2. Explicitly mark variables as no longer needed:**

```quest
let temp_result = calculate()
save_to_file(temp_result)
del temp_result  # Clearly indicate we're done with this
```

**3. Remove variables before scope ends:**

```quest
fun process_data()
    let cache = {}
    # ... use cache ...
    del cache  # Clean up before function returns
    return result
end
```

### Scope Restrictions

`del` only works on variables in the current scope:

```quest
let global_var = 100

fun example()
    let local_var = 50
    del local_var  # OK - deletes local variable

    # del global_var  # Error: cannot delete variable from outer scope
end
```

### Deleting and Redeclaration

After deleting a variable, you can redeclare it:

```quest
let x = 10
del x
let x = 20  # OK - x was deleted first
puts(x)  # Prints: 20
```

### What You Cannot Delete

- **Module imports:**
  ```quest
  use "std/math"
  # del math  # Error: cannot delete module
  ```

- **Function parameters:**
  ```quest
  fun example(x)
      # del x  # Error: cannot delete parameter
  end
  ```

- **Built-in functions:**
  ```quest
  # del puts  # Error: cannot delete built-in function
  ```

## Block Scope

Control structures (if, elif, else) create new scopes:

```quest
let x = 10

if true
    let x = 20  # New variable, shadows outer x
    puts(x)     # Prints: 20
end

puts(x)  # Prints: 10
```

### If/Elif/Else Scoping

Each branch creates its own scope:

```quest
let value = 5

if value < 0
    let msg = "negative"
    puts(msg)
elif value == 0
    let msg = "zero"  # Different variable from if branch
    puts(msg)
else
    let msg = "positive"  # Different variable from other branches
    puts(msg)
end

# puts(msg)  # Error: msg not defined here
```

## Variable Assignment vs Declaration

Quest supports reassignment to variables in the same scope:

```quest
let x = 10  # Declaration
puts(x)     # Prints: 10

x = 20      # Reassignment
puts(x)     # Prints: 20
```

### Reassignment in Function Scopes

Quest supports reassignment of variables from outer scopes:

```quest
let x = 10

fun modify()
    x = 20  # Modifies the outer x
end

modify()
puts(x)  # Prints: 20
```

Assignment always modifies the variable where it was first declared, searching through scopes from innermost to outermost.

## Closures and Captured Variables

Functions can read and modify variables from their enclosing scope:

```quest
let message = "Hello"

fun greet(name)
    # Can read 'message' from outer scope
    puts(message, ", ", name)
end

greet("Alice")  # Prints: Hello, Alice
```

Quest supports **true closures with mutable state**. When you assign to a variable inside a function, Quest searches for that variable in outer scopes and modifies it where it was originally declared:

```quest
let count = 0

fun increment()
    count = count + 1  # Modifies outer 'count'
    puts(count)
end

increment()  # Prints: 1
increment()  # Prints: 2
puts(count)  # Prints: 2
```

This enables powerful patterns like counters, accumulators, and stateful closures:

```quest
let make_counter = fun ()
    let count = 0
    return fun ()
        count = count + 1
        return count
    end
end

let counter1 = make_counter()
puts(counter1())  # 1
puts(counter1())  # 2
puts(counter1())  # 3
```

## Module Scope

When you import a module with `use`, it creates a variable in the current scope:

```quest
use "std/math"

# 'math' is now a variable in this scope
puts(math.pi)

fun example()
    # Can access math from outer scope
    let result = math.sin(1.5)
    puts(result)
end
```

### Module Aliasing

You can alias modules to different names:

```quest
use "std/math" as m

puts(m.pi)
puts(m.cos(0))
```

## Scope Best Practices

### 1. Minimize Global Variables

Prefer passing data as function parameters:

```quest
# Avoid:
let total = 0

fun add_to_total(n)
    total = total + n
end

# Prefer:
fun add(a, b)
    return a + b
end

let total = add(10, 20)
```

### 2. Use Descriptive Names

Avoid shadowing unless intentional:

```quest
# Avoid:
let data = [1, 2, 3]

fun process()
    let data = [4, 5, 6]  # Shadows outer data - confusing
    # ...
end

# Prefer:
let input_data = [1, 2, 3]

fun process()
    let processed_data = [4, 5, 6]  # Clear intention
    # ...
end
```

### 3. Limit Variable Lifetime

Declare variables in the narrowest scope possible:

```quest
# Avoid:
fun calculate()
    let temp1 = 10
    let temp2 = 20
    let result = 0

    if temp1 > 5
        result = temp1 * temp2
    end

    return result
end

# Prefer:
fun calculate()
    let temp1 = 10
    let temp2 = 20

    if temp1 > 5
        let result = temp1 * temp2  # Scoped to if block
        return result
    end

    return 0
end
```

### 4. Use Closures Effectively

Quest supports true closures with mutable captured variables:

```quest
let counter = 0

let increment = fun ()
    counter = counter + 1
    puts(counter)
end

increment()  # Prints: 1
increment()  # Prints: 2
puts(counter)  # Prints: 2
```

Use closures to encapsulate state and create factory functions:

```quest
fun make_accumulator()
    let total = 0
    return fun (x)
        total = total + x
        return total
    end
end

let acc = make_accumulator()
puts(acc(5))   # 5
puts(acc(10))  # 15
puts(acc(3))   # 18
```

## Common Scoping Errors

### Undefined Variable

```quest
fun example()
    puts(x)  # Error: x not defined
end

let x = 10
example()
```

Variables must be defined before use, even if they exist in a later scope.

### Variable Redeclaration

```quest
let x = 10
let x = 20  # Error: variable x already declared
```

Cannot redeclare a variable in the same scope. Use shadowing or a new scope instead.

### Out of Scope Access

```quest
if true
    let temp = 42
end

puts(temp)  # Error: temp not defined in this scope
```

Variables don't leak out of their declaring scope.

## Scope and Iteration

Iteration constructs respect scope rules:

```quest
# for..in loops
for item in [1, 2, 3]
    # 'item' is scoped to this loop
    puts(item * 2)
end
# puts(item)  # Error: item not defined here

# .each method
let arr = [1, 2, 3]
arr.each(fun (item)
    # 'item' is scoped to this function
    puts(item * 2)
end)
# puts(item)  # Error: item not defined here
```

## Summary

- Quest uses **lexical scoping** - inner scopes can access outer scope variables
- Variables are **block-scoped** - limited to the block they're declared in
- Functions create **new scopes** for parameters and local variables
- **Shadowing** allows reusing variable names in nested scopes
- **Closures** capture variables from enclosing scopes
- Variables must be **declared before use** in their scope
- **`del` statement** removes variables from the current scope
- **Module imports** create variables in the current scope

Understanding scoping helps write clearer, more maintainable Quest programs.
