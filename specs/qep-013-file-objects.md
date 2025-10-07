# QEP-011: File Objects and Context Management

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** QEP-010 (I/O Redirection), QEP-009 (StringIO)

## Abstract

This QEP proposes adding File objects to Quest's I/O system. File objects provide:

1. **Object-oriented file handles** - Files as first-class objects with methods
2. **Explicit resource management** - Manual `open()` and `close()` control
3. **Context manager protocol** - Automatic cleanup with `with` blocks (Phase 2)
4. **Streaming operations** - Read/write in chunks, line-by-line iteration
5. **Unified interface** - Same API as StringIO for consistency

## Current State

Quest currently provides functional file I/O:

```quest
use "std/io"

# All operations are one-shot functions
io.write("file.txt", "content")
let content = io.read("file.txt")
io.append("file.txt", "more")
io.remove("file.txt")
```

**Limitations:**
- No file handle reuse (each operation opens/closes)
- No streaming (must read entire file)
- No explicit resource management
- No automatic cleanup on errors
- Cannot pass files to functions expecting file-like objects

## Rationale

File objects are essential for:

1. **Performance** - Reuse file handles instead of open/close per operation
2. **Streaming** - Read/write large files in chunks without loading into memory
3. **Resource safety** - Ensure files are closed, even on exceptions
4. **Compatibility** - Drop-in replacement for StringIO in I/O redirection
5. **Line iteration** - Process files line-by-line efficiently

**Use cases:**

```quest
use "std/io"

# Read large file line-by-line (memory efficient)
let f = io.open("large.log", "r")
try
    while true
        let line = f.readline()
        if line == ""
            break
        end
        process_line(line)
    end
ensure
    f.close()
end

# Write incrementally
let f = io.open("output.txt", "w")
try
    for item in data
        f.write(item.to_string() .. "\n")
    end
ensure
    f.close()
end

# Phase 2: Automatic cleanup with 'with'
with io.open("file.txt", "r") as f
    let content = f.read()
end  # Automatic f.close()
```

## Design Philosophy

**Principle 1: Python File API**
- Similar to Python's `open()`, `read()`, `write()`, `close()`
- Familiar modes: `"r"`, `"w"`, `"a"`, `"rb"`, `"wb"`
- Compatible with StringIO interface

**Principle 2: Context Manager Protocol**
- Implement `_enter()` and `_exit()` methods
- Automatic cleanup with `with` blocks (Phase 2)
- Manual cleanup with `try/ensure` (Phase 1)

**Principle 3: Explicit is Better**
- `io.open()` returns File object (explicit resource)
- `io.read()` / `io.write()` remain as convenience functions
- Clear separation: convenience vs control

**Principle 4: Streaming Support**
- Read/write in chunks
- Line-by-line iteration
- Memory efficient for large files

## API Design - Phase 1 (Manual Resource Management)

### Opening Files

#### `io.open(path: Str, mode: Str) → File`

Open file and return File object.

**Parameters:**
- `path` (Str) - File path
- `mode` (Str) - File mode:
  - `"r"` - Read text (default)
  - `"w"` - Write text (truncate)
  - `"a"` - Append text
  - `"rb"` - Read binary
  - `"wb"` - Write binary
  - `"ab"` - Append binary
  - `"r+"` - Read/write text
  - `"w+"` - Read/write text (truncate)
  - `"a+"` - Read/append text

**Returns:** File object

**Example:**
```quest
use "std/io"

let f = io.open("file.txt", "r")
try
    let content = f.read()
    puts(content)
ensure
    f.close()
end
```

### File Object Methods

#### Reading Methods

**`read() → Str`**
Read entire file contents.

```quest
let f = io.open("file.txt", "r")
let content = f.read()
f.close()
```

**`read(size: Int) → Str`**
Read up to `size` bytes.

```quest
let f = io.open("file.txt", "r")
let chunk = f.read(1024)  # Read 1KB
f.close()
```

**`readline() → Str`**
Read one line (including newline).

```quest
let f = io.open("file.txt", "r")
let line1 = f.readline()  # "First line\n"
let line2 = f.readline()  # "Second line\n"
f.close()
```

**`readlines() → Array[Str]`**
Read all lines into array.

```quest
let f = io.open("file.txt", "r")
let lines = f.readlines()  # ["line 1\n", "line 2\n", ...]
f.close()
```

#### Writing Methods

