# Basic Logging Example
# Shows how to use the root logger with different log levels

use "std/log"

puts("=== Basic Logging Example ===\n")

# By default, root logger is at WARNING level
# Only WARNING, ERROR, and CRITICAL will be displayed

puts("With default WARNING level:")
log.debug("This debug message won't show")
log.info("This info message won't show")
log.warning("This warning WILL show")
log.error("This error WILL show")
log.critical("This critical WILL show")

puts("\n--- Changing to DEBUG level ---\n")

# Set root logger to DEBUG to see all messages
log.set_level(log.DEBUG)

log.debug("Now debug shows")
log.info("Now info shows")
log.warning("Warning still shows")
log.error("Error still shows")
log.critical("Critical still shows")

puts("\n=== Log Levels ===")
puts("DEBUG:    " .. log.DEBUG.str() .. "  - Detailed diagnostic info")
puts("INFO:     " .. log.INFO.str() .. "  - General informational messages")
puts("WARNING:  " .. log.WARNING.str() .. "  - Warning messages")
puts("ERROR:    " .. log.ERROR.str() .. "  - Error messages")
puts("CRITICAL: " .. log.CRITICAL.str() .. " - Critical errors")
