use "std/test" { module, describe, it, assert_eq, assert_neq, assert_type, assert }
use "std/process"

module("Process Module - Advanced Features (QEP-012)")

describe("wait_with_timeout()", fun ()
  it("returns exit code when process finishes quickly", fun ()
    let proc = process.spawn(["echo", "fast"])
    proc.stdin.close()
    proc.stdout.read()
    let code = proc.wait_with_timeout(5)

    assert_neq(code, nil, "Should not timeout")
    assert_eq(code, 0)  end)

  it("returns nil when process times out", fun ()
    let proc = process.spawn(["sleep", "10"])
    let code = proc.wait_with_timeout(1)

    assert_eq(code, nil, "Should timeout and return nil")
    proc.kill()  # Cleanup
  end)

  it("accepts float seconds", fun ()
    let proc = process.spawn(["echo", "test"])
    proc.stdin.close()
    proc.stdout.read()
    let code = proc.wait_with_timeout(0.5)

    assert_neq(code, nil, "Should complete within 0.5s")
  end)
end)

describe("communicate()", fun ()
  it("sends input and reads all output", fun ()
    let proc = process.spawn(["grep", "match"])
    let result = proc.communicate("line 1\nline with match\nline 3\n")

    assert_type(result, "Dict")
    assert(result["stdout"].contains("match"), "Should have matched line")
    assert_eq(result["code"], 0)
  end)

  it("returns stdout, stderr, and code", fun ()
    let proc = process.spawn(["sh", "-c", "echo out; echo err >&2; exit 5"])
    let result = proc.communicate("")

    assert(result["stdout"].contains("out"))
    assert(result["stderr"].contains("err"))
    assert_eq(result["code"], 5)
  end)

  it("works with bytes input", fun ()
    let proc = process.spawn(["cat"])
    let result = proc.communicate(b"binary data")

    assert_eq(result["stdout"], "binary data")
  end)

  it("handles empty input", fun ()
    let proc = process.spawn(["cat"])
    let result = proc.communicate("")

    assert_eq(result["stdout"], "")
    assert_eq(result["code"], 0)
  end)
end)

describe("check_run()", fun ()
  it("returns stdout on success", fun ()
    let output = process.check_run(["echo", "test"])
    assert_eq(output.trim(), "test")
  end)

  it("raises error on non-zero exit", fun ()
    try
      process.check_run(["false"])
      fail("Should have raised error")
    catch e
      assert(e.message().contains("exit code"), "Should mention exit code")
    end
  end)

  it("includes stdout and stderr in error", fun ()
    try
      process.check_run(["sh", "-c", "echo out; echo err >&2; exit 1"])
      fail("Should have raised error")
    catch e
      assert(e.message().contains("out"), "Should include stdout")
      assert(e.message().contains("err"), "Should include stderr")
    end
  end)

  it("accepts options (cwd, env, stdin)", fun ()
    let output = process.check_run(
      ["sh", "-c", "pwd; echo $VAR; cat"],
      {"cwd": "/tmp", "env": {"VAR": "value", "PATH": "/usr/bin:/bin"}, "stdin": "input"}
    )
    assert(output.contains("tmp"), "Should show cwd")
    assert(output.contains("value"), "Should show env var")
    assert(output.contains("input"), "Should show stdin")
  end)
end)

describe("shell()", fun ()
  it("executes shell command with pipes", fun ()
    let result = process.shell("echo hello | tr a-z A-Z")
    assert_eq(result.stdout().trim(), "HELLO")
    assert(result.success(), "Command should succeed")
  end)

  it("handles command with redirects", fun ()
    let result = process.shell("echo output 2>&1")
    assert(result.stdout().contains("output"))
  end)

  it("supports shell globbing", fun ()
    let result = process.shell("echo *.toml")
    assert(result.stdout().len() > 0, "Should expand glob")
  end)

  it("accepts options", fun ()
    let result = process.shell("pwd", {"cwd": "/tmp"})
    assert(result.stdout().contains("tmp"))
  end)
end)

describe("pipeline()", fun ()
  it("chains two commands", fun ()
    let result = process.pipeline([
      ["echo", "HELLO"],
      ["tr", "A-Z", "a-z"]
    ])
    assert_eq(result.stdout().trim(), "hello")
  end)

  it("chains three commands", fun ()
    let result = process.pipeline([
      ["printf", "3\n1\n2"],
      ["sort"],
      ["head", "-n", "1"]
    ])
    assert_eq(result.stdout().trim(), "1", "Should get first sorted item")
  end)

  it("returns exit code from last command", fun ()
    let result = process.pipeline([
      ["echo", "test"],
      ["grep", "nomatch"]
    ])
    # grep returns 1 when no match
    assert_eq(result.code(), 1, "Should get grep's exit code")
  end)

  it("handles empty output", fun ()
    let result = process.pipeline([
      ["echo", ""],
      ["cat"]
    ])
    assert(result.success())
  end)
end)

describe("writelines()", fun ()
  it("writes multiple lines", fun ()
    let proc = process.spawn(["cat"])
    proc.stdin.writelines(["line1\n", "line2\n", "line3\n"])
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "line1\nline2\nline3\n")  end)

  it("works with empty array", fun ()
    let proc = process.spawn(["cat"])
    proc.stdin.writelines([])
    proc.stdin.close()
    let output = proc.stdout.read()
    proc.wait()

    assert_eq(output, "")  end)
end)

describe("timeout option in run()", fun ()
  it("enforces timeout", fun ()
    try
      process.run(["sleep", "10"], {"timeout": 1})
      fail("Should have timed out")
    catch e
      assert(e.message().contains("timeout"), "Should mention timeout")
    end
  end)

  it("doesn't timeout for fast commands", fun ()
    let result = process.run(["echo", "fast"], {"timeout": 5})
    assert(result.success(), "Should succeed")
    assert_eq(result.stdout().trim(), "fast")
  end)

  it("accepts float timeout", fun ()
    let result = process.run(["echo", "test"], {"timeout": 0.5})
    assert(result.success())
  end)
end)

describe("terminate() vs kill()", fun ()
  it("terminate() stops process", fun ()
    let proc = process.spawn(["sleep", "10"])
    proc.terminate()
    let code = proc.wait_with_timeout(2)
    # Process should have been terminated
  end)

  it("kill() stops process", fun ()
    let proc = process.spawn(["sleep", "10"])
    proc.kill()
    proc.wait()
    # If we get here, process was killed
  end)
end)

describe("Integration examples", fun ()
  it("pipeline for data processing", fun ()
    # Count unique words
    let result = process.pipeline([
      ["printf", "apple\nbanana\napple\ncherry\nbanana\napple"],
      ["sort"],
      ["uniq", "-c"]
    ])
    assert(result.stdout().contains("3"), "Should count 3 apples")
    assert(result.stdout().contains("2"), "Should count 2 bananas")
  end)

  it("check_run for build scripts", fun ()
    # Simulate a build command that must succeed
    let output = process.check_run(["echo", "Build successful"])
    assert(output.contains("successful"))
  end)

  it("communicate for filters", fun ()
    let proc = process.spawn(["grep", "-v", "skip"])
    let result = proc.communicate("keep this\nskip this line\nkeep this too\n")
    assert(result["stdout"].contains("keep this"))
    assert_eq(result["stdout"].contains("skip"), false, "Should not include skipped line")
  end)
end)
