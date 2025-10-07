use "std/test"
use "std/sys"
use "std/io"

test.module("std/sys I/O Redirection (QEP-010)")

test.describe("System stream singletons", fun ()
    test.it("sys.stdout exists and has correct type", fun ()
        test.assert_eq(sys.stdout.cls(), "stdout", nil)
    end)

    test.it("sys.stderr exists and has correct type", fun ()
        test.assert_eq(sys.stderr.cls(), "stderr", nil)
    end)

    test.it("sys.stdin exists and has correct type", fun ()
        test.assert_eq(sys.stdin.cls(), "stdin", nil)
    end)

    test.it("sys.stdout.write() works", fun ()
        let count = sys.stdout.write("test\n")
        test.assert_eq(count, 5, "Should return byte count")
    end)

    test.it("sys.stderr.write() works", fun ()
        let count = sys.stderr.write("error\n")
        test.assert_eq(count, 6, "Should return byte count")
    end)
end)

test.describe("Redirect to StringIO", fun ()
    test.it("captures puts output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        puts("Captured line 1")
        puts("Captured line 2")

        guard.restore()

        test.assert_eq(buffer.get_value(), "Captured line 1\nCaptured line 2\n", nil)
    end)

    test.it("captures print output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        print("Hello ")
        print("World")

        guard.restore()

        test.assert_eq(buffer.get_value(), "Hello World", nil)
    end)

    test.it("captures mixed puts and print", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        puts("Line 1")
        print("Partial ")
        print("line ")
        puts("2")

        guard.restore()

        test.assert_eq(buffer.get_value(), "Line 1\nPartial line 2\n", nil)
    end)

    test.it("handles empty output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        # No output

        guard.restore()

        test.assert_eq(buffer.get_value(), "", nil)
    end)
end)

test.describe("Redirect to file path", fun ()
    test.it("redirects to file", fun ()
        let path = "/tmp/quest_redirect_test.txt"

        let guard = sys.redirect_stream(sys.stdout, path)
        puts("File output line 1")
        puts("File output line 2")
        guard.restore()

        let content = io.read(path)
        test.assert(content.contains("File output line 1"), "Should contain line 1")
        test.assert(content.contains("File output line 2"), "Should contain line 2")

        io.remove(path)
    end)

    test.it("appends to existing file", fun ()
        let path = "/tmp/quest_append_test.txt"

        io.write(path, "Initial\n")

        let guard = sys.redirect_stream(sys.stdout, path)
        puts("Appended")
        guard.restore()

        let content = io.read(path)
        test.assert(content.contains("Initial"), "Should have initial content")
        test.assert(content.contains("Appended"), "Should have appended content")

        io.remove(path)
    end)

    test.it("redirects to /dev/null", fun ()
        let guard = sys.redirect_stream(sys.stdout, "/dev/null")
        puts("This is suppressed")
        puts("So is this")
        guard.restore()

        # If we got here without error, suppression worked
        test.assert(true)    end)
end)

test.describe("Redirect stderr", fun ()
    test.it("captures stderr to StringIO", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stderr, buffer)

        sys.stderr.write("Error message\n")

        guard.restore()

        test.assert_eq(buffer.get_value(), "Error message\n", nil)
    end)

    test.it("redirects stderr to file", fun ()
        let path = "/tmp/quest_stderr_test.txt"

        let guard = sys.redirect_stream(sys.stderr, path)
        sys.stderr.write("Stderr to file\n")
        guard.restore()

        let content = io.read(path)
        test.assert_eq(content, "Stderr to file\n")
        io.remove(path)
    end)
end)

test.describe("RedirectGuard methods", fun ()
    test.it("is_active returns true when active", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        test.assert(guard.is_active(), "Guard should be active")

        guard.restore()
    end)

    test.it("is_active returns false after restore", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        guard.restore()

        test.assert_eq(guard.is_active(), false, "Guard should be inactive")
    end)

    test.it("restore is idempotent", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        puts("Output")

        guard.restore()
        guard.restore()  # Second call
        guard.restore()  # Third call

        # All should succeed without error
        test.assert_eq(guard.is_active(), false, nil)
        test.assert_eq(buffer.get_value(), "Output\n", nil)
    end)
end)

