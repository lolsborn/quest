#!/usr/bin/env quest
# Logging Framework Demo
# Demonstrates the std/log module capabilities

use "std/log" as log

puts("=== Quest Logging Framework Demo ===")
puts("")

# Basic logging at different levels
puts("1. Basic Logging:")
log.debug("This is a DEBUG message (won't show, default level is INFO)")
log.info("This is an INFO message")
log.warning("This is a WARNING message")
log.error("This is an ERROR message")
log.critical("This is a CRITICAL message")

puts("")
puts("2. Changing Log Level to DEBUG:")
log.set_level(log.DEBUG)
log.debug("Now DEBUG messages are visible!")
log.info("INFO still visible")

puts("")
puts("3. Changing Log Level to ERROR:")
log.set_level(log.ERROR)
log.info("This INFO won't show")
log.warning("This WARNING won't show")
log.error("Only ERROR and above show now")
log.critical("CRITICAL also shows")

puts("")
puts("4. Custom Format - Simple:")
log.set_level(log.INFO)
log.set_format("[%(level)] %(message)")
log.info("Simple format without timestamp")
log.error("Error in simple format")

puts("")
puts("5. Custom Format - Detailed:")
log.set_format("%(time) [%(levelnum)] %(level): %(message)")
log.info("Detailed format with level number")

puts("")
puts("6. Message-Only Format:")
log.set_format("%(message)")
log.warning("Just the message, no level or time")

puts("")
puts("7. Reset to Defaults:")
log.reset()
log.info("Back to default format and INFO level")

puts("")
puts("8. Using Level Constants:")
puts("DEBUG constant = " .. log.DEBUG._str())
puts("INFO constant = " .. log.INFO._str())
puts("WARNING constant = " .. log.WARNING._str())
puts("ERROR constant = " .. log.ERROR._str())
puts("CRITICAL constant = " .. log.CRITICAL._str())

puts("")
puts("9. Setting Level by Name:")
log.set_level("WARNING")
log.info("This won't show (below WARNING)")
log.warning("This WARNING shows")
log.error("This ERROR shows")

puts("")
puts("10. Exception Logging:")
log.set_level(log.INFO)
log.set_format("%(time) [%(level)] %(message)")

# Simple exception logging (no exception object)
log.exception("File not found: /data/input.txt", nil)

# Exception logging with exception object
try
    raise "Invalid JSON format"
catch e
    log.exception("Failed to parse config", e)
end

puts("")
puts("11. Practical Example - Application Logging:")
log.info("Application started")
log.info("Loading configuration...")
log.warning("Config file not found, using defaults")
log.info("Connecting to database...")

try
    raise "Connection timeout"
catch err
    log.exception("Database connection failed", err)
end

log.critical("Cannot proceed without database")
log.info("Shutting down")

puts("")
puts("=== Demo Complete ===")
