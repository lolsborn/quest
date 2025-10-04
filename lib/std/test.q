# =============================================================================
# Example Usage
# =============================================================================
# use "std/test"
# let it = test.it, describe = test.describe, assert_eq = test.assert_eq, run = test.run
#
# describe("Calculator", fun ()
#     it("adds numbers", fun ()
#         assert_eq(2 + 2, 4)
#     end)
#
#     it("subtracts numbers", fun ()
#         assert_eq(5 - 3, 2)
#     end)
#
#     it("multiplies numbers", fun ()
#         assert_eq(3 * 4, 12)
#     end)
# end)
#
# describe("String operations", fun ()
#     it("concatenates strings", fun ()
#         assert_eq("hello" + " world", "hello world")
#     end)
#
#     it("gets string length", fun ()
#         assert_eq("hello".len(), 5)
#     end)
# end)
#
# run()

# Test Module for Quest
# Provides testing framework with assertions and test organization

# Import term module for terminal colors and formatting
use "std/term"
use "std/math"
use "std/time"

# Test state (module-level variables)
let test_suites = []
let current_suite = nil
let current_suite_tests = []
let test_count = 0
let pass_count = 0
let fail_count = 0
let skip_count = 0
let failed_tests = []
let use_colors = true  # Can be disabled with set_colors(false)
let condensed_output = false  # Can be enabled with set_condensed(true)
let suite_start_time = 0  # Track total test suite time

# Tag filtering
let filter_tags = []  # Only run tests with these tags (empty = run all)
let skip_tags = []    # Skip tests with these tags
let current_describe_tags = []  # Tags from current describe block
let next_test_tags = []  # Tags for the next describe() or it() call

# Condensed mode tracking
let current_module_name = nil
let current_describe_name = nil
let module_test_count = 0
let module_pass_count = 0
let module_fail_count = 0
let describe_test_count = 0
let describe_pass_count = 0
let describe_fail_count = 0
let describe_failures = []  # Track failures in current describe block
let module_describe_buffer = []  # Buffer describe blocks to print after module header

# =============================================================================
# Configuration Functions
# =============================================================================

# set_colors(enabled) - Enable or disable colored output
fun set_colors(enabled)
    use_colors = enabled
end

# set_condensed(enabled) - Enable or disable condensed output
fun set_condensed(enabled)
    condensed_output = enabled
end

# set_filter_tags(tags) - Only run tests with these tags
fun set_filter_tags(tags)
    filter_tags = tags
end

# set_skip_tags(tags) - Skip tests with these tags
fun set_skip_tags(tags)
    skip_tags = tags
end

# tag(tags) - Set tags for the next describe() or it() call
# Accepts either a string or array of strings
fun tag(tags)
    # Normalize to array if string
    if tags.cls() == "Str"
        tags = [tags]
    end
    next_test_tags = tags
end

# Helper functions for conditional coloring
fun green(text)
    if use_colors
        return term.green(text)
    else
        return text
    end
end

fun red(text)
    if use_colors
        return term.red(text)
    else
        return text
    end
end

fun yellow(text)
    if use_colors
        return term.yellow(text)
    else
        return text
    end
end

fun cyan(text)
    if use_colors
        return term.cyan(text)
    else
        return text
    end
end

fun bold(text)
    if use_colors
        return term.bold(text)
    else
        return text
    end
end

fun dimmed(text)
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
fun format_time(ms)
    if ms < 1000
        # Show milliseconds as integer
        return math.round(ms, 0)._str() .. "ms"
    elif ms < 60000
        # Show seconds as integer
        return math.round(ms / 1000, 0)._str() .. "s"
    elif ms < 3600000
        # Show minutes as integer
        return math.round(ms / 60000, 0)._str() .. "m"
    else
        # Show hours as integer
        return math.round(ms / 3600000, 0)._str() .. "h"
    end
end

# =============================================================================
# Condensed Output Functions
# =============================================================================

