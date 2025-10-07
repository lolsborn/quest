# QEP-023: I/O Context Managers

**Status**: Proposed
**Created**: 2025-10-05
**Author**: Quest Team
**Related**: QEP-011 (with Statement), QEP-013 (File Objects), QEP-010 (I/O Redirection)

## Summary

Replace Quest's function-based I/O operations with File objects that implement the `_enter()` and `_exit()` context manager protocol. All file operations will require `io.open()` with `with` statements for proper resource management.

**Breaking Change**: This removes `io.read()`, `io.write()`, and `io.append()` convenience functions in favor of explicit resource management.

## Motivation

Currently, Quest's `io` module provides simple function-based operations:

```quest
use "std/io" as io

# Current approach - convenience functions
let content = io.read("file.txt")
io.write("file.txt", "data")
```

This is convenient for simple cases but lacks:

1. **Resource management** - No explicit file handles to close
2. **Streaming** - Must read entire file into memory
3. **Reusability** - Can't reuse file handles for multiple operations
4. **Safety** - No automatic cleanup on errors

**Problem scenario:**

```quest
# Needs manual try/ensure pattern
let file = some_object_that_needs_closing()
try
    # work with file
    file.write("data")
ensure
    file.close()  # Must remember this!
end
```

**Desired solution:**

```quest
# Automatic cleanup with 'with' statement
with io.open("file.txt", "w") as f
    f.write("data")
end  # Automatically closed!
```

## Goals

1. **Replace convenience functions** with explicit `io.open()` that returns File objects
2. **Require context managers** for all file operations (enforces resource safety)
3. **Implement `_enter()` and `_exit()`** on File objects for automatic cleanup
4. **Enable streaming** - Read/write large files in chunks
5. **Enforce best practices** - All file operations must properly manage resources

## Proposed API

### File Context Manager

```quest
use "std/io" as io

# Opens file and returns File object
with io.open("data.txt", "r") as f
    let content = f.read()
    puts(content)
end  # Automatically calls f.close()

# Multiple operations on same file
with io.open("log.txt", "a") as f
    f.write("Event 1\n")
    f.write("Event 2\n")
    f.flush()  # Ensure written to disk
end  # Auto-closes

# Read file line-by-line (streaming)
with io.open("large.log", "r") as f
    while true
        let line = f.readline()
        if line == ""
            break
        end
        process_line(line)
    end
end  # Auto-closes
```

### File Modes

```quest
io.open(path, mode)
```

**Text modes:**
- `"r"` - Read text (default)
- `"w"` - Write text (truncate)
- `"a"` - Append text
- `"r+"` - Read/write text
- `"w+"` - Read/write text (truncate)
- `"a+"` - Read/append text

**Binary modes:**
- `"rb"` - Read binary
- `"wb"` - Write binary
- `"ab"` - Append binary
- `"rb+"` - Read/write binary
- `"wb+"` - Read/write binary (truncate)
- `"ab+"` - Read/append binary

### File Object Methods

**Reading:**
```quest
f.read()           # Read entire file → Str
f.read(size)       # Read N bytes → Str
f.readline()       # Read one line → Str
f.readlines()      # Read all lines → Array[Str]
```

**Writing:**
```quest
f.write(data)      # Write string → Int (bytes written)
f.writelines(arr)  # Write array of strings → Nil
```

**Position:**
```quest
f.tell()           # Get current position → Int
f.seek(pos)        # Seek to absolute position → Int
f.seek(off, whence) # Seek relative (whence: 0=start, 1=current, 2=end) → Int
```

**Resource Management:**
```quest
f.close()          # Close file → Nil
f.closed()         # Check if closed → Bool
f.flush()          # Flush write buffer → Nil
```

**Introspection:**
```quest
f.name()           # Get file path → Str
f.mode()           # Get file mode → Str
f.len()            # Get file size → Int
```

**Context Manager Protocol:**
```quest
f._enter()         # Called by 'with' - returns self
f._exit()          # Called by 'with' - closes file
```

## Context Manager Protocol

File objects implement the context manager protocol from QEP-011:

```quest
type File
    # ... fields ...

    # Context manager entry
    fun _enter()
        self  # Return self for 'as' binding
    end

    # Context manager exit - guaranteed cleanup
    fun _exit()
        if not self.closed()
            self.close()
        end
        nil
    end
end
```

**Behavior:**
- `_enter()` is called when entering `with` block
- `_exit()` is **always** called when leaving block, even on exception
- File is automatically closed in `_exit()`

## Complete Examples

### Example 1: Read File

