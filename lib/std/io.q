"""
File and stream input/output operations.

This module provides functions for reading, writing, and manipulating files
and directories, as well as pattern matching with glob patterns.

**Example:**
```quest
use "std/io" as io

let content = io.read("data.txt")
io.write("output.txt", "Hello, World!")

let files = io.glob("*.q")
for file in files
  puts(file)
end
```
"""

# =============================================================================
# File Reading
# =============================================================================

#  read(path)
"""
## Read entire file contents as a string.

**Parameters:**
- `path` (**Str**) - File path (absolute or relative)

**Returns:** **Str** - File contents decoded as UTF-8

**Raises:**
- `IOError` - File doesn't exist or can't be read
- `UnicodeError` - File contains invalid UTF-8

**Example:**
```quest
let content = io.read("data.txt")
puts(content)
```
"""

# =============================================================================
# File Writing
# =============================================================================

#  write(path, content)
"""
## Write string to `file.`

  **Parameters:**
      * `path` (**Str**) - File path
      * `content` (**Str**) - String to write (will be UTF-8 encoded)

  **Returns:** **Nil**

  **Raises:**
  - `IOError` - Can't write to file (permissions, etc.)

  **Example:**
  ```
  io.write("output.txt", "Hello, World!")
  ```

**Warning:** This **OVERWRITES** existing files. Use `io.append()` to add to files.
"""

#  append(path, content)
"""
## Append string to file (creates if doesn't exist).

**Parameters:**
- `path` (**Str**) - File path
- `content` (**Str**) - Content to append

**Returns:** **Nil**

**Example:**
```quest
io.append("log.txt", "New log entry\n")
```
"""

# =============================================================================
# Path Operations
# =============================================================================

#  exists(path)
"""
## Check if file or directory exists.

**Parameters:**
- `path` (**Str**) - File or directory path

**Returns:** **Bool** - `true` if exists, `false` otherwise

**Example:**
```quest
if io.exists("config.json")
  let config = io.read("config.json")
end
```
"""

#  is_file(path)
"""
## Check if path is a file (not a directory).

**Parameters:**
- `path` (**Str**) - Path to check

**Returns:** **Bool** - `true` if path is a file

**Example:**
```quest
if io.is_file("data.txt")
  puts("It's a file")
end
```
"""

#  is_dir(path)
"""
## Check if path is a directory.

**Parameters:**
- `path` (**Str**) - Path to check

**Returns:** **Bool** - `true` if path is a directory

**Example:**
```quest
if io.is_dir("src")
  puts("It's a directory")
end
```
"""

# =============================================================================
# File Metadata
# =============================================================================

#  size(path)
"""
## Get file size in bytes.

**Parameters:**
- `path` (**Str**) - File path

**Returns:** **Num** - Size in bytes

**Raises:**
- `IOError` - File doesn't exist or can't be accessed

**Example:**
```quest
let size = io.size("large_file.dat")
puts("File is " .. size._str() .. " bytes")
```
"""

# =============================================================================
# File Operations
# =============================================================================

#  copy(src, dst)
"""
## Copy file from source to destination.

**Parameters:**
- `src` (**Str**) - Source file path
- `dst` (**Str**) - Destination file path

**Returns:** **Nil**

**Raises:**
- `IOError` - Source doesn't exist or destination can't be written

**Example:**
```quest
io.copy("original.txt", "backup.txt")
```
"""

#  move(src, dst)
"""
## Move/rename file.

**Parameters:**
- `src` (**Str**) - Source file path
- `dst` (**Str**) - Destination file path

**Returns:** **Nil**

**Raises:**
- `IOError` - Source doesn't exist or destination can't be written

**Example:**
```quest
io.move("temp.txt", "data.txt")
```
"""

#  remove(path)
"""
## Delete file or directory (including all contents if directory).

**Parameters:**
- `path` (**Str**) - File or directory path

**Returns:** **Nil**

**Raises:**
- `IOError` - Path doesn't exist or can't be deleted

**Example:**
```quest
if io.exists("temp.txt")
  io.remove("temp.txt")
end
```

**Warning:** This **permanently deletes** files. Be careful with directory removal.
"""

# =============================================================================
# Glob/Pattern Matching
# =============================================================================

#  glob(pattern)
"""
## Find all files matching a glob pattern.

**Parameters:**
- `pattern` (**Str**) - Glob pattern with wildcards:
  - `*` - Matches any characters except `/`
  - `**` - Matches any characters including `/` (recursive)
  - `?` - Matches single character
  - `[abc]` - Matches one character from set
  - `[!abc]` - Matches one character not in set

**Returns:** **Array[Str]** - List of matching file paths

**Example:**
```quest
# Find all .q files in current directory
let quest_files = io.glob("*.q")

# Find all .txt files recursively
let all_text = io.glob("**/*.txt")

# Find test files
let tests = io.glob("test_*.q")
```

**Common Patterns:**
- `"*.q"` - All `.q` files in current directory
- `"src/**/*.rs"` - All `.rs` files in `src/` (recursive)
- `"test_*.q"` - Files starting with `test_`
- `"data/[0-9]*.csv"` - CSV files starting with digit in `data/`
"""

