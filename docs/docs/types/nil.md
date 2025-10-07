# Nil

Nil represents the absence of a value in Quest. It's a singleton type with a single value: `nil`. Nil is fundamental to Quest's type system, representing optional values, uninitialized variables, and absent dictionary entries.

## The nil Literal

Quest has one nil literal:

```quest
let nothing = nil
```

## Singleton and ID

Nil is implemented as a singleton—there is only ever one nil value in memory. This singleton always has ID 0:

```quest
nil._id()  # Always returns 0
```

All nil values are the same object:

```quest
let a = nil
let b = nil
a._id() == b._id()  # true (both are ID 0)
```

## Nil in Variables

Variables can hold nil to indicate the absence of a value:

```quest
let name = nil  # Not yet set

# Later...
name = "Alice"
```

## Nil as Falsy

Nil is one of the falsy values in Quest (along with `false`, `0`, and `0.0`):

```quest
if nil
    puts("This won't print")
end

if not nil
    puts("This will print")  # nil is falsy
end
```

## The Elvis Operator (`?:`)

The Elvis operator provides a concise way to provide default values for nil:

```quest
let config = nil
let timeout = config ?: 30  # Returns 30 since config is nil

let name = "Alice"
let display = name ?: "Guest"  # Returns "Alice" since name is not nil
```

The Elvis operator returns the left operand if it's truthy, otherwise the right operand.

### Elvis with Variables

```quest
let user_input = nil
let default_value = "N/A"
let result = user_input ?: default_value  # "N/A"
```

### Elvis Chaining

```quest
let primary = nil
let secondary = nil
let fallback = "default"
let result = primary ?: secondary ?: fallback  # "default"
```

## Optional Fields in Types

Type definitions can mark fields as optional using the `?` suffix:

```quest
type Person
    name: str       # Required
    age: int?       # Optional - defaults to nil
    email: str?     # Optional - defaults to nil
end

let person = Person.new(name: "Alice")
puts(person.age)     # nil
puts(person.email)   # nil
```

Optional fields automatically default to nil if not provided.

## Nil Checking Patterns

### Explicit Comparison

```quest
let value = get_config("timeout")

if value == nil
    puts("No timeout configured")
end

if value != nil
    puts("Timeout: " .. value._str())
end
```

### Truthiness Check

```quest
let value = get_config("timeout")

if value
    puts("Timeout: " .. value._str())
else
    puts("No timeout configured")
end
```

### Elvis with Default

```quest
let value = get_config("timeout") ?: 30
puts("Timeout: " .. value._str())
```

## Dictionary Access

Accessing a non-existent dictionary key returns nil:

```quest
let config = {"port": 8080}

let port = config["port"]      # 8080
let host = config["host"]      # nil (key doesn't exist)

# Use Elvis for defaults
let host_with_default = config["host"] ?: "localhost"
```

## Array Access

Accessing an out-of-bounds array index raises an error, not nil:

```quest
let arr = [1, 2, 3]

# This raises IndexErr:
# let item = arr[10]

# Instead, check bounds first:
let index = 10
if index < arr.len()
    let item = arr[index]
else
    puts("Index out of bounds")
end
```

## Methods

### _str() → String

Returns the string representation of nil:

```quest
let value = nil
puts(value._str())  # "nil"
```

### _type() → String

Returns the type name:

```quest
let value = nil
puts(value._type())  # "Nil"
```

### _id() → Int

Returns the unique ID (always 0 for nil):

```quest
let value = nil
puts(value._id())  # 0
```

## Function Return Values

Functions without an explicit return value return nil:

```quest
fun print_greeting(name)
    puts("Hello, " .. name)
    # No return statement
end

let result = print_greeting("Alice")
puts(result)  # nil
```

Explicit nil returns:

```quest
fun find_user(id)
    # Search logic...
    if not found
        return nil
    end
    return user
end

let user = find_user(123)
if user == nil
    puts("User not found")
end
```

## REPL Behavior

The Quest REPL suppresses nil values to reduce noise:

```quest
>> let x = 5
>> x = 10        # No output (assignment returns nil)
>> puts("hi")    # Prints "hi" but no nil return value shown
```

Only non-nil values are printed in the REPL.

## Common Patterns

### Safe Navigation

```quest
fun get_user_email(user_id)
    let user = find_user(user_id)
    if user == nil
        return nil
    end
    return user.email
end

let email = get_user_email(123) ?: "no-email@example.com"
```

### Lazy Initialization

```quest
let cache = nil

fun get_config()
    if cache == nil
        cache = load_config_from_file()
    end
    return cache
end
```

### Optional Parameters with Nil Check

```quest
fun greet(name, greeting)
    let msg = greeting ?: "Hello"
    puts(msg .. ", " .. name)
end

greet("Alice", nil)      # "Hello, Alice"
greet("Alice", "Hi")     # "Hi, Alice"
```

Note: With default parameters (QEP-033), this can be written more cleanly:

```quest
fun greet(name, greeting = "Hello")
    puts(greeting .. ", " .. name)
end
```

### Validation Functions

```quest
fun validate_input(value)
    if value == nil
        raise ValueErr.new("Value cannot be nil")
    end
    # Process value...
end
```

## Nil vs Empty Values

Nil is distinct from empty collections:

```quest
let nothing = nil
let empty_array = []
let empty_dict = {}
let empty_string = ""

nothing == nil          # true
empty_array == nil      # false
empty_dict == nil       # false
empty_string == nil     # false

# All empty collections are truthy
if empty_array
    puts("Empty arrays are truthy!")  # This prints
end
```

## Type Safety with Optional Fields

When working with optional fields, always handle the nil case:

```quest
type Config
    port: int
    host: str?
    timeout: int?
end

let config = Config.new(port: 8080)

# Safe access
let host = config.host ?: "localhost"
let timeout = config.timeout ?: 30

# Or explicit checking
if config.timeout != nil
    set_timeout(config.timeout)
else
    set_timeout(30)  # Default
end
```

## Nil in Collections

Collections can contain nil values:

```quest
let mixed = [1, nil, 3, nil, 5]
let values = {"a": 1, "b": nil, "c": 3}

# Filter out nils
let non_nil = []
for item in mixed
    if item != nil
        non_nil.push(item)
    end
end
```

## Performance

Nil checking is extremely fast. The singleton implementation means:
- All nil values share the same memory location
- Equality checks are simple pointer comparisons
- No memory allocation or deallocation needed

## See Also

- [Bool](bool.md) - Boolean type and truthiness
- [Control Flow](../language/control-flow.md) - Conditional statements
- [Types](../language/types.md) - Optional fields
- [Dict](dicts.md) - Dictionary access and nil
- [Functions](../language/functions.md) - Return values
