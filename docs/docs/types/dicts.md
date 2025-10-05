# dicts

Dictionaries (dicts) in Quest are key-value collections where keys are strings and values can be any type. Dicts are immutable by default - methods that modify dicts return new dicts rather than mutating the original.

## Dict Literals

```quest
let empty = {}
let person = {"name": "Alice", "age": 30}
let mixed = {"count": 42, "active": true, "data": [1, 2, 3]}
let nested = {
    "user": {
        "name": "Bob",
        "email": "bob@example.com"
    },
    "settings": {
        "theme": "dark"
    }
}
```

## Dict Access

Dicts can be accessed using bracket notation with string keys:

```quest
let person = {"name": "Alice", "age": 30}
puts(person["name"])  # Alice
puts(person["age"])   # 30
```

Accessing a non-existent key returns `nil`:

```quest
let dict = {"x": 10}
puts(dict["y"])  # nil
```

## Immutability Pattern

Since dicts are immutable in expressions, use reassignment to "update" a dict:

```quest
let config = {"debug": false, "timeout": 30}

# Add or update a key
config = config.set("debug", true)
puts(config)  # {debug: true, timeout: 30}

# Remove a key
config = config.remove("timeout")
puts(config)  # {debug: true}
```

## Common Patterns

### Building Dicts

```quest
let dict = {}
dict = dict.set("name", "Alice")
dict = dict.set("age", 30)
dict = dict.set("active", true)
puts(dict)  # {active: true, age: 30, name: Alice}
```

### Checking for Keys

```quest
let settings = {"theme": "dark", "font": "mono"}

if settings.contains("theme")
    puts("Theme is set to: " .. settings["theme"])
end

# Using get with default value
let timeout = settings.get("timeout", 30)
puts(timeout)  # 30 (default, since "timeout" key doesn't exist)
```

### Iterating Over Keys

```quest
let scores = {"Alice": 95, "Bob": 87, "Carol": 92}

# Get all keys
let names = scores.keys()
names.each(fun (name)
    puts(name .. ": " .. scores[name])
end)
# Output:
# Alice: 95
# Bob: 87
# Carol: 92
```

### Iterating Over Values

```quest
let inventory = {"apples": 10, "oranges": 5, "bananas": 8}

let total = inventory.values().reduce(fun (sum, count)
    sum + count
end, 0)
puts("Total items: " .. total)  # Total items: 23
```

### Transforming Values

```quest
let prices = {"apple": 1.5, "banana": 0.8, "orange": 1.2}

# Apply a discount by creating a new dict
let discounted = {}
prices.keys().each(fun (item)
    let old_price = prices[item]
    let new_price = old_price * 0.9  # 10% off
    discounted = discounted.set(item, new_price)
end)
```

### Merging Dicts

```quest
let defaults = {"theme": "light", "size": 12, "autosave": true}
let user_prefs = {"theme": "dark", "size": 14}

# Merge by copying keys from user_prefs into defaults
let config = defaults
user_prefs.keys().each(fun (key)
    config = config.set(key, user_prefs[key])
end)
puts(config)  # {autosave: true, size: 14, theme: dark}
```

### Filtering Keys

```quest
let data = {"a": 1, "b": 2, "c": 3, "d": 4}

# Keep only keys where value > 2
let filtered = {}
data.keys().each(fun (key)
    if data[key] > 2
        filtered = filtered.set(key, data[key])
    end
end)
puts(filtered)  # {c: 3, d: 4}
```

## Dict Methods

### `len()`
Returns the number of key-value pairs in the dict.

**Returns:** Num

**Example:**
```quest
let dict = {"a": 1, "b": 2, "c": 3}
puts(dict.len())  # 3

let empty = {}
puts(empty.len())  # 0
```

### `keys()`
Returns an array of all keys in the dict (in arbitrary order).

**Returns:** Array (of strings)

**Example:**
```quest
let person = {"name": "Alice", "age": 30, "city": "NYC"}
let keys = person.keys()
puts(keys)  # [age, city, name] (sorted alphabetically)
```

### `values()`
Returns an array of all values in the dict (in arbitrary order, corresponding to keys order).

**Returns:** Array (of any type)

**Example:**
```quest
let scores = {"Alice": 95, "Bob": 87, "Carol": 92}
let all_scores = scores.values()
puts(all_scores)  # [95, 87, 92]

# Calculate average
let avg = all_scores.reduce(fun (sum, score) sum + score end, 0) / all_scores.len()
puts(avg)  # 91.33...
```

### `contains(key)`
Checks if the dict contains the specified key.

**Parameters:**
- `key` - Key to check for (string)

**Returns:** Bool (true if key exists)

