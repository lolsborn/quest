# io - File operations

The `io` module provides file and stream input/output operations.

## File Reading

### `io.read(path)`
Read entire file contents as a string

**Parameters:**
- `path` - File path (Str)

**Returns:** File contents (Str)

**Raises:** Error if file doesn't exist or can't be read

**Example:**
```quest
let content = io.read("data.txt")
puts(content)
```

### `io.read_lines(path)`
Read file as list of lines (with newlines stripped)

**Parameters:**
- `path` - File path (Str)

**Returns:** List of lines (List of Str)

**Example:**
```quest
let lines = io.read_lines("input.txt")
for line in lines
    puts(line)
end
```

### `io.read_bytes(path)`
Read file as raw bytes

**Parameters:**
- `path` - File path (Str)

**Returns:** Byte array (Bytes)

**Example:**
```quest
let data = io.read_bytes("image.png")
```

## File Writing

### `io.write(path, content)`
Write string to file (overwrites existing content)

**Parameters:**
- `path` - File path (Str)
- `content` - Content to write (Str)

**Returns:** Nil

**Example:**
```quest
io.write("output.txt", "Hello, World!")
```

### `io.write_lines(path, lines)`
Write list of strings to file (adds newlines)

**Parameters:**
- `path` - File path (Str)
- `lines` - List of strings (List)

**Returns:** Nil

**Example:**
```quest
let lines = ["First line", "Second line", "Third line"]
io.write_lines("output.txt", lines)
```

### `io.write_bytes(path, bytes)`
Write raw bytes to file

**Parameters:**
- `path` - File path (Str)
- `bytes` - Byte data (Bytes)

**Returns:** Nil

