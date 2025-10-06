# sys - System params

The `sys` module provides access to system-level information and runtime details, similar to Python's `sys` module.

## Usage

```quest
use "std/sys"

puts("Version:", sys.version)
puts("Platform:", sys.platform)
puts("Args:", sys.argv)
```

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

### `sys.script_path`

The absolute path to the currently executing script file. This is `nil` when running in the REPL or from piped stdin.

**Type:** Str or Nil

**Example:**
```quest
# my_script.q
puts("Script path:", sys.script_path)
# Output: Script path: /Users/username/projects/my_script.q

# Use it to load files relative to the script
if sys.script_path != nil
    let script_dir = sys.script_path.split("/").slice(0, -1).join("/")
    puts("Script directory:", script_dir)
end
```

**Common Use Cases:**
- Loading configuration files relative to the script location
- Determining the script's directory for file operations
- Building portable scripts that reference local resources

**Note:** `sys.script_path` is always an absolute, canonicalized path (symlinks are resolved). For relative imports, see the "Relative Imports" section below.

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

### `sys.INT_MIN`

The minimum value for a 64-bit signed integer (`-9223372036854775808`).

**Type:** Int

**Example:**
```quest
use "std/sys"

puts("Min int:", sys.INT_MIN)
# Output: Min int: -9223372036854775808

# Useful for overflow testing
try
    sys.INT_MIN - 1  # Overflow!
catch e
    puts("Overflow detected:", e)
end
```

### `sys.INT_MAX`

The maximum value for a 64-bit signed integer (`9223372036854775807`).

**Type:** Int

**Example:**
```quest
use "std/sys"

puts("Max int:", sys.INT_MAX)
# Output: Max int: 9223372036854775807

# Useful for overflow testing
try
    sys.INT_MAX + 1  # Overflow!
catch e
    puts("Overflow detected:", e)
end
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

### Implemented
- ✅ `sys.exit()` - Exit with status code

### Not Implemented (yet)
- ❌ `sys.stdin`, `sys.stdout`, `sys.stderr` - Standard streams
- ❌ `sys.path` - Module search paths (Quest uses `os.search_path`)
- ❌ `sys.modules` - Loaded modules cache

## Relative Imports

Quest supports relative imports using the `.` prefix in `use` statements. This allows modules to import files relative to their own location, making code more portable.

### Syntax

```quest
use ".module" as m          # Import module.q from same directory
use ".subdir/helper" as h   # Import from subdirectory
```

### How It Works

- Relative imports start with a dot (`.`)
- The path is resolved relative to the directory containing the current script file
- The `.q` extension is automatically added if not present
- Relative imports can only be used in script files, not in the REPL

### Example Structure

```
project/
├── main.q
├── utils.q
└── lib/
    └── helper.q
```

**main.q:**
```quest
use ".utils" as utils
use ".lib/helper" as helper

puts(utils.greeting)
puts(helper.process())
```

**utils.q:**
```quest
use ".lib/helper" as helper  # Relative imports work in modules too

let greeting = "Hello!"

fun enhanced()
    return greeting .. " " .. helper.suffix
end
```

**lib/helper.q:**
```quest
let suffix = "from helper"

fun process()
    return "Processing..."
end
```

### Benefits

1. **Portability** - Scripts can be moved to different locations without changing import paths
2. **Clarity** - Makes it clear which imports are local vs external
3. **Nested Imports** - Modules can use relative imports to load their own dependencies

### When to Use

- ✅ Use relative imports (`.`) for files within your project
- ✅ Use absolute imports (`std/...` or module names) for standard library and external modules
- ✅ Relative imports work in nested module imports

### Comparison with sys.script_path

- **`sys.script_path`** - Get the absolute path of the current script
- **Relative imports** - Import modules relative to the current script

While `sys.script_path` gives you the path as a string, relative imports handle the resolution automatically:

```quest
# Manual approach using sys.script_path
let script_dir = sys.script_path.split("/").slice(0, -1).join("/")
use (script_dir .. "/utils")  # This doesn't work - use takes string literals

# Better approach: use relative imports
use ".utils" as utils  # Automatically resolves to same directory
```

## Notes

- The `sys` module must be explicitly imported with `use "std/sys"`
- All `sys` properties are **read-only** - attempting to modify them has no effect
- `sys.argv` always includes the script name as the first element
- `sys.script_path` is `nil` in the REPL or when reading from stdin
- Relative imports (`.`) only work in script files, not in the REPL

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

## Module Functions

### `sys.exit([code])`

Immediately exit the program with the specified status code.

**Parameters:**
- `code` (Num, optional) - Exit status code (default: 0)
  - `0` - Success (default)
  - Non-zero - Error/failure

**Returns:** Never returns (process exits)

**Example:**
```quest
use "std/sys"

# Exit with success
sys.exit()  # Exit code 0

# Exit with error
sys.exit(1)

# Exit with custom code
if some_error
    sys.exit(2)
