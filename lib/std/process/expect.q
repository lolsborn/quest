# std/process/expect - Interactive Program Automation (QEP-022)
# Pure Quest implementation wrapping std/process

use "std/process" as process
use "std/regex" as regex
use "std/time" as time

# Special sentinel values for pattern matching
# Note: These are constants that can be used in pattern arrays
const EOF = "__EXPECT_EOF__"
const TIMEOUT = "__EXPECT_TIMEOUT__"

# ExpectSession type for managing interactive sessions
pub type ExpectSession
    proc: process.Process   # The underlying process
    pub buffer: Str         # Accumulated output buffer
    pub before: Str         # Text before last match
    pub after: Str          # Text after last match (includes match)
    pub match_text: Str     # Last matched text
    default_timeout: Int    # Default timeout in seconds
    log_path: Str?          # Optional log file path
    log_append: Bool        # Append to log file

    fun expect(pattern, timeout)
        """Match a pattern in the output stream.

        Args:
            pattern: String (literal), regex, or array of [pattern, callback] pairs
            timeout: Timeout in seconds (nil = use default_timeout)

        Returns: Matched text, or result of callback if array pattern
        Raises: TimeoutError, EOFError
        """
        let actual_timeout = timeout ?: self.default_timeout
        let start = time.ticks_ms()

        while true
            # Check timeout
            if actual_timeout != nil
                let elapsed = (time.ticks_ms() - start) / 1000.0
                if elapsed > actual_timeout
                    let p = pattern.str()
                    let t = actual_timeout
                    let msg = "Timeout waiting for pattern '" .. p .. "' after " .. t.str() .. "s"
                    raise TimeoutError.new(
                        pattern: p,
                        timeout: t,
                        buffer: self.buffer,
                        message: msg
                    )
                end
            end

            # Read available data (non-blocking with small timeout)
            let chunk = self.proc.stdout.read_nonblocking(4096, 0.05)

            # Log if enabled
            if self.log_path != nil and chunk.len() > 0
                self._log_output(chunk)
            end

            # Check for EOF
            if chunk.len() == 0
                let exit_status = self.proc.poll()
                if exit_status != nil
                    # Process exited
                    let p = pattern.str()
                    let s = exit_status
                    let msg = "EOF while waiting for pattern '" .. p .. "' (exit status: " .. s.str() .. ")"
                    raise EOFError.new(
                        pattern: p,
                        exit_status: s,
                        buffer: self.buffer,
                        message: msg
                    )
                end
                # Still running, just no output yet - continue loop
                time.sleep(0.05)
                continue
            end

            self.buffer = self.buffer .. chunk

            # Try to match pattern
            if pattern.is("Array")
                # Array of [pattern, callback] pairs
                let match_result = self._try_match_array(pattern)
                if match_result != nil
                    return match_result
                end
            else
                # Single pattern (string or regex)
                let match_result = self._try_match_single(pattern)
                if match_result != nil
                    return match_result
                end
            end
        end
    end

    fun _try_match_single(pattern)
        """Try to match a single pattern against the buffer.

        Returns: Matched text if found, nil otherwise
        """
        if pattern.is("Str")
            # Literal string search - simple substring search
            let buf_len = self.buffer.len()
            let pat_len = pattern.len()

            if pat_len > buf_len
                return nil
            end

            # Iterate through buffer to find substring
            let i = 0
            while i <= buf_len - pat_len
                let matches = true
                let j = 0
                while j < pat_len
                    let buf_char = self.buffer.slice(i + j, i + j + 1)
                    let pat_char = pattern.slice(j, j + 1)
                    if not buf_char.eq(pat_char)
                        matches = false
                        break
                    end
                    j = j + 1
                end

                if matches
                    # Found a match
                    let match_start = i
                    let match_end = i + pat_len
                    self.before = self.buffer.slice(0, match_start)
                    self.match_text = pattern
                    self.after = self.buffer.slice(match_end)
                    self.buffer = self.after
                    return self.match_text
                end

                i = i + 1
            end
            nil
        else
            # Assume regex pattern
            let m = regex.find(pattern, self.buffer)
            if m != nil
                let match_start = m[0]
                let match_end = m[1]
                self.before = self.buffer.slice(0, match_start)
                self.match_text = self.buffer.slice(match_start, match_end)
                self.after = self.buffer.slice(match_end)
                self.buffer = self.after
                return self.match_text
            end
        end
        nil
    end

    fun _try_match_array(patterns)
        """Try to match multiple patterns, calling callback on first match.

        Args:
            patterns: Array of [pattern, callback] pairs

        Returns: Callback result if matched, nil otherwise
        """
        for pair in patterns
            let pattern = pair[0]
            let callback = pair[1]

            let matched = self._try_match_single(pattern)
            if matched != nil
                # Call the callback with match info
                if callback.is("Fun") or callback.is("UserFun")
                    return callback(matched)
                else
                    # Callback is an index (for expect returning which pattern matched)
                    return callback
                end
            end
        end
        nil
    end

    fun _log_output(text)
        """Log output to file if logging enabled."""
        if self.log_path != nil
            use "std/io" as io
            io.append(self.log_path, text)
        end
    end

    fun expect_exact(text, timeout)
        """Match exact text (no regex).

        Args:
            text: String to match
            timeout: Timeout in seconds (nil = use default)

        Returns: Matched text
        Raises: TimeoutError, EOFError
        """
        self.expect(text, timeout)
    end

    fun expect_eof(timeout)
        """Wait for process to exit.

        Args:
            timeout: Timeout in seconds (nil = use default)

        Returns: Exit status (int)
        Raises: TimeoutError
        """
        let actual_timeout = timeout ?: self.default_timeout
        let start = time.ticks_ms()

        while true
            # Check timeout
            if actual_timeout != nil
                let elapsed = (time.ticks_ms() - start) / 1000.0
                if elapsed > actual_timeout
                    let t = actual_timeout
                    let msg = "Timeout waiting for EOF after " .. t.str() .. "s"
                    raise TimeoutError.new(
                        pattern: "EOF",
                        timeout: t,
                        buffer: self.buffer,
                        message: msg
                    )
                end
            end

            let exit_status = self.proc.poll()
            if exit_status != nil
                return exit_status
            end

            time.sleep(0.1)
        end
    end

    fun send(text)
        """Send text without newline."""
        self.proc.stdin.write(text)
        if self.log_path != nil
            self._log_output(text)
        end
    end

    fun send_line(text)
        """Send text with newline."""
        self.send(text .. "\n")
    end

    fun send_control(char)
        """Send control character.

        Args:
            char: Control character ('c' for Ctrl-C, 'd' for Ctrl-D, etc.)
        """
        let lower = char.lower()
        let ctrl_byte = nil
        if lower.eq("c")
            ctrl_byte = b"\x03"  # Ctrl-C (ETX)
        elif lower.eq("d")
            ctrl_byte = b"\x04"  # Ctrl-D (EOT)
        elif lower.eq("z")
            ctrl_byte = b"\x1A" # Ctrl-Z (SUB)
        elif lower.eq("a")
            ctrl_byte = b"\x01"  # Ctrl-A
        elif lower.eq("b")
            ctrl_byte = b"\x02"  # Ctrl-B
        elif lower.eq("e")
            ctrl_byte = b"\x05"  # Ctrl-E
        elif lower.eq("u")
            ctrl_byte = b"\x15"  # Ctrl-U
        elif lower.eq("w")
            ctrl_byte = b"\x17"  # Ctrl-W
        else
            raise "Invalid control character: " .. char
        end

        self.proc.stdin.write(ctrl_byte)
    end

    fun read_nonblocking(size, timeout)
        """Read available data without blocking.

        Args:
            size: Maximum bytes to read (default 1024)
            timeout: Timeout in seconds (default 0 = immediate)

        Returns: String of available data (empty if nothing available)
        """
        let actual_size = size ?: 1024
        let actual_timeout = timeout ?: 0
        self.proc.stdout.read_nonblocking(actual_size, actual_timeout)
    end

    fun close(force)
        """Close the session and wait for process to exit.

        Args:
            force: If true, send SIGKILL; otherwise send SIGTERM

        Returns: Exit status (int) or nil if already closed
        """
        let actual_force = force ?: false
        if actual_force
            self.proc.send_signal("SIGKILL")
        else
            self.proc.send_signal("SIGTERM")
        end

        # Wait briefly for graceful exit
        try
            return self.expect_eof(2)
        catch e
            # If timeout, force kill
            if not actual_force
                self.proc.send_signal("SIGKILL")
                self.proc.wait()
            end
            nil
        end
    end

    fun is_alive()
        """Check if process is still running."""
        self.proc.poll() == nil
    end

    fun pid()
        """Get process ID."""
        self.proc.pid()
    end

    fun log_file(path, append)
        """Enable logging of all I/O to a file.

        Args:
            path: File path for log
            append: If true, append to existing file; otherwise overwrite
        """
        self.log_path = path
        let actual_append = append ?: false
        self.log_append = actual_append

        # Create/clear file if not appending
        if not actual_append
            use "std/io" as io
            io.write(path, "")
        end
    end
