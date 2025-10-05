# os - Misc OS interfaces

The `os` module provides operating system interfaces for file system operations, directory management, and environment variables.

## Usage

```quest
use "std/os" as os

# Get current directory
let cwd = os.getcwd()
puts("Current directory:", cwd)

# List directory contents
let files = os.listdir(".")
files.each(fun (file)
    puts(file)
end)
```

## Directory Operations

### `os.getcwd()`

Returns the current working directory.

**Returns:** Str - Absolute path to current directory

**Example:**
```quest
let current = os.getcwd()
puts("Working in:", current)
# Output: Working in: /home/user/project
```

### `os.chdir(path)`

Changes the current working directory.

**Parameters:**
- `path` (Str) - Path to new working directory

**Returns:** nil

**Raises:** Error if path doesn't exist or isn't accessible

**Example:**
```quest
os.chdir("/tmp")
puts("Now in:", os.getcwd())
```

### `os.listdir(path)`

Lists the contents of a directory.

**Parameters:**
- `path` (Str) - Directory path to list

**Returns:** Array of Str - File and directory names

**Raises:** Error if path doesn't exist or isn't a directory

**Example:**
```quest
let files = os.listdir(".")
puts("Files in current directory:")
files.each(fun (name)
    puts("  -", name)
end)
```

### `os.mkdir(path)`

Creates a new directory.

**Parameters:**
- `path` (Str) - Path of directory to create

**Returns:** nil

**Raises:** Error if directory already exists or path is invalid

**Example:**
```quest
os.mkdir("new_folder")
puts("Created directory: new_folder")
```

### `os.rmdir(path)`

Removes an empty directory.

**Parameters:**
- `path` (Str) - Path of directory to remove

**Returns:** nil

**Raises:** Error if directory doesn't exist, isn't empty, or isn't accessible

**Example:**
```quest
os.rmdir("old_folder")
puts("Removed directory: old_folder")
```

## File Operations

### `os.remove(path)`

Deletes a file.

**Parameters:**
- `path` (Str) - Path of file to delete

**Returns:** nil

**Raises:** Error if file doesn't exist or isn't accessible

**Example:**
```quest
os.remove("temp.txt")
puts("Deleted file: temp.txt")
```

### `os.rename(src, dst)`

Renames a file or directory.

**Parameters:**
- `src` (Str) - Source path
- `dst` (Str) - Destination path

**Returns:** nil

**Raises:** Error if source doesn't exist or destination already exists

**Example:**
```quest
os.rename("old_name.txt", "new_name.txt")
puts("File renamed")
```

## Environment Variables

### `os.environ()`

Returns all environment variables as a dictionary.

**Returns:** Dict - Environment variables as key-value pairs

**Example:**
```quest
let env = os.environ()
puts("PATH:", env["PATH"])
puts("HOME:", env["HOME"])
```

### `os.getenv(key)`

Gets the value of an environment variable.

**Parameters:**
- `key` (Str) - Environment variable name

**Returns:** Str or nil - Variable value, or nil if not set

**Example:**
```quest
let home = os.getenv("HOME")
if home != nil
    puts("Home directory:", home)
else
    puts("HOME not set")
end
```

### `os.setenv(key, value)`

Sets an environment variable.

**Parameters:**
- `key` (Str) - Environment variable name
- `value` (Str) - Value to set

**Returns:** nil

**Example:**
```quest
os.setenv("MY_VAR", "my_value")
puts("Set MY_VAR to:", os.getenv("MY_VAR"))
```

### `os.unsetenv(key)`

Removes an environment variable.

**Parameters:**
- `key` (Str) - Environment variable name to remove

**Returns:** nil

**Example:**
```quest
os.setenv("TEMP_VAR", "temp_value")
os.unsetenv("TEMP_VAR")
# TEMP_VAR is now removed
let result = os.getenv("TEMP_VAR")  # Returns nil
```

## Common Patterns

### Directory Traversal

```quest
use "std/os" as os

fun list_all_files(path)
    let items = os.listdir(path)
    items.each(fun (item)
        let full_path = path .. "/" .. item
        puts(full_path)
    end)
end

list_all_files(".")
```

### Safe Directory Creation

```quest
use "std/os" as os

fun ensure_dir(path)
    # Only create if it doesn't exist
    let files = os.listdir(".")
    if !files.contains(path)
        os.mkdir(path)
        puts("Created:", path)
    else
        puts("Already exists:", path)
    end
end

ensure_dir("data")
```

### Backup Files

```quest
use "std/os" as os

fun backup_file(filename)
    let backup_name = filename .. ".bak"
    os.rename(filename, backup_name)
    puts("Backed up", filename, "to", backup_name)
end

backup_file("config.txt")
```

### Environment Configuration

```quest
use "std/os" as os

# Read config from environment with defaults
let port = os.getenv("APP_PORT")
if port == nil
    port = "8080"
end

let host = os.getenv("APP_HOST")
if host == nil
    host = "localhost"
end

puts("Server running on", host .. ":" .. port)
```

### Clean Temporary Files

```quest
use "std/os" as os

let temp_dir = os.getenv("TMPDIR")
if temp_dir == nil
    temp_dir = "/tmp"
end

os.chdir(temp_dir)
let files = os.listdir(".")

files.each(fun (file)
    if file.startswith("temp_")
        os.remove(file)
        puts("Removed:", file)
    end
end)
```

## Platform Considerations

- Paths use forward slashes `/` on Unix-like systems (Linux, macOS)
- Paths use backslashes `\` on Windows (use `\\` in strings)
- Some environment variables are platform-specific:
  - Unix: `HOME`, `USER`, `SHELL`
  - Windows: `USERPROFILE`, `USERNAME`, `COMSPEC`

**Cross-platform path example:**
```quest
use "std/os" as os

let home = os.getenv("HOME")
if home == nil
    home = os.getenv("USERPROFILE")  # Windows fallback
end
puts("Home directory:", home)
```

## Best Practices

1. **Check existence before operations**
   ```quest
   let files = os.listdir(".")
   if files.contains("data")
       os.chdir("data")
   end
   ```

2. **Use absolute paths when possible**
   ```quest
   let abs_path = os.getcwd() .. "/data"
   os.mkdir(abs_path)
   ```

3. **Handle missing environment variables**
   ```quest
   let value = os.getenv("MY_VAR")
   if value == nil
       value = "default"
   end
   ```

4. **Restore working directory after changes**
   ```quest
   let original = os.getcwd()
   os.chdir("/tmp")
   # ... do work
   os.chdir(original)
   ```

## Summary

The `os` module provides essential operating system interfaces:

**Directory Operations:**
- `os.getcwd()` - Get current directory
- `os.chdir(path)` - Change directory
- `os.listdir(path)` - List directory contents
- `os.mkdir(path)` - Create directory
- `os.rmdir(path)` - Remove directory

**File Operations:**
- `os.remove(path)` - Delete file
- `os.rename(src, dst)` - Rename file or directory

**Environment Variables:**
- `os.environ()` - Get all environment variables
- `os.getenv(key)` - Get specific variable
- `os.setenv(key, value)` - Set variable
- `os.unsetenv(key)` - Remove variable