end
```

**Use Cases:**
- **Error Handling** - Exit when encountering fatal errors
- **Validation** - Exit early if prerequisites aren't met
- **Test Runners** - Exit with non-zero code when tests fail
- **CLI Tools** - Return appropriate exit codes for shell scripts

**Example: Test Runner**
```quest
use "std/sys"
use "std/test" as test

# Run tests
test.run()

# Exit with error code if any tests failed
if test.failed_count() > 0
    sys.exit(1)
end

# Exit with success
sys.exit(0)
```

**Example: Argument Validation**
```quest
use "std/sys"

if sys.argc < 2
    puts("Error: Missing required argument")
    puts("Usage:", sys.argv[0], "<filename>")
    sys.exit(1)
end

let filename = sys.argv[1]
# ... process file
```

**Notes:**
- The process exits immediately, no cleanup code runs after `sys.exit()`
- Use exit code `0` for success, non-zero for errors
- Common conventions:
  - `0` - Success
  - `1` - General error
  - `2` - Misuse of command (e.g., invalid arguments)
  - `126` - Command cannot execute
  - `127` - Command not found
  - `128+n` - Fatal error signal n

### `sys.load_module(path)`

Dynamically load a Quest module at runtime. Returns the loaded module object.

**Parameters:**
- `path` (Str) - Path to the `.q` file to load (relative or absolute)

**Returns:** Module object

**Example:**
```quest
# Load a module dynamically
let mod = sys.load_module("test/sample.q")

# Access module members
puts(mod.greeting)

# Load without capturing (useful for test files that self-register)
sys.load_module("test/integration.q")
```

**Use Cases:**
- **Test Discovery** - Load test files dynamically
- **Plugin Systems** - Load plugins based on configuration
- **Conditional Loading** - Load modules based on runtime conditions

**Example: Test Discovery**
```quest
use "std/io" as io
use "std/test" as test

# Find all test files
let test_files = io.glob("test/**/*.q")

# Load each test file
for file in test_files
    sys.load_module(file)
end

# Run discovered tests
test.run()
```

**Notes:**
- The module is executed in its own scope
- Module cache is shared, so loading the same file twice returns the cached version
- Paths are canonicalized for security (prevents directory traversal)
- Relative paths are resolved from the current working directory
- For relative-to-script imports, use the `.` prefix in `use` statements instead

### `sys.eval(code)`

Evaluate Quest code from a string in the current scope. This enables dynamic code execution, code generation, and metaprogramming patterns.

**Parameters:**
- `code` (Str) - Quest code to evaluate

**Returns:** The result of the last expression in the code

**Example:**
```quest
use "std/sys"

# Evaluate simple expression
let result = sys.eval("2 + 2")
puts(result)  # 4

# Evaluate with variables in scope
let x = 10
let result = sys.eval("x * 2")
puts(result)  # 20

# Execute statements
sys.eval("let y = 5")
puts(y)  # 5 (variable created in current scope)

# Evaluate complex code
let code = """
let sum = 0
for i in 1 to 10
    sum = sum + i
end
sum
"""
puts(sys.eval(code))  # 55
```

**Use Cases:**
- **Dynamic expressions** - Evaluate user-provided formulas
- **Code generation** - Build and execute code at runtime
- **Configuration** - Execute code from config files
- **REPL features** - Build custom interactive environments
- **Testing** - Generate test cases programmatically

**Security Warning:**
⚠️ **Never evaluate untrusted user input** - This can execute arbitrary code with full access to your program's scope and capabilities. Only use with trusted code.

```quest
# ❌ DANGEROUS - User can execute arbitrary code
let user_input = "sys.exit(1)"  # Or worse
sys.eval(user_input)  # BAD!

# ✅ SAFE - Controlled environment
let allowed_vars = {"x": 10, "y": 20}
let formula = "x + y"  # From config file
let result = sys.eval(formula)
```

**Error Handling:**
```quest
try
    let result = sys.eval("invalid syntax!")
catch e
    puts("Parse error:", e.message())
end
```

**Notes:**
- Code is parsed and evaluated in the current scope
- Variables created by eval() persist in the scope
- Empty or whitespace-only strings return nil
- Syntax errors raise ParseError exceptions
- Runtime errors propagate as normal exceptions

## Summary

The `sys` module provides essential system and runtime information:

**Properties:**
- **`sys.version`** - Quest version
- **`sys.platform`** - OS platform name
- **`sys.executable`** - Path to Quest executable
- **`sys.script_path`** - Absolute path to current script (nil in REPL)
- **`sys.builtin_module_names`** - Available built-in modules
- **`sys.argc`** - Argument count
- **`sys.argv`** - Argument array
- **`sys.INT_MIN`** - Minimum 64-bit signed integer value (-9223372036854775808)
- **`sys.INT_MAX`** - Maximum 64-bit signed integer value (9223372036854775807)

**Functions:**
- **`sys.exit([code])`** - Exit program with status code
- **`sys.load_module(path)`** - Dynamically load a module at runtime
- **`sys.eval(code)`** - Evaluate Quest code from a string (QEP-018)

**Additional features:**
- **Relative imports** - Use `.` prefix to import files relative to current script

Use these properties and features to build flexible, portable, cross-platform Quest scripts!
