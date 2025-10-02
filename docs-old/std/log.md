# Log Module

The `log` module provides a flexible logging framework for Quest, inspired by Python's `logging` module. It supports multiple log levels, configurable formatting, and custom output handlers.

## Log Levels

The module defines five standard log levels (in ascending order of severity):

| Level    | Numeric Value | Description                              |
|----------|---------------|------------------------------------------|
| DEBUG    | 10            | Detailed diagnostic information          |
| INFO     | 20            | Confirmation that things are working     |
| WARNING  | 30            | Something unexpected happened            |
| ERROR    | 40            | A serious problem occurred               |
| CRITICAL | 50            | A critical failure that may stop program |

## Basic Logging

### `log.debug(message)`
Log a debug-level message

**Parameters:**
- `message` - Message to log (Str)

**Example:**
```quest
use "std/log" as log

log.debug("Variable x = " .. x._str())
log.debug("Entering function process_data()")
```

### `log.info(message)`
Log an info-level message

**Parameters:**
- `message` - Message to log (Str)

**Example:**
```quest
log.info("Application started successfully")
log.info("Processing 1000 records")
```

### `log.warning(message)`
Log a warning-level message

**Parameters:**
- `message` - Message to log (Str)

**Example:**
```quest
log.warning("Configuration file not found, using defaults")
log.warning("API rate limit approaching")
```

### `log.error(message)`
Log an error-level message

**Parameters:**
- `message` - Message to log (Str)

**Example:**
```quest
log.error("Failed to connect to database")
log.error("Invalid input: " .. input._str())
```

### `log.critical(message)`
Log a critical-level message

**Parameters:**
- `message` - Message to log (Str)

**Example:**
```quest
log.critical("Disk space exhausted")
log.critical("System shutdown initiated")
```

### `log.exception(message, exc)`
Log an exception at ERROR level. This is typically used in exception handlers. When an exception object is provided, includes the exception type, message, and stack trace (when available).

**Parameters:**
- `message` - Log message (Str)
- `exc` - Optional exception object (Exception or nil)

**Note:** Like Python's `logging.exception()`, this function is designed to include stack traces. Quest has exception support with `try/catch/raise`, and the infrastructure for stack traces exists, but stack traces are not yet automatically populated at runtime. When this is implemented, `log.exception()` will automatically include them.

**Example:**
```quest
# Simple usage (no exception object)
log.exception("Operation failed", nil)

# With exception object - includes type and message
try
    risky_operation()
catch e
    log.exception("Caught error in operation", e)
    # Logs: "Caught error in operation [Error: message]"
end

# Future: When stack traces are populated
try
    nested_function_call()
catch e
    log.exception("Error in nested call", e)
    # Will log with full stack trace showing call chain
end
```

## Configuration

### `log.set_level(level)`
Set the minimum log level. Only messages at or above this level will be output.

**Parameters:**
- `level` - Minimum level (Num or Str): Can be numeric (10, 20, 30, 40, 50) or constant name ("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL")

**Example:**
```quest
# Set to INFO level - debug messages won't appear
log.set_level(log.INFO)
log.set_level(20)           # Same as above
log.set_level("INFO")       # Also same

# Set to DEBUG level - all messages appear
log.set_level(log.DEBUG)

# Set to ERROR level - only errors and critical messages
log.set_level(log.ERROR)
```

### `log.get_level()`
Get the current minimum log level

**Returns:** Current level (Num)

**Example:**
```quest
let current = log.get_level()
puts("Current log level: " .. current._str())
```

### `log.set_format(format_string)`
Set the format string for log messages

**Parameters:**
- `format_string` - Format template (Str) with placeholders:
  - `%(time)` - Timestamp (YYYY-MM-DD HH:MM:SS format)
  - `%(level)` - Level name (DEBUG, INFO, WARNING, ERROR, CRITICAL)
  - `%(levelnum)` - Level number (10, 20, 30, 40, 50)
  - `%(message)` - The actual log message

**Default Format:** `"%(time) [%(level)] %(message)"`

**Example:**
```quest
# Simple format
log.set_format("[%(level)] %(message)")

# Detailed format
log.set_format("%(time) [%(levelnum)] %(level): %(message)")

# Minimal format
log.set_format("%(level): %(message)")
```

### `log.get_format()`
Get the current format string

**Returns:** Current format (Str)

**Example:**
```quest
let fmt = log.get_format()
puts("Current format: " .. fmt)
```

## Advanced Configuration

### `log.enable_colors(enabled)`
Enable or disable colored output (uses std/term module)

**Parameters:**
- `enabled` - Whether to use colors (Bool)

**Default:** `true`

**Note:** Due to a current limitation in Quest's module system, this function may not work as expected. Colors are enabled by default. As a workaround, you can use custom format strings without color codes or redirect output through a handler that strips ANSI codes.