#  glob_match(path, pattern)
"""
## Check if a path matches a glob pattern.

**Parameters:**
- `path` (**Str**) - File path to test
- `pattern` (**Str**) - Glob pattern (same syntax as `glob()`)

**Returns:** **Bool** - `true` if path matches pattern

**Example:**
```quest
if io.glob_match("test_utils.q", "test_*.q")
  puts("This is a test file")
end
```
"""

# =============================================================================
# StringIO - In-Memory String Buffers (QEP-009)
# =============================================================================

%type StringIO
"""
## In-memory string buffer with file-like interface.

StringIO provides file-like operations on strings stored in memory.
Useful for testing, output capture, and efficient string building.

**Constructor:**
```quest
let buf = io.StringIO.new()           # Empty buffer
let buf2 = io.StringIO.new("Initial") # With initial content
```

**Writing:**
```quest
buf.write("Hello")        # Appends to buffer, returns byte count
buf.writelines(["A\n", "B\n"])  # Write multiple lines
```

**Reading:**
```quest
buf.get_value()           # Get all content (or getvalue() Python-style)
buf.read()                # Read from position to end
buf.read(10)              # Read 10 bytes
buf.readline()            # Read one line
buf.readlines()           # Read all lines as array
```

**Position:**
```quest
buf.tell()                # Get current position
buf.seek(10)              # Seek to absolute position
buf.seek(-5, 2)           # Seek relative (whence: 0=start, 1=current, 2=end)
```

**Utilities:**
```quest
buf.len()                 # Buffer size in bytes
buf.char_len()            # Buffer size in characters (UTF-8 aware)
buf.empty()               # Check if empty
buf.clear()               # Clear all content
buf.truncate(5)           # Truncate to size
```

**Context Manager:**
```quest
with io.StringIO.new() as buf
    buf.write("Hello")
    puts(buf.get_value())
end
```

**Design Notes:**
- write() always appends to end (ignores position)
- Uses Rc<RefCell<>> for interior mutability
- close() and flush() are no-ops (for file-like compatibility)
- Positions are byte offsets (not character offsets)
"""

#  StringIO.new()
#  StringIO.new(initial)
"""
Create in-memory string buffer.

**Parameters:**
- `initial` (**Str**, optional) - Initial buffer content

**Returns:** **StringIO** - New StringIO object

**Example:**
```quest
let buf = io.StringIO.new()
let buf2 = io.StringIO.new("Initial text")
```
"""

#  StringIO.write(data)
"""
Write string to buffer (appends to end).

**Parameters:**
- `data` (**Str**) - String to write

**Returns:** **Int** - Number of bytes written

**Note:** Returns byte count, not character count.
For UTF-8 multibyte chars, byte count may be higher.

**Example:**
```quest
let buf = io.StringIO.new()
let count = buf.write("Hello")  # 5 bytes
buf.write(" World")
puts(buf.get_value())  # "Hello World"
```
"""

#  StringIO.writelines(lines)
"""
Write multiple lines to buffer.

**Parameters:**
- `lines` (**Array[Str]**) - Array of strings to write

**Returns:** **Nil**

**Note:** Does not add newlines automatically.

**Example:**
```quest
let buf = io.StringIO.new()
buf.writelines(["Line 1\n", "Line 2\n"])
```
"""

#  StringIO.get_value()
#  StringIO.getvalue()
"""
Get entire buffer contents (regardless of position).

**Returns:** **Str** - Complete buffer contents

**Note:** Both get_value() (Quest style) and getvalue() (Python style) are supported.

**Example:**
```quest
let buf = io.StringIO.new()
buf.write("Hello")
puts(buf.get_value())   # "Hello"
puts(buf.getvalue())    # "Hello" (Python alias)
```
"""

#  StringIO.read()
#  StringIO.read(size)
"""
Read from current position.

**Parameters:**
- `size` (**Int**, optional) - Maximum bytes to read (reads all if omitted)

**Returns:** **Str** - String from position to end (or up to size bytes)

**Example:**
```quest
let buf = io.StringIO.new("Hello World")
puts(buf.read(5))   # "Hello"
puts(buf.read())    # " World"
```
"""

#  StringIO.readline()
"""
Read one line from buffer.

**Returns:** **Str** - Line including newline, or rest of buffer, or empty string at EOF

**Example:**
```quest
let buf = io.StringIO.new("Line 1\nLine 2\n")
puts(buf.readline())  # "Line 1\n"
puts(buf.readline())  # "Line 2\n"
puts(buf.readline())  # ""
```
"""

#  StringIO.readlines()
"""
Read all lines from current position.

**Returns:** **Array[Str]** - Array of lines (including newlines)

**Example:**
```quest
let buf = io.StringIO.new("A\nB\nC")
let lines = buf.readlines()  # ["A\n", "B\n", "C"]
```
"""

