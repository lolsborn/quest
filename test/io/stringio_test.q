use "std/test" { module, describe, it, assert_eq, assert, assert_nil }
use "std/io"

module("std/io StringIO")

describe("StringIO.new", fun ()
    it("creates empty buffer", fun ()
        let buf = io.StringIO.new()
        assert_eq(buf.get_value(), "")
        assert_eq(buf.tell(), 0)
        assert_eq(buf.len(), 0)
        assert(buf.empty(), "Buffer should be empty")
    end)

    it("creates buffer with initial content", fun ()
        let buf = io.StringIO.new("Hello")
        assert_eq(buf.get_value(), "Hello")
        assert_eq(buf.getvalue(), "Hello", "Python-style alias")
        assert_eq(buf.tell(), 0)
        assert_eq(buf.len(), 5)
    end)
end)

describe("StringIO.write", fun ()
    it("writes strings to buffer", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("Hello")
        assert_eq(count, 5, "Should return byte count")
        assert_eq(buf.get_value(), "Hello")
        assert_eq(buf.tell(), 5, "Position should advance")
    end)

    it("concatenates multiple writes", fun ()
        let buf = io.StringIO.new()
        buf.write("Hello")
        buf.write(" ")
        buf.write("World")
        assert_eq(buf.get_value(), "Hello World")
    end)

    it("returns byte count for UTF-8 characters", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("→")
        assert_eq(count, 3, "Should return 3 bytes")
    end)

    it("always appends to end regardless of position", fun ()
        let buf = io.StringIO.new("Hello")
        buf.seek(0)
        buf.write(" World")
        assert_eq(buf.get_value(), "Hello World")
        assert_eq(buf.tell(), 11, "Position at end after write")
    end)
end)

describe("StringIO.writelines", fun ()
    it("writes multiple lines", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["Line 1\n", "Line 2\n", "Line 3\n"])
        assert_eq(buf.get_value(), "Line 1\nLine 2\nLine 3\n")
    end)

    it("does not add newlines automatically", fun ()
        let buf = io.StringIO.new()
        buf.writelines(["A", "B", "C"])
        assert_eq(buf.get_value(), "ABC")
    end)
end)

describe("StringIO.read", fun ()
    it("reads entire buffer", fun ()
        let buf = io.StringIO.new("Hello World")
        let content = buf.read()
        assert_eq(content, "Hello World")        assert_eq(buf.tell(), 11, "Position at end")
    end)

    it("reads specified number of bytes", fun ()
        let buf = io.StringIO.new("Hello World")
        let part1 = buf.read(5)
        let part2 = buf.read(6)
        assert_eq(part1, "Hello")        assert_eq(part2, " World")        assert_eq(buf.tell(), 11)
    end)

    it("returns empty string when reading past end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.read()
        let extra = buf.read()
        assert_eq(extra, "")    end)
end)

describe("StringIO.readline", fun ()
    it("reads lines one at a time", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        assert_eq(buf.readline(), "Line 1\n")
        assert_eq(buf.readline(), "Line 2\n")
        assert_eq(buf.readline(), "Line 3", "Last line without newline")
        assert_eq(buf.readline(), "", "Empty at end")
    end)

    it("handles no newlines", fun ()
        let buf = io.StringIO.new("No newlines here")
        let line = buf.readline()
        assert_eq(line, "No newlines here")        assert_eq(buf.readline(), "", "Should return empty on second call")
    end)
end)

describe("StringIO.readlines", fun ()
    it("reads all lines as array", fun ()
        let buf = io.StringIO.new("Line 1\nLine 2\nLine 3")
        let lines = buf.readlines()
        assert_eq(lines.len(), 3)
        assert_eq(lines.get(0), "Line 1\n")
        assert_eq(lines.get(1), "Line 2\n")
        assert_eq(lines.get(2), "Line 3")
    end)

    it("returns empty array for empty buffer", fun ()
        let buf = io.StringIO.new("")
        let lines = buf.readlines()
        assert_eq(lines.len(), 0)
    end)
end)

describe("StringIO.seek", fun ()
    it("seeks to absolute position", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(6)
        assert_eq(new_pos, 6, "Should return new position")
        assert_eq(buf.read(), "World")
    end)

    it("seeks relative to current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_pos = buf.seek(1, 1)
        assert_eq(new_pos, 6)        assert_eq(buf.read(), "World")
    end)

    it("seeks relative to end", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-5, 2)
        assert_eq(new_pos, 6)        assert_eq(buf.read(), "World")
    end)

    it("handles negative seek from current", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        let new_pos = buf.seek(-4, 1)
        assert_eq(new_pos, 6)        assert_eq(buf.read(), "World")
    end)

    it("clamps negative positions to 0", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_pos = buf.seek(-100, 1)
        assert_eq(new_pos, 0, "Should clamp to 0")
    end)

    it("clamps beyond buffer end", fun ()
        let buf = io.StringIO.new("Hello")
        buf.seek(1000)
        assert_eq(buf.tell(), 5, "Should clamp to buffer length")
    end)
