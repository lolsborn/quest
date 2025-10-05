# json - JSON Encode/Decode

The `json` module provides JSON parsing and serialization functionality.

## Parsing

### `json.parse(text)`
Parse JSON string into Quest object

**Parameters:**
- `text` - JSON string (Str)

**Returns:** Parsed value (Num, Str, Bool, Nil, List, or Dict)

**Raises:** Error if invalid JSON

**Example:**
```quest
let data = json.parse('{"name": "Alice", "age": 30}')
puts(data.name)  # Alice
puts(data.age)   # 30
```

### `json.parse_file(path)`
Parse JSON from file

**Parameters:**
- `path` - File path (Str)

**Returns:** Parsed JSON value

**Example:**
```quest
let config = json.parse_file("config.json")
puts("Host: ", config.host)
puts("Port: ", config.port)
```

### `json.try_parse(text)`
Try to parse JSON, return nil on error instead of raising

**Parameters:**
- `text` - JSON string (Str)

**Returns:** Parsed value or Nil if invalid

**Example:**
```quest
let result = json.try_parse(user_input)
if result == nil
    puts("Invalid JSON")
else
    puts("Parsed successfully")
end
```

## Serialization

### `json.stringify(value, pretty = false)`
Convert Quest value to JSON string

**Parameters:**
- `value` - Value to serialize (Num, Str, Bool, Nil, List, or Dict)
- `pretty` - Pretty print with indentation (Bool, default false)

**Returns:** JSON string (Str)

**Example:**
```quest
let data = {"name": "Bob", "scores": [95, 87, 92]}
let json_str = json.stringify(data)
puts(json_str)  # {"name":"Bob","scores":[95,87,92]}
```

### `json.stringify_pretty(value, indent = 2)`
Convert Quest value to pretty-printed JSON

**Parameters:**
- `value` - Value to serialize
- `indent` - Number of spaces for indentation (Num, default 2)

**Returns:** Formatted JSON string (Str)

**Example:**
```quest
let data = {"name": "Bob", "scores": [95, 87, 92]}
let json_str = json.stringify_pretty(data)
puts(json_str)
# Output:
# {
#   "name": "Bob",
#   "scores": [
#     95,
#     87,
#     92
#   ]
# }
```

### `json.to_file(value, path, pretty = false)`
Serialize value and write to file

**Parameters:**
- `value` - Value to serialize
- `path` - File path (Str)
- `pretty` - Pretty print (Bool, default false)

**Returns:** Nil

**Example:**
```quest
let config = {"host": "localhost", "port": 8080, "debug": true}
json.to_file(config, "config.json", true)
```

## Validation

### `json.is_valid(text)`
Check if string is valid JSON

**Parameters:**
- `text` - String to validate (Str)

**Returns:** Bool (true if valid JSON)

**Example:**
```quest
let input = io.read_line()
if json.is_valid(input)
    let data = json.parse(input)
    process(data)
else
    puts("Error: Invalid JSON format")
end
```

## Type Checking

### `json.is_object(value)`
Check if parsed JSON value is an object (Dict)

**Parameters:**
- `value` - Parsed JSON value

**Returns:** Bool

### `json.is_array(value)`
Check if parsed JSON value is an array (List)

**Parameters:**
- `value` - Parsed JSON value

**Returns:** Bool

**Example:**
```quest
let data = json.parse(input)

if json.is_array(data)
    for item in data
        puts(item)
    end
elif json.is_object(data)
    for key in data.keys()
        puts(key, ": ", data[key])
    end
end
```

## Path Access (JSON Pointer)

### `json.get(data, path, default = nil)`
Get value at JSON path

**Parameters:**
- `data` - Parsed JSON object
- `path` - Dot-separated path (Str) e.g., "user.address.city"
- `default` - Default value if path not found (default nil)

**Returns:** Value at path or default

**Example:**
```quest
let data = json.parse('{"user": {"name": "Alice", "address": {"city": "NYC"}}}')
let city = json.get(data, "user.address.city")
puts(city)  # NYC

let unknown = json.get(data, "user.age", 0)
puts(unknown)  # 0 (default)
```

### `json.set(data, path, value)`
Set value at JSON path