# Print summary for current describe block (condensed mode)
fun print_describe_summary()
    if describe_test_count == 0
        return
    end

    # Only buffer describe blocks that have failures in condensed mode
    if describe_fail_count > 0
        let status_marker = red("✗")
        let counts = red(describe_pass_count._str() .. "/" .. describe_test_count._str())

        # Buffer describe header
        let describe_output = ["    " .. status_marker .. " " .. current_describe_name .. " [" .. counts .. "]"]

        # Buffer failures
        describe_failures.each(fun (failure)
            describe_output = describe_output.push("      " .. red("✗") .. " " .. failure)
        end)

        # Add to module buffer
        module_describe_buffer = module_describe_buffer.concat(describe_output)
    end
end

# Print summary for current module (condensed mode)
fun print_module_summary()
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
        counts = red(module_pass_count._str() .. "/" .. module_test_count._str())
    else
        counts = green(module_test_count._str() .. "/" .. module_test_count._str())
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
fun module(name)
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
    module_describe_buffer = []

    if not condensed_output
        puts("")
        puts(yellow(name))
    end
end

# describe(name, fn) - Define a test suite/group
fun describe(name, test_fn)
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
    describe_failures = []

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
fun it(name, test_fn)
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
        if not condensed_output
            let tag_display = ""
            if merged_tags.len() > 0
                tag_display = " " .. dimmed("[" .. merged_tags.join(", ") .. "]")
            end
            puts("  " .. yellow("⊘") .. " " .. name .. tag_display .. " " .. dimmed("(" .. skip_reason .. ")"))
        end
    else
        # Track test execution time
        let start_time = time.ticks_ms()

        # Track fail counts before test runs
        let fail_count_before = fail_count

        # Execute test (would use try/catch when available)
        test_fn()

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
        end
    end
end

# before(fn) - Run setup before each test
fun before(setup_fn)
    # Store setup function for current suite
    # Would be called before each it() in the suite
end

# after(fn) - Run teardown after each test
fun after(teardown_fn)
    # Store teardown function for current suite
    # Would be called after each it() in the suite
end

# before_all(fn) - Run setup once before all tests in suite
fun before_all(setup_fn)
    # Execute immediately or store for suite
    setup_fn()
end

# after_all(fn) - Run teardown once after all tests in suite
fun after_all(teardown_fn)
    # Store to execute after suite completes
end

# =============================================================================
# Assertion Functions
# =============================================================================

# assert(condition, message = nil) - Assert condition is true
fun assert(condition, message)
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
fun assert_eq(actual, expected, message)
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
fun assert_neq(actual, expected, message)
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
fun assert_gt(actual, expected, message)
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
fun assert_lt(actual, expected, message)
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
fun assert_gte(actual, expected, message)
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
fun assert_lte(actual, expected, message)
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
fun assert_nil(value, message)
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
fun assert_not_nil(value, message)
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
fun assert_type(value, type_name, message)
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
fun assert_near(actual, expected, tolerance, message)
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

# assert_raises(exception_type, fn, message = nil) - Assert function raises specific exception
fun assert_raises(expected_exc_type, test_fn, message)
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
        # Check if the caught exception type matches expected
        if e.exc_type() != expected_exc_type
            fail_count = fail_count + 1
            describe_fail_count = describe_fail_count + 1
            module_fail_count = module_fail_count + 1

            let failure_msg = "Expected " .. expected_exc_type .. " but got " .. e.exc_type() .. ": " .. e.message()
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

# skip(reason = nil) - Skip current test
fun skip(name, test_fn)
    skip_count = skip_count + 1
    puts("  " .. yellow("⊘") .. " Skipped")
    # Would throw SkipException here
end

# fail(message) - Explicitly fail test
fun fail(message)
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
fun stats()
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
    let status_line = "Total:   " .. test_count._str()

    if pass_count > 0
        status_line = status_line .. "  |  " .. green("Passed:  " .. pass_count._str())
    end

    if fail_count > 0
        status_line = status_line .. "  |  " .. red("Failed:  " .. fail_count._str())
    end

    if skip_count > 0
        status_line = status_line .. "  |  " .. yellow("Skipped: " .. skip_count._str())
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
fun find_tests_dir(root_dir)
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
            filtered = filtered.push(file)
        # Include files ending with "_test.q"
        elif filename.endswith("_test.q")
            filtered = filtered.push(file)
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
fun find_tests(paths)
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
                    all_tests = all_tests.push(path)
                end
            end
        # If path doesn't exist, skip it silently
        end
    end

    return all_tests
end