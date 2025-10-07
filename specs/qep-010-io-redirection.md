# QEP-010: I/O Redirection - stdout/stderr Control

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Updated:** 2025-10-05
**Related:** QEP-009 (StringIO)

## Abstract

This QEP specifies I/O redirection capabilities for Quest, allowing programs to redirect stdout and stderr to files, StringIO buffers, or null. The design uses **guard objects** (Python context manager style) that automatically restore streams when they go out of scope or are explicitly restored.

**Implementation Phases:**
- **Phase 1**: Manual guard restoration with `guard.restore()`
- **Phase 2**: Automatic restoration with `with` statement blocks

## Current State

Quest currently supports:
- Redirecting stdout/stderr to files
- Redirecting to `/dev/null` (discard output)

**What's missing:**
- Programmatic control of redirection at runtime
- Redirect to in-memory buffers (StringIO)
- Safe restoration of previous streams
- Access to current stdout/stderr streams

## Rationale

I/O redirection is essential for:

1. **Testing** - Capture output for verification
2. **Logging** - Redirect output to log files dynamically
3. **Silent execution** - Suppress noisy output
4. **Output processing** - Capture and analyze program output
5. **Debugging** - Separate debug output from normal output

## Design Philosophy

**Principle 1: Python Context Manager Pattern**
- `sys.redirect_stdout()` returns a **guard object**
- Guard automatically saves previous stream state
- Restoration via `guard.restore()` (Phase 1) or `with` blocks (Phase 2)
- Guard is idempotent (safe to restore multiple times)

**Principle 2: Safe by Default**
- Guard objects ensure streams are restored
- Use `try/ensure` pattern for exception safety
- Clear error messages when restoration fails

**Principle 3: Simple API**
- `sys.stdout`, `sys.stderr`, `sys.stdin` singleton objects
- Guard objects with `_enter()`, `_exit()`, `restore()` methods
- Any object with `write()` can be a target

**Principle 4: Flexible Targets**
- Files (by path or file object)
- StringIO buffers
- `/dev/null` for discard
- Any object with `write()` method

## API Design - Phase 1 (Manual Guards)

### System Stream Objects

#### `sys.stdout` (Singleton)

Singleton object representing OS stdout.

**Type:** SystemStream

**Methods:**
- `write(data: Str) → Int` - Write to stdout, returns bytes written
- `flush() → Nil` - Flush output buffer

**Example:**
```quest
use "std/sys"

# Write directly
sys.stdout.write("Hello\n")
```

#### `sys.stderr` (Singleton)

Singleton object representing OS stderr.

**Type:** SystemStream

**Methods:**
- `write(data: Str) → Int` - Write to stderr
- `flush() → Nil` - Flush output buffer

#### `sys.stdin` (Singleton)

Singleton object representing OS stdin.

**Type:** SystemStream

**Methods:**
- `read() → Str` - Read all available input
- `readline() → Str` - Read one line

### Guard Object Type

#### `RedirectGuard`

Returned by `sys.redirect_stdout()` and `sys.redirect_stderr()`. Manages stream restoration.

**Type:** RedirectGuard

**Methods:**
- `restore() → Nil` - Restore previous stream (idempotent)
- `is_active() → Bool` - Returns `true` if not yet restored
- `_enter() → RedirectGuard` - Context manager enter (Phase 2)
- `_exit() → Nil` - Context manager exit (Phase 2)

**Properties:**
- Restoration is **idempotent** - calling `restore()` multiple times is safe
- Guards track their own state (active vs restored)
- Cloning a guard shares the same restoration state

### Redirection Functions

#### `sys.redirect_stdout(target) → RedirectGuard`

Redirect stdout to target, returns guard object for restoration.

**Parameters:**
- `target` - Can be:
  - `Str` - File path (e.g., `"output.log"`, `"/dev/null"`)
  - `File` - Open file object
  - `StringIO` - In-memory buffer
  - Any object with `write(data: Str) → Int` method

**Returns:** RedirectGuard object

**Phase 1 Example (Manual Restoration):**
```quest
use "std/sys"
use "std/io"

# Basic usage
let buffer = io.StringIO.new()
let guard = sys.redirect_stdout(buffer)
puts("Captured")
guard.restore()
test.assert_eq(buffer.get_value(), "Captured\n", nil)

# Exception-safe pattern
let buffer = io.StringIO.new()
let guard = sys.redirect_stdout(buffer)
try
    puts("Safe capture")
    risky_operation()
ensure
    guard.restore()  # Always restores, even on exception
end
```

