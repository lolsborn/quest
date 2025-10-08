# QEP-012: std/process - External Process Execution

**Status:** ✅ Implemented
**Author:** Quest Team
**Created:** 2025-10-05
**Completed:** 2025-10-07
**Module Name:** `std/process`

## Abstract

This QEP specifies the `std/process` module for executing external commands and managing subprocesses in Quest. The module provides a subprocess-style API with both simple run() for common cases and spawn() for advanced streaming scenarios, inspired by Python's subprocess, Rust's std::process, and Ruby's Process.

## Rationale

Running external commands is essential for:
- **System administration** - Executing shell commands, system utilities
- **Build systems** - Running compilers, linters, formatters
- **Data processing** - Piping data through external tools (grep, awk, jq)
- **Integration** - Calling other programs, scripts, binaries
- **Testing** - Running test suites, external validators
- **Automation** - Orchestrating workflows with multiple tools

Quest currently lacks a safe, cross-platform way to:
1. Execute external commands
2. Capture stdout/stderr separately
3. Write to stdin
4. Control environment and working directory
5. Handle timeouts and exit codes
6. Chain processes with pipes

Users must resort to shell scripts or workarounds, which is error-prone and insecure.

## Design Goals

1. **Security first** - No shell by default (avoid injection attacks)
2. **Simple API** - `run()` for 90% of use cases
3. **Powerful API** - `spawn()` for streaming, pipes, complex I/O
4. **Cross-platform** - Works on Unix, macOS, Windows
5. **Type-safe** - Clear error handling, no silent failures
6. **Pythonic** - Familiar to developers from Python subprocess
7. **Efficient** - Streaming I/O, no unnecessary buffering

## Why subprocess over popen

| Feature | popen | subprocess/process |
|---------|-------|-------------------|
| Security | Shell by default ⚠️ | No shell by default ✅ |
| stderr | Can't capture separately | Separate capture ✅ |
| stdin+stdout | Can't do both | Full bidirectional ✅ |
| Exit code | Only at close | Immediate access ✅ |
| Timeout | No support | Built-in ✅ |
| Environment | Limited | Full control ✅ |
| Modern | Deprecated | Standard pattern ✅ |

## API Design

### Simple API - process.run()

For quick command execution when you just need output:

```quest
use "std/process"

# Run command, get output
let result = process.run(["ls", "-la", "/tmp"])
puts(result.stdout)
puts("Exit code: " .. result.code.str())

# Check if successful
if result.success()
    puts("Command succeeded!")
end

# With options (passed as dict)
let result = process.run(["python", "script.py"], {
    "cwd": "/projects",
    "env": {"PYTHONPATH": "/libs"},
    "timeout": 30
})
```

**Returns:** ProcessResult with:
- `stdout` (Str) - Standard output as UTF-8 string
- `stderr` (Str) - Standard error as UTF-8 string
- `stdout_bytes` (Bytes) - Raw stdout bytes (for binary data)
- `stderr_bytes` (Bytes) - Raw stderr bytes (for binary data)
- `code` (Int) - Exit code (0 = success)
- `success()` (Bool) - True if exit code is 0

### Advanced API - process.spawn()

For streaming I/O, pipes, and complex scenarios:

```quest
use "std/process"

# Spawn process with pipes
let proc = process.spawn(["grep", "error"])

# Write to stdin
proc.stdin.write("line 1\n")
proc.stdin.write("line 2 with error\n")
proc.stdin.close()

# Read from stdout
let output = proc.stdout.read()
puts(output)

# Wait for completion
let code = proc.wait()
puts("Exit code: " .. code.str())
```

**Returns:** Process object with:
- `stdin` - WritableStream with methods:
  - `write(data: Str or Bytes) → Int` - Write to stdin, returns bytes written
  - `close() → Nil` - Close stdin (signals EOF to process)
  - `flush() → Nil` - Flush write buffer
- `stdout` - ReadableStream with methods:
  - `read() → Str` - Read all stdout as UTF-8 string
  - `read(n: Int) → Str` - Read up to n bytes as UTF-8 string
  - `read_bytes() → Bytes` - Read all stdout as raw bytes
  - `read_bytes(n: Int) → Bytes` - Read up to n bytes as raw bytes
  - `readline() → Str` - Read one line (including newline)
  - `readlines() → Array[Str]` - Read all lines as array
