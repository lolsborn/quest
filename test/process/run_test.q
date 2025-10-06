use "std/test"
use "std/process"

test.module("Process Module - process.run() (QEP-012)")

test.describe("Basic command execution", fun ()
    test.it("runs echo command and captures output", fun ()
        let result = process.run(["echo", "Hello, World!"])
        test.assert_eq(result.stdout().trim(), "Hello, World!", nil)
        test.assert_eq(result.code(), 0, nil)
        test.assert(result.success(), "Command should succeed")
    end)

    test.it("runs command with multiple arguments", fun ()
        let result = process.run(["printf", "one two three"])
        test.assert_eq(result.stdout(), "one two three", nil)
        test.assert_eq(result.code(), 0, nil)
    end)

    test.it("captures stderr separately from stdout", fun ()
        # Use perl to write to stderr
        let result = process.run(["perl", "-e", "print STDERR 'error message'"])
        test.assert_eq(result.stderr(), "error message", nil)
        test.assert_eq(result.stdout(), "", "stdout should be empty")
    end)
end)

test.describe("Exit codes and success", fun ()
    test.it("returns non-zero exit code for false command", fun ()
        let result = process.run(["false"])
        test.assert_eq(result.code(), 1, nil)
        test.assert_eq(result.success(), false, "false command should fail")
    end)

    test.it("returns zero exit code for true command", fun ()
        let result = process.run(["true"])
        test.assert_eq(result.code(), 0, nil)
        test.assert(result.success(), "true command should succeed")
    end)

    test.it("success() method returns correct boolean", fun ()
        let success_result = process.run(["echo", "test"])
        test.assert(success_result.success(), "Echo should succeed")

        let fail_result = process.run(["false"])
        test.assert_eq(fail_result.success(), false, "False should fail")
    end)
end)

test.describe("ProcessResult as boolean (truthiness)", fun ()
    test.it("successful result is truthy", fun ()
        let result = process.run(["true"])
        if result
            # Success
        else
            test.fail("Successful ProcessResult should be truthy")
        end
    end)

    test.it("failed result is falsy", fun ()
        let result = process.run(["false"])
        if result
            test.fail("Failed ProcessResult should be falsy")
        end
    end)
end)

test.describe("Binary data (stdout_bytes, stderr_bytes)", fun ()
    test.it("stdout_bytes returns raw bytes", fun ()
        let result = process.run(["echo", "test"])
        let bytes = result.stdout_bytes()
        test.assert_type(bytes, "Bytes", nil)
        test.assert(bytes.len() > 0, "Should have bytes")
    end)

    test.it("stderr_bytes returns raw bytes", fun ()
        let result = process.run(["perl", "-e", "print STDERR 'err'"])
        let bytes = result.stderr_bytes()
        test.assert_type(bytes, "Bytes", nil)
        test.assert(bytes.len() > 0, "Should have bytes")
    end)
end)

test.describe("Working directory (cwd option)", fun ()
    test.it("runs command in specified directory", fun ()
        let result = process.run(["pwd"], {"cwd": "/tmp"})
        test.assert(result.stdout().contains("tmp"), "Should be in /tmp")
        test.assert(result.success(), "Command should succeed")
    end)
end)

test.describe("Environment variables (env option)", fun ()
    test.it("sets environment variables", fun ()
        let result = process.run(
            ["sh", "-c", "echo $TEST_VAR"],
            {"env": {"TEST_VAR": "test_value", "PATH": "/usr/bin:/bin"}}
        )
        test.assert_eq(result.stdout().trim(), "test_value", nil)
        test.assert(result.success(), "Command should succeed")
    end)
end)

test.describe("Stdin data (stdin option)", fun ()
    test.it("sends data to stdin", fun ()
        let result = process.run(["cat"], {"stdin": "Hello from stdin"})
        test.assert_eq(result.stdout(), "Hello from stdin", nil)
        test.assert(result.success(), "Command should succeed")
    end)

    test.it("sends bytes to stdin", fun ()
        let input = b"Binary data"
        let result = process.run(["cat"], {"stdin": input})
        test.assert_eq(result.stdout(), "Binary data", nil)
    end)

    test.it("pipes data through grep", fun ()
        let input = "line 1\nline 2 with match\nline 3\n"
        let result = process.run(["grep", "match"], {"stdin": input})
        test.assert(result.stdout().contains("line 2 with match"), "Should find matching line")
    end)
end)

test.describe("Error handling", fun ()
    test.it("raises error for nonexistent command", fun ()
        try
            process.run(["this-command-does-not-exist-12345"])
            test.fail("Should raise error for nonexistent command")
        catch e
            test.assert(e.message().contains("No such file"), "Error should mention file not found")
        end
    end)

    test.it("raises error for empty command array", fun ()
        try
            process.run([])
            test.fail("Should raise error for empty command array")
        catch e
            test.assert(e.message().contains("cannot be empty"), "Error should mention empty array")
        end
    end)
end)

test.describe("ProcessResult type", fun ()
    test.it("has correct type name", fun ()
        let result = process.run(["echo", "test"])
        test.assert_eq(result.cls(), "ProcessResult", nil)
    end)

    test.it("has unique object ID", fun ()
        let result1 = process.run(["echo", "test1"])
        let result2 = process.run(["echo", "test2"])
        test.assert_neq(result1._id(), result2._id(), "Results should have different IDs")
    end)
end)

test.describe("Multiple options combined", fun ()
    test.it("combines cwd, env, and stdin options", fun ()
        let result = process.run(
            ["sh", "-c", "pwd; echo $MY_VAR; cat"],
            {
                "cwd": "/tmp",
                "env": {"MY_VAR": "my_value", "PATH": "/usr/bin:/bin"},
                "stdin": "stdin_content"
            }
        )
        test.assert(result.stdout().contains("tmp"), "Should show /tmp")
        test.assert(result.stdout().contains("my_value"), "Should show env var")
        test.assert(result.stdout().contains("stdin_content"), "Should show stdin")
        test.assert(result.success(), "Command should succeed")
    end)
end)

test.describe("Real-world examples", fun ()
    test.it("lists files with ls", fun ()
        let result = process.run(["ls", "/"])
        test.assert(result.success(), "ls should succeed")
        test.assert(result.stdout().len() > 0, "Should have output")
    end)

    test.it("counts lines with wc", fun ()
        let result = process.run(["wc", "-l"], {"stdin": "line1\nline2\nline3\n"})
        test.assert(result.stdout().trim().contains("3"), "Should count 3 lines")
    end)

    test.it("uses printf for formatting", fun ()
        let result = process.run(["printf", "%s %d", "Count:", "42"])
        test.assert_eq(result.stdout(), "Count: 42", nil)
    end)
end)
