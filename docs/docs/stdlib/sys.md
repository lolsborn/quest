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

### `sys.stdout`

Singleton object representing the standard output stream.

**Type:** SystemStream

**Methods:**
- `write(str)` - Write a string to stdout, returns the number of bytes written

**Example:**
```quest
use "std/sys"

let count = sys.stdout.write("Hello World\n")
puts("Wrote " .. count.str() .. " bytes")
# Output: Hello World
#         Wrote 12 bytes
```

**Use Cases:**
- Direct output control (alternative to `puts` and `print`)
- Byte count tracking
- Redirection target (see `sys.redirect_stream()`)

### `sys.stderr`

Singleton object representing the standard error stream.

**Type:** SystemStream

**Methods:**
- `write(str)` - Write a string to stderr, returns the number of bytes written

**Example:**
```quest
use "std/sys"

sys.stderr.write("Error: Something went wrong\n")
# Writes to stderr instead of stdout
```

**Use Cases:**
- Error and warning messages
- Diagnostic output separate from normal output
- Logging that should not be captured by stdout redirection

**Example: Separate stdout and stderr**
```quest
puts("Normal output")           # Goes to stdout
sys.stderr.write("Error!\n")    # Goes to stderr

# In shell: quest script.q 2>/dev/null  (suppresses stderr only)
```

### `sys.stdin`

Singleton object representing the standard input stream.

**Type:** SystemStream

**Note:** Currently supports basic operations. Full read functionality may be added in future versions.

**Example:**
```quest
use "std/sys"

puts("stdin type:", sys.stdin.cls())
# Output: stdin type: stdin
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
        puts("    [" .. idx.str() .. "]:", arg)
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
- ✅ `sys.stdin`, `sys.stdout`, `sys.stderr` - Standard stream objects (QEP-010)
- ✅ `sys.redirect_stream()` - I/O redirection (QEP-010)

### Not Implemented (yet)
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

### `sys.fail([message])`

Immediately raise an exception with an optional error message. This is a convenience function for testing and error handling.

**Parameters:**
- `message` (Str, optional) - Error message (default: "Failure")

**Returns:** Never returns (raises exception)

**Example:**
```quest
use "std/sys"

# Raise generic failure
try
    sys.fail()
catch e
    puts(e)  # "Failure"
end

# Raise with custom message
try
    sys.fail("Invalid configuration")
catch e
    puts(e)  # "Invalid configuration"
end
```

**Use Cases:**
- **Testing** - Trigger test failures
- **Validation** - Fail fast when preconditions aren't met
- **Development** - Mark unimplemented code paths

**Example: Input validation**
```quest
fun process_age(age)
    if age < 0
        sys.fail("Age cannot be negative")
    end
    if age > 150
        sys.fail("Age seems unrealistic")
    end
    # Process valid age
end

try
    process_age(-5)
catch e
    puts("Error:", e)  # Error: Age cannot be negative
end
```

**Example: Test helper**
```quest
fun assert_positive(n)
    if n <= 0
        sys.fail("Expected positive number, got " .. n.str())
    end
end

try
    assert_positive(-10)
catch e
    puts("Test failed:", e)
end
```

**Note:** Unlike `sys.exit()` which terminates the process, `sys.fail()` raises an exception that can be caught with `try/catch`.

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

### `sys.redirect_stream(from, to)`

Redirect stdout or stderr to a file, StringIO buffer, or another stream. Returns a RedirectGuard object that can restore the original output target.

**Parameters:**
- `from` - The stream to redirect (must be `sys.stdout` or `sys.stderr`)
- `to` - The target destination:
  - String (file path) - Appends to file
  - StringIO object - Captures to in-memory buffer
  - `sys.stdout` or `sys.stderr` - Redirect to another stream

**Returns:** RedirectGuard object with methods:
- `restore()` - Restore the original output target
- `is_active()` - Check if redirection is still active

**Example: Capture output to StringIO**
```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()
let guard = sys.redirect_stream(sys.stdout, buffer)

puts("This goes to the buffer")
puts("So does this")

guard.restore()

puts("This goes to normal stdout")
puts("Buffer contains: " .. buffer.get_value())
# Output: Buffer contains: This goes to the buffer\nSo does this\n
```

**Example: Redirect to file**
```quest
let guard = sys.redirect_stream(sys.stdout, "/tmp/output.txt")
puts("This goes to the file")
puts("So does this")
guard.restore()

