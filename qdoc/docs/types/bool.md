# Bool

Bool represents boolean values in Quest: `true` and `false`. Booleans are fundamental to control flow, conditional logic, and comparison operations.

## Literals

Quest has two boolean literals:

```quest
let is_valid = true
let is_complete = false
```

## Truthiness

In Quest, certain values are considered "falsy" in boolean contexts, while all others are "truthy":

**Falsy values:**
- `false` - the boolean false
- `nil` - the absence of a value
- `0` - integer zero
- `0.0` - float zero

**Truthy values:**
- `true` - the boolean true
- All non-zero numbers
- All strings (including empty strings)
- All collections (including empty arrays and dicts)
- All objects

```quest
if 0
    puts("This won't print")
end

if nil
    puts("This won't print either")
end

if ""
    puts("Empty strings are truthy!")  # This prints
end

if []
    puts("Empty arrays are truthy!")  # This prints
end
```

## Logical Operators

### and

Returns true if both operands are truthy:

```quest
true and true    # true
true and false   # false
false and true   # false
false and false  # false

let age = 25
let has_license = true
if age >= 18 and has_license
    puts("Can drive")
end
```

Short-circuits: if the first operand is falsy, the second is not evaluated.

### or

Returns true if at least one operand is truthy:

```quest
true or true     # true
true or false    # true
false or true    # true
false or false   # false

let is_admin = false
let is_moderator = true
if is_admin or is_moderator
    puts("Has elevated privileges")
end
```

Short-circuits: if the first operand is truthy, the second is not evaluated.

### not

Negates a boolean value:

```quest
not true   # false
not false  # true

let is_ready = false
if not is_ready
    puts("Not ready yet")
end
```

## Comparison Operators

Comparison operations return boolean values:

```quest
# Equality
5 == 5     # true
5 == 10    # false
5 != 10    # true

# Ordering
5 < 10     # true
5 > 10     # false
5 <= 5     # true
5 >= 10    # false

# String comparison
"abc" == "abc"    # true
"abc" < "xyz"     # true (lexicographic)
```

## Methods

### _str() → String

Returns the string representation of the boolean:

```quest
let flag = true
puts(flag.str())  # "true"

let other = false
puts(other.str())  # "false"
```

### _type() → String

Returns the type name:

```quest
let flag = true
puts(flag._type())  # "Bool"
```

## Control Flow

Booleans are primarily used in control flow structures:

### if/elif/else

```quest
let score = 85

if score >= 90
    puts("A")
elif score >= 80
    puts("B")
elif score >= 70
    puts("C")
else
    puts("F")
end
```

### Inline if (Ternary)

```quest
let age = 20
let status = "adult" if age >= 18 else "minor"
```

### while loops

```quest
let count = 0
while count < 5
    puts(count)
    count = count + 1
end
```

## Boolean Functions

Many methods return boolean values for testing conditions:

```quest
# String methods
"hello".starts_with("he")    # true
"hello".ends_with("lo")      # true
"hello".contains("ll")       # true

# Array methods
let arr = [1, 2, 3]
arr.contains(2)              # true
arr.is_empty()               # false

# Dict methods
let dict = {"key": "value"}
dict.has_key("key")          # true

# Type checking
let x = 42
x.is("Int")                  # true
```

## Elvis Operator with Booleans

The Elvis operator (`?:`) provides a concise way to handle nil values:

```quest
let config = nil
let timeout = config ?: 30  # Returns 30 since config is nil

let flag = false
let result = flag ?: true   # Returns true since false is falsy
```

See [Nil](nil.md) for more details on the Elvis operator.

## Combining Conditions

Complex boolean expressions can be built using parentheses:

```quest
let age = 25
let has_ticket = true
let has_id = true

if (age >= 18 and has_id) or has_ticket
    puts("Entry granted")
end
```

## Common Patterns

### Flag Variables

```quest
let is_processing = true
let has_error = false
let should_retry = true
```

### Validation

```quest
fun is_valid_email(email)
    return email.contains("@") and email.contains(".")
end

fun is_in_range(value, min, max)
    return value >= min and value <= max
end
```

### State Checking

```quest
let is_logged_in = false
let is_admin = false

if not is_logged_in
    puts("Please log in")
    return
end

if is_admin
    # Admin-only functionality
end
```

## Type Conversion

### To Boolean (Implicit)

Quest automatically converts values to boolean in conditional contexts:

```quest
let value = 42
if value
    puts("Value is truthy")
end
```

### From Boolean to String

```quest
let flag = true
let msg = "Status: " .. flag.str()  # "Status: true"
```

### From Boolean to Int

There's no automatic conversion, but you can use inline if:

```quest
let flag = true
let as_int = 1 if flag else 0
```

## Performance

Boolean operations are extremely fast. Use them freely without performance concerns. Short-circuiting (`and`, `or`) can improve performance by avoiding unnecessary evaluations:

```quest
# expensive_check() is only called if cheap_check() returns true
if cheap_check() and expensive_check()
    # ...
end
```

## See Also

- [Control Flow](../language/control-flow.md) - if, elif, else statements
- [Loops](../language/loops.md) - while and for loops
- [Nil](nil.md) - Nil type and Elvis operator
- [Functions](../language/functions.md) - Boolean return values
