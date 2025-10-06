# Process - External Command Execution

The process module enables safe, cross-platform execution of external commands and subprocess management, similar to Python's subprocess module.

## Import

```quest
use "std/process"
```

## Quick Start

```quest
use "std/process"

# Simple command execution
let result = process.run(["ls", "-la"])
if result.success()
    puts(result.stdout())
end

# Streaming with spawn
let proc = process.spawn(["grep", "error"])
proc.stdin.write("line 1\nerror in line 2\n")
proc.stdin.close()
let matches = proc.stdout.read()
proc.wait()
```

## Security First

**⚠️ IMPORTANT:** Quest uses array-based arguments by default, preventing shell injection attacks:

```quest
# ✅ SAFE - Arguments properly escaped
let file = user_input
process.run(["cat", file])

# ❌ DANGEROUS - Don't concatenate user input into shell commands
process.shell("cat " .. user_input)  # Vulnerable to injection!
```

## Module Functions

### `process.run(command, options?)`

Execute a command and wait for completion. Captures all output.

**Parameters:**
- `command` (Array[Str]) - Command and arguments, e.g., `["ls", "-la", "/tmp"]`
- `options` (Dict, optional):
  - `cwd` (Str) - Working directory
  - `env` (Dict[Str, Str]) - Environment variables
  - `timeout` (Int or Float) - Timeout in seconds
  - `stdin` (Str or Bytes) - Data to send to stdin

**Returns:** ProcessResult object with:
- `stdout()` → Str - Standard output as UTF-8 string
- `stderr()` → Str - Standard error as UTF-8 string
- `stdout_bytes()` → Bytes - Raw stdout bytes (for binary data)
- `stderr_bytes()` → Bytes - Raw stderr bytes
- `code()` → Int - Exit code (0 = success)
- `success()` → Bool - True if exit code is 0

**Example:**
```quest
use "std/process"

# Basic execution
let result = process.run(["git", "status", "--short"])
if result.success()
    puts("Git status:")
    puts(result.stdout())
else
    puts("Git failed:", result.stderr())
end

# With options
let result = process.run(
    ["npm", "install"],
    {
        "cwd": "/projects/myapp",
        "env": {"NODE_ENV": "production"},
        "timeout": 300
    }
)

# With stdin
let result = process.run(
    ["grep", "pattern"],
    {"stdin": "line 1\nline 2 with pattern\n"}
)
puts(result.stdout())
```

**ProcessResult Truthiness:**
```quest
let result = process.run(["test", "-f", "file.txt"])
if result
    puts("File exists (exit code 0)")
else
    puts("File doesn't exist (non-zero exit)")
end
```

### `process.spawn(command, options?)`

Spawn a process with piped I/O for streaming and interactive use.

**Parameters:**
- `command` (Array[Str]) - Command and arguments
- `options` (Dict, optional):
  - `cwd` (Str) - Working directory
  - `env` (Dict[Str, Str]) - Environment variables

**Returns:** Process object with:
- `stdin` (WritableStream) - Write to process stdin
- `stdout` (ReadableStream) - Read from process stdout
- `stderr` (ReadableStream) - Read from process stderr
- `wait()` → Int - Wait for completion, return exit code
- `wait_with_timeout(seconds)` → Int or nil - Wait with timeout, nil on timeout
- `communicate(input)` → Dict - Write input, read output, wait for completion
- `kill()` - Terminate process forcefully (SIGKILL)
- `terminate()` - Terminate gracefully (SIGTERM on Unix)
- `pid()` → Int - Get process ID

**Example:**
```quest
use "std/process"

# Streaming I/O
let proc = process.spawn(["sort"])
proc.stdin.write("zebra\napple\nmango\n")
proc.stdin.close()
let sorted = proc.stdout.read()
puts(sorted)
proc.wait()

# Interactive process
let proc = process.spawn(["python3", "-i"])
proc.stdin.write("print('Hello from Python')\n")
proc.stdin.write("2 + 2\n")
proc.stdin.write("exit()\n")
proc.stdin.close()
puts(proc.stdout.read())
proc.wait()
```

### `process.check_run(command, options?)`

Execute command and return stdout, raising error on non-zero exit. Fail-fast pattern for scripts.