#### `sys.redirect_stderr(target) → RedirectGuard`

Redirect stderr to target, returns guard object.

**Parameters:**
- `target` - Same types as `redirect_stdout()`

**Returns:** RedirectGuard object

**Example:**
```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()
let guard = sys.redirect_stderr(buffer)

try
    sys.stderr.write("Error message\n")
ensure
    guard.restore()
end

test.assert_eq(buffer.get_value(), "Error message\n", nil)
```

### Stream Target Requirements

Any object can be used as redirection target if it implements:

**Required method:**
```quest
write(data: Str) → Int
```
Writes string data, returns number of bytes/characters written.

**Optional methods:**
```quest
flush() → Nil  # Flush buffered data
close() → Nil  # Close stream
```

## Complete Examples - Phase 1

### Example 1: Test Output Capture

```quest
use "std/test"
use "std/sys"
use "std/io"

test.module("Output Capture")

test.describe("Output capture", fun ()
    test.it("captures puts output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        try
            puts("Hello")
            puts("World")
        ensure
            guard.restore()
        end

        test.assert_eq(buffer.get_value(), "Hello\nWorld\n")
    end)

    test.it("guard is idempotent", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        puts("Test")
        guard.restore()
        guard.restore()  # Safe to call multiple times
        guard.restore()

        test.assert_eq(buffer.get_value(), "Test\n")
    end)

    test.it("checks guard active state", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        test.assert(guard.is_active(), "Should be active")
        guard.restore()
        test.assert(not guard.is_active(), "Should be inactive")
    end)
end)
```

### Example 2: Nested Redirections

```quest
use "std/sys"
use "std/io"

fun nested_capture()
    let buf1 = io.StringIO.new()
    let guard1 = sys.redirect_stdout(buf1)

    try
        puts("Outer")

        # Inner redirection
        let buf2 = io.StringIO.new()
        let guard2 = sys.redirect_stdout(buf2)
        try
            puts("Inner")
        ensure
            guard2.restore()  # Back to buf1
        end

        puts("Outer again")
    ensure
        guard1.restore()  # Back to console
    end

    puts("buf1: " .. buf1.get_value())  # "Outer\nOuter again\n"
    puts("buf2: " .. buf2.get_value())  # "Inner\n"
end
```

### Example 3: Capture Function Output

```quest
use "std/sys"
use "std/io"

fun capture_output(func)
    let buffer = io.StringIO.new()
    let guard = sys.redirect_stdout(buffer)

    try
        func()
    ensure
        guard.restore()
    end

    buffer.get_value()
end

# Usage
let output = capture_output(fun ()
    puts("Line 1")
    puts("Line 2")
    puts("Line 3")
end)

puts("Captured: " .. output)
```

### Example 4: Suppress Output

```quest
use "std/sys"

fun silent(func)
    let guard_out = sys.redirect_stdout("/dev/null")
    let guard_err = sys.redirect_stderr("/dev/null")

    try
        func()
    ensure
        guard_out.restore()
        guard_err.restore()
    end
end

# Usage
silent(fun ()
    puts("This won't appear")
    sys.stderr.write("Neither will this\n")
end)
```

### Example 5: Log to File

```quest
use "std/sys"
use "std/io"

fun with_file_output(filename, func)
    let guard = sys.redirect_stdout(filename)
    try
        func()
    ensure
        guard.restore()
    end
end

# Usage
with_file_output("output.log", fun ()
    puts("Starting process...")
    puts("Processing data...")
    puts("Done!")
end)

let log = io.read("output.log")
puts("Log:\n" .. log)
```

### Example 6: Dual Output (Tee)

```quest
use "std/sys"
use "std/io"

# Custom TeeWriter
type TeeWriter
    array: targets

    fun write(data)
        for target in self.targets
            target.write(data)
        end
        data.len()
    end

    fun flush()
        for target in self.targets
            try
                target.flush()
            catch e
                # Ignore if flush() not supported
            end
        end
    end
end

# Usage
let file = io.open("output.log", "w")
let tee = TeeWriter.new(targets: [sys.stdout, file])
let guard = sys.redirect_stdout(tee)

try
    puts("Goes to both console and file!")
ensure
    guard.restore()
    file.close()
end
```

## API Design - Phase 2 (with blocks)

### `with` Statement Syntax

```quest
with sys.redirect_stdout(buffer)
    # Code here has stdout redirected
    puts("Captured")
end  # Automatic restoration via guard._exit()
```

### How `with` Works