- `stderr` - ReadableStream (same methods as stdout)
- `wait() → Int` - Wait for process completion, return exit code
- `wait_with_timeout(seconds: Int) → Int or nil` - Wait with timeout, returns exit code or nil on timeout
- `communicate(input: Str or Bytes) → Dict` - Write input to stdin, close it, read all stdout/stderr, wait for completion. Returns `{"stdout": Str, "stderr": Str, "code": Int}`
- `kill() → Nil` - Terminate process forcefully (SIGKILL on Unix)
- `terminate() → Nil` - Gracefully terminate process (SIGTERM on Unix, TerminateProcess on Windows)
- `pid() → Int` - Get process ID
- `_enter() → Process` - Context manager entry (returns self)
- `_exit() → Nil` - Context manager exit (calls wait())

## Rust Implementation

**Primary API:** `std::process::Command` (Rust standard library, no dependencies)

**Key features:**
- Cross-platform (Unix, Windows, macOS)
- No shell by default (security)
- Full I/O control (stdin, stdout, stderr)
- Environment and working directory control
- Built-in timeout support (via wait_with_timeout)

**Implementation notes:**
- `run()` uses `Command::output()` - blocks until complete, captures all output
- `spawn()` uses `Command::spawn()` - returns immediately with piped I/O
- Automatic UTF-8 decoding for strings
- Raw bytes available via stdout_bytes/stderr_bytes if needed

## Complete Examples

### Example 1: Simple Command Execution

```quest
use "std/process"

# Run git status
let result = process.run(["git", "status", "--short"])

if result.success()
    puts("Modified files:")
    puts(result.stdout)
else
    puts("Git failed: " .. result.stderr)
end
```

### Example 2: Capture and Parse Output

```quest
use "std/process"
use "std/encoding/json"

# Get system info as JSON
let result = process.run(["sw_vers", "-json"])
let info = json.parse(result.stdout)
puts("macOS version: " .. info["ProductVersion"])
```

### Example 3: Pipeline (Filter Data)

```quest
use "std/process"

# Read file, filter with grep
let cat = process.spawn(["cat", "/var/log/system.log"])
let grep = process.spawn(["grep", "error"])

# Pipe cat stdout to grep stdin
let logs = cat.stdout.read()
grep.stdin.write(logs)
grep.stdin.close()

let filtered = grep.stdout.read()
puts(filtered)

cat.wait()
grep.wait()
```

### Example 4: Working Directory and Environment

```quest
use "std/process"

# Run npm install in project directory
let result = process.run(["npm", "install"], {
    "cwd": "/projects/myapp",
    "env": {
        "NODE_ENV": "production",
        "PATH": "/usr/local/bin:/usr/bin"
    }
})

if not result.success()
    puts("npm install failed:")
    puts(result.stderr)
end
```

### Example 5: Timeout Handling

```quest
use "std/process"

# Run command with timeout
try
    let result = process.run(["python", "slow_script.py"], {
        "timeout": 5  # 5 seconds
    })
    puts(result.stdout)
catch e
    if e.message().contains("timeout")
        puts("Command took too long!")
    else
        puts("Error: " .. e.message())
    end
end
```

### Example 6: Interactive Input/Output

```quest
use "std/process"

# Interactive process (e.g., REPLs, CLIs)
let proc = process.spawn(["python3", "-i"])

# Send commands
proc.stdin.write("print('Hello from Python')\n")
proc.stdin.write("2 + 2\n")
proc.stdin.write("exit()\n")
proc.stdin.close()

# Read output
let output = proc.stdout.read()
puts(output)

proc.wait()
```

### Example 7: Parallel Execution

```quest
use "std/process"

# Run multiple commands in parallel
let procs = [
    process.spawn(["task1.sh"]),
    process.spawn(["task2.sh"]),
    process.spawn(["task3.sh"])
]

# Wait for all to complete
let i = 0
while i < procs.len()
    let code = procs[i].wait()
    puts("Task " .. (i + 1).str() .. " finished with code " .. code.str())
    i = i + 1
end
```

