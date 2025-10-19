"""
## Example Usage

```quest
use "std/test" as test {it, describe, assert_eq, run}

describe("Calculator", fun ()
    it("adds numbers", fun ()
        assert_eq(2 + 2, 4)
    end)

    it("subtracts numbers", fun ()
        assert_eq(5 - 3, 2)
    end)

    it("multiplies numbers", fun ()
        assert_eq(3 * 4, 12)
    end)
end)

describe("String operations", fun ()
    it("concatenates strings", fun ()
        assert_eq("hello" + " world", "hello world")
    end)

    it("gets string length", fun ()
        assert_eq("hello".len(), 5)
    end)
end)

run()
```
"""

# Test Module for Quest
# Provides testing framework with assertions and test organization

# Import term module for terminal colors and formatting
use "std/term"
use "std/math"
use "std/time"
use "std/sys"
use "std/io"
use "std/conf" as conf

# =============================================================================
# Configuration Schema (QEP-053 compliant)
# =============================================================================

pub type Configuration
    pub colors: Bool?
    pub condensed: Bool?
    pub capture: Str?
    pub paths: Array?
    pub tags: Array?
    pub skip_tags: Array?

    fun self.from_dict(dict)
        let cfg_tags = dict["tags"] or []
        let cfg_skip_tags = dict["skip_tags"] or []
        let config = Configuration.new(
            colors: dict["colors"] or true,
            condensed: dict["condensed"] or false,
            capture: dict["capture"] or "all",
            paths: dict["paths"] or ["test/"],
            tags: cfg_tags,
            skip_tags: cfg_skip_tags
        )
        return config
    end
end

# Register schema and load configuration (QEP-053)
conf.register_schema("std.test", Configuration)
pub let config = conf.get_config("std.test")

# Test state (module-level variables)
let test_suites = []
let current_suite = nil
let current_suite_tests = []
let test_count = 0
let pass_count = 0
let fail_count = 0
let skip_count = 0
let failed_tests = []
let use_colors = config.colors  # Loaded from quest.toml
let condensed_output = config.condensed  # Loaded from quest.toml
let suite_start_time = 0  # Track total test suite time
let capture_output = config.capture  # Loaded from quest.toml

# Tag filtering (loaded from quest.toml)
let filter_tags = config.tags  # Only run tests with these tags (empty = run all)
let skip_tags = config.skip_tags  # Skip tests with these tags
let current_describe_tags = []  # Tags from current describe block
let next_test_tags = []  # Tags for the next describe() or it() call

# Condensed mode tracking
let current_module_name = nil
let current_describe_name = nil
let module_test_count = 0
let module_pass_count = 0
let module_fail_count = 0
let module_skip_count = 0
let describe_test_count = 0
let describe_pass_count = 0
let describe_fail_count = 0
let describe_skip_count = 0
let describe_failures = []  # Track failures in current describe block
let describe_skips = []  # Track skipped tests in current describe block
let module_describe_buffer = []  # Buffer describe blocks to print after module header

# =============================================================================
# Configuration Functions
# =============================================================================

# set_colors(enabled) - Enable or disable colored output
pub fun set_colors(enabled)
    use_colors = enabled
end

# set_condensed(enabled) - Enable or disable condensed output
pub fun set_condensed(enabled)
    condensed_output = enabled
end

# set_capture(mode) - Set output capture mode
# Modes: all, no, 0, 1, stdout, stderr
pub fun set_capture(mode)
    capture_output = mode
end

# set_filter_tags(tags) - Only run tests with these tags
pub fun set_filter_tags(tags)
    filter_tags = tags
end

# set_skip_tags(tags) - Skip tests with these tags
pub fun set_skip_tags(tags)
    skip_tags = tags
end

# tag(tags) - Set tags for the next describe() or it() call
# Accepts either a string or array of strings
pub fun tag(tags)
    # Normalize to array if string
    if tags.cls() == "Str"
        tags = [tags]
    end
    next_test_tags = tags
end

# Helper functions for conditional coloring
pub fun green(text)
    if use_colors
        return term.green(text)
    else
        return text
    end