The `with` statement automatically calls:
1. `guard._enter()` - Called at block entry (returns self)
2. Block executes with redirection active
3. `guard._exit()` - Called at block exit (even on exception)

### Phase 2 Examples

#### Example 1: Simple Capture

```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()

with sys.redirect_stdout(buffer)
    puts("Hello")
    puts("World")
end  # Automatic restoration

test.assert_eq(buffer.get_value(), "Hello\nWorld\n", nil)
```

#### Example 2: Exception Safety

```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()

try
    with sys.redirect_stdout(buffer)
        puts("Before error")
        raise "Something failed"
        puts("After error")  # Won't execute
    end  # guard._exit() still called!
catch e
    puts("Caught: " .. e.message())
end

# Output was still captured before error
test.assert_eq(buffer.get_value(), "Before error\n", nil)
```

#### Example 3: Nested with Blocks

```quest
use "std/sys"
use "std/io"

let buf1 = io.StringIO.new()
let buf2 = io.StringIO.new()

with sys.redirect_stdout(buf1)
    puts("Outer")

    with sys.redirect_stdout(buf2)
        puts("Inner")
    end  # Back to buf1

    puts("Outer again")
end  # Back to console

puts("buf1: " .. buf1.get_value())  # "Outer\nOuter again\n"
puts("buf2: " .. buf2.get_value())  # "Inner\n"
```

#### Example 4: Multiple Streams

```quest
use "std/sys"
use "std/io"

let out_buf = io.StringIO.new()
let err_buf = io.StringIO.new()

with sys.redirect_stdout(out_buf)
    with sys.redirect_stderr(err_buf)
        puts("Normal output")
        sys.stderr.write("Error output\n")
    end
end

test.assert_eq(out_buf.get_value(), "Normal output\n", nil)
test.assert_eq(err_buf.get_value(), "Error output\n", nil)
```

## Implementation Notes

### RedirectGuard Type

```rust
// src/types/redirect_guard.rs

#[derive(Debug, Clone)]
pub struct QRedirectGuard {
    pub id: u64,
    pub stream_type: StreamType,
    pub previous_target: Rc<RefCell<Option<OutputTarget>>>,  // Shared state
    pub scope_id: usize,  // Reference to scope for restoration
}

#[derive(Debug, Clone, PartialEq)]
pub enum StreamType {
    Stdout,
    Stderr,
    Stdin,
}

impl QRedirectGuard {
    pub fn new(stream_type: StreamType, previous: OutputTarget, scope_id: usize) -> Self {
        Self {
            id: next_object_id(),
            stream_type,
            previous_target: Rc::new(RefCell::new(Some(previous))),
            scope_id,
        }
    }

    pub fn restore(&self, scope: &mut Scope) -> Result<QValue, String> {
        let mut prev = self.previous_target.borrow_mut();

        if let Some(target) = prev.take() {
            match self.stream_type {
                StreamType::Stdout => scope.stdout = target,
                StreamType::Stderr => scope.stderr = target,
                StreamType::Stdin => scope.stdin = target,
            }
        }
        // If already restored (None), this is a no-op

        Ok(QValue::Nil(QNil))
    }

    pub fn is_active(&self) -> bool {
        self.previous_target.borrow().is_some()
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>, scope: &mut Scope)
        -> Result<QValue, String> {
        match method_name {
            "restore" => {
                if !args.is_empty() {
                    return Err(format!("restore() takes no arguments, got {}", args.len()));
                }
                self.restore(scope)
            }
            "is_active" => {
                if !args.is_empty() {
                    return Err(format!("is_active() takes no arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.is_active())))
            }
            "_enter" => {
                // Phase 2: Called by 'with' statement on entry
                // Guard already activated in redirect_stdout(), just return self
                Ok(QValue::RedirectGuard(Box::new(self.clone())))
            }
            "_exit" => {
                // Phase 2: Called by 'with' statement on exit
                self.restore(scope)
            }
            _ => Err(format!("RedirectGuard has no method '{}'", method_name))
        }
    }
}

impl QObj for QRedirectGuard {
    fn cls(&self) -> String {
        "RedirectGuard".to_string()
    }

    fn q_type(&self) -> &'static str {
        "RedirectGuard"
    }

    fn _str(&self) -> String {
        let status = if self.is_active() { "active" } else { "restored" };
        format!("<RedirectGuard for {:?} ({})>", self.stream_type, status)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Guard object for {} redirection", match self.stream_type {
            StreamType::Stdout => "stdout",
            StreamType::Stderr => "stderr",
            StreamType::Stdin => "stdin",
        })
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
```

