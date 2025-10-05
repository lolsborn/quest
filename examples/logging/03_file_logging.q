# File Logging Example
# Shows how to log to files using FileHandler

use "std/log"
use "std/io"

puts("=== File Logging Example ===\n")

# Get a logger
let logger = log.get_logger("file_example")
logger.set_level(log.DEBUG)

# Create a file handler
let file_handler = log.FileHandler.new(
    filepath: "/tmp/quest_app.log",
    mode: "w",
    level: log.DEBUG,
    formatter_obj: nil,
    filters: []
)

# Create a formatter
let formatter = log.Formatter.new(
    format_string: "{level_name} {name} {message}",
    date_format: "%Y-%m-%d %H:%M:%S",
    use_colors: false  # No colors in files
)
file_handler.set_formatter(formatter)

# Add handler to logger
logger.add_handler(file_handler)

puts("Logging messages to /tmp/quest_app.log...")

# Log some messages
logger.debug("Application starting")
logger.info("Processing request #1234")
logger.warning("Cache miss - performance may be affected")
logger.error("Failed to connect to external service")
logger.critical("Out of memory!")

puts("\nLog file contents:")
puts("==================")
let contents = io.read("/tmp/quest_app.log")
puts(contents)
puts("==================")

puts("\nNote: Messages are logged to BOTH console and file")
puts("because the logger propagates to the root logger's")
puts("console handler. To log ONLY to file, set:")
puts("  logger.propagate = false")
