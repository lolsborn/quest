# Test Module for Quest
# Provides testing framework with assertions and test organization
#
# NOTE: This is a reference implementation showing the intended API.
# Function declarations are in the grammar but not yet implemented in the evaluator.
# This file will work once function declarations are implemented.

# Import term module for terminal colors and formatting
use "std/term"

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

# =============================================================================
# Test Organization Functions
# =============================================================================

# module(name) - Print module header (for test organization)
fun module(name)
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

    # Execute test (would use try/catch when available)
    test_fn()

    # If we reach here, test passed
    pass_count = pass_count + 1
    puts("  " .. green("✓") .. " " .. name)
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
    if !condition
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
    puts("\n" .. bold("Test Results:"))
    puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    puts("Total:   " .. test_count._str())

    if pass_count > 0
        puts(green("Passed:  " .. pass_count._str()))
    end

    if fail_count > 0
        puts(red("Failed:  " .. fail_count._str()))
    end

    if skip_count > 0
        puts(yellow("Skipped: " .. skip_count._str()))
    end

    puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    if fail_count == 0
        puts(bold(green("✓ All tests passed!")))
        return 0
    else
        puts(bold(red("✗ Some tests failed")))
        return 1
    end
end

# run_file(path) - Load and run tests from file
fun run_file(path)
    # Would load and execute file, then call run()
    puts("Running tests from ", path)
end

# run_dir(path) - Run all test files in directory
fun run_dir(path)
    # Would find all .q files and run each
    puts("Running tests from directory ", path)
end

# =============================================================================
# Example Usage
# =============================================================================
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
