# sys Module

The `sys` module provides access to system-level information and runtime details, similar to Python's `sys` module.

## Usage

```quest
# The sys module is automatically available in scripts
puts("Version:", sys.version)
puts("Platform:", sys.platform)
puts("Args:", sys.argv)
```

**Note**: The `sys` module is automatically injected into script scope and doesn't need to be imported.

## Module Properties

### `sys.version`

The Quest version string.

**Type:** Str

**Example:**
```quest
puts("Quest version:", sys.version)
# Output: Quest version: 0.1.0
```

### `sys.platform`

The operating system platform name.

**Type:** Str

**Values:**
- `"darwin"` - macOS
- `"linux"` - Linux
- `"win32"` - Windows
- `"freebsd"` - FreeBSD
- `"openbsd"` - OpenBSD
- `"unknown"` - Other/unrecognized platforms

**Example:**
```quest
if sys.platform == "darwin"
    puts("Running on macOS")
elif sys.platform == "linux"
    puts("Running on Linux")
elif sys.platform == "win32"
    puts("Running on Windows")
end
```

### `sys.executable`

The absolute path to the Quest executable.

**Type:** Str

**Example:**
```quest
puts("Quest executable:", sys.executable)
# Output: Quest executable: /usr/local/bin/quest
```

### `sys.builtin_module_names`

Array of all built-in module names that can be imported.

**Type:** Array of Str

**Example:**
```quest
puts("Available modules:", sys.builtin_module_names)
# Output: Available modules: [math, os, term, hash, json, io, sys]

# Check if a module is available
if sys.builtin_module_names.contains("math")
    use math
    puts("Math module available!")
end
```

### `sys.argc`

The number of command-line arguments passed to the script, including the script name.

**Type:** Num

**Example:**
```quest
# script.q
puts("Number of arguments:", sys.argc)
```

```bash
$ quest script.q
Number of arguments: 1

$ quest script.q arg1 arg2
Number of arguments: 3
```

### `sys.argv`

Array containing all command-line arguments. The first element (`sys.argv[0]`) is always the script name.

**Type:** Array of Str

**Example:**
```quest
# greet.q
if sys.argc < 2
    puts("Usage:", sys.argv[0], "<name>")
else
    puts("Hello,", sys.argv[1] .. "!")
end
```

```bash
$ quest greet.q
Usage: greet.q <name>

$ quest greet.q Alice
Hello, Alice!
```

## Common Patterns

### Version Checking

```quest
# Check if running a specific version
let required_version = "0.1.0"
if sys.version != required_version
    puts("Warning: This script requires Quest", required_version)
    puts("You are running", sys.version)
end
```

### Platform-Specific Behavior

```quest
# Use platform-specific paths
let config_dir = ""
if sys.platform == "win32"
    config_dir = "C:\\Users\\Config"
else
    config_dir = "/home/user/.config"
end
```

### Argument Parsing

```quest
#!/usr/bin/env quest
# Simple argument parser

if sys.argc < 2
    puts("Usage:", sys.argv[0], "<command> [options]")
else
    let command = sys.argv[1]

    if command == "help"
        puts("Available commands: help, run, test")
    elif command == "run"
        puts("Running...")
    elif command == "test"
        puts("Testing...")
    else
        puts("Unknown command:", command)
    end
end
```

### Processing Multiple Files

```quest
#!/usr/bin/env quest
# process_files.q

if sys.argc < 2
    puts("Usage:", sys.argv[0], "<file1> [file2] [file3] ...")
else
    puts("Processing", sys.argc - 1, "files:")

    # Skip first argument (script name), process rest
    sys.argv.slice(1, sys.argc).each(fun (filename)
        puts("  Processing:", filename)
        # ... process file
    end)
end
```

### Flag Parsing

```quest
#!/usr/bin/env quest
# Example with -v verbose flag

let verbose = false
let files = []

# Parse arguments
let i = 1
while i < sys.argc
    let arg = sys.argv[i]

    if arg == "-v" or arg == "--verbose"
        verbose = true
    elif arg.startswith("-")
        puts("Unknown flag:", arg)
    else
        files = files.push(arg)
    end

    i = i + 1
end

if verbose
    puts("Verbose mode enabled")
    puts("Processing", files.len(), "files")
end
```

