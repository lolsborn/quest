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

%fun read(path)
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

%fun write(path, content)
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

%fun append(path, content)
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

%fun exists(path)
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

%fun is_file(path)
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

%fun is_dir(path)
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

%fun size(path)
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

%fun copy(src, dst)
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

%fun move(src, dst)
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

%fun remove(path)
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

%fun glob(pattern)
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

%fun glob_match(path, pattern)
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

# type Settings
#     header_color: str = "bold_cyan"
#     list_bullet: str = "•"
#     list_bullet_color: str = "green"
#     bold_word_color: str = "bold_yellow"
#     italic_word_color: str = "italic_yellow"
#     code_block_color: str = "dimmed"
#     error_word_color: str = "red"
# end
