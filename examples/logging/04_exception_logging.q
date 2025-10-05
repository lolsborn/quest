# Exception Logging Example
# Shows how to log exceptions with stack traces

use "std/log"

puts("=== Exception Logging Example ===\n")

let logger = log.get_logger("app")
logger.set_level(log.DEBUG)
logger.add_handler(log.StreamHandler.new(level: log.NOTSET, formatter_obj: nil, filters: []))

fun risky_operation()
    raise "Something went wrong in risky_operation!"
end

fun process_data()
    risky_operation()
end

puts("Attempting risky operation...")

try
    process_data()
catch e
    # Log the exception with full details
    logger.exception("Operation failed", e)

    puts("\nException details:")
    puts("  Type: " .. e.exc_type())
    puts("  Message: " .. e.message())
    puts("  Stack frames: " .. e.stack().len()._str())
end

puts("\n=== Another Example ===\n")

fun divide(a, b)
    if b == 0
        raise "Division by zero!"
    end
    return a / b
end

try
    let result = divide(10, 0)
    puts("Result: " .. result._str())
catch e2
    logger.error("Division failed: " .. e2.message())
end

puts("\nThe exception() method automatically includes:")
puts("  - Exception type")
puts("  - Exception message")
puts("  - Full stack trace")
puts("  - Source file and line numbers (if available)")
