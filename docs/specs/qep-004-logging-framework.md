# QEP 4 - Quest Logging Framework Specification v1.0

## Abstract

This QEP (Quest Enhancement Proposal) describes the Quest Logging Framework. The purpose of this specification is to provide a flexible, hierarchical logging system for Quest applications with support for multiple output destinations, custom formatting, and runtime configuration.

This specification is inspired by [Python's logging module](https://docs.python.org/3/library/logging.html) and adapted to conform to Quest's syntax, type system, and language features.

## Rationale

Logging is essential for debugging, monitoring, and understanding application behavior. A well-designed logging framework should:

1. Support hierarchical loggers (e.g., "app", "app.db", "app.db.query")
2. Allow different log levels (DEBUG, INFO, WARNING, ERROR, CRITICAL)
3. Enable multiple output destinations (console, files, network)
4. Support custom formatting per destination
5. Be configurable at runtime via `.settings.toml`
6. Maintain simplicity for basic use cases while supporting advanced patterns

## Architecture Overview

The Quest logging framework consists of five core components:

1. **LogRecord** - Immutable data structure representing a single log event
2. **Formatter** - Converts LogRecords to formatted strings
3. **Handler** - Dispatches formatted logs to destinations (console, file, etc.)
4. **Filter** - Performs arbitrary filtering of log records
5. **Logger** - Main API for creating log messages, organized hierarchically

## Log Levels

The framework defines five standard log levels:

| Level    | Numeric Value | Usage                                      |
|----------|---------------|--------------------------------------------|
| DEBUG    | 10            | Detailed diagnostic information            |
| INFO     | 20            | General informational messages             |
| WARNING  | 30            | Warning messages (potential issues)        |
| ERROR    | 40            | Error messages (failures)                  |
| CRITICAL | 50            | Critical errors (may cause shutdown)       |

Additional level `NOTSET` (0) indicates no level is set (inherit from parent).

## Core Types

### LogRecord Type

Represents a single log event with all metadata:

```quest
type LogRecord
    str: name                    # Logger name (e.g., "app.db")
    int: level_no                # 10, 20, 30, 40, 50
    str: level_name              # "DEBUG", "INFO", etc.
    str: message                 # Formatted message
    str: pathname                # Full path to source file
    str: filename                # Just filename
    str?: module                 # Module name
    int?: line_no                # Line number
    int?: func_name              # Function name
    float: created               # Timestamp (seconds since epoch)
    float: relative_created      # Milliseconds since logger startup
    exception?: exc_info         # Quest exception object (or nil)
    str?: exc_text               # Cached exception text
    str?: stack_info             # Stack trace string

    fun get_message()
        self.message
    end
end
```

### Formatter Type

Converts LogRecords to formatted strings:

```quest
type Formatter
    str: format_string           # e.g., "{level_name} {name} {message}"
    str?: date_format            # e.g., "%Y-%m-%d %H:%M:%S"

    fun format(log_record)
        # Replace placeholders with LogRecord fields
        # Available placeholders:
        #   {level_name} {level_no} {name} {message}
        #   {asctime} {pathname} {filename} {line_no}
        #   {func_name} {module} {relative_created}
    end

    fun format_time(log_record)
        # Convert log_record.created to formatted string
    end

    fun format_exception(exc_info)
        # Convert exception to multi-line string with stack trace
    end
end
```

**Example formatters:**

```quest
# Simple formatter
let simple_fmt = Formatter.new(
    format_string: "{level_name} {message}"
)

# Detailed formatter with timestamps
let detailed_fmt = Formatter.new(
    format_string: "{asctime} [{level_name}] {name}: {message}",
    date_format: "%Y-%m-%d %H:%M:%S"
)

# Debug formatter with file/line info
let debug_fmt = Formatter.new(
    format_string: "{asctime} {level_name} {name} ({filename}:{line_no}) - {message}"
)
```

### Handler Type

Dispatches log records to destinations:

```quest
type Handler
    int: level                   # Minimum level for this handler
    formatter?: formatter        # Optional Formatter instance
    array: filters               # Array of Filter instances

    fun emit(log_record)
        # Abstract - subclasses implement
        raise "emit() must be implemented by subclass"
    end

    fun handle(log_record)
        # Check level and filters, then emit
        if log_record.level_no >= self.level
            if not self.should_filter(log_record)
                self.emit(log_record)
            end
        end
    end

    fun format(log_record)
        if self.formatter != nil
            return self.formatter.format(log_record)
        else
            return log_record.message
        end
    end

    fun set_level(level)
        self.level = level
    end

    fun set_formatter(fmt)
        self.formatter = fmt
    end

    fun add_filter(filter)
        self.filters.push(filter)
    end
end
```

### StreamHandler Type

Writes to console output:

```quest
type StreamHandler
    # Inherits from Handler

    fun emit(log_record)
        let msg = self.format(log_record)
        puts(msg)  # Write to stdout
    end
end
```

### FileHandler Type

Writes to files:

```quest
type FileHandler
    str: filepath                # Path to log file
    str: mode                    # "a" for append, "w" for write

    fun emit(log_record)
        let msg = self.format(log_record)
        io.append(self.filepath, msg .. "\n")
    end
end
```

### Filter Type

Filters log records by logger name hierarchy:

```quest
type Filter
    str: name                    # Logger name prefix to match

    fun filter(log_record)
        # Return true to log, false to skip
        if self.name == ""
            return true
        elif self.name == log_record.name
            return true
        elif log_record.name.starts_with(self.name .. ".")
            return true
        else
            return false
        end
    end
end
```

**Example:** Filter("app.db") allows:
- "app.db" ✓
- "app.db.query" ✓
- "app.db.pool.connection" ✓

But rejects:
- "app.database" ✗
- "app" ✗

### Logger Type

Main logging interface with hierarchical organization:

```quest
type Logger
    str: name                    # e.g., "app.db.query"
    int?: level                  # nil means inherit from parent
    array: handlers              # List of Handler instances
    bool: propagate              # Pass to parent handlers (default true)
    logger?: parent              # Parent logger in hierarchy
    dict: children               # Child loggers (name → Logger)

    # Logging methods
    fun debug(message)
        self.log(DEBUG, message)
    end

    fun info(message)
        self.log(INFO, message)
    end

    fun warning(message)
        self.log(WARNING, message)
    end

    fun error(message)
        self.log(ERROR, message)
    end

    fun critical(message)
        self.log(CRITICAL, message)
    end

    fun exception(message, exc)
        # Log error with exception details
        let record = self.make_record(ERROR, message)
        record.exc_info = exc
        self.handle(record)
    end

    fun log(level, message)
        if self.is_enabled_for(level)
            let record = self.make_record(level, message)
            self.handle(record)
        end
    end

    # Configuration methods
    fun set_level(level)
        self.level = level
    end

    fun add_handler(handler)
        self.handlers.push(handler)
    end

    fun remove_handler(handler)
        # Remove handler from list
    end

    # Internal methods
    fun is_enabled_for(level)
        return level >= self.effective_level()
    end

    fun effective_level()
        # Return own level or walk up parent chain
        if self.level != nil
            return self.level
        elif self.parent != nil
            return self.parent.effective_level()
        else
            return NOTSET
        end
    end

    fun handle(record)
        # Pass to own handlers
        self.handlers.each(fun (handler)
            handler.handle(record)
        end)

        # Propagate to parent
        if self.propagate and self.parent != nil
            self.parent.handle(record)
        end
    end

    fun make_record(level, message)
        # Create LogRecord with metadata
        return LogRecord.new(
            name: self.name,
            level_no: level,
            level_name: level_to_name(level),
            message: message,
            created: time.now().timestamp(),
            # ... other fields ...
        )
    end
end
```

## Module API

### Logger Management

```quest
# Get a logger (creates if doesn't exist)
fun get_logger(name)
    # Returns Logger instance
end

# Get the root logger
fun get_root_logger()
    # Returns root logger (name: "root")
end
```

**Example:**

```quest
use "std/log"

let app_logger = log.get_logger("app")
let db_logger = log.get_logger("app.db")
let query_logger = log.get_logger("app.db.query")

app_logger.info("Application started")
db_logger.debug("Connected to database")
query_logger.debug("Executing query: SELECT * FROM users")
```

### Convenience Functions (Root Logger)

```quest
# Log to root logger
fun debug(message)
fun info(message)
fun warning(message)
fun error(message)
fun critical(message)
fun exception(message, exc)
```

**Example:**

```quest
use "std/log"

log.info("Quick log message")
log.error("Something went wrong")
```

### Basic Configuration

```quest
# Quick setup for common use cases
fun basic_config(level?, format?, filename?, filemode?)
    # Sets up root logger with:
    # - Console or file handler
    # - Default formatter
    # - Specified level
end
```

**Example:**

```quest
use "std/log"

# Log to console
log.basic_config(level: log.DEBUG)

# Log to file
log.basic_config(
    level: log.INFO,
    filename: "app.log",
    format: "{asctime} {level_name} {message}"
)
```

### Level Utilities

```quest
# Convert level to name
fun level_to_name(level)
    # 10 → "DEBUG"
end

# Convert name to level
fun name_to_level(name)
    # "DEBUG" → 10
end

# Set global minimum level
fun set_level(level)
    # Sets root logger level
end

# Get current level
fun get_level()
end
```

## Configuration Type

All Quest standard library modules should expose configuration via a `Settings` type:

```quest
pub type Settings
    # Default log level for new loggers (default: INFO)
    str: level = "INFO"

    # Whether to use colored output (default: true)
    bool: use_colors = true

    # Default date format for timestamps
    str: date_format = "%Y-%m-%d %H:%M:%S"

    # Default format string
    str: format = "{level_name} {name} {message}"

    # Root logger configuration
    str?: root_level = "WARNING"

    # Whether to raise exceptions during logging (default: true)
    bool: raise_exceptions = true

    # Default file handler path
    str?: default_log_file = nil

    # Default file mode: "a" for append, "w" for write
    str: default_file_mode = "a"

    # Whether to auto-configure basic logging on module load
    bool: auto_configure = false

    # Disable all logging below this level globally
    int: global_minimum_level = 0

    fun apply()
        # Apply settings to logging system
    end

    fun to_dict()
        # Convert to dictionary
    end

    static fun from_dict(config_dict)
        # Create Settings from dictionary
    end
end

# Module-level settings instance
pub let settings = Settings.new()
```

### Configuration via .settings.toml

The logging module automatically loads configuration from `.settings.toml`:

```toml
[log]
level = "DEBUG"
use_colors = true
format = "{asctime} [{level_name}] {name}: {message}"
date_format = "%Y-%m-%d %H:%M:%S"
root_level = "INFO"
auto_configure = true
default_log_file = "app.log"
default_file_mode = "a"
raise_exceptions = true
global_minimum_level = 0
```

## Usage Examples

### Basic Usage

```quest
use "std/log"

# Use root logger for simple cases
log.info("Application started")
log.warning("Low memory")
log.error("Failed to connect")
```

### Hierarchical Loggers

```quest
use "std/log"

# Create logger hierarchy
let app = log.get_logger("app")
let db = log.get_logger("app.db")
let query = log.get_logger("app.db.query")

# Configure root to only show warnings+
log.set_level(log.WARNING)

# But enable debug for database subsystem
db.set_level(log.DEBUG)

app.info("Starting")        # Not shown (below WARNING)
db.debug("Connecting")      # Shown (db is DEBUG)
query.debug("SELECT...")    # Shown (inherits from db)
```

### Multiple Handlers

```quest
use "std/log"

let logger = log.get_logger("app")

# Add console handler (DEBUG+)
let console = StreamHandler.new()
console.set_level(log.DEBUG)
console.set_formatter(Formatter.new(
    format_string: "{level_name} {message}"
))
logger.add_handler(console)

# Add file handler (ERROR+ only)
let file_handler = FileHandler.new(
    filepath: "errors.log",
    mode: "a"
)
file_handler.set_level(log.ERROR)
file_handler.set_formatter(Formatter.new(
    format_string: "{asctime} {level_name} {name} - {message}",
    date_format: "%Y-%m-%d %H:%M:%S"
))
logger.add_handler(file_handler)

# This goes to both console and file
logger.error("Database connection failed")

# This only goes to console
logger.debug("Processing request")
```

### Exception Logging

```quest
use "std/log"

let logger = log.get_logger("app")

try
    risky_operation()
catch exc
    # Log with full exception details and stack trace
    logger.exception("Operation failed", exc)
    # Outputs:
    # ERROR app Operation failed [DatabaseError: Connection timeout]
    # Stack trace:
    #   at risky_operation (app.q:42)
    #   at main (app.q:10)
end
```

### Filtering

```quest
use "std/log"

let logger = log.get_logger("app.db")
let handler = StreamHandler.new()

# Only log messages from "app.db" and children
let filter = Filter.new(name: "app.db")
handler.add_filter(filter)

logger.add_handler(handler)
```

## Implementation Notes

### Logger Hierarchy

Loggers form a tree based on dot-separated names:

```
root
├── app
│   ├── app.db
│   │   ├── app.db.query
│   │   └── app.db.pool
│   └── app.api
│       ├── app.api.auth
│       └── app.api.routes
└── lib
    └── lib.utils
```

When a message is logged:
1. Check if logger's effective level allows it
2. Create LogRecord
3. Pass to all handlers on this logger
4. If `propagate=true`, pass to parent logger's handlers
5. Repeat up the tree to root

### Level Inheritance

Loggers inherit levels from parents:

```quest
let root = log.get_logger("")
root.set_level(log.WARNING)

let app = log.get_logger("app")
# app.effective_level() → WARNING (from root)

let db = log.get_logger("app.db")
db.set_level(log.DEBUG)
# db.effective_level() → DEBUG (own level)

let query = log.get_logger("app.db.query")
# query.effective_level() → DEBUG (from db)
```

### Handler Propagation

By default, messages propagate up the hierarchy:

```quest
let root = log.get_logger("")
root.add_handler(console_handler)

let app = log.get_logger("app")
app.add_handler(file_handler)

# Logs to both file_handler AND console_handler (propagates to root)
app.info("Message")

# Disable propagation
app.propagate = false
# Now only logs to file_handler
app.info("Message")
```

## Thread Safety

For Quest v1.0, thread safety is **not** required. The logging framework assumes single-threaded execution. Future versions may add thread-safe variants.

## Performance Considerations

1. **Early level check**: `logger.debug()` should check `is_enabled_for()` before creating LogRecord
2. **Lazy formatting**: Only format messages if they will be emitted
3. **Handler caching**: Cache effective level to avoid tree walks
4. **String interpolation**: Use Quest's native string operations (avoid complex regex)

## Compatibility with Python

This specification maintains conceptual compatibility with Python's logging module:

| Python           | Quest                | Notes                          |
|------------------|----------------------|--------------------------------|
| `logging.Logger` | `Logger`             | Quest type                     |
| `logging.Handler`| `Handler`            | Quest type                     |
| `logging.Formatter` | `Formatter`        | Quest type                     |
| `logging.getLogger()` | `log.get_logger()` | Module function            |
| `logging.debug()` | `log.debug()`        | Root logger convenience        |
| `logging.basicConfig()` | `log.basic_config()` | Quick setup          |

## Future Extensions

Future versions may add:

1. **Network handlers** (syslog, HTTP, email)
2. **Rotating file handlers** (by size or time)
3. **Buffering handlers** (batch writes)
4. **Async handlers** (non-blocking I/O)
5. **Structured logging** (JSON output)
6. **Context managers** (scoped logging)
7. **Thread safety** (locks, thread-local storage)

## References

- [Python logging module](https://docs.python.org/3/library/logging.html)
- [Python logging cookbook](https://docs.python.org/3/howto/logging-cookbook.html)
- [PEP 282 - A Logging System](https://peps.python.org/pep-0282/)

## Status

**Draft** - Proposed for Quest v1.0 standard library

## Copyright

This document is placed in the public domain.
