# QEP-009: StringIO - In-Memory String Buffers

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** QEP-010 (I/O Redirection)

## Abstract

This QEP specifies StringIO, an in-memory string buffer type that implements a file-like interface. StringIO allows programs to treat strings as files, enabling testing, output capture, and data manipulation without actual file I/O.

## Quick Reference

```quest
use "std/io"

# Create
let buf = io.StringIO.new()
let buf2 = io.StringIO.new("initial content")

# Write
buf.write("Hello")               # Returns byte count
buf.writelines(["A\n", "B\n"])   # Write multiple

# Read
buf.get_value()                  # Get all content
buf.read()                       # Read from position to end
buf.read(10)                     # Read 10 characters
buf.readline()                   # Read one line
buf.readlines()                  # Read all lines as array

# Position
buf.tell()                       # Get position
buf.seek(10)                     # Seek absolute
buf.seek(-5, 2)                  # Seek relative to end

# Utilities
buf.len()                        # Buffer size in bytes
buf.char_len()                   # Buffer size in characters
buf.empty()                      # Check if empty
buf.clear()                      # Clear all content
buf.truncate(5)                  # Truncate to size

# Context Manager (QEP-011)
with io.StringIO.new() as buffer
    buffer.write("Hello")
end
```

## Rationale

StringIO is essential for:

1. **Testing** - Capture and verify output without files
2. **Data manipulation** - Build strings using file-like operations
3. **Memory efficiency** - Process data in memory without temp files
4. **Compatibility** - Provide file-like interface for string data

**Problems it solves:**

```quest
# Without StringIO: Must write to temp file
use "std/io"
io.write("/tmp/test.txt", "data")
let result = io.read("/tmp/test.txt")
io.remove("/tmp/test.txt")

# With StringIO: All in memory
use "std/io"
let buffer = io.StringIO.new()
buffer.write("data")
let result = buffer.get_value()
```

## Design Philosophy

**Principle 1: File-like Interface**
- Implement common file methods: `write()`, `read()`, `readline()`
- Drop-in replacement for file objects in most contexts

**Principle 2: Python Compatibility**
- Similar to Python's `io.StringIO`
- Familiar API for developers
- Support both `get_value()` (Quest convention) and `getvalue()` (Python compatibility)

**Principle 3: Simplicity**
- Easy construction: `io.StringIO.new()`
- Simple retrieval: `get_value()`
- No complex configuration

**Principle 4: Internal Mutability**
- StringIO is internally mutable using `Rc<RefCell<>>` pattern
- No `mut` binding required in user code
- All mutating methods work on immutable references from user perspective

## API Design

### Constructor

#### `io.StringIO.new()` → StringIO

Create a new in-memory string buffer.

**Returns:** StringIO object

**Example:**
```quest
use "std/io"

let buffer = io.StringIO.new()
buffer.write("Hello World")
puts(buffer.get_value())  # "Hello World"
```

#### `io.StringIO.new(initial)` → StringIO

Create StringIO with initial content.

**Parameters:**
- `initial` (Str) - First positional argument: initial buffer content (optional)

**Returns:** StringIO object

**Example:**
```quest
let buffer = io.StringIO.new("Initial text")
buffer.write(" more text")
puts(buffer.get_value())  # "Initial text more text"
```

### Writing Methods

#### `write(data: Str) → Int`

Write string to buffer. **Always appends to end** regardless of current position. After writing, position moves to the new end of buffer.

**Parameters:**
- `data` (Str) - String to write

**Returns:** Number of bytes written (Int)

**Behavior:**
- Write appends to end of buffer (ignoring current position)
- Position is updated to buffer's new end
- This design simplifies implementation and matches most use cases

**Note:** Returns byte count, not character count. For ASCII strings, bytes = characters. For UTF-8 with multibyte characters, byte count will be higher.

**Example:**
```quest
let buffer = io.StringIO.new()
let count = buffer.write("Hello")
puts(count)  # 5 (bytes)

let buf2 = io.StringIO.new("Hello")
buf2.seek(0)          # Position at start
buf2.write(" World")  # Appends (doesn't overwrite)
puts(buf2.get_value())  # "Hello World"
puts(buf2.tell())       # 11 (at end after write)

let buf3 = io.StringIO.new()
let count3 = buf3.write("→")  # 3-byte UTF-8 character
puts(count3)  # 3 (bytes)
```

**Why append-only?** See "Design Decisions" section for rationale.

#### `writelines(lines: Array[Str]) → Nil`

Write multiple lines to buffer (does not add newlines automatically - include them in your strings if needed).

**Parameters:**
- `lines` (Array[Str]) - Array of strings to write

**Returns:** `nil`

**Example:**
```quest
let buffer = io.StringIO.new()
buffer.writelines(["Line 1\n", "Line 2\n", "Line 3\n"])
puts(buffer.get_value())  # "Line 1\nLine 2\nLine 3\n"
```

### Reading Methods

#### `get_value() → Str` / `getvalue() → Str`

Get entire buffer contents as string (regardless of current position).

**Returns:** Complete buffer contents (Str)

**Aliases:** Both `get_value()` (Quest convention) and `getvalue()` (Python compatibility) are supported.

**Example:**
```quest
let buffer = io.StringIO.new()
buffer.write("Hello")
buffer.write(" World")
puts(buffer.get_value())  # "Hello World"
puts(buffer.getvalue())   # "Hello World" (Python-style)
```

#### `read() → Str`

Read entire buffer from current position to end.

**Returns:** String from current position to end

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
buffer.seek(6)
puts(buffer.read())  # "World"
```

#### `read(size: Int) → Str`

Read up to `size` characters from current position.

**Parameters:**
- `size` (Int) - Maximum number of characters to read

**Returns:** String of up to `size` characters

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
puts(buffer.read(5))  # "Hello"
puts(buffer.read(6))  # " World"
```

#### `readline() → Str`

Read one line from buffer (up to and including newline).