```quest
use "std/io" as io

# Read entire file
with io.open("config.json", "r") as f
    let content = f.read()
    puts(content)
end
```

### Example 2: Write File

```quest
use "std/io" as io

# Write to file
with io.open("output.txt", "w") as f
    f.write("Hello ")
    f.write("World\n")
    f.write("Line 2\n")
end
```

### Example 3: Append to Log

```quest
use "std/io" as io
use "std/time"

fun log_event(message)
    with io.open("app.log", "a") as f
        let timestamp = time.now_local().format("%Y-%m-%d %H:%M:%S")
        f.write(f"[{timestamp}] {message}\n")
        f.flush()  # Ensure written immediately
    end
end

log_event("Application started")
log_event("Processing data")
log_event("Application stopped")
```

### Example 4: Process Large File (Streaming)

```quest
use "std/io" as io

fun count_lines(filename)
    let count = 0
    with io.open(filename, "r") as f
        while true
            let line = f.readline()
            if line == ""
                break
            end
            count = count + 1
        end
    end
    count
end

puts(f"Lines: {count_lines('large.log')}")
```

### Example 5: Copy File in Chunks

```quest
use "std/io" as io

fun copy_file(src, dst)
    with io.open(src, "rb") as input
        with io.open(dst, "wb") as output
            let total = 0
            while true
                let chunk = input.read(8192)  # 8KB chunks
                if chunk == ""
                    break
                end
                output.write(chunk)
                total = total + chunk.len()
            end
            puts(f"Copied {total} bytes")
        end
    end
end

copy_file("large.dat", "backup.dat")
```

### Example 6: Exception Safety

```quest
use "std/io" as io

try
    with io.open("output.txt", "w") as f
        f.write("Line 1\n")
        raise "Error occurred"
        f.write("Never written")
    end  # File still closed despite exception!
catch e
    puts(f"Error: {e.message()}")
end
```

### Example 7: Read CSV Line-by-Line

```quest
use "std/io" as io

fun parse_csv(filename)
    let rows = []
    with io.open(filename, "r") as f
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
    end
    rows
end

let users = parse_csv("users.csv")
for user in users
    puts(f"{user.name} ({user.age}) from {user.city}")
end
```

### Example 8: Write Binary File

```quest
use "std/io" as io

fun write_header(filename)
    with io.open(filename, "wb") as f
        # Write magic bytes
        f.write(b"\x89PNG\r\n\x1a\n")
        # Write size
        f.write(b"\x00\x00\x01\x00")
    end
end

write_header("image.png")
```

## Integration with Existing Features

### With I/O Redirection (QEP-010)

File objects work seamlessly with I/O redirection:

```quest
use "std/sys"
use "std/io" as io

with io.open("output.log", "w") as f
    with sys.redirect_stream(sys.stdout, f)
        puts("This goes to file")
        puts("So does this")
    end  # stdout restored
end  # file closed
```

### With StringIO (QEP-009)

File and StringIO share the same interface:

```quest
use "std/io" as io

fun process_stream(stream)
    while true
        let line = stream.readline()
        if line == ""
            break
        end
        puts(line.trim())
    end
end

# Works with File
with io.open("data.txt", "r") as f
    process_stream(f)
end

# Works with StringIO
let buffer = io.StringIO.new("Line 1\nLine 2\n")
process_stream(buffer)
```

### With Exception Handling

```quest
use "std/io" as io

try
    with io.open("data.txt", "r") as f
        let content = f.read()
        process(content)
    end
catch IOError as e
    puts(f"File error: {e.message()}")
catch ParseError as e
    puts(f"Parse error: {e.message()}")
end
```

## Breaking Changes

**Removed functions:**
- `io.read(path)` - Use `io.open(path, "r")` with `f.read()`
- `io.write(path, content)` - Use `io.open(path, "w")` with `f.write()`
- `io.append(path, content)` - Use `io.open(path, "a")` with `f.write()`

**Rationale:**
1. **Enforces resource safety** - Can't forget to close files
2. **Encourages best practices** - Explicit is better than implicit
3. **Prevents resource leaks** - All files automatically closed
4. **Consistent API** - One way to do file I/O
5. **Better error handling** - Exceptions always trigger cleanup

**Philosophy:**
Quest prioritizes correctness over convenience. While one-line functions are convenient, they hide resource management complexity and make it easy to leak file handles or leave files unclosed. Requiring explicit `with` statements ensures every file operation is properly managed.

## Implementation

### Type Definition

