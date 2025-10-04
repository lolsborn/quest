# Log Module for Quest
# Python-inspired logging framework with levels, formatting, and handlers
#
# Usage:
#   use "std/log" as log
#   log.set_level(log.INFO)
#   log.info("Application started")
#   log.error("Something went wrong")
#
# Import required modules
use "std/term"
use "std/time"

# =============================================================================
# Log Level Constants
# =============================================================================

pub let DEBUG = 10
pub let INFO = 20
pub let WARNING = 30
pub let ERROR = 40
pub let CRITICAL = 50

pub type Logger
    """
    Logger instance for structured logging.
    """

    int: log_level = INFO  # Default level

    fun go() -> str
        puts("Logger ready")
    end
end


# =============================================================================
# Module State
# =============================================================================

# Current minimum log level (default: INFO)
let current_level = 20

# Whether to use colored output
let use_colors = true

# Output handler function (default: puts to stdout)
let output_handler = nil  # nil means use default puts()

# =============================================================================
# Helper Functions
# =============================================================================

# Get current timestamp in YYYY-MM-DD HH:MM:SS format
fun get_timestamp()
    let now = time.now_local()
    return now.format("%Y-%m-%d %H:%M:%S")
end

# Convert level number to level name
fun level_name(level_num)
    if level_num == 10
        return "DEBUG"
    elif level_num == 20
        return "INFO"
    elif level_num == 30
        return "WARNING"
    elif level_num == 40
        return "ERROR"
    elif level_num == 50
        return "CRITICAL"
    else
        return "UNKNOWN"
    end
end

# Convert level name to level number
fun level_number(level_str)
    if level_str == "DEBUG"
        return 10
    elif level_str == "INFO"
        return 20
    elif level_str == "WARNING"
        return 30
    elif level_str == "ERROR"
        return 40
    elif level_str == "CRITICAL"
        return 50
    else
        return 20  # Default to INFO
    end
end

# Get whether colors are enabled
fun colors_enabled()
    return use_colors
end

# Apply color to text based on log level
fun colorize_level(level_name_str, level_num)
    # If colors are disabled, return plain text
    if not colors_enabled()
        return level_name_str
    end

    # Apply color based on level
    if level_num == 10  # DEBUG
        return term.grey(level_name_str)
    elif level_num == 20  # INFO
        return term.cyan(level_name_str)
    elif level_num == 30  # WARNING
        return term.yellow(level_name_str)
    elif level_num == 40  # ERROR
        return term.red(level_name_str)
    elif level_num == 50  # CRITICAL
        return term.bold(term.red(level_name_str))
    else
        return level_name_str
    end
end

# Format a log message using string interpolation
fun format_message(level_num, message)
    let level_str = level_name(level_num)
    let colored_level = colorize_level(level_str, level_num)

    # Build message parts
    let parts = []
    parts.push(colored_level)

    let timestamp = get_timestamp()
    parts.push(timestamp)

    # Add message
    parts.push(message)

    # Join with spaces
    return parts.join(" ")
end

# Output a formatted message
fun output_message(formatted_msg)
    if output_handler == nil
        puts(formatted_msg)
    else
        output_handler(formatted_msg)
    end
end

# Core logging function - checks level and outputs message
fun log_message(level_num, message)
    if level_num >= current_level
        let formatted = format_message(level_num, message)
        output_message(formatted)
    end
end

# =============================================================================
# Public Logging Functions
# =============================================================================

# Log a debug message
pub fun debug(message)
    log_message(10, message)
end

# Log an info message
pub fun info(message)
    log_message(20, message)
end

# Log a warning message
pub fun warning(message)
    log_message(30, message)
end

# Log an error message
pub fun error(message)
    log_message(40, message)
end

# Log a critical message
pub fun critical(message)
    log_message(50, message)
end

# Log an exception with ERROR level
# This is typically used in exception handlers to log error details
# Includes exception type and stack trace if available
#
# Usage:
#   try
#       # code that might fail
#   catch exc
#       log.exception("Error occurred", exc)
#   end
pub fun exception(message, exc)
    let full_message = message .. " [" .. exc.exc_type() .. ": " .. exc.message() .. "]"

    # Add stack trace if available
    let stack = exc.stack()
    if stack.len() > 0
        full_message = full_message .. "\nStack trace:"
        stack.each(fun (frame)
            full_message = full_message .. "\n  " .. frame
        end)
    end

    log_message(40, full_message)
end

# =============================================================================
# Configuration Functions
# =============================================================================

# Set the minimum log level
# Accepts: number (10, 20, 30, 40, 50) or string ("DEBUG", "INFO", etc.)
pub fun set_level(level)
    # Try to use it as a number first, if that fails treat as string
    # Numbers: 10, 20, 30, 40, 50
    # Strings: "DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"
    if level == 10 or level == 20 or level == 30 or level == 40 or level == 50
        current_level = level
    elif level == "DEBUG" or level == "INFO" or level == "WARNING" or level == "ERROR" or level == "CRITICAL"
        current_level = level_number(level)
    else
        # Fallback: assume it's a number
        current_level = level
    end
end

# Get the current log level
pub fun get_level()
    return current_level
end

# Enable or disable colored output
pub fun enable_colors(enabled)
    use_colors = enabled
end

# Set a custom output handler
# Handler should be a function that takes one argument (the formatted message)
pub fun set_output(handler_fn)
    output_handler = handler_fn
end

# Reset to default configuration
pub fun reset()
    current_level = 20  # INFO
    use_colors = true
    output_handler = nil
end

# =============================================================================
# Example Usage (commented out)
# =============================================================================
#
# use "std/log" as log
#
# # Basic usage with timestamps
# log.info("Application started")
# log.warning("This is a warning")
# log.error("An error occurred")
#
# # Set log level
# log.set_level(log.DEBUG)
# log.debug("Debug message now visible")
#
# # Customize format - disable timestamp
# log.info("No timestamp")
#
# # Show level numbers
# log.warning("With level number")
#
# # Disable colors
# log.enable_colors(false)
# log.error("Plain text without colors")
#
# # Custom handler (log to file)
# log.set_output(fun (msg)
#     io.append("app.log", msg .. "\n")
# end)
#
# # Exception logging
# try
#     raise "Something failed"
# catch exc
#     log.exception("Operation failed", exc)
# end
#
# # Reset to defaults
# log.reset()