### `io.append(path, content)`
Append string to file (creates if doesn't exist)

**Parameters:**
- `path` - File path (Str)
- `content` - Content to append (Str)

**Returns:** Nil

**Example:**
```quest
io.append("log.txt", "New log entry\n")
```

## File Operations

### `io.exists(path)`
Check if file or directory exists

**Parameters:**
- `path` - File or directory path (Str)

**Returns:** Bool (true if exists)

**Example:**
```quest
if io.exists("config.json")
    let config = io.read("config.json")
end
```

### `io.is_file(path)`
Check if path is a file

**Parameters:**
- `path` - Path (Str)

**Returns:** Bool

### `io.is_dir(path)`
Check if path is a directory

**Parameters:**
- `path` - Path (Str)

**Returns:** Bool

### `io.size(path)`
Get file size in bytes

**Parameters:**
- `path` - File path (Str)

**Returns:** Size in bytes (Num)

**Example:**
```quest
let size = io.size("large_file.dat")
puts("File is ", size, " bytes")
```

### `io.copy(src, dst)`
Copy file from source to destination

**Parameters:**
- `src` - Source file path (Str)
- `dst` - Destination file path (Str)

**Returns:** Nil

**Example:**
```quest
io.copy("original.txt", "backup.txt")
```

### `io.move(src, dst)`
Move/rename file

**Parameters:**
- `src` - Source file path (Str)
- `dst` - Destination file path (Str)

**Returns:** Nil

### `io.remove(path)`
Delete file

**Parameters:**
- `path` - File path (Str)

**Returns:** Nil

**Example:**
```quest
if io.exists("temp.txt")
    io.remove("temp.txt")
end
```

## Directory Operations

### `io.mkdir(path)`
Create directory (fails if parent doesn't exist)

**Parameters:**
- `path` - Directory path (Str)

**Returns:** Nil

### `io.mkdir_all(path)`
Create directory and all parent directories

**Parameters:**
- `path` - Directory path (Str)

**Returns:** Nil

**Example:**
```quest
io.mkdir_all("data/outputs/2024")
```

### `io.rmdir(path)`
Remove empty directory

**Parameters:**
- `path` - Directory path (Str)

**Returns:** Nil

### `io.rmdir_all(path)`
Remove directory and all contents recursively

**Parameters:**
- `path` - Directory path (Str)

**Returns:** Nil

**Warning:** Use with caution - permanently deletes all contents

### `io.list_dir(path)`
List files and directories in path

**Parameters:**
- `path` - Directory path (Str)

**Returns:** List of names (List of Str)

**Example:**
```quest
let files = io.list_dir(".")
for file in files
    puts(file)
end
```

### `io.walk(path)`
Recursively walk directory tree

**Parameters:**
- `path` - Root directory path (Str)

**Returns:** List of all file paths (List of Str)

**Example:**
```quest
let all_files = io.walk("src")
for file in all_files
    if file.endswith(".q")
        puts(file)
    end
end
```

## File Metadata

### `io.modified_time(path)`
Get last modification time as Unix timestamp

**Parameters:**
- `path` - File path (Str)

**Returns:** Unix timestamp (Num)

### `io.created_time(path)`
Get creation time as Unix timestamp

**Parameters:**
- `path` - File path (Str)

**Returns:** Unix timestamp (Num)

### `io.accessed_time(path)`
Get last access time as Unix timestamp

**Parameters:**
- `path` - File path (Str)

**Returns:** Unix timestamp (Num)

## Path Utilities

### `io.absolute(path)`
Convert relative path to absolute path

**Parameters:**
- `path` - Relative or absolute path (Str)

**Returns:** Absolute path (Str)

**Example:**
```quest
let abs = io.absolute("../data/file.txt")
puts(abs)  # /Users/name/project/data/file.txt
```

### `io.basename(path)`
Get filename from path

**Parameters:**
- `path` - File path (Str)

**Returns:** Filename (Str)

**Example:**
```quest
io.basename("/path/to/file.txt")  # Returns "file.txt"
```

### `io.dirname(path)`
Get directory from path

**Parameters:**
- `path` - File path (Str)

**Returns:** Directory path (Str)

**Example:**
```quest
io.dirname("/path/to/file.txt")  # Returns "/path/to"
```

### `io.extension(path)`
Get file extension

**Parameters:**
- `path` - File path (Str)

**Returns:** Extension including dot (Str) or empty string

**Example:**
```quest
io.extension("file.txt")  # Returns ".txt"
io.extension("archive.tar.gz")  # Returns ".gz"
```

### `io.join(parts...)`
Join path components with appropriate separator

**Parameters:**
- `parts...` - Path components (Str)

**Returns:** Joined path (Str)

**Example:**
```quest
let path = io.join("data", "outputs", "results.csv")
# Returns "data/outputs/results.csv" on Unix
# Returns "data\outputs\results.csv" on Windows
```

## Glob/Pattern Matching

### `io.glob(pattern)`
Find all files matching a glob pattern

**Parameters:**
- `pattern` - Glob pattern (Str)
  - `*` matches any characters except `/`
  - `**` matches any characters including `/` (recursive)
  - `?` matches single character
  - `[abc]` matches one character from set
  - `[!abc]` matches one character not in set

**Returns:** List of matching file paths (List of Str)

**Example:**
```quest
# Find all .q files in current directory
let quest_files = io.glob("*.q")

# Find all .txt files recursively
let all_text = io.glob("**/*.txt")

# Find all test files
let tests = io.glob("test_*.q")

# Multiple patterns
let sources = io.glob("src/**/*.{q,md}")
```

### `io.glob_match(path, pattern)`
Check if a path matches a glob pattern

**Parameters:**
- `path` - File path to test (Str)
- `pattern` - Glob pattern (Str)

**Returns:** Bool (true if matches)

**Example:**
```quest
if io.glob_match("test_utils.q", "test_*.q")
    puts("This is a test file")
end
```

## StringIO - In-Memory String Buffers

StringIO provides an in-memory string buffer with a file-like interface. It's useful for testing, building strings efficiently, and capturing output without creating temporary files.

### `io.StringIO.new()`
Create empty in-memory string buffer

**Returns:** StringIO object

**Example:**
```quest
let buf = io.StringIO.new()
buf.write("Hello")
buf.write(" World")
puts(buf.get_value())  # "Hello World"
```

### `io.StringIO.new(initial)`
Create StringIO with initial content

**Parameters:**
- `initial` - Initial buffer content (Str)

**Returns:** StringIO object

**Example:**
```quest
let buf = io.StringIO.new("Initial text")
buf.write(" more text")
puts(buf.get_value())  # "Initial text more text"
```

### StringIO Methods

#### Writing Methods

**`write(data)` → Int**
Write string to buffer (always appends to end). Returns number of bytes written.

```quest
let buf = io.StringIO.new()
let count = buf.write("Hello")  # Returns 5
```

**`writelines(lines)` → Nil**
Write array of strings to buffer (does not add newlines automatically).

```quest
let buf = io.StringIO.new()
buf.writelines(["Line 1\n", "Line 2\n"])
```

#### Reading Methods

**`get_value()` → Str** / **`getvalue()` → Str**
Get entire buffer contents (regardless of current position). Both spellings supported for Python compatibility.

```quest
let buf = io.StringIO.new("Hello World")
puts(buf.get_value())  # "Hello World"
```

**`read()` → Str**
Read from current position to end of buffer.

```quest
let buf = io.StringIO.new("Hello World")
buf.seek(6)
puts(buf.read())  # "World"
```

**`read(size)` → Str**
Read up to `size` characters from current position.

```quest
let buf = io.StringIO.new("Hello World")
puts(buf.read(5))  # "Hello"
```

**`readline()` → Str**
Read one line (up to and including newline).

```quest
let buf = io.StringIO.new("Line 1\nLine 2\n")
puts(buf.readline())  # "Line 1\n"
puts(buf.readline())  # "Line 2\n"
```

**`readlines()` → Array[Str]**
Read all lines from current position as array.

```quest
let buf = io.StringIO.new("A\nB\nC")
let lines = buf.readlines()  # ["A\n", "B\n", "C"]
```

#### Position Methods

**`tell()` → Int**
Get current position in buffer (0-based byte offset).

**`seek(pos)` → Int**
Seek to absolute position. Returns new position.

```quest
let buf = io.StringIO.new("Hello World")
buf.seek(6)
puts(buf.read())  # "World"
```

**`seek(offset, whence)` → Int**
Seek relative to reference point. Returns new position.

**Whence values:**
- `0` - SEEK_SET: Seek from beginning
- `1` - SEEK_CUR: Seek from current position
- `2` - SEEK_END: Seek from end

```quest
let buf = io.StringIO.new("Hello World")
buf.seek(-5, 2)   # 5 bytes before end
puts(buf.read())  # "World"
```

#### Utility Methods

**`clear()` → Nil**
Clear buffer contents and reset position to 0.

**`truncate()` → Int** / **`truncate(size)` → Int**
Truncate buffer to size (defaults to current position). Returns new size.

```quest
let buf = io.StringIO.new("Hello World")
buf.seek(5)
buf.truncate()  # Truncate at position 5
puts(buf.get_value())  # "Hello"
```

**`len()` → Int**
Get buffer length in bytes.

**`char_len()` → Int**
Get buffer length in Unicode characters (useful for UTF-8).

```quest
let buf = io.StringIO.new("Hello → World")
puts(buf.len())       # 15 (bytes)
puts(buf.char_len())  # 13 (characters)
```

**`empty()` → Bool**
Check if buffer is empty.

**`flush()` → Nil**
No-op (included for file compatibility).

**`close()` → Nil**
No-op (included for file compatibility).

**`closed()` → Bool**
Always returns false (StringIO never closes).

#### Context Manager Support

StringIO supports the `with` statement for automatic cleanup:

```quest
with io.StringIO.new() as buf
    buf.write("Line 1\n")
    buf.write("Line 2\n")
    puts(buf.get_value())
end
```

### StringIO Examples

**Example 1: Building strings efficiently**
```quest
use "std/io"

fun build_report(items)
    let buf = io.StringIO.new()

    buf.write("Report\n")
    buf.write("======\n\n")

    for item in items
        buf.write("- ")
        buf.write(item.name)
        buf.write(": ")
        buf.write(item.value.to_string())
        buf.write("\n")
    end

    buf.get_value()
end
```

**Example 2: Parsing line-by-line**
```quest
let data = io.StringIO.new("Name: Alice\nAge: 30\nCity: NYC")
let user = {}

while true
    let line = data.readline()
    if line == ""
        break
    end

    let parts = line.trim().split(":")
    user[parts[0]] = parts[1].trim()
end
```

**Example 3: Testing output**
```quest
use "std/test"

test.it("generates correct output", fun ()
    let buf = io.StringIO.new()

    # Capture output by writing to buffer
    buf.write("Header\n")
    buf.write("Data\n")

    let result = buf.get_value()
    test.assert(result.contains("Header"), nil)
    test.assert(result.contains("Data"), nil)
end)
```

**When to use StringIO vs string concatenation:**
- **Use StringIO** for: Building strings in loops (>10 iterations), line-by-line processing, capturing output, testing
- **Use string concat (`..`)** for: Simple 2-3 concatenations, inline string construction

## Stream/Handle Operations

### `io.open(path, mode = "r")`
Open file and return file handle

**Parameters:**
- `path` - File path (Str)
- `mode` - Open mode (Str): "r" (read), "w" (write), "a" (append), "r+" (read/write)

**Returns:** File handle (File)

**Example:**
```quest
let f = io.open("data.txt", "r")
let content = f.read()
f.close()
```

### File Handle Methods

#### `file.read()`
Read entire file contents

**Returns:** File contents (Str)

#### `file.read_line()`
Read single line (returns nil at EOF)

**Returns:** Line string or Nil

#### `file.write(content)`
Write string to file

**Parameters:**
- `content` - String to write (Str)

#### `file.flush()`
Flush write buffer to disk

#### `file.close()`
Close file handle

#### `file.seek(position)`
Seek to position in file

**Parameters:**
- `position` - Byte offset (Num)

#### `file.tell()`
Get current position in file

**Returns:** Byte offset (Num)

### `io.with_file(path, mode, fn)`
Open file, execute function, automatically close

**Parameters:**
- `path` - File path (Str)
- `mode` - Open mode (Str)
- `fn` - Function to execute with file handle

**Returns:** Result of function

**Example:**
```quest
io.with_file("output.txt", "w", fun(f)
    f.write("Line 1\n")
    f.write("Line 2\n")
end)
```

## Standard Streams

### `io.stdin`
Standard input stream (File handle)

### `io.stdout`
Standard output stream (File handle)

### `io.stderr`
Standard error stream (File handle)

**Example:**
```quest
io.stderr.write("Error: something went wrong\n")
```

### `io.read_line()`
Read line from standard input

**Returns:** Input line (Str)

**Example:**
```quest
print("Enter your name: ")
let name = io.read_line()
puts("Hello, ", name, "!")
```

## Temporary Files

### `io.temp_file(prefix = "quest")`
Create temporary file

**Parameters:**
- `prefix` - Filename prefix (Str)

**Returns:** File handle to temp file (File)

### `io.temp_dir(prefix = "quest")`
Create temporary directory

**Parameters:**
- `prefix` - Directory name prefix (Str)

**Returns:** Path to temp directory (Str)

## Common Patterns

### Reading and Processing Lines
```quest
let lines = io.read_lines("input.txt")
let results = []

for line in lines
    if !line.startswith("#")  # Skip comments
        results.append(line.trim())
    end
end

io.write_lines("output.txt", results)
```

### Safe File Writing
```quest
io.with_file("config.json", "w", fun(f)
    f.write("{")
    f.write("  \"version\": 1,")
    f.write("  \"enabled\": true")
    f.write("}")
end)
```

### Directory Traversal
```quest
let quest_files = []
for file in io.walk("src")
    if io.extension(file) == ".q"
        quest_files.append(file)
    end
end
puts("Found ", quest_files.len(), " Quest files")
```

### File Size Check
```quest
if io.exists("large_file.dat") and io.size("large_file.dat") > 1000000
    puts("Warning: File is larger than 1MB")
end
```
