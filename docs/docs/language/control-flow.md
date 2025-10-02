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

## Implementation Details

If statements in Quest are implemented as block statements with the `if...end` syntax. The parser supports:
- Multiple `elif` clauses for chaining conditions
- Optional `else` clause for default behavior
- One-line and multi-line block forms
- All comparison and logical operators in conditions
