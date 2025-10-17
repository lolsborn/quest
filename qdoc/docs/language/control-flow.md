# Control Flow

Quest provides intuitive control flow constructs for conditional execution. All control flow in Quest follows a consistent block-based syntax with the `end` keyword.

## If Statements

### Block If

The standard if statement uses block syntax with optional `elif` and `else` clauses:

```quest
if condition
    # statements
end
```

**Multiple conditions:**
```quest
if condition
    # statements
elif another_condition
    # statements
else
    # statements
end
```

**Examples:**
```quest
# Simple condition
if age >= 18
    puts("You are an adult")
end

# With elif and else
if score >= 90
    puts("Grade: A")
elif score >= 80
    puts("Grade: B")
elif score >= 70
    puts("Grade: C")
else
    puts("Grade: F")
end

# Method calls in conditions
if name.len() > 0
    puts("Hello, " .. name)
else
    puts("Name cannot be empty")
end
```

### One-Line If

If statements can also be written on a single line:

```quest
if condition puts("yes") else puts("no") end
```

**Examples:**
```quest
# One-line if/else
if friendly puts("Hi") else puts("Bye") end

# With expressions
if x > 10 puts("Large") else puts("Small") end

# Multiple statements (use semicolons or newlines within the block)
if ready puts("Starting...") end
```

## Comparison Operators

Quest supports standard comparison operators for use in conditions:

| Operator | Description | Example |
|----------|-------------|---------|
| `==` | Equal to | `x == 5` |
| `!=` | Not equal to | `x != 0` |
| `<` | Less than | `x < 10` |
| `>` | Greater than | `x > 0` |
| `<=` | Less than or equal | `x <= 100` |
| `>=` | Greater than or equal | `x >= 18` |

## Logical Operators

Combine multiple conditions with logical operators:

| Operator | Description | Example |
|----------|-------------|---------|
| `and` | Logical AND | `x > 0 and x < 10` |
| `or` | Logical OR | `x < 0 or x > 100` |
| `not` | Logical NOT | `not is_empty` |

**Examples:**
```quest
# Logical AND
if age >= 18 and has_license
    puts("You can drive")
end

# Logical OR
if day == "Saturday" or day == "Sunday"
    puts("It's the weekend!")
end

# Logical NOT
if not is_valid
    puts("Invalid input")
end

# Complex conditions
if (age >= 13 and age <= 19) or status == "student"
    puts("Eligible for student discount")
end
```

## Truthiness

Quest has clear truthiness rules:

**Falsy values:**
- `false` (the boolean false)
- `nil` (the nil value)

**Truthy values:**
- Everything else, including:
  - `true`
  - All numbers (including `0`)
  - All strings (including `""`)
  - All arrays and dicts (including empty ones)

```quest
# Numbers are truthy (including 0)
if 0
    puts("This will print")
end

# Empty strings are truthy
if ""
    puts("This will also print")
end

# nil is falsy
if nil
    puts("This won't print")
end

# Explicit boolean checks
if value != nil
    puts("Value exists")
end
```

## Common Patterns

### Guard Clauses

```quest
if not user_logged_in
    puts("Please log in first")
    return
end

# Continue with main logic
process_request()
```

### Range Checks

```quest
if age >= 13 and age <= 19
    puts("Teenager")
end
```

### Type Checking

```quest
if value.is("Num")
    puts("It's a number")
elif value.is("Str")
    puts("It's a string")
end
```

### Nil Checks

```quest
if result != nil
    process(result)
else
    puts("No result found")
end
```

### Nested Conditions

```quest
if user != nil
    if user.is_admin
        show_admin_panel()
    else
        show_user_panel()
    end
else
    show_login_page()
end
```

## Match Statements

Match statements provide a clean way to compare a value against multiple possibilities. They're ideal for replacing long chains of `if/elif` conditions.

### Basic Syntax

```quest
match expression
in value1
    # statements
in value2
    # statements
else
    # default statements
end
```

### Multiple Values

A single `in` clause can match multiple values using comma separation:

```quest
match day
in "Monday", "Tuesday", "Wednesday", "Thursday", "Friday"
    puts("Weekday")
in "Saturday", "Sunday"
    puts("Weekend")
end
```

### Examples

**Simple matching:**
```quest
match status
in 200
    puts("OK")
in 404
    puts("Not Found")
in 500
    puts("Server Error")
else
    puts("Unknown status")
end
```

**HTTP status handler:**
```quest
fun handle_status(code)
    match code
    in 200, 201, 204
        "success"
    in 400, 401, 403
        "client_error"
    in 404
        "not_found"
    in 500, 502, 503
        "server_error"
    else
        "unknown"
    end
end
```

**Command dispatcher:**
```quest
match command
in "help", "h", "?"
    show_help()
in "quit", "exit", "q"
    exit_program()
in "list", "ls"
    list_items()
else
    puts("Unknown command")
end
```

### Match Features

**Type matching:**
```quest
match value
in "hello"
    puts("String match")
in 42
    puts("Number match")
in true
    puts("Boolean match")
in nil
    puts("Nil match")
end
```

**Expression matching:**
```quest
match x * 2
in 10
    puts("Matched 10")
in 20
    puts("Matched 20")
end
```

**Nested matching:**
```quest
match outer
in 1
    match inner
    in "a"
        "1-a"
    in "b"
        "1-b"
    end
in 2
    "outer-2"
end
```

**First match wins:**
```quest
match value
in 1
    "first"
in 1
    "second"  # This will never execute
end
```

### Control Flow in Match

Match statements support break, continue, and return within their blocks:

```quest
# Return from function
fun classify(code)
    match code
    in 200
        return "success"
    in 404
        return "not_found"
    end
end

# Break from loop
for item in items
    match item
    in "stop"
        break
    else
        process(item)
    end
end
```

### Match vs If/Elif

Use match when:
- Comparing one value against multiple possibilities
- You have many conditions checking the same variable
- Readability matters (match is often cleaner)

Use if/elif when:
- Conditions involve different variables
- You need complex boolean logic
- Conditions use comparison operators other than equality

```quest
# Better with match
match status_code
in 200, 201, 204
    "success"
in 404
    "not_found"
end

# Better with if/elif
if age < 13
    "child"
elif age < 20
    "teenager"
elif age < 65
    "adult"
else
    "senior"
end
```

## Implementation Details

Control flow statements in Quest are implemented as block statements with the `...end` syntax. The parser supports:

**If statements:**
- Multiple `elif` clauses for chaining conditions
- Optional `else` clause for default behavior
- One-line and multi-line block forms
- All comparison and logical operators in conditions

**Match statements:**
- Multiple `in` clauses with comma-separated values
- Optional `else` clause for default case
- Expression evaluation (match expression is evaluated once)
- First-match-wins semantics
- Support for break, continue, and return within blocks