**Parameters:**
- `command` (Array[Str]) - Command and arguments
- `options` (Dict, optional) - Same as `run()`

**Returns:** Str - stdout on success

**Raises:** Error with stdout/stderr details on non-zero exit

**Example:**
```quest
use "std/process"

# Returns stdout if successful
let output = process.check_run(["git", "rev-parse", "HEAD"])
puts("Current commit:", output.trim())

# Raises error on failure
try
    process.check_run(["make", "build"])
catch e
    puts("Build failed:", e.message())
    sys.exit(1)
end
```

### `process.shell(command, options?)`

**⚠️ DANGEROUS** - Execute command through system shell.

**Security Warning:** Vulnerable to command injection. Only use with fully trusted input.

**Parameters:**
- `command` (Str) - Shell command string
- `options` (Dict, optional) - Same as `run()`

**Returns:** ProcessResult

**Example:**
```quest
use "std/process"

# Only use with trusted, hardcoded commands
let result = process.shell("ls *.txt | wc -l")
puts("Text files:", result.stdout().trim())

# ❌ NEVER with user input
let user_file = get_user_input()
process.shell("cat " .. user_file)  # DANGEROUS!

# ✅ Use this instead
process.run(["cat", user_file])  # Safe
```

### `process.pipeline(commands)`

Execute multiple commands in a pipeline (stdout of each feeds stdin of next).

**Parameters:**
- `commands` (Array[Array[Str]]) - Array of command arrays

**Returns:** ProcessResult with output of final command

**Example:**
```quest
use "std/process"

# Equivalent to: cat file.txt | grep error | wc -l
let result = process.pipeline([
    ["cat", "file.txt"],
    ["grep", "error"],
    ["wc", "-l"]
])
puts("Error lines:", result.stdout().trim())

# Complex pipeline
let result = process.pipeline([
    ["find", ".", "-name", "*.q"],
    ["xargs", "wc", "-l"],
    ["sort", "-n"],
    ["tail", "-5"]
])
puts("5 largest files:")
puts(result.stdout())
```

## Process Object

Returned by `process.spawn()` for streaming subprocess control.

### Stream Access

Access streams as properties:

```quest
let proc = process.spawn(["cat"])
proc.stdin.write("data")
proc.stdin.close()
let output = proc.stdout.read()
```

### Methods

#### `wait()`

Wait for process to complete and return exit code.

```quest
let proc = process.spawn(["command"])
# ... interact with process ...
let code = proc.wait()
puts("Exited with code:", code)
```

#### `wait_with_timeout(seconds)`

Wait with timeout. Returns exit code or nil on timeout.

```quest
let proc = process.spawn(["long-task"])
let code = proc.wait_with_timeout(30)
if code == nil
    puts("Timed out!")
    proc.kill()
else
    puts("Completed with code:", code)
end
```

#### `communicate(input)`

Write input to stdin, close it, read stdout/stderr, and wait for completion.

```quest
let proc = process.spawn(["grep", "pattern"])
let result = proc.communicate("line 1\nline 2\n")
puts("stdout:", result["stdout"])
puts("stderr:", result["stderr"])
puts("code:", result["code"])
```

#### `kill()`

Forcefully terminate the process (SIGKILL on Unix, TerminateProcess on Windows).

```quest
let proc = process.spawn(["stuck-process"])
proc.kill()
proc.wait()
```

#### `terminate()`

Gracefully request process termination (SIGTERM on Unix).

```quest
let proc = process.spawn(["server"])
proc.terminate()  # Ask nicely
let code = proc.wait_with_timeout(5)
if code == nil
    proc.kill()  # Force kill if it didn't stop
end
```

#### `pid()`

Get the process ID.

```quest
let proc = process.spawn(["command"])
puts("Process ID:", proc.pid())
```

### Context Manager

Process objects support the `with` statement for automatic cleanup:

```quest
with process.spawn(["cat"]) as proc
    proc.stdin.write("data")
    proc.stdin.close()
    let output = proc.stdout.read()
    puts(output)
end  # Automatically calls proc.wait()

# Exception-safe cleanup
with process.spawn(["task"]) as proc
    proc.stdin.write("data")
    raise "Error!"
end  # proc.wait() still called!
```

## WritableStream (stdin)

Stream for writing to process stdin.

### Methods

#### `write(data)`

