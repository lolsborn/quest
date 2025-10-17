# QEP-058: Match Statement Range Patterns

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-17
**Related:** QEP-016 (Match Statement)

## Abstract

Extend Quest's `match` statement to support range patterns using the existing `to`/`until`/`step` syntax from `for` loops. This enables elegant range-based matching without verbose conditional chains.

## Rationale

Quest currently supports `match` for equality checking only:

```quest
fun describe_age(age)
    match age
    in 7
        "child"
    in 15
        "teenager"
    in 45
        "adult"
    else
        "unknown"
    end
end
```

**Problems:**
1. Can't express range conditions (e.g., "between 0 and 12")
2. Must fall back to verbose `if/elif/else` chains for ranges
3. Inconsistent with Quest's ergonomic `for i in 0 to 10` range syntax

**Solution:** Extend `match` to support range patterns using the same `to`/`until`/`step` syntax already familiar to Quest developers.

## Proposed Syntax

### Basic Range Matching

```quest
fun describe_age(age)
    match age
    in 0 to 12
        "child"
    in 13 to 19
        "teenager"
    in 20 to 64
        "adult"
    else
        "senior"
    end
end

puts(describe_age(7))   # => "child"
puts(describe_age(15))  # => "teenager"
puts(describe_age(45))  # => "adult"
puts(describe_age(70))  # => "senior"
```

### Inclusive vs Exclusive Ranges

**`to` is inclusive** (matches endpoints):
```quest
match score
in 0 to 59
    "F"
in 60 to 69
    "D"
in 70 to 79
    "C"
in 80 to 89
    "B"
in 90 to 100
    "A"
end
```

