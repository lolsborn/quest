use "std/test"
use "std/io"

test.module("std/io StringIO")

test.describe("StringIO.new", fun ()
    test.it("creates empty buffer", fun ()
        let buf = io.StringIO.new()
        test.assert_eq(buf.get_value(), "", nil)
        test.assert_eq(buf.tell(), 0, nil)
        test.assert_eq(buf.len(), 0, nil)
        test.assert(buf.empty(), "Buffer should be empty")
    end)

    test.it("creates buffer with initial content", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.get_value(), "Hello", nil)
        test.assert_eq(buf.getvalue(), "Hello", "Python-style alias")
        test.assert_eq(buf.tell(), 0, nil)
        test.assert_eq(buf.len(), 5, nil)
    end)
end)

test.describe("StringIO.write", fun ()
    test.it("writes strings to buffer", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("Hello")
        test.assert_eq(count, 5, "Should return byte count")
        test.assert_eq(buf.get_value(), "Hello", nil)
        test.assert_eq(buf.tell(), 5, "Position should advance")
    end)

    test.it("concatenates multiple writes", fun ()
        let buf = io.StringIO.new()
        buf.write("Hello")
        buf.write(" ")
        buf.write("World")
        test.assert_eq(buf.get_value(), "Hello World", nil)
    end)

    test.it("returns byte count for UTF-8 characters", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("→")
        test.assert_eq(count, 3, "Should return 3 bytes")
    end)

    test.it("always appends to end regardless of position", fun ()
        let buf = io.StringIO.new("Hello")
        buf.seek(0)
        buf.write(" World")
        test.assert_eq(buf.get_value(), "Hello World", nil)
        test.assert_eq(buf.tell(), 11, "Position at end after write")
    end)
end)

test.describe("StringIO.writelines", fun ()
    test.it("writes multiple lines", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["Line 1\n", "Line 2\n", "Line 3\n"])
        test.assert_eq(buf.get_value(), "Line 1\nLine 2\nLine 3\n", nil)
    end)

    test.it("does not add newlines automatically", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["A", "B", "C"])
        test.assert_eq(buf.get_value(), "ABC", nil)
    end)
end)

test.describe("StringIO.read", fun ()
    test.it("reads entire buffer", fun ()
        let buf = io.StringIO.new("Hello World")
        let content = buf.read()
        test.assert_eq(content, "Hello World", nil)
        test.assert_eq(buf.tell(), 11, "Position at end")
    end)

    test.it("reads specified number of bytes", fun ()
        let buf = io.StringIO.new("Hello World")
        let part1 = buf.read(5)
        let part2 = buf.read(6)
        test.assert_eq(part1, "Hello", nil)
        test.assert_eq(part2, " World", nil)
        test.assert_eq(buf.tell(), 11, nil)
    end)

    test.it("returns empty string when reading past end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.read()
        let extra = buf.read()
        test.assert_eq(extra, "", nil)
    end)
end)

test.describe("StringIO.readline", fun ()
    test.it("reads lines one at a time", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        test.assert_eq(buf.readline(), "Line 1\n", nil)
        test.assert_eq(buf.readline(), "Line 2\n", nil)
        test.assert_eq(buf.readline(), "Line 3", "Last line without newline")
        test.assert_eq(buf.readline(), "", "Empty at end")
    end)

    test.it("handles no newlines", fun ()
        let buf = io.StringIO.new("No newlines here")
        let line = buf.readline()
        test.assert_eq(line, "No newlines here", nil)
        test.assert_eq(buf.readline(), "", "Should return empty on second call")
    end)
end)

test.describe("StringIO.readlines", fun ()
    test.it("reads all lines as array", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        let lines = buf.readlines()
        test.assert_eq(lines.len(), 3, nil)
        test.assert_eq(lines.get(0), "Line 1\n", nil)
        test.assert_eq(lines.get(1), "Line 2\n", nil)
        test.assert_eq(lines.get(2), "Line 3", nil)
    end)

    test.it("returns empty array for empty buffer", fun ()
        let buf = io.StringIO.new("")
        let lines = buf.readlines()
        test.assert_eq(lines.len(), 0, nil)
    end)
end)

