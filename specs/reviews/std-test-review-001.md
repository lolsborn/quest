# std/test.q Code Review

**Review ID:** std-test-review-001
**Date:** 2025-10-05
**Reviewer:** Claude (Code Review Agent)
**File:** lib/std/test.q (1044 lines)
**Status:** Production-Ready with Recommended Improvements

---

## Executive Summary

**Overall Grade: B+ (87/100)**

The test framework is **functional and feature-rich**, with excellent output capture, tag filtering, and condensed mode. However, there are **significant opportunities** for code quality improvements through:
- Reducing duplication (especially in assertions)
- Extracting helper functions
- Simplifying complex logic
- Improving robustness with better error handling

**Recommendation:** Refactor for maintainability while preserving all features.

---

## Scoring Breakdown

| Category | Score | Notes |
|----------|-------|-------|
| **Functionality** | 9/10 | Comprehensive feature set |
| **Code Quality** | 7/10 | Significant duplication |
| **Maintainability** | 7/10 | Could be more modular |
| **Robustness** | 8/10 | Good but could be better |
| **Documentation** | 9/10 | Good examples and comments |
| **Performance** | 9/10 | Efficient overall |
| **Total** | **87/100** | **B+** |

---

## Critical Issues

### None Found ✅

The code works correctly and has no blocking bugs.

---

## High Priority Improvements

### 1. **Massive Duplication in Assertion Functions** 🔴

**Severity:** HIGH
**Lines:** 582-854 (273 lines of nearly identical code)

**Problem:**
All 11 assertion functions follow identical patterns with only minor variations:
- Increment fail counters (3 lines, identical in every function)
- Format failure message (varies)
- Handle condensed vs normal output (4-6 lines, identical)

**Example of Duplication:**
```quest
# Lines 607-622 (assert_eq)
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

# Lines 627-642 (assert_neq)
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
```

This pattern repeats **11 times** (assert, assert_eq, assert_neq, assert_gt, assert_lt, assert_gte, assert_lte, assert_nil, assert_not_nil, assert_type, assert_near).

**Solution:** Extract common logic into helper function:

```quest
# Helper function for assertion failures
fun record_failure(failure_msg, user_message)
    fail_count = fail_count + 1
    describe_fail_count = describe_fail_count + 1
    module_fail_count = module_fail_count + 1

    # Append user message if provided
    let full_msg = failure_msg
    if user_message != nil
        full_msg = full_msg .. ": " .. user_message
    end

    # Display based on output mode
    if condensed_output
        describe_failures = describe_failures.concat([full_msg])
    else
        puts("  " .. red("✗") .. " " .. full_msg)
    end
end

# Now assertions become much shorter:
pub fun assert_eq(actual, expected, message)
    if actual != expected
        record_failure(
            "Expected " .. expected._rep() .. " but got " .. actual._rep(),
            message
        )
    end
end

pub fun assert_neq(actual, expected, message)
    if actual == expected
        record_failure(
            "Expected value to not equal " .. expected._rep(),
            message
        )
    end
end

pub fun assert_gt(actual, expected, message)
    if actual <= expected
        record_failure(
            "Expected " .. actual._rep() .. " > " .. expected._rep(),
            message
        )
    end
end
```

**Impact:**
- **Reduces code from ~273 lines to ~100 lines** (63% reduction)
- **Improves maintainability** - single source of truth for failure handling
- **Makes changes easier** - modify one function instead of 11
- **No behavior changes** - purely refactoring

---

### 2. **Duplicate Captured Output Display Logic** 🔴

**Severity:** HIGH
**Lines:** 475-493 and 531-549 (38 lines duplicated)

**Problem:**
The exact same code for displaying captured stdout/stderr appears twice:

```quest
# Lines 475-493 (in exception handler)
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

# Lines 531-549 (in assertion failure handler)
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
```

**Solution:**

```quest
fun display_captured_output(captured_stdout, captured_stderr)
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

# Usage:
display_captured_output(captured_stdout, captured_stderr)
```