### Example 8: Build System

```quest
use "std/process"

fun build_project(target)
    puts("Building " .. target .. "...")

    # Clean
    let clean = process.run(["make", "clean"])
    if not clean.success()
        raise "Clean failed"
    end

    # Build
    let build = process.run(["make", target], {
        "timeout": 300  # 5 minutes
    })

    if not build.success()
        puts("Build errors:")
        puts(build.stderr)
        raise "Build failed"
    end

    puts("Build successful!")
end

build_project("release")
```

### Example 9: Data Processing Pipeline

```quest
use "std/process"
use "std/io"

# Process CSV file through awk and sort
let awk = process.spawn(["awk", "-F,", "{print $2}"])
let sort = process.spawn(["sort"])
let uniq = process.spawn(["uniq", "-c"])

# Read CSV
let csv = io.read("data.csv")

# Pipeline: awk -> sort -> uniq
awk.stdin.write(csv)
awk.stdin.close()

let awk_out = awk.stdout.read()
sort.stdin.write(awk_out)
sort.stdin.close()

let sort_out = sort.stdout.read()
uniq.stdin.write(sort_out)
uniq.stdin.close()

let result = uniq.stdout.read()
puts("Unique values:")
puts(result)

# Wait for all
awk.wait()
sort.wait()
uniq.wait()
```

### Example 10: Error Handling

```quest
use "std/process"

fun safe_execute(command)
    try
        let result = process.run(command)

        if result.success()
            return result.stdout
        else
            puts("Command failed with code " .. result.code.str())
            puts("stderr: " .. result.stderr)
            return nil
        end
    catch e
        puts("Exception running command: " .. e.message())
        return nil
    end
end

let output = safe_execute(["ls", "/nonexistent"])
if output == nil
    puts("Command failed")
end
```

### Example 11: communicate() for Bidirectional I/O

```quest
use "std/process"

# Simple bidirectional communication
let proc = process.spawn(["grep", "pattern"])
let result = proc.communicate("line 1\nline 2 with pattern\nline 3\n")

puts("Matches:")
puts(result["stdout"])
puts("Exit code: " .. result["code"])

# With Python script
let proc = process.spawn(["python3", "-c", "import sys; print(sys.stdin.read().upper())"])
let result = proc.communicate("hello world")
puts(result["stdout"])  # "HELLO WORLD\n"
```

### Example 12: Context Manager (with statement)

```quest
use "std/process"
use "std/io"

# Automatic cleanup with 'with' statement
with process.spawn(["cat"]) as proc
    proc.stdin.write("Hello World\n")
    proc.stdin.close()
    let output = proc.stdout.read()
    puts(output)
end  # Automatically calls proc.wait()

# Multiple files with nested 'with'
with io.open("input.txt", "r") as input
    with process.spawn(["sort"]) as proc
        proc.stdin.write(input.read())
        proc.stdin.close()
        let sorted = proc.stdout.read()
        puts(sorted)
    end  # proc.wait() called
end  # input.close() called

# Exception safety - process still cleaned up
with process.spawn(["long-task"]) as proc
    proc.stdin.write("data")
    raise "Error occurred"
end  # proc.wait() still called!
```

## API Reference

### process.run(command, options?) → ProcessResult

Execute a command and wait for completion.

**Parameters:**
- `command` (Array[Str]) - Command and arguments (e.g., `["ls", "-la"]`)
- `options` (Dict, optional):
  - `cwd` (Str) - Working directory
  - `env` (Dict[Str, Str]) - Environment variables
  - `timeout` (Int) - Timeout in seconds
  - `stdin` (Str or Bytes) - Data to write to stdin

**Returns:** ProcessResult with:
- `stdout` (Str) - Standard output as UTF-8 string
- `stderr` (Str) - Standard error as UTF-8 string
- `stdout_bytes` (Bytes) - Raw stdout bytes
- `stderr_bytes` (Bytes) - Raw stderr bytes
- `code` (Int) - Exit code
- `success() → Bool` - True if exit code is 0

**Raises:**
- Error if command not found
- Error if timeout exceeded
- Error if I/O fails