Write string or bytes to stdin.

**Returns:** Int - Number of bytes written

```quest
proc.stdin.write("text data")
proc.stdin.write(b"\xFF\x00")  # Binary data
```

#### `writelines(lines)`

Write multiple lines from an array.

```quest
proc.stdin.writelines(["line1\n", "line2\n", "line3\n"])
```

#### `close()`

Close stdin stream (signals EOF to process).

```quest
proc.stdin.close()
```

#### `flush()`

Flush write buffer to process.

```quest
proc.stdin.flush()
```

## ReadableStream (stdout/stderr)

Stream for reading from process output.

### Methods

#### `read()` / `read(n)`

Read all output as UTF-8 string, or read up to n bytes.

```quest
let all = proc.stdout.read()        # Read all
let chunk = proc.stdout.read(1024)  # Read up to 1024 bytes
```

#### `read_bytes()` / `read_bytes(n)`

Read as raw bytes.

```quest
let data = proc.stdout.read_bytes()      # All bytes
let chunk = proc.stdout.read_bytes(100)  # First 100 bytes
```

#### `readline()`

Read one line (including newline character).

```quest
let line = proc.stdout.readline()
# Returns "" at EOF
```

#### `readlines()`

Read all lines as an array.

```quest
let lines = proc.stdout.readlines()
for line in lines
    puts("Line:", line.trim())
end
```

## Common Patterns

### Check Command Success

```quest
let result = process.run(["make", "test"])
if result.success()
    puts("Tests passed!")
else
    puts("Tests failed with code", result.code())
    puts(result.stderr())
    sys.exit(1)
end
```

### Capture and Parse JSON

```quest
use "std/process"
use "std/encoding/json"

let result = process.run(["gh", "api", "/user"])
let user = json.parse(result.stdout())
puts("Username:", user["login"])
```

### Pipeline Data Processing

```quest
# Count unique values in CSV column
let result = process.pipeline([
    ["cut", "-d,", "-f2", "data.csv"],
    ["sort"],
    ["uniq", "-c"]
])
puts(result.stdout())
```

### Long-Running Task with Timeout

```quest
let proc = process.spawn(["database-backup.sh"])
let code = proc.wait_with_timeout(3600)  # 1 hour

if code == nil
    puts("Backup timed out!")
    proc.terminate()
    proc.wait_with_timeout(30)  # Grace period
    proc.kill()  # Force kill if needed
    sys.exit(1)
elif code != 0
    puts("Backup failed with code", code)
    sys.exit(code)
else
    puts("Backup completed successfully")
end
```

### Interactive Process

```quest
let proc = process.spawn(["python3"])
proc.stdin.writelines([
    "import math\n",
    "print(math.pi)\n",
    "print(math.sqrt(16))\n",
    "exit()\n"
])
proc.stdin.close()
puts(proc.stdout.read())
proc.wait()
```

### Parallel Execution

```quest
# Run multiple tasks in parallel
let tasks = [
    process.spawn(["task1.sh"]),
    process.spawn(["task2.sh"]),
    process.spawn(["task3.sh"])
]

# Do other work while tasks run...

# Wait for all
let i = 0
while i < tasks.len()
    let code = tasks[i].wait()
    puts("Task", i + 1, "finished with code", code)
    i = i + 1
end
```

### Build System

```quest
use "std/process"

fun build_project(target)
    puts("Cleaning...")
    process.check_run(["make", "clean"])

    puts("Building", target .. "...")
    try
        let output = process.check_run(
            ["make", target],
            {"timeout": 600}
        )
        puts("Build successful!")
        return true
    catch e
        puts("Build failed:")
        puts(e.message())
        return false
    end
end

if not build_project("release")
    sys.exit(1)
end
```

## Error Handling

### Command Not Found

```quest
try
    process.run(["nonexistent-command"])
catch e
    if e.message().contains("No such file")
        puts("Command not found")
    end
end
```

### Timeout Handling

```quest
try
    process.run(["slow-task"], {"timeout": 30})
catch e
    if e.message().contains("timeout")
        puts("Task took too long!")
    end
end
```

### Exit Code Checking

