# Exception Handling

Quest provides exception handling for error management and recovery using `try`, `catch`, `ensure`, and `raise` keywords.

## Basic Exception Handling

### Try-Catch Block

```quest
try
    # Code that might raise an exception
    let result = risky_operation()
    puts("Success: ", result)
catch e
    # Handle the exception
    puts("Error occurred: ", e.message)
end
```

### Try-Catch-Ensure

The `ensure` block always executes, whether an exception occurs or not:

```quest
try
    file = io.open("data.txt", "r")
    let content = file.read()
    process(content)
catch e
    puts("Failed to read file: ", e.message)
ensure
    # Always runs, even if exception occurs
    if file != nil
        file.close()
    end
end
```

## Raising Exceptions

### Basic Raise

```quest
if value < 0
    raise "Value cannot be negative"
end
```

### Raise with Exception Type

```quest
if !user.is_authenticated()
    raise AuthenticationError("User not logged in")
end

if file_size > max_size
    raise ValueError("File too large: " .. file_size .. " bytes")
end
```

### Re-raising Exceptions

```quest
try
    dangerous_operation()
catch e
    puts("Logging error: ", e.message)
    raise  # Re-raise the same exception
end
```

## Multiple Catch Blocks

Handle different exception types differently using type annotations:

```quest
try
    let data = json.parse(user_input)
    process_data(data)
catch e: ValueErr
    puts("Invalid JSON format: " .. e.message())
    return nil
catch e: TypeErr
    puts("Type error: " .. e.message())
    return nil
catch e: IOErr
    puts("I/O error: " .. e.message())
    return nil
catch e: Err
    # Catch all other exception types
    puts("Unexpected error: " .. e.message())
    raise  # Re-raise if we don't know how to handle it
end
```

The order matters: catch specific exception types first, then more general ones.

## Exception Object

Exception objects have the following properties:

```quest
try
    risky_function()
catch e
    puts("Type:    ", e.type)        # Exception type name
    puts("Message: ", e.message)     # Error message
    puts("Stack:   ", e.stack)       # Stack trace
    puts("Line:    ", e.line)        # Line number where error occurred
    puts("File:    ", e.file)        # File where error occurred
end
```

## Built-in Exception Types

Quest provides a hierarchical exception system where all exception types implement the `Error` trait. This enables both specific and generic error handling through type-based catch clauses.

### Standard Exception Types

All built-in exceptions implement the `Error` trait and can be caught using type annotations:

- **Err** - Base exception type (catches all exceptions)
- **IndexErr** - Sequence index out of range
- **TypeErr** - Wrong type for operation
- **ValueErr** - Invalid value for operation
- **ArgErr** - Wrong number or type of arguments
- **AttrErr** - Object has no attribute or method
- **NameErr** - Name not found in scope
- **RuntimeErr** - Generic runtime error
- **IOErr** - Input/output operation failed
- **ImportErr** - Module import failed
- **KeyErr** - Dictionary key not found

### Creating Typed Exceptions

Use the `.new()` method to create exception instances:

```quest
raise Err.new("Generic error message")
raise IndexErr.new("index out of bounds: 10")
raise TypeErr.new("expected str, got int")
raise ValueErr.new("value must be positive")
raise ArgErr.new("expected 2 arguments, got 3")
raise AttrErr.new("object has no attribute 'foo'")
raise NameErr.new("name 'x' is not defined")
raise RuntimeErr.new("something went wrong")
raise IOErr.new("failed to read file")
raise ImportErr.new("module 'foo' not found")
raise KeyErr.new("key 'config' not found")
```

### Hierarchical Exception Catching

Catch specific exception types or use the base `Err` type to catch all:

```quest
try
    let item = array[10]  # May raise IndexErr
catch e: IndexErr
    puts("Index error: " .. e.message())
catch e: Err
    # Catches all other exception types
    puts("Other error: " .. e.type())
end
```

### Exception Object Methods

All exception objects provide these methods:

```quest
try
    risky_operation()
catch e
    puts(e.type())        # Exception type name (e.g., "IndexErr")
    puts(e.message())     # Error message
    puts(e.stack())       # Stack trace
    puts(e.str())        # String representation
end
```

### Backwards Compatibility

String-based exceptions are still supported and are treated as `RuntimeErr`:

```quest
raise "Something went wrong"  # Equivalent to RuntimeErr.new("Something went wrong")
```

## Custom Exceptions

Define custom exception types:

```quest
type ValidationError
    message: Str
    field: Str
end

fun validate_email(email)
    if !email.contains("@")
        raise ValidationError("Invalid email format", email)
    end
end

try
    validate_email(user_input)
catch e: ValidationError
    puts("Field '", e.field, "' is invalid: ", e.message)
end
```