## Practical Examples

### File Processor with Help

```quest
#!/usr/bin/env quest
# file_stats.q - Display file statistics

fun show_help()
    puts("Usage:", sys.argv[0], "<filename>")
    puts("")
    puts("Displays statistics about a file")
    puts("")
    puts("Options:")
    puts("  -h, --help    Show this help message")
end

if sys.argc < 2 or sys.argv[1] == "-h" or sys.argv[1] == "--help"
    show_help()
else
    let filename = sys.argv[1]
    puts("File:", filename)
    puts("Platform:", sys.platform)
    # ... read and process file
end
```

### Calculator Script

```quest
#!/usr/bin/env quest
# calc.q - Simple calculator

if sys.argc != 4
    puts("Usage:", sys.argv[0], "<num1> <op> <num2>")
    puts("Example:", sys.argv[0], "5 + 3")
    puts("")
    puts("Operators: +, -, *, /")
else
    # Note: In a real implementation, you'd convert strings to numbers
    let a_str = sys.argv[1]
    let op = sys.argv[2]
    let b_str = sys.argv[3]

    puts("Operation:", a_str, op, b_str)
    # ... perform calculation
end
```

### Environment Info

```quest
#!/usr/bin/env quest
# sysinfo.q - Display system information

puts("=== Quest System Information ===")
puts("")
puts("Version:", sys.version)
puts("Platform:", sys.platform)
puts("Executable:", sys.executable)
puts("")
puts("Built-in Modules:")
sys.builtin_module_names.each(fun (name)
    puts("  -", name)
end)
puts("")
puts("Command Line:")
puts("  Script:", sys.argv[0])
puts("  Arguments:", sys.argc - 1)
if sys.argc > 1
    sys.argv.slice(1, sys.argc).each(fun (arg, idx)
        puts("    [" .. idx._str() .. "]:", arg)
    end)
end
```

## Differences from Python's sys Module

### Similar Features
- ✅ `sys.argv` - Command line arguments (same concept)
- ✅ `sys.version` - Version string (similar)
- ✅ `sys.platform` - Platform name (similar)
- ✅ `sys.executable` - Executable path (similar)

### Quest-Specific
- ✅ `sys.argc` - Argument count (not in Python, Python uses `len(sys.argv)`)
- ✅ `sys.builtin_module_names` - Quest's built-in modules

### Not Implemented (yet)
- ❌ `sys.exit()` - Exit with status code
- ❌ `sys.stdin`, `sys.stdout`, `sys.stderr` - Standard streams
- ❌ `sys.path` - Module search paths (Quest uses `os.search_path`)
- ❌ `sys.modules` - Loaded modules cache

## Notes

- The `sys` module is **automatically available** in scripts - no `use sys` required
- In the REPL, `sys` is not available since there's no script context
- All `sys` properties are **read-only** - attempting to modify them has no effect
- `sys.argv` always includes the script name as the first element

## Best Practices

1. **Always check argc before accessing argv**
   ```quest
   if sys.argc > 1
       let arg = sys.argv[1]
   end
   ```

2. **Provide usage information**
   ```quest
   if sys.argc < 2
       puts("Usage:", sys.argv[0], "<required_arg>")
   end
   ```

3. **Use sys.platform for cross-platform code**
   ```quest
   let path_sep = if sys.platform == "win32" "\\" else "/" end
   ```

4. **Store argv values in named variables**
   ```quest
   let script_name = sys.argv[0]
   let input_file = if sys.argc > 1 sys.argv[1] else "" end
   ```

## Summary

The `sys` module provides essential system and runtime information:
- **`sys.version`** - Quest version
- **`sys.platform`** - OS platform name
- **`sys.executable`** - Path to Quest executable
- **`sys.builtin_module_names`** - Available built-in modules
- **`sys.argc`** - Argument count
- **`sys.argv`** - Argument array

Use these properties to build flexible, cross-platform Quest scripts!
