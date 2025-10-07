use "std/test"
use "std/process"

test.module("Process Module - process.spawn() (QEP-012)")

test.describe("Basic spawning and output", fun ()
    test.it("spawns process and reads stdout", fun ()
        let proc = process.spawn(["echo", "Hello from spawn"])
        proc.stdin.close()
        let output = proc.stdout.read()
        let code = proc.wait()

        test.assert_eq(output.trim(), "Hello from spawn", nil)
        test.assert_eq(code, 0)    end)

    test.it("reads output with read() method", fun ()
        let proc = process.spawn(["printf", "test output"])
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "test output")    end)

    test.it("reads empty output", fun ()
        let proc = process.spawn(["true"])
        proc.stdin.close()
        let output = proc.stdout.read()
        let code = proc.wait()

        test.assert_eq(output, "", "Should be empty")
        test.assert_eq(code, 0)    end)
end)

test.describe("Writing to stdin", fun ()
    test.it("writes string to stdin", fun ()
        let proc = process.spawn(["cat"])
        proc.stdin.write("Hello stdin")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "Hello stdin")    end)

    test.it("writes bytes to stdin", fun ()
        let data = b"Binary input"
        let proc = process.spawn(["cat"])
        proc.stdin.write(data)
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "Binary input")    end)

    test.it("writes multiple times", fun ()
        let proc = process.spawn(["cat"])
        proc.stdin.write("First ")
        proc.stdin.write("Second ")
        proc.stdin.write("Third")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "First Second Third")    end)

    test.it("pipes through grep", fun ()
        let proc = process.spawn(["grep", "match"])
        proc.stdin.write("line 1\nline 2 with match\nline 3\n")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert(output.contains("match"), "Should contain matched line")
    end)
end)

test.describe("Stderr handling", fun ()
    test.it("captures stderr separately", fun ()
        let proc = process.spawn(["perl", "-e", "print STDERR 'error msg'"])
        proc.stdin.close()
        let err_output = proc.stderr.read()
        let std_output = proc.stdout.read()
        proc.wait()

        test.assert_eq(err_output, "error msg")        test.assert_eq(std_output, "", "stdout should be empty")
    end)

    test.it("reads both stdout and stderr", fun ()
        let proc = process.spawn(["sh", "-c", "echo stdout; echo stderr >&2"])
        proc.stdin.close()
        let out = proc.stdout.read()
        let err = proc.stderr.read()
        proc.wait()

        test.assert(out.contains("stdout"), "Should have stdout")
        test.assert(err.contains("stderr"), "Should have stderr")
    end)
end)

test.describe("Process methods", fun ()
    test.it("wait() returns exit code", fun ()
        let proc = process.spawn(["false"])
        proc.stdin.close()
        proc.stdout.read()
        let code = proc.wait()

        test.assert_eq(code, 1, "false should return 1")
    end)

    test.it("wait() returns 0 for success", fun ()
        let proc = process.spawn(["true"])
        proc.stdin.close()
        proc.stdout.read()
        let code = proc.wait()

        test.assert_eq(code, 0)    end)

    test.it("pid() returns process ID", fun ()
        let proc = process.spawn(["sleep", "0.01"])
        let pid = proc.pid()
        proc.stdin.close()
        proc.wait()

        test.assert(pid > 0, "PID should be positive")
    end)

    test.it("kill() terminates process", fun ()
        let proc = process.spawn(["sleep", "10"])
        proc.kill()
        proc.wait()
        # Process was killed, test passes if no hang
    end)
end)

test.describe("Stream reading methods", fun ()
    test.it("readline() reads one line", fun ()
        let proc = process.spawn(["printf", "line1\nline2\nline3"])
        proc.stdin.close()
        let line1 = proc.stdout.readline()
        let line2 = proc.stdout.readline()
        proc.wait()

        test.assert_eq(line1, "line1\n")        test.assert_eq(line2, "line2\n")    end)

    test.it("readline() at EOF returns empty", fun ()
        let proc = process.spawn(["echo", "single"])
        proc.stdin.close()
        proc.stdout.readline()  # Read the line
        let eof = proc.stdout.readline()  # Try to read past EOF
        proc.wait()

        test.assert_eq(eof, "", "Should be empty at EOF")
    end)

    test.it("readlines() returns array of lines", fun ()
        let proc = process.spawn(["printf", "a\nb\nc\n"])
        proc.stdin.close()
        let lines = proc.stdout.readlines()
        proc.wait()

        test.assert_eq(lines.len(), 3, nil)
        test.assert_eq(lines[0], "a\n")        test.assert_eq(lines[1], "b\n")        test.assert_eq(lines[2], "c\n")    end)

    test.it("read_bytes() returns Bytes", fun ()
        let proc = process.spawn(["echo", "test"])
        proc.stdin.close()
        let bytes = proc.stdout.read_bytes()
        proc.wait()

        test.assert_type(bytes, "Bytes")        test.assert(bytes.len() > 0, "Should have bytes")
    end)
end)