let content = io.read("/tmp/output.txt")
puts(content)  # Shows captured output
```

**Example: Context manager (automatic restore)**
```quest
let buffer = io.StringIO.new()

with sys.redirect_stream(sys.stdout, buffer) as guard
    puts("Captured in with block")
    puts("Automatically restored when block ends")
end  # guard.restore() called automatically

puts("Normal output")
puts("Buffer: " .. buffer.get_value())
```

**Example: Redirect stderr to stdout**
```quest
let buffer = io.StringIO.new()
let guard_out = sys.redirect_stream(sys.stdout, buffer)
let guard_err = sys.redirect_stream(sys.stderr, sys.stdout)

puts("Normal output")
sys.stderr.write("Error output\n")

guard_err.restore()
guard_out.restore()

# Both stdout and stderr captured in buffer
puts("All output: " .. buffer.get_value())
```

**Example: Suppress output**
```quest
# Redirect to /dev/null to suppress output
let guard = sys.redirect_stream(sys.stdout, "/dev/null")
puts("This is hidden")
puts("So is this")
guard.restore()

puts("This is visible again")
```

**Example: Nested redirections**
```quest
let buf1 = io.StringIO.new()
let buf2 = io.StringIO.new()

let guard1 = sys.redirect_stream(sys.stdout, buf1)
puts("Outer")

let guard2 = sys.redirect_stream(sys.stdout, buf2)
puts("Inner")
guard2.restore()

puts("Outer again")
guard1.restore()

# buf1 contains: "Outer\nOuter again\n"
# buf2 contains: "Inner\n"
```

**Use Cases:**
- **Testing** - Capture output for test assertions
- **Logging** - Redirect output to log files
- **Silence** - Suppress unwanted output (redirect to `/dev/null`)
- **Debugging** - Separate stdout and stderr for analysis
- **Output Processing** - Capture and transform program output

**RedirectGuard Methods:**

`restore()` - Restore the original output target. Safe to call multiple times (idempotent).

```quest
let guard = sys.redirect_stream(sys.stdout, buffer)
# ... output code ...
guard.restore()  # Restore
guard.restore()  # Safe to call again (does nothing)
```

`is_active()` - Check if the redirection is still active.

```quest
let guard = sys.redirect_stream(sys.stdout, buffer)
puts(guard.is_active())  # true

guard.restore()
puts(guard.is_active())  # false
```

**Context Manager Support:**

RedirectGuard implements the context manager protocol (`_enter()` and `_exit()`), making it safe to use with `with` statements. The stream is automatically restored when the block exits, even if an exception occurs.

```quest
let buffer = io.StringIO.new()

try
    with sys.redirect_stream(sys.stdout, buffer)
        puts("Before error")
        raise "Something went wrong"
        puts("Never printed")
    end  # Automatically restored despite exception
catch e
    puts("Caught: " .. e.message())
end

# Output captured before error
puts(buffer.get_value())  # "Before error\n"
```

**Notes:**
- Redirections are restored automatically when using `with` statements
- Multiple redirections can be active simultaneously (stdout and stderr independently)
- Nested redirections are supported - restore in reverse order for proper cleanup
- File redirections append to existing files
- RedirectGuard uses shared state (Rc\<RefCell\<>>) so clones share the same active status
- Stream objects (`sys.stdout`, `sys.stderr`) are singletons

**Best Practices:**

1. **Always restore or use context managers**
   ```quest
   # ✅ Good - guaranteed restore
   with sys.redirect_stream(sys.stdout, buffer) as guard
       # code
   end

   # ✅ Good - manual restore with ensure
   let guard = sys.redirect_stream(sys.stdout, buffer)
   try
       # code
   ensure
       guard.restore()
   end
   ```

2. **Independent stdout/stderr redirection**
   ```quest
   let out_buf = io.StringIO.new()
   let err_buf = io.StringIO.new()

   with sys.redirect_stream(sys.stdout, out_buf)
       with sys.redirect_stream(sys.stderr, err_buf)
           # Both streams captured independently
       end
   end
   ```

3. **Testing output**
   ```quest
   # Capture and assert on output
   let buffer = io.StringIO.new()
   with sys.redirect_stream(sys.stdout, buffer)
       my_function_that_prints()
   end

   test.assert_eq(buffer.get_value(), "Expected output\n")
   ```

### `sys.pid()`

Get the process ID (PID) of the current Quest process.

**Parameters:** None

**Returns:** Int - The current process ID

**Example:**
```quest
use "std/sys"

