# std/sys - System Module
#
# Provides system-level functionality including process control, module loading,
# and I/O redirection.
#
# Usage:
#   use "std/sys"
#
#   puts("Platform: " .. sys.platform)
#   puts("Version: " .. sys.version)
#
#   # I/O redirection (QEP-010)
#   let buf = io.StringIO.new()
#   let guard = sys.redirect_stdout(buf)
#   puts("Captured")
#   guard.restore()
#
# === Module Variables ===
#
# sys.version -> Str
#   Quest version string (from Cargo.toml)
#
#   Example:
#     puts("Quest version: " .. sys.version)
#
# sys.platform -> Str
#   Operating system platform name
#
#   Possible values: "darwin" (macOS), "linux", "windows", "unknown"
#
#   Example:
#     if sys.platform == "darwin"
#         puts("Running on macOS")
#     end
#
# sys.executable -> Str
#   Path to the Quest executable
#
#   Example:
#     puts("Quest executable: " .. sys.executable)
#
# sys.argc -> Int
#   Number of command-line arguments
#
#   Example:
#     puts("Arguments: " .. sys.argc)
#
# sys.argv -> Array[Str]
#   Array of command-line arguments
#
#   Example:
#     for arg in sys.argv
#         puts("Arg: " .. arg)
#     end
#
# sys.script_path -> Str or nil
#   Absolute path to current script (nil in REPL)
#
#   Example:
#     if sys.script_path != nil
#         puts("Running from: " .. sys.script_path)
#     end
#
# sys.builtin_module_names -> Array[Str]
#   List of built-in module names
#
#   Example:
#     for mod in sys.builtin_module_names
#         puts(mod)
#     end
#
# === System Stream Singletons (QEP-010) ===
#
# sys.stdout -> SystemStream
#   Singleton object representing OS stdout stream
#
#   Methods:
#     write(data: Str) -> Int  - Write to stdout, returns bytes written
#     flush() -> Nil           - Flush output buffer
#
#   Example:
#     sys.stdout.write("Direct write\n")
#     sys.stdout.flush()
#
# sys.stderr -> SystemStream
#   Singleton object representing OS stderr stream
#
#   Methods:
#     write(data: Str) -> Int  - Write to stderr, returns bytes written
#     flush() -> Nil           - Flush output buffer
#
#   Example:
#     sys.stderr.write("Error message\n")
#
# sys.stdin -> SystemStream
#   Singleton object representing OS stdin stream
#
#   Methods:
#     read() -> Str       - Read all available input
#     readline() -> Str   - Read one line
#
#   Example:
#     let line = sys.stdin.readline()
#
# === System Functions ===
#
# sys.exit(code?) -> Never
#   Exit the program with optional exit code
#
#   Parameters:
#     code (Int, optional) - Exit code (default: 0)
#
#   Returns: Never (terminates program)
#
#   Example:
#     sys.exit(0)    # Success
#     sys.exit(1)    # Error
#
# sys.fail(message?) -> Never
#   Raise an error with optional message
#
#   Parameters:
#     message (Str, optional) - Error message (default: "Failure")
#
#   Returns: Never (raises exception)
#
#   Example:
#     sys.fail("Something went wrong")
#
# sys.load_module(path) -> Module
#   Dynamically load a Quest module at runtime
#
#   Parameters:
#     path (Str) - Module file path (absolute or relative)
#
#   Returns: Module object
#
#   Example:
#     let math = sys.load_module("std/math")
#     puts(math.pi)
#
# === I/O Redirection Functions (QEP-010) ===
#
# sys.redirect_stream(from, to) -> RedirectGuard
#   Redirect a stream to a target, returns guard for restoration
#
#   Parameters:
#     from - Source stream (sys.stdout or sys.stderr)
#     to   - Destination target:
#       Str         - File path (e.g., "output.log", "/dev/null")
#       StringIO    - In-memory buffer
#       sys.stdout  - Redirect to stdout (for restoration or stderr→stdout)
#       sys.stderr  - Redirect to stderr (for stdout→stderr)
#
#   Returns: RedirectGuard object
#
#   Examples:
#     # Redirect stdout to StringIO
#     let buf = io.StringIO.new()
#     let guard = sys.redirect_stream(sys.stdout, buf)
#     puts("Captured")
#     guard.restore()
#     puts(buf.get_value())  # "Captured\n"
#
#     # Redirect stderr to file
#     let guard = sys.redirect_stream(sys.stderr, "/tmp/errors.log")
#     sys.stderr.write("Error\n")
#     guard.restore()
#
#     # Suppress stdout
#     let guard = sys.redirect_stream(sys.stdout, "/dev/null")
#     noisy_function()
#     guard.restore()
#
#     # Redirect stderr to stdout (like shell 2>&1)
#     let buf = io.StringIO.new()
#     let g1 = sys.redirect_stream(sys.stdout, buf)
#     let g2 = sys.redirect_stream(sys.stderr, sys.stdout)
#     puts("Normal")
#     sys.stderr.write("Error\n")
#     g2.restore()
#     g1.restore()
#     # Both captured in buf
#
#     # Redirect stdout to stderr
#     let guard = sys.redirect_stream(sys.stdout, sys.stderr)
#     puts("This goes to stderr!")
#     guard.restore()
#
# === RedirectGuard Type ===
#
# Returned by sys.redirect_stdout() and sys.redirect_stderr()
# Manages safe restoration of redirected streams
#
# RedirectGuard Methods:
#
# restore() -> Nil
#   Restore stream to previous target (idempotent)
#
#   Can be called multiple times safely - subsequent calls are no-ops
#
#   Example:
#     let guard = sys.redirect_stdout(buffer)
#     puts("Output")
#     guard.restore()
#     guard.restore()  # Safe - no-op
#     guard.restore()  # Safe - no-op
#
# is_active() -> Bool
#   Check if guard is still active (not yet restored)
#
#   Returns: true if not restored, false after restore()
#
#   Example:
#     let guard = sys.redirect_stdout(buffer)
#     puts(guard.is_active())  # true
#     guard.restore()
#     puts(guard.is_active())  # false
#
# _enter() -> RedirectGuard
#   Context manager entry (for 'with' statement)
#   Returns self
#
# _exit() -> Nil
#   Context manager exit (for 'with' statement)
#   Automatically calls restore()
#
# === I/O Redirection Usage Patterns ===
#
# Pattern 1: Manual Restoration
#
#   let buffer = io.StringIO.new()
#   let guard = sys.redirect_stream(sys.stdout, buffer)
#   try
#       puts("Captured output")
#   ensure
#       guard.restore()  # Always restore
#   end
#   puts("Output was: " .. buffer.get_value())
#
# Pattern 2: Context Manager (Automatic)
#
#   let buffer = io.StringIO.new()
#   with sys.redirect_stream(sys.stdout, buffer)
#       puts("Auto-captured")
#   end  # Automatic restore via _exit()
#   puts("Output: " .. buffer.get_value())
#
# Pattern 3: Nested Redirections
#
#   let buf1 = io.StringIO.new()
#   let buf2 = io.StringIO.new()
#
#   with sys.redirect_stream(sys.stdout, buf1)
#       puts("Outer")
#       with sys.redirect_stream(sys.stdout, buf2)
#           puts("Inner")
#       end  # Back to buf1
#       puts("Outer again")
#   end  # Back to console
#
#   # buf1: "Outer\nOuter again\n"
#   # buf2: "Inner\n"
#
# Pattern 4: Suppress Output
#
#   let guard = sys.redirect_stream(sys.stdout, "/dev/null")
#   try
#       noisy_function()
#   ensure
#       guard.restore()
#   end
#
# Pattern 5: Log to File
#
#   let guard = sys.redirect_stream(sys.stdout, "app.log")
#   try
#       puts("Starting...")
#       process_data()
#       puts("Done!")
#   ensure
#       guard.restore()
#   end
#
# Pattern 6: Capture for Testing
#
#   test.it("generates correct output", fun ()
#       let buf = io.StringIO.new()
#       with sys.redirect_stream(sys.stdout, buf)
#           my_function()
#       end
#       test.assert(buf.get_value().contains("Expected"))
#   end)
#
# Pattern 7: Merge stderr to stdout (like shell 2>&1)
#
#   let buf = io.StringIO.new()
#   let guard_out = sys.redirect_stream(sys.stdout, buf)
#   let guard_err = sys.redirect_stream(sys.stderr, sys.stdout)
#
#   try
#       puts("Normal output")
#       sys.stderr.write("Error output\n")
#   ensure
#       guard_err.restore()
#       guard_out.restore()
#   end
#
#   # Both outputs captured in buf
#
# Pattern 8: Simultaneous Independent Streams
#
#   let out_buf = io.StringIO.new()
#   let err_buf = io.StringIO.new()
#
#   let guard_out = sys.redirect_stream(sys.stdout, out_buf)
#   let guard_err = sys.redirect_stream(sys.stderr, err_buf)
#
#   try
#       puts("Normal output")
#       sys.stderr.write("Error output\n")
#   ensure
#       guard_out.restore()
#       guard_err.restore()
#   end
#
# === Guard Behavior ===
#
# Idempotent Restoration:
#   Guards can be restored multiple times safely
#   After first restore(), subsequent calls are no-ops
#
#   let guard = sys.redirect_stream(sys.stdout, buf)
#   guard.restore()
#   guard.restore()  # No error
#
# Shared State:
#   Cloned guards share restoration state (via Rc<RefCell<>>)
#
#   let guard1 = sys.redirect_stream(sys.stdout, buf)
#   let guard2 = guard1  # Clone
#   guard1.restore()
#   puts(guard2.is_active())  # false (shared state)
#
# Exception Safety:
#   Always restore in ensure block to handle exceptions
#
#   let guard = sys.redirect_stream(sys.stdout, buf)
#   try
#       puts("Output")
#       raise "Error"
#   ensure
#       guard.restore()  # Still called!
#   end
#
# === Redirection Targets ===
#
# StringIO (In-Memory):
#   Fastest, best for testing
#   let buf = io.StringIO.new()
#   let guard = sys.redirect_stream(sys.stdout, buf)
#
# File Path (String):
#   Appends to file, creates if doesn't exist
#   let guard = sys.redirect_stream(sys.stdout, "output.log")
#
# /dev/null (Suppress):
#   Discards all output
#   let guard = sys.redirect_stream(sys.stdout, "/dev/null")
#
# sys.stdout/sys.stderr (Restore or Stream-to-Stream):
#   Restore to console: sys.redirect_stream(sys.stdout, sys.stdout)
#   Merge streams: sys.redirect_stream(sys.stderr, sys.stdout)  # 2>&1
#
# === Performance Notes ===
#
# Redirection Overhead:
#   - StringIO: Minimal (in-memory, very fast)
#   - File: Moderate (opens/appends/closes on each write)
#   - /dev/null: Minimal (kernel discards)
#   - Default: No overhead (direct print!)
#
# File Buffering:
#   File targets append on each write (not buffered)
#   For high-frequency output, consider capturing to StringIO first
#   then writing to file once
#
# === Security Considerations ===
#
# File Permissions:
#   Redirecting to file requires write permissions
#   Will fail with error if permissions denied
#
# Path Safety:
#   File paths are not sandboxed
#   Can write to any path with permissions
#   Validate user-provided paths before redirecting
#
# === Integration with Other Features ===
#
# Works with:
#   - puts() and print() - Both respect redirection
#   - sys.stdout.write() and sys.stderr.write() - Respect redirection
#   - StringIO (QEP-009) - In-memory buffers
#   - Context managers (QEP-011) - Automatic cleanup
#
# Does NOT redirect:
#   - Log handlers (std/log) - Independent streams
#   - Direct Rust print! macros - Only Quest puts()/print()
#
# === Error Handling ===
#
# Invalid target type:
#   try
#       sys.redirect_stdout(123)
#   catch e
#       puts("Error: " .. e.message())
#       # "target must be String, StringIO, or sys.stdout"
#   end
#
# File open failure:
#   try
#       let guard = sys.redirect_stdout("/invalid/path.txt")
#   catch e
#       puts("Error: " .. e.message())
#       # "Failed to open '/invalid/path.txt': ..."
#   end
#
# === Complete Examples ===
#
# Example 1: Test Output Verification
#
#   use "std/test"
#   use "std/sys"
#   use "std/io"
#
#   test.it("function produces correct output", fun ()
#       let buf = io.StringIO.new()
#
#       with sys.redirect_stream(sys.stdout, buf)
#           my_function()
#       end
#
#       let output = buf.get_value()
#       test.assert(output.contains("Expected"))
#   end)
#
# Example 2: Build System Output
#
#   use "std/sys"
#   use "std/io"
#
#   fun build_with_log(target)
#       let guard = sys.redirect_stream(sys.stdout, "build.log")
#       try
#           puts("Building " .. target .. "...")
#           # ... build steps ...
#           puts("Build complete!")
#       ensure
#           guard.restore()
#       end
#   end
#
# Example 3: Silent Execution
#
#   use "std/sys"
#
#   fun silent(func)
#       let guard_out = sys.redirect_stream(sys.stdout, "/dev/null")
#       let guard_err = sys.redirect_stream(sys.stderr, "/dev/null")
#
#       try
#           func()
#       ensure
#           guard_out.restore()
#           guard_err.restore()
#       end
#   end
#
#   silent(fun () puts("Suppressed") end)
#
# Example 4: Capture Function Output
#
#   use "std/sys"
#   use "std/io"
#
#   fun capture_output(func)
#       let buf = io.StringIO.new()
#
#       with sys.redirect_stream(sys.stdout, buf)
#           func()
#       end
#
#       buf.get_value()
#   end
#
#   let output = capture_output(fun ()
#       puts("Line 1")
#       puts("Line 2")
#   end)
#
#   puts("Captured:\n" .. output)
#
# Example 5: Merge stderr to stdout (Shell 2>&1 equivalent)
#
#   use "std/sys"
#   use "std/io"
#
#   let buf = io.StringIO.new()
#   let guard_out = sys.redirect_stream(sys.stdout, buf)
#   let guard_err = sys.redirect_stream(sys.stderr, sys.stdout)
#
#   try
#       puts("Normal output")
#       sys.stderr.write("Error output\n")
#   ensure
#       guard_err.restore()
#       guard_out.restore()
#   end
#
#   # Both stdout and stderr captured in buf
#   puts("Combined output:\n" .. buf.get_value())
#
# === See Also ===
#
# Related modules:
#   - std/io - File I/O and StringIO
#   - std/log - Logging framework
#
# Related QEPs:
#   - QEP-010: I/O Redirection specification
#   - QEP-009: StringIO specification
#   - QEP-011: Context managers (with statement)