### Scope Structure

```rust
// src/main.rs

pub struct Scope {
    pub variables: HashMap<String, QValue>,
    pub stdout: OutputTarget,
    pub stderr: OutputTarget,
    pub stdin: InputTarget,
    // ... other fields
}

#[derive(Debug, Clone)]
pub enum OutputTarget {
    Default,  // OS stdout
    DefaultStderr,  // OS stderr
    File(String),  // File path
    FileHandle(Rc<RefCell<File>>),  // Open file
    StringIO(Rc<RefCell<QStringIO>>),  // In-memory
    Custom(Box<QValue>),  // Any object with write()
}

impl OutputTarget {
    pub fn write(&mut self, data: &str) -> Result<usize, String> {
        match self {
            OutputTarget::Default => {
                print!("{}", data);
                io::stdout().flush().ok();
                Ok(data.len())
            }
            OutputTarget::DefaultStderr => {
                eprint!("{}", data);
                io::stderr().flush().ok();
                Ok(data.len())
            }
            OutputTarget::File(path) => {
                use std::fs::OpenOptions;
                use std::io::Write;
                let mut file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)
                    .map_err(|e| format!("Failed to open {}: {}", path, e))?;
                file.write_all(data.as_bytes())
                    .map_err(|e| format!("Write failed: {}", e))?;
                Ok(data.len())
            }
            OutputTarget::FileHandle(file_rc) => {
                use std::io::Write;
                let mut file = file_rc.borrow_mut();
                file.write_all(data.as_bytes())
                    .map_err(|e| format!("Write failed: {}", e))?;
                Ok(data.len())
            }
            OutputTarget::StringIO(buf) => {
                buf.borrow_mut().write(data)?;
                Ok(data.len())
            }
            OutputTarget::Custom(obj) => {
                // Call write() method on custom object
                let args = vec![QValue::Str(QString::new(data.to_string()))];
                // This requires calling the method - implementation detail
                // Would need scope reference to call methods properly
                unimplemented!("Custom output targets")
            }
        }
    }
}
```

### sys Module Functions

```rust
// src/modules/sys.rs

pub fn call_sys_function(
    func_name: &str,
    args: Vec<QValue>,
    scope: &mut Scope
) -> Result<QValue, String> {
    match func_name {
        "sys.redirect_stdout" => {
            if args.len() != 1 {
                return Err(format!(
                    "sys.redirect_stdout() expects 1 argument, got {}",
                    args.len()
                ));
            }

            // Save current stdout
            let previous = scope.stdout.clone();

            // Parse and set new target
            let target = parse_output_target(&args[0])?;
            scope.stdout = target;

            // Return guard for restoration
            let guard = QRedirectGuard::new(StreamType::Stdout, previous, 0);
            Ok(QValue::RedirectGuard(Box::new(guard)))
        }

        "sys.redirect_stderr" => {
            if args.len() != 1 {
                return Err(format!(
                    "sys.redirect_stderr() expects 1 argument, got {}",
                    args.len()
                ));
            }

            let previous = scope.stderr.clone();
            let target = parse_output_target(&args[0])?;
            scope.stderr = target;

            let guard = QRedirectGuard::new(StreamType::Stderr, previous, 0);
            Ok(QValue::RedirectGuard(Box::new(guard)))
        }

        _ => Err(format!("Unknown sys function: {}", func_name))
    }
}

fn parse_output_target(value: &QValue) -> Result<OutputTarget, String> {
    match value {
        QValue::SystemStream(stream) => {
            match stream.stream_id {
                0 => Ok(OutputTarget::Default),
                1 => Ok(OutputTarget::DefaultStderr),
                _ => Err("Invalid system stream".to_string())
            }
        }
        QValue::Str(s) => {
            Ok(OutputTarget::File(s.value.clone()))
        }
        QValue::StringIO(buf) => {
            Ok(OutputTarget::StringIO(Rc::clone(buf)))
        }
        QValue::File(f) => {
            Ok(OutputTarget::FileHandle(Rc::new(RefCell::new(f.clone()))))
        }
        _ => {
            Err("sys.redirect_stdout: target must be String, File, StringIO, or object with write()".to_string())
        }
    }
}
```

### Modify puts() and print()

