use "std/test"
use "std/process"

test.module("Process Module - Advanced Features (QEP-012)")

test.describe("wait_with_timeout()", fun ()
    test.it("returns exit code when process finishes quickly", fun ()
        let proc = process.spawn(["echo", "fast"])
        proc.stdin.close()
        proc.stdout.read()
        let code = proc.wait_with_timeout(5)

        test.assert_neq(code, nil, "Should not timeout")
        test.assert_eq(code, 0)    end)

    test.it("returns nil when process times out", fun ()
        let proc = process.spawn(["sleep", "10"])
        let code = proc.wait_with_timeout(1)

        test.assert_eq(code, nil, "Should timeout and return nil")
        proc.kill()  # Cleanup
    end)

    test.it("accepts float seconds", fun ()
        let proc = process.spawn(["echo", "test"])
        proc.stdin.close()
        proc.stdout.read()
        let code = proc.wait_with_timeout(0.5)

        test.assert_neq(code, nil, "Should complete within 0.5s")
    end)
end)

test.describe("communicate()", fun ()
    test.it("sends input and reads all output", fun ()
        let proc = process.spawn(["grep", "match"])
        let result = proc.communicate("line 1\nline with match\nline 3\n")

        test.assert_type(result, "Dict")        test.assert(result["stdout"].contains("match"), "Should have matched line")
        test.assert_eq(result["code"], 0)    end)

    test.it("returns stdout, stderr, and code", fun ()
        let proc = process.spawn(["sh", "-c", "echo out; echo err >&2; exit 5"])
        let result = proc.communicate("")

        test.assert(result["stdout"].contains("out"))
        test.assert(result["stderr"].contains("err"))
        test.assert_eq(result["code"], 5)    end)

    test.it("works with bytes input", fun ()
        let proc = process.spawn(["cat"])
        let result = proc.communicate(b"binary data")

        test.assert_eq(result["stdout"], "binary data")    end)

    test.it("handles empty input", fun ()
        let proc = process.spawn(["cat"])
        let result = proc.communicate("")

        test.assert_eq(result["stdout"], "")        test.assert_eq(result["code"], 0)    end)
end)

test.describe("check_run()", fun ()
    test.it("returns stdout on success", fun ()
        let output = process.check_run(["echo", "test"])
        test.assert_eq(output.trim(), "test")
    end)

    test.it("raises error on non-zero exit", fun ()
        try
            process.check_run(["false"])
            test.fail("Should have raised error")
        catch e
            test.assert(e.message().contains("exit code"), "Should mention exit code")
        end
    end)

    test.it("includes stdout and stderr in error", fun ()
        try
            process.check_run(["sh", "-c", "echo out; echo err >&2; exit 1"])
            test.fail("Should have raised error")
        catch e
            test.assert(e.message().contains("out"), "Should include stdout")
            test.assert(e.message().contains("err"), "Should include stderr")
        end
    end)

    test.it("accepts options (cwd, env, stdin)", fun ()
        let output = process.check_run(
            ["sh", "-c", "pwd; echo $VAR; cat"],
            {"cwd": "/tmp", "env": {"VAR": "value", "PATH": "/usr/bin:/bin"}, "stdin": "input"}
        )
        test.assert(output.contains("tmp"), "Should show cwd")
        test.assert(output.contains("value"), "Should show env var")
        test.assert(output.contains("input"), "Should show stdin")
    end)
end)

test.describe("shell()", fun ()
    test.it("executes shell command with pipes", fun ()
        let result = process.shell("echo hello | tr a-z A-Z")
        test.assert_eq(result.stdout().trim(), "HELLO")
        test.assert(result.success(), "Command should succeed")
    end)

    test.it("handles command with redirects", fun ()
        let result = process.shell("echo output 2>&1")
        test.assert(result.stdout().contains("output"))
    end)

    test.it("supports shell globbing", fun ()
        let result = process.shell("echo *.toml")
        test.assert(result.stdout().len() > 0, "Should expand glob")
    end)

    test.it("accepts options", fun ()
        let result = process.shell("pwd", {"cwd": "/tmp"})
        test.assert(result.stdout().contains("tmp"))
    end)
end)