**Examples:**
```quest
# Simple execution
let result = process.run(["echo", "hello"])
puts(result.stdout)  # "hello\n"

# With stdin data
let result = process.run(["grep", "error"], {
    "stdin": "line 1\nline 2 with error\nline 3\n"
})
puts(result.stdout)  # "line 2 with error\n"

# Binary output
let result = process.run(["cat", "image.png"])
let image_data = result.stdout_bytes  # Raw bytes
io.write("copy.png", image_data)
```

### process.spawn(command, options?) → Process

Spawn a process with piped I/O for streaming.

**Parameters:**
- `command` (Array[Str]) - Command and arguments
- `options` (Dict, optional):
  - `cwd` (Str) - Working directory
  - `env` (Dict[Str, Str]) - Environment variables

**Returns:** Process object with:
- `stdin` - WritableStream
  - `write(data: Str or Bytes)` - Write to stdin
  - `close()` - Close stdin (signals EOF)
- `stdout` - ReadableStream
  - `read()` - Read all stdout
  - `read(n)` - Read up to n bytes
  - `readline()` - Read one line
  - `readlines()` - Read all lines as array
- `stderr` - ReadableStream (same methods as stdout)
- `wait()` → Int - Wait for process, return exit code
- `wait_with_timeout(seconds: Int)` → Int or nil - Wait with timeout, nil on timeout
- `kill()` - Terminate process (SIGTERM on Unix, TerminateProcess on Windows)
- `pid()` → Int - Get process ID

**Example:**
```quest
let proc = process.spawn(["cat"])
proc.stdin.write("Hello\n")
proc.stdin.close()
let output = proc.stdout.read()
proc.wait()
```

### process.shell(command, options?) → ProcessResult

**⚠️ DANGEROUS - Use only for trusted input**

Execute command through system shell. Vulnerable to injection attacks.

**Parameters:**
- `command` (Str) - Shell command string
- `options` (Dict, optional) - Same as run()

**Returns:** ProcessResult (same as run())

**Security Warning:**
```quest
# ❌ NEVER DO THIS with user input
let user_input = "test; rm -rf /"
let result = process.shell("cat " .. user_input)  # DANGEROUS!

# ✅ DO THIS instead
let result = process.run(["cat", user_input])  # Safe
```

Use `shell()` only when:
1. Command contains shell features (pipes, redirects, globs)
2. Input is 100% trusted (no user data)
3. You understand the security implications

**Example (safe):**
```quest
# Shell features needed
let result = process.shell("ls *.txt | wc -l")
```

### process.check_run(command, options?) → Str

Execute command and return stdout, raising error on non-zero exit.

**Parameters:**
- `command` (Array[Str]) - Command and arguments
- `options` (Dict, optional) - Same as `run()`

**Returns:** stdout as Str

**Raises:**
- Error if exit code is not 0 (exception includes stdout, stderr, and exit code)
- Error if command not found
- Error if timeout exceeded

**Example:**
```quest
use "std/process"

# Returns stdout directly if successful
let output = process.check_run(["ls", "/tmp"])
puts(output)

# Raises on failure
try
    let output = process.check_run(["ls", "/nonexistent"])
catch e
    puts("Command failed with code " .. e.code)
    puts("stderr: " .. e.stderr)
end
```

**Use case:** When you expect command to succeed and want to fail-fast on errors.

### process.pipeline(commands) → ProcessResult

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

puts("Error lines: " .. result.stdout.trim())

# More complex pipeline
let result = process.pipeline([
    ["find", ".", "-name", "*.q"],
    ["xargs", "wc", "-l"],
    ["sort", "-n"],
    ["tail", "-5"]
])
puts("Top 5 largest files:\n" .. result.stdout)
```

**Implementation note:** Creates all processes with piped stdin/stdout, connects them, waits for all to complete.

## Security Considerations

### Command Injection Prevention

**Always use array form, never concatenate strings:**

```quest
# ✅ SAFE - Arguments are properly escaped
let file = user_input
let result = process.run(["grep", "pattern", file])

# ❌ DANGEROUS - Shell injection possible
let result = process.shell("grep pattern " .. user_input)
```

**Why arrays are safe:**
- Arguments passed directly to execve() (Unix) or CreateProcess() (Windows)
- No shell interpretation
- Special characters are literal data

### Path Safety

```quest
# ✅ Use absolute paths for security-critical commands
let result = process.run(["/usr/bin/sudo", "ls"])