**Example:**
```quest
# Disable colors for log files (currently not working)
log.enable_colors(false)

# Workaround: Use a simple format without relying on color disabling
log.set_format("[%(level)] %(message)")
```

### `log.set_output(handler_fn)`
Set a custom output handler function

**Parameters:**
- `handler_fn` - Function that receives formatted log messages (Fun)

**Default:** Outputs to stdout using `puts()`

**Example:**
```quest
# Custom handler that writes to file
let log_file = io.open("app.log", "a")
log.set_output(fun (formatted_message)
    io.append("app.log", formatted_message .. "\n")
end)

# Handler that also prints to console
log.set_output(fun (formatted_message)
    puts(formatted_message)
    io.append("app.log", formatted_message .. "\n")
end)

# Handler for structured logging (JSON)
use "std/encoding/json" as json
log.set_output(fun (formatted_message)
    let record = {
        "timestamp": get_time(),
        "message": formatted_message
    }
    puts(json.stringify(record))
end)
```

### `log.reset()`
Reset logger to default configuration
- Level: INFO
- Format: `"%(time) [%(level)] %(message)"`
- Colors: enabled
- Output: stdout

**Example:**
```quest
log.reset()
```

## Level Constants

The module provides constants for each log level:

```quest
log.DEBUG     # 10
log.INFO      # 20
log.WARNING   # 30
log.ERROR     # 40
log.CRITICAL  # 50
```

These can be used with `set_level()`:

```quest
log.set_level(log.DEBUG)
log.set_level(log.ERROR)
```

## Complete Example

```quest
use "std/log" as log

# Configure logging
log.set_level(log.INFO)
log.set_format("%(time) [%(level)] %(message)")

# Application code
log.info("Application starting")

let config = load_config()
if config == nil
    log.warning("Config not found, using defaults")
    config = default_config()
end

log.debug("Config loaded: " .. config._rep())  # Won't appear (level is INFO)

let result = process_data(config)
if result.is_error()
    log.error("Processing failed: " .. result.error)
else
    log.info("Processing completed successfully")
    log.info("Processed " .. result.count._str() .. " records")
end
```

## Output Examples

With default format `"%(time) [%(level)] %(message)"`:

```
2025-10-01 14:32:15 [INFO] Application starting
2025-10-01 14:32:15 [WARNING] Config not found, using defaults
2025-10-01 14:32:16 [INFO] Processing completed successfully
2025-10-01 14:32:16 [INFO] Processed 1000 records
```

With custom format `"[%(level)] %(message)"`:

```
[INFO] Application starting
[WARNING] Config not found, using defaults
[INFO] Processing completed successfully
[INFO] Processed 1000 records
```

## Color Coding

When colors are enabled (default), log levels are color-coded:
- **DEBUG**: Grey
- **INFO**: Cyan
- **WARNING**: Yellow
- **ERROR**: Red
- **CRITICAL**: Bold Red

## Best Practices

### 1. Set appropriate log levels
```quest
# Development
log.set_level(log.DEBUG)

# Production
log.set_level(log.INFO)

# Critical systems only
log.set_level(log.ERROR)
```

### 2. Use structured messages
```quest
# Good
log.info("User login: " .. user.name .. " from " .. ip)

# Better - easy to parse
log.info("User login | user=" .. user.name .. " | ip=" .. ip)
```

### 3. Log exceptions and errors
```quest
# When handling errors
if not file_exists(path)
    log.error("File not found: " .. path)
    return nil
end
```

### 4. Use debug for verbose diagnostics
```quest
fun process_data(data)
    log.debug("process_data called with " .. data.len()._str() .. " items")

    data.each(fun (item)
        log.debug("Processing item: " .. item.id._str())
        # ...
    end)

    log.debug("process_data completed")
end
```

### 5. Write to files in production
```quest
# Append all logs to file
log.set_output(fun (msg)
    io.append("logs/app.log", msg .. "\n")
end)

# Rotate logs by date
let date = get_current_date()
let log_file = "logs/app-" .. date .. ".log"
log.set_output(fun (msg)
    io.append(log_file, msg .. "\n")
end)
```

## Comparison with Python logging

Quest's logging module is inspired by Python's `logging` module:

| Python                     | Quest                          |
|----------------------------|--------------------------------|
| `logging.debug(msg)`       | `log.debug(msg)`               |
| `logging.info(msg)`        | `log.info(msg)`                |
| `logging.setLevel(level)`  | `log.set_level(level)`         |
| `logging.basicConfig()`    | `log.reset()`                  |
| `logging.DEBUG`            | `log.DEBUG`                    |

Key differences:
- Quest uses module-level functions instead of logger instances
- Quest's format string uses `%(name)` instead of `%(name)s`
- Quest's handler is a simple function, not a class
- Quest integrates with `std/term` for colored output
