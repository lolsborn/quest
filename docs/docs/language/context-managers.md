# Context Managers

Context managers provide automatic resource management through the `with` statement, ensuring that setup and cleanup code always runs—even when exceptions occur.

## Overview

A context manager is any object that implements two methods:
- `_enter()` - Called when entering the `with` block
- `_exit()` - Called when exiting the `with` block (even on exception)

This pattern is inspired by Python's context managers and provides a clean way to manage resources like files, database connections, locks, and temporary states.

## Basic Syntax

### Simple Form

```quest
with context_manager
    # code here
end
```

### With Variable Binding

```quest
with context_manager as variable
    # code here with access to variable
end
```

## How It Works

The `with` statement automatically handles setup and cleanup:

```quest
# This code:
with context_manager as var
    do_work(var)
end

# Is equivalent to:
let __ctx = context_manager
let var = __ctx._enter()
try
    do_work(var)
ensure
    __ctx._exit()
end
```

**Key guarantee**: `_exit()` is **always** called, even if:
- An exception occurs in the body
- A `return` statement is encountered
- Any other control flow exits the block

## Creating Context Managers

### User-Defined Context Managers

Any Quest type can be a context manager by implementing `_enter()` and `_exit()`:

```quest
type Timer
    str: label
    float?: start_time

    fun _enter()
        self.start_time = time.now()
        puts("Timer started: " .. self.label)
        self  # Return self for 'as' binding
    end

    fun _exit()
        let elapsed = time.now() - self.start_time
        puts(self.label .. " took " .. elapsed .. " seconds")
    end
end

# Usage
with Timer.new(label: "Database query")
    db.execute("SELECT * FROM large_table")
end
# Output: Database query took 1.234 seconds
```

### Method Signatures

#### `_enter() → Any`

Called when entering the `with` block.

**Returns:** Value to bind to the `as` variable (often `self`, but can be anything)

**Example:**
```quest
type FileWrapper
    file: file_handle

    fun _enter()
        puts("File opened")
        self.file  # Return the file, not self
    end
end

with FileWrapper.new(file: f) as file
    # 'file' is the file handle, not the wrapper
    file.read()
end
```

#### `_exit() → Nil`

Called when exiting the `with` block (even on exception).

**Returns:** `nil` (future: `true` to suppress exceptions)

**Example:**
```quest
fun _exit()
    puts("Cleaning up")
    self.cleanup()
    # Always return nil
end
```

## Common Patterns

### Resource Management

Automatically clean up resources:

```quest
type DatabaseTransaction
    connection: conn
    bool: committed

    fun _enter()
        self.connection.execute("BEGIN TRANSACTION")
        self
    end

    fun _exit()
        if not self.committed
            self.connection.execute("ROLLBACK")
            puts("Transaction rolled back")
        end
    end

    fun commit()
        self.connection.execute("COMMIT")
        self.committed = true
    end
end

# Usage - automatic rollback on error
with db.begin_transaction() as tx
    db.execute("INSERT INTO users VALUES (?)", ["Alice"])
    db.execute("INSERT INTO posts VALUES (?)", ["Post 1"])
    tx.commit()  # Explicit commit
end  # Automatically rolls back if not committed
```

### Temporary State Changes

Save and restore state:

```quest
type WorkingDirectory
    str: original_dir
    str: new_dir

    fun _enter()
        self.original_dir = os.getcwd()
        os.chdir(self.new_dir)
        self.new_dir
    end

    fun _exit()
        os.chdir(self.original_dir)
    end
end

# Usage
with WorkingDirectory.new(new_dir: "/tmp") as dir
    # Work in /tmp
    io.write("temp.txt", "data")
end  # Automatically restored to original directory
```

### Output Capture

Redirect and restore output:

```quest
use "std/sys"
use "std/io"

# StringIO with context manager (built-in)
with io.StringIO.new() as buffer
    sys.redirect_stdout(buffer)
    try
        puts("Captured output")
    ensure
        sys.redirect_stdout(sys.stdout)
    end

    puts("Output was: " .. buffer.get_value())
end
```

