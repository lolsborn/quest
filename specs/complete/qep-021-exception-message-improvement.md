# QEP-021: Exception Message Improvement

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05

## Abstract

This QEP addresses the quality and consistency of exception messages throughout Quest's codebase. Currently, many errors provide minimal context, making debugging difficult for users. This proposal establishes standards for error messages, categorizes existing issues, and provides actionable recommendations for improvement.

## Problem Statement

Quest currently has 822 error return sites across 51 Rust source files. Analysis reveals several categories of problems:

### 1. **Generic Error Messages**
Many errors provide little context about what went wrong or how to fix it:
```rust
// Bad: What operation? What value? What type was expected?
"Cannot shift from empty array"
"Cannot humanize this span"
"Invalid escape sequence at end of bytes literal"
```

### 2. **Missing Contextual Information**
Errors don't include values, types, or state information:
```rust
// Bad: Which variable? What was the actual type?
"write expects a Str argument"

// Good alternative:
"write expects Str argument, got Float"
```

### 3. **Inconsistent Formatting**
Similar errors have different message patterns:
```rust
"len expects 0 arguments, got {}"              // Format 1
"{} expects 0 arguments, got {}"                // Format 2
"write expects 1 argument, got {}"              // Format 3
"execute expects at least 1 argument (sql)"     // Format 4
```

### 4. **Ambiguous Operation Context**
When errors occur deep in method chains, it's unclear which operation failed:
```rust
// Error: "Division by zero"
// But which division? In which expression?
let x = (a / b) + (c / d) + (e / f)  // Which one failed?
```

### 5. **Poor User Experience**
Users see terse messages without guidance:
```rust
// Bad
"Invalid"
"Error"
"Cannot"

// Better
"Invalid date format 'abc': expected YYYY-MM-DD"
```

## Current Error Distribution

**Total Error Sites:** 822 across 51 files

**Files with Most Errors:**
- [src/main.rs](../../src/main.rs) - 80+ errors (evaluator, core operations)
- [src/types/string.rs](../../src/types/string.rs) - 39+ errors (string methods)
- [src/types/float.rs](../../src/types/float.rs) - 31+ errors (numeric operations)
- [src/types/array.rs](../../src/types/array.rs) - 26+ errors (array operations)
- [src/types/set.rs](../../src/types/set.rs) - 28+ errors (set operations)
- [src/modules/time.rs](../../src/modules/time.rs) - 142+ errors (time operations)
- [src/modules/process.rs](../../src/modules/process.rs) - 57+ errors (process execution)
- [src/modules/http/client.rs](../../src/modules/http/client.rs) - 30+ errors (HTTP operations)

## Error Message Quality Analysis

### Category A: Argument Count Validation (Good) ✅

**Pattern:** Clear, consistent, actionable
```rust
format!("{} expects {} argument(s), got {}", method, expected, actual)
```

**Examples:**
```rust
"len expects 0 arguments, got 2"
"push expects 1 argument, got 3"
"reduce expects 2 arguments (initial, function), got 1"
```

**Quality:** ★★★★★ (5/5)
- Clear operation name
- Expected count
- Actual count
- Sometimes includes parameter names

**Recommendation:** Keep this pattern as the standard

### Category B: Type Mismatch Errors (Needs Improvement) ⚠️

**Current Pattern:** Missing actual type
```rust
"write expects a Str argument"
"filter expects a function argument"
"gt expects a numeric argument"
```

**Issues:**
- Doesn't show what type was received
- User can't see their mistake
- Requires trial-and-error debugging

**Recommended Pattern:**
```rust
format!("{} expects {} argument, got {}", method, expected_type, actual_type)
```

**Examples:**
```rust
// Current
"write expects a Str argument"

// Improved
"write expects Str argument, got Float"
"filter expects Function argument, got Int"
"gt expects numeric argument, got Str"
```

**Quality:** ★★☆☆☆ (2/5)

### Category C: Bounds/Validation Errors (Good) ✅

**Pattern:** Includes actual values and context
```rust
format!("Index {} out of bounds for array of length {}", index, len)
format!("Invalid slice range {}:{} for bytes of length {}", start, end, len)
```

