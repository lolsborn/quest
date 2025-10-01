# Exception Handling

Quest provides exception handling for error management and recovery using `try`, `catch`, `ensure`, and `raise` keywords.

## Basic Exception Handling

### Try-Catch Block

```
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

```
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

```
if value < 0
    raise "Value cannot be negative"
end
```

### Raise with Exception Type

```
if !user.is_authenticated()
    raise AuthenticationError("User not logged in")
end

if file_size > max_size
    raise ValueError("File too large: " .. file_size .. " bytes")
end
```

### Re-raising Exceptions

```
try
    dangerous_operation()
catch e
    puts("Logging error: ", e.message)
    raise  # Re-raise the same exception
end
```

## Multiple Catch Blocks

Handle different exception types differently:

```
try
    let data = json.parse(user_input)
    process_data(data)
catch e: JsonParseError
    puts("Invalid JSON format")
    return nil
catch e: ValidationError
    puts("Data validation failed: ", e.message)
    return nil
catch e: NetworkError
    puts("Network error occurred: ", e.message)
    return nil
catch e
    # Catch all other exceptions
    puts("Unexpected error: ", e.message)
    raise  # Re-raise if we don't know how to handle it
end
```

## Exception Object

Exception objects have the following properties:

```
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

### Standard Exceptions

- **Error** - Base exception type
- **TypeError** - Type mismatch or invalid type operation
- **ValueError** - Invalid value for operation
- **KeyError** - Dictionary key not found
- **IndexError** - Array index out of bounds
- **ZeroDivisionError** - Division by zero
- **FileNotFoundError** - File doesn't exist
- **PermissionError** - Insufficient permissions
- **NetworkError** - Network-related errors
- **TimeoutError** - Operation timed out
- **ParseError** - Parsing failed
- **JsonParseError** - JSON parsing failed
- **AssertionError** - Assertion failed
- **NotImplementedError** - Feature not implemented

## Custom Exceptions

Define custom exception types:

```
type ValidationError {
    str: message
    str: field
}

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

```
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

```
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

```
fun validate_user_data(data)
    if data == nil
        raise ValueError("User data cannot be nil")
    end

    if !data.has("email")
        raise ValidationError("Missing required field: email")
    end

    if !data.has("name")
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

```
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

```
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

```
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

```
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

```
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

```
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

```
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

```
# Bad: Vague message
raise "Invalid input"

# Good: Specific and actionable
raise ValueError("Email must contain '@' symbol, got: " .. email)
```

### 5. Use Exceptions for Exceptional Cases

```
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

## Grammar Addition

To add exception handling to Quest, the following grammar rules would be added:

```
try_statement = {
    "try" ~ statement* ~ catch_clause+ ~ ensure_clause? ~ "end"
    | "try" ~ statement* ~ ensure_clause ~ "end"
}

catch_clause = {
    "catch" ~ identifier ~ ":" ~ type_expr ~ statement*  // catch e: TypeError
    | "catch" ~ identifier ~ statement*                   // catch e
}

ensure_clause = { "ensure" ~ statement* }

raise_statement = {
    "raise" ~ expression     // raise "error" or raise ExceptionType("message")
    | "raise"                // re-raise current exception
}
```
