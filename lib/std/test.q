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
use "std/math" as math

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
let suite_start_time = 0  # Track total test suite time

# =============================================================================
# Configuration Functions
# =============================================================================

# set_colors(enabled) - Enable or disable colored output
fun set_colors(enabled)
    use_colors = enabled
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
# Test Organization Functions
# =============================================================================

# module(name) - Print module header (for test organization)
fun module(name)
    # Start timing on first module
    if suite_start_time == 0
        suite_start_time = ticks_ms()
    end

    puts("")
    puts(yellow(name))
end

# describe(name, fn) - Define a test suite/group
fun describe(name, test_fn)
    puts("\n" .. bold(cyan(name)))
    let old_suite = current_suite
    current_suite = name

    # Execute test suite function
    test_fn()

    current_suite = old_suite
end

# it(name, fn) - Define a single test case
fun it(name, test_fn)
    test_count = test_count + 1

    # Track test execution time
    let start_time = ticks_ms()

    # Execute test (would use try/catch when available)
    test_fn()

    # Calculate elapsed time
    let elapsed = ticks_ms() - start_time

    # If we reach here, test passed
    pass_count = pass_count + 1

    # Format and display result with timing
    let time_str = " " .. dimmed(format_time(elapsed))
    puts("  " .. green("✓") .. " " .. name .. time_str)
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
        if message == nil
            puts("  " .. red("✗") .. " Assertion failed")
        else
            puts("  " .. red("✗") .. " Assertion failed: " .. message)
        end
        # Would raise AssertionError here
    end
end

# assert_eq(actual, expected, message = nil) - Assert equality
fun assert_eq(actual, expected, message)
    if actual != expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected " .. expected._rep() .. " but got " .. actual._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_neq(actual, expected, message = nil) - Assert inequality
fun assert_neq(actual, expected, message)
    if actual == expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected value to not equal " .. expected._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_gt(actual, expected, message = nil) - Assert greater than
fun assert_gt(actual, expected, message)
    if actual <= expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected " .. actual._rep() .. " > " .. expected._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_lt(actual, expected, message = nil) - Assert less than
fun assert_lt(actual, expected, message)
    if actual >= expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected " .. actual._rep() .. " < " .. expected._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_gte(actual, expected, message = nil) - Assert greater than or equal
fun assert_gte(actual, expected, message)
    if actual < expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected " .. actual._rep() .. " >= " .. expected._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_lte(actual, expected, message = nil) - Assert less than or equal
fun assert_lte(actual, expected, message)
    if actual > expected
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected " .. actual._rep() .. " <= " .. expected._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_nil(value, message = nil) - Assert value is nil
fun assert_nil(value, message)
    if value != nil
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected nil but got " .. value._rep())
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_not_nil(value, message = nil) - Assert value is not nil
fun assert_not_nil(value, message)
    if value == nil
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected non-nil value")
        if message != nil
            puts("    " .. message)
        end
    end
end

# assert_type(value, type_name, message = nil) - Assert value has specific type
fun assert_type(value, type_name, message)
    let actual_type = value.cls()
    if actual_type != type_name
        fail_count = fail_count + 1
        puts("  " .. red("✗") .. " Expected type " .. type_name .. " but got " .. actual_type)
        if message != nil
            puts("    " .. message)
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
        puts("  " .. red("✗") .. " Expected " .. actual._rep() .. " within " .. tolerance._rep() .. " of " .. expected._rep())
        if message != nil
            puts("    " .. message)
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
        puts("  " .. red("✗") .. " Expected " .. expected_exc_type .. " to be raised but nothing was raised")
        if message != nil
            puts("    " .. message)
        end
    catch e
        # Check if the caught exception type matches expected
        if e.exc_type() != expected_exc_type
            fail_count = fail_count + 1
            puts("  " .. red("✗") .. " Expected " .. expected_exc_type .. " but got " .. e.exc_type() .. ": " .. e.message())
            if message != nil
                puts("    " .. message)
            end
        end
    end
end

# =============================================================================
# Test Control Functions
# =============================================================================

# skip(reason = nil) - Skip current test
fun skip(reason)
    skip_count = skip_count + 1
    if reason == nil
        puts("  " .. yellow("⊘") .. " Skipped")
    else
        puts("  " .. yellow("⊘") .. " Skipped: " .. reason)
    end
    # Would throw SkipException here
end

# skip_if(condition, reason = nil) - Skip test if condition is true
fun skip_if(condition, reason)
    if condition
        skip(reason)
    end
end

# fail(message) - Explicitly fail test
fun fail(message)
    fail_count = fail_count + 1
    puts("  " .. red("✗") .. " " .. message)
    # Would raise TestFailure here
end

# =============================================================================
# Test Runner Functions
# =============================================================================

# run() - Execute all tests and print summary
fun run()
    # Calculate total elapsed time
    let total_elapsed = ticks_ms() - suite_start_time

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
# Finds all .q files in root_dir recursively
# Filters out dotfiles (starting with .) and helper files (starting with _)
fun find_tests_dir(root_dir)
    use "std/io" as io

    # Find all .q files in root_dir
    let pattern = root_dir .. "/**/*.q"
    let all_files = io.glob(pattern)

    # Filter out files with filenames starting with "." or "_"
    let filtered = []
    let parts = []
    let filename = ""

    for file in all_files
        # Split path to get filename
        parts = file.split("/")
        filename = parts[parts.len() - 1]

        # Skip if filename starts with . or _
        if filename.startswith(".")
            # Skip dotfiles
        elif filename.startswith("_")
            # Skip helper files
        else
            # Include this file
            filtered = filtered.push(file)
        end
    end

    return filtered
end

# find_tests(paths) - Discover test files from array of paths
# Accepts array of file paths and/or directory paths
# For directories: finds all .q files recursively (excluding . and _ prefixed)
# For files: includes them directly if they end with .q
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
            # File: check if it's a .q file and not a helper/dotfile
            parts = path.split("/")
            filename = parts[parts.len() - 1]

            # Only include .q files that don't start with . or _
            if path.endswith(".q") and not filename.startswith(".") and not filename.startswith("_")
                all_tests = all_tests.push(path)
            end
        # If path doesn't exist, skip it silently
        end
    end

    return all_tests
end