end

pub fun red(text)
    if use_colors
        return term.red(text)
    else
        return text
    end
end

pub fun yellow(text)
    if use_colors
        return term.yellow(text)
    else
        return text
    end
end

pub fun cyan(text)
    if use_colors
        return term.cyan(text)
    else
        return text
    end
end

pub fun bold(text)
    if use_colors
        return term.bold(text)
    else
        return text
    end
end

pub fun dimmed(text)
    if use_colors
        return term.dimmed(text)
    else
        return text
    end
end

# =============================================================================
# Time Formatting
# =============================================================================

# Format elapsed time with appropriate units
pub fun format_time(ms)
    if ms < 1000
        # Show milliseconds as integer
        return math.round(ms, 0).str() .. "ms"
    elif ms < 60000
        # Show seconds as integer
        return math.round(ms / 1000, 0).str() .. "s"
    elif ms < 3600000
        # Show minutes as integer
        return math.round(ms / 60000, 0).str() .. "m"
    else
        # Show hours as integer
        return math.round(ms / 3600000, 0).str() .. "h"
    end
end

# =============================================================================
# Condensed Output Functions
# =============================================================================

# Print summary for current describe block (condensed mode)
pub fun print_describe_summary()
    if describe_test_count == 0
        return
    end

    # Buffer describe blocks that have failures or skips in condensed mode
    if describe_fail_count > 0 or describe_skip_count > 0
        let status_marker = nil
        if describe_fail_count > 0
            status_marker = red("✗")
        else
            status_marker = green("✓")
        end

        let counts = nil
        if describe_fail_count > 0
            counts = red(describe_pass_count.str() .. "/" .. describe_test_count.str())
        else
            counts = green(describe_pass_count.str() .. "/" .. describe_test_count.str())
        end

        # Buffer describe header
        let describe_output = ["    " .. status_marker .. " " .. current_describe_name .. " [" .. counts .. "]"]

        # Buffer failures
        describe_failures.each(fun (failure)
            describe_output.push("      " .. red("✗") .. " " .. failure)
        end)

        # Buffer skips
        describe_skips.each(fun (skip_msg)
            describe_output.push("      " .. yellow("⊘") .. " " .. skip_msg)
        end)

        # Add to module buffer
        module_describe_buffer = module_describe_buffer.concat(describe_output)
    end
end

# Print summary for current module (condensed mode)
pub fun print_module_summary()
    if module_test_count == 0
        return
    end

    let status_marker = nil
    if module_fail_count == 0
        status_marker = green("✓")
    else
        status_marker = red("✗")
    end

    let counts = nil
    if module_fail_count > 0
        counts = red(module_pass_count.str() .. "/" .. module_test_count.str())
    else
        counts = green(module_pass_count.str() .. "/" .. module_test_count.str())
    end

    # Print module header
    puts(status_marker .. " [" .. counts .. "] " .. current_module_name)

    # Print all buffered describe blocks
    module_describe_buffer.each(fun (line)
        puts(line)
    end)

    # Clear buffer for next module
    module_describe_buffer = []
end

# =============================================================================
# Test Organization Functions
# =============================================================================

# module(name) - Print module header (for test organization)
pub fun module(name)
    # Start timing on first module
    if suite_start_time == 0
        suite_start_time = time.ticks_ms()
    end

    # Print previous module summary if in condensed mode
    if condensed_output and current_module_name != nil
        print_module_summary()
    end

    # Reset module counters and state
    current_module_name = name
    module_test_count = 0
    module_pass_count = 0
    module_fail_count = 0
    module_skip_count = 0
    module_describe_buffer = []

    if not condensed_output
        puts("")
        puts(yellow(name))
    end
end

