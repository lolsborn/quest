# QEP-011: with Statement (Context Managers)

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** QEP-010 (I/O Redirection)

## Abstract

This QEP specifies the `with` statement for Quest, enabling automatic resource management through the context manager protocol. Any object implementing `_enter()` and `_exit()` methods can be used with the `with` statement.

## Motivation

Resource management often requires setup and cleanup steps that must happen even when exceptions occur:

```quest
# Without 'with' - manual cleanup
let file = io.open("data.txt", "r")
try
    let data = file.read()
    process(data)
ensure
    file.close()  # Must remember to close
end

# With 'with' - automatic cleanup
with io.open("data.txt", "r") as file
    let data = file.read()
    process(data)
end  # Automatically closes
```

**Benefits:**
1. **Exception safety** - Cleanup always happens
2. **Less boilerplate** - No manual `try/ensure` needed
3. **Clear intent** - Resource lifetime is explicit
4. **Composable** - Nest multiple context managers
5. **Extensible** - Users can define their own

## Design Philosophy

**Principle 1: Duck Typed Protocol**
- No trait required in Rust
- Any object with `_enter()` and `_exit()` methods works
- Simple to implement in both Rust and Quest

**Principle 2: Python-Compatible**
- Familiar to Python developers
- `_enter()` and `_exit()` match Python's `__enter__`/`__exit__`
- Similar semantics and behavior

**Principle 3: Python-Compatible Behavior**
- `with` is a statement, not an expression (returns nil)
- Variable shadowing follows Python semantics
- `_exit()` always called, even on exception
- Exceptions propagate after `_exit()` returns

**Principle 4: Optional Variable Binding**
- `with expr` - Use expression result in block
- `with expr as var` - Bind `_enter()` result to variable
- Variable shadows outer scope, restored after block

## Syntax

### Basic Form

```quest
with <expression>
    <statements>
end
```

### With Variable Binding

```quest
with <expression> as <identifier>
    <statements>
end
```

### Multiple Context Managers

```quest
# Nested form
with ctx1
    with ctx2
        <statements>
    end
end

# Future: Compact form (not in initial implementation)
# with ctx1, ctx2
#     <statements>
# end
```

## Semantics

### Execution Flow

```quest
with expression as var
    body
end
```

Equivalent to (Python-compatible):

```quest
let __ctx = expression
let __saved_var = var  # Save if var exists
let var = __ctx._enter()
try
    body
ensure
    __ctx._exit()
    del var  # Remove from scope
    # Restore __saved_var if it existed
end
```

**Note**: Following Python semantics, the `with` statement is a **statement**, not an expression, and always returns `nil`.

### Detailed Steps

1. **Evaluate expression** - Create context manager object
2. **Save shadowed variable** - If `as` variable exists, save its current value
3. **Call `_enter()`** - Setup phase, returns value for `as` binding
4. **Bind `as` variable** - Store `_enter()` result in scope
5. **Execute body** - Run statements in block
6. **Call `_exit()`** - Cleanup phase (always runs, even on exception)
7. **Restore variable scope** - Remove `as` binding, restore shadowed variable if any
8. **Propagate exception** - If body raised exception, re-raise after `_exit()`
9. **Return nil** - The `with` statement always returns nil (Python-compatible)

### Exception Handling

**If body raises exception:**
```quest
with ctx
    raise "Error"
end
```

1. Exception occurs in body
2. `ctx._exit()` is called
3. Exception propagates after `_exit()` returns
4. If `_exit()` itself raises, that exception takes precedence

**If `_exit()` raises:**
```quest
# Body succeeds, but _exit fails
with ctx
    puts("Success")
end  # ctx._exit() raises exception
```

The exception from `_exit()` propagates normally.

## Scope and Variable Behavior

### Return Value (Python-Compatible)

Following Python's design, the `with` statement is a **statement**, not an expression, and always returns `nil`:

```quest
# In Python, this would be a syntax error:
# result = with ctx: ...

# In Quest, it's allowed but always returns nil
let result = with ctx
    "some value"
end

puts(result)  # nil (not "some value")
```