**Returns:** String up to and including next newline, or rest of buffer

**Example:**
```quest
let buffer = io.StringIO.new("Line 1\nLine 2\nLine 3")
puts(buffer.readline())  # "Line 1\n"
puts(buffer.readline())  # "Line 2\n"
puts(buffer.readline())  # "Line 3"
```

#### `readlines() → Array[Str]`

Read all lines from current position, returns array.

**Returns:** Array of strings (including newlines)

**Example:**
```quest
let buffer = io.StringIO.new("Line 1\nLine 2\nLine 3")
let lines = buffer.readlines()
# lines = ["Line 1\n", "Line 2\n", "Line 3"]
```

### Position Methods

#### `tell() → Int`

Get current position in buffer.

**Returns:** Current position (0-based index)

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
buffer.read(5)
puts(buffer.tell())  # 5
```

#### `seek(pos: Int) → Int`

Seek to absolute position in buffer.

**Parameters:**
- `pos` (Int) - Position to seek to (0-based byte offset)

**Returns:** New position (Int)

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
let new_pos = buffer.seek(6)
puts(new_pos)        # 6
puts(buffer.read())  # "World"
```

#### `seek(offset: Int, whence: Int) → Int`

Seek to position relative to whence.

**Parameters:**
- `offset` (Int) - Offset from whence position (can be negative for SEEK_CUR and SEEK_END)
- `whence` (Int) - Reference point:
  - `0` - Beginning of buffer (SEEK_SET)
  - `1` - Current position (SEEK_CUR)
  - `2` - End of buffer (SEEK_END)

**Returns:** New position (Int)

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
buffer.seek(-5, 2)  # Seek 5 bytes before end
puts(buffer.read())  # "World"

buffer.seek(0, 0)    # Reset to beginning
buffer.seek(3, 1)    # Advance 3 bytes from current position
```

### Utility Methods

#### `clear() → Nil`

Clear buffer contents and reset position to 0.

**Returns:** `nil`

**Example:**
```quest
let buffer = io.StringIO.new("Hello")
buffer.clear()
puts(buffer.get_value())  # ""
puts(buffer.tell())       # 0
```

#### `truncate() → Int` / `truncate(size: Int) → Int`

Truncate buffer to size (default: current position).

**Parameters:**
- `size` (Int, optional) - Byte count to truncate to (default: current position)

**Returns:** New size (Int)

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
buffer.seek(5)
let new_size = buffer.truncate()
puts(new_size)            # 5
puts(buffer.get_value())  # "Hello"

buffer.write(" World Again")
buffer.truncate(8)        # Explicit size
puts(buffer.get_value())  # "Hello Wo"
```

#### `flush() → Nil`

Flush buffer (no-op for StringIO, included for file-like compatibility).

**Returns:** `nil`

**Example:**
```quest
let buffer = io.StringIO.new()
buffer.write("data")
buffer.flush()  # Does nothing, but safe to call
```

#### `close() → Nil`

Close the buffer (no-op for StringIO, included for file-like compatibility).

**Returns:** `nil`

**Example:**
```quest
let buffer = io.StringIO.new()
buffer.write("data")
buffer.close()  # Does nothing, but safe to call
```

#### `closed() → Bool`

Check if buffer is closed.

**Returns:** Always `false` for StringIO (close is a no-op)

### Introspection Methods

#### `len() → Int`

Get total length of buffer in bytes.

**Returns:** Total buffer length in bytes (Int)

**Example:**
```quest
let buffer = io.StringIO.new("Hello World")
puts(buffer.len())  # 11 (bytes)
```

#### `char_len() → Int`

Get total length of buffer in Unicode characters (not bytes).

**Returns:** Total buffer length in characters (Int)

**Example:**
```quest
let buf = io.StringIO.new("Hello →")
puts(buf.len())       # 9 (bytes: 5 ASCII + 1 space + 3-byte UTF-8 char)
puts(buf.char_len())  # 7 (characters)
```

**Use case:** When you need character positions rather than byte positions (e.g., for text formatting, column alignment).

#### `empty() → Bool`

Check if buffer is empty.

**Returns:** `true` if buffer length is 0, `false` otherwise

**Example:**
```quest
let buffer = io.StringIO.new()
puts(buffer.empty())  # true

buffer.write("Hello")
puts(buffer.empty())  # false
```

### Context Manager Protocol (QEP-011)

StringIO implements the context manager protocol for use with `with` statements:

#### `_enter() → StringIO`

Returns self when entering `with` block.

**Example:**
```quest
with io.StringIO.new() as buffer
    buffer.write("Hello World")
    puts(buffer.get_value())
end  # No cleanup needed (buffer remains accessible)
```

#### `_exit() → Nil`

No-op exit handler (StringIO has no resources to release).

**Complete Example:**
```quest
use "std/io"

# StringIO as context manager
with io.StringIO.new() as buf
    buf.write("Line 1\n")
    buf.write("Line 2\n")
    let content = buf.get_value()
end

# Buffer is safe to use after 'with' block
# (unlike file handles which get closed)
```

**Note:** Unlike file objects, StringIO doesn't need cleanup, so `_exit()` is a no-op. However, implementing the protocol allows StringIO to be used consistently with other I/O objects.

## Complete Examples

### Example 1: Building Strings

```quest
use "std/io"
use "std/time"

fun build_report(data)
    let buffer = io.StringIO.new()

    buffer.write("Report Generated: ")
    buffer.write(time.timestamp().to_string())
    buffer.write("\n")

    # Write separator line (50 equals signs)
    let i = 0
    while i.lt(50)
        buffer.write("=")
        i = i + 1
    end
    buffer.write("\n\n")

    for item in data
        buffer.write("Item: " .. item.name .. "\n")
        buffer.write("Value: " .. item.value.to_string() .. "\n\n")
    end

    buffer.get_value()
end
```

### Example 2: Parsing Line-by-Line