```rust
// src/types/file.rs

use std::fs::File as StdFile;
use std::io::{Read, Write, Seek, SeekFrom, BufReader, BufWriter};

pub struct QFile {
    pub path: String,
    pub mode: String,
    pub handle: FileHandle,
    pub id: u64,
}

pub enum FileHandle {
    Reader(BufReader<StdFile>),
    Writer(BufWriter<StdFile>),
    ReadWriter(StdFile),
    Closed,
}

impl QFile {
    pub fn open(path: &str, mode: &str) -> Result<Self, String> {
        // Open file based on mode
        // Return QFile instance
    }

    // Reading methods
    pub fn read(&mut self, size: Option<usize>) -> Result<String, String> { }
    pub fn readline(&mut self) -> Result<String, String> { }
    pub fn readlines(&mut self) -> Result<Vec<String>, String> { }

    // Writing methods
    pub fn write(&mut self, data: &str) -> Result<usize, String> { }
    pub fn writelines(&mut self, lines: Vec<String>) -> Result<(), String> { }

    // Position methods
    pub fn tell(&mut self) -> Result<u64, String> { }
    pub fn seek(&mut self, pos: i64, whence: i32) -> Result<u64, String> { }

    // Resource management
    pub fn close(&mut self) -> Result<(), String> { }
    pub fn closed(&self) -> bool { }
    pub fn flush(&mut self) -> Result<(), String> { }

    // Context manager protocol
    pub fn enter(&self) -> QValue {
        QValue::File(Box::new(self.clone()))
    }

    pub fn exit(&mut self) -> Result<QValue, String> {
        if !self.closed() {
            self.close()?;
        }
        Ok(QValue::Nil(QNil))
    }
}
```

### Module Registration

```rust
// src/modules/io.rs

pub fn call_io_function(
    func_name: &str,
    args: Vec<QValue>,
    _scope: &mut Scope
) -> Result<QValue, String> {
    match func_name {
        "io.open" => {
            if args.len() < 1 || args.len() > 2 {
                return Err(format!(
                    "io.open expects 1-2 arguments (path, mode?), got {}",
                    args.len()
                ));
            }

            let path = args[0].as_str();
            let mode = if args.len() == 2 {
                args[1].as_str()
            } else {
                "r".to_string()
            };

            let file = QFile::open(&path, &mode)?;
            Ok(QValue::File(Box::new(file)))
        }

        // Other io functions: glob, exists, remove, copy, move, etc.
        // (Path operations remain, only file I/O functions removed)
        _ => Err(format!("Unknown io function: {}", func_name))
    }
}
```

### Method Dispatch

```rust
// In QFile::call_method

impl QFile {
    pub fn call_method(
        &mut self,
        method_name: &str,
        args: Vec<QValue>
    ) -> Result<QValue, String> {
        match method_name {
            "read" => { /* ... */ }
            "readline" => { /* ... */ }
            "readlines" => { /* ... */ }
            "write" => { /* ... */ }
            "writelines" => { /* ... */ }
            "close" => {
                self.close()?;
                Ok(QValue::Nil(QNil))
            }
            "closed" => {
                Ok(QValue::Bool(QBool::new(self.closed())))
            }
            "flush" => {
                self.flush()?;
                Ok(QValue::Nil(QNil))
            }
            "tell" => { /* ... */ }
            "seek" => { /* ... */ }
            "name" => {
                Ok(QValue::Str(QString::new(self.path.clone())))
            }
            "mode" => {
                Ok(QValue::Str(QString::new(self.mode.clone())))
            }
            "len" => { /* ... */ }

            // Context manager protocol
            "_enter" => Ok(self.enter()),
            "_exit" => self.exit(),

            _ => Err(format!("File has no method '{}'", method_name))
        }
    }
}
```

## Error Handling

```quest
use "std/io" as io

# File not found
try
    with io.open("nonexistent.txt", "r") as f
        let content = f.read()
    end
catch IOError as e
    puts(f"Error: {e.message()}")
end

# Permission denied
try
    with io.open("/root/secret.txt", "w") as f
        f.write("data")
    end
catch IOError as e
    puts(f"Permission error: {e.message()}")
end

# Operations on closed file
let f = io.open("test.txt", "w")
f.close()
try
    f.write("data")
catch IOError as e
    puts("Cannot write to closed file")
end
```

## Testing Strategy

