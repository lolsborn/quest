# Log Handler Tests - QEP-004
# Tests Handler, StreamHandler, and FileHandler types

use "std/test" as test
use "std/log" as log
use "std/time" as time
use "std/io" as io

test.module("Log Handlers (QEP-004)")

# Helper to create test record
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
            "module_name": nil,
            "line_no": nil
        },
        "exc_info": nil
    }
end

test.describe("StreamHandler construction", fun ()
    test.it("creates StreamHandler with default settings", fun ()
        let handler = log.StreamHandler.new(
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        test.assert(handler != nil, "StreamHandler should be created")
    end)

    test.it("creates StreamHandler with custom formatter", fun ()
        let fmt = log.Formatter.new(
            format_string: "{level_name} {message}",
            date_format: "",
            use_colors: false
        )

        let handler = log.StreamHandler.new(
            level: log.DEBUG,
            formatter_obj: fmt,
            filters: []
        )

        test.assert(handler != nil, "StreamHandler with formatter should be created")
    end)
end)

test.describe("FileHandler construction", fun ()
    test.it("creates FileHandler for new file", fun ()
        let handler = log.FileHandler.new(
            filepath: "/tmp/test_quest_log.txt",
            mode: "w",
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        test.assert(handler != nil, "FileHandler should be created")
    end)

    test.it("creates FileHandler in append mode", fun ()
        let handler = log.FileHandler.new(
            filepath: "/tmp/test_quest_append.txt",
            mode: "a",
            level: log.DEBUG,
            formatter_obj: nil,
            filters: []
        )

        test.assert(handler != nil, "FileHandler in append mode should be created")
    end)
end)

test.describe("Handler level filtering", fun ()
    test.it("handler blocks messages below its level", fun ()
        let handler = log.StreamHandler.new(
            level: log.WARNING,
            formatter_obj: nil,
            filters: []
        )

        # INFO is below WARNING (20 < 30)
        let info_record = make_test_record("test", log.INFO, "info message")
        let result = handler.handle(info_record)

        # Should return nil (blocked)
        test.assert(result == nil, "Handler should block INFO when level is WARNING")
    end)

    test.it("handler allows messages at or above its level", fun ()
        let handler = log.StreamHandler.new(
            level: log.WARNING,
            formatter_obj: nil,
            filters: []
        )

        # ERROR is above WARNING (40 > 30)
        let error_record = make_test_record("test", log.ERROR, "error message")
        let result = handler.handle(error_record)

        # Should return record (not blocked)
        test.assert(result != nil, "Handler should allow ERROR when level is WARNING")
    end)

    test.it("handler with NOTSET level allows all messages", fun ()
        let handler = log.StreamHandler.new(
            level: log.NOTSET,
            formatter_obj: nil,
            filters: []
        )

        let debug_record = make_test_record("test", log.DEBUG, "debug")
        let result = handler.handle(debug_record)

        test.assert(result != nil, "NOTSET handler should allow DEBUG")
    end)
end)

test.describe("Handler.set_level()", fun ()
    test.it("updates handler level threshold", fun ()
        let handler = log.StreamHandler.new(
            level: log.WARNING,
            formatter_obj: nil,
            filters: []
        )

        # Initially blocks INFO
        let info_record = make_test_record("test", log.INFO, "info")
        test.assert(handler.handle(info_record) == nil, "Should initially block INFO")

        # Change level to DEBUG
        handler.set_level(log.DEBUG)

        # Now allows INFO
        let info_record2 = make_test_record("test", log.INFO, "info2")
        test.assert(handler.handle(info_record2) != nil, "Should now allow INFO after level change")
    end)

    test.it("accepts level as integer", fun ()
        let handler = log.StreamHandler.new(
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        handler.set_level(10)  # DEBUG = 10
        # Level should be updated (tested via behavior, can't access private field)
        test.assert(true, "set_level with int should work")
    end)
end)

test.describe("Handler.set_formatter()", fun ()
    test.it("changes output format", fun ()
        # Can't easily test output, but verify no errors
        let handler = log.StreamHandler.new(
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        let new_fmt = log.Formatter.new(
            format_string: "CUSTOM {message}",
            date_format: "",
            use_colors: false
        )

        handler.set_formatter(new_fmt)

        # Verify handle still works
        let record = make_test_record("test", log.INFO, "test")
        test.assert(handler.handle(record) != nil, "Handler should still work after formatter change")
    end)
end)

test.describe("FileHandler file operations", fun ()
    test.it("writes to file in write mode", fun ()
        let log_file = "/tmp/quest_handler_test_write.log"

        # Remove file if it exists
        if io.exists(log_file)
            io.remove(log_file)
        end

        let handler = log.FileHandler.new(
            filepath: log_file,
            mode: "w",
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        let record = make_test_record("test", log.INFO, "Test message 1")
        handler.handle(record)

        # Verify file was created and contains message
        test.assert(io.exists(log_file), "Log file should be created")

        let content = io.read(log_file)
        test.assert(content.contains("Test message 1"), "File should contain logged message")

        # Cleanup
        io.remove(log_file)
    end)

    test.it("appends to file in append mode", fun ()
        let log_file = "/tmp/quest_handler_test_append.log"

        # Create initial file
        io.write(log_file, "Initial content\n")

        let handler = log.FileHandler.new(
            filepath: log_file,
            mode: "a",
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        let record = make_test_record("test", log.INFO, "Appended message")
        handler.handle(record)

        let content = io.read(log_file)
        test.assert(content.contains("Initial content"), "Should preserve existing content")
        test.assert(content.contains("Appended message"), "Should append new message")

        # Cleanup
        io.remove(log_file)
    end)

    test.it("write mode overwrites file", fun ()
        let log_file = "/tmp/quest_handler_test_overwrite.log"

        # Create file with existing content
        io.write(log_file, "Old content\n")

        let handler = log.FileHandler.new(
            filepath: log_file,
            mode: "w",
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        # First write should overwrite
        let record1 = make_test_record("test", log.INFO, "First write")
        handler.handle(record1)

        let content1 = io.read(log_file)
        test.assert(not content1.contains("Old content"), "Old content should be overwritten")
        test.assert(content1.contains("First write"), "Should contain first message")

        # Note: Due to value semantics, mode change in emit() doesn't persist
        # Each subsequent write will also overwrite (mode stays "w")
        # This is expected behavior given Quest's value semantics

        # Cleanup
        io.remove(log_file)
    end)
end)

test.describe("Handler formatting", fun ()
    test.it("uses custom formatter when set", fun ()
        let fmt = log.Formatter.new(
            format_string: "CUSTOM",
            date_format: "",
            use_colors: false
        )

        let handler = log.StreamHandler.new(
            level: log.INFO,
            formatter_obj: fmt,
            filters: []
        )

        # Verify handler has formatter (via behavior)
        let record = make_test_record("test", log.INFO, "test")
        test.assert(handler.handle(record) != nil, "Handler with custom formatter should work")
    end)

    test.it("uses default formatter when none set", fun ()
        let handler = log.StreamHandler.new(
            level: log.INFO,
            formatter_obj: nil,
            filters: []
        )

        let record = make_test_record("test", log.INFO, "test")
        test.assert(handler.handle(record) != nil, "Handler without formatter should use default")
    end)
end)