**`write(data: Str) → Int`**
Write string to file, returns bytes written.

```quest
let f = io.open("file.txt", "w")
f.write("Hello ")
f.write("World\n")
f.close()
```

**`writelines(lines: Array[Str]) → Nil`**
Write multiple lines (does not add newlines).

```quest
let f = io.open("file.txt", "w")
f.writelines(["Line 1\n", "Line 2\n"])
f.close()
```

#### Resource Management

**`close() → Nil`**
Close file and release resources.

```quest
let f = io.open("file.txt", "r")
# ... use file ...
f.close()
```

**`closed() → Bool`**
Check if file is closed.

```quest
let f = io.open("file.txt", "r")
puts(f.closed())  # false
f.close()
puts(f.closed())  # true
```

**`flush() → Nil`**
Flush write buffer to disk.

```quest
let f = io.open("file.txt", "w")
f.write("Important data")
f.flush()  # Ensure written to disk
f.close()
```

#### Position Methods

**`tell() → Int`**
Get current position in file.

```quest
let f = io.open("file.txt", "r")
f.read(10)
puts(f.tell())  # 10
f.close()
```

**`seek(pos: Int) → Int`**
Seek to absolute position.

```quest
let f = io.open("file.txt", "r")
f.seek(100)
let content = f.read()  # Read from position 100
f.close()
```

**`seek(offset: Int, whence: Int) → Int`**
Seek relative to whence (0=start, 1=current, 2=end).

```quest
let f = io.open("file.txt", "r")
f.seek(-100, 2)  # Seek to 100 bytes before end
let tail = f.read()
f.close()
```

#### Introspection

**`name() → Str`**
Get file path.

```quest
let f = io.open("/tmp/file.txt", "r")
puts(f.name())  # "/tmp/file.txt"
f.close()
```

**`mode() → Str`**
Get file mode.

```quest
let f = io.open("file.txt", "w")
puts(f.mode())  # "w"
f.close()
```

**`len() → Int`**
Get file size in bytes.

```quest
let f = io.open("file.txt", "r")
puts(f.len())  # File size
f.close()
```

### Context Manager Protocol

#### `_enter() → File`

Called when entering `with` block (Phase 2).

**Returns:** self

#### `_exit() → Nil`

Called when exiting `with` block (Phase 2). Automatically closes file.

**Returns:** nil

## Complete Examples - Phase 1

### Example 1: Read File Line-by-Line

```quest
use "std/io"

fun count_lines(filename)
    let f = io.open(filename, "r")
    let count = 0

    try
        while true
            let line = f.readline()
            if line == ""
                break
            end
            count = count + 1
        end
    ensure
        f.close()
    end

    count
end

puts("Lines: " .. count_lines("app.log"))
```

### Example 2: Write Large File Incrementally

```quest
use "std/io"

fun write_csv(filename, rows)
    let f = io.open(filename, "w")

    try
        # Write header
        f.write("name,age,city\n")

        # Write rows incrementally (memory efficient)
        for row in rows
            let line = row.name .. "," .. row.age .. "," .. row.city .. "\n"
            f.write(line)
        end

        f.flush()  # Ensure written to disk
    ensure
        f.close()
    end
end
```

### Example 3: Read File in Chunks

```quest
use "std/io"
use "std/hash"

fun hash_file(filename)
    let f = io.open(filename, "rb")
    let hasher = hash.sha256_new()  # Streaming hasher (future)

    try
        while true
            let chunk = f.read(4096)  # Read 4KB at a time
            if chunk == ""
                break
            end
            hasher.update(chunk)
        end
    ensure
        f.close()
    end

    hasher.finalize()
end
```

### Example 4: Append to Log File

```quest
use "std/io"
use "std/time"

fun log_event(message)
    let f = io.open("app.log", "a")

    try
        let timestamp = time.now_local().format("%Y-%m-%d %H:%M:%S")
        f.write("[" .. timestamp .. "] " .. message .. "\n")
        f.flush()
    ensure
        f.close()
    end
end

log_event("Application started")
log_event("Processing data")
log_event("Application shutdown")
```

### Example 5: Copy File with Progress