#  StringIO.tell()
"""
Get current position in buffer.

**Returns:** **Int** - Current byte offset (0-based)

**Example:**
```quest
let buf = io.StringIO.new("Hello")
buf.read(3)
puts(buf.tell())  # 3
```
"""

#  StringIO.seek(pos)
#  StringIO.seek(offset, whence)
"""
Seek to position in buffer.

**Parameters:**
- `pos` (**Int**) - Absolute position (byte offset)
- OR
- `offset` (**Int**) - Offset from whence (can be negative)
- `whence` (**Int**) - Reference point:
    - 0 - Beginning (SEEK_SET)
    - 1 - Current position (SEEK_CUR)
    - 2 - End (SEEK_END)

**Returns:** **Int** - New position

**Example:**
```quest
let buf = io.StringIO.new("Hello World")
buf.seek(6)        # Absolute: position 6
buf.seek(-5, 2)    # Relative: 5 bytes before end
buf.seek(1, 1)     # Relative: 1 byte forward from current
```
"""

#  StringIO.clear()
"""
Clear buffer contents and reset position to 0.

**Returns:** **Nil**

**Example:**
```quest
let buf = io.StringIO.new("Hello")
buf.clear()
puts(buf.empty())  # true
```
"""

#  StringIO.truncate()
#  StringIO.truncate(size)
"""
Truncate buffer to size.

**Parameters:**
- `size` (**Int**, optional) - Size to truncate to (default: current position)

**Returns:** **Int** - New buffer size

**Example:**
```quest
let buf = io.StringIO.new("Hello World")
buf.seek(5)
buf.truncate()          # Truncate at position
puts(buf.get_value())   # "Hello"
```
"""

#  StringIO.len()
"""
Get buffer length in bytes.

**Returns:** **Int** - Buffer size in bytes

**Example:**
```quest
let buf = io.StringIO.new("Hello")
puts(buf.len())  # 5
```
"""

#  StringIO.char_len()
"""
Get buffer length in Unicode characters.

**Returns:** **Int** - Buffer size in characters

**Note:** For UTF-8, character count may differ from byte count.

**Example:**
```quest
let buf = io.StringIO.new("→→→")
puts(buf.len())       # 9 (bytes)
puts(buf.char_len())  # 3 (characters)
```
"""

#  StringIO.empty()
"""
Check if buffer is empty.

**Returns:** **Bool** - true if buffer length is 0

**Example:**
```quest
let buf = io.StringIO.new()
puts(buf.empty())  # true
```
"""

#  StringIO.flush()
"""
Flush buffer (no-op for StringIO).

Included for file-like compatibility. Does nothing.

**Returns:** **Nil**
"""

#  StringIO.close()
"""
Close buffer (no-op for StringIO).

Included for file-like compatibility. Buffer remains usable after close().

**Returns:** **Nil**
"""

#  StringIO.closed()
"""
Check if buffer is closed.

**Returns:** **Bool** - Always false for StringIO

**Note:** close() is a no-op, so this always returns false.
"""

# =============================================================================
# StringIO Examples
# =============================================================================

"""
## StringIO Usage Examples

### Example 1: Building Strings Efficiently

For loops with many iterations, StringIO is much faster than concatenation:

```quest
# SLOW: O(n²) - repeated string allocations
let result = ""
for i in 0..10000
    result = result .. "Item " .. i .. "\n"
end

# FAST: O(n) - single buffer
let buf = io.StringIO.new()
for i in 0..10000
    buf.write("Item ")
    buf.write(i.to_string())
    buf.write("\n")
end
let result = buf.get_value()
```

### Example 2: Capture Output

With QEP-010 I/O redirection:

```quest
use "std/sys"
use "std/io"

let buf = io.StringIO.new()
let guard = sys.redirect_stdout(buf)

try
    puts("This goes to buffer")
    puts("So does this")
ensure
    guard.restore()
end

puts("Captured: " .. buf.get_value())
```

### Example 3: Parse CSV Data

```quest
use "std/io"

fun parse_csv(csv_string)
    let buf = io.StringIO.new(csv_string)
    let rows = []

    # Skip header
    buf.readline()

    while true
        let line = buf.readline()
        if line == ""
            break
        end
        rows.push(line.trim().split(","))
    end

    rows
end

let data = "Name,Age\nAlice,30\nBob,25\n"
let rows = parse_csv(data)
```

### Example 4: Context Manager

```quest
use "std/io"

with io.StringIO.new() as buf
    buf.write("Line 1\n")
    buf.write("Line 2\n")
    let content = buf.get_value()
    puts(content)
end
```

### Example 5: UTF-8 Handling

```quest
use "std/io"

let buf = io.StringIO.new("Hello → World")
puts("Bytes: " .. buf.len())        # 15 (→ is 3 bytes)
puts("Characters: " .. buf.char_len())  # 13

# Seek uses byte positions
buf.seek(6)
puts(buf.read())  # "→ World"
```
"""
