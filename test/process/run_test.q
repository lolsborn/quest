use "std/test" { module, describe, it, assert_eq, assert_neq, assert_type, assert }
use "std/process"

module("Process Module - process.run() (QEP-012)")

describe("Basic command execution", fun ()
  it("runs echo command and captures output", fun ()
    let result = process.run(["echo", "Hello, World!"])
    assert_eq(result.stdout().trim(), "Hello, World!")
    assert_eq(result.code(), 0)
    assert(result.success(), "Command should succeed")
  end)

  it("runs command with multiple arguments", fun ()
    let result = process.run(["printf", "one two three"])
    assert_eq(result.stdout(), "one two three")
    assert_eq(result.code(), 0)
  end)

  it("captures stderr separately from stdout", fun ()
    # Use perl to write to stderr
    let result = process.run(["perl", "-e", "print STDERR 'error message'"])
    assert_eq(result.stderr(), "error message")
    assert_eq(result.stdout(), "", "stdout should be empty")
  end)
end)

describe("Exit codes and success", fun ()
  it("returns non-zero exit code for false command", fun ()
    let result = process.run(["false"])
    assert_eq(result.code(), 1)
    assert_eq(result.success(), false, "false command should fail")
  end)

  it("returns zero exit code for true command", fun ()
    let result = process.run(["true"])
    assert_eq(result.code(), 0)
    assert(result.success(), "true command should succeed")
  end)

  it("success() method returns correct boolean", fun ()
    let success_result = process.run(["echo", "test"])
    assert(success_result.success(), "Echo should succeed")

    let fail_result = process.run(["false"])
    assert_eq(fail_result.success(), false, "False should fail")
  end)
end)

describe("ProcessResult as boolean (truthiness)", fun ()
  it("successful result is truthy", fun ()
    let result = process.run(["true"])
    if result
      # Success
    else
      fail("Successful ProcessResult should be truthy")
    end
  end)

  it("failed result is falsy", fun ()
    let result = process.run(["false"])
    if result
      fail("Failed ProcessResult should be falsy")
    end
  end)
end)

describe("Binary data (stdout_bytes, stderr_bytes)", fun ()
  it("stdout_bytes returns raw bytes", fun ()
    let result = process.run(["echo", "test"])
    let bytes = result.stdout_bytes()
    assert_type(bytes, "Bytes")    assert(bytes.len() > 0, "Should have bytes")
  end)

  it("stderr_bytes returns raw bytes", fun ()
    let result = process.run(["perl", "-e", "print STDERR 'err'"])
    let bytes = result.stderr_bytes()
    assert_type(bytes, "Bytes")    assert(bytes.len() > 0, "Should have bytes")
  end)
end)

describe("Working directory (cwd option)", fun ()
  it("runs command in specified directory", fun ()
    let result = process.run(["pwd"], {"cwd": "/tmp"})
    assert(result.stdout().contains("tmp"), "Should be in /tmp")
    assert(result.success(), "Command should succeed")
  end)
end)

describe("Environment variables (env option)", fun ()
  it("sets environment variables", fun ()
    let result = process.run(
      ["sh", "-c", "echo $TEST_VAR"],
      {"env": {"TEST_VAR": "test_value", "PATH": "/usr/bin:/bin"}}
    )
    assert_eq(result.stdout().trim(), "test_value")
    assert(result.success(), "Command should succeed")
  end)
end)

describe("Stdin data (stdin option)", fun ()
  it("sends data to stdin", fun ()
    let result = process.run(["cat"], {"stdin": "Hello from stdin"})
    assert_eq(result.stdout(), "Hello from stdin")
    assert(result.success(), "Command should succeed")
  end)

  it("sends bytes to stdin", fun ()
    let input = b"Binary data"
    let result = process.run(["cat"], {"stdin": input})
    assert_eq(result.stdout(), "Binary data")
  end)

  it("pipes data through grep", fun ()
    let input = "line 1\nline 2 with match\nline 3\n"
    let result = process.run(["grep", "match"], {"stdin": input})
    assert(result.stdout().contains("line 2 with match"), "Should find matching line")
  end)
end)

describe("Error handling", fun ()
  it("raises error for nonexistent command", fun ()
    try
      process.run(["this-command-does-not-exist-12345"])
      fail("Should raise error for nonexistent command")
    catch e
      assert(e.message().contains("No such file"), "Error should mention file not found")
    end
  end)

  it("raises error for empty command array", fun ()
    try
      process.run([])
      fail("Should raise error for empty command array")
    catch e
      assert(e.message().contains("cannot be empty"), "Error should mention empty array")
    end
  end)
end)

describe("ProcessResult type", fun ()
  it("has correct type name", fun ()
    let result = process.run(["echo", "test"])
    assert_eq(result.cls(), "ProcessResult")
  end)

  it("has unique object ID", fun ()
    let result1 = process.run(["echo", "test1"])
    let result2 = process.run(["echo", "test2"])
    assert_neq(result1._id(), result2._id(), "Results should have different IDs")
  end)
end)

describe("Multiple options combined", fun ()
  it("combines cwd, env, and stdin options", fun ()
    let result = process.run(
      ["sh", "-c", "pwd; echo $MY_VAR; cat"],
      {
        "cwd": "/tmp",
        "env": {"MY_VAR": "my_value", "PATH": "/usr/bin:/bin"},
        "stdin": "stdin_content"
      }
    )
    assert(result.stdout().contains("tmp"), "Should show /tmp")
    assert(result.stdout().contains("my_value"), "Should show env var")
    assert(result.stdout().contains("stdin_content"), "Should show stdin")
    assert(result.success(), "Command should succeed")
  end)
end)

describe("Real-world examples", fun ()
  it("lists files with ls", fun ()
    let result = process.run(["ls", "/"])
    assert(result.success(), "ls should succeed")
    assert(result.stdout().len() > 0, "Should have output")
  end)

  it("counts lines with wc", fun ()
    let result = process.run(["wc", "-l"], {"stdin": "line1\nline2\nline3\n"})
    assert(result.stdout().trim().contains("3"), "Should count 3 lines")
  end)

  it("uses printf for formatting", fun ()
    let result = process.run(["printf", "%s %d", "Count:", "42"])
    assert_eq(result.stdout(), "Count: 42")
  end)
end)