# ⚠️ Relies on PATH environment variable
let result = process.run(["sudo", "ls"])
```

### Environment Variable Isolation

```quest
# ✅ Explicit environment (inherits nothing)
let result = process.run(["python", "script.py"], {
    "env": {"PATH": "/usr/bin", "LANG": "en_US.UTF-8"}
})

# ⚠️ Inherits all environment variables
let result = process.run(["python", "script.py"])
```

## Error Handling

### Exit Codes

```quest
let result = process.run(["grep", "pattern", "file.txt"])

# grep exit codes:
# 0 = found
# 1 = not found
# 2 = error

if result.code == 0
    puts("Pattern found")
elif result.code == 1
    puts("Pattern not found")
else
    puts("Error: " .. result.stderr)
end
```

### Exceptions

```quest
try
    let result = process.run(["nonexistent-command"])
catch e
    # Command not found, permission denied, etc.
    puts("Error: " .. e.message())
end
```

### Timeout Handling

```quest
try
    let result = process.run(["long-running-task"], {"timeout": 10})
catch e
    if e.message().contains("timeout")
        puts("Task took too long")
    end
end
```

## Cross-Platform Considerations

### Command Differences

```quest
use "std/sys"
use "std/process"

# Platform-specific commands
let cmd = if sys.platform == "win32"
    ["dir", "/B"]
else
    ["ls"]
end

let result = process.run(cmd)
```

### Path Separators

```quest
use "std/process"

# Use forward slashes (works on all platforms)
let result = process.run(["python", "scripts/build.py"], {
    "cwd": "projects/myapp"
})
```

### Line Endings

```quest
# Windows uses \r\n, Unix uses \n
let result = process.run(["some-command"])
let lines = result.stdout.split("\n")

# Or use readlines() which handles it
let proc = process.spawn(["some-command"])
let lines = proc.stdout.readlines()
```

## Performance Tips

### Avoid Shell When Possible

```quest
# ❌ Slow (spawns shell)
process.shell("ls -la")

# ✅ Fast (direct execution)
process.run(["ls", "-la"])
```

### Streaming for Large Data

```quest
# ❌ Buffers entire output in memory
let result = process.run(["find", "/", "-name", "*.txt"])

# ✅ Stream output line by line
let proc = process.spawn(["find", "/", "-name", "*.txt"])
while true
    let line = proc.stdout.readline()
    if line == nil
        break
    end
    puts(line)
end
```

### Parallel Execution

```quest
# ✅ Run multiple tasks in parallel
let tasks = [
    process.spawn(["task1"]),
    process.spawn(["task2"]),
    process.spawn(["task3"])
]

# Do other work while tasks run...

# Wait for all
tasks.each(fun (proc) proc.wait() end)
```

## Process Cleanup and Resource Management

### Automatic Cleanup Behavior

**Process objects must be explicitly waited on or cleaned up:**

```quest
# ❌ BAD: Process becomes zombie if not waited on
let proc = process.spawn(["command"])
proc.stdin.write("data")
# ... forget to call proc.wait() ...
# Process remains as zombie until Quest exits

# ✅ GOOD: Always wait or use context manager
let proc = process.spawn(["command"])
try
    proc.stdin.write("data")
ensure
    proc.wait()  # Cleanup
end

# ✅ BEST: Use context manager (automatic)
with process.spawn(["command"]) as proc
    proc.stdin.write("data")
end  # Automatic proc.wait()
```

### Finalizer Behavior

If a Process object is garbage collected without calling `wait()`:
- **Unix/macOS**: Child process becomes a zombie until Quest exits
- **Windows**: Child process continues running as detached process

**Recommendation:** Always call `wait()` explicitly or use `with` statement.

### Signal Handling

**`proc.terminate()`** - Graceful shutdown (SIGTERM on Unix)
```quest
let proc = process.spawn(["long-running-task"])
# ... give it some time ...
proc.terminate()  # Ask nicely to stop
let code = proc.wait_with_timeout(5)
if code == nil
    proc.kill()  # Force kill if it didn't stop