```quest
use "std/io"

fun copy_file(src, dst)
    let input = io.open(src, "rb")
    let output = io.open(dst, "wb")

    try
        let total = 0
        while true
            let chunk = input.read(8192)
            if chunk == ""
                break
            end

            output.write(chunk)
            total = total + chunk.len()

            if total % 1048576 == 0  # Every MB
                puts("Copied " .. (total / 1048576) .. " MB")
            end
        end

        puts("Total: " .. total .. " bytes")
    ensure
        input.close()
        output.close()
    end
end
```

### Example 6: Parse CSV File

```quest
use "std/io"

fun read_csv(filename)
    let f = io.open(filename, "r")
    let rows = []

    try
        # Skip header
        f.readline()

        while true
            let line = f.readline()
            if line == ""
                break
            end

            let fields = line.trim().split(",")
            rows.push({
                "name": fields.get(0),
                "age": fields.get(1).to_int(),
                "city": fields.get(2)
            })
        end
    ensure
        f.close()
    end

    rows
end

let users = read_csv("users.csv")
for user in users
    puts(user.name .. " is " .. user.age)
end
```

### Example 7: Redirect to File Object

```quest
use "std/sys"
use "std/io"

# Redirect stdout to file object (requires QEP-010)
let f = io.open("output.log", "w")
let guard = sys.redirect_stdout(f)

try
    puts("This goes to file")
    puts("So does this")
ensure
    guard.restore()
    f.close()
end
```

## API Design - Phase 2 (with Blocks)

### Automatic Resource Management

```quest
use "std/io"

# File automatically closed at end of block
with io.open("file.txt", "r") as f
    let content = f.read()
    puts(content)
end  # f.close() called automatically

# Even on exceptions
with io.open("file.txt", "w") as f
    f.write("Data")
    raise "Error"
    f.write("Never written")
end  # f.close() still called!
```

### Multiple Files

```quest
use "std/io"

with io.open("input.txt", "r") as input
    with io.open("output.txt", "w") as output
        for line in input.readlines()
            output.write(line.upper())
        end
    end
end  # Both files closed automatically
```

### Combined with I/O Redirection

```quest
use "std/sys"
use "std/io"

with io.open("output.log", "w") as f
    with sys.redirect_stdout(f)
        puts("Logged to file")
    end  # stdout restored
end  # file closed
```

## Implementation Notes

### File Type