# describe(name, fn) - Define a test suite/group
pub fun describe(name, test_fn)
    # Consume next_test_tags and store as describe tags
    let tags = next_test_tags
    next_test_tags = []  # Reset for next call

    # Store previous describe tags and set new ones
    let old_describe_tags = current_describe_tags
    current_describe_tags = tags

    # Reset describe counters
    current_describe_name = name
    describe_test_count = 0
    describe_pass_count = 0
    describe_fail_count = 0
    describe_skip_count = 0
    describe_failures = []
    describe_skips = []

    if not condensed_output
        puts("\n" .. bold(cyan(name)))
    end

    let old_suite = current_suite
    current_suite = name

    # Execute test suite function
    test_fn()

    # Print describe summary if in condensed mode
    # (Module header will be printed by print_describe_summary if needed)
    if condensed_output
        print_describe_summary()
    end

    current_suite = old_suite

    # Restore previous describe tags
    current_describe_tags = old_describe_tags
end

# it(name, fn) - Define a single test case
pub fun it(name, test_fn)
    # Consume next_test_tags and merge with describe tags
    let tags = next_test_tags
    next_test_tags = []  # Reset for next call
    let merged_tags = current_describe_tags.concat(tags)

    # Check if test should be skipped based on tags
    let should_skip = false
    let skip_reason = ""

    # Check skip_tags - if test has any of these tags, skip it
    if skip_tags.len() > 0
        for skip_tag in skip_tags
            for test_tag in merged_tags
                if test_tag == skip_tag
                    should_skip = true
                    skip_reason = "tag '" .. skip_tag .. "'"
                end
            end
        end
    end

    # Check filter_tags - if specified, only run tests with these tags
    if not should_skip and filter_tags.len() > 0
        let has_matching_tag = false
        for filter_tag in filter_tags
            for test_tag in merged_tags
                if test_tag == filter_tag
                    has_matching_tag = true
                end
            end
        end
        if not has_matching_tag
            should_skip = true
            skip_reason = "missing required tag"
        end
    end

    test_count = test_count + 1
    describe_test_count = describe_test_count + 1
    module_test_count = module_test_count + 1

    # Skip test if filtered out
    if should_skip
        skip_count = skip_count + 1
        describe_skip_count = describe_skip_count + 1
        module_skip_count = module_skip_count + 1

        if not condensed_output
            let tag_display = ""
            if merged_tags.len() > 0
                tag_display = " " .. dimmed("[" .. merged_tags.join(", ") .. "]")
            end
            puts("  " .. yellow("⊘") .. " " .. name .. tag_display .. " " .. dimmed("(" .. skip_reason .. ")"))
        else
            # In condensed mode, track for later display
            let skip_display = "Skipped - " .. name
            if skip_reason != ""
                skip_display = skip_display .. " (" .. skip_reason .. ")"
            end
            describe_skips = describe_skips.concat([skip_display])
        end
    else
        # Track test execution time
        let start_time = time.ticks_ms()

        # Track fail counts before test runs
        let fail_count_before = fail_count

        # Setup output capture if enabled
        let stdout_buffer = nil
        let stderr_buffer = nil
        let stdout_guard = nil
        let stderr_guard = nil

        if capture_output != "no" and capture_output != "0"
            # Capture stdout unless mode is "stderr" only
            if capture_output != "stderr"
                stdout_buffer = io.StringIO.new()
                stdout_guard = sys.redirect_stream(sys.stdout, stdout_buffer)
            end

            # Capture stderr unless mode is "stdout" only
            if capture_output != "stdout"
                stderr_buffer = io.StringIO.new()
                stderr_guard = sys.redirect_stream(sys.stderr, stderr_buffer)
            end
        end

        # Execute test with exception handling
        let test_error = nil
        try
            test_fn()
        catch e
            test_error = e
        end

        # Restore stdout/stderr and get captured content
        let captured_stdout = ""
        let captured_stderr = ""

        if stdout_guard != nil
            stdout_guard.restore()
            captured_stdout = stdout_buffer.get_value()
        end

        if stderr_guard != nil
            stderr_guard.restore()
            captured_stderr = stderr_buffer.get_value()
        end

        # Now handle the test error if one occurred
        if test_error != nil
            let e = test_error
            # Unexpected exception during test execution
            fail_count = fail_count + 1
            describe_fail_count = describe_fail_count + 1
            module_fail_count = module_fail_count + 1

            # Format error message with context
            let error_msg = "Unexpected " .. e.type() .. ": " .. e.message()

            # Show context immediately (not buffered)
            if condensed_output
                # Print module header if not yet printed
                if module_test_count == 1
                    puts("\n" .. red("✗") .. " " .. current_module_name)
                end
                # Print describe header if not yet shown
                if describe_test_count == 1
                    puts("  " .. red("✗") .. " " .. current_describe_name)
                end
            end

            # Print test failure with full context
            puts("  " .. red("✗") .. " " .. name)
            puts("    " .. red(error_msg))

            # Print captured output if any
            if captured_stdout != ""
                puts("    " .. dimmed("Captured stdout:"))
                let lines = captured_stdout.split("\n")
                for line in lines
                    if line != ""
                        puts("      " .. dimmed(line))
                    end
                end
            end

            if captured_stderr != ""
                puts("    " .. dimmed("Captured stderr:"))
                let lines = captured_stderr.split("\n")
                for line in lines
                    if line != ""
                        puts("      " .. dimmed(line))
                    end
                end
            end

            # Print stack trace if available
            let stack = e.stack()
            if stack != nil and stack.len() > 0
                puts("    Stack trace:")
                stack.each(fun (frame)
                    puts("      " .. dimmed(frame))
                end)
            end

            # Add to describe failures for summary
            if condensed_output
                describe_failures = describe_failures.concat([name .. ": " .. error_msg])
            end
        end

        # Calculate elapsed time
        let elapsed = time.ticks_ms() - start_time

        # Only increment pass counters if no failures occurred during this test
        if fail_count == fail_count_before
            pass_count = pass_count + 1
            describe_pass_count = describe_pass_count + 1
            module_pass_count = module_pass_count + 1

            # Format and display result with timing
            if not condensed_output
                let tag_display = ""
                if merged_tags.len() > 0
                    tag_display = " " .. dimmed("[" .. merged_tags.join(", ") .. "]")
                end
                let time_str = " " .. dimmed(format_time(elapsed))
                puts("  " .. green("✓") .. " " .. name .. tag_display .. time_str)
            end
        else
            # Test failed via assertion (not exception)
            # Display captured output if any
            if captured_stdout != ""
                puts("    " .. dimmed("Captured stdout:"))
                let lines = captured_stdout.split("\n")
                for line in lines
                    if line != ""
                        puts("      " .. dimmed(line))
                    end
                end
            end

            if captured_stderr != ""
                puts("    " .. dimmed("Captured stderr:"))
                let lines = captured_stderr.split("\n")
                for line in lines
                    if line != ""
                        puts("      " .. dimmed(line))
                    end
                end
            end
        end
    end