**Rationale**: Consistent with Python's design philosophy that resource management statements should not be used for value computation.

### Variable Binding with `as`

The `as` clause binds the result of `_enter()` to a variable in the current scope:

```quest
with ctx as x
    # x is available here
    puts(x)
end
# x is no longer available
puts(x)  # Error: Undefined variable 'x'
```

### Variable Shadowing (Python-Compatible)

If an `as` variable shadows an existing variable, the original is **saved and restored** after the block:

```quest
let x = "outer"

with ctx as x
    puts(x)  # Context manager value from _enter()
end

# x is restored to original value
puts(x)  # "outer"
```

This matches Python's behavior:
```python
x = "outer"
with ctx as x:
    print(x)  # Context manager value
print(x)  # "outer" (restored)
```

### Variable Lifetime

The `as` variable is removed after the `with` block, even if an exception occurs:

```quest
with ctx as x
    puts(x)  # Works
    raise "Error"
end  # x is removed before exception propagates

# Exception has propagated, x is gone
```

### Implementation Notes

The implementation must:
1. Check if `as` variable exists in current scope
2. If yes, save its value
3. Bind `_enter()` result to variable
4. After `_exit()`, restore saved value or remove variable
5. This happens even if exceptions occur

## Context Manager Protocol

### Required Methods

Any object can be a context manager by implementing:

#### `_enter() → Any`

Called when entering `with` block.

**Returns:** Value to bind to `as` variable (often `self`)

**Example:**
```quest
type FileContext
    file: file_obj

    fun _enter()
        puts("Opening file")
        self  # Return self for 'as' binding
    end
end
```

#### `_exit() → Nil`

Called when exiting `with` block (even on exception).

**Returns:** Nil (future: Bool to suppress exceptions)

**Example:**
```quest
type FileContext
    file: file_obj

    fun _exit()
        puts("Closing file")
        self.file.close()
    end
end
```

### Optional: Manual Cleanup Method

Context managers often provide a manual cleanup method for Phase 1 usage:

```quest
type FileContext
    file: file_obj

    # Context manager protocol
    fun _enter()
        self
    end

    fun _exit()
        self.close()
    end

    # Manual API
    fun close()
        if not self.file.is_closed()
            self.file.close()
        end
    end
end

# Manual usage
let ctx = FileContext.new(...)
try
    # work
ensure
    ctx.close()
end

# Automatic usage
with FileContext.new(...) as ctx
    # work
end  # Auto-closes
```

## Complete Examples

### Example 1: File Context Manager

```quest
type FileContext
    file: file_obj

    fun _enter()
        self.file
    end

    fun _exit()
        self.file.close()
    end

    static fun open(path, mode)
        let f = io.open(path, mode)
        FileContext.new(file: f)
    end
end

# Usage
with FileContext.open("data.txt", "r") as f
    let content = f.read()
    puts(content)
end  # File automatically closed
```

### Example 2: Timer Context Manager

```quest
use "std/time"

type Timer
    str: label
    float?: start_time

    fun _enter()
        self.start_time = time.now()
        puts("Timer started: " .. self.label)
        self
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

### Example 3: Database Transaction

```quest
type Transaction
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
        puts("Transaction committed")
    end
end

# Usage
with db.begin_transaction() as tx
    db.execute("INSERT INTO users VALUES (?)", ["Alice"])
    db.execute("INSERT INTO posts VALUES (?)", ["Post 1"])
    tx.commit()  # Explicit commit
end  # Rolls back if not committed
```

### Example 4: Temporary Directory

```quest
type TempDir
    str?: path

    fun _enter()
        self.path = os.mkdtemp()
        self.path
    end

    fun _exit()
        if self.path != nil
            os.rmdir(self.path)
            self.path = nil
        end
    end
end

# Usage
with TempDir.new() as tmpdir
    let file_path = tmpdir .. "/data.txt"
    io.write(file_path, "temp data")
    process_file(file_path)
end  # Directory automatically deleted
```

### Example 5: Nested Context Managers

```quest
# Nested with statements
with sys.redirect_stdout(buffer1)
    puts("Outer")

    with sys.redirect_stdout(buffer2)
        puts("Inner")
    end  # Restores to buffer1

    puts("Outer again")