```rust
// src/types/file.rs

use std::fs::File as StdFile;
use std::io::{Read, Write, Seek, SeekFrom, BufReader, BufWriter};

#[derive(Debug)]
pub struct QFile {
    pub path: String,
    pub mode: String,
    pub handle: FileHandle,
    pub id: u64,
}

pub enum FileHandle {
    Reader(BufReader<StdFile>),
    Writer(BufWriter<StdFile>),
    ReadWriter(StdFile),  // For "r+", "w+", "a+"
    Closed,
}

impl QFile {
    pub fn open(path: &str, mode: &str) -> Result<Self, String> {
        let file = match mode {
            "r" | "rb" => {
                StdFile::open(path)
                    .map_err(|e| format!("Failed to open '{}': {}", path, e))?
            }
            "w" | "wb" => {
                StdFile::create(path)
                    .map_err(|e| format!("Failed to create '{}': {}", path, e))?
            }
            "a" | "ab" => {
                StdFile::options()
                    .append(true)
                    .create(true)
                    .open(path)
                    .map_err(|e| format!("Failed to open '{}' for append: {}", path, e))?
            }
            "r+" | "w+" | "a+" => {
                // Read/write modes
                unimplemented!("Read/write modes not yet implemented")
            }
            _ => return Err(format!("Invalid file mode: '{}'. Use 'r', 'w', 'a', 'rb', 'wb', or 'ab'", mode))
        };

        let handle = if mode.starts_with('r') {
            FileHandle::Reader(BufReader::new(file))
        } else {
            FileHandle::Writer(BufWriter::new(file))
        };

        Ok(Self {
            path: path.to_string(),
            mode: mode.to_string(),
            handle,
            id: next_object_id(),
        })
    }

    pub fn read(&mut self, size: Option<usize>) -> Result<String, String> {
        match &mut self.handle {
            FileHandle::Reader(reader) => {
                let mut buffer = match size {
                    Some(n) => vec![0u8; n],
                    None => Vec::new(),
                };

                if let Some(n) = size {
                    reader.read_exact(&mut buffer)
                        .map_err(|e| format!("Read error: {}", e))?;
                } else {
                    reader.read_to_end(&mut buffer)
                        .map_err(|e| format!("Read error: {}", e))?;
                }

                String::from_utf8(buffer)
                    .map_err(|e| format!("Invalid UTF-8: {}", e))
            }
            FileHandle::Closed => Err("Cannot read from closed file".to_string()),
            _ => Err("File not opened for reading".to_string())
        }
    }

    pub fn readline(&mut self) -> Result<String, String> {
        match &mut self.handle {
            FileHandle::Reader(reader) => {
                let mut line = String::new();
                use std::io::BufRead;
                reader.read_line(&mut line)
                    .map_err(|e| format!("Read error: {}", e))?;
                Ok(line)
            }
            FileHandle::Closed => Err("Cannot read from closed file".to_string()),
            _ => Err("File not opened for reading".to_string())
        }
    }

    pub fn write(&mut self, data: &str) -> Result<usize, String> {
        match &mut self.handle {
            FileHandle::Writer(writer) => {
                writer.write_all(data.as_bytes())
                    .map_err(|e| format!("Write error: {}", e))?;
                Ok(data.len())
            }
            FileHandle::Closed => Err("Cannot write to closed file".to_string()),
            _ => Err("File not opened for writing".to_string())
        }
    }

    pub fn close(&mut self) -> Result<(), String> {
        if let FileHandle::Writer(writer) = &mut self.handle {
            writer.flush()
                .map_err(|e| format!("Flush error: {}", e))?;
        }
        self.handle = FileHandle::Closed;
        Ok(())
    }

    pub fn closed(&self) -> bool {
        matches!(self.handle, FileHandle::Closed)
    }

    pub fn call_method(&mut self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "read" => { /* ... */ }
            "readline" => { /* ... */ }
            "readlines" => { /* ... */ }
            "write" => { /* ... */ }
            "writelines" => { /* ... */ }
            "close" => {
                if !args.is_empty() {
                    return Err(format!("close() takes no arguments, got {}", args.len()));
                }
                self.close()?;
                Ok(QValue::Nil(QNil))
            }
            "closed" => {
                if !args.is_empty() {
                    return Err(format!("closed() takes no arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.closed())))
            }
            "flush" => { /* ... */ }
            "tell" => { /* ... */ }
            "seek" => { /* ... */ }
            "name" => {
                if !args.is_empty() {
                    return Err(format!("name() takes no arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.path.clone())))
            }
            "mode" => {
                if !args.is_empty() {
                    return Err(format!("mode() takes no arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.mode.clone())))
            }
            "_enter" => {
                // Phase 2: Context manager entry
                Ok(QValue::File(Box::new(self.clone())))
            }
            "_exit" => {
                // Phase 2: Context manager exit
                self.close()?;
                Ok(QValue::Nil(QNil))
            }
            _ => Err(format!("File has no method '{}'", method_name))
        }
    }
}

impl QObj for QFile {
    fn cls(&self) -> String {
        "File".to_string()
    }

    fn q_type(&self) -> &'static str {
        "File"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "File"
    }

    fn _str(&self) -> String {
        let status = if self.closed() { "closed" } else { "open" };
        format!("<File '{}' mode='{}' ({})>", self.path, self.mode, status)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("File object for '{}'", self.path)
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
```

### Module Registration

```rust
// src/modules/io.rs

pub fn call_io_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "io.open" => {
            if args.len() < 1 || args.len() > 2 {
                return Err(format!("io.open() expects 1 or 2 arguments (path, mode?), got {}", args.len()));
            }

            let path = args[0].as_str();
            let mode = if args.len() == 2 {
                args[1].as_str()
            } else {
                "r".to_string()  // Default to read mode
            };

            let file = QFile::open(&path, &mode)?;
            Ok(QValue::File(Box::new(file)))
        }

        // Keep existing convenience functions
        "io.read" => {
            // Convenience: io.read(path) opens, reads, closes automatically
            if args.len() != 1 {
                return Err(format!("io.read() expects 1 argument, got {}", args.len()));
            }

            let path = args[0].as_str();
            let mut file = QFile::open(&path, "r")?;
            let content = file.read(None)?;
            file.close()?;
            Ok(QValue::Str(QString::new(content)))
        }

        "io.write" => {
            // Convenience: io.write(path, content) opens, writes, closes
            if args.len() != 2 {
                return Err(format!("io.write() expects 2 arguments, got {}", args.len()));
            }

            let path = args[0].as_str();
            let content = args[1].as_str();

            let mut file = QFile::open(&path, "w")?;
            file.write(&content)?;
            file.close()?;
            Ok(QValue::Nil(QNil))
        }

        // ... other io functions
        _ => Err(format!("Unknown io function: {}", func_name))
    }
}
```