**Parameters:**
- `data` - Parsed JSON object (Dict)
- `path` - Dot-separated path (Str)
- `value` - Value to set

**Returns:** Modified data object

**Example:**
```quest
let data = {"user": {"name": "Alice"}}
json.set(data, "user.age", 30)
json.set(data, "user.address.city", "NYC")
puts(json.stringify_pretty(data))
```

### `json.contains(data, path)`
Check if path exists in JSON object

**Parameters:**
- `data` - Parsed JSON object
- `path` - Dot-separated path (Str)

**Returns:** Bool (true if path exists)

**Example:**
```quest
let data = json.parse_file("config.json")
if json.contains(data, "database.host")
    let host = json.get(data, "database.host")
    puts("Connecting to: ", host)
else
    puts("Database configuration missing")
end
```

## Merging

### `json.merge(obj1, obj2, deep = false)`
Merge two JSON objects

**Parameters:**
- `obj1` - First object (Dict)
- `obj2` - Second object (Dict)
- `deep` - Deep merge nested objects (Bool, default false)

**Returns:** Merged object (Dict)

**Example:**
```quest
let defaults = {"host": "localhost", "port": 8080, "timeout": 30}
let config = {"host": "example.com", "debug": true}
let merged = json.merge(defaults, config)
puts(json.stringify_pretty(merged))
# {
#   "host": "example.com",
#   "port": 8080,
#   "timeout": 30,
#   "debug": true
# }
```

## Schema Validation

### `json.validate(data, schema)`
Validate JSON data against schema

**Parameters:**
- `data` - Parsed JSON value
- `schema` - Schema definition (Dict)

**Returns:** Bool (true if valid)

**Example:**
```quest
let schema = {
    "type": "object",
    "properties": {
        "name": {"type": "string"},
        "age": {"type": "number"}
    },
    "required": ["name"]
}

let data = {"name": "Alice", "age": 30}
if json.validate(data, schema)
    puts("Valid data")
else
    puts("Invalid data")
end
```

## Common Use Cases

### Configuration Files
```quest
# Load configuration
let config = json.parse_file("config.json")
let host = json.get(config, "database.host", "localhost")
let port = json.get(config, "database.port", 5432)

# Update and save configuration
json.set(config, "last_updated", time.now())
json.to_file(config, "config.json", true)
```

### API Requests/Responses
```quest
# Make API request
let request_body = json.stringify({
    "action": "create_user",
    "data": {"name": "Alice", "email": "alice@example.com"}
})

let response = http.post("https://api.example.com/users", request_body)
let result = json.parse(response.body)

if result.success
    puts("User created with ID: ", result.user_id)
else
    puts("Error: ", result.error)
end
```

### Data Processing
```quest
# Load and process JSON data
let users = json.parse_file("users.json")
let active_users = []

for user in users
    if user.active
        active_users.append(user)
    end
end

json.to_file(active_users, "active_users.json", true)
```

### Logging
```quest
# Structured JSON logging
let log_entry = {
    "timestamp": time.now(),
    "level": "ERROR",
    "message": "Connection failed",
    "details": {
        "host": "db.example.com",
        "error": "timeout"
    }
}

let log_line = json.stringify(log_entry)
io.append("logs/app.log", log_line + "\n")
```

### Data Validation
```quest
# Validate user input
let user_input = io.read("user_data.json")
let data = json.try_parse(user_input)

if data == nil
    puts("Error: Invalid JSON format")
    return
end

if !json.contains(data, "email") or !json.contains(data, "name")
    puts("Error: Missing required fields")
    return
end

# Process valid data
puts("Processing user: ", data.name)
```

### Nested Data Access
```quest
# Access deeply nested data safely
let response = json.parse_file("api_response.json")

let city = json.get(response, "data.user.address.city", "Unknown")
let zip = json.get(response, "data.user.address.zip", "00000")

puts("Location: ", city, " ", zip)
```

### Data Export
```quest
# Export data to JSON
let results = [
    {"id": 1, "name": "Alice", "score": 95},
    {"id": 2, "name": "Bob", "score": 87},
    {"id": 3, "name": "Carol", "score": 92}
]

json.to_file(results, "results.json", true)
puts("Exported ", results.len(), " records")
```