end

# before(fn) - Run setup before each test
pub fun before(setup_fn)
    # Store setup function for current suite
    # Would be called before each it() in the suite
end

# after(fn) - Run teardown after each test
pub fun after(teardown_fn)
    # Store teardown function for current suite
    # Would be called after each it() in the suite
end

# before_all(fn) - Run setup once before all tests in suite
pub fun before_all(setup_fn)
    # Execute immediately or store for suite
    setup_fn()
end

# after_all(fn) - Run teardown once after all tests in suite
pub fun after_all(teardown_fn)
    # Store to execute after suite completes
end

# =============================================================================
# Assertion Functions
# =============================================================================

# assert(condition, message = nil) - Assert condition is true
pub fun assert(condition, message = nil)
    if not condition
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = nil
        if message == nil
            failure_msg = "Assertion failed"
        else
            failure_msg = "Assertion failed: " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
        # Would raise AssertionError here
    end
end

# assert_eq(actual, expected, message = nil) - Assert equality
pub fun assert_eq(actual, expected, message = nil)
    if actual != expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. expected._rep() .. " but got " .. actual._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_neq(actual, expected, message = nil) - Assert inequality
pub fun assert_neq(actual, expected, message = nil)
    if actual == expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected value to not equal " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_gt(actual, expected, message = nil) - Assert greater than