**Quality:** ★★★★☆ (4/5)
- Shows actual values
- Shows valid ranges
- Clear problem statement

**Recommendation:** Add suggestion for valid range
```rust
format!(
    "Index {} out of bounds for array of length {} (valid range: 0..{})",
    index, len, len
)
```

### Category D: Mathematical Errors (Needs Improvement) ⚠️

**Current Pattern:** No context
```rust
"Division by zero"
"Modulo by zero"
"Cannot divide by zero"
```

**Issues:**
- No expression context
- No operand values
- Inconsistent wording (3 variations for same error)

**Recommended Pattern:**
```rust
format!("Division by zero: {} / 0", left_value)
```

**Examples:**
```rust
// Current
"Division by zero"

// Improved
"Division by zero: 42 / 0"
"Modulo by zero: 17 % 0"
"Integer overflow: 9223372036854775807 + 1"
```

**Quality:** ★★☆☆☆ (2/5)

### Category E: Empty Collection Errors (Fair) ⭐

**Pattern:** Clear but could be more helpful
```rust
"Cannot pop from empty array"
"Cannot shift from empty array"
"Cannot get first element of empty array"
```

**Quality:** ★★★☆☆ (3/5)
- Clear operation
- Clear problem
- Missing: suggestion or context

**Recommended Enhancement:**
```rust
"Cannot pop from empty array (length 0)"
"Cannot shift from empty array: no elements to remove"
```

### Category F: Unknown/Not Found Errors (Good) ✅

**Pattern:** Includes name of missing entity
```rust
format!("Unknown method '{}' on {}", method, type_name)
format!("Type {} not found", type_name)
format!("Trait {} not found", trait_name)
```

**Quality:** ★★★★☆ (4/5)
- Shows what was requested
- Shows context (type/module)

**Enhancement Opportunity:**
```rust
// Current
"Unknown method 'foo' on Array"

// With suggestions
"Unknown method 'foo' on Array. Did you mean 'find'? Available: push, pop, shift, ..."
```

### Category G: Format/Parsing Errors (Needs Improvement) ⚠️

**Current Pattern:** Generic messages
```rust
"Invalid duration format"
"Invalid escape sequence at end of bytes literal"
"Invalid character in duration"
```

**Issues:**
- Doesn't show the invalid input
- No example of valid format
- No position information

**Recommended Pattern:**
```rust
format!(
    "Invalid {} format: '{}'. Expected format: {} (example: {})",
    thing, input, format_spec, example
)
```

**Examples:**
```rust
// Current
"Invalid duration format"

// Improved
"Invalid duration format: 'abc123'. Expected format: <number><unit> where unit is d/h/m/s (example: '5h', '30m')"
"Invalid escape sequence: '\\z' at position 12. Valid sequences: \\n, \\r, \\t, \\\\, \\', \\\", \\xHH"
```

**Quality:** ★☆☆☆☆ (1/5)

### Category H: Configuration/Option Errors (Good) ✅

**Pattern:** Shows valid values
```rust
format!("Invalid data bits: {} (must be 5, 6, 7, or 8)", bits)
format!("Invalid parity: {} (must be 'none', 'odd', or 'even')", parity)
```

**Quality:** ★★★★★ (5/5)
- Shows invalid value
- Shows valid options
- Clear constraint

**Recommendation:** This is the gold standard

## Proposed Standards

### Standard 1: Error Message Structure

Every error message should follow this structure:
```
[Operation/Context]: [Problem Description] [Additional Info] [Suggestion/Valid Values]
```

**Examples:**
```rust
// Argument errors
"push expects 1 argument, got 3"

// Type errors
"write expects Str argument, got Float"

// Bounds errors
"Index 5 out of bounds for array of length 3 (valid range: 0..3)"

// Configuration errors
"Invalid parity: 'invalid' (must be 'none', 'odd', or 'even')"

// Format errors
"Invalid date format: '2025-13-45'. Expected YYYY-MM-DD (example: '2025-10-05')"
```

### Standard 2: Always Include Actual Values

When validation fails, show what was provided:
```rust
// ❌ Bad
"Invalid timeout"

// ✅ Good
"Invalid timeout: -5 (must be positive)"

// ❌ Bad
"gt expects a numeric argument"

// ✅ Good
"gt expects numeric argument, got Str"
```