```quest
# test/io/file_context_manager_test.q

use "std/test"
use "std/io" as io

test.module("I/O Context Managers")

test.describe("io.open()", fun ()
    test.it("returns File object", fun ()
        let f = io.open("/tmp/test.txt", "w")
        test.assert_eq(f.cls(), "File", nil)
        f.close()
        io.remove("/tmp/test.txt")
    end)

    test.it("defaults to read mode", fun ()
        io.write("/tmp/test.txt", "data")
        let f = io.open("/tmp/test.txt")
        test.assert_eq(f.mode(), "r", nil)
        f.close()
        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File context manager", fun ()
    test.it("automatically closes file", fun ()
        let f = nil
        with io.open("/tmp/test.txt", "w") as file
            f = file
            test.assert_eq(f.closed(), false, "Should be open in block")
        end
        test.assert_eq(f.closed(), true, "Should be closed after block")
        io.remove("/tmp/test.txt")
    end)

    test.it("closes on exception", fun ()
        let f = nil
        try
            with io.open("/tmp/test.txt", "w") as file
                f = file
                raise "Error"
            end
        catch e
            # Ignore
        end
        test.assert_eq(f.closed(), true, "Should be closed despite exception")
        io.remove("/tmp/test.txt")
    end)
end)

test.describe("File methods", fun ()
    test.it("reads entire file", fun ()
        io.write("/tmp/test.txt", "Hello World")
        with io.open("/tmp/test.txt", "r") as f
            let content = f.read()
            test.assert_eq(content, "Hello World")        end
        io.remove("/tmp/test.txt")
    end)

    test.it("writes to file", fun ()
        with io.open("/tmp/test.txt", "w") as f
            f.write("Hello ")
            f.write("World")
        end
        let content = io.read("/tmp/test.txt")
        test.assert_eq(content, "Hello World")        io.remove("/tmp/test.txt")
    end)

    test.it("reads line by line", fun ()
        io.write("/tmp/test.txt", "Line 1\nLine 2\nLine 3")
        with io.open("/tmp/test.txt", "r") as f
            test.assert_eq(f.readline(), "Line 1\n", nil)
            test.assert_eq(f.readline(), "Line 2\n", nil)
            test.assert_eq(f.readline(), "Line 3", nil)
            test.assert_eq(f.readline(), "", "EOF")
        end
        io.remove("/tmp/test.txt")
    end)
end)

test.describe("Removed functions", fun ()
    test.it("io.read is removed", fun ()
        test.assert_raises(fun ()
            io.read("/tmp/test.txt")
        end, "Unknown io function")
    end)

    test.it("io.write is removed", fun ()
        test.assert_raises(fun ()
            io.write("/tmp/test.txt", "data")
        end, "Unknown io function")
    end)

    test.it("io.append is removed", fun ()
        test.assert_raises(fun ()
            io.append("/tmp/test.txt", "data")
        end, "Unknown io function")
    end)
end)
```

## Performance Considerations

**Context managers with `io.open()`:**
- Minimal overhead: ~1-2μs for context manager protocol
- Efficient for both single and multiple operations
- Memory efficient: stream large files in chunks
- No performance penalty vs manual management

**Benefits:**
- Reuse file handles for multiple operations
- Stream large files without loading into memory
- Automatic cleanup has negligible cost
- Compile-time guarantee of proper resource management

## Migration Guide

### Breaking Changes

All code using `io.read()`, `io.write()`, or `io.append()` must be updated.

### Step 1: Update Simple Read

```quest
# Before
let content = io.read("file.txt")

# After
with io.open("file.txt", "r") as f
    let content = f.read()
end
```

### Step 2: Update Simple Write

```quest
# Before
io.write("output.txt", "Hello World")

# After
with io.open("output.txt", "w") as f
    f.write("Hello World")
end
```

### Step 3: Update Append

```quest
# Before
io.append("log.txt", "New entry\n")

# After
with io.open("log.txt", "a") as f
    f.write("New entry\n")
end
```

### Step 4: Convert Multiple Operations

```quest
# Before (multiple open/close)
io.write("log.txt", "Line 1\n")
io.append("log.txt", "Line 2\n")
io.append("log.txt", "Line 3\n")

# After (single open/close)
with io.open("log.txt", "w") as f
    f.write("Line 1\n")
    f.write("Line 2\n")
    f.write("Line 3\n")
end
```

### Step 5: Enable Streaming for Large Files

```quest
# Before (loads entire file into memory)
let content = io.read("huge.log")
for line in content.split("\n")
    process(line)
end

# After (streams line by line - memory efficient)
with io.open("huge.log", "r") as f
    while true
        let line = f.readline()
        if line == ""
            break
        end
        process(line)
    end
end
```

### Automated Migration Script

Create a migration script to help update existing code:

```bash
# Replace io.read() patterns
sed -i 's/let \(.*\) = io\.read("\(.*\)")/with io.open("\2", "r") as __f\n    let \1 = __f.read()\nend/g' *.q

# Replace io.write() patterns
sed -i 's/io\.write("\(.*\)", \(.*\))/with io.open("\1", "w") as __f\n    __f.write(\2)\nend/g' *.q

# Replace io.append() patterns
sed -i 's/io\.append("\(.*\)", \(.*\))/with io.open("\1", "a") as __f\n    __f.write(\2)\nend/g' *.q
```

**Note**: These are starting points - manual review required for correctness.

## Documentation Updates

### CLAUDE.md

Add to the I/O section:

```markdown
**File Context Managers** (QEP-023):
- `io.open(path, mode)` - Returns File object with context manager protocol
- Use with `with` statement for automatic cleanup
- Modes: "r", "w", "a", "rb", "wb", "ab", "r+", "w+", "a+"
- Methods: read, readline, write, close, flush, seek, tell
- Implements `_enter()` and `_exit()` for automatic cleanup
```

### stdlib/io.md

Add comprehensive documentation with examples showing:
- Basic usage with `with` statement
- All file modes
- All file methods
- Comparison with convenience functions
- When to use each approach

## Implementation Checklist

### Core Implementation
- [ ] Create `src/types/file.rs` with `QFile` struct
- [ ] Add `File` variant to `QValue` enum
- [ ] Implement `QFile::open()` with all modes
- [ ] Implement reading methods: `read()`, `readline()`, `readlines()`
- [ ] Implement writing methods: `write()`, `writelines()`
- [ ] Implement position methods: `tell()`, `seek()`
- [ ] Implement resource methods: `close()`, `closed()`, `flush()`
- [ ] Implement introspection: `name()`, `mode()`, `len()`
- [ ] Implement context manager protocol: `_enter()`, `_exit()`
- [ ] Add `io.open()` function to io module
- [ ] Update `call_method_on_value()` helper to support File

### Testing
- [ ] Test `io.open()` with all modes
- [ ] Test file reading methods
- [ ] Test file writing methods
- [ ] Test position methods
- [ ] Test resource management
- [ ] Test context manager protocol (`_enter`, `_exit`)
- [ ] Test automatic cleanup with `with` statement
- [ ] Test exception safety
- [ ] Test backwards compatibility with convenience functions
- [ ] Test nested file context managers
- [ ] Test integration with I/O redirection

### Documentation
- [ ] Update `CLAUDE.md` with File context manager info
- [ ] Write comprehensive `docs/docs/stdlib/io.md` documentation
- [ ] Add examples to documentation
- [ ] Write migration guide
- [ ] Document performance characteristics
- [ ] Document when to use convenience vs context managers

## Future Enhancements

### Phase 2: Advanced Features
- [ ] File iteration: `for line in f.lines()`
- [ ] Memory-mapped files
- [ ] File locking
- [ ] Temporary files: `io.TemporaryFile()`
- [ ] Named pipes support

### Phase 3: Async I/O
- [ ] Async file operations
- [ ] Non-blocking I/O
- [ ] Event-driven file watching

## Related Work

- **Python**: `open()` returns file object with `__enter__`/`__exit__`
- **Rust**: `File` with manual `Drop` trait
- **Ruby**: `File.open` with block auto-closes
- **Go**: `defer file.Close()` pattern

Quest's approach combines Python's ergonomic `with` statement with Rust's explicit resource management philosophy.

## Conclusion

QEP-023 brings automatic resource management to Quest's I/O system through context managers. By implementing `_enter()` and `_exit()` on File objects and removing convenience functions, we enforce safe, explicit file handling that integrates seamlessly with Quest's `with` statement (QEP-011).

**Key benefits:**
- ✅ Automatic cleanup with `with` statement
- ✅ Exception-safe resource management (enforced by API)
- ✅ Streaming support for large files
- ✅ Prevents resource leaks by design
- ✅ Explicit resource management (no hidden file handles)

**Breaking change rationale:**
Removing `io.read()`, `io.write()`, and `io.append()` forces explicit resource management. While this adds verbosity for simple cases, it:
- Prevents resource leaks
- Makes file lifetimes explicit
- Encourages best practices from day one
- Eliminates an entire class of bugs

**Migration:**
- All file operations must use `io.open()` with `with` statements
- Path operations (`io.glob()`, `io.exists()`, `io.remove()`) remain unchanged
- Update existing code using migration patterns above

This completes Quest's resource management story, building on QEP-011's `with` statement foundation to provide Python-like ergonomics with Quest's emphasis on correctness and safety over convenience.