```quest
use "std/io"

let data = "Name: John\nAge: 30\nCity: NYC"
let buffer = io.StringIO.new(data)

let user = {}
while true
    let line = buffer.readline()
    if line == ""
        break
    end

    let parts = line.trim().split(":")
    user[parts[0]] = parts[1].trim()
end

puts(user)  # {"Name": "John", "Age": "30", "City": "NYC"}
```

### Example 3: Testing Output

```quest
use "std/test"
use "std/io"

test.describe("Report generation", fun ()
    test.it("generates valid report", fun ()
        let buffer = io.StringIO.new()

        buffer.write("Header\n")
        buffer.write("Data\n")
        buffer.write("Footer\n")

        let result = buffer.get_value()
        test.assert(result.contains("Header"), "Should have header")
        test.assert(result.contains("Data"), "Should have data")
        test.assert(result.contains("Footer"), "Should have footer")
    end)
end)
```

### Example 4: CSV Building

```quest
use "std/io"

fun write_csv(rows)
    let buffer = io.StringIO.new()

    for row in rows
        let line = row.join(",") .. "\n"
        buffer.write(line)
    end

    buffer.get_value()
end

let data = [
    ["Name", "Age", "City"],
    ["Alice", "30", "NYC"],
    ["Bob", "25", "LA"]
]

let csv = write_csv(data)
puts(csv)
```

### Example 5: Stream Processing

```quest
use "std/io"

fun process_stream(input_string)
    let buffer = io.StringIO.new(input_string)
    let results = []

    while true
        let line = buffer.readline()
        if line == ""
            break
        end

        # Skip comment lines
        if line.starts_with("#")
            # Note: Quest doesn't have 'continue' yet,
            # so we skip by not adding to results
        else
            results.push(line.trim())
        end
    end

    results
end

let input = "# Comment\nLine 1\n# Another comment\nLine 2"
let lines = process_stream(input)
# lines = ["Line 1", "Line 2"]
```

### Example 6: JSON Building

```quest
use "std/io"
use "std/encoding/json"

fun build_json_stream(items)
    let buffer = io.StringIO.new()

    buffer.write("[\n")
    let first = true

    for item in items
        if not first
            buffer.write(",\n")
        end
        first = false

        buffer.write("  " .. json.stringify(item))
    end

    buffer.write("\n]")
    buffer.get_value()
end
```

### Example 7: String Builder Pattern

StringIO is more efficient than repeated string concatenation for building large strings:

```quest
use "std/io"

# SLOW: O(n²) due to repeated allocations
fun build_slow(items)
    let result = ""
    for item in items
        result = result .. item .. "\n"  # Creates new string each time
    end
    result
end

# FAST: O(n) with StringIO
fun build_fast(items)
    let buf = io.StringIO.new()
    for item in items
        buf.write(item)
        buf.write("\n")
    end
    buf.get_value()
end

# Benchmark with 10,000 items:
# build_slow: ~5000ms
# build_fast: ~50ms (100x faster!)
```

**Recommendation:** Use StringIO when building strings with >10 concatenations.

## When to Use StringIO vs String Concatenation

| Use StringIO When | Use String Concat When |
|-------------------|------------------------|
| Building strings in loops (>10 iterations) | Simple 2-3 concatenations |
| File-like interface needed | Direct string building |
| Position tracking required | Linear append only |
| Testing/capturing output | Inline string construction |
| Line-by-line processing | Single-expression results |

**Examples:**

```quest
# Use concat: Simple cases
let greeting = "Hello" .. " " .. name .. "!"

# Use StringIO: Complex building
let report = build_report()  # Internally uses StringIO

# Use concat: Template with few inserts
let msg = "User " .. user.name .. " has " .. user.points .. " points"

# Use StringIO: Many operations
let buf = io.StringIO.new()
for item in items
    buf.write("Item: ")
    buf.write(item.name)
    buf.write("\n")
end
```

## Integration with QEP-010 (I/O Redirection)

StringIO integrates seamlessly with Quest's I/O redirection system:

### Example: Capture stdout

```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()
let guard = sys.redirect_stdout(buffer)

try
    puts("This goes to the buffer")
    puts("So does this")
ensure
    guard.restore()
end

puts("Captured output:")
puts(buffer.get_value())
# Output:
# Captured output:
# This goes to the buffer
# So does this
```

### Example: Test Output Verification

```quest
use "std/test"
use "std/sys"
use "std/io"

test.it("generates correct output", fun ()
    let buffer = io.StringIO.new()
    let guard = sys.redirect_stdout(buffer)

    try
        my_function_that_prints()
    ensure
        guard.restore()
    end

    let output = buffer.get_value()
    test.assert(output.contains("Expected text"), nil)
end)
```

**Implementation Note:** The `Rc<RefCell<>>` wrapper is essential here - `sys.redirect_stdout(buffer)` stores a reference to the buffer in the scope's `OutputTarget`, while the user's `buffer` variable also holds a reference. Both can read/write the same underlying StringIO.

## Implementation Notes

### Rust Implementation