end  # Restores to console

test.assert_eq(buffer1.get_value(), "Outer\nOuter again\n", nil)
test.assert_eq(buffer2.get_value(), "Inner\n", nil)
```

### Example 6: Exception Handling

```quest
type ResourceContext
    str: name

    fun _enter()
        puts("Acquired: " .. self.name)
        self
    end

    fun _exit()
        puts("Released: " .. self.name)
    end
end

# _exit() called even on exception
try
    with ResourceContext.new(name: "database")
        puts("Using resource")
        raise "Error occurred"
    end
catch e
    puts("Caught: " .. e.message())
end

# Output:
# Acquired: database
# Using resource
# Released: database
# Caught: Error occurred
```

### Example 7: Without Variable Binding

```quest
# When you don't need the context manager result
with sys.redirect_stdout("/dev/null")
    noisy_function()
end  # Output suppressed
```

## Grammar

```pest
// In quest.pest

with_statement = {
    "with" ~ expression ~ (as_clause)? ~ newline ~
    statement* ~
    "end"
}

as_clause = { "as" ~ identifier }

statement = _{
    let_statement
  | assignment
  | if_statement
  | while_statement
  | for_statement
  | with_statement  // Add to statement alternatives
  | try_statement
  | function_call
  | expression
}
```

## Implementation

### Evaluator Logic

```rust
// In eval_pair

Rule::with_statement => {
    let mut inner = pair.into_inner();

    // 1. Evaluate the context manager expression
    let ctx_expr = inner.next().unwrap();
    let ctx_manager = eval_pair(ctx_expr, scope)?;

    // 2. Check for 'as' clause and collect statements
    let mut as_var = None;
    let mut statements = Vec::new();

    for item in inner {
        match item.as_rule() {
            Rule::as_clause => {
                let var_name = item.into_inner().next().unwrap().as_str();
                as_var = Some(var_name.to_string());
            }
            _ => statements.push(item),
        }
    }

    // 3. Save shadowed variable if 'as' clause present (Python-compatible)
    let saved_var = if let Some(ref var_name) = as_var {
        scope.variables.get(var_name).cloned()
    } else {
        None
    };

    // 4. Call _enter() on the context manager
    let enter_result = call_method_on_value(&ctx_manager, "_enter", vec![], scope)?;

    // 5. Bind result to variable if 'as' clause present
    if let Some(ref var_name) = as_var {
        scope.variables.insert(var_name.clone(), enter_result);
    }

    // 6. Execute block (with exception handling)
    let mut exception = None;

    for stmt in statements {
        match eval_pair(stmt, scope) {
            Ok(_val) => {}, // Ignore return value (Python-compatible)
            Err(e) => {
                exception = Some(e);
                break;
            }
        }
    }

    // 7. Always call _exit() (even if exception occurred)
    let exit_result = call_method_on_value(&ctx_manager, "_exit", vec![], scope);

    // 8. Restore variable scope (Python-compatible)
    if let Some(var_name) = as_var {
        if let Some(saved) = saved_var {
            // Restore shadowed variable
            scope.variables.insert(var_name, saved);
        } else {
            // Remove variable (it didn't exist before)
            scope.variables.remove(&var_name);
        }
    }

    // 9. Handle exceptions
    // If _exit() raised, that takes precedence
    if let Err(exit_err) = exit_result {
        return Err(exit_err);
    }

    // Otherwise, re-raise original exception if any
    if let Some(e) = exception {
        return Err(e);
    }

    // 10. Always return nil (Python-compatible)
    Ok(QValue::Nil(QNil))
}
```

### Helper Function

A generic helper function is needed to call methods on any QValue type:

```rust
// Call method on any QValue (add to main.rs or utils module)
fn call_method_on_value(
    value: &QValue,
    method_name: &str,
    args: Vec<QValue>,
    scope: &mut Scope
) -> Result<QValue, String> {
    match value {
        QValue::Struct(s) => {
            s.call_method(method_name, args, scope)
        }
        QValue::Int(i) => {
            i.call_method(method_name, args)
        }
        QValue::Float(f) => {
            f.call_method(method_name, args)
        }
        QValue::Str(s) => {
            s.call_method(method_name, args)
        }
        QValue::Array(a) => {
            a.call_method(method_name, args)
        }
        QValue::Dict(d) => {
            d.call_method(method_name, args)
        }
        QValue::File(f) => {
            f.call_method(method_name, args, scope)
        }
        // Add all other QValue types that have methods
        _ => Err(format!(
            "{} object has no method '{}'",
            value.cls(),
            method_name
        ))
    }
}
```

**Note**: This helper should be added to Quest's core functionality as it's useful beyond just the `with` statement.

## Error Handling

### Missing Methods

```quest
# Object doesn't have _enter
with "not a context manager"
    puts("Body")