end

# Exception types
pub type TimeoutError
    pub pattern: Str
    pub timeout: Int
    pub buffer: Str
    pub message: Str  # Required for exception handling
end

pub type EOFError
    pub pattern: Str
    pub exit_status: Int?
    pub buffer: Str
    pub message: Str  # Required for exception handling
end

# Module functions
pub fun spawn(command, timeout, env, cwd)
    """Spawn a new interactive session.

    Args:
        command: Command to execute (string or array)
        timeout: Default timeout for expect operations (seconds, default 30)
        env: Environment variables (dict, optional)
        cwd: Working directory (string, optional)

    Returns: ExpectSession object
    """
    let actual_timeout = timeout ?: 30

    let opts = {}
    if env != nil
        opts["env"] = env
    end
    if cwd != nil
        opts["cwd"] = cwd
    end

    let proc = process.spawn(command, opts)

    ExpectSession.new(
        proc: proc,
        buffer: "",
        before: "",
        after: "",
        match_text: "",
        default_timeout: actual_timeout,
        log_path: nil,
        log_append: false
    )
end

pub fun run(command, events, timeout)
    """Run a simple automation with predefined event responses.

    Args:
        command: Command to execute
        events: Array of [pattern, response] string pairs
        timeout: Timeout for the entire operation (default 30)

    Returns: Full output (string)
    Raises: TimeoutError, EOFError
    """
    let actual_timeout = timeout ?: 30
    let session = spawn(command, actual_timeout)
    let full_output = ""

    # Convert events to expect array format
    let patterns = []
    for event in events
        let pattern = event[0]
        let response = event[1]
        patterns.push([pattern, fun ()
            session.send(response)
            nil
        end])
    end

    # Keep matching until EOF
    try
        while true
            session.expect(patterns, actual_timeout)
        end
    catch e
        # Expected - process completed (EOFError)
        full_output = session.buffer
    end

    full_output
end