test.describe("Restore to sys.stdout", fun ()
    test.it("can restore by redirecting to sys.stdout", fun ()
        let buffer = io.StringIO.new()
        sys.redirect_stream(sys.stdout, buffer)

        puts("Captured")

        sys.redirect_stream(sys.stdout, sys.stdout)  # Restore manually

        let buffer2 = io.StringIO.new()
        sys.redirect_stream(sys.stdout, buffer2)
        puts("New capture")
        sys.redirect_stream(sys.stdout, sys.stdout)

        test.assert_eq(buffer.get_value(), "Captured\n", nil)
        test.assert_eq(buffer2.get_value(), "New capture\n", nil)
    end)
end)

test.describe("Nested redirections", fun ()
    test.it("handles nested StringIO redirections", fun ()
        let buf1 = io.StringIO.new()
        let buf2 = io.StringIO.new()

        let guard1 = sys.redirect_stream(sys.stdout, buf1)
        puts("Outer 1")

        let guard2 = sys.redirect_stream(sys.stdout, buf2)
        puts("Inner")

        guard2.restore()  # Back to buf1
        puts("Outer 2")

        guard1.restore()  # Back to console

        test.assert_eq(buf1.get_value(), "Outer 1\nOuter 2\n", nil)
        test.assert_eq(buf2.get_value(), "Inner\n", nil)
    end)

    test.it("handles nested file redirections", fun ()
        let path1 = "/tmp/quest_nest1.txt"
        let path2 = "/tmp/quest_nest2.txt"

        let guard1 = sys.redirect_stream(sys.stdout, path1)
        puts("File 1 - Line 1")

        let guard2 = sys.redirect_stream(sys.stdout, path2)
        puts("File 2 - Line 1")

        guard2.restore()
        puts("File 1 - Line 2")

        guard1.restore()

        let content1 = io.read(path1)
        let content2 = io.read(path2)

        test.assert(content1.contains("File 1 - Line 1"), nil)
        test.assert(content1.contains("File 1 - Line 2"), nil)
        test.assert(content2.contains("File 2 - Line 1"), nil)
        test.assert_eq(content2.contains("File 1"), false, "File 2 shouldn't have File 1 content")

        io.remove(path1)
        io.remove(path2)
    end)
end)

test.describe("Exception safety", fun ()
    test.it("can restore in ensure block", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        try
            puts("Before error")
            raise "Test error"
            puts("After error")  # Won't execute
        catch e
            # Exception caught
        ensure
            guard.restore()
        end

        test.assert_eq(buffer.get_value(), "Before error\n", nil)
    end)

    test.it("guard still works after exception", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        try
            puts("Output")
            raise "Error"
        catch e
            # Error handled
        ensure
            guard.restore()
        end

        test.assert_eq(guard.is_active(), false, "Should be restored")
        test.assert_eq(buffer.get_value(), "Output\n", nil)
    end)
end)

test.describe("Context manager support", fun ()
    test.it("works with 'with' statement", fun ()
        let buffer = io.StringIO.new()

        with sys.redirect_stream(sys.stdout, buffer) as guard
            puts("In with block")
            test.assert(guard.is_active(), "Should be active in block")
        end  # Automatic restore via _exit()

        # After 'with' block, should be restored
        test.assert_eq(buffer.get_value(), "In with block\n", nil)
    end)

    test.it("restores on exception in with block", fun ()
        let buffer = io.StringIO.new()

        try
            with sys.redirect_stream(sys.stdout, buffer)
                puts("Before error")
                raise "Error in with"
                puts("After error")  # Won't execute
            end
        catch e
            # Exception handled
        end

        # Output captured before error, guard auto-restored
        test.assert_eq(buffer.get_value(), "Before error\n", nil)
    end)

    test.it("nested with blocks", fun ()
        let buf1 = io.StringIO.new()
        let buf2 = io.StringIO.new()

        with sys.redirect_stream(sys.stdout, buf1)
            puts("Outer")

            with sys.redirect_stream(sys.stdout, buf2)
                puts("Inner")
            end  # Auto-restore to buf1

            puts("Outer again")
        end  # Auto-restore to console

        test.assert_eq(buf1.get_value(), "Outer\nOuter again\n", nil)
        test.assert_eq(buf2.get_value(), "Inner\n", nil)
    end)
end)