```rust
// In builtin function handler

"puts" => {
    let mut output = String::new();
    for arg in &args {
        output.push_str(&arg._str());
    }
    output.push('\n');

    scope.stdout.write(&output)?;
    Ok(QValue::Nil(QNil))
}

"print" => {
    let mut output = String::new();
    for (i, arg) in args.iter().enumerate() {
        if i > 0 {
            output.push(' ');
        }
        output.push_str(&arg._str());
    }

    scope.stdout.write(&output)?;
    Ok(QValue::Nil(QNil))
}
```

## Testing Strategy

```quest
# test/sys/redirect_test.q
use "std/test"
use "std/sys"
use "std/io"

test.module("std/sys I/O Redirection")

test.describe("Phase 1: Manual Guards", fun ()
    test.it("redirects to StringIO", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        try
            puts("Test output")
        ensure
            guard.restore()
        end

        test.assert_eq(buffer.get_value(), "Test output\n", nil)
    end)

    test.it("guard is idempotent", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        puts("Output")
        guard.restore()
        guard.restore()  # Safe
        guard.restore()  # Safe

        test.assert(not guard.is_active(), "Should be inactive")
    end)

    test.it("nested redirections work", fun ()
        let buf1 = io.StringIO.new()
        let buf2 = io.StringIO.new()

        let guard1 = sys.redirect_stdout(buf1)
        try
            puts("Outer")

            let guard2 = sys.redirect_stdout(buf2)
            try
                puts("Inner")
            ensure
                guard2.restore()
            end

            puts("Outer again")
        ensure
            guard1.restore()
        end

        test.assert_eq(buf1.get_value(), "Outer\nOuter again\n", nil)
        test.assert_eq(buf2.get_value(), "Inner\n", nil)
    end)

    test.it("redirects to file path", fun ()
        let path = "/tmp/quest_test_" .. sys.argv.get(0) .. ".txt"
        let guard = sys.redirect_stdout(path)

        try
            puts("File output")
        ensure
            guard.restore()
        end

        let content = io.read(path)
        test.assert(content.contains("File output"), "File should contain output")
        io.remove(path)
    end)

    test.it("suppresses with /dev/null", fun ()
        let guard = sys.redirect_stdout("/dev/null")

        try
            puts("Suppressed")
        ensure
            guard.restore()
        end

        test.assert(true, "Should not error")
    end)
end)

test.describe("Phase 1: stderr redirection", fun ()
    test.it("redirects stderr to StringIO", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stderr(buffer)

        try
            sys.stderr.write("Error message\n")
        ensure
            guard.restore()
        end

        test.assert_eq(buffer.get_value(), "Error message\n", nil)
    end)
end)

test.describe("Phase 1: Exception safety", fun ()
    test.it("restores on exception", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stdout(buffer)

        try
            puts("Before error")
            raise "Test error"
        catch e
            guard.restore()
        end

        # stdout should be restored
        puts("After restore")
        test.assert_eq(buffer.get_value(), "Before error\n", nil)
    end)
end)

# Phase 2 tests (when 'with' statement is implemented)
# test.describe("Phase 2: with blocks", fun ()
#     test.it("auto-restores with 'with' block", fun ()
#         let buffer = io.StringIO.new()
#
#         with sys.redirect_stdout(buffer)
#             puts("Captured")
#         end
#
#         test.assert_eq(buffer.get_value(), "Captured\n", nil)
#     end)
# end)
```

## Buffering Behavior

**stdout:**
- Line-buffered by default (flushes on `\n`)
- Explicit flush: `sys.stdout.flush()`

**stderr:**
- Unbuffered (flushes immediately)
- Explicit flush: `sys.stderr.flush()`

**File targets:**
- Buffered by OS
- Explicit flush via File object's `flush()` method

**StringIO:**
- No buffering (writes immediately to memory)

## Error Handling

**Invalid targets:**
```quest
sys.redirect_stdout(123)  # Error: Invalid type
sys.redirect_stdout(nil)  # Error: Cannot redirect to nil
```

**File errors:**
```quest
try
    let guard = sys.redirect_stdout("/invalid/path/file.txt")
    guard.restore()  # Might not be reached
catch e
    puts("Error: " .. e.message())
end
```

**Double restoration (safe):**
```quest
let guard = sys.redirect_stdout(buffer)
puts("Output")
guard.restore()
guard.restore()  # No-op, safe
```

## Integration with Other Modules

### std/log

Log handlers (StreamHandler, FileHandler) **do not** respect stdout redirection. They write directly to their configured streams.

To capture log output:
```quest
let buffer = io.StringIO.new()
let handler = log.StreamHandler(buffer)
logger.add_handler(handler)
```

### Built-in Functions

