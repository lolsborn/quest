"""
#CSV (Comma-Separated Values) file parsing and generation.

This module provides functions to read and write CSV files with automatic type
detection, header support, and customizable delimiters.

**Example:**
```quest
use "std/encoding/csv"
use "std/io"

# Parse CSV file
let csv_text = io.read("users.csv")
let users = csv.parse(csv_text)

for user in users
    puts(user["name"] .. " - " .. user["email"])
end

# Write CSV file
let data = [
    {"name": "Alice", "age": "30"},
    {"name": "Bob", "age": "25"}
]
let csv = csv.stringify(data)
io.write("output.csv", csv)
```
"""

%fun parse(text, options)
"""
## Parse CSV text into array of dictionaries or arrays.

By default, treats first row as headers and returns array of dictionaries.
Automatically detects and converts types (Int, Float, Bool, Str).

**Parameters:**
- `text` (**Str**) - CSV text to parse
- `options` (**Dict**, optional) - Parse options

**Options:**
- `has_headers` (**Bool**) - First row contains headers (default: true)
- `delimiter` (**Str**) - Field delimiter (default: ",")
- `trim` (**Bool**) - Trim whitespace from fields (default: true)

**Returns:**
- If `has_headers` is true: **Array** of **Dict** (column name → value)
- If `has_headers` is false: **Array** of **Array** (raw rows)

**Type Detection:**
- Integers: `"42"` → `42` (Int)
- Floats: `"3.14"` → `3.14` (Float)
- Booleans: `"true"`, `"false"` → Bool (case-insensitive)
- Everything else: Str

**Example:**
```quest
# With headers (default)
let csv_text = "name,age,active\nAlice,30,true\nBob,25,false"

let rows = csv.parse(csv_text)
for row in rows
    puts(row["name"] .. " is " .. row["age"])
    # Types are auto-detected:
    # row["age"] is Int, row["active"] is Bool
end

# Without headers
let csv2 = "Alice,30\nBob,25"
let rows2 = csv.parse(csv2, {"has_headers": false})
puts(rows2[0][0])  # "Alice"
puts(rows2[0][1])  # 30 (Int)

# Custom delimiter (TSV)
let tsv = "name\tage\nAlice\t30"
let rows3 = csv.parse(tsv, {"delimiter": "\t"})
```
"""

%fun stringify(data, options)
"""
## Convert array of dictionaries or arrays to CSV text.

**Parameters:**
- `data` (**Array**) - Array of Dict or Array of Array
- `options` (**Dict**, optional) - Stringify options

**Options:**
- `delimiter` (**Str**) - Field delimiter (default: ",")
- `headers` (**Array**) - Custom headers (default: infer from first row)

**Returns:** **Str** - CSV formatted text

**Behavior:**
- If data is array of Dict: Writes headers automatically
- If data is array of Array: No headers (unless provided in options)
- All values converted to strings
- Strings with delimiter/quotes are automatically quoted

**Example:**
```quest
# Array of dictionaries
let users = [
    {"name": "Alice", "age": "30", "city": "NYC"},
    {"name": "Bob", "age": "25", "city": "LA"}
]
let csv = csv.stringify(users)
puts(csv)
# name,age,city
# Alice,30,NYC
# Bob,25,LA

# Array of arrays
let data = [
    ["Alice", "30", "NYC"],
    ["Bob", "25", "LA"]
]
let csv2 = csv.stringify(data)
puts(csv2)
# Alice,30,NYC
# Bob,25,LA

# Custom delimiter
let tsv = csv.stringify(users, {"delimiter": "\t"})

# Custom headers
let csv3 = csv.stringify(data, {"headers": ["Name", "Age", "City"]})
# Name,Age,City
# Alice,30,NYC
# Bob,25,LA
```
"""