end)

describe("StringIO.tell", fun ()
    it("returns current position", fun ()
        let buf = io.StringIO.new("Hello World")
        assert_eq(buf.tell(), 0)
        buf.read(5)
        assert_eq(buf.tell(), 5)
    end)
end)

describe("StringIO.clear", fun ()
    it("clears buffer contents", fun ()
        let buf = io.StringIO.new("Hello")
        buf.clear()
        assert_eq(buf.get_value(), "")
        assert_eq(buf.tell(), 0)
        assert(buf.empty(), "Should be empty")
    end)
end)

describe("StringIO.truncate", fun ()
    it("truncates at current position", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(5)
        let new_size = buf.truncate()
        assert_eq(new_size, 5)        assert_eq(buf.get_value(), "Hello")
    end)

    it("truncates at explicit size", fun ()
        let buf = io.StringIO.new("Hello World")
        let new_size = buf.truncate(8)
        assert_eq(new_size, 8)        assert_eq(buf.get_value(), "Hello Wo")
    end)

    it("adjusts position if beyond new size", fun ()
        let buf = io.StringIO.new("Hello World")
        buf.seek(10)
        buf.truncate(5)
        assert_eq(buf.tell(), 5, "Position should adjust")
    end)
end)

describe("StringIO utility methods", fun ()
    it("flush is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.flush()
        assert_eq(buf.get_value(), "Hello", "No change")
    end)

    it("close is a no-op", fun ()
        let buf = io.StringIO.new("Hello")
        buf.close()
        assert_eq(buf.get_value(), "Hello", "Still readable")
        buf.write(" World")
        assert_eq(buf.get_value(), "Hello World")
    end)

    it("closed always returns false", fun ()
        let buf = io.StringIO.new("Hello")
        assert_eq(buf.closed(), false)
        buf.close()
        assert_eq(buf.closed(), false, "Still false after close")
    end)
end)

describe("StringIO.len and empty", fun ()
    it("returns correct length", fun ()
        let buf = io.StringIO.new("Hello")
        assert_eq(buf.len(), 5)
        buf.write(" World")
        assert_eq(buf.len(), 11)
    end)

    it("empty returns correct status", fun ()
        let buf = io.StringIO.new()
        assert(buf.empty(), "Should be empty")
        buf.write("Hello")
        assert_eq(buf.empty(), false, "Should not be empty")
    end)
end)

describe("StringIO.char_len", fun ()
    it("counts characters correctly", fun ()
        let buf = io.StringIO.new("ASCII")
        assert_eq(buf.char_len(), 5)
        assert_eq(buf.len(), 5)
    end)

    it("handles multibyte UTF-8", fun ()
        let buf = io.StringIO.new("→→→")
        assert_eq(buf.char_len(), 3, "3 characters")
        assert_eq(buf.len(), 9, "9 bytes (3 bytes per arrow)")
    end)

    it("handles mixed ASCII and UTF-8", fun ()
        let buf = io.StringIO.new("Hello → World")
        assert_eq(buf.char_len(), 13, "13 characters")
        assert_eq(buf.len(), 15, "15 bytes")
    end)
end)

describe("StringIO edge cases", fun ()
    it("handles empty writes", fun ()
        let buf = io.StringIO.new()
        let count = buf.write("")
        assert_eq(count, 0)        assert_eq(buf.get_value(), "")
    end)

    it("handles UTF-8 multibyte characters", fun ()
        let buf = io.StringIO.new("Hello → World")
        assert_eq(buf.len(), 15, "Arrow is 3 bytes")
        assert_eq(buf.char_len(), 13, "Arrow is 1 character")
    end)
end)

describe("StringIO context manager", fun ()
    it("supports with statement", fun ()
        with io.StringIO.new() as buf
            buf.write("test")
            assert_eq(buf.get_value(), "test")
        end
    end)

    it("_exit is a no-op", fun ()
        let buf = io.StringIO.new("data")
        buf._exit()
        assert_eq(buf.get_value(), "data")
        buf.write(" more")
        assert_eq(buf.get_value(), "data more")
    end)
end)

describe("StringIO context manager comprehensive", fun ()
    it("automatic resource cleanup with with statement", fun ()
        let final_content = nil

        with io.StringIO.new("Start\n") as buf
            buf.write("Middle\n")
            buf.write("End\n")
            final_content = buf.get_value()
        end

        assert_eq(final_content, "Start\nMiddle\nEnd\n", "Content should be preserved")
    end)

    it("exception safety in with block", fun ()
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

        assert_eq(content_before_error, "Before error\n", "Should capture content before exception")
    end)

    it("nested StringIO with statements", fun ()
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

        assert_eq(inner_final, "Inner\n", "Inner buffer should be independent")
        assert_eq(outer_final, "Outer start\nOuter end\n", "Outer buffer should be preserved")
    end)
end)