**Redirected:**
- `puts()` - Uses `scope.stdout`
- `print()` - Uses `scope.stdout`

**Not redirected:**
- `sys.stderr.write()` - Direct write (unless stderr redirected)
- Log handlers - Independent streams

## Performance Considerations

1. **File redirection** - Opens/closes on each write (consider using File object for performance)
2. **StringIO redirection** - Very fast (in-memory only)
3. **Default output** - Same as original (no overhead)
4. **Guard overhead** - Minimal (one clone of OutputTarget)

## Implementation Checklist

### Phase 1: Manual Guards
- [ ] Add `QRedirectGuard` type to types/redirect_guard.rs
- [ ] Add `RedirectGuard` variant to `QValue` enum
- [ ] Add `OutputTarget` enum to Scope structure
- [ ] Create `sys.stdout`, `sys.stderr`, `sys.stdin` singletons
- [ ] Implement `sys.redirect_stdout()` returning guard
- [ ] Implement `sys.redirect_stderr()` returning guard
- [ ] Implement `guard.restore()` method
- [ ] Implement `guard.is_active()` method
- [ ] Support String (file paths) as targets
- [ ] Support StringIO as targets
- [ ] Support File objects as targets
- [ ] Modify `puts()` to use `scope.stdout`
- [ ] Modify `print()` to use `scope.stdout`
- [ ] Write comprehensive test suite
- [ ] Add documentation

### Phase 2: with Blocks
- [ ] Implement `with` statement in parser
- [ ] Call `_enter()` on block entry
- [ ] Call `_exit()` on block exit (even on exception)
- [ ] Implement `guard._enter()` method
- [ ] Implement `guard._exit()` method
- [ ] Add Phase 2 tests
- [ ] Update documentation

## Conclusion

I/O redirection with guard objects provides safe, Python-style context management for Quest. The phased approach allows immediate usefulness (Phase 1) while planning for ergonomic `with` blocks (Phase 2).

**Phase 1 Benefits:**
- **Manual restoration** - Explicit control with `guard.restore()`
- **Exception safety** - Use `try/ensure` pattern
- **Idempotent** - Safe to restore multiple times
- **Nestable** - Guards stack naturally
- **Testable** - Easy to capture and verify output

**Phase 2 Benefits:**
- **Automatic restoration** - `with` blocks handle cleanup
- **Cleaner syntax** - No manual `try/ensure` needed
- **Python-familiar** - Matches context manager pattern

**Example comparison:**

```quest
# Phase 1 (Available immediately)
let guard = sys.redirect_stdout(buffer)
try
    puts("Output")
ensure
    guard.restore()
end

# Phase 2 (When 'with' is implemented)
with sys.redirect_stdout(buffer)
    puts("Output")
end  # Automatic restoration
```

Both phases use the same guard object type with `_enter()` and `_exit()` methods, ensuring a smooth transition path.

## Implementation Challenges and Solutions

### Challenge 1: Scope Inheritance for User Functions

**Problem:** When `test.it(fun () ... end)` called user function `test_fn`, the function created a new scope that reset `stdout_target` to `Default`, breaking redirection.

**Symptom:**
```quest
let buf = io.StringIO.new()
let guard = sys.redirect_stream(sys.stdout, buf)

test.it("test", fun ()
    puts("Should be captured")  # Actually went to console!
end)

guard.restore()
puts(buf.get_value())  # Empty!
```

**Root Cause:** `function_call.rs:call_user_function()` created a new `Scope` that didn't inherit I/O targets from parent.

**Solution:** Inherit I/O targets when creating function scope:
```rust
// src/function_call.rs:54-55
func_scope.stdout_target = parent_scope.stdout_target.clone();
func_scope.stderr_target = parent_scope.stderr_target.clone();
```

**Impact:** Essential for test output capture to work. User functions now properly inherit redirection.

---

### Challenge 2: Scope Inheritance for Module Functions

**Problem:** Module functions (like `log.warning()`) also bypassed redirection because they used `Scope::with_shared_base()` which reset I/O targets.

**Symptom:**
```quest
let buf = io.StringIO.new()
let guard = sys.redirect_stream(sys.stdout, buf)

log.warning("Message")  # Went to console, not buffer!
```

**Root Cause:** When calling module functions, `main.rs:1820` created `module_scope` with `with_shared_base()` which initialized `stdout_target` to `Default`.

**Solution:** Inherit I/O targets after creating module scope:
```rust
// src/main.rs:1834-1835 (in module function call handling)
module_scope.stdout_target = scope.stdout_target.clone();
module_scope.stderr_target = scope.stderr_target.clone();
```