### Timing and Performance

Measure execution time:

```quest
type PerformanceTimer
    str: operation
    float?: start

    fun _enter()
        self.start = time.now()
        self
    end

    fun _exit()
        let duration = time.now() - self.start
        log.info(self.operation .. " completed in " .. duration .. "s")
    end
end

with PerformanceTimer.new(operation: "Data processing")
    process_large_dataset()
end
```

## Exception Handling

### Basic Exception Safety

`_exit()` is called even when exceptions occur:

```quest
type ResourceLogger
    str: name

    fun _enter()
        puts("Acquired: " .. self.name)
        self
    end

    fun _exit()
        puts("Released: " .. self.name)
    end
end

try
    with ResourceLogger.new(name: "database")
        puts("Working...")
        raise "Something failed"
    end
catch e
    puts("Caught: " .. e.message())
end

# Output:
# Acquired: database
# Working...
# Released: database
# Caught: Something failed
```

### Exception Priority

If `_exit()` raises an exception, it takes precedence:

```quest
type BrokenExit
    fun _enter()
        puts("Enter")
        self
    end

    fun _exit()
        puts("Exit")
        raise "Exit failed"
    end
end

try
    with BrokenExit.new()
        puts("Body")
        raise "Body failed"  # This exception is lost
    end
catch e
    puts("Caught: " .. e.message())
end

# Output:
# Enter
# Body
# Exit
# Caught: Exit failed  (body exception is replaced)
```

**Best practice**: Don't raise exceptions in `_exit()` unless absolutely necessary.

## Variable Scoping

### Variable Binding

The `as` clause binds the result of `_enter()` to a variable:

```quest
with create_context() as ctx
    # ctx is available here
    ctx.do_something()
end
# ctx is no longer accessible here
```

### Variable Shadowing (Python-Compatible)

If a variable with the same name exists, it's saved and restored:

```quest
let x = "outer"

with ValueContext.new(value: "inner") as x
    puts(x)  # "inner"
end

puts(x)  # "outer" (restored)
```

### No Variable Binding

You can use `with` without binding the result:

```quest
with sys.redirect_stdout("/dev/null")
    noisy_function()  # Output suppressed
end
```

## Nested Context Managers

Context managers can be nested:

```quest
use "std/sys"
use "std/io"

let out_buf = io.StringIO.new()
let err_buf = io.StringIO.new()

with sys.redirect_stdout(out_buf)
    with sys.redirect_stderr(err_buf)
        puts("Normal output")
        sys.stderr.write("Error output\n")
    end  # stderr restored
end  # stdout restored

puts("Captured stdout: " .. out_buf.get_value())
puts("Captured stderr: " .. err_buf.get_value())
```

## Built-in Context Managers

### I/O Redirection Guards

```quest
use "std/sys"
use "std/io"

let buffer = io.StringIO.new()

with sys.redirect_stdout(buffer)
    puts("This is captured")
end  # Automatically restored

puts("Captured: " .. buffer.get_value())
```