end
```

**`proc.kill()`** - Forceful termination (SIGKILL on Unix)
```quest
let proc = process.spawn(["stuck-process"])
proc.kill()  # Immediate termination
proc.wait()  # Reap zombie
```

## Buffering Behavior

### stdout/stderr Buffering

**Default behavior (from child process perspective):**
- **stdout**: Line-buffered when connected to terminal, fully buffered when piped
- **stderr**: Unbuffered (flushes immediately)

**Impact on Quest:**
```quest
# Process with line-buffered stdout
let proc = process.spawn(["python", "-u", "script.py"])  # -u for unbuffered
let line = proc.stdout.readline()  # May block if script doesn't flush
```

**Solutions:**
1. Use `communicate()` which reads all output at once
2. Ensure child process flushes output explicitly
3. Use unbuffered mode in child (e.g., `python -u`, `stdbuf -o0`)

### Quest's Read Buffering

**`read()` blocks until:**
- EOF reached (process closes stdout)
- Requested byte count fulfilled

**`readline()` blocks until:**
- Newline found
- EOF reached

**Best practices:**
```quest
# ✅ For processes that produce all output then exit
let proc = process.spawn(["command"])
let output = proc.stdout.read()  # Blocks until command finishes
proc.wait()

# ✅ For line-oriented output
let proc = process.spawn(["tail", "-f", "log.txt"])
while true
    let line = proc.stdout.readline()
    if line == ""
        break
    end
    process_line(line)
end

# ❌ DON'T: read() on never-ending output
let proc = process.spawn(["tail", "-f", "log.txt"])
let output = proc.stdout.read()  # Blocks forever!
```

## Stream Type Definitions

### ReadableStream

Object returned by `proc.stdout` and `proc.stderr`.

**Methods:**
- `read() → Str` - Read all available data as UTF-8 string (blocks until EOF)
- `read(n: Int) → Str` - Read up to n bytes as UTF-8 string
- `read_bytes() → Bytes` - Read all available data as raw bytes (blocks until EOF)
- `read_bytes(n: Int) → Bytes` - Read up to n bytes as raw bytes
- `readline() → Str` - Read one line including newline (blocks until `\n` or EOF)
- `readlines() → Array[Str]` - Read all lines (blocks until EOF)

**Blocking behavior:**
- All read methods block until data is available
- `read()` without size blocks until EOF
- `readline()` blocks until newline or EOF
- Returns empty string at EOF

### WritableStream

Object returned by `proc.stdin`.

**Methods:**
- `write(data: Str or Bytes) → Int` - Write data, returns bytes written
- `writelines(lines: Array[Str]) → Nil` - Write multiple lines
- `flush() → Nil` - Flush write buffer to child process
- `close() → Nil` - Close stream (signals EOF to child)

**Behavior:**
- Writes may block if pipe buffer is full
- `close()` is important - signals EOF to child process
- After `close()`, writes will fail

## Implementation Checklist

### Core Types
- [ ] Create `src/modules/process.rs`
- [ ] ProcessResult type:
  - [ ] `stdout`, `stderr` (Str)
  - [ ] `stdout_bytes`, `stderr_bytes` (Bytes)
  - [ ] `code` (Int)
  - [ ] `success()` method
- [ ] Process type:
  - [ ] `stdin` (WritableStream)
  - [ ] `stdout`, `stderr` (ReadableStream)
  - [ ] `wait()`, `wait_with_timeout()` methods
  - [ ] `communicate()` method
  - [ ] `kill()`, `terminate()` methods
  - [ ] `pid()` method
  - [ ] `_enter()`, `_exit()` context manager methods
- [ ] ReadableStream type:
  - [ ] `read()`, `read(n)` for UTF-8 strings
  - [ ] `read_bytes()`, `read_bytes(n)` for raw bytes
  - [ ] `readline()`, `readlines()`
- [ ] WritableStream type:
  - [ ] `write()` for Str or Bytes
  - [ ] `writelines()`
  - [ ] `flush()`, `close()`

### API Functions
- [ ] `process.run(command, options?)` - blocks until complete
- [ ] `process.spawn(command, options?)` - returns Process object
- [ ] `process.shell(command, options?)` - shell execution (dangerous)
- [ ] `process.check_run(command, options?)` - raises on non-zero exit
- [ ] `process.pipeline(commands)` - multi-stage pipeline

### Options Support
- [ ] `cwd` (Str) - Working directory
- [ ] `env` (Dict[Str, Str]) - Environment variables
- [ ] `timeout` (Int) - Timeout in seconds for `run()`
- [ ] `stdin` (Str or Bytes) - Input data for `run()`

### Platform Support
- [ ] Unix/Linux support
- [ ] macOS support
- [ ] Windows support
- [ ] Cross-platform testing
- [ ] Platform-specific error messages

### Error Handling
- [ ] Command not found errors
- [ ] Permission denied errors
- [ ] Timeout errors
- [ ] I/O errors (broken pipe, etc.)
- [ ] UTF-8 decoding errors

### Documentation
- [ ] `lib/std/process.q` - Module documentation
- [ ] Security best practices
- [ ] Buffering behavior documentation
- [ ] Resource cleanup documentation
- [ ] Cross-platform considerations

### Testing
- [ ] `test/process/run_test.q` - process.run() tests
- [ ] `test/process/spawn_test.q` - process.spawn() tests
- [ ] `test/process/communicate_test.q` - communicate() tests
- [ ] `test/process/pipeline_test.q` - pipeline() tests
- [ ] `test/process/context_test.q` - context manager tests
- [ ] `test/process/timeout_test.q` - timeout handling
- [ ] `test/process/errors_test.q` - error handling
- [ ] `test/process/security_test.q` - injection prevention tests

## Future Enhancements

### Process Pools (QEP-013)

```quest
# Parallel task execution with worker pool
let pool = process.Pool.new({"workers": 4})
let results = pool.map(files, fun (file)
    process.run(["process_file", file])
end)
pool.close()
pool.join()  # Wait for all workers
```

### Async Process Execution (QEP-014)

```quest
# Non-blocking process execution
let task1 = process.run_async(["task1"])
let task2 = process.run_async(["task2"])