**Impact:** Log handlers, module functions, and any code calling across module boundaries now respects redirection.

---

### Challenge 3: API Design - Single Function vs Multiple

**Original Design:** Separate `sys.redirect_stdout()` and `sys.redirect_stderr()` (Python-style)

**Refactored To:** Single `sys.redirect_stream(from, to)` (Unix-style)

**Why:**
- Enables stream-to-stream redirection: `sys.redirect_stream(sys.stderr, sys.stdout)`  # 2>&1
- More flexible and future-proof
- Single API to learn
- Explicit about what's being redirected

**Trade-off:** Slightly more verbose for common case, but much more powerful.

---

### Challenge 4: Guard Method Dispatch with Scope Access

**Problem:** `RedirectGuard.restore()` needs mutable access to `Scope` to update `stdout_target`/`stderr_target`, but method calls happen in two places:
1. `call_method_on_value()` - Has scope access
2. Postfix operator dispatch - Also has scope access

**Initial Approach:** Tried to make `call_method()` take `&mut Scope` parameter.

**Problem with Initial Approach:** Would require changing signature of all `call_method()` implementations across all types.

**Solution:** Special-case `RedirectGuard` in both dispatch locations:
```rust
// In call_method_on_value() and postfix dispatch
QValue::RedirectGuard(rg) => {
    match method_name {
        "restore" => {
            rg.restore(scope)?;  // Has scope access here
            Ok(QValue::Nil(QNil))
        }
        "_enter" | "_exit" => { /* ... */ }
        _ => rg.call_method_without_scope(method_name, args)
    }
}
```

**Impact:** Clean separation - most methods don't need scope, only `restore()`, `_enter()`, `_exit()` do.

---

### Challenge 5: Test Framework Output Capture

**Problem:** Initially, test output wasn't being captured even though guards were created.

**Root Cause:** Three-part issue:
1. User functions didn't inherit I/O targets (Challenge #1)
2. Module functions didn't inherit I/O targets (Challenge #2)
3. Assertion failures (`test.assert_eq()`) displayed immediately, bypassing capture