See [I/O Redirection](../stdlib/sys.md#io-redirection) for more details.

### StringIO (Future)

When StringIO implements the context manager protocol:

```quest
use "std/io"

with io.StringIO.new() as buffer
    buffer.write("Hello World")
    puts(buffer.get_value())
end
```

## Advanced Patterns

### Manual and Automatic APIs

Provide both manual cleanup and context manager:

```quest
type Resource
    bool: closed

    # Manual API
    fun close()
        if not self.closed
            self.cleanup()
            self.closed = true
        end
    end

    # Context manager API
    fun _enter()
        self
    end

    fun _exit()
        self.close()
    end
end

# Manual usage
let res = Resource.new()
try
    res.do_work()
ensure
    res.close()
end

# Automatic usage
with Resource.new() as res
    res.do_work()
end  # Auto-closed
```

### Conditional Cleanup

Only clean up if operation succeeded:

```quest
type ConditionalCleanup
    bool: success

    fun _enter()
        self
    end

    fun _exit()
        if not self.success
            puts("Rolling back changes")
            self.rollback()
        end
    end

    fun mark_success()
        self.success = true
    end
end

with ConditionalCleanup.new() as op
    op.do_work()
    op.mark_success()  # Prevent rollback
end
```

### Multiple Return Values

`_enter()` can return anything:

```quest
type MultiResource
    fun _enter()
        # Return array of resources
        [self.resource1, self.resource2, self.resource3]
    end

    fun _exit()
        self.cleanup_all()
    end
end

with MultiResource.new() as resources
    let r1 = resources.get(0)
    let r2 = resources.get(1)
    # Use resources
end
```

## Best Practices

### ✅ DO

- **Keep `_exit()` simple** - Avoid complex logic or exceptions
- **Make `_exit()` idempotent** - Safe to call multiple times
- **Return `self` from `_enter()`** - Unless you have a specific reason
- **Use for resource management** - Files, connections, locks, temporary states
- **Provide manual API too** - For cases where `with` isn't appropriate

### ❌ DON'T

- **Don't raise in `_exit()`** - It can mask original exceptions
- **Don't rely on return value** - `with` always returns `nil`
- **Don't modify external state unpredictably** - Keep cleanup obvious
- **Don't use for simple functions** - Use regular functions for non-resource code

## Comparison with Try/Ensure

| Feature | `with` statement | `try/ensure` |
|---------|------------------|--------------|
| Setup code | `_enter()` method | Manual setup |
| Cleanup code | `_exit()` method | `ensure` block |
| Reusability | Encapsulated in type | Copy/paste |
| Variable binding | Built-in with `as` | Manual |
| Exception safety | Automatic | Manual |
| Best for | Reusable patterns | One-off cleanup |

**Use `with` when:**
- Pattern is reusable
- Multiple places need same setup/cleanup
- Clean abstraction improves readability

**Use `try/ensure` when:**
- One-off cleanup
- Simple cases
- Don't need reusability

## Return Value

**Important**: The `with` statement is a statement (not an expression) and always returns `nil`:

```quest
let result = with context
    "some value"
end

puts(result)  # nil (not "some value")
```

This matches Python's behavior and reinforces that `with` is for resource management, not value computation.

## Implementation Notes

### Duck Typing

Quest uses duck typing for context managers—no trait or interface is required. Any object with `_enter()` and `_exit()` methods works:

```quest
# This works:
type MyContext
    fun _enter()
        self
    end

    fun _exit()
        nil
    end
end

# No explicit "implements ContextManager" needed
```

### Method Names

Quest uses `_enter` and `_exit` (single underscore) instead of Python's `__enter__` and `__exit__` (double underscore) to match Quest's naming conventions for special methods.

## See Also

- [Exception Handling](exceptions.md) - try/catch/ensure statements
- [I/O Module](../stdlib/io.md) - File I/O and StringIO
- [Sys Module](../stdlib/sys.md) - I/O redirection with guards
- [Types](types.md) - User-defined types

## Examples

### Complete Example: File Context Manager

```quest
type ManagedFile
    str: path
    str: mode
    file?: handle

    fun _enter()
        self.handle = io.open(self.path, self.mode)
        self.handle
    end

    fun _exit()
        if self.handle != nil
            self.handle.close()
            self.handle = nil
        end
    end

    static fun open(path, mode)
        ManagedFile.new(path: path, mode: mode)
    end
end

# Usage
with ManagedFile.open("data.txt", "r") as file
    let content = file.read()
    puts(content)
end  # File automatically closed
```

### Complete Example: Test Output Capture

```quest
use "std/test"
use "std/sys"
use "std/io"

type OutputCapture
    buffer?: original_buffer

    fun _enter()
        self.buffer = io.StringIO.new()
        sys.redirect_stdout(self.buffer)
        self.buffer
    end

    fun _exit()
        sys.redirect_stdout(sys.stdout)
    end
end

test.it("captures output", fun ()
    with OutputCapture.new() as buffer
        puts("Test output")
        my_function()
    end  # stdout restored

    let output = buffer.get_value()
    test.assert(output.contains("Test output"), nil)
end)
```