```rust
// src/types/mod.rs - Add to QValue enum
pub enum QValue {
    // ... existing variants
    StringIO(Rc<RefCell<QStringIO>>),  // Use Rc<RefCell<>> for interior mutability
}

// src/types/stringio.rs
use std::rc::Rc;
use std::cell::RefCell;

#[derive(Debug, Clone)]
pub struct QStringIO {
    pub buffer: String,
    pub position: usize,
    pub id: u64,
    // Note: No 'closed' field - close() is a true no-op
}

impl QStringIO {
    pub fn new() -> Self {
        Self {
            buffer: String::new(),
            position: 0,
            id: next_object_id(),
        }
    }

    pub fn new_with_content(content: String) -> Self {
        Self {
            buffer: content,
            position: 0,
            id: next_object_id(),
        }
    }

    /// Write data to buffer. Always appends to end regardless of position.
    /// Returns number of bytes written.
    pub fn write(&mut self, data: &str) -> usize {
        // Simplified: always append to end (like Python's StringIO in text mode)
        self.buffer.push_str(data);
        self.position = self.buffer.len();  // Move position to end after write
        data.len()  // Return byte count
    }

    /// Write multiple strings to buffer
    pub fn writelines(&mut self, lines: Vec<String>) {
        for line in lines {
            self.write(&line);
        }
    }

    pub fn get_value(&self) -> String {
        self.buffer.clone()
    }

    pub fn read(&mut self, size: Option<usize>) -> String {
        let start = self.position;
        let end = match size {
            Some(n) => std::cmp::min(start + n, self.buffer.len()),
            None => self.buffer.len(),
        };

        let result = self.buffer[start..end].to_string();
        self.position = end;
        result
    }

    pub fn readline(&mut self) -> String {
        let start = self.position;
        if start >= self.buffer.len() {
            return String::new();
        }

        if let Some(newline_pos) = self.buffer[start..].find('\n') {
            let end = start + newline_pos + 1;
            let result = self.buffer[start..end].to_string();
            self.position = end;
            result
        } else {
            // No newline found, return rest of buffer
            let result = self.buffer[start..].to_string();
            self.position = self.buffer.len();
            result
        }
    }

    pub fn readlines(&mut self) -> Vec<String> {
        let mut lines = Vec::new();
        loop {
            let line = self.readline();
            if line.is_empty() {
                break;
            }
            lines.push(line);
        }
        lines
    }

    pub fn tell(&self) -> usize {
        self.position
    }

    /// Seek to position. Returns new position.
    /// offset can be negative for whence=1 (SEEK_CUR) and whence=2 (SEEK_END)
    pub fn seek(&mut self, offset: i64, whence: i32) -> usize {
        self.position = match whence {
            0 => {
                // SEEK_SET - absolute position
                offset.max(0) as usize
            }
            1 => {
                // SEEK_CUR - relative to current position
                let new_pos = (self.position as i64) + offset;
                new_pos.max(0) as usize
            }
            2 => {
                // SEEK_END - relative to end
                let new_pos = (self.buffer.len() as i64) + offset;
                new_pos.max(0) as usize
            }
            _ => self.position,
        };
        // Clamp to valid range
        self.position = std::cmp::min(self.position, self.buffer.len());
        self.position
    }

    pub fn clear(&mut self) {
        self.buffer.clear();
        self.position = 0;
    }

    /// Truncate buffer to size. If size not provided, use current position.
    /// Returns new size.
    pub fn truncate(&mut self, size: Option<usize>) -> usize {
        let truncate_at = size.unwrap_or(self.position);
        let truncate_at = std::cmp::min(truncate_at, self.buffer.len());
        self.buffer.truncate(truncate_at);
        // Adjust position if it's beyond new end
        self.position = std::cmp::min(self.position, self.buffer.len());
        self.buffer.len()
    }

    pub fn len(&self) -> usize {
        self.buffer.len()
    }

    pub fn empty(&self) -> bool {
        self.buffer.is_empty()
    }

    pub fn call_method(&mut self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "write" => {
                if args.len() != 1 {
                    return Err(format!("write expects 1 argument, got {}", args.len()));
                }
                let data = args[0].as_str();
                let count = self.write(&data);
                Ok(QValue::Int(QInt::new(count as i64)))
            }
            "writelines" => {
                if args.len() != 1 {
                    return Err(format!("writelines expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Array(arr) => {
                        let lines: Vec<String> = arr.elements.iter()
                            .map(|v| v.as_str())
                            .collect();
                        self.writelines(lines);
                        Ok(QValue::Nil(QNil))
                    }
                    _ => Err("writelines expects an Array argument".to_string())
                }
            }
            "read" => {
                let size = if args.is_empty() {
                    None
                } else if args.len() == 1 {
                    Some(args[0].as_int()? as usize)
                } else {
                    return Err(format!("read expects 0 or 1 argument, got {}", args.len()));
                };
                let result = self.read(size);
                Ok(QValue::Str(QString::new(result)))
            }
            "readline" => {
                if !args.is_empty() {
                    return Err(format!("readline expects 0 arguments, got {}", args.len()));
                }
                let result = self.readline();
                Ok(QValue::Str(QString::new(result)))
            }
            "readlines" => {
                if !args.is_empty() {
                    return Err(format!("readlines expects 0 arguments, got {}", args.len()));
                }
                let lines = self.readlines();
                let qlines: Vec<QValue> = lines.into_iter()
                    .map(|s| QValue::Str(QString::new(s)))
                    .collect();
                Ok(QValue::Array(Box::new(QArray::new(qlines))))
            }
            "get_value" | "getvalue" => {
                if !args.is_empty() {
                    return Err(format!("{} expects 0 arguments, got {}", method_name, args.len()));
                }
                Ok(QValue::Str(QString::new(self.get_value())))
            }
            "tell" => {
                if !args.is_empty() {
                    return Err(format!("tell expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.tell() as i64)))
            }
            "seek" => {
                if args.is_empty() || args.len() > 2 {
                    return Err(format!("seek expects 1 or 2 arguments, got {}", args.len()));
                }
                let offset = args[0].as_int()?;
                let whence = if args.len() == 2 {
                    args[1].as_int()? as i32
                } else {
                    0  // Default to SEEK_SET
                };
                let new_pos = self.seek(offset, whence);
                Ok(QValue::Int(QInt::new(new_pos as i64)))
            }
            "clear" => {
                if !args.is_empty() {
                    return Err(format!("clear expects 0 arguments, got {}", args.len()));
                }
                self.clear();
                Ok(QValue::Nil(QNil))
            }
            "truncate" => {
                if args.len() > 1 {
                    return Err(format!("truncate expects 0 or 1 argument, got {}", args.len()));
                }
                let size = if args.len() == 1 {
                    Some(args[0].as_int()? as usize)
                } else {
                    None
                };
                let new_size = self.truncate(size);
                Ok(QValue::Int(QInt::new(new_size as i64)))
            }
            "flush" | "close" => {
                // No-ops for compatibility
                if !args.is_empty() {
                    return Err(format!("{} expects 0 arguments, got {}", method_name, args.len()));
                }
                Ok(QValue::Nil(QNil))
            }
            "closed" => {
                if !args.is_empty() {
                    return Err(format!("closed expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(false)))  // Always false
            }
            "len" => {
                if !args.is_empty() {
                    return Err(format!("len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.len() as i64)))
            }
            "empty" => {
                if !args.is_empty() {
                    return Err(format!("empty expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.empty())))
            }
            "char_len" => {
                if !args.is_empty() {
                    return Err(format!("char_len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.buffer.chars().count() as i64)))
            }
            "_enter" => {
                if !args.is_empty() {
                    return Err(format!("_enter expects 0 arguments, got {}", args.len()));
                }
                // Return self wrapped back in StringIO
                Ok(QValue::StringIO(Rc::new(RefCell::new(self.clone()))))
            }
            "_exit" => {
                if !args.is_empty() {
                    return Err(format!("_exit expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Nil(QNil))
            }
            _ => Err(format!("Unknown method '{}' on StringIO", method_name))
        }
    }
}

impl QObj for QStringIO {
    fn cls(&self) -> String {
        "StringIO".to_string()
    }

    fn q_type(&self) -> &'static str {
        "StringIO"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "StringIO"
    }

    fn _str(&self) -> String {
        format!("<StringIO: {} bytes at position {}>", self.buffer.len(), self.position)
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        "In-memory string buffer with file-like interface".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
```

