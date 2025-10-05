# QEP-006: std/encoding/csv - CSV File Handling

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Module Name:** `std/encoding/csv`

## Abstract

This QEP specifies the `std/encoding/csv` module for reading and writing CSV (Comma-Separated Values) files in Quest. The module provides both simple parse/stringify functions for basic use cases and reader/writer objects for advanced scenarios like streaming large files, custom delimiters, and header handling.

## Rationale

CSV is one of the most common data interchange formats, used for:
- Spreadsheet exports (Excel, Google Sheets)
- Data science and analysis
- Database imports/exports
- Configuration files
- Log files and reports

Quest needs CSV support that is:
1. **Simple for common cases** - `csv.parse()` and `csv.stringify()` for basic usage
2. **Powerful for complex cases** - Reader/Writer objects for streaming, custom options
3. **Type-aware** - Automatic type detection (Int, Float, Str, Bool)
4. **Header-aware** - Access rows as dictionaries using column names
5. **Flexible** - Custom delimiters, quotes, escape characters

## Design Philosophy

**Two-tier API:**

```quest
# Simple API (parse entire file at once)
csv.parse(text)          # Quick and easy
csv.stringify(data)      # Quick and easy

# Advanced API (streaming, custom options)
csv.reader(text)         # Stream rows, custom delimiters
csv.writer()             # Build CSV incrementally
```

This matches Python's `csv` module pattern: simple functions for simple cases, objects for complex cases.

## Rust Implementation

**Primary dependency:** `csv = "1.3"` (most popular Rust CSV crate)