## Exception Chaining

Preserve the original exception when raising a new one:

```quest
try
    let data = load_data()
    process_data(data)
catch e: FileNotFoundError
    # Chain the original exception
    raise ProcessingError("Failed to process data", e)
end

# Later, you can inspect the chain:
catch e: ProcessingError
    puts("Error: ", e.message)
    puts("Caused by: ", e.cause.message)
end
```

## Pattern: Resource Management

Ensure resources are cleaned up:

```quest
fun read_file_safely(path)
    let file = nil
    try
        file = io.open(path, "r")
        return file.read()
    catch e: FileNotFoundError
        puts("File not found: ", path)
        return nil
    catch e: PermissionError
        puts("Permission denied: ", path)
        return nil
    ensure
        if file != nil
            file.close()
        end
    end
end
```

## Pattern: Validation with Exceptions

```quest
fun validate_user_data(data)
    if data == nil
        raise ValueError("User data cannot be nil")
    end

    if !data.contains("email")
        raise ValidationError("Missing required field: email")
    end

    if !data.contains("name")
        raise ValidationError("Missing required field: name")
    end

    if data.email.len() < 5
        raise ValidationError("Email too short")
    end

    return true
end

try
    validate_user_data(user_input)
    save_user(user_input)
    puts("User saved successfully")
catch e: ValidationError
    puts("Validation failed: ", e.message)
    show_error_to_user(e.message)
catch e
    puts("Unexpected error: ", e.message)
    log_error(e)
end
```

## Pattern: Graceful Degradation

```quest
fun fetch_user_avatar(user_id)
    try
        return api.get_avatar(user_id)
    catch e: NetworkError
        puts("Network error, using default avatar")
        return default_avatar
    catch e: TimeoutError
        puts("Request timed out, using cached avatar")
        return cache.get_avatar(user_id, default_avatar)
    end
end
```

## Pattern: Transaction Rollback

```quest
fun transfer_funds(from_account, to_account, amount)
    let transaction = db.begin_transaction()

    try
        from_account.withdraw(amount)
        to_account.deposit(amount)
        transaction.commit()
        puts("Transfer successful")
    catch e
        transaction.rollback()
        puts("Transfer failed, rolled back: ", e.message)
        raise
    ensure
        transaction.close()
    end
end
```

## Pattern: Logging and Re-raising

```quest
fun critical_operation()
    try
        perform_operation()
    catch e
        # Log the error
        logger.error("Critical operation failed", {
            "error": e.message,
            "type": e.type,
            "stack": e.stack
        })

        # Send alert
        alerts.send_critical_error(e)

        # Re-raise to let caller handle it
        raise
    end
end
```

## Pattern: Timeout Protection

```quest
fun fetch_with_timeout(url, timeout_seconds)
    let timer = time.start_timer(timeout_seconds)

    try
        return http.get(url)
    catch e: TimeoutError
        puts("Request timed out after ", timeout_seconds, " seconds")
        return nil
    ensure
        timer.cancel()
    end
end
```

## Best Practices

### 1. Be Specific with Exception Types

```quest
# Bad: Too generic
try
    process_data()
catch e
    # What went wrong?
    puts("Error")
end

# Good: Handle specific cases
try
    process_data()
catch e: ValidationError
    handle_validation_error(e)
catch e: NetworkError
    handle_network_error(e)
catch e: FileNotFoundError
    handle_missing_file(e)
catch e
    # Only catch unexpected errors here
    log_unexpected_error(e)
    raise
end
```

### 2. Don't Swallow Exceptions Silently

```quest
# Bad: Silent failure
try
    important_operation()
catch e
    # Nothing - error disappears
end

# Good: At least log it
try
    important_operation()
catch e
    logger.error("Operation failed: ", e.message)
    # Or provide fallback behavior
end
```

### 3. Clean Up Resources

```quest
# Always use ensure for cleanup
try
    connection = db.connect()
    perform_queries(connection)
catch e
    puts("Database error: ", e.message)
ensure
    if connection != nil
        connection.close()
    end
end
```

### 4. Provide Context in Error Messages

```quest
# Bad: Vague message
raise "Invalid input"

# Good: Specific and actionable
raise ValueError("Email must contain '@' symbol, got: " .. email)
```

### 5. Use Exceptions for Exceptional Cases

```quest
# Bad: Using exceptions for control flow
try
    find_user(id)
catch e: NotFoundError
    # Expected case, shouldn't use exception
    create_user(id)
end

# Good: Use return values for expected cases
let user = find_user(id)
if user == nil
    user = create_user(id)
end
```