### Standard 3: Provide Context for Chained Operations

Include object type and method in error context:
```rust
// ❌ Bad
"Cannot pop from empty array"

// ✅ Good
"Array.pop() failed: cannot pop from empty array (length 0)"
```

### Standard 4: Suggest Valid Values/Ranges

When there's a finite set of valid values, show them:
```rust
// ✅ Excellent
"Invalid compression level: 10 (must be 0-9)"
"Unknown hash algorithm: 'sha3'. Supported: md5, sha1, sha256, sha512, crc32"
```

### Standard 5: Consistent Terminology

Use consistent wording across similar errors:
```rust
// ❌ Inconsistent
"Division by zero"
"Cannot divide by zero"
"Divide by zero error"

// ✅ Consistent
"Division by zero: {} / 0"
"Modulo by zero: {} % 0"
```

### Standard 6: Include Type Names in Type Errors

Always show both expected and actual types:
```rust
// ❌ Bad
"expects a function argument"

// ✅ Good
"filter expects Function argument, got Int"
```

### Standard 7: Format Errors Should Show Examples

When parsing/format validation fails:
```rust
format!(
    "Invalid {} format: '{}'. Expected: {} (example: {})",
    entity, input, spec, example
)
```

## Implementation Priorities

### Priority 1: Type Mismatch Errors (High Impact) 🔴

**Files:** All type files ([src/types/](../../src/types/)), module files
**Issue:** Missing actual type in error messages
**Impact:** High - affects every type operation
**Effort:** Medium - requires passing actual type to error message

**Example Fix:**
```rust
// Before
_ => return Err("write expects a Str argument".to_string())

// After
_ => return Err(format!(
    "write expects Str argument, got {}",
    args[0].as_obj().cls()
))
```

**Estimated Sites:** ~200 errors
**Files to Fix:**
- [src/types/string.rs](../../src/types/string.rs) - ~39 type errors
- [src/types/array.rs](../../src/types/array.rs) - ~26 type errors
- [src/types/dict.rs](../../src/types/dict.rs) - ~4 type errors
- [src/types/float.rs](../../src/types/float.rs) - ~31 type errors
- [src/types/int.rs](../../src/types/int.rs) - ~18 type errors
- [src/modules/](../../src/modules/) - ~100+ type errors across all modules

### Priority 2: Mathematical Operation Errors (High Visibility) 🔴

**Files:** [src/types/int.rs](../../src/types/int.rs), [src/types/float.rs](../../src/types/float.rs), [src/types/decimal.rs](../../src/types/decimal.rs)
**Issue:** No context about operands
**Impact:** High - common operations
**Effort:** Low - just add operand values

**Example Fix:**
```rust
// Before
return Err("Division by zero".to_string())

// After
return Err(format!("Division by zero: {} / 0", self.value))
```

**Estimated Sites:** ~20 errors

### Priority 3: Format/Parsing Errors (Medium Impact) 🟡

**Files:** [src/modules/time.rs](../../src/modules/time.rs), [src/main.rs](../../src/main.rs) (literals)
**Issue:** No examples or format specifications
**Impact:** Medium - confusing for users
**Effort:** Medium - requires format documentation

**Example Fix:**
```rust
// Before
return Err("Invalid duration format".to_string())

// After
return Err(format!(
    "Invalid duration format: '{}'. Expected: <number><unit> where unit is d/h/m/s (example: '5h', '30m')",
    input
))
```

**Estimated Sites:** ~50 errors

### Priority 4: Bounds Checking Errors (Low Priority) 🟢

**Files:** [src/types/array.rs](../../src/types/array.rs), [src/types/bytes.rs](../../src/types/bytes.rs)
**Issue:** Could include valid range
**Impact:** Low - messages already decent
**Effort:** Low

**Example Enhancement:**
```rust
// Before
format!("Index {} out of bounds for array of length {}", index, len)

// After
format!(
    "Index {} out of bounds for array of length {} (valid range: 0..{})",
    index, len, len
)
```

**Estimated Sites:** ~15 errors

### Priority 5: Add Suggestions for Unknown Methods (Nice-to-Have) 🔵