test.describe("pipeline()", fun ()
    test.it("chains two commands", fun ()
        let result = process.pipeline([
            ["echo", "HELLO"],
            ["tr", "A-Z", "a-z"]
        ])
        test.assert_eq(result.stdout().trim(), "hello")
    end)

    test.it("chains three commands", fun ()
        let result = process.pipeline([
            ["printf", "3\n1\n2"],
            ["sort"],
            ["head", "-n", "1"]
        ])
        test.assert_eq(result.stdout().trim(), "1", "Should get first sorted item")
    end)

    test.it("returns exit code from last command", fun ()
        let result = process.pipeline([
            ["echo", "test"],
            ["grep", "nomatch"]
        ])
        # grep returns 1 when no match
        test.assert_eq(result.code(), 1, "Should get grep's exit code")
    end)

    test.it("handles empty output", fun ()
        let result = process.pipeline([
            ["echo", ""],
            ["cat"]
        ])
        test.assert(result.success())
    end)
end)

test.describe("writelines()", fun ()
    test.it("writes multiple lines", fun ()
        let proc = process.spawn(["cat"])
        proc.stdin.writelines(["line1\n", "line2\n", "line3\n"])
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "line1\nline2\nline3\n")    end)

    test.it("works with empty array", fun ()
        let proc = process.spawn(["cat"])
        proc.stdin.writelines([])
        proc.stdin.close()
        let output = proc.stdout.read()
        proc.wait()

        test.assert_eq(output, "")    end)
end)

test.describe("timeout option in run()", fun ()
    test.it("enforces timeout", fun ()
        try
            process.run(["sleep", "10"], {"timeout": 1})
            test.fail("Should have timed out")
        catch e
            test.assert(e.message().contains("timeout"), "Should mention timeout")
        end
    end)

    test.it("doesn't timeout for fast commands", fun ()
        let result = process.run(["echo", "fast"], {"timeout": 5})
        test.assert(result.success(), "Should succeed")
        test.assert_eq(result.stdout().trim(), "fast")
    end)

    test.it("accepts float timeout", fun ()
        let result = process.run(["echo", "test"], {"timeout": 0.5})
        test.assert(result.success())
    end)
end)

test.describe("terminate() vs kill()", fun ()
    test.it("terminate() stops process", fun ()
        let proc = process.spawn(["sleep", "10"])
        proc.terminate()
        let code = proc.wait_with_timeout(2)
        # Process should have been terminated
    end)

    test.it("kill() stops process", fun ()
        let proc = process.spawn(["sleep", "10"])
        proc.kill()
        proc.wait()
        # If we get here, process was killed
    end)
end)

test.describe("Integration examples", fun ()
    test.it("pipeline for data processing", fun ()
        # Count unique words
        let result = process.pipeline([
            ["printf", "apple\nbanana\napple\ncherry\nbanana\napple"],
            ["sort"],
            ["uniq", "-c"]
        ])
        test.assert(result.stdout().contains("3"), "Should count 3 apples")
        test.assert(result.stdout().contains("2"), "Should count 2 bananas")
    end)

    test.it("check_run for build scripts", fun ()
        # Simulate a build command that must succeed
        let output = process.check_run(["echo", "Build successful"])
        test.assert(output.contains("successful"))
    end)

    test.it("communicate for filters", fun ()
        let proc = process.spawn(["grep", "-v", "skip"])
        let result = proc.communicate("keep this\nskip this line\nkeep this too\n")
        test.assert(result["stdout"].contains("keep this"))
        test.assert_eq(result["stdout"].contains("skip"), false, "Should not include skipped line")
    end)
end)
