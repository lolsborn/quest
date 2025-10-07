# Log Formatter Tests - QEP-004
# Tests the Formatter type for log message formatting

use "std/test" as test
use "std/log" as log
use "std/time" as time

test.module("Log Formatters (QEP-004)")

# Helper to create test record with all fields
fun make_test_record(name, level, message)
    return {
        "record": {
            "name": name,
            "level_no": level,
            "level_name": log.level_to_name(level),
            "message": message,
            "datetime": time.now_local(),
            "created": time.now().as_seconds().to_f64(),
            "relative_created": 1000.0,
            "module_name": "test_module",
            "line_no": 42,
            "pathname": "/path/to/file.q",
            "filename": "file.q",
            "func_name": "test_function"
        },
        "exc_info": nil
    }
end

test.describe("Formatter construction", fun ()
    test.it("creates formatter with basic format string", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name} {message}",
            date_format: "%Y-%m-%d",
            use_colors: false
        )

        test.assert(fmt != nil, "Formatter should be created")
    end)

    test.it("creates formatter with timestamp format", fun ()
        let fmt = log.Formatter.new(
            format_string: "[{timestamp}] {level_name} {message}",
            date_format: "[%d/%b/%Y %H:%M:%S]",
            use_colors: true
        )

        test.assert(fmt != nil, "Formatter with timestamp should be created")
    end)
end)

test.describe("Timestamp formatting", fun ()
    test.it("formats timestamp with default format", fun ()
        let fmt = log.Formatter.new(
            format_string: "{timestamp}",
            date_format: "%Y-%m-%d %H:%M:%S",
            use_colors: false
        )

        let record = make_test_record("test", log.INFO, "message")
        let timestamp = fmt.format_time(record["record"])

        # Should contain year-month-day pattern
        test.assert(timestamp.len() > 10, "Timestamp should be formatted string")
        test.assert(timestamp.contains("-"), "Should contain date separators")
    end)

    test.it("formats timestamp with Apache/CLF style", fun ()
        let fmt = log.Formatter.new(
            format_string: "",
            date_format: "[%d/%b/%Y %H:%M:%S]",
            use_colors: false
        )

        let record = make_test_record("test", log.INFO, "message")
        let timestamp = fmt.format_time(record["record"])

        test.assert(timestamp.startswith("["), "Should start with [")
        test.assert(timestamp.contains("/"), "Should contain / separators")
    end)

    test.it("formats timestamp with custom format codes", fun ()
        let fmt = log.Formatter.new(
            format_string: "",
            date_format: "%A, %B %d, %Y",
            use_colors: false
        )

        let record = make_test_record("test", log.INFO, "message")
        let timestamp = fmt.format_time(record["record"])

        # Should contain full weekday and month names
        test.assert(timestamp.contains(","), "Should contain comma separator")
        test.assert(timestamp.len() > 15, "Full format should be longer")
    end)
end)

test.describe("Message formatting", fun ()
    test.it("formats basic message with level and text", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name} {message}",
            date_format: "",
            use_colors: false
        )

        let record = make_test_record("test", log.INFO, "Hello World")
        let formatted = fmt.format(record)

        test.assert(formatted.contains("INFO"), "Should contain level name")
        test.assert(formatted.contains("Hello World"), "Should contain message")
    end)

    test.it("includes logger name in formatted output", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name} [{name}] {message}",
            date_format: "",
            use_colors: false
        )

        let record = make_test_record("app.db.query", log.DEBUG, "Query executed")
        let formatted = fmt.format(record)

        test.assert(formatted.contains("app.db.query"), "Should contain logger name")
        test.assert(formatted.contains("Query executed"), "Should contain message")
    end)

    test.it("formats all log levels correctly", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name}",
            date_format: "",
            use_colors: false
        )

        let levels = [
            [log.DEBUG, "DEBUG"],
            [log.INFO, "INFO"],
            [log.WARNING, "WARNING"],
            [log.ERROR, "ERROR"],
            [log.CRITICAL, "CRITICAL"]
        ]

        let i = 0
        while i < levels.len()
            let level_num = levels[i][0]
            let level_name = levels[i][1]
            let record = make_test_record("test", level_num, "msg")
            let formatted = fmt.format(record)

            test.assert(formatted.contains(level_name), "Should format " .. level_name)
            i = i + 1
        end
    end)
end)