```quest
let result = process.run(["grep", "pattern", "file.txt"])

# grep exit codes:
# 0 = found, 1 = not found, 2 = error
if result.code() == 0
    puts("Pattern found")
elif result.code() == 1
    puts("Pattern not found")
else
    puts("Grep error:", result.stderr())
end
```

## Cross-Platform Support

### Platform-Specific Commands

```quest
use "std/sys"
use "std/process"

let cmd = if sys.platform == "win32"
    ["dir", "/B"]
else
    ["ls"]
end

let result = process.run(cmd)
puts(result.stdout())
```

### Path Handling

```quest
# Use forward slashes (works on all platforms)
let result = process.run(
    ["python", "scripts/build.py"],
    {"cwd": "projects/myapp"}
)
```

## Advanced Examples

### Data Pipeline

```quest
use "std/process"
use "std/io"

# Process log files
let result = process.pipeline([
    ["cat", "access.log"],
    ["grep", "ERROR"],
    ["awk", "{print $1}"],
    ["sort"],
    ["uniq", "-c"],
    ["sort", "-rn"],
    ["head", "-10"]
])

puts("Top 10 error sources:")
puts(result.stdout())
```

### Two-Way Communication

```quest
# Send data, get processed result
let proc = process.spawn(["awk", "{print toupper($0)}"])
let result = proc.communicate("convert this to uppercase\n")
puts(result["stdout"])  # "CONVERT THIS TO UPPERCASE"
```

### Resource Cleanup

```quest
# Manual cleanup
let proc = process.spawn(["task"])
try
    proc.stdin.write("data")
    let output = proc.stdout.read()
ensure
    proc.wait()  # Always cleanup
end

# Automatic with 'with' statement (recommended)
with process.spawn(["task"]) as proc
    proc.stdin.write("data")
    let output = proc.stdout.read()
end  # Auto cleanup
```

## Best Practices

### 1. Always Use Array Arguments

```quest
# ✅ Safe
process.run(["rm", filename])

# ❌ Unsafe - Use only with trusted input
process.shell("rm " .. filename)
```

### 2. Always Wait for Processes

```quest
# ✅ Good - explicit wait
let proc = process.spawn(["task"])
try
    # ... work with process ...
ensure
    proc.wait()
end

# ✅ Better - context manager
with process.spawn(["task"]) as proc
    # ... work with process ...
end  # Auto wait
```

### 3. Handle Timeouts

```quest
# ✅ Prevent hangs
let result = process.run(
    ["external-service"],
    {"timeout": 30}
)
```

### 4. Check Exit Codes

```quest
# ✅ Explicit checking
let result = process.run(["critical-task"])
if not result.success()
    puts("Task failed:", result.stderr())
    sys.exit(result.code())
end

# ✅ Fail-fast pattern
try
    process.check_run(["critical-task"])
catch e
    puts("Task failed:", e.message())
    sys.exit(1)
end
```

### 5. Close Stdin When Done

```quest
# ✅ Signal EOF
proc.stdin.write("data")
proc.stdin.close()  # Important!
let output = proc.stdout.read()  # Won't block
```

## Performance Tips

### Streaming for Large Data

```quest
# ❌ Buffers entire output in memory
let result = process.run(["find", "/", "-name", "*.txt"])

# ✅ Stream line by line
let proc = process.spawn(["find", "/", "-name", "*.txt"])
proc.stdin.close()
while true
    let line = proc.stdout.readline()
    if line == ""
        break
    end
    process_line(line)
end
proc.wait()
```

### Parallel Execution

```quest
# ✅ Run tasks in parallel
let procs = [
    process.spawn(["task1"]),
    process.spawn(["task2"]),
    process.spawn(["task3"])
]

# Do other work...

# Wait for all
procs.each(fun (p) p.wait() end)
```

## Limitations and Notes

- **Zombie processes**: Processes must be waited on or they become zombies (Unix/macOS)
- **Buffering**: Child processes may buffer output - use unbuffered mode if needed
- **Blocking**: `read()` blocks until EOF - use `readline()` for line-by-line
- **Windows**: Some Unix-specific features behave differently (signals, exit codes)
- **Shell features**: For pipes/redirects/globs, use `pipeline()` or `shell()` (carefully)

## See Also

- **[io](./io.md)** - File I/O operations
- **[sys](./sys.md)** - System information and exit()
- **[os](./os.md)** - Operating system interfaces