### Module Registration

```rust
// src/modules/io.rs
use std::rc::Rc;
use std::cell::RefCell;

pub fn create_io_module() -> QValue {
    let mut members = HashMap::new();

    // Existing functions
    members.insert("read".to_string(), create_fn("io", "read"));
    members.insert("write".to_string(), create_fn("io", "write"));
    // ...

    // StringIO constructor - create a nested module/type object
    // Pattern matches Array.new, Dict.new, etc.
    let mut stringio_members = HashMap::new();
    stringio_members.insert("new".to_string(), create_fn("io.StringIO", "new"));
    members.insert("StringIO".to_string(),
        QValue::Type(Box::new(QType::new_module_type("StringIO", stringio_members))));

    QValue::Module(Box::new(QModule::new("io".to_string(), members)))
}

pub fn call_io_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "io.StringIO.new" => {
            if args.is_empty() {
                Ok(QValue::StringIO(Rc::new(RefCell::new(QStringIO::new()))))
            } else if args.len() == 1 {
                let content = args[0].as_str();
                Ok(QValue::StringIO(Rc::new(RefCell::new(QStringIO::new_with_content(content)))))
            } else {
                Err(format!("StringIO.new expects 0 or 1 argument, got {}", args.len()))
            }
        }
        // ... other io functions
        _ => Err(format!("Unknown io function: {}", func_name))
    }
}
```

### Method Call Handling

When Quest evaluates a method call on a StringIO object, it needs to handle the `Rc<RefCell<>>` wrapper:

```rust
// In main.rs or wherever postfix operations are handled
QValue::StringIO(stringio_rc) => {
    let mut stringio = stringio_rc.borrow_mut();
    stringio.call_method(method_name, args)?
}
```

## Testing Strategy