let pid = sys.pid()
puts("Current process ID:", pid)
# Output: Current process ID: 12345
```

**Use Cases:**
- **Process management** - Track process identity for logging or debugging
- **Lock files** - Create PID-based lock files to prevent multiple instances
- **Interprocess communication** - Use PID for signaling or coordination
- **Diagnostics** - Include PID in error reports or log files

**Example: Create a PID lock file**
```quest
use "std/sys"
use "std/io" as io

let lock_file = "/tmp/myapp.pid"

# Check if lock file exists
if io.exists(lock_file)
    let old_pid = io.read(lock_file).trim()
    puts("Error: Another instance may be running (PID:", old_pid .. ")")
    sys.exit(1)
end

# Write current PID to lock file
io.write(lock_file, sys.pid().str() .. "\n")

# ... run application ...

# Cleanup lock file when done
io.remove(lock_file)
```

**Example: Logging with PID**
```quest
use "std/sys"

fun log(message)
    let timestamp = "2025-01-15 10:30:45"  # Simplified
    let pid = sys.pid()
    puts("[" .. timestamp .. "] [PID " .. pid.str() .. "] " .. message)
end

log("Application started")
log("Processing data")
# Output: [2025-01-15 10:30:45] [PID 12345] Application started
#         [2025-01-15 10:30:45] [PID 12345] Processing data
```

**Example: Unique temporary files**
```quest
use "std/sys"

let temp_file = "/tmp/data_" .. sys.pid().str() .. ".tmp"
puts("Using temp file:", temp_file)
# Output: Using temp file: /tmp/data_12345.tmp
```

**Notes:**
- Returns a unique identifier for the current operating system process
- The PID is assigned by the OS and persists for the lifetime of the process
- PIDs can be reused by the OS after a process terminates
- On Unix-like systems, PID 1 is typically the init/systemd process
- Cross-platform compatible (works on macOS, Linux, Windows, BSD)

### `sys.get_call_depth()`

Get the current function call depth. Returns the number of active function calls on the stack.

**Parameters:** None

**Returns:** Int - Current call depth

**Example:**
```quest
use "std/sys"

fun level_a()
    puts("Level A depth:", sys.get_call_depth())
    level_b()
end

fun level_b()
    puts("Level B depth:", sys.get_call_depth())
end

puts("Top level depth:", sys.get_call_depth())
level_a()
# Output: Top level depth: 2
#         Level A depth: 3
#         Level B depth: 4
```

**Use Cases:**
- **Debugging** - Monitor recursion depth in complex algorithms
- **Profiling** - Track call stack depth for performance analysis
- **Stack overflow prevention** - Check depth before deep recursion
- **Diagnostics** - Include call depth in error reports

**Example: Monitoring recursion depth**
```quest
fun factorial(n)
    if sys.get_call_depth() > 100
        puts("Warning: Deep recursion detected!")
    end

    if n <= 1
        return 1
    end
    return n * factorial(n - 1)
end

puts(factorial(50))
```

**Example: Stack depth in logs**
```quest
fun log(message)
    let depth = sys.get_call_depth()
    let indent = "  ".repeat(depth)
    puts(indent .. message)
end

fun process_data()
    log("Processing data")
    validate_input()
end

fun validate_input()
    log("Validating input")
end

log("Starting")
process_data()
# Output: Starting
#           Processing data
#             Validating input
```

**Notes:**
- Call depth includes the test framework's internal calls (typically 2-5 frames)
- Depth increases by 1 for each function call
- Depth is tracked independently from evaluation depth (internal)
- Useful for detecting potential stack overflow before it happens

### `sys.get_depth_limits()`

Get the configured recursion depth limits. Returns a Dict with three limit values that control maximum recursion depths.

**Parameters:** None

**Returns:** Dict with keys:
- `"function_calls"` (Int) - Maximum function call depth (default: 1000)
- `"eval_recursion"` (Int) - Maximum expression evaluation depth (default: 2000)
- `"module_loading"` (Int) - Maximum module loading nesting depth (default: 50)

**Example:**
```quest
use "std/sys"

