# Named Loggers Example
# Shows hierarchical logging with parent-child relationships

use "std/log"

puts("=== Named Loggers Example ===\n")

# Create loggers for different parts of an application
let app_logger = log.get_logger("app")
let db_logger = log.get_logger("app.db")
let api_logger = log.get_logger("app.api")

# Add handlers to each logger
app_logger.add_handler(log.StreamHandler.new(level: log.NOTSET, formatter_obj: nil, filters: []))
db_logger.add_handler(log.StreamHandler.new(level: log.NOTSET, formatter_obj: nil, filters: []))
api_logger.add_handler(log.StreamHandler.new(level: log.NOTSET, formatter_obj: nil, filters: []))

puts("Set root logger to WARNING, but db logger to DEBUG:\n")

# Root logger at WARNING (default)
log.set_level(log.WARNING)

# But we want debug logging for database operations
db_logger.set_level(log.DEBUG)

# These won't show (below WARNING at root)
app_logger.info("App starting...")

# These will show (db logger is at DEBUG)
db_logger.debug("Connecting to database")
db_logger.info("Database connected")

# These will show (at or above WARNING)
app_logger.warning("Low memory warning")
api_logger.error("API request failed")
db_logger.critical("Database connection lost!")

puts("\n=== Logger Hierarchy ===")
puts("Loggers inherit levels from their parents:")
puts("  root (WARNING)")
puts("  ├─ app (inherits WARNING)")
puts("  │  ├─ app.db (set to DEBUG)")
puts("  │  └─ app.api (inherits WARNING)")