end
# Error: Str object has no method '_enter'
```

### Exception in _enter()

```quest
type BrokenContext
    fun _enter()
        raise "Enter failed"
    end

    fun _exit()
        puts("Exit called")
    end
end

with BrokenContext.new()
    puts("Body")
end
# Error: Enter failed
# Note: _exit() is NOT called (never entered)
```

### Exception in Body

```quest
type SafeContext
    fun _enter()
        puts("Entered")
        self
    end

    fun _exit()
        puts("Exited")
    end
end

try
    with SafeContext.new()
        puts("Body")
        raise "Body failed"
    end
catch e
    puts("Caught: " .. e.message())
end

# Output:
# Entered
# Body
# Exited
# Caught: Body failed
```

### Exception in _exit()

```quest
type BrokenExit
    fun _enter()
        puts("Entered")
        self
    end

    fun _exit()
        puts("Exiting")
        raise "Exit failed"
    end
end

try
    with BrokenExit.new()
        puts("Body succeeded")
    end
catch e
    puts("Caught: " .. e.message())
end

# Output:
# Entered
# Body succeeded
# Exiting
# Caught: Exit failed
```

## Testing Strategy

```quest
# test/with_statement_test.q
use "std/test"

test.module("with Statement")

test.describe("Basic with statement", fun ()
    test.it("calls _enter and _exit", fun ()
        let calls = []

        type TestContext
            array: calls

            fun _enter()
                self.calls.push("enter")
                self
            end

            fun _exit()
                self.calls.push("exit")
            end
        end

        with TestContext.new(calls: calls)
            calls.push("body")
        end

        test.assert_eq(calls, ["enter", "body", "exit"])    end)

    test.it("binds value with 'as' clause", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let result = nil
        with ValueContext.new(value: "test") as val
            result = val
        end

        test.assert_eq(result, "test")    end)
end)

test.describe("Exception handling", fun ()
    test.it("calls _exit on exception", fun ()
        let calls = []

        type CleanupContext
            array: calls

            fun _enter()
                self
            end

            fun _exit()
                self.calls.push("exited")
            end
        end

        try
            with CleanupContext.new(calls: calls)
                raise "Test error"
            end
        catch e
            # Ignore
        end

        test.assert(calls.contains("exited"), "_exit should have been called")
    end)

    test.it("propagates exception after _exit", fun ()
        type SimpleContext
            fun _enter()
                self
            end

            fun _exit()
                nil
            end
        end

        let caught = false
        try
            with SimpleContext.new()
                raise "Test error"
            end
        catch e
            caught = true
            test.assert_eq(e.message(), "Test error", nil)
        end

        test.assert(caught, "Exception should propagate")
    end)
end)

test.describe("Nested with statements", fun ()
    test.it("handles nested contexts correctly", fun ()
        let order = []

        type OrderedContext
            array: order
            str: name

            fun _enter()
                self.order.push("enter_" .. self.name)
                self
            end

            fun _exit()
                self.order.push("exit_" .. self.name)
            end
        end

        with OrderedContext.new(order: order, name: "outer")
            with OrderedContext.new(order: order, name: "inner")
                order.push("body")
            end
        end

        test.assert_eq(order, [
            "enter_outer",
            "enter_inner",
            "body",
            "exit_inner",
            "exit_outer"
        ])    end)
end)