let limits = sys.get_depth_limits()
puts("Function call limit:", limits["function_calls"])
puts("Eval recursion limit:", limits["eval_recursion"])
puts("Module loading limit:", limits["module_loading"])
# Output: Function call limit: 1000
#         Eval recursion limit: 2000
#         Module loading limit: 50
```

**Use Cases:**
- **Diagnostics** - Check configured limits when debugging recursion issues
- **Documentation** - Display limits to users
- **Validation** - Verify limits are appropriate for your use case
- **Pre-flight checks** - Ensure limits are sufficient before deep recursion

**Example: Check if recursion will exceed limits**
```quest
fun deep_recursion(n)
    let current_depth = sys.get_call_depth()
    let limits = sys.get_depth_limits()

    if current_depth + n > limits["function_calls"]
        puts("Warning: Recursion would exceed limit of", limits["function_calls"])
        return nil
    end

    # Safe to proceed
    if n > 0
        deep_recursion(n - 1)
    end
end

deep_recursion(500)  # Safe - well under 1000 limit
deep_recursion(1500)  # Warns about limit
```

**Example: Display system limits**
```quest
fun show_limits()
    let limits = sys.get_depth_limits()
    puts("=== Quest Recursion Limits ===")
    puts("Function calls:", limits["function_calls"])
    puts("Eval recursion:", limits["eval_recursion"])
    puts("Module loading:", limits["module_loading"])
end

show_limits()
# Output: === Quest Recursion Limits ===
#         Function calls: 1000
#         Eval recursion: 2000
#         Module loading: 50
```

**Limit Types Explained:**

1. **`function_calls`** (1000) - Maximum user-defined function call depth
   - Applies to Quest functions you define with `fun`
   - Does not include built-in methods or operators
   - Prevents infinite recursion in your code
   - Note: Currently returned but not enforced (QEP-048 Phase 1)

2. **`eval_recursion`** (2000) - Maximum internal expression evaluation depth
   - Internal limit for parser/evaluator recursion
   - Automatically managed by the interpreter
   - Prevents stack overflow from deeply nested expressions
   - Note: Currently returned but not enforced (QEP-048 Phase 1)

3. **`module_loading`** (50) - Maximum nested module import depth
   - Limits depth of `use` statements during module loading
   - Prevents circular or excessively deep module dependencies
   - A `use` within a `use` increases this counter
   - Note: Currently returned but not enforced (QEP-048 Phase 1)

**Modifying Limits:**

Limits are currently hardcoded in `src/modules/sys.rs`. Future versions may support runtime configuration or environment variables.

**Current Implementation Status (QEP-048 Phase 1):**

- ✅ Limits are defined and returned by `sys.get_depth_limits()`
- ✅ Depth tracking is implemented (accessible via `sys.get_call_depth()`)
- ❌ Limit enforcement is not yet implemented (no errors when exceeding limits)

Future phases may add enforcement that raises exceptions when limits are exceeded.

**Notes:**
- All limits are positive integers
- Default limits (1000/2000/50) are safe for most use cases
- To check current depth, use `sys.get_call_depth()` instead
- Limits are independent - exceeding one doesn't affect others

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
- **`sys.stdout`** - Standard output stream singleton (QEP-010)
- **`sys.stderr`** - Standard error stream singleton (QEP-010)
- **`sys.stdin`** - Standard input stream singleton (QEP-010)

**Functions:**
- **`sys.exit([code])`** - Exit program with status code
- **`sys.fail([message])`** - Raise an exception with optional message
- **`sys.load_module(path)`** - Dynamically load a module at runtime
- **`sys.eval(code)`** - Evaluate Quest code from a string (QEP-018)
- **`sys.redirect_stream(from, to)`** - Redirect stdout/stderr to files or buffers (QEP-010)
- **`sys.pid()`** - Get the current process ID
- **`sys.get_call_depth()`** - Get current function call depth (QEP-048)
- **`sys.get_depth_limits()`** - Get current recursion depth limits (QEP-048)

**Additional features:**
- **Relative imports** - Use `.` prefix to import files relative to current script

Use these properties and features to build flexible, portable, cross-platform Quest scripts!