## Testing Strategy

```quest
# test/io/file_test.q
use "std/test"
use "std/io"

test.module("std/io File Objects")

test.describe("io.open", fun ()
    test.it("opens file for reading", fun ()
        io.write("/tmp/test.txt", "Hello World")

        let f = io.open("/tmp/test.txt", "r")
        test.assert_eq(f.closed(), false, nil)
        test.assert_eq(f.mode(), "r", nil)
        test.assert_eq(f.name(), "/tmp/test.txt", nil)
        f.close()

        io.remove("/tmp/test.txt")
    end)

    test.it("defaults to read mode", fun ()
        io.write("/tmp/test.txt", "content")

        let f = io.open("/tmp/test.txt")
        test.assert_eq(f.mode(), "r", nil)
        f.close()

        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File.read", fun ()
    test.it("reads entire file", fun ()
        io.write("/tmp/test.txt", "Hello World")

        let f = io.open("/tmp/test.txt", "r")
        let content = f.read()
        test.assert_eq(content, "Hello World")        f.close()

        io.remove("/tmp/test.txt")
    end)

    test.it("reads in chunks", fun ()
        io.write("/tmp/test.txt", "Hello World")

        let f = io.open("/tmp/test.txt", "r")
        let part1 = f.read(5)
        let part2 = f.read(6)
        test.assert_eq(part1, "Hello")        test.assert_eq(part2, " World")        f.close()

        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File.readline", fun ()
    test.it("reads lines", fun ()
        io.write("/tmp/test.txt", "Line 1\nLine 2\nLine 3")

        let f = io.open("/tmp/test.txt", "r")
        test.assert_eq(f.readline(), "Line 1\n", nil)
        test.assert_eq(f.readline(), "Line 2\n", nil)
        test.assert_eq(f.readline(), "Line 3", nil)
        test.assert_eq(f.readline(), "", "Empty at EOF")
        f.close()

        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File.write", fun ()
    test.it("writes to file", fun ()
        let f = io.open("/tmp/test.txt", "w")
        f.write("Hello ")
        f.write("World")
        f.close()

        let content = io.read("/tmp/test.txt")
        test.assert_eq(content, "Hello World")
        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File.close", fun ()
    test.it("closes file", fun ()
        let f = io.open("/tmp/test.txt", "w")
        test.assert_eq(f.closed(), false, nil)
        f.close()
        test.assert_eq(f.closed(), true, nil)

        io.remove("/tmp/test.txt")
    end)

    test.it("prevents operations after close", fun ()
        let f = io.open("/tmp/test.txt", "w")
        f.close()

        test.assert_raises("closed file", fun () f.write("data") end, nil)

        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File resource safety", fun ()
    test.it("closes in ensure block", fun ()
        let f = io.open("/tmp/test.txt", "w")

        try
            f.write("Before error")
            raise "Test error"
        catch e
            # Error occurred
        ensure
            f.close()  # Always closes
        end

        test.assert(f.closed(), "File should be closed")

        io.remove("/tmp/test.txt")
    end)
end)
```

## Backwards Compatibility

**Existing code continues to work:**

```quest
# Old style (convenience functions)
io.write("file.txt", "content")
let content = io.read("file.txt")
io.append("file.txt", "more")
```

**New style (file objects):**

```quest
# When you need control
let f = io.open("file.txt", "w")
try
    f.write("content")
ensure
    f.close()
end
```

**Both coexist** - use convenience functions for simple cases, file objects for complex cases.

## Binary vs Text Modes

**Text modes** (`"r"`, `"w"`, `"a"`):
- Returns `Str` from `read()`
- Accepts `Str` for `write()`
- UTF-8 encoding/decoding automatic
- Line ending normalization (platform-specific)

**Binary modes** (`"rb"`, `"wb"`, `"ab"`):
- Returns `Bytes` from `read()`
- Accepts `Bytes` or `Str` for `write()`
- No encoding/decoding
- Raw byte access

```quest
# Text mode
let f = io.open("file.txt", "r")
let text = f.read()  # Returns Str
f.close()

# Binary mode
let f = io.open("file.bin", "rb")
let data = f.read()  # Returns Bytes
f.close()
```

