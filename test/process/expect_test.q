use "std/test" as test
use "std/process/expect" as expect

test.module("Expect Library")

test.describe("Basic spawning", fun ()
    test.skip("spawns and closes a process", fun ()
        let session = expect.spawn(["echo", "hello"], nil, nil, nil)
        test.assert(session.is_alive(), "Process should be running initially")

        let status = session.expect_eof(5)
        test.assert_eq(status, 0, "Should exit with status 0")
    end)

    test.skip("reads output with read_nonblocking", fun ()
        let session = expect.spawn(["echo", "test output"], nil, nil, nil)
        let output = session.read_nonblocking(1024, 1)
        test.assert(output.contains("test output"), "Should contain echoed text")
        session.expect_eof(5)
    end)
end)

test.describe("Pattern matching", fun ()
    test.skip("matches literal strings", fun ()
        let session = expect.spawn(["sh", "-c", "printf 'Ready: '; read x; echo $x"], nil, nil, nil)

        let matched = session.expect("Ready: ", 5)
        test.assert_eq(matched, "Ready: ", "Should match prompt")

        session.send_line("test")
        session.expect_eof(5)
    end)

    test.skip("captures before and after text", fun ()
        let session = expect.spawn(["sh", "-c", "echo 'START'; printf 'MIDDLE'; echo 'END'"], nil, nil, nil)

        session.expect("MIDDLE", 5)
        test.assert(session.before.contains("START"), "Before should contain START")
        test.assert(session.after.contains("END"), "After should contain END")

        session.expect_eof(5)
    end)
end)

test.describe("Control characters", fun ()
    test.skip("sends Ctrl-D to exit shell", fun ()
        let session = expect.spawn(["sh"], nil, nil, nil)
        session.send_control("d")

        let status = session.expect_eof(5)
        test.assert_eq(status, 0, "Shell should exit with status 0")
    end)
end)

test.describe("Timeouts", fun ()
    test.skip("raises TimeoutError on timeout", fun ()
        let session = expect.spawn(["sleep", "10"], nil, nil, nil)

        let error_caught = false
        try
            session.expect("never_appears", 1)
        catch e
            error_caught = true
            # Check that it's a TimeoutError by checking the message
            let msg = e.message()
            test.assert(msg.contains("Timeout"), "Should be timeout error")
        end

        test.assert(error_caught, "Should raise timeout error")
        session.close(true)  # Force kill
    end)
end)

test.describe("EOF handling", fun ()
    test.skip("raises EOFError when process exits unexpectedly", fun ()
        let session = expect.spawn(["echo", "quick"], nil, nil, nil)

        # Give it time to print and exit
        use "std/time" as time
        time.sleep(0.2)

        let error_caught = false
        try
            # Try to expect something after process exits
            session.expect("never_appears", 2)
        catch e
            error_caught = true
            let msg = e.message()
            test.assert(msg.contains("EOF"), "Should be EOF error")
        end

        test.assert(error_caught, "Should raise EOF error")
    end)
end)

test.describe("Multiple send/expect", fun ()
    test.skip("handles multiple interactions", fun ()
        let session = expect.spawn(["sh"], nil, nil, nil)

        session.send_line("echo first")
        session.send_line("echo second")
        session.send_line("exit")

        let status = session.expect_eof(5)
        test.assert_eq(status, 0, "Shell should exit cleanly")

        # Buffer should contain both echoes
        test.assert(session.buffer.contains("first"), "Should have first output")
        test.assert(session.buffer.contains("second"), "Should have second output")
    end)
end)