pub fun assert_gt(actual, expected, message = nil)
    if actual <= expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. actual._rep() .. " > " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_lt(actual, expected, message = nil) - Assert less than
pub fun assert_lt(actual, expected, message = nil)
    if actual >= expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. actual._rep() .. " < " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_gte(actual, expected, message = nil) - Assert greater than or equal
pub fun assert_gte(actual, expected, message = nil)
    if actual < expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. actual._rep() .. " >= " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_lte(actual, expected, message = nil) - Assert less than or equal
pub fun assert_lte(actual, expected, message = nil)
    if actual > expected
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. actual._rep() .. " <= " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_nil(value, message = nil) - Assert value is nil
pub fun assert_nil(value, message = nil)
    if value != nil
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected nil but got " .. value._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_not_nil(value, message = nil) - Assert value is not nil
pub fun assert_not_nil(value, message = nil)
    if value == nil
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected non-nil value"
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_type(value, type_name, message = nil) - Assert value has specific type
pub fun assert_type(value, type_name, message = nil)
    let actual_type = value.cls()
    if actual_type != type_name
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected type " .. type_name .. " but got " .. actual_type
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_near(actual, expected, tolerance, message = nil) - Assert approximate equality
pub fun assert_near(actual, expected, tolerance, message = nil)
    let diff = actual - expected
    if diff < 0
        diff = 0 - diff
    end

    if diff > tolerance
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. actual._rep() .. " within " .. tolerance._rep() .. " of " .. expected._rep()
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    end
end

# assert_raises(exception_type, fn, message = nil) -Assert function raises specific exception
pub fun assert_raises(expected_exc_type, test_fn, message = nil)
    # Try to execute the function and catch any raised exceptions
    # Returns true if expected exception was raised, false otherwise

    # Note: We need to use a different approach since we can't declare variables
    # inside catch blocks due to parsing limitations. Instead, we check after.

    try
        test_fn()
        # If we reach here, no exception was raised
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. expected_exc_type .. " to be raised but nothing was raised"
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    catch e
        # Check if the caught exception type matches expected (QEP-037)

        let actual_type = e.type()
        # Special case: "Err" is the base exception type - matches all exceptions
        # Otherwise, check for exact match
        let matches = (expected_exc_type == Err) or (actual_type == expected_exc_type)

        if not matches
            fail_count = fail_count + 1
            describe_fail_count = describe_fail_count + 1
            module_fail_count = module_fail_count + 1

            let failure_msg = "Expected " .. expected_exc_type .. " but got " .. actual_type .. ": " .. e.message()
            if message != nil
                failure_msg = failure_msg .. ": " .. message
            end

            if condensed_output
                describe_failures = describe_failures.concat([failure_msg])
            else
                puts("  " .. red("✗") .. " " .. failure_msg)
            end
        end
    end
end

# =============================================================================
# Test Control Functions
# =============================================================================

# skip(name, reason?) - Define a skipped test
# Like test.it() but marks test as skipped instead of running it
pub fun skip(name, reason = nil)
    # Consume next_test_tags and merge with describe tags
    let tags = next_test_tags
    next_test_tags = []  # Reset for next call
    let merged_tags = current_describe_tags.concat(tags)

    test_count = test_count + 1
    describe_test_count = describe_test_count + 1
    module_test_count = module_test_count + 1

    skip_count = skip_count + 1
    describe_skip_count = describe_skip_count + 1
    module_skip_count = module_skip_count + 1

    let skip_reason = ""
    if reason != nil
        skip_reason = reason
    end

    if not condensed_output
        let tag_display = ""
        if merged_tags.len() > 0
            tag_display = " " .. dimmed("[" .. merged_tags.join(", ") .. "]")
        end

        let reason_display = ""
        if skip_reason != ""
            reason_display = " " .. dimmed("(" .. skip_reason .. ")")
        end

        puts("  " .. yellow("⊘") .. " " .. name .. tag_display .. reason_display)
    else
        # In condensed mode, track for later display
        let skip_display = "Skipped - " .. name
        if skip_reason != ""
            skip_display = skip_display .. " (" .. skip_reason .. ")"
        end
        describe_skips = describe_skips.concat([skip_display])
    end