test.describe("Missing methods", fun ()
    test.it("errors if _enter is missing", fun ()
        type NoEnter
            fun _exit()
                nil
            end
        end

        test.assert_raises(fun ()
            with NoEnter.new()
                puts("Body")
            end
        end, "has no method '_enter'")
    end)

    test.it("errors if _exit is missing", fun ()
        type NoExit
            fun _enter()
                self
            end
        end

        test.assert_raises(fun ()
            with NoExit.new()
                puts("Body")
            end
        end, "has no method '_exit'")
    end)
end)

test.describe("Variable shadowing (Python-compatible)", fun ()
    test.it("restores shadowed variable", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        let x = "outer"
        with ValueContext.new(value: "inner") as x
            test.assert_eq(x, "inner", "Should shadow with inner value")
        end
        test.assert_eq(x, "outer", "Should restore outer value")
    end)

    test.it("removes new variable after block", fun ()
        type ValueContext
            str: value

            fun _enter()
                self.value
            end

            fun _exit()
                nil
            end
        end

        with ValueContext.new(value: "temp") as y
            test.assert_eq(y, "temp", "Variable should exist in block")
        end

        # y should not exist after block
        test.assert_raises(fun ()
            puts(y)
        end, "Undefined variable")
    end)
end)

test.describe("Return value (Python-compatible)", fun ()
    test.it("always returns nil", fun ()
        type SimpleContext
            fun _enter()
                self
            end

            fun _exit()
                nil
            end
        end

        let result = with SimpleContext.new()
            "some value"
        end

        test.assert_eq(result, nil, "with statement should return nil")
    end)
end)
```

## Edge Cases

### `_enter()` Returns Different Value

The `as` variable is bound to the **return value of `_enter()`**, not the context manager itself:

```quest
type Wrapper
    str: inner_value

    fun _enter()
        # Return inner value, not self
        self.inner_value
    end

    fun _exit()
        nil
    end
end

with Wrapper.new(inner_value: "hello") as val
    puts(val)  # "hello" (not the Wrapper object)
    puts(val.cls())  # "Str" (not "Wrapper")
end
```

### Empty `with` Block

An empty `with` block still calls `_enter()` and `_exit()`:

```quest
type TracingContext
    fun _enter()
        puts("Entered")
        self
    end

    fun _exit()
        puts("Exited")
    end
end

with TracingContext.new()
    # Empty block
end

# Output:
# Entered
# Exited
```

### `with` Without `as` Clause

You can use `with` without binding the result:

```quest
type SideEffectContext
    fun _enter()
        puts("Setup")
        nil  # Return value ignored
    end

    fun _exit()
        puts("Cleanup")
    end
end

with SideEffectContext.new()
    puts("Body")
end

# Output:
# Setup
# Body
# Cleanup
```

### Multiple `with` Statements in Sequence

Each `with` is independent:

```quest
with ctx1 as x
    puts(x)
end  # x removed

with ctx2 as x
    puts(x)  # Different x (no relation to first)
end  # x removed
```

## Integration with Existing Features

### I/O Redirection (QEP-010)

```quest
use "std/sys"
use "std/io"

# RedirectGuard implements context manager protocol
with sys.redirect_stdout(buffer)
    puts("Captured")
end

# Works because RedirectGuard has:
# - _enter() → returns self
# - _exit() → calls restore()
```

### File Objects

```quest
# Future: io.open returns context manager
with io.open("data.txt", "r") as file
    let content = file.read()
end  # Auto-closes
```

### Database Connections

```quest
# Future: Database connections as context managers
with db.connect("postgresql://...") as conn
    with conn.cursor() as cur
        cur.execute("SELECT * FROM users")
        let rows = cur.fetch_all()
    end