test.describe("StringIO.seek", fun ()
    test.it("seeks to absolute position", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(6)
        test.assert_eq(new_pos, 6, "Should return new position")
        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("seeks relative to current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_pos = buf.seek(1, 1)
        test.assert_eq(new_pos, 6, nil)
        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("seeks relative to end", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-5, 2)
        test.assert_eq(new_pos, 6, nil)
        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("handles negative seek from current", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        let new_pos = buf.seek(-4, 1)
        test.assert_eq(new_pos, 6, nil)
        test.assert_eq(buf.read(), "World", nil)
    end)

    test.it("clamps negative positions to 0", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-100, 1)
        test.assert_eq(new_pos, 0, "Should clamp to 0")
    end)

    test.it("clamps beyond buffer end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.seek(1000)
        test.assert_eq(buf.tell(), 5, "Should clamp to buffer length")
    end)
end)

test.describe("StringIO.tell", fun ()
    test.it("returns current position", fun ()
        let buf = io.StringIO.new("Hello World")
        test.assert_eq(buf.tell(), 0, nil)
        buf.read(5)
        test.assert_eq(buf.tell(), 5, nil)
    end)
end)

test.describe("StringIO.clear", fun ()
    test.it("clears buffer contents", fun ()
        let buf = io.StringIO.new("Hello")
        buf.clear()
        test.assert_eq(buf.get_value(), "", nil)
        test.assert_eq(buf.tell(), 0, nil)
        test.assert(buf.empty(), "Should be empty")
    end)
end)

test.describe("StringIO.truncate", fun ()
    test.it("truncates at current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_size = buf.truncate()
        test.assert_eq(new_size, 5, nil)
        test.assert_eq(buf.get_value(), "Hello", nil)
    end)

    test.it("truncates at explicit size", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_size = buf.truncate(8)
        test.assert_eq(new_size, 8, nil)
        test.assert_eq(buf.get_value(), "Hello Wo", nil)
    end)

    test.it("adjusts position if beyond new size", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        buf.truncate(5)
        test.assert_eq(buf.tell(), 5, "Position should adjust")
    end)
end)

test.describe("StringIO utility methods", fun ()
    test.it("flush is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.flush()
        test.assert_eq(buf.get_value(), "Hello", "No change")
    end)

    test.it("close is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.close()
        test.assert_eq(buf.get_value(), "Hello", "Still readable")
        buf.write(" World")
        test.assert_eq(buf.get_value(), "Hello World", nil)
    end)

    test.it("closed always returns false", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.closed(), false, nil)
        buf.close()
        test.assert_eq(buf.closed(), false, "Still false after close")
    end)
end)

test.describe("StringIO.len and empty", fun ()
    test.it("returns correct length", fun ()
        let buf = io.StringIO.new("Hello")
        test.assert_eq(buf.len(), 5, nil)
        buf.write(" World")
        test.assert_eq(buf.len(), 11, nil)
    end)

    test.it("empty returns correct status", fun ()
        let buf = io.StringIO.new()
        test.assert(buf.empty(), "Should be empty")
        buf.write("Hello")
        test.assert_eq(buf.empty(), false, "Should not be empty")
    end)
end)

test.describe("StringIO.char_len", fun ()
    test.it("counts characters correctly", fun ()
        let buf = io.StringIO.new("ASCII")
        test.assert_eq(buf.char_len(), 5, nil)
        test.assert_eq(buf.len(), 5, nil)
    end)

    test.it("handles multibyte UTF-8", fun ()
        let buf = io.StringIO.new("→→→")
        test.assert_eq(buf.char_len(), 3, "3 characters")
        test.assert_eq(buf.len(), 9, "9 bytes (3 bytes per arrow)")
    end)

    test.it("handles mixed ASCII and UTF-8", fun ()
        let buf = io.StringIO.new("Hello → World")
        test.assert_eq(buf.char_len(), 13, "13 characters")
        test.assert_eq(buf.len(), 15, "15 bytes")
    end)
end)

test.describe("StringIO edge cases", fun ()
    test.it("handles empty writes", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("")
        test.assert_eq(count, 0, nil)
        test.assert_eq(buf.get_value(), "", nil)
    end)

    test.it("handles UTF-8 multibyte characters", fun ()
        let buf = io.StringIO.new("Hello → World")
        test.assert_eq(buf.len(), 15, "Arrow is 3 bytes")
        test.assert_eq(buf.char_len(), 13, "Arrow is 1 character")
    end)
end)

test.describe("StringIO context manager", fun ()
    test.it("supports with statement", fun ()
        with io.StringIO.new() as buf
            buf.write("test")
            test.assert_eq(buf.get_value(), "test", nil)
        end
    end)

    test.it("_exit is a no-op", fun ()
        let buf = io.StringIO.new("data")
        buf._exit()
        test.assert_eq(buf.get_value(), "data", nil)
        buf.write(" more")
        test.assert_eq(buf.get_value(), "data more", nil)
    end)
end)

test.describe("StringIO context manager comprehensive", fun ()
    test.it("automatic resource cleanup with with statement", fun ()
        let final_content = nil

        with io.StringIO.new("Start\n") as buf
            buf.write("Middle\n")
            buf.write("End\n")
            final_content = buf.get_value()
        end

        test.assert_eq(final_content, "Start\nMiddle\nEnd\n", "Content should be preserved")
    end)

    test.it("exception safety in with block", fun ()
        let content_before_error = nil

        try
            with io.StringIO.new() as buf
                buf.write("Before error\n")
                content_before_error = buf.get_value()
                raise "Test error"
            end
        catch e
            # Exception handled
        end

        test.assert_eq(content_before_error, "Before error\n", "Should capture content before exception")
    end)

    test.it("nested StringIO with statements", fun ()
        let outer_final = nil
        let inner_final = nil

        with io.StringIO.new() as outer_buf
            outer_buf.write("Outer start\n")

            with io.StringIO.new() as inner_buf
                inner_buf.write("Inner\n")
                inner_final = inner_buf.get_value()
            end

            outer_buf.write("Outer end\n")
            outer_final = outer_buf.get_value()
        end

        test.assert_eq(inner_final, "Inner\n", "Inner buffer should be independent")
        test.assert_eq(outer_final, "Outer start\nOuter end\n", "Outer buffer should be preserved")
    end)
end)
