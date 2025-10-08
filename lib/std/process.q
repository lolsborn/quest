"""
External process execution and subprocess management (QEP-012).

This module provides safe, cross-platform subprocess execution with support for
capturing output, streaming I/O, pipes, timeouts, and process control.

Security: No shell by default - use array arguments to prevent injection attacks.

Available Functions:
- process.run(command, options?) - Execute and wait for completion
- process.spawn(command, options?) - Spawn with streaming I/O
- process.check_run(command, options?) - Execute and raise on failure
- process.shell(command, options?) - DANGEROUS - Execute via shell
- process.pipeline(commands) - Chain multiple commands

Quick Start:
  use "std/process" as process

  # Simple command execution
  let result = process.run(["ls", "-la"])
  puts(result.stdout())

  # With options
  let result = process.run(["python", "script.py"], {
      "cwd": "/projects",
      "env": {"PYTHONPATH": "/libs"},
      "timeout": 30
  })

  # Streaming I/O
  let proc = process.spawn(["grep", "error"])
  proc.stdin.write("line 1\n")
  proc.stdin.write("line 2 with error\n")
  proc.stdin.close()
  let output = proc.stdout.read()
  proc.wait()

Security Best Practices:
  # SAFE - Array arguments prevent injection
  let file = user_input
  let result = process.run(["grep", "pattern", file])

  # DANGEROUS - Shell injection possible
  let result = process.shell("grep pattern " .. user_input)

See QEP-012 for full documentation.
"""