**Example:**
```quest
let config = {"debug": true, "port": 8080}
puts(config.contains("debug"))   # true
puts(config.contains("host"))    # false

# Use for conditional access
if config.contains("timeout")
    puts("Timeout: " .. config["timeout"])
else
    puts("No timeout configured")
end
```

### `get(key, default?)`
Returns the value for the given key. If the key doesn't exist, returns the optional default value, or `nil` if no default is provided.

**Parameters:**
- `key` - Key to look up (string)
- `default` - Optional default value to return if key not found (any type)

**Returns:** Value at key, or default, or nil

**Example:**
```quest
let settings = {"theme": "dark", "size": 12}

# Get existing key
puts(settings.get("theme"))      # dark

# Get missing key (returns nil)
puts(settings.get("font"))       # nil

# Get missing key with default
puts(settings.get("font", "mono"))     # mono
puts(settings.get("autosave", false))  # false

# Useful for configuration with defaults
let timeout = settings.get("timeout", 30)
let retries = settings.get("retries", 3)
```

### `set(key, value)`
Returns a new dict with the key set to the value. If the key already exists, its value is updated in the new dict.

**Parameters:**
- `key` - Key to set (string)
- `value` - Value to associate with key (any type)

**Returns:** Dict (new dict with key set)

**Example:**
```quest
let dict = {"a": 1, "b": 2}

# Add new key
let dict2 = dict.set("c", 3)
puts(dict)   # {a: 1, b: 2} (original unchanged)
puts(dict2)  # {a: 1, b: 2, c: 3}

# Update existing key
let dict3 = dict.set("a", 100)
puts(dict3)  # {a: 100, b: 2}

# Chain multiple sets
let config = {}
    .set("host", "localhost")
    .set("port", 8080)
    .set("debug", true)
puts(config)  # {debug: true, host: localhost, port: 8080}
```

### `remove(key)`
Returns a new dict with the specified key removed. If the key doesn't exist, returns a copy of the original dict.

**Parameters:**
- `key` - Key to remove (string)

**Returns:** Dict (new dict without key)

**Example:**
```quest
let dict = {"a": 1, "b": 2, "c": 3}

let dict2 = dict.remove("b")
puts(dict)   # {a: 1, b: 2, c: 3} (original unchanged)
puts(dict2)  # {a: 1, c: 3}

# Removing non-existent key is safe
let dict3 = dict.remove("z")
puts(dict3)  # {a: 1, b: 2, c: 3}

# Chain multiple removals
let cleaned = dict
    .remove("a")
    .remove("b")
puts(cleaned)  # {c: 3}
```

## Dict Display Format

Dicts are displayed with keys sorted alphabetically:

```quest
let dict = {"zebra": 1, "apple": 2, "monkey": 3}
puts(dict)  # {apple: 2, monkey: 3, zebra: 1}
```

The format is `{key: value, key: value, ...}` with:
- Keys sorted alphabetically
- Space after colon
- Comma-space between pairs
- No trailing comma

## Bracket Notation vs Methods

Quest supports both bracket notation and method calls:

```quest
let dict = {"x": 10, "y": 20}

# Bracket notation - direct access
puts(dict["x"])          # 10
puts(dict["z"])          # nil (missing key)

# Method calls - more explicit
puts(dict.get("x"))      # 10
puts(dict.get("z", 0))   # 0 (with default)
puts(dict.contains("x"))      # true
```

Bracket notation is more concise for reading, while methods provide more control (like default values with `get()`).

## Notes

- Dicts are **key-value** collections with **string keys**
- Dicts are **immutable** (methods return new dicts)
- Use reassignment (`dict = dict.set(k, v)`) to update dict variables
- Keys are always strings; values can be any type
- Accessing non-existent keys with `[]` returns `nil`
- Keys are displayed in **alphabetical order** when printing
- Empty dict is `{}`
- The `get()` method supports optional default values
- Use `contains()` to check for key existence before accessing
- Dict values can be any Quest type (numbers, strings, bools, arrays, other dicts, etc.)

## Comparison with Arrays

| Feature | Array | Dict |
|---------|-------|------|
| Keys | Numeric indices (0, 1, 2...) | String keys |
| Access | `arr[0]` | `dict["key"]` |
| Order | Preserves insertion order | Keys sorted alphabetically for display |
| Add | `.push(value)` | `.set(key, value)` |
| Remove | `.pop()`, `.shift()` | `.remove(key)` |
| Check | `.contains(value)` | `.contains(key)` |
| Size | `.len()` | `.len()` |
| Iterate | `.each(fun (elem) ... end)` | `.keys().each(fun (key) ... end)` |
