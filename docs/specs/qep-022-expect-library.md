# QEP-022: Expect Library for Interactive Program Automation

**Status**: Proposed
**Created**: 2025-10-05
**Author**: Claude Code

## Summary

Proposes a `std/process/expect` module for automating interactions with interactive programs (shells, CLIs, SSH sessions, etc.) inspired by Tcl's Expect and Python's pexpect.

## Motivation

Many systems require interaction with programs that:
- Prompt for user input (passwords, confirmations, menus)
- Don't provide API interfaces (legacy tools, system utilities)
- Require terminal control (text UIs, progress indicators)
- Need automated testing of CLI interfaces

Current workarounds are fragile (piping stdin) or impossible (password prompts). An expect library enables robust automation of interactive programs.

## Design

### Core API

```quest
use "std/process/expect"

# Basic usage
let session = expect.spawn("ssh user@host")
session.expect("Password:")
session.send_line("secret123")
session.expect("$ ")
session.send_line("ls -la")
let output = session.expect("$ ")
session.close()

# Pattern matching
session.expect([
    ["Password:", fun (match) session.send_line("secret") end],
    ["Key fingerprint", fun (match) session.send_line("yes") end],
    ["Permission denied", fun (match) raise "Auth failed" end]
])

# Timeout control
session.expect("prompt", timeout: 5)  # 5 seconds
session.expect("prompt", timeout: nil)  # Wait forever
```

### Session Object

```quest
type ExpectSession
    # Properties
    int: pid              # Process ID
    bool: is_alive        # Process running?
    str: before           # Text before last match
    str: after            # Text after last match (includes match)
    str: match            # Last matched pattern

    # Core methods
    fun expect(pattern, timeout: 30)
        # pattern: str (literal) or regex or array of [pattern, callback]
        # Returns: matched text (str) or calls callback
        # Raises: TimeoutError, EOFError
    end

    fun send(text)
        # Send text without newline
    end

    fun send_line(text)
        # Send text with newline
    end

    fun send_control(char)
        # Send control character: 'c' for Ctrl-C, 'd' for Ctrl-D
    end

    fun read_nonblocking(size: 1024, timeout: 0)
        # Read available bytes without blocking
    end

    fun expect_exact(text, timeout: 30)
        # Literal string match (no regex)
    end

    fun expect_eof(timeout: 30)
        # Wait for process to exit
        # Returns: exit status (int)
    end

    fun close(force: false)
        # Close session gracefully (SIGTERM) or forcefully (SIGKILL)
        # Returns: exit status (int) or nil if already closed
    end

    fun interact()
        # Give control to user (interactive mode)
        # Useful for debugging: automation up to point, then manual
    end

    # Logging
    fun log_file(path, append: false)
        # Log all I/O to file
    end
end
```

### Module Functions

```quest
# Spawn new process
expect.spawn(command, timeout: 30, encoding: "utf-8", env: nil, cwd: nil)
    # Returns: ExpectSession

# Spawn with PTY dimensions
expect.spawn(command, rows: 24, cols: 80, timeout: 30)

# Run simple automation
expect.run(command, events, timeout: 30)
    # events: array of [pattern, response] pairs
    # Returns: full output (str)

# Example:
let output = expect.run("sudo apt update", [
    ["password", "mypass\n"],
    ["Continue?", "y\n"]
])
```

### Pattern Types

1. **String literals**: Exact substring match
2. **Regex objects**: `expect.expect(regex.compile(r"\d+ files"))`
3. **Special matchers**:
   - `expect.EOF` - Process terminated
   - `expect.TIMEOUT` - Timeout occurred (for array patterns)

```quest
session.expect([
    [expect.EOF, fun (m) puts("Process ended") end],
    [expect.TIMEOUT, fun (m) puts("Timed out") end],
    ["Ready", fun (m) session.send_line("go") end]
])
```

### Error Handling

```quest
trait ExpectError extends Exception end

type TimeoutError
    impl ExpectError
        str: pattern
        int: timeout
        str: buffer  # What was read before timeout
    end
end

type EOFError
    impl ExpectError
        str: pattern
        int?: exit_status
        str: buffer
    end
end

# Usage
try
    session.expect("$ ", timeout: 5)
catch TimeoutError as e
    puts(f"Timed out waiting for {e.pattern}")
    puts(f"Buffer: {e.buffer}")
end
```

## Examples

### SSH Automation

```quest
use "std/process/expect"

fun ssh_execute(host, user, password, command)
    let session = expect.spawn(f"ssh {user}@{host}")

    # Handle known_hosts prompt
    let idx = session.expect([
        ["Are you sure", 0],
        ["password:", 1],
        ["Permission denied", 2]
    ])

    if idx == 0
        session.send_line("yes")
        session.expect("password:")
    elif idx == 2
        raise "SSH connection failed"
    end

    # Send password
    session.send_line(password)
    session.expect("$ ")

    # Execute command
    session.send_line(command)
    let output = session.expect("$ ")

    # Cleanup
    session.send_line("exit")
    session.expect_eof()

    output
end
```

### Interactive Menu Navigation

```quest
use "std/process/expect"

let app = expect.spawn("./my-tui-app")

# Navigate menu
app.expect("Main Menu")
app.send_line("2")  # Select option 2

app.expect("Enter name:")
app.send_line("TestUser")

app.expect("Confirm (y/n):")
app.send_line("y")

app.expect("Success")
app.send_control('c')  # Exit
app.close()
```