**Files:** [src/main.rs](../../src/main.rs) (method resolution)
**Issue:** No suggestions for typos
**Impact:** Low - quality-of-life improvement
**Effort:** High - requires fuzzy matching

**Example Enhancement:**
```rust
// Before
format!("Unknown method '{}' on {}", method, type_name)

// After
format!(
    "Unknown method '{}' on {}. Did you mean '{}'? Available methods: {}",
    method, type_name, suggestion, available_methods
)
```

**Estimated Sites:** ~10 errors
**Complexity:** Requires implementation of:
- Method name fuzzy matching (Levenshtein distance)
- Method enumeration for each type
- Suggestion ranking

## File-by-File Recommendations

### High Priority Files

#### [src/types/string.rs](../../src/types/string.rs) (39 errors)
**Issues:**
- Type mismatch errors missing actual type
- Format errors without examples

**Recommended Changes:**
```rust
// Line ~50-100: Method argument validation
// Before
_ => return Err("split expects a string separator".to_string())

// After
_ => return Err(format!(
    "split expects Str separator, got {}",
    args[0].as_obj().cls()
))

// Line ~200-300: Format operations
// Before
return Err("Invalid format specifier".to_string())

// After
return Err(format!(
    "Invalid format specifier: '{}' at position {}. Valid: {}, {}, {}, ...",
    spec, pos, "s", "d", "f"
))
```

#### [src/types/float.rs](../../src/types/float.rs) (31 errors)
**Issues:**
- "Division by zero" without operand values
- Type errors without actual types
- Inconsistent comparison error messages

**Recommended Changes:**
```rust
// Lines 160-190: Division operations
// Before
return Err("Division by zero".to_string())

// After
return Err(format!("Division by zero: {} / 0", self.value))

// Lines 230-280: Comparison operations
// Before
_ => return Err("gt expects a numeric argument".to_string())

// After
_ => return Err(format!(
    "gt expects numeric argument (Int, Float, Decimal), got {}",
    args[0].as_obj().cls()
))
```

#### [src/types/array.rs](../../src/types/array.rs) (26 errors)
**Issues:**
- Type errors for functional methods (map, filter, reduce)
- Empty array errors could include length

**Recommended Changes:**
```rust
// Lines 200-300: Functional methods
// Before
_ => return Err("map expects a function argument".to_string())

// After
_ => return Err(format!(
    "map expects Function argument, got {}",
    args[0].as_obj().cls()
))

// Lines 50-100: Empty checks
// Before
return Err("Cannot pop from empty array".to_string())

// After
return Err("Cannot pop from empty array (length 0)".to_string())
```

#### [src/modules/time.rs](../../src/modules/time.rs) (142 errors)
**Issues:**
- Format parsing errors without examples
- Duration parsing without format specification
- Validation errors without valid ranges

**Recommended Changes:**
```rust
// Duration parsing
// Before
return Err("Invalid duration format".to_string())

// After
return Err(format!(
    "Invalid duration format: '{}'. Expected: <number><unit> where unit is d/h/m/s (examples: '5h', '30m', '1d')",
    input
))

// Date parsing
// Before
return Err("Invalid date format".to_string())

// After
return Err(format!(
    "Invalid date format: '{}'. Expected: YYYY-MM-DD (example: '2025-10-05')",
    input
))

// Time component validation
// Before
return Err("Invalid hour".to_string())

// After
return Err(format!(
    "Invalid hour: {} (must be 0-23)",
    hour_value
))
```

### Medium Priority Files

#### [src/types/int.rs](../../src/types/int.rs) (18 errors)
Similar issues to float.rs - division by zero, type mismatches

#### [src/types/dict.rs](../../src/types/dict.rs) (4 errors)
Type validation for keys/values

#### [src/types/bytes.rs](../../src/types/bytes.rs) (7 errors)
Escape sequence errors, bounds checking

#### [src/modules/http/client.rs](../../src/modules/http/client.rs) (30 errors)
HTTP-specific validation (URLs, headers, methods)

#### [src/modules/serial.rs](../../src/modules/serial.rs) (15 errors)
Serial port configuration validation (already good examples)

### Low Priority Files