**Impact:**
- **Reduces 38 lines to 2 (function call)**
- **Easier to modify display format** - change once, applies everywhere
- **More DRY (Don't Repeat Yourself)**

---

### 3. **Complex Tag Filtering Logic** 🟡

**Severity:** MEDIUM
**Lines:** 342-372 (31 lines of nested loops)

**Problem:**
Tag filtering uses nested loops to check if arrays contain common elements:

```quest
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
```

**Solution:** Extract helper function for array intersection:

```quest
# Helper: Check if any element from array1 is in array2
fun arrays_intersect(array1, array2)
    for item1 in array1
        for item2 in array2
            if item1 == item2
                return true
            end
        end
    end
    return false
end

# Now tag filtering becomes clearer:
let should_skip = false
let skip_reason = ""

# Skip if test has any skip_tags
if skip_tags.len() > 0 and arrays_intersect(merged_tags, skip_tags)
    should_skip = true
    skip_reason = "excluded by tag filter"
end

# Skip if test doesn't have required filter_tags
if not should_skip and filter_tags.len() > 0
    if not arrays_intersect(merged_tags, filter_tags)
        should_skip = true
        skip_reason = "missing required tag"
    end
end
```

**Impact:**
- **Clearer intent** - function names explain what's happening
- **Reusable** - can be used elsewhere
- **Easier to test** - helper can be tested independently

---

### 4. **Color Helper Functions Are Redundant** 🟡

**Severity:** MEDIUM
**Lines:** 118-165 (48 lines)

**Problem:**
Six color helper functions follow identical pattern:

```quest
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

# ... 4 more identical functions
```

**Solution:** Single higher-order function:

```quest
# Single color wrapper
fun color(color_fn, text)
    if use_colors
        return color_fn(text)
    else
        return text
    end
end

# Usage becomes:
puts(color(term.green, "✓ Passed"))
puts(color(term.red, "✗ Failed"))
```

**Or even better - inline the check:**

```quest
# Just use term.* directly and disable via term module
if not use_colors
    term.set_colors(false)  # Assuming term module has this
end

# Then use term.green() directly everywhere
puts(term.green("✓ Passed"))
```

**Impact:**
- **Reduces 48 lines to ~2 lines**
- **Simpler mental model** - use colors directly
- **Less code to maintain**

**Note:** If term module doesn't have set_colors(), keep the wrappers but consider making them private (not `pub`).

---

## Medium Priority Improvements

### 5. **Unimplemented Lifecycle Functions** 🟡

**Severity:** MEDIUM
**Lines:** 554-575

**Problem:**
Four functions are stubs with no real implementation:

```quest
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
```

**Solution:**

**Option 1: Remove them**
```quest
# Just delete these functions if not used
# Users can manually call setup in their tests
```

**Option 2: Implement properly**
```quest
let before_each_fn = nil
let after_each_fn = nil
let after_all_fns = []  # Stack of cleanup functions

pub fun before(setup_fn)
    before_each_fn = setup_fn
end

pub fun after(teardown_fn)
    after_each_fn = teardown_fn
end

pub fun after_all(teardown_fn)
    after_all_fns.push(teardown_fn)
end

# In it() function, add:
if before_each_fn != nil
    before_each_fn()
end

# Execute test
test_fn()

# After test
if after_each_fn != nil
    after_each_fn()
end

# In describe() at end, add:
if after_all_fns.len() > 0
    let cleanup_fn = after_all_fns.pop()
    if cleanup_fn != nil
        cleanup_fn()
    end
end
```

**Recommendation:** Either implement fully or remove. Stub functions create confusion.

---

### 6. **Module Variables Are Global State** 🟡

**Severity:** MEDIUM
**Lines:** 43-76 (34 module-level variables)

**Problem:**
Test state is stored in 34 module-level variables:

```quest
let test_suites = []
let current_suite = nil
let current_suite_tests = []
let test_count = 0
let pass_count = 0
let fail_count = 0
# ... 28 more variables
```

**Issues:**
- Makes testing the test framework difficult
- Risk of state corruption
- Can't run multiple test suites independently
- Hard to reset state

**Solution:** Encapsulate in a type:

```quest
type TestRunner
    # Counters
    int: test_count
    int: pass_count
    int: fail_count
    int: skip_count

    # State
    str?: current_module_name
    str?: current_describe_name
    array: describe_failures

    # Config
    bool: use_colors
    bool: condensed_output

    # ... rest of state

    fun reset()
        self.test_count = 0
        self.pass_count = 0
        # ... reset all
    end

    fun it(name, test_fn)
        # Implementation using self.*
    end

    fun assert_eq(actual, expected, message)
        # Implementation using self.*
    end
end

# Usage:
let runner = TestRunner.new(use_colors: true, condensed_output: false)
runner.module("My Tests")
runner.describe("Feature", fun ()
    runner.it("works", fun ()
        runner.assert_eq(1, 1, nil)
    end)
end)
runner.stats()
```

**Impact:**
- **Better encapsulation** - state is explicit
- **Testable** - can create multiple runners
- **Resetable** - easy to start fresh
- **Thread-safe potential** - each runner independent

**Trade-off:** More verbose API (`runner.it()` vs `test.it()`)

**Recommendation:** Consider for next major version. Current approach works but limits extensibility.

---

### 7. **Inconsistent Error Handling** 🟡

**Severity:** MEDIUM
**Lines:** Various

**Problem:**
Some paths don't handle errors well:

**Example 1: File operations don't check for errors**
```quest
# Lines 1028-1038
if io.is_file(path)
    # What if path is invalid?
    parts = path.split("/")
    filename = parts[parts.len() - 1]  # Could error if empty
    # ...
end
```

**Example 2: Array indexing without bounds check**
```quest
# Line 991
filename = parts[parts.len() - 1]  # What if parts is empty?
```

**Solution:**

```quest
# Defensive path parsing
fun get_filename(path)
    let parts = path.split("/")
    if parts.len() == 0
        return ""
    end
    return parts[parts.len() - 1]
end

# Usage:
let filename = get_filename(path)
if filename == ""
    # Skip invalid path
end
```

**Impact:**
- **More robust** - handles edge cases
- **Clearer error messages** - can add context
- **Prevents crashes** - graceful degradation

---

### 8. **Magic Numbers and Strings** 🟡

**Severity:** LOW
**Lines:** Various

**Problem:**
Hardcoded values without named constants:

```quest
# Line 962: What is 255?
if fail_count > 255
    return 255

# Lines 475-549: Hardcoded indentation "      "
puts("      " .. dimmed(line))

# Line 940: Hardcoded separator
puts("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
```

**Solution:**

```quest
# Constants at top of file
let MAX_EXIT_CODE = 255  # Exit codes are 0-255
let TEST_INDENT = "  "
let FAILURE_INDENT = "    "
let OUTPUT_INDENT = "      "
let SEPARATOR_LINE = "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Usage:
if fail_count > MAX_EXIT_CODE
    return MAX_EXIT_CODE

puts(OUTPUT_INDENT .. dimmed(line))
puts(SEPARATOR_LINE)
```

**Impact:**
- **Self-documenting** - names explain purpose
- **Easy to change** - modify once, applies everywhere
- **Consistency** - ensures uniform spacing

---

## Low Priority Improvements

### 9. **Unused Variable** ℹ️

**Line 44:**
```quest
let test_suites = []
```

**Problem:** Declared but never used.

**Solution:** Remove it.

---

### 10. **Verbose Conditional Assignment** ℹ️

**Lines:** 200-212, 238-250

**Problem:**
```quest
let status_marker = nil
if describe_fail_count > 0
    status_marker = red("✗")
else
    status_marker = green("✓")
end
```

**Solution:** Use ternary:
```quest
let status_marker = if describe_fail_count > 0 then red("✗") else green("✓")
```

**Impact:** More concise, same behavior.

---

### 11. **Comments Could Be More Specific** ℹ️

**Lines:** 554-575

**Problem:**
```quest
# Would be called before each it() in the suite
```

**Better:**
```quest
# TODO: Implement before hook to call setup_fn before each test
# Currently unimplemented - tests must handle setup manually
```

**Impact:** Sets clearer expectations.

---

## Strengths to Preserve ✅

### 1. **Excellent Output Capture Integration**
Lines 406-445 implement proper output capture with guard restoration. This is production-quality code.

### 2. **Tag Filtering System**
Lines 98-116 provide flexible tag-based filtering. Well-designed feature.

### 3. **Condensed Mode**
Lines 192-262 implement smart condensed output. Great for CI/CD.

### 4. **Comprehensive Assertions**
11 different assertion types cover most use cases.

### 5. **Test Discovery**
Lines 971-1044 implement pytest-style test discovery. Very useful.

---

## Refactoring Priority

**High Priority (Do First):**
1. Extract `record_failure()` helper (Issue #1)
2. Extract `display_captured_output()` helper (Issue #2)
3. Decide on lifecycle hooks (Issue #5)

**Medium Priority (Do Next):**
4. Extract `arrays_intersect()` helper (Issue #3)
5. Simplify color helpers (Issue #4)
6. Add error handling (Issue #7)

**Low Priority (Nice to Have):**
7. Add constants for magic numbers (Issue #8)
8. Consider TestRunner type (Issue #6)
9. Remove unused variable (Issue #9)
10. Use ternary operators (Issue #10)

---

## Proposed Refactored Structure

```quest
# =============================================================================
# Constants
# =============================================================================
let MAX_EXIT_CODE = 255
let TEST_INDENT = "  "
let FAILURE_INDENT = "    "
let OUTPUT_INDENT = "      "

# =============================================================================
# State (Consider encapsulating in TestRunner type)
# =============================================================================
# ... module variables ...

# =============================================================================
# Helpers (New Section)
# =============================================================================

fun record_failure(failure_msg, user_message)
    # Common failure handling
end

fun display_captured_output(captured_stdout, captured_stderr)
    # Display captured output
end

fun arrays_intersect(array1, array2)
    # Check if arrays have common elements
end

fun get_filename(path)
    # Safe path parsing
end

# =============================================================================
# Color Helpers (Simplified)
# =============================================================================
# Either inline or keep 6 functions

# =============================================================================
# Configuration
# =============================================================================
# ... existing config functions ...

# =============================================================================
# Core Framework
# =============================================================================

pub fun module(name)
    # ... existing implementation ...
end

pub fun describe(name, test_fn)
    # ... existing implementation ...
end

pub fun it(name, test_fn)
    # ... simplified with helpers ...
end

# =============================================================================
# Assertions (Simplified with record_failure)
# =============================================================================

pub fun assert_eq(actual, expected, message)
    if actual != expected
        record_failure(
            "Expected " .. expected._rep() .. " but got " .. actual._rep(),
            message
        )
    end
end

# ... other assertions similarly simplified ...

# =============================================================================
# Lifecycle Hooks (Implement or Remove)
# =============================================================================
# Either implement fully or delete

# =============================================================================
# Test Discovery
# =============================================================================
# ... existing implementation ...
```

---

## Estimated Refactoring Effort

| Task | Complexity | Time | Lines Changed |
|------|-----------|------|---------------|
| Extract record_failure() | Low | 30 min | -180 lines |
| Extract display_captured_output() | Low | 15 min | -36 lines |
| Extract arrays_intersect() | Low | 15 min | -15 lines |
| Simplify color helpers | Low | 20 min | -40 lines |
| Add error handling | Medium | 45 min | +30 lines |
| Decide on lifecycle hooks | Low | 10 min | ±0 or -22 lines |
| Add constants | Low | 10 min | +10 lines |
| **Total** | | **~2.5 hours** | **-253 lines (24% reduction)** |

---

## Testing Strategy for Refactoring

1. **Before refactoring:** Run all existing tests, capture output
2. **After each change:** Re-run tests, compare output
3. **Verify:**
   - All tests still pass
   - Output format unchanged
   - Performance same or better
4. **Add tests for helpers:**
   ```quest
   test.describe("Helpers", fun ()
       test.it("arrays_intersect detects overlap", fun ()
           test.assert(arrays_intersect([1, 2], [2, 3]), nil)
           test.assert(not arrays_intersect([1, 2], [3, 4]), nil)
       end)
   end)
   ```

---

## Migration Path

**Phase 1: Non-Breaking Changes (Do Now)**
- Extract helper functions
- Add constants
- Improve error handling
- No API changes

**Phase 2: API Improvements (Next Major Version)**
- Implement or remove lifecycle hooks
- Consider TestRunner type
- Breaking changes allowed

---

## Conclusion

The test framework is **functional and feature-complete** but suffers from **code duplication** that makes it harder to maintain. The proposed refactoring would:

- **Reduce code by ~253 lines (24%)**
- **Improve maintainability** through DRY principles
- **Preserve all features** - purely internal improvements
- **Take ~2.5 hours** of focused work

**Recommendation:** Implement high-priority refactorings (Issues #1, #2, #5) immediately. These provide the most benefit with lowest risk.

---

## Final Score

**Current:** B+ (87/100)
**After Refactoring:** A (94/100)

The functionality is excellent; the code quality can be significantly improved with straightforward refactoring.

---

**Review Completed:** 2025-10-05
**Reviewer:** Claude (Code Review Agent)
**Lines Reviewed:** 1044 lines
**Issues Found:** 11 (0 critical, 7 high/medium, 4 low)
**Recommended Action:** Refactor high-priority issues