**Key features:**
- Automatic type inference
- Header support
- Custom delimiters and quotes
- Streaming (doesn't load entire file into memory)
- RFC 4180 compliant

## API Design

### Simple API

#### `csv.parse(text)` / `csv.parse(text, options)`

Parse CSV text into array of arrays or array of dictionaries.

**Parameters:**
- `text` (Str) - CSV text to parse
- `options` (Dict, optional) - Parse options

**Options:**
- `has_headers` (Bool) - First row is headers (default: true)
- `delimiter` (Str) - Field delimiter (default: ",")
- `quote` (Str) - Quote character (default: "\"")
- `trim` (Bool) - Trim whitespace (default: true)

**Returns:**
- If `has_headers` is true: Array of Dictionaries (column name → value)
- If `has_headers` is false: Array of Arrays (raw rows)

**Example:**
```quest
use "std/encoding/csv"

let csv_text = """
name,age,city
Alice,30,NYC
Bob,25,LA
"""

let rows = csv.parse(csv_text)
for row in rows
    puts(row["name"] .. " is " .. row["age"])
end
# Alice is 30
# Bob is 25
```

#### `csv.stringify(data)` / `csv.stringify(data, options)`

Convert array of dictionaries or arrays to CSV text.

**Parameters:**
- `data` (Array) - Array of dictionaries or arrays
- `options` (Dict, optional) - Stringify options

**Options:**
- `headers` (Array) - Column headers (default: infer from first row)
- `delimiter` (Str) - Field delimiter (default: ",")
- `quote` (Str) - Quote character (default: "\"")

**Returns:** CSV text (Str)

**Example:**
```quest
use "std/encoding/csv"

let data = [
    {"name": "Alice", "age": "30", "city": "NYC"},
    {"name": "Bob", "age": "25", "city": "LA"}
]

let csv_text = csv.stringify(data)
puts(csv_text)
# name,age,city
# Alice,30,NYC
# Bob,25,LA
```

### Advanced API (Reader/Writer Objects)

#### `csv.reader(text)` / `csv.reader(text, options)`

Create a CSV reader for streaming rows.

**Parameters:**
- `text` (Str) - CSV text
- `options` (Dict, optional) - Same as `csv.parse()`

**Returns:** CsvReader object

**CsvReader Methods:**
- `next()` - Read next row (Dict or Array), returns Nil when done
- `read_all()` - Read all remaining rows
- `headers()` - Get headers (Array or Nil)

**Example:**
```quest
use "std/encoding/csv"

let reader = csv.reader(csv_text)

# Stream rows one at a time
let row = reader.next()
while row != nil
    puts(row["name"])
    row = reader.next()
end
```

#### `csv.writer()` / `csv.writer(options)`

Create a CSV writer for building CSV incrementally.

**Parameters:**
- `options` (Dict, optional) - Writer options

**Options:**
- `delimiter` (Str) - Field delimiter (default: ",")
- `quote` (Str) - Quote character (default: "\"")

**Returns:** CsvWriter object

**CsvWriter Methods:**
- `write_row(row)` - Write row (Array or Dict)
- `write_rows(rows)` - Write multiple rows
- `write_headers(headers)` - Write header row
- `to_string()` - Get CSV text

**Example:**
```quest
use "std/encoding/csv"

let writer = csv.writer()
writer.write_headers(["name", "age", "city"])
writer.write_row(["Alice", "30", "NYC"])
writer.write_row(["Bob", "25", "LA"])

let csv_text = writer.to_string()
puts(csv_text)
```

## Type Handling

### Automatic Type Detection (Parse)

When parsing, Quest should auto-detect types:

```quest
# CSV input:
# name,age,active,score
# Alice,30,true,95.5

let rows = csv.parse(csv_text)
let row = rows[0]

puts(row["name"].cls())   # "Str"
puts(row["age"].cls())    # "Int" (auto-detected)
puts(row["active"].cls()) # "Bool" (auto-detected)
puts(row["score"].cls())  # "Float" (auto-detected)
```

**Detection rules:**
1. Try Int (digits only, optional leading `-`)
2. Try Float (contains `.` or `e`)
3. Try Bool (`true`, `false`, case-insensitive)
4. Default to Str

### Stringify Behavior

When stringifying, convert all values to strings:

```quest
let data = [
    {"name": "Alice", "age": 30, "active": true, "score": 95.5}
]
let csv = csv.stringify(data)
# name,age,active,score
# Alice,30,true,95.5
```

## Complete Examples

### Reading CSV from File

```quest
use "std/encoding/csv"
use "std/io"

let csv_text = io.read("users.csv")
let users = csv.parse(csv_text)

for user in users
    puts(user["name"] .. " (" .. user["email"] .. ")")
end
```

### Writing CSV to File

```quest
use "std/encoding/csv"
use "std/io"

let data = [
    {"name": "Alice", "email": "alice@example.com", "age": "30"},
    {"name": "Bob", "email": "bob@example.com", "age": "25"}
]

let csv_text = csv.stringify(data)
io.write("output.csv", csv_text)
```

### Custom Delimiter (TSV)

```quest
use "std/encoding/csv"

let tsv_text = "name\tage\tcity\nAlice\t30\tNYC"
let rows = csv.parse(tsv_text, {"delimiter": "\t"})

let data = [{"name": "Alice", "age": "30"}]
let tsv = csv.stringify(data, {"delimiter": "\t"})
```

### CSV without Headers

```quest
use "std/encoding/csv"

let csv_text = "Alice,30,NYC\nBob,25,LA"
let rows = csv.parse(csv_text, {"has_headers": false})

for row in rows
    puts(row[0] .. " is " .. row[1])
end
# Alice is 30
# Bob is 25
```

### Streaming Large Files

```quest
use "std/encoding/csv"
use "std/io"

let csv_text = io.read("huge_file.csv")
let reader = csv.reader(csv_text)

# Process one row at a time (memory efficient)
let count = 0
let row = reader.next()
while row != nil
    count = count + 1
    # Process row...
    row = reader.next()
end

puts("Processed " .. count .. " rows")
```

### Building CSV Incrementally

```quest
use "std/encoding/csv"

let writer = csv.writer()
writer.write_headers(["id", "name", "status"])

for i in 1 to 1000
    writer.write_row([i, "User_" .. i, "active"])
end

let csv = writer.to_string()
```

### Data Transformation

```quest
use "std/encoding/csv"
use "std/io"

# Read CSV, transform, write CSV
let input = io.read("input.csv")
let rows = csv.parse(input)

# Filter and transform
let filtered = []
for row in rows
    if row["age"] > 25
        filtered.push({
            "name": row["name"].upper(),
            "age": row["age"],
            "status": "senior"
        })
    end
end

let output = csv.stringify(filtered)
io.write("output.csv", output)
```

### Handling Missing Values

```quest
use "std/encoding/csv"

let csv_text = """
name,age,city
Alice,30,NYC
Bob,,LA
Charlie,35,
"""

let rows = csv.parse(csv_text)

for row in rows
    let age = row["age"] or "unknown"
    let city = row["city"] or "unknown"
    puts(row["name"] .. ": age=" .. age .. ", city=" .. city)
end
# Alice: age=30, city=NYC
# Bob: age=unknown, city=LA
# Charlie: age=35, city=unknown
```

## Implementation Notes

### Rust Structure

```rust
// src/modules/encoding/csv.rs
use csv::{Reader, Writer, ReaderBuilder, WriterBuilder};

// Simple API
pub fn csv_parse(text: String, options: HashMap<String, QValue>) -> Result<Vec<HashMap<String, QValue>>, String> {
    let has_headers = options.get("has_headers").map(|v| v.as_bool()).unwrap_or(true);
    let delimiter = options.get("delimiter").map(|v| v.as_str()).unwrap_or(",");

    let mut reader = ReaderBuilder::new()
        .delimiter(delimiter.as_bytes()[0])
        .has_headers(has_headers)
        .from_reader(text.as_bytes());

    // Parse and convert to QValue...
}

// Reader object
pub struct QCsvReader {
    reader: Reader<&[u8]>,
    headers: Option<Vec<String>>,
}

// Writer object
pub struct QCsvWriter {
    writer: Writer<Vec<u8>>,
    headers: Option<Vec<String>>,
}
```

### Quest Type System

```rust
// Add to QValue enum
pub enum QValue {
    // ...
    CsvReader(Box<QCsvReader>),
    CsvWriter(Box<QCsvWriter>),
}
```

## Testing Strategy

```quest
# test/encoding/csv_test.q
use "std/test"
use "std/encoding/csv"

test.describe("csv.parse", fun ()
    test.it("parses simple CSV with headers", fun ()
        let csv = "name,age\nAlice,30\nBob,25"
        let rows = csv.parse(csv)

        test.assert_eq(rows.len(), 2, nil)
        test.assert_eq(rows[0]["name"], "Alice", nil)
        test.assert_eq(rows[0]["age"], 30, nil)  # Auto-converted to Int
    end)

    test.it("parses CSV without headers", fun ()
        let csv = "Alice,30\nBob,25"
        let rows = csv.parse(csv, {"has_headers": false})

        test.assert_eq(rows[0][0], "Alice", nil)
        test.assert_eq(rows[0][1], 30, nil)
    end)
end)
```

## Implementation Checklist

- [ ] Create QEP-006 specification
- [ ] Add `csv` crate to Cargo.toml
- [ ] Implement `csv.parse()` with type detection
- [ ] Implement `csv.stringify()`
- [ ] Implement `CsvReader` object type
- [ ] Implement `CsvWriter` object type
- [ ] Add QValue::CsvReader and QValue::CsvWriter variants
- [ ] Create `lib/std/encoding/csv.q` documentation
- [ ] Write comprehensive test suite
- [ ] Register in module system
- [ ] Add to docs/docs/stdlib/encoding.md

## Open Questions

1. **Type detection - opt-in or automatic?**
   - Auto-detect by default?
   - Or add `types: false` option to keep everything as strings?
   - **Decision:** Auto-detect by default, add option to disable

2. **Empty values - nil or empty string?**
   - `"Alice,,NYC"` - should middle value be `nil` or `""`?
   - **Decision:** Empty string by default, `nil` with `empty_as_nil: true` option

3. **Should we support CSV writing to files directly?**
   - `csv.write_file(path, data)`?
   - **Decision:** No, keep separation of concerns. Use `io.write()` + `csv.stringify()`

4. **Should reader/writer handle file I/O?**
   - Reader could take file path instead of text
   - **Decision:** Phase 2 - keep text-based for v1

## Conclusion

The `std/encoding/csv` module provides Quest with industry-standard CSV handling. By offering both simple functions for common cases and streaming objects for advanced usage, we serve beginners and power users alike. Automatic type detection makes working with CSV data natural in Quest, while flexible options support various CSV dialects.