test.describe("Process type", fun ()
    test.it("has correct type name", fun ()
        let proc = process.spawn(["true"])
        proc.stdin.close()
        proc.wait()

        test.assert_eq(proc.cls(), "Process", nil)
    end)

    test.it("stdin has WritableStream type", fun ()
        let proc = process.spawn(["cat"])
        test.assert_eq(proc.stdin.cls(), "WritableStream", nil)
        proc.stdin.close()
        proc.wait()
    end)

    test.it("stdout has ReadableStream type", fun ()
        let proc = process.spawn(["echo", "test"])
        test.assert_eq(proc.stdout.cls(), "ReadableStream", nil)
        proc.stdin.close()
        proc.wait()
    end)

    test.it("stderr has ReadableStream type", fun ()
        let proc = process.spawn(["echo", "test"])
        test.assert_eq(proc.stderr.cls(), "ReadableStream", nil)
        proc.stdin.close()
        proc.wait()
    end)
end)

test.describe("Context manager (with statement)", fun ()
    test.it("automatically waits with context manager", fun ()
        with process.spawn(["echo", "auto cleanup"]) as proc
            proc.stdin.close()
            let output = proc.stdout.read()
            test.assert_eq(output.trim(), "auto cleanup", nil)
        end
        # Process should be automatically waited on at end
    end)

    test.it("cleans up even on error", fun ()
        try
            with process.spawn(["echo", "test"]) as proc
                proc.stdin.close()
                raise "Intentional error"
            end
        catch e
            # Process should still be cleaned up
            test.assert(e.message().contains("Intentional"), nil)
        end
    end)

    test.it("nested with blocks work", fun ()
        with process.spawn(["echo", "outer"]) as proc1
            with process.spawn(["echo", "inner"]) as proc2
                proc1.stdin.close()
                proc2.stdin.close()
                let out1 = proc1.stdout.read()
                let out2 = proc2.stdout.read()
                test.assert_eq(out1.trim(), "outer", nil)
                test.assert_eq(out2.trim(), "inner", nil)
            end
        end
    end)
end)

test.describe("Options (cwd and env)", fun ()
    test.it("runs in specified directory", fun ()
        let proc = process.spawn(["pwd"], {"cwd": "/tmp"})
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert(output.contains("tmp"), "Should be in /tmp")
    end)

    test.it("sets environment variables", fun ()
        let proc = process.spawn(
            ["sh", "-c", "echo $MY_VAR"],
            {"env": {"MY_VAR": "custom_value", "PATH": "/usr/bin:/bin"}}
        )
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output.trim(), "custom_value", nil)
    end)
end)

test.describe("Error handling", fun ()
    test.it("raises error for nonexistent command", fun ()
        try
            process.spawn(["nonexistent-command-xyz"])
            test.fail("Should raise error")
        catch e
            test.assert(e.message().contains("No such file"), nil)
        end
    end)

    test.it("raises error for empty command array", fun ()
        try
            process.spawn([])
            test.fail("Should raise error")
        catch e
            test.assert(e.message().contains("cannot be empty"), nil)
        end
    end)
end)

test.describe("Real-world examples", fun ()
    test.it("counts lines with wc", fun ()
        let proc = process.spawn(["wc", "-l"])
        proc.stdin.write("line1\nline2\nline3\n")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert(output.trim().contains("3"), "Should count 3 lines")
    end)

    test.it("sorts input", fun ()
        let proc = process.spawn(["sort"])
        proc.stdin.write("zebra\napple\nmango\n")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert(output.contains("apple"), "Should contain apple")
        let lines = output.split("\n")
        test.assert_eq(lines[0], "apple", "First should be apple")
    end)

    test.it("filters with grep", fun ()
        let proc = process.spawn(["grep", "-i", "error"])
        proc.stdin.write("INFO: starting\nERROR: failed\nWARN: issue\nError: another\n")
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        let lines = output.split("\n")
        let non_empty = []
        let i = 0
        while i < lines.len()
            if lines[i].len() > 0
                non_empty.push(lines[i])
            end
            i = i + 1
        end
        test.assert_eq(non_empty.len(), 2, "Should match 2 lines")
    end)
end)
