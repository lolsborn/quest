# IO Module

The `io` module provides file and stream input/output operations.

## File Reading

### `io.read(path)`
Read entire file contents as a string

**Parameters:**
- `path` - File path (Str)

**Returns:** File contents (Str)

**Raises:** Error if file doesn't exist or can't be read

**Example:**
```
let content = io.read("data.txt")
puts(content)
```

### `io.read_lines(path)`
Read file as list of lines (with newlines stripped)

**Parameters:**
- `path` - File path (Str)

**Returns:** List of lines (List of Str)

**Example:**
```
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
```
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
```
io.write("output.txt", "Hello, World!")
```

### `io.write_lines(path, lines)`
Write list of strings to file (adds newlines)

**Parameters:**
- `path` - File path (Str)
- `lines` - List of strings (List)

**Returns:** Nil

**Example:**
```
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
```
io.append("log.txt", "New log entry\n")
```

## File Operations

### `io.exists(path)`
Check if file or directory exists

**Parameters:**
- `path` - File or directory path (Str)

**Returns:** Bool (true if exists)

**Example:**
```
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
```
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
```
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
```
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
```
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
```
let files = io.list_dir(".")
for file in files
    puts(file)
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
```
let abs = io.absolute("../data/file.txt")
puts(abs)  # /Users/name/project/data/file.txt
```

### `io.basename(path)`
Get filename from path

**Parameters:**
- `path` - File path (Str)

**Returns:** Filename (Str)

**Example:**
```
io.basename("/path/to/file.txt")  # Returns "file.txt"
```

### `io.dirname(path)`
Get directory from path

**Parameters:**
- `path` - File path (Str)

**Returns:** Directory path (Str)

**Example:**
```
io.dirname("/path/to/file.txt")  # Returns "/path/to"
```

### `io.extension(path)`
Get file extension

**Parameters:**
- `path` - File path (Str)

**Returns:** Extension including dot (Str) or empty string

**Example:**
```
io.extension("file.txt")  # Returns ".txt"
io.extension("archive.tar.gz")  # Returns ".gz"
```

### `io.join(parts...)`
Join path components with appropriate separator

**Parameters:**
- `parts...` - Path components (Str)

**Returns:** Joined path (Str)

**Example:**
```
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
```
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
```
if io.glob_match("test_utils.q", "test_*.q")
    puts("This is a test file")
end
```

## Stream/Handle Operations

### `io.open(path, mode = "r")`
Open file and return file handle

**Parameters:**
- `path` - File path (Str)
- `mode` - Open mode (Str): "r" (read), "w" (write), "a" (append), "r+" (read/write)

**Returns:** File handle (File)

**Example:**
```
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
```
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
```
io.stderr.write("Error: something went wrong\n")
```

### `io.read_line()`
Read line from standard input

**Returns:** Input line (Str)

**Example:**
```
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
```
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
```
io.with_file("config.json", "w", fun(f)
    f.write("{")
    f.write("  \"version\": 1,")
    f.write("  \"enabled\": true")
    f.write("}")
end)
```

### Directory Traversal
```
let quest_files = []
for file in io.walk("src")
    if io.extension(file) == ".q"
        quest_files.append(file)
    end
end
puts("Found ", quest_files.len(), " Quest files")
```

### File Size Check
```
if io.exists("large_file.dat") and io.size("large_file.dat") > 1000000
    puts("Warning: File is larger than 1MB")
end
```