Most module files have decent error messages or low error counts (< 10 errors per file).

## Helper Function for Type Errors

Create a helper function for consistent type error messages:

```rust
// In src/types/mod.rs or src/error.rs

pub fn type_error(
    method: &str,
    param_name: &str,
    expected: &str,
    actual: &QValue
) -> String {
    format!(
        "{} expects {} {}, got {}",
        method,
        expected,
        param_name,
        actual.as_obj().cls()
    )
}

// Usage
return Err(type_error("map", "argument", "Function", &args[0]))
// Produces: "map expects Function argument, got Int"

pub fn multi_type_error(
    method: &str,
    param_name: &str,
    expected: &[&str],
    actual: &QValue
) -> String {
    format!(
        "{} expects {} {} ({}), got {}",
        method,
        expected.join(" or "),
        param_name,
        expected.join(", "),
        actual.as_obj().cls()
    )
}

// Usage
return Err(multi_type_error("write", "argument", &["Str", "Bytes"], &args[0]))
// Produces: "write expects Str or Bytes argument (Str, Bytes), got Int"
```

## Helper Function for Bounds Errors

```rust
pub fn bounds_error(
    index: i64,
    len: usize,
    collection_type: &str
) -> String {
    format!(
        "Index {} out of bounds for {} of length {} (valid range: 0..{})",
        index, collection_type, len, len
    )
}

// Usage
return Err(bounds_error(index, elements.len(), "array"))
// Produces: "Index 10 out of bounds for array of length 5 (valid range: 0..5)"
```

## Helper Function for Format Errors

```rust
pub fn format_error(
    entity: &str,
    input: &str,
    expected_format: &str,
    example: &str
) -> String {
    format!(
        "Invalid {} format: '{}'. Expected: {} (example: '{}')",
        entity, input, expected_format, example
    )
}

// Usage
return Err(format_error(
    "date",
    input,
    "YYYY-MM-DD",
    "2025-10-05"
))
// Produces: "Invalid date format: 'abc'. Expected: YYYY-MM-DD (example: '2025-10-05')"
```

## Implementation Strategy

### Phase 1: Create Helper Functions (Week 1)
- Create [src/error.rs](../../src/error.rs) module
- Implement helper functions for common error patterns
- Add comprehensive tests
- Document usage patterns

### Phase 2: High-Priority Type Errors (Weeks 2-3)
- Fix type mismatch errors in core types
  - [src/types/string.rs](../../src/types/string.rs)
  - [src/types/array.rs](../../src/types/array.rs)
  - [src/types/int.rs](../../src/types/int.rs)
  - [src/types/float.rs](../../src/types/float.rs)
  - [src/types/dict.rs](../../src/types/dict.rs)
- Run test suite after each file
- Update tests that check error messages

### Phase 3: Mathematical Errors (Week 4)
- Fix division by zero errors
- Add operand context to overflow errors
- Update numeric type error messages

### Phase 4: Format/Parsing Errors (Week 5)
- [src/modules/time.rs](../../src/modules/time.rs) - Date/time/duration parsing
- [src/main.rs](../../src/main.rs) - Literal parsing
- Add format examples to all parsing errors

### Phase 5: Module-Specific Errors (Week 6)
- Fix remaining errors in modules
- Focus on high-usage modules:
  - [src/modules/io.rs](../../src/modules/io.rs)
  - [src/modules/http/client.rs](../../src/modules/http/client.rs)
  - [src/modules/db/](../../src/modules/db/)

### Phase 6: Polish and Suggestions (Week 7)
- Add method name suggestions (fuzzy matching)
- Add "did you mean?" for common typos
- Improve error message formatting

### Phase 7: Documentation (Week 8)
- Update error handling guide
- Create examples of good error messages
- Document error message standards

## Testing Strategy

### Test Error Messages Explicitly

Add tests that verify error message quality:

```quest
# test/errors/error_message_test.q
use "std/test"

test.module("Error Message Quality")

test.describe("Type errors include actual type", fun ()
    test.it("shows actual type in error message", fun ()
        let arr = [1, 2, 3]
        try
            arr.map(42)  # 42 is Int, not Function
            test.fail("Should raise error")
        catch e
            # Verify error message includes both expected and actual type
            test.assert(e.message().contains("Function"), "Should mention expected type")
            test.assert(e.message().contains("Int"), "Should mention actual type")
        end
    end)
end)

test.describe("Bounds errors include valid range", fun ()
    test.it("shows valid range for array access", fun ()
        let arr = [1, 2, 3]
        try
            arr.get(10)
            test.fail("Should raise error")
        catch e
            test.assert(e.message().contains("10"), "Should show requested index")
            test.assert(e.message().contains("3"), "Should show array length")
            test.assert(e.message().contains("0..3"), "Should show valid range")
        end
    end)
end)

test.describe("Format errors include examples", fun ()
    test.it("shows example for date format errors", fun ()
        try
            time.parse("invalid-date", "%Y-%m-%d")
            test.fail("Should raise error")
        catch e
            test.assert(e.message().contains("example"), "Should include example")
            test.assert(e.message().contains("YYYY-MM-DD"), "Should show format")
        end
    end)
end)
```

### Regression Prevention

When fixing error messages:
1. Search for tests that assert on old error message text
2. Update test assertions to match new messages
3. Add test if error message wasn't previously tested
4. Ensure new message is more informative than old

## Metrics for Success

Track improvement with these metrics:

### Before (Baseline)
- Total error sites: 822
- Type errors without actual type: ~200 (24%)
- Math errors without operands: ~20 (2%)
- Format errors without examples: ~50 (6%)
- Generic "Error" messages: ~30 (4%)

### After (Target)
- Type errors with actual type: 100%
- Math errors with operand context: 100%
- Format errors with examples: 100%
- Zero generic "Error" messages: 0%

### Quality Scores (5-point scale)
- Argument count errors: 5/5 (already good) ✅
- Type errors: 2/5 → 5/5
- Bounds errors: 4/5 → 5/5
- Math errors: 2/5 → 5/5
- Format errors: 1/5 → 5/5
- Configuration errors: 5/5 (already good) ✅

## Breaking Changes

Some tests may assert on specific error message text. These will need updates:

```quest
# Before
test.assert(e.message() == "Division by zero")

# After
test.assert(e.message().contains("Division by zero"))
# or be more specific
test.assert(e.message().contains("Division by zero: 42 / 0"))
```

**Recommendation:** Search for `e.message() ==` in test files and update to use `.contains()` for forward compatibility.

## Examples of Improved Error Messages

### Before and After

#### Example 1: Type Error
```rust
// Before
❌ "write expects a Str argument"

// After
✅ "write expects Str argument, got Float"
```

#### Example 2: Mathematical Error
```rust
// Before
❌ "Division by zero"

// After
✅ "Division by zero: 42 / 0"
```

#### Example 3: Format Error
```rust
// Before
❌ "Invalid duration format"

// After
✅ "Invalid duration format: 'abc123'. Expected: <number><unit> where unit is d/h/m/s (example: '5h', '30m')"
```

#### Example 4: Bounds Error
```rust
// Before
⚠️ "Index 10 out of bounds for array of length 5"

// After
✅ "Index 10 out of bounds for array of length 5 (valid range: 0..5)"
```

#### Example 5: Configuration Error (Already Good)
```rust
// Current
✅ "Invalid parity: 'invalid' (must be 'none', 'odd', or 'even')"

// This is the gold standard!
```

#### Example 6: Empty Collection
```rust
// Before
⚠️ "Cannot pop from empty array"

// After
✅ "Array.pop() failed: cannot pop from empty array (length 0)"
```

#### Example 7: Unknown Method (Future Enhancement)
```rust
// Before
⚠️ "Unknown method 'len' on Array"

// After (with suggestions)
✅ "Unknown method 'len' on Array. Did you mean 'length'? Available: push, pop, shift, unshift, get, ..."
```

## Alternative Approaches Considered

### 1. Exception Types with Structured Data

Instead of string messages, use typed exceptions:

```rust
enum QuestError {
    TypeError {
        operation: String,
        expected: Vec<String>,
        got: String,
    },
    BoundsError {
        index: i64,
        length: usize,
        collection_type: String,
    },
    // ...
}
```