test.describe("Edge cases", fun ()
    test.it("handles UTF-8 in redirected output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        puts("Hello 世界 → 🌍")

        guard.restore()

        test.assert(buffer.get_value().contains("世界"), "Should handle UTF-8")
        test.assert(buffer.get_value().contains("🌍"), "Should handle emoji")
    end)

    test.it("handles large output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        let i = 0
        while i < 100
            puts("Line " .. i)
            i = i + 1
        end

        guard.restore()

        let lines = buffer.get_value().split("\n")
        test.assert_gte(lines.len(), 100, "Should have at least 100 lines")
    end)

    test.it("empty redirected output", fun ()
        let buffer = io.StringIO.new()
        let guard = sys.redirect_stream(sys.stdout, buffer)

        # No output

        guard.restore()

        test.assert_eq(buffer.get_value(), "", "Empty output should work")
        test.assert(buffer.empty(), "Buffer should be empty")
    end)
end)

test.describe("Multiple simultaneous redirections", fun ()
    test.it("can redirect stdout and stderr independently", fun ()
        let out_buf = io.StringIO.new()
        let err_buf = io.StringIO.new()

        let guard_out = sys.redirect_stream(sys.stdout, out_buf)
        let guard_err = sys.redirect_stream(sys.stderr, err_buf)

        puts("Standard output")
        sys.stderr.write("Error output\n")

        guard_out.restore()
        guard_err.restore()

        test.assert_eq(out_buf.get_value(), "Standard output\n", nil)
        test.assert_eq(err_buf.get_value(), "Error output\n", nil)
    end)

    test.it("stdout and stderr don't interfere", fun ()
        let out_buf = io.StringIO.new()
        let err_buf = io.StringIO.new()

        let guard_out = sys.redirect_stream(sys.stdout, out_buf)
        let guard_err = sys.redirect_stream(sys.stderr, err_buf)

        try
            puts("Normal")
            sys.stderr.write("Error\n")
            puts("More normal")
        ensure
            guard_out.restore()
            guard_err.restore()
        end

        test.assert_eq(out_buf.get_value(), "Normal\nMore normal\n", nil)
        test.assert_eq(err_buf.get_value(), "Error\n", nil)
    end)
end)

test.describe("Stream-to-stream redirection", fun ()
    test.it("can redirect stderr to stdout", fun ()
        let buffer = io.StringIO.new()

        # First redirect stdout to buffer
        let guard_out = sys.redirect_stream(sys.stdout, buffer)

        # Then redirect stderr to stdout (which goes to buffer)
        let guard_err = sys.redirect_stream(sys.stderr, sys.stdout)

        puts("Normal output")
        sys.stderr.write("Error output\n")

        guard_err.restore()
        guard_out.restore()

        # Both should be captured in buffer
        let output = buffer.get_value()
        test.assert(output.contains("Normal output"), "Should have stdout")
        test.assert(output.contains("Error output"), "Should have stderr")
    end)

    test.it("can redirect stdout to stderr", fun ()
        let buffer = io.StringIO.new()

        # Redirect stderr to buffer
        let guard_err = sys.redirect_stream(sys.stderr, buffer)

        # Redirect stdout to stderr (which goes to buffer)
        let guard_out = sys.redirect_stream(sys.stdout, sys.stderr)

        puts("Stdout message")
        sys.stderr.write("Stderr message\n")

        guard_out.restore()
        guard_err.restore()

        # Both captured
        let output = buffer.get_value()
        test.assert(output.contains("Stdout message"), nil)
        test.assert(output.contains("Stderr message"), nil)
    end)
end)

test.describe("Guard state management", fun ()
    test.it("cloned guards share state", fun ()
        let buffer = io.StringIO.new()
        let guard1 = sys.redirect_stream(sys.stdout, buffer)

        puts("Output")

        # Create another reference to same guard
        let guard2 = guard1

        test.assert(guard1.is_active(), "guard1 should be active")
        test.assert(guard2.is_active(), "guard2 should be active")

        guard1.restore()

        # Both should now be inactive (shared state via Rc<RefCell<>>)
        test.assert_eq(guard1.is_active(), false, "guard1 should be inactive")
        test.assert_eq(guard2.is_active(), false, "guard2 should be inactive")
    end)

    test.it("restore from either cloned guard works", fun ()
        let buffer = io.StringIO.new()
        let guard1 = sys.redirect_stream(sys.stdout, buffer)
        let guard2 = guard1

        puts("Test")

        guard2.restore()  # Restore from clone

        # Both inactive
        test.assert_eq(guard1.is_active(), false, nil)

        test.assert_eq(buffer.get_value(), "Test\n", nil)
    end)
end)