test.describe("Color formatting", fun ()
    test.it("adds colors when use_colors is true", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name}",
            date_format: "",
            use_colors: true
        )

        let record = make_test_record("test", log.ERROR, "error message")
        let formatted = fmt.format(record)

        # Colored output contains ANSI escape codes
        test.assert(formatted.contains("\u001b[") or formatted.contains("[31m"), "Should contain ANSI color codes for ERROR")
    end)

    test.it("no colors when use_colors is false", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name}",
            date_format: "",
            use_colors: false
        )

        let record = make_test_record("test", log.ERROR, "error message")
        let formatted = fmt.format(record)

        # Should not contain ANSI codes
        test.assert(not formatted.contains("\u001b["), "Should not contain ANSI escape codes")
        test.assert(formatted.contains("ERROR"), "Should contain plain ERROR text")
    end)

    test.it("colorizes different levels appropriately", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name}",
            date_format: "",
            use_colors: true
        )

        # Each level should get different colors
        let debug_rec = make_test_record("test", log.DEBUG, "msg")
        let info_rec = make_test_record("test", log.INFO, "msg")
        let warning_rec = make_test_record("test", log.WARNING, "msg")

        let debug_out = fmt.format(debug_rec)
        let info_out = fmt.format(info_rec)
        let warning_out = fmt.format(warning_rec)

        # All should be colored
        test.assert(debug_out != "DEBUG", "DEBUG should be colored")
        test.assert(info_out != "INFO", "INFO should be colored")
        test.assert(warning_out != "WARNING", "WARNING should be colored")
    end)
end)

test.describe("Exception formatting", fun ()
    test.it("formats exception with type and message", fun ()
        let fmt = log.Formatter.new(
            format_string: "{message}",
            date_format: "",
            use_colors: false
        )

        let exc = nil
        try
            raise "Test error message"
        catch e
            exc = e
        end

        let record_with_exc = {
            "record": {
                "name": "test",
                "level_no": log.ERROR,
                "level_name": "ERROR",
                "message": "An error occurred",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": exc
        }

        let formatted = fmt.format(record_with_exc)

        test.assert(formatted.contains("An error occurred"), "Should contain log message")
        test.assert(formatted.contains("RuntimeErr:"), "Should contain exception type (QEP-037: string raises are RuntimeErr)")
        test.assert(formatted.contains("Test error message"), "Should contain exception message")
    end)

    test.it("formats exception with stack trace", fun ()
        let fmt = log.Formatter.new(
            format_string: "{message}",
            date_format: "",
            use_colors: false
        )

        let exc = nil
        try
            raise "With stack"
        catch e
            exc = e
        end

        let record_with_exc = {
            "record": {
                "name": "test",
                "level_no": log.ERROR,
                "level_name": "ERROR",
                "message": "Error",
                "datetime": time.now_local(),
                "module_name": nil,
                "line_no": nil
            },
            "exc_info": exc
        }

        let formatted = fmt.format(record_with_exc)

        test.assert(formatted.contains("Stack trace:"), "Should include stack trace header")
    end)
end)

test.describe("Message edge cases", fun ()
    test.it("handles empty message", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name} {message}",
            date_format: "",
            use_colors: false
        )

        let record = make_test_record("test", log.INFO, "")
        let formatted = fmt.format(record)

        test.assert(formatted.contains("INFO"), "Should contain level even with empty message")
    end)

    test.it("handles very long message", fun ()
        let fmt = log.Formatter.new(
            format_string: "{message}",
            date_format: "",
            use_colors: false
        )

        let long_msg = "A" .. "B" .. "C" .. "D" .. "E" .. "F" .. "G" .. "H" .. "I" .. "J"
        long_msg = long_msg .. long_msg .. long_msg  # ~30 chars
        let record = make_test_record("test", log.INFO, long_msg)
        let formatted = fmt.format(record)

        test.assert(formatted.contains("ABC"), "Should contain long message")
        test.assert(formatted.len() > 20, "Should preserve long message")
    end)

    test.it("handles special characters in message", fun ()
        let fmt = log.Formatter.new(
            format_string: "{message}",
            date_format: "",
            use_colors: false
        )

        let special_msg = "Test: @#$% 'quotes' \"double\" \nnewline"
        let record = make_test_record("test", log.INFO, special_msg)
        let formatted = fmt.format(record)

        test.assert(formatted.contains("@#$%"), "Should preserve special chars")
        test.assert(formatted.contains("quotes"), "Should preserve quotes")
    end)
end)
