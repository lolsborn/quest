use "std/test" { module, describe, it, assert_eq, assert, assert_type, fail }
use "std/process"

module("Process Module - process.spawn() (QEP-012)")

describe("Basic spawning and output", fun ()
  it("spawns process and reads stdout", fun ()
    let proc = process.spawn(["echo", "Hello from spawn"])
    proc.stdin.close()
    let output = proc.stdout.read()
    let code = proc.wait()

    assert_eq(output.trim(), "Hello from spawn")
    assert_eq(code, 0)  end)

  it("reads output with read() method", fun ()
    let proc = process.spawn(["printf", "test output"])
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "test output")  end)

  it("reads empty output", fun ()
    let proc = process.spawn(["true"])
    proc.stdin.close()
    let output = proc.stdout.read()
    let code = proc.wait()

    assert_eq(output, "", "Should be empty")
    assert_eq(code, 0)  end)
end)

describe("Writing to stdin", fun ()
  it("writes string to stdin", fun ()
    let proc = process.spawn(["cat"])
    proc.stdin.write("Hello stdin")
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "Hello stdin")  end)

  it("writes bytes to stdin", fun ()
    let data = b"Binary input"
    let proc = process.spawn(["cat"])
    proc.stdin.write(data)
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "Binary input")  end)

  it("writes multiple times", fun ()
    let proc = process.spawn(["cat"])
    proc.stdin.write("First ")
    proc.stdin.write("Second ")
    proc.stdin.write("Third")
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "First Second Third")  end)

  it("pipes through grep", fun ()
    let proc = process.spawn(["grep", "match"])
    proc.stdin.write("line 1\nline 2 with match\nline 3\n")
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert(output.contains("match"), "Should contain matched line")
  end)
end)

describe("Stderr handling", fun ()
  it("captures stderr separately", fun ()
    let proc = process.spawn(["perl", "-e", "print STDERR 'error msg'"])
    proc.stdin.close()
    let err_output = proc.stderr.read()
    let std_output = proc.stdout.read()
    proc.wait()

    assert_eq(err_output, "error msg")    assert_eq(std_output, "", "stdout should be empty")
  end)

  it("reads both stdout and stderr", fun ()
    let proc = process.spawn(["sh", "-c", "echo stdout; echo stderr >&2"])
    proc.stdin.close()
    let out = proc.stdout.read()
    let err = proc.stderr.read()
    proc.wait()

    assert(out.contains("stdout"), "Should have stdout")
    assert(err.contains("stderr"), "Should have stderr")
  end)
end)

describe("Process methods", fun ()
  it("wait() returns exit code", fun ()
    let proc = process.spawn(["false"])
    proc.stdin.close()
    proc.stdout.read()
    let code = proc.wait()

    assert_eq(code, 1, "false should return 1")
  end)

  it("wait() returns 0 for success", fun ()
    let proc = process.spawn(["true"])
    proc.stdin.close()
    proc.stdout.read()
    let code = proc.wait()

    assert_eq(code, 0)  end)

  it("pid() returns process ID", fun ()
    let proc = process.spawn(["sleep", "0.01"])
    let pid = proc.pid()
    proc.stdin.close()
    proc.wait()

    assert(pid > 0, "PID should be positive")
  end)

  it("kill() terminates process", fun ()
    let proc = process.spawn(["sleep", "10"])
    proc.kill()
    proc.wait()
    # Process was killed, test passes if no hang
  end)
end)

describe("Stream reading methods", fun ()
  it("readline() reads one line", fun ()
    let proc = process.spawn(["printf", "line1\nline2\nline3"])
    proc.stdin.close()
    let line1 = proc.stdout.readline()
    let line2 = proc.stdout.readline()
    proc.wait()

    assert_eq(line1, "line1\n")    assert_eq(line2, "line2\n")  end)

  it("readline() at EOF returns empty", fun ()
    let proc = process.spawn(["echo", "single"])
    proc.stdin.close()
    proc.stdout.readline()  # Read the line
    let eof = proc.stdout.readline()  # Try to read past EOF
    proc.wait()

    assert_eq(eof, "", "Should be empty at EOF")
  end)

  it("readlines() returns array of lines", fun ()
    let proc = process.spawn(["printf", "a\nb\nc\n"])
    proc.stdin.close()
    let lines = proc.stdout.readlines()
    proc.wait()

    assert_eq(lines.len(), 3)
    assert_eq(lines[0], "a\n")    assert_eq(lines[1], "b\n")    assert_eq(lines[2], "c\n")  end)

  it("read_bytes() returns Bytes", fun ()
    let proc = process.spawn(["echo", "test"])
    proc.stdin.close()
    let bytes = proc.stdout.read_bytes()
    proc.wait()

    assert_type(bytes, "Bytes")    assert(bytes.len() > 0, "Should have bytes")
  end)
end)