# Do other work...

let result1 = task1.await()
let result2 = task2.await()
```

### Advanced Pipe Operators (QEP-015)

```quest
# Language-level pipe operator
let count = process.run(["cat", "file.txt"])
    | process.run(["grep", "error"])
    | process.run(["wc", "-l"])

puts(count.stdout.trim())
```

## Related QEPs

- **QEP-011**: File Objects - File objects also support context managers, same pattern as Process
- **QEP-010**: I/O Redirection - Process stdout/stderr can be redirected
- **QEP-009**: StringIO - Can be used as process stdin/stdout targets

## Conclusion

The `std/process` module provides safe, powerful subprocess execution for Quest with a comprehensive API covering simple commands to complex pipelines.

**Key features:**
- **Security first** - No shell by default prevents injection attacks
- **Multiple APIs** - `run()` for simplicity, `spawn()` for control, `pipeline()` for chaining
- **Convenience methods** - `check_run()` for fail-fast, `communicate()` for bidirectional I/O
- **Context managers** - Automatic cleanup with `with` statements
- **Binary support** - `stdout_bytes` / `stderr_bytes` for non-UTF-8 data
- **Streaming** - Memory-efficient line-by-line and chunked reading
- **Cross-platform** - Works on Unix, macOS, Windows

**Design highlights:**
- Options passed as Dict (Quest convention, not keyword args)
- Explicit resource management with `try/ensure` or `with` blocks
- Clear separation between simple (`run`) and advanced (`spawn`) APIs
- Comprehensive error handling with specific error types
- Well-documented buffering and cleanup behavior

**Security model:**
- Default is safe (no shell, array arguments)
- `shell()` clearly marked as dangerous
- Strong documentation on injection prevention
- Examples show safe patterns

This QEP provides everything needed for Quest to integrate seamlessly with external tools while maintaining safety and ergonomics.

## References

- Python subprocess: https://docs.python.org/3/library/subprocess.html
- Rust std::process: https://doc.rust-lang.org/std/process/
- Ruby Process: https://ruby-doc.org/core/Process.html
- Node.js child_process: https://nodejs.org/api/child_process.html