end

# fail(message) - Explicitly fail test
pub fun fail(message)
    fail_count = fail_count + 1
    describe_fail_count = describe_fail_count + 1
    module_fail_count = module_fail_count + 1

    if condensed_output
        describe_failures = describe_failures.concat([message])
    else
        puts("  " .. red("✗") .. " " .. message)
    end
    # Would raise TestFailure here
end

# =============================================================================
# Test Runner Functions
# =============================================================================

# stats() - Print summary of test results and return exit code
pub fun stats()
    # Print final module summary if in condensed mode
    if condensed_output and current_module_name != nil
        print_module_summary()
    end

    # Calculate total elapsed time
    let total_elapsed = time.ticks_ms() - suite_start_time

    # Build result header with status
    let header = "\n" .. bold("Test Results:")
    if fail_count == 0
        header = header .. " " .. bold(green("✓ All tests passed!"))
    else
        header = header .. " " .. bold(red("✗ Some tests failed"))
    end
    puts(header)

    puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    # Build status line with conditional sections
    let status_line = "Total:   " .. test_count.str()

    if pass_count > 0
        status_line = status_line .. "  |  " .. green("Passed:  " .. pass_count.str())
    end

    if fail_count > 0
        status_line = status_line .. "  |  " .. red("Failed:  " .. fail_count.str())
    end

    if skip_count > 0
        status_line = status_line .. "  |  " .. yellow("Skipped: " .. skip_count.str())
    end

    # Add elapsed time
    status_line = status_line .. "  |  Elapsed: " .. dimmed(format_time(total_elapsed))

    puts(status_line)

    if fail_count > 255
        return 255
    elseif fail_count > 0
        return fail_count
    else
        return 0
    end
end

# find_tests_dir(root_dir) - Discover test files in a single directory
# Finds .q files matching test naming conventions:
#   - Files starting with "test_" (e.g., test_example.q)
#   - Files ending with "_test.q" (e.g., example_test.q)
# Filters out dotfiles (starting with .) and helper files (starting with _)
pub fun find_tests_dir(root_dir)
    use "std/io" as io

    # Find all .q files in root_dir
    let pattern = root_dir .. "/**/*.q"
    let all_files = io.glob(pattern)

    # Filter to only include test files (starting with test_ or ending with _test.q)
    let filtered = []
    let parts = []
    let filename = ""

    for file in all_files
        # Split path to get filename
        parts = file.split("/")
        filename = parts[parts.len() - 1]

        # Skip dotfiles
        if filename.startswith(".")
            # Skip dotfiles
        # Include files starting with "test_"
        elif filename.startswith("test_")
            filtered.push(file)
        # Include files ending with "_test.q"
        elif filename.endswith("_test.q")
            filtered.push(file)
        # Skip all other files
        end
    end

    return filtered
end

# find_tests(paths) - Discover test files from array of paths
# Accepts array of file paths and/or directory paths
# For directories: finds test files recursively (test_*.q or *_test.q)
# For files: includes them if they match test naming conventions
# Returns combined list of all discovered test files
pub fun find_tests(paths)
    use "std/io" as io

    let all_tests = []
    let parts = []
    let filename = ""

    for path in paths
        # Check if path is a directory or file
        if io.is_dir(path)
            # Directory: find all tests recursively
            let dir_tests = find_tests_dir(path)
            all_tests = all_tests.concat(dir_tests)
        elif io.is_file(path)
            # File: check if it matches test naming conventions
            parts = path.split("/")
            filename = parts[parts.len() - 1]

            # Only include test files: starting with test_ or ending with _test.q
            # Skip dotfiles
            if not filename.startswith(".")
                if filename.startswith("test_") or filename.endswith("_test.q")
                    all_tests.push(path)
                end
            end
        # If path doesn't exist, skip it silently
        end
    end

    return all_tests
end