describe("Process type", fun ()
  it("has correct type name", fun ()
    let proc = process.spawn(["true"])
    proc.stdin.close()
    proc.wait()

    assert_eq(proc.cls(), "Process")
  end)

  it("stdin has WritableStream type", fun ()
    let proc = process.spawn(["cat"])
    assert_eq(proc.stdin.cls(), "WritableStream")
    proc.stdin.close()
    proc.wait()
  end)

  it("stdout has ReadableStream type", fun ()
    let proc = process.spawn(["echo", "test"])
    assert_eq(proc.stdout.cls(), "ReadableStream")
    proc.stdin.close()
    proc.wait()
  end)

  it("stderr has ReadableStream type", fun ()
    let proc = process.spawn(["echo", "test"])
    assert_eq(proc.stderr.cls(), "ReadableStream")
    proc.stdin.close()
    proc.wait()
  end)
end)

describe("Context manager (with statement)", fun ()
  it("automatically waits with context manager", fun ()
    with process.spawn(["echo", "auto cleanup"]) as proc
      proc.stdin.close()
      let output = proc.stdout.read()
      assert_eq(output.trim(), "auto cleanup")
    end
    # Process should be automatically waited on at end
  end)

  it("cleans up even on error", fun ()
    try
      with process.spawn(["echo", "test"]) as proc
        proc.stdin.close()
        raise "Intentional error"
      end
    catch e
      # Process should still be cleaned up
      assert(e.message().contains("Intentional"))
    end
  end)

  it("nested with blocks work", fun ()
    with process.spawn(["echo", "outer"]) as proc1
      with process.spawn(["echo", "inner"]) as proc2
        proc1.stdin.close()
        proc2.stdin.close()
        let out1 = proc1.stdout.read()
        let out2 = proc2.stdout.read()
        assert_eq(out1.trim(), "outer")
        assert_eq(out2.trim(), "inner")
      end
    end
  end)
end)

describe("Options (cwd and env)", fun ()
  it("runs in specified directory", fun ()
    let proc = process.spawn(["pwd"], {"cwd": "/tmp"})
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert(output.contains("tmp"), "Should be in /tmp")
  end)

  it("sets environment variables", fun ()
    let proc = process.spawn(
      ["sh", "-c", "echo $MY_VAR"],
      {"env": {"MY_VAR": "custom_value", "PATH": "/usr/bin:/bin"}}
    )
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output.trim(), "custom_value")
  end)
end)

describe("Error handling", fun ()
  it("raises error for nonexistent command", fun ()
    try
      process.spawn(["nonexistent-command-xyz"])
      fail("Should raise error")
    catch e
      assert(e.message().contains("No such file"))
    end
  end)

  it("raises error for empty command array", fun ()
    try
      process.spawn([])
      fail("Should raise error")
    catch e
      assert(e.message().contains("cannot be empty"))
    end
  end)
end)

describe("Real-world examples", fun ()
  it("counts lines with wc", fun ()
    let proc = process.spawn(["wc", "-l"])
    proc.stdin.write("line1\nline2\nline3\n")
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert(output.trim().contains("3"), "Should count 3 lines")
  end)

  it("sorts input", fun ()
    let proc = process.spawn(["sort"])
    proc.stdin.write("zebra\napple\nmango\n")
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert(output.contains("apple"), "Should contain apple")
    let lines = output.split("\n")
    assert_eq(lines[0], "apple", "First should be apple")
  end)

  it("filters with grep", fun ()
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
    assert_eq(non_empty.len(), 2, "Should match 2 lines")
  end)
end)