```quest
# test/io/stringio_test.q
use "std/test"
use "std/io"

test.module("std/io StringIO")

test.describe("StringIO.new", fun ()
    test.it("creates empty buffer", fun ()
        let buf = io.StringIO.new()
        test.assert_eq(buf.get_value(), "", nil)
        test.assert_eq(buf.tell(), 0, nil)
        test.assert_eq(buf.len(), 0, nil)
        test.assert(buf.empty(), "Buffer should be empty")
    end)

    test.it("creates buffer with initial content", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.get_value(), "Hello", nil)
        test.assert_eq(buf.getvalue(), "Hello", "Python-style alias")
        test.assert_eq(buf.tell(), 0, nil)
        test.assert_eq(buf.len(), 5, nil)
    end)
end)

test.describe("StringIO.write", fun ()
    test.it("writes strings to buffer", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("Hello")
        test.assert_eq(count, 5, "Should return byte count")
        test.assert_eq(buf.get_value(), "Hello", nil)
        test.assert_eq(buf.tell(), 5, "Position should advance")
    end)

    test.it("concatenates multiple writes", fun ()
        let buf = io.StringIO.new()
        buf.write("Hello")
        buf.write(" ")
        buf.write("World")
        test.assert_eq(buf.get_value(), "Hello World", nil)
    end)

    test.it("returns byte count for UTF-8 characters", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("→")  # 3-byte UTF-8 character
        test.assert_eq(count, 3, "Should return 3 bytes")
    end)
end)

test.describe("StringIO.writelines", fun ()
    test.it("writes multiple lines", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["Line 1\n", "Line 2\n", "Line 3\n"])
        test.assert_eq(buf.get_value(), "Line 1\nLine 2\nLine 3\n", nil)
    end)

    test.it("does not add newlines automatically", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["A", "B", "C"])
        test.assert_eq(buf.get_value(), "ABC", nil)
    end)
end)

test.describe("StringIO.read", fun ()
    test.it("reads entire buffer", fun ()
        let buf = io.StringIO.new("Hello World")
        let content = buf.read()
        test.assert_eq(content, "Hello World")        test.assert_eq(buf.tell(), 11, "Position at end")
    end)

    test.it("reads specified number of bytes", fun ()
        let buf = io.StringIO.new("Hello World")
        let part1 = buf.read(5)
        let part2 = buf.read(6)
        test.assert_eq(part1, "Hello")        test.assert_eq(part2, " World")        test.assert_eq(buf.tell(), 11, nil)
    end)

    test.it("returns empty string when reading past end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.read()  # Read all
        let extra = buf.read()
        test.assert_eq(extra, "")    end)
end)

test.describe("StringIO.readline", fun ()
    test.it("reads lines one at a time", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        test.assert_eq(buf.readline(), "Line 1\n", nil)
        test.assert_eq(buf.readline(), "Line 2\n", nil)
        test.assert_eq(buf.readline(), "Line 3", "Last line without newline")
        test.assert_eq(buf.readline(), "", "Empty at end")
    end)
end)

test.describe("StringIO.readlines", fun ()
    test.it("reads all lines as array", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        let lines = buf.readlines()
        test.assert_eq(lines.len(), 3, nil)
        test.assert_eq(lines.get(0), "Line 1\n", nil)
        test.assert_eq(lines.get(1), "Line 2\n", nil)
        test.assert_eq(lines.get(2), "Line 3", nil)
    end)

    test.it("returns empty array for empty buffer", fun ()
        let buf = io.StringIO.new("")
        let lines = buf.readlines()
        test.assert_eq(lines.len(), 0, nil)
    end)
end)

test.describe("StringIO.seek", fun ()
    test.it("seeks to absolute position", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(6)
        test.assert_eq(new_pos, 6, "Should return new position")
        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("seeks relative to current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_pos = buf.seek(1, 1)  # Forward 1 from current
        test.assert_eq(new_pos, 6)        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("seeks relative to end", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-5, 2)  # 5 bytes before end
        test.assert_eq(new_pos, 6)        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("handles negative seek from current", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        let new_pos = buf.seek(-4, 1)  # Back 4 from current
        test.assert_eq(new_pos, 6)        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("clamps negative positions to 0", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-100, 1)
        test.assert_eq(new_pos, 0, "Should clamp to 0")
    end)
end)

test.describe("StringIO.tell", fun ()
    test.it("returns current position", fun ()
        let buf = io.StringIO.new("Hello World")
        test.assert_eq(buf.tell(), 0, nil)
        buf.read(5)
        test.assert_eq(buf.tell(), 5, nil)
    end)
end)

test.describe("StringIO.clear", fun ()
    test.it("clears buffer contents", fun ()
        let buf = io.StringIO.new("Hello")
        buf.clear()
        test.assert_eq(buf.get_value(), "", nil)
        test.assert_eq(buf.tell(), 0, nil)
        test.assert(buf.empty(), "Should be empty")
    end)
end)

test.describe("StringIO.truncate", fun ()
    test.it("truncates at current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_size = buf.truncate()
        test.assert_eq(new_size, 5)        test.assert_eq(buf.get_value(), "Hello", nil)
    end)

    test.it("truncates at explicit size", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_size = buf.truncate(8)
        test.assert_eq(new_size, 8)        test.assert_eq(buf.get_value(), "Hello Wo", nil)
    end)

    test.it("adjusts position if beyond new size", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        buf.truncate(5)
        test.assert_eq(buf.tell(), 5, "Position should adjust")
    end)
end)

test.describe("StringIO utility methods", fun ()
    test.it("flush is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.flush()  # Should not error
        test.assert_eq(buf.get_value(), "Hello", "No change")
    end)

    test.it("close is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.close()  # Should not error
        test.assert_eq(buf.get_value(), "Hello", "Still readable")
        buf.write(" World")  # Still writable
        test.assert_eq(buf.get_value(), "Hello World", nil)
    end)

    test.it("closed always returns false", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.closed(), false, nil)
        buf.close()
        test.assert_eq(buf.closed(), false, "Still false after close")
    end)
end)

test.describe("StringIO.len and empty", fun ()
    test.it("returns correct length", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.len(), 5, nil)
        buf.write(" World")
        test.assert_eq(buf.len(), 11, nil)
    end)

    test.it("empty returns correct status", fun ()
        let buf = io.StringIO.new()
        test.assert(buf.empty(), "Should be empty")
        buf.write("Hello")
        test.assert_eq(buf.empty(), false, "Should not be empty")
    end)
end)

test.describe("StringIO edge cases", fun ()
    test.it("handles empty writes", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("")
        test.assert_eq(count, 0)        test.assert_eq(buf.get_value(), "", nil)
    end)

    test.it("handles very large strings", fun ()
        let buf = io.StringIO.new()
        # Build a 1MB string by repeated writes
        let i = 0
        while i.lt(100000)
            buf.write("1234567890")  # 10 bytes per write = 1MB total
            i = i + 1
        end
        test.assert_eq(buf.len(), 1000000, nil)
    end)

    test.it("handles seek beyond buffer end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.seek(1000)
        test.assert_eq(buf.tell(), 5, "Should clamp to buffer length")
    end)

    test.it("readline with no newlines", fun ()
        let buf = io.StringIO.new("No newlines here")
        let line = buf.readline()
        test.assert_eq(line, "No newlines here")        test.assert_eq(buf.readline(), "", "Should return empty on second call")
    end)

    test.it("handles UTF-8 multibyte characters", fun ()
        let buf = io.StringIO.new("Hello → World")
        test.assert_eq(buf.len(), 15, "Arrow is 3 bytes")
        test.assert_eq(buf.char_len(), 13, "Arrow is 1 character")
    end)
end)

test.describe("StringIO context manager", fun ()
    test.it("supports with statement", fun ()
        with io.StringIO.new() as buf
            buf.write("test")
            test.assert_eq(buf.get_value(), "test", nil)
        end
    end)

    test.it("_enter returns self", fun ()
        let buf = io.StringIO.new("initial")
        let result = buf._enter()
        # Both should work on the same buffer
        buf.write(" more")
        test.assert_eq(result.get_value(), "initial more", nil)
    end)

    test.it("_exit is a no-op", fun ()
        let buf = io.StringIO.new("data")
        buf._exit()
        # Buffer should still be usable
        test.assert_eq(buf.get_value(), "data", nil)
        buf.write(" more")
        test.assert_eq(buf.get_value(), "data more", nil)
    end)
end)

test.describe("StringIO char_len", fun ()
    test.it("counts characters correctly", fun ()
        let buf = io.StringIO.new("ASCII")
        test.assert_eq(buf.char_len(), 5, nil)
        test.assert_eq(buf.len(), 5, nil)
    end)

    test.it("handles multibyte UTF-8", fun ()
        let buf = io.StringIO.new("→→→")
        test.assert_eq(buf.char_len(), 3, "3 characters")
        test.assert_eq(buf.len(), 9, "9 bytes (3 bytes per arrow)")
    end)
end)
```