### CLI Testing

```quest
use "std/test"
use "std/process/expect"

test.describe("Quest REPL", fun ()
    test.it("evaluates expressions", fun ()
        let repl = expect.spawn("./target/release/quest")
        repl.expect("quest> ")

        repl.send_line("2 + 2")
        repl.expect("quest> ")
        test.assert(repl.before.contains("4"))

        repl.send_line("let x = 10")
        repl.expect("quest> ")

        repl.send_line("x * 2")
        repl.expect("quest> ")
        test.assert(repl.before.contains("20"))

        repl.send_control('d')
        repl.expect_eof()
    end)
end)
```

### Password Manager Automation

```quest
use "std/process/expect"

fun unlock_vault(vault_path, master_password)
    let vault = expect.spawn(f"vault open {vault_path}")

    vault.expect("Master password:", timeout: 5)
    vault.send_line(master_password)

    let idx = vault.expect([
        ["Vault unlocked", 0],
        ["Incorrect password", 1],
        [expect.TIMEOUT, 2]
    ], timeout: 10)

    if idx == 1
        raise "Invalid master password"
    elif idx == 2
        raise "Vault did not respond"
    end

    vault
end
```

### Logging and Debugging

```quest
use "std/process/expect"

let session = expect.spawn("complex-app")
session.log_file("/tmp/expect.log")  # Log all I/O

session.expect("Ready")
session.send_line("start")

# Drop to interactive mode for debugging
session.interact()  # User takes over, Ctrl-] to return
```

## Implementation Notes

### Implementation Language

**The expect library should be written entirely in Quest**, not Rust. It will be a pure-Quest module located at `stdlib/process/expect.q` that wraps the existing `sys/process` module.

This approach:
- Demonstrates Quest's capability for building complex abstractions
- Keeps the implementation maintainable and readable
- Leverages existing process spawning infrastructure
- Allows users to read and understand the implementation

### Architecture

The library will wrap `sys/process` which already provides:
- `process.spawn(command, options)` - Returns `Process` object with stdin/stdout/stderr streams
- `process.run(command, options)` - Runs to completion, returns `ProcessResult`
- Stream I/O via `WritableStream` and `ReadableStream`

The expect library adds:
- Pattern matching loop that reads from stdout incrementally
- Timeout handling via polling with sleep
- Buffer management for `before`/`after`/`match` properties
- Regex support via `std/regex` module
- State machine for managing interactive sessions

### Key Algorithms

**Pattern Matching Loop**:
```quest
# Pseudocode for expect() implementation
fun expect(pattern, timeout)
    let buffer = ""
    let start_time = current_time()

    while true
        # Check timeout
        if timeout and (current_time() - start_time > timeout)
            raise TimeoutError(pattern, timeout, buffer)
        end

        # Read available data (non-blocking or short timeout)
        let chunk = self.stdout.read(1024)  # or read_nonblocking
        if chunk.empty?()
            # Check if process exited
            let status = self.wait_nonblocking()
            if status != nil
                raise EOFError(pattern, status, buffer)
            end
            sleep(0.1)  # Small delay before retry
            continue
        end

        buffer = buffer .. chunk

        # Try to match pattern
        let match_result = try_match(pattern, buffer)
        if match_result
            self.before = match_result.before
            self.after = match_result.after
            self.match = match_result.match
            return match_result.value
        end
    end
end
```

### Platform Support

**PTY Support**: The initial implementation will use regular pipes (`process.spawn`). PTY support can be added later via a Rust extension if needed, but most use cases work fine with pipes.

**Cross-platform**: Works on Unix, Linux, macOS, and Windows (using the existing `process` module's platform handling).

### Performance

- Buffer reads in chunks (configurable, default 1024-4096 bytes)
- Compile regex patterns once at spawn time
- Polling loop with small sleep intervals (0.1s default) to avoid busy-waiting
- Stream reading uses existing Rust-based I/O for efficiency

### Security

- Never log passwords by default
- Provide `send_password(text)` that temporarily disables logging
- Clear sensitive data from buffers after use (if logging disabled)
- Log file writes are append-only

### Required Additions to `sys/process`

The current `process` module may need these additions to fully support expect:
1. **Non-blocking read**: `stream.read_nonblocking(size, timeout)` - Returns immediately with available data
2. **Non-blocking wait**: `process.poll()` - Check if process has exited without blocking
3. **Signal sending**: `process.send_signal(signal)` - Send signals like SIGINT (Ctrl-C)

These can be added to the Rust implementation if not already present.

## Alternatives Considered

1. **Pipe-based approach**: Doesn't work for password prompts or PTY-dependent programs
2. **Script generation**: Less flexible, doesn't handle dynamic responses
3. **External expect binary**: Adds dependency, less integrated

## Migration

New module, no breaking changes. Enables patterns not previously possible in Quest.

## Open Questions

1. Should `interact()` be blocking or support callback handlers?
2. Windows ConPTY minimum version requirement (Windows 10 1809+)?
3. Default buffer size and timeout values?
4. Support for expect-style "glob" patterns or stick to regex?

## References

- Tcl Expect: https://core.tcl-lang.org/expect/
- Python pexpect: https://pexpect.readthedocs.io/
- Go expect: https://github.com/google/goexpect
- Rust expectrl: https://docs.rs/expectrl/