**Solution:**
1. Fixed scope inheritance (Challenges #1 and #2)
2. Changed test framework flow:
   ```quest
   # Before
   try
       test_fn()
   catch e
       puts("FAIL")  # Immediate output
   end

   # After
   let test_error = nil
   try
       test_fn()
   catch e
       test_error = e
   end

   # Restore first
   if guard != nil
       guard.restore()
       captured = buffer.get_value()
   end

   # Then display with captured output
   if test_error != nil
       puts("FAIL")
       puts("Captured: " .. captured)
   end
   ```

**Impact:** Test output is now clean by default, only showing on failures with full context.

---

### Challenge 6: OutputTarget Clone Semantics

**Problem:** `OutputTarget` needed to be `Clone` for guard restoration, but what does it mean to clone a file path vs StringIO?

**Design Decision:**
```rust
#[derive(Clone)]
pub enum OutputTarget {
    Default,                          // Clone: Same console
    File(String),                     // Clone: Same path (opens separately)
    StringIO(Rc<RefCell<QStringIO>>), // Clone: Shared buffer (Rc)
}
```

**Key Insight:** `Rc::clone()` for StringIO is essential - when redirecting to a buffer, both the guard's `previous_target` and the active `scope.stdout_target` need to point to the **same** buffer instance.

**Why it matters:**
```quest
let buf = io.StringIO.new()
let guard = sys.redirect_stream(sys.stdout, buf)
# guard.previous_target has Rc to same buffer
# scope.stdout_target has Rc to same buffer
# buf variable has Rc to same buffer
# All three write to the SAME underlying QStringIO
```

---

### Challenge 7: Idempotent Restoration with Shared State

**Problem:** Multiple guards or cloned guards should share restoration state so restoring once affects all.

**Solution:** Use `Rc<RefCell<Option<OutputTarget>>>` in QRedirectGuard:
```rust
pub struct QRedirectGuard {
    pub previous_target: Rc<RefCell<Option<OutputTarget>>>,
    // ...
}

pub fn restore(&self, scope: &mut Scope) -> Result<(), String> {
    let mut prev = self.previous_target.borrow_mut();
    if let Some(target) = prev.take() {  // take() replaces with None
        // Restore...
    }
    // Second call finds None, does nothing (idempotent)
    Ok(())
}
```

**Result:**
```quest
let guard1 = sys.redirect_stream(sys.stdout, buf)
let guard2 = guard1  # Clone

guard1.restore()
guard2.is_active()  # false (shared state!)
guard2.restore()    # No-op (safe)
```

---

### Challenge 8: Preventing and_op Evaluation Error

**Problem:** During implementation, added defensive error case for operator tokens:
```rust
Rule::or_op | Rule::and_op | Rule::not_op => {
    Err("Cannot evaluate operator as expression")
}
```

This broke existing code because the bug #008 fix added proper token skipping:
```rust
// In logical_and evaluation
if matches!(next.as_rule(), Rule::and_op) {
    continue;  // Skip the token
}
```

**Symptom:** Tests failed with "Unsupported rule: and_op" error.

**Solution:** Removed the defensive error case. The existing skip logic handles operator tokens correctly.

**Lesson:** Trust existing patterns. The grammar and parser already handle edge cases correctly.

---

### Challenge 9: SystemStream.write() Bypass

**Problem:** Direct calls to `sys.stdout.write()` initially bypassed redirection because `QSystemStream.call_method()` wrote directly to `print!()`.

**Solution:** Special-case `SystemStream.write()` in method dispatch to check `scope.stdout_target`:
```rust
QValue::SystemStream(ss) => {
    if method_name == "write" {
        // Write to redirected target
        match ss.stream_id {
            0 => scope.stdout_target.write(&data)?,
            1 => scope.stderr_target.write(&data)?,
            _ => ...
        }
    } else {
        ss.call_method(method_name, args)
    }
}
```

**Impact:** Both `puts()` and `sys.stdout.write()` now respect redirection consistently.

---

## Implementation Statistics

**Development Time:** ~3 hours total
- Phase 0 (Foundation types): 1 hour
- Phase 1 (Core redirection): 1 hour
- Phase 2 (Context manager): Already implemented in QEP-011
- API refactor (redirect_stream): 30 minutes
- Test capture integration: 30 minutes
- Debug and fixes: 30 minutes

**Files Modified:** 9 files
- 4 new type files (system_stream, redirect_guard, OutputTarget in scope.rs)
- 3 core files (main.rs, function_call.rs, modules/sys.rs)
- 2 test framework files (lib/std/test.q, scripts/qtest)

**Lines of Code:** ~600 lines added
- Types: 250 lines
- Integration: 150 lines
- Tests: 200 lines

**Test Coverage:** 34 dedicated I/O redirection tests + integration with test framework

**Key Files:**
- `src/types/system_stream.rs` - Singleton stream objects
- `src/types/redirect_guard.rs` - Guard lifecycle management
- `src/scope.rs` - OutputTarget enum and write() implementation
- `src/modules/sys.rs` - redirect_stream() function
- `src/function_call.rs` - Scope inheritance fix #1
- `src/main.rs` - Scope inheritance fix #2, method dispatch
- `lib/std/test.q` - Output capture integration
- `test/sys/redirect_test.q` - 34 comprehensive tests

## Lessons Learned

1. **Scope inheritance is subtle** - Any scope creation point needs to consider what to inherit (variables, exceptions, I/O targets, call stack)

2. **Guard pattern works well** - Dedicated guard objects separate lifecycle management from the resources being managed

3. **Test early in realistic contexts** - Output capture bug only appeared when testing in actual test framework, not in isolated tests

4. **Defensive error checks can backfire** - Trust existing patterns (like token skipping) rather than adding redundant checks

5. **Clone semantics matter** - `Rc<RefCell<>>` for shared mutable state, `Box` for owned state, careful choice needed

6. **Stream-to-stream unlocks power** - `redirect_stream(from, to)` enables Unix-style redirection (2>&1) that wouldn't work with `redirect_stdout(target)`

7. **Documentation through examples** - Writing usage examples (2>&1, capture, nested) validated the API design

## Future Enhancements

**Already possible with current implementation:**
- ✅ Capture test output (implemented in test framework)
- ✅ Stream merging (stderr→stdout)
- ✅ File logging
- ✅ Silent execution (/dev/null)
- ✅ Nested redirections
- ✅ Context manager support

**Potential Phase 3 additions:**
- `sys.stdin` redirection for input mocking
- File object support (when QEP-011 File Objects implemented)
- Custom write() object support (any object with write method)
- Tee functionality (write to multiple targets simultaneously)
- Buffering control

**Not needed:**
- Restore without guard (can just `sys.redirect_stream(sys.stdout, sys.stdout)`)
- Separate redirect_stdout/stderr functions (redirect_stream covers all cases)