end  # Auto-closes cursor and connection
```

## Performance Considerations

The `with` statement has minimal overhead:

1. **Method call overhead** - Two method calls (`_enter()` and `_exit()`) per `with` block
2. **Variable management** - O(1) operations for saving/restoring/removing variables
3. **Exception handling** - Always uses exception tracking internally (negligible overhead)
4. **Nested contexts** - Each nesting level adds the above overhead independently

**Recommendations:**
- Use `with` for resources that need cleanup (files, locks, connections)
- Don't avoid `with` for performance reasons - overhead is negligible
- The safety guarantees outweigh any minimal performance cost

**Benchmark comparison** (hypothetical):
```quest
# Manual cleanup: ~1000ns overhead (try/ensure)
let ctx = setup()
try
    work()
ensure
    cleanup(ctx)
end

# with statement: ~1200ns overhead (try/ensure + method calls)
with ctx
    work()
end

# Difference: ~200ns (0.0002ms) - negligible for resource management
```

## Future Enhancements

### Phase 2: Exception Suppression

Allow `_exit()` to suppress exceptions by returning `true`:

```rust
fun _exit()
    if recoverable_error
        return true  # Suppress exception
    end
    false  # Propagate exception
end
```

### Phase 3: Multiple Context Managers

Compact syntax for multiple context managers:

```quest
with ctx1, ctx2, ctx3
    # All entered in order
    # All exited in reverse order
end
```

### Phase 4: Exception Info in _exit()

Pass exception information to `_exit()`:

```quest
fun _exit(exc_type, exc_value, exc_traceback)
    if exc_type != nil
        log.error("Exception occurred: " .. exc_value)
    end
    false  # Don't suppress
end
```

## Implementation Checklist

### Grammar (quest.pest)
- [ ] Add `with_statement` rule to quest.pest
- [ ] Add `as_clause` rule to quest.pest
- [ ] Add `with_statement` to statement alternatives

### Core Implementation (main.rs)
- [ ] Add `call_method_on_value()` helper function
- [ ] Implement `with_statement` evaluation in eval_pair
- [ ] Save shadowed `as` variable before `_enter()` (Python-compatible)
- [ ] Call `_enter()` and bind result to `as` variable
- [ ] Execute block with exception handling
- [ ] Always call `_exit()` after block (even on exception)
- [ ] Restore shadowed variable or remove new variable (Python-compatible)
- [ ] Handle exception priority (_exit() exception takes precedence)
- [ ] Always return nil from `with` statement (Python-compatible)

### Testing (test/with_statement_test.q)
- [ ] Test basic `_enter()` and `_exit()` calls
- [ ] Test `as` variable binding
- [ ] Test exception handling (_exit() always called)
- [ ] Test exception propagation
- [ ] Test nested `with` statements
- [ ] Test missing `_enter()` method error
- [ ] Test missing `_exit()` method error
- [ ] Test variable shadowing (Python-compatible)
- [ ] Test new variable removal after block
- [ ] Test return value is always nil (Python-compatible)

### Documentation
- [ ] Update CLAUDE.md with `with` statement documentation
- [ ] Add context manager examples to standard library modules
- [ ] Document Python compatibility notes

## Conclusion

The `with` statement provides automatic resource management through a simple duck-typed protocol. Any object implementing `_enter()` and `_exit()` methods can be used as a context manager, making it easy to ensure cleanup happens even when exceptions occur.

**Key Benefits:**
- **Simple protocol** - Just two methods: `_enter()` and `_exit()`
- **Duck typed** - No trait required, works with any object
- **Exception safe** - `_exit()` always called
- **Python-compatible** - Follows Python semantics for shadowing and return values
- **Extensible** - Users can define their own context managers

**Python Compatibility Notes:**
- ✅ `with` is a statement, always returns nil
- ✅ Variable shadowing: saves and restores outer variables
- ✅ Exception handling: `_exit()` always called
- ✅ Method names: `_enter()` and `_exit()` (vs Python's `__enter__`/`__exit__`)

**Example:**
```quest
# Any object with _enter() and _exit() works
with my_context_manager as ctx
    # Setup happens in _enter()
    work_with(ctx)
    # Cleanup happens in _exit() (even on exception)
end
# ctx is removed, shadowed variable restored
```

This provides the foundation for QEP-010 (I/O Redirection) and future resource management features.
