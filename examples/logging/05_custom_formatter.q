# Custom Formatter Example
# Shows how to customize timestamp formats and color settings

use "std/log"

puts("=== Custom Formatter Example ===\n")

# The log format is: [timestamp] LEVEL [logger.name] message
# You can customize:
#   1. Timestamp format (using strftime codes)
#   2. Color on/off

# Example 1: Default Apache/CLF style timestamps
puts("1. Default Apache Common Log Format style:\n")

log.basic_config(log.INFO, nil, nil, nil)
log.info("Server started on port 8080")
log.warning("Cache size exceeding 80%")

# Example 2: ISO 8601 timestamp format
puts("\n2. ISO 8601 timestamp format (YYYY-MM-DD HH:MM:SS):\n")

let iso_formatter = log.Formatter.new(
    format_string: "",  # Format string not currently used (format is fixed)
    date_format: "%Y-%m-%d %H:%M:%S",
    use_colors: true
)

let iso_handler = log.StreamHandler.new(
    level: log.NOTSET,
    formatter_obj: iso_formatter,
    filters: []
)

let logger2 = log.get_logger("app.iso")
logger2.set_level(log.INFO)
logger2.add_handler(iso_handler)

logger2.info("Database connection established")
logger2.error("Failed to load configuration file")

# Example 3: Human-readable verbose format
puts("\n3. Verbose human-readable format:\n")

let verbose_formatter = log.Formatter.new(
    format_string: "",
    date_format: "%A, %B %d, %Y at %I:%M:%S %p",
    use_colors: true
)

let verbose_handler = log.StreamHandler.new(
    level: log.NOTSET,
    formatter_obj: verbose_formatter,
    filters: []
)

let logger3 = log.get_logger("app.verbose")
logger3.set_level(log.INFO)
logger3.add_handler(verbose_handler)

logger3.info("User authentication successful")
logger3.warning("Session timeout in 5 minutes")

# Example 4: Simple date format
puts("\n4. Simple date format (DD/MM/YYYY HH:MM):\n")

let simple_formatter = log.Formatter.new(
    format_string: "",
    date_format: "%d/%m/%Y %H:%M",
    use_colors: true
)

let simple_handler = log.StreamHandler.new(
    level: log.NOTSET,
    formatter_obj: simple_formatter,
    filters: []
)

let logger4 = log.get_logger("app.simple")
logger4.set_level(log.INFO)
logger4.add_handler(simple_handler)

logger4.info("Request processed successfully")
logger4.error("Payment gateway timeout")

# Example 5: No colors (good for log files)
puts("\n5. Without colors (for log files):\n")

let plain_formatter = log.Formatter.new(
    format_string: "",
    date_format: "[%d/%b/%Y %H:%M:%S]",
    use_colors: false
)

let plain_handler = log.StreamHandler.new(
    level: log.NOTSET,
    formatter_obj: plain_formatter,
    filters: []
)

let logger5 = log.get_logger("app.plain")
logger5.set_level(log.INFO)
logger5.add_handler(plain_handler)

logger5.info("Log entry without ANSI colors")
logger5.error("Error entry in plain text")

puts("\n=== Available Date Format Codes ===")
puts("Date components:")
puts("  %Y - Year with century (2025)")
puts("  %m - Month as number (01-12)")
puts("  %d - Day of month (01-31)")
puts("  %B - Full month name (October)")
puts("  %b - Abbreviated month (Oct)")
puts("  %A - Full weekday name (Wednesday)")
puts("  %a - Abbreviated weekday (Wed)")
puts("")
puts("Time components:")
puts("  %H - Hour 24-hour format (00-23)")
puts("  %I - Hour 12-hour format (01-12)")
puts("  %M - Minute (00-59)")
puts("  %S - Second (00-59)")
puts("  %p - AM/PM designation")
puts("")
puts("Examples:")
puts("  [%d/%b/%Y %H:%M:%S]    → [04/Oct/2025 14:30:45]")
puts("  %Y-%m-%d %H:%M:%S      → 2025-10-04 14:30:45")
puts("  %B %d, %Y              → October 04, 2025")
puts("  %A at %I:%M %p         → Wednesday at 02:30 PM")