## Performance Considerations

**File objects vs convenience functions:**

| Operation | Convenience (`io.read()`) | File Object | Use When |
|-----------|--------------------------|-------------|----------|
| Single read | Fast (one open/close) | Same | Simple cases |
| Multiple operations | Slow (open/close each time) | Fast (reuse handle) | Complex operations |
| Large files | Memory intensive (loads all) | Memory efficient (streaming) | Large files |
| Resource cleanup | Automatic | Manual (try/ensure) | Safety matters |

**Recommendations:**
- Use `io.read()` / `io.write()` for simple one-shot operations
- Use `io.open()` for multiple operations, streaming, or resource control
- Always use `try/ensure` pattern with file objects
- Use `with` blocks (Phase 2) for automatic cleanup

## Error Handling

```quest
# File not found
try
    let f = io.open("/nonexistent.txt", "r")
catch e
    puts("Error: " .. e.message())  # "Failed to open '/nonexistent.txt': No such file or directory"
end

# Permission denied
try
    let f = io.open("/root/secret.txt", "w")
catch e
    puts("Error: " .. e.message())  # "Failed to create '/root/secret.txt': Permission denied"
end

# Write to closed file
let f = io.open("/tmp/test.txt", "w")
f.close()
try
    f.write("data")
catch e
    puts("Error: " .. e.message())  # "Cannot write to closed file"
end
```

## Integration with Existing Systems

### I/O Redirection (QEP-010)

File objects work seamlessly with I/O redirection:

```quest
use "std/sys"
use "std/io"

let f = io.open("output.log", "w")
let guard = sys.redirect_stdout(f)

try
    puts("Goes to file")
ensure
    guard.restore()
    f.close()
end
```

### StringIO (QEP-009)

File and StringIO share the same interface:

```quest
fun process_stream(stream)
    while true
        let line = stream.readline()
        if line == ""
            break
        end
        process_line(line)
    end
end

# Works with File
let f = io.open("data.txt", "r")
process_stream(f)
f.close()

# Works with StringIO
let buffer = io.StringIO.new("Line 1\nLine 2\n")
process_stream(buffer)
```

## Future Enhancements

**Phase 2: with Blocks**
- Automatic file closure
- `with io.open("file.txt", "r") as f`
- Cleaner syntax

**Phase 3: Advanced Features**
- File iteration: `for line in f.lines()`
- Async I/O support
- Memory-mapped files
- File locking
- Temporary files: `io.TemporaryFile()`

## Implementation Checklist

### Phase 1: Basic File Objects
- [ ] Create `src/types/file.rs`
- [ ] Add `QFile` struct with FileHandle enum
- [ ] Add `File` variant to `QValue` enum
- [ ] Implement `QFile::open()` with mode support
- [ ] Implement reading methods: `read()`, `readline()`, `readlines()`
- [ ] Implement writing methods: `write()`, `writelines()`
- [ ] Implement resource methods: `close()`, `closed()`, `flush()`
- [ ] Implement position methods: `tell()`, `seek()`
- [ ] Implement introspection: `name()`, `mode()`, `len()`
- [ ] Add `io.open()` function to io module
- [ ] Keep existing `io.read()`, `io.write()` convenience functions
- [ ] Write comprehensive test suite
- [ ] Add documentation

### Phase 2: Context Managers
- [ ] Implement `_enter()` method on File
- [ ] Implement `_exit()` method on File
- [ ] Add `with` statement support in parser
- [ ] Test automatic cleanup
- [ ] Update documentation with `with` examples

## Conclusion

File objects bring explicit resource management and streaming capabilities to Quest's I/O system. By implementing the context manager protocol (`_enter()`, `_exit()`), they integrate seamlessly with future `with` statement support while remaining usable with manual `try/ensure` patterns today.

**Key benefits:**
- **Performance** - Reuse file handles, stream large files
- **Safety** - Explicit resource management with try/ensure
- **Compatibility** - Same interface as StringIO
- **Flexibility** - Choose convenience functions or file objects as needed

**Migration path:**
- Phase 1: Manual resource management with `try/ensure`
- Phase 2: Automatic cleanup with `with` blocks
- Backwards compatible: existing `io.read()` / `io.write()` continue working

The design balances simplicity (convenience functions remain) with power (file objects for complex cases), following Python's successful model.