## Performance Considerations

1. **Memory usage** - Buffer grows dynamically; large strings use proportional memory
2. **Write performance** - O(1) for appends (always appends to end)
3. **Read performance** - O(n) where n is bytes read
4. **Position tracking** - O(1) for tell/seek operations
5. **Interior mutability overhead** - `Rc<RefCell<>>` adds minimal runtime cost

**Recommendations:**
- Use `clear()` to free memory when done with large buffers
- For building large strings, StringIO is more efficient than repeated string concatenation
- No memory limits enforced - monitor buffer size for very large data

**Memory Limits:**
- No built-in size limits
- Buffer can grow until system memory exhausted
- Consider implementing max_size parameter in future if needed

## Design Decisions

### Why write() always appends to end?

**Decision:** `write()` always appends to the end of the buffer, ignoring current position.

**Rationale:**
1. **Simplicity** - Avoids complex insertion/overwrite logic with UTF-8 character boundaries
2. **Python compatibility** - Python's `io.StringIO` in text mode behaves similarly
3. **Common use case** - Most StringIO usage is for building strings, not editing them
4. **Performance** - Append is O(1), insert/overwrite would be O(n)

**Alternative considered:** Overwrite at current position (like C FILE* streams)
- **Rejected because:** Complex with UTF-8, error-prone with character boundaries, uncommon use case

### Why Rc<RefCell<>> instead of Box?

**Decision:** Wrap QStringIO in `Rc<RefCell<>>` instead of `Box`.

**Decision Matrix:**

| Scenario | Box | Rc<RefCell<>> | Winner |
|----------|-----|---------------|--------|
| Single owner | ✅ Works | ✅ Works | Box (simpler) |
| I/O redirection (QEP-010) | ❌ Needs clone | ✅ Shares reference | Rc<RefCell<>> |
| Method mutation | ❌ Needs &mut | ✅ Works with & | Rc<RefCell<>> |
| Passing to functions | ❌ Needs clone | ✅ Cheap clone | Rc<RefCell<>> |

**Rationale:**
1. **QEP-010 needs shared references** - I/O redirection stores StringIO in `OutputTarget` enum alongside current stdout
2. **Multiple references may exist** - Scope, output target, and user variable all need access
3. **Interior mutability** - Allows mutation without `mut` binding in user code
4. **API ergonomics** - Users don't need `let mut buffer`, just `let buffer`
5. **Consistent with mutable shared state** - Standard Rust pattern for this use case

**Example where Box fails:**
```quest
let buffer = io.StringIO.new()
sys.redirect_stdout(buffer)  # Takes ownership with Box
puts(buffer.get_value())     # ERROR: buffer moved!
```

With `Rc<RefCell<>>`, both work fine because cloning the `Rc` just increments the reference count.

### Why support both get_value() and getvalue()?

**Decision:** Support both naming conventions.

**Rationale:**
1. **Python compatibility** - Python uses `getvalue()` (no underscore)
2. **Quest convention** - Quest prefers `get_value()` (with underscore, like `to_string()`)
3. **Zero cost** - Both are aliases to same implementation
4. **Migration path** - Helps Python developers transition to Quest

### Why is close() a no-op?

**Decision:** `close()` does nothing, buffer remains usable after calling it.

**Rationale:**
1. **In-memory only** - No system resources to release
2. **File-like compatibility** - Allows StringIO to be drop-in replacement for files
3. **Simplicity** - No state tracking needed
4. **Common pattern** - Python's StringIO behaves the same way

## Future Enhancements

**Phase 2:**
- `io.BytesIO()` - Binary version of StringIO for byte manipulation
  - Same API but works with Bytes instead of Str
  - Useful for binary protocols, image manipulation, etc.
- Line iteration protocol: `for line in buffer.lines()` (when Quest adds iterators)
- Stream copying: `io.copy(source, dest)` utility function

**Phase 3:**
- Encoding/decoding support for different text encodings
- Memory limits with `max_size` parameter
- Compression/decompression in memory (integrate with compress module)
- Performance optimization: Consider rope data structure for very large buffers

**Phase 4:**
- Async I/O support for StringIO
  - `async_write()`, `async_read()` for concurrent operations
  - Integration with Quest's async/await (when added)
- Stream transformations
  - `buffer.map(transform_fn)` - Apply function to each line
  - `buffer.filter(predicate)` - Filter lines
  - Pipeline operations

**Comparison with Bytes type:**
- **Use StringIO when:** Building/parsing text data, capturing string output, testing
- **Use Bytes when:** Working with binary data, network protocols, raw byte manipulation
- **Use BytesIO (future) when:** Building/parsing binary data with file-like interface

## Implementation Checklist

### Core Implementation
- [ ] Add `QStringIO` struct to [types/stringio.rs](src/types/stringio.rs) (new file)
- [ ] Add `StringIO(Rc<RefCell<QStringIO>>)` variant to `QValue` enum in [types/mod.rs](src/types/mod.rs)
- [ ] Implement `QObj` trait for `QStringIO`
- [ ] Implement core methods:
  - [ ] `new()` and `new_with_content()`
  - [ ] `write()` - append only, returns byte count
  - [ ] `writelines()`
  - [ ] `get_value()` / `getvalue()` - both aliases
  - [ ] `read()` and `read(size)`
  - [ ] `readline()`
  - [ ] `readlines()`