**Pros:**
- Structured data for programmatic error handling
- Easier to test
- More extensible

**Cons:**
- Large refactor (affects all 822 error sites)
- Would require changes to Quest's exception model
- May impact performance (heap allocation for error data)

**Decision:** Defer to future QEP. Current string-based approach is adequate with improved messages.

### 2. Localization/i18n Support

Error messages in multiple languages:

```rust
error_message("type_mismatch", locale, args)
// en: "write expects Str argument, got Float"
// es: "write espera argumento Str, recibió Float"
```

**Pros:**
- International audience support
- Centralized message management

**Cons:**
- Premature optimization (no demand yet)
- Significant infrastructure investment
- Maintenance burden

**Decision:** Not needed at this time. Focus on improving English messages first.

### 3. Error Context Stack

Attach stack of operations to errors:

```rust
let result = array
    .map(transform)      // <- Error here
    .filter(predicate)
    .reduce(sum)

// Error: "map expects Function argument, got Int"
//        in: array.map(transform).filter(predicate).reduce(sum)
//             ~~~~~~~~~~~~~~~~~~
```

**Pros:**
- Shows error location in expression chain
- Extremely helpful for debugging

**Cons:**
- Requires changes to evaluator
- Performance impact (tracking context)
- Complex implementation

**Decision:** Defer to future QEP. Would be valuable but out of scope for this proposal.

## Related QEPs

- **QEP-006**: Exception Handling - Defines exception model, doesn't address message quality
- **QEP-010**: Stack Traces - Shows call stack, complements good error messages

## Future Enhancements

### Structured Error Types
Create typed exception hierarchy with structured data (QEP-022 candidate)

### Error Recovery Suggestions
Add actionable suggestions: "Did you mean...?", "Try..."

### Interactive Error Explorer
REPL command to explore last error: `.error.explain()`, `.error.docs()`

### Error Message Linting
Tool to detect poor error messages in code reviews

## Conclusion

Quest's error messages need systematic improvement to provide better developer experience. This QEP establishes:

1. **Standards** for error message structure and content
2. **Categorization** of existing error quality (822 sites, 51 files)
3. **Priorities** for implementation (type errors first, then math, then formats)
4. **Helper functions** for consistent error formatting
5. **Testing strategy** to prevent regressions
6. **Metrics** to measure success

**Primary Goal:** Transform generic errors like "Invalid" into helpful messages like "Invalid date format: 'abc'. Expected: YYYY-MM-DD (example: '2025-10-05')"

**Impact:**
- Reduces debugging time for users
- Improves Quest's reputation for developer experience
- Makes error messages competitive with Python, Ruby, Rust

**Estimated Effort:** 8 weeks with systematic file-by-file approach

**Risk:** Low - mostly additive changes, minimal breaking changes (some test assertions need updates)

## References

### Error Message Best Practices
- Rust Error Handling: https://doc.rust-lang.org/book/ch09-00-error-handling.html
- Python Exception Messages: https://docs.python.org/3/tutorial/errors.html
- Elm Compiler Messages: https://elm-lang.org/news/compiler-errors-for-humans

### Studies
- "What Makes a Good Error Message?" - Microsoft Research
- "Error Message Guidelines" - Nielsen Norman Group

### Examples from Other Languages

**Rust** (Excellent):
```
error[E0308]: mismatched types
 --> src/main.rs:5:21
  |
5 |     let x: i32 = "hello";
  |                  ^^^^^^^ expected `i32`, found `&str`
```

**Elm** (Excellent):
```
-- TYPE MISMATCH -------------------------------------------- Main.elm

The 1st argument to `map` is not what I expect:

8|   List.map 42 numbers
              ^^
This argument is a number of type:

    number

But `map` needs the 1st argument to be:

    a -> b
```

**Python** (Good):
```python
TypeError: 'int' object is not iterable
IndexError: list index out of range
ValueError: invalid literal for int() with base 10: 'abc'
```

**Quest Target** (Excellent):
```
TypeError: map expects Function argument, got Int
BoundsError: Index 10 out of bounds for array of length 5 (valid range: 0..5)
FormatError: Invalid date format: 'abc'. Expected: YYYY-MM-DD (example: '2025-10-05')
```