**`until` is exclusive** (doesn't match upper bound):
```quest
match hour
in 0 until 6
    "night"       # 0-5
in 6 until 12
    "morning"     # 6-11
in 12 until 18
    "afternoon"   # 12-17
in 18 until 24
    "evening"     # 18-23
end
```

### Step Patterns

Match values at specific intervals:

```quest
fun describe_number(n)
    match n
    in 0 to 100 step 2
        "even (0-100)"
    in 1 to 100 step 2
        "odd (0-100)"
    else
        "out of range"
    end
end

describe_number(42)  # => "even (0-100)"
describe_number(17)  # => "odd (0-100)"
describe_number(101) # => "out of range"
```

### Negative Ranges

```quest
match temperature
in -10 to -1
    "below freezing"
in 0 to 10
    "cold"
in 11 to 25
    "comfortable"
else
    "hot"
end
```

### Mixed Patterns

Combine ranges with discrete values in separate arms:

```quest
match status_code
in 200, 201, 204
    "success"
in 300 to 399
    "redirect"
in 400 to 499
    "client error"
in 500 to 599
    "server error"
else
    "unknown"
end
```

**Note:** Ranges and discrete values must be in **separate match arms**. Mixing them in a single pattern is not supported:

```quest
# ❌ NOT ALLOWED - mixing range and values in one arm
in 200, 201, 204, 300 to 399
    "success or redirect"

# ✅ ALLOWED - separate arms
in 200, 201, 204
    "success"
in 300 to 399
    "redirect"
```

## Semantics

### Matching Behavior

1. **First match wins** - Evaluation stops at first matching pattern
2. **Range endpoints** - `to` includes both bounds, `until` excludes upper bound
3. **Type checking** - Ranges only work with numeric types (Int, Float, Decimal, BigInt)
4. **Type promotion** - Follows Quest's arithmetic promotion rules (Int promoted to Float when comparing against Float ranges)
5. **Ascending ranges only** - Range start must be <= end (descending ranges not supported)
6. **Step validation** - Step must be non-zero and positive
7. **Step restrictions** - Step patterns only allowed with Int and BigInt (not Float or Decimal)
8. **Order matters** - More specific patterns should come before general ones

### Range Evaluation

**Basic range matching:**

For pattern `in start to end`:
- Check if `value >= start` and `value <= end`

For pattern `in start until end`:
- Check if `value >= start` and `value < end`

**With step (Int/BigInt only):**

For pattern `in start to end step s`:
- Check if `value >= start` and `value <= end`
- Check if `(value - start) % step == 0`
- Step must be positive and non-zero

For pattern `in start until end step s`:
- Check if `value >= start` and `value < end`
- Check if `(value - start) % step == 0`
- Step must be positive and non-zero

**Range validation:**
- Start must be <= end (empty ranges where start > end never match)
- For `until`: If start == end, range is empty and never matches

### Type Compatibility

**Numeric types supported:**

```quest
# ✅ Works with all numeric types
match 42        in 0 to 100    ... end  # Int
match 3.14      in 0.0 to 10.0 ... end  # Float
match 999999n   in 0n to 1000000n ... end  # BigInt
match dec       in Decimal.zero() to Decimal.new("100") ... end  # Decimal

# ❌ Type error - ranges require numeric types
match "hello"   in 0 to 100    ... end  # Error: Cannot match str against numeric range
match true      in 0 to 1      ... end  # Error: Cannot match bool against numeric range
```

**Type promotion (follows Quest's arithmetic rules):**

```quest
# ✅ Int promoted to Float for comparison
match 42        in 0.0 to 100.0
    "matches"   # Int 42 promoted to Float 42.0
end

# ✅ Float compared against Int range
match 3.14      in 0 to 10
    "matches"   # Int bounds promoted to Float for comparison
end

# ❌ Type error - BigInt and Int/Float don't auto-promote
match 42n       in 0 to 100
    "no match"  # Error: Cannot compare BigInt with Int range
end
```

**Step pattern restrictions:**

```quest
# ✅ Step allowed with Int and BigInt
match 42        in 0 to 100 step 2      # OK
match 42n       in 0n to 100n step 2n   # OK

# ❌ Step not allowed with Float or Decimal (precision issues)
match 0.3       in 0.0 to 1.0 step 0.1  # Error: Step patterns not supported for Float
match dec       in d1 to d2 step d_step # Error: Step patterns not supported for Decimal
```

### Edge Cases

**Overlapping ranges** (first match wins):
```quest
match 50
in 0 to 100
    "first"      # This matches
in 25 to 75
    "second"     # Never reached
end
# => "first"
```

**Empty ranges** (never match):
```quest
match 5
in 10 to 1       # Empty range (start > end) - never matches
    "never"
else
    "always"
end
# => "always"

match 5
in 10 until 10   # Empty range (start == end with until) - never matches
    "never"
end
# => nil (no match, no else)
```

**Single-value ranges**:
```quest
match 5
in 5 to 5        # Single value range (start == end with to)
    "exactly five"
end
# Equivalent to: in 5

match 5
in 5 until 6     # Also matches only 5 (until excludes 6)
    "exactly five"
end
```

## Error Messages

The following error messages should be raised for invalid range patterns:

```quest
# Non-numeric value
match "hello" in 0 to 10 ... end
# => TypeErr: Cannot match str against numeric range

# Non-numeric range bounds
match 42 in "a" to "z" ... end
# => TypeErr: Range bounds must be numeric (got str)

# Zero step
match 42 in 0 to 100 step 0 ... end
# => ValueErr: Step cannot be zero

# Negative step
match 42 in 0 to 100 step -2 ... end
# => ValueErr: Step must be positive (descending ranges not supported)

# Step with Float
match 0.5 in 0.0 to 1.0 step 0.1 ... end
# => TypeErr: Step patterns only supported for Int and BigInt (not Float)

# Step with Decimal
match d in d1 to d2 step d_step ... end
# => TypeErr: Step patterns only supported for Int and BigInt (not Decimal)

# BigInt with Int range
match 42n in 0 to 100 ... end
# => TypeErr: Cannot compare BigInt with Int range (no auto-promotion)
```

## Non-Goals

This QEP explicitly does **not** include:

1. **Descending ranges** - `in 100 to 0 step -1` not supported (may be added in future QEP)
2. **Pattern guards** - `in 0 to 100 if x % 2 == 0` deferred to future enhancement
3. **Variable binding** - `in 0 to 100 as range` deferred to future enhancement
4. **Mixed patterns in single arm** - `in 1, 2, 3, 10 to 20` not allowed (use separate arms)
5. **Non-numeric ranges** - String ranges (`"a" to "z"`), date ranges out of scope
6. **Step with Float/Decimal** - Avoided due to floating point precision issues

## Implementation Strategy

### Phase 1: Grammar Extension

Extend `src/quest.pest`:

```pest
match_arm = {
    "in" ~ match_pattern ~ NEWLINE* ~ match_arm_body
}

match_pattern = {
    range_pattern |
    value_list
}

range_pattern = {
    expr ~ ("to" | "until") ~ expr ~ ("step" ~ expr)?
}

value_list = {
    expr ~ ("," ~ expr)*
}
```

**Grammar precedence:** The parser checks for `range_pattern` first (looks for `to`/`until` keywords), then falls back to `value_list`. This makes the grammar unambiguous.

### Phase 2: Range Matching Logic

In `src/main.rs`, extend match statement evaluation:

```rust
fn eval_match_arm(value: &QValue, pattern: Pair<Rule>, scope: &Scope) -> Result<bool, String> {
    match pattern.as_rule() {
        Rule::range_pattern => {
            eval_range_match(value, pattern, scope)
        }
        Rule::value_list => {
            // Existing equality matching
            eval_value_list_match(value, pattern, scope)
        }
        _ => Err("Invalid match pattern".to_string())
    }
}

fn eval_range_match(value: &QValue, pattern: Pair<Rule>, scope: &Scope) -> Result<bool, String> {
    // Extract start, end, step, and range_type (to/until)
    // Convert value to numeric
    // Check if value falls within range
    // If step provided, check if (value - start) % step == 0
}
```

### Phase 3: Type Checking and Validation

Add type validation and range checks:

```rust
fn validate_range_pattern(
    value: &QValue,
    start: &QValue,
    end: &QValue,
    step: Option<&QValue>,
    range_type: RangeType  // Enum: Inclusive or Exclusive
) -> Result<(), String> {
    // 1. Check value is numeric
    if !value.is_numeric() {
        return Err(format!("Cannot match {} against numeric range", value.q_type()));
    }

    // 2. Check bounds are numeric
    if !start.is_numeric() || !end.is_numeric() {
        return Err("Range bounds must be numeric".to_string());
    }

    // 3. Validate step if provided
    if let Some(s) = step {
        // Step must be Int or BigInt
        if !matches!(s, QValue::Int(_) | QValue::BigInt(_)) {
            return Err(format!("Step patterns only supported for Int and BigInt (not {})", s.q_type()));
        }

        // Step must be non-zero
        if s.is_zero() {
            return Err("Step cannot be zero".to_string());
        }

        // Step must be positive (no descending ranges)
        if s.is_negative() {
            return Err("Step must be positive (descending ranges not supported)".to_string());
        }

        // Value and bounds must also be Int or BigInt
        if !matches!(value, QValue::Int(_) | QValue::BigInt(_)) ||
           !matches!(start, QValue::Int(_) | QValue::BigInt(_)) ||
           !matches!(end, QValue::Int(_) | QValue::BigInt(_)) {
            return Err("Step patterns require Int or BigInt types".to_string());
        }
    }

    // 4. Type compatibility (with promotion)
    validate_type_promotion(value, start, end)?;

    Ok(())
}

fn validate_type_promotion(value: &QValue, start: &QValue, end: &QValue) -> Result<(), String> {
    // Int <-> Float promotion allowed (follows arithmetic rules)
    // BigInt requires exact match (no auto-promotion)
    // Decimal requires exact match (no auto-promotion)

    match (value, start, end) {
        (QValue::BigInt(_), QValue::Int(_), _) |
        (QValue::BigInt(_), _, QValue::Int(_)) |
        (QValue::Int(_), QValue::BigInt(_), _) |
        (QValue::Int(_), _, QValue::BigInt(_)) => {
            Err("Cannot compare BigInt with Int range (no auto-promotion)".to_string())
        }
        _ => Ok(())
    }
}
```

## Test Cases

```quest
use "std/test"

test.module("Match Range Patterns (QEP-058)")

test.describe("Basic range matching", fun ()
    test.it("matches inclusive ranges with 'to'", fun ()
        fun check(n)
            match n
            in 0 to 10
                "low"
            in 11 to 20
                "high"
            else
                "other"
            end
        end

        test.assert_eq(check(0), "low")
        test.assert_eq(check(5), "low")
        test.assert_eq(check(10), "low")
        test.assert_eq(check(11), "high")
        test.assert_eq(check(20), "high")
        test.assert_eq(check(21), "other")
    end)

    test.it("matches exclusive ranges with 'until'", fun ()
        fun check(n)
            match n
            in 0 until 10
                "low"
            in 10 until 20
                "high"
            end
        end

        test.assert_eq(check(0), "low")
        test.assert_eq(check(9), "low")
        test.assert_eq(check(10), "high")
        test.assert_eq(check(19), "high")
        test.assert_eq(check(20), nil)
    end)
end)

test.describe("Step patterns", fun ()
    test.it("matches even numbers with step", fun ()
        fun check(n)
            match n
            in 0 to 100 step 2
                "even"
            in 1 to 100 step 2
                "odd"
            else
                "other"
            end
        end

        test.assert_eq(check(0), "even")
        test.assert_eq(check(42), "even")
        test.assert_eq(check(1), "odd")
        test.assert_eq(check(17), "odd")
        test.assert_eq(check(101), "other")
    end)
end)

test.describe("Negative ranges", fun ()
    test.it("matches negative numbers", fun ()
        fun check(temp)
            match temp
            in -10 to -1
                "below freezing"
            in 0 to 10
                "cold"
            else
                "other"
            end
        end

        test.assert_eq(check(-5), "below freezing")
        test.assert_eq(check(5), "cold")
    end)
end)

test.describe("Mixed patterns", fun ()
    test.it("combines ranges and discrete values", fun ()
        fun check(code)
            match code
            in 200, 201, 204
                "success"
            in 400 to 499
                "client error"
            in 500 to 599
                "server error"
            else
                "other"
            end
        end

        test.assert_eq(check(200), "success")
        test.assert_eq(check(404), "client error")
        test.assert_eq(check(500), "server error")
    end)
end)

test.describe("Type safety", fun ()
    test.it("works with Float", fun ()
        fun check(x)
            match x
            in 0.0 to 1.0
                "unit"
            else
                "other"
            end
        end

        test.assert_eq(check(0.5), "unit")
    end)

    test.it("promotes Int to Float for comparison", fun ()
        fun check(x)
            match x
            in 0.0 to 100.0
                "matches"
            else
                "other"
            end
        end

        test.assert_eq(check(42), "matches")  # Int 42 promoted to Float
    end)

    test.it("raises error for non-numeric types", fun ()
        fun check(x)
            match x
            in 0 to 10
                "number"
            end
        end

        test.assert_raises(TypeErr, fun () check("hello") end)
    end)

    test.it("rejects step with Float", fun ()
        fun check(x)
            match x
            in 0.0 to 1.0 step 0.1
                "matches"
            end
        end

        test.assert_raises(TypeErr, fun () check(0.5) end)
    end)
end)

test.describe("Edge cases", fun ()
    test.it("handles single-value ranges", fun ()
        fun check(n)
            match n
            in 5 to 5
                "five"
            end
        end

        test.assert_eq(check(5), "five")
        test.assert_eq(check(4), nil)
    end)

    test.it("handles empty ranges (start > end)", fun ()
        fun check(n)
            match n
            in 10 to 1
                "never"
            else
                "always"
            end
        end

        test.assert_eq(check(5), "always")
    end)

    test.it("handles empty 'until' ranges (start == end)", fun ()
        fun check(n)
            match n
            in 10 until 10
                "never"
            else
                "always"
            end
        end

        test.assert_eq(check(10), "always")
    end)

    test.it("first match wins for overlapping ranges", fun ()
        fun check(n)
            match n
            in 0 to 100
                "first"
            in 25 to 75
                "second"
            end
        end

        test.assert_eq(check(50), "first")
    end)

    test.it("rejects zero step", fun ()
        fun check(n)
            match n
            in 0 to 100 step 0
                "never"
            end
        end

        test.assert_raises(ValueErr, fun () check(50) end)
    end)

    test.it("rejects negative step", fun ()
        fun check(n)
            match n
            in 0 to 100 step -2
                "never"
            end
        end

        test.assert_raises(ValueErr, fun () check(50) end)
    end)
end)
```

## Benefits

1. **Ergonomic** - Natural syntax consistent with `for` loops
2. **Readable** - `in 0 to 12` is clearer than `>= 0 and <= 12`
3. **Familiar** - Reuses existing language constructs
4. **Powerful** - Combines ranges with discrete values and steps
5. **Type-safe** - Runtime validation prevents misuse

## Comparison with Other Languages

### Ruby
```ruby
case age
when 0..12 then "child"
when 13..19 then "teenager"
else "adult"
end
```

### Python
```python
# No direct syntax - uses if/elif
if 0 <= age <= 12:
    return "child"
elif 13 <= age <= 19:
    return "teenager"
```

### Rust
```rust
match age {
    0..=12 => "child",
    13..=19 => "teenager",
    _ => "adult"
}
```

### Quest (Proposed)
```quest
match age
in 0 to 12
    "child"
in 13 to 19
    "teenager"
else
    "adult"
end
```

Quest's syntax is most similar to Ruby, but uses keywords (`to`/`until`) instead of operators (`..`/`...`) for clarity.

## Backwards Compatibility

✅ **Fully backwards compatible** - Existing `match` statements continue to work unchanged. Range patterns are purely additive.

## Performance Considerations

**Range matching complexity:**
- Basic range check: O(1) - simple numeric comparisons
- Step validation: O(1) - single modulo operation
- Type promotion: O(1) - follows Quest's existing arithmetic conversion

**Large BigInt ranges with step:**
```quest
# Performance note: Step validation with very large BigInt ranges
# requires modulo operation, which can be expensive for huge numbers
match value
in 0n to 1000000000000000000n step 1n
    # This performs one modulo operation: (value - 0n) % 1n
    # Still O(1) but with larger constant factor for BigInt
end
```

**Recommendation:** For very large BigInt ranges with small steps, consider whether step validation is actually needed for your use case.

## Migration Guide

**Converting if/elif chains to match ranges:**

```quest
# Before: Verbose if/elif chain
fun grade(score)
    if score >= 90 and score <= 100
        "A"
    elif score >= 80 and score < 90
        "B"
    elif score >= 70 and score < 80
        "C"
    elif score >= 60 and score < 70
        "D"
    else
        "F"
    end
end

# After: Clean match statement
fun grade(score)
    match score
    in 90 to 100
        "A"
    in 80 until 90
        "B"
    in 70 until 80
        "C"
    in 60 until 70
        "D"
    else
        "F"
    end
end
```

**No breaking changes:** Existing `match` statements continue to work unchanged.

## Future Enhancements

Potential additions for future QEPs:

1. **Descending ranges** - `in 100 to 0 step -1` (requires negative step support)
2. **Pattern guards** - `in 0 to 100 if x % 2 == 0` (conditional matching)
3. **Variable binding** - `in min to max as range` (capture matched range)
4. **Multiple ranges in single arm** - `in (0 to 10, 20 to 30)` (match either range)
5. **String ranges** - `in "a" to "z"` (character/lexicographic ranges)
6. **Step with Float/Decimal** - Requires careful epsilon-based comparison design

## References

- QEP-016: Match Statement (original implementation)
- Quest for loops: [test/loops/for_test.q](../test/loops/for_test.q)
- Ruby case/when ranges: https://ruby-doc.org/core/Range.html
- Rust match ranges: https://doc.rust-lang.org/book/ch18-03-pattern-syntax.html#matching-ranges-of-values