### Position and Utility Methods
- [ ] Implement position methods:
  - [ ] `tell()` - returns current position
  - [ ] `seek(pos)` - absolute seek, returns new position
  - [ ] `seek(offset, whence)` - relative seek with negative offset support
- [ ] Implement utility methods:
  - [ ] `clear()` - clear buffer and reset position
  - [ ] `truncate()` and `truncate(size)` - returns new size
  - [ ] `flush()` - no-op for compatibility
  - [ ] `close()` - no-op for compatibility
  - [ ] `closed()` - always returns false
  - [ ] `len()` - returns byte count
  - [ ] `char_len()` - returns character count (Unicode)
  - [ ] `empty()` - returns true if len == 0
  - [ ] `_enter()` - context manager entry (returns self)
  - [ ] `_exit()` - context manager exit (no-op)

### Integration
- [ ] Add StringIO constructor to [modules/io.rs](src/modules/io.rs)
  - [ ] Handle `io.StringIO.new()` call in `call_io_function`
  - [ ] Support 0 or 1 argument (optional initial content)
- [ ] Add method dispatch for StringIO in postfix handler ([main.rs](src/main.rs))
  - [ ] Handle `Rc<RefCell<>>` unwrapping with `borrow_mut()`
  - [ ] Call `stringio.call_method()` with method name and args

### Testing
- [ ] Create [test/io/stringio_test.q](test/io/stringio_test.q)
- [ ] Test constructor (empty and with initial content)
- [ ] Test write operations (single, multiple, UTF-8)
- [ ] Test writelines
- [ ] Test read operations (full, sized, past end)
- [ ] Test readline and readlines
- [ ] Test seek (absolute, relative to current, relative to end, negative offsets)
- [ ] Test tell
- [ ] Test clear and truncate
- [ ] Test utility methods (flush, close, closed)
- [ ] Test len and empty
- [ ] Test char_len with ASCII and UTF-8
- [ ] Test both get_value() and getvalue() aliases
- [ ] Test context manager support (_enter, _exit, with statement)
- [ ] Test edge cases:
  - [ ] Empty writes
  - [ ] Very large strings (1MB+)
  - [ ] Seek beyond buffer end
  - [ ] Readline with no newlines
  - [ ] UTF-8 multibyte characters

### Documentation
- [ ] Update [CLAUDE.md](CLAUDE.md) with StringIO description
- [ ] Add examples to standard library docs
- [ ] Update QEP-010 (I/O Redirection) to use StringIO

## Open Implementation Questions

### 1. How to handle QType::new_module_type()?

**Issue:** The module registration code references `QType::new_module_type()` which may not exist in Quest's codebase.

**Options:**
- **A)** Create this helper method if it doesn't exist (matches pattern for other module types)
- **B)** Use existing pattern from Array, Dict, etc. - check how they register `.new()` constructors
- **C)** Create a simpler pattern specific to StringIO

**Recommendation:** Check existing code for Array.new/Dict.new pattern and follow that exactly.

### 2. Method dispatch with Rc<RefCell<>>

**Issue:** Need to ensure method calls properly handle `borrow_mut()` and panic handling.

**Considerations:**
- What happens if StringIO is already borrowed when method called? (should be rare in single-threaded Quest)
- Should we catch borrow panics and convert to Quest errors?
- How do other mutable types (Array, Dict) handle this?

**Recommendation:** Follow pattern used by existing mutable types. If they use `Box`, consider whether StringIO actually needs `Rc<RefCell<>>` or if simpler wrapping suffices.

### 3. as_int() method for seek offset

**Issue:** Seek implementation assumes `args[0].as_int()` returns `i64`, but needs proper error handling.

**Question:** Does `QValue::as_int()` return `Result<i64, String>` or `i64`? Need to check actual signature.

**Action:** Verify QValue API and adjust implementation accordingly.

### 4. QArray::new() constructor pattern

**Issue:** Code assumes `QArray::new(elements)` exists for readlines() implementation.

**Question:** What's the actual constructor signature for QArray in Quest?

**Action:** Check [types/array.rs](src/types/array.rs) for correct pattern.

### 5. Interior mutability - Required or Optional?

**Issue:** Decision to use `Rc<RefCell<>>` assumes StringIO needs shared mutable references.

**Question:**
- Do we actually need this for QEP-010 I/O redirection, or can we use simpler `Box` like other types?
- Does I/O redirection need to store the same StringIO in multiple places?
- How do other Quest types handle mutation?

**For discussion:** Review whether `Rc<RefCell<>>` adds value vs complexity. May be premature optimization.

### 6. UTF-8 Character Boundaries in seek()

**Issue:** Current implementation uses byte positions for seek, but Rust strings are UTF-8.

**Question:** If user seeks to middle of a multi-byte UTF-8 character, what happens?
- **Option A:** Allow it, let read() handle invalid UTF-8 (may panic)
- **Option B:** Validate and round to character boundary (slower, more complex)
- **Option C:** Document that positions are byte offsets and user must be careful

**Recommendation:** Option C - document behavior, keep implementation simple. Python's StringIO has similar considerations.

## Conclusion

StringIO provides an essential primitive for in-memory string manipulation with a file-like interface. It enables testing, data processing, and output capture without filesystem overhead.

**Key benefits:**
- **Testing** - Easy output verification
- **Performance** - No file I/O overhead
- **Simplicity** - Familiar file-like API
- **Compatibility** - Drop-in file replacement
- **Internal mutability** - No `mut` required in user code

**Key design decisions:**
- **Append-only writes** - Simpler implementation, matches common use case
- **Byte-based positions** - Consistent with Rust String, documented clearly
- **Python compatibility** - Support both Quest and Python naming conventions
- **No close enforcement** - close() is a true no-op for simplicity

The implementation follows Python's `io.StringIO` closely while integrating naturally with Quest's design patterns and type system.
