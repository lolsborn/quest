# Bug #017: Optional Typed Fields Reject Explicit Nil Values

**Status:** Open
**Severity:** High
**Discovered:** 2025-10-06
**Related:** QEP-032, QEP-015 (Type Annotations)

## Summary

Optional typed fields (e.g., `field: str?`) reject explicit `nil` values even though the `?` marker should allow nil. The type checker validates the type before checking the optional flag, causing "Type mismatch: expected str, got Nil" errors.

## Reproduction

```quest
type Person
    name: str
    email: str?  # Should allow str or nil
end

# This fails with "Type mismatch: expected str, got Nil"
let p = Person.new(
    name: "Alice",
    email: nil  # Should be valid but is rejected
)
```

## Expected Behavior

According to QEP-032 (line 246-260), optional fields marked with `?` should accept:
1. Values of the specified type (e.g., `str`)
2. Explicit `nil` values
3. Can be omitted if a default value is provided

## Actual Behavior

- Passing explicit `nil` to `str?` field: **FAILS** with type mismatch error
- Omitting the field (if default provided): **Works**
- Passing valid string: **Works**

## Root Cause

The type checker likely performs these steps:
1. Check if provided value matches field type
2. If mismatch, then check if field is optional

This order is wrong. It should be:
1. Check if field is optional and value is nil → **ALLOW**
2. Otherwise, check if value matches field type

## Current Workaround

Use untyped fields with default nil:
```quest
type Person
    name: str
    email = nil  # Untyped, defaults to nil
end

let p = Person.new(
    name: "Alice",
    email: nil  # Now works
)
```

## Impact

- **High:** Affects all type definitions with optional fields
- Forces developers to use untyped fields, losing type safety
- Inconsistent with QEP-032 specification
- Makes it impossible to properly type optional fields

## Files Affected

During QEP-032 implementation, this affected:
- `lib/std/log.q` - Lines 438, 711, 714 (had to remove types)
- Any type with optional fields requiring explicit nil

## Test Case

```quest
# Test: Optional fields should accept nil
type Test
    required: str
    optional_int: int? = nil
    optional_str: str? = nil
end

# Should all succeed:
let t1 = Test.new(required: "hello")
let t2 = Test.new(required: "hello", optional_int: nil)
let t3 = Test.new(required: "hello", optional_str: nil)
let t4 = Test.new(required: "hello", optional_int: 42, optional_str: "world")
```

## Suggested Fix

In the type checker (likely in `src/main.rs` where type validation occurs):

```rust
// When validating field assignment
fn validate_field_value(field_type: &TypeExpr, field_optional: bool, value: &QValue) -> Result<()> {
    // IMPORTANT: Check optional+nil FIRST
    if field_optional && matches!(value, QValue::Nil) {
        return Ok(()); // nil is always valid for optional fields
    }

    // Then check type compatibility
    if !value.matches_type(field_type) {
        return Err(format!("Type mismatch: expected {}, got {}", field_type, value.q_type()));
    }

    Ok(())
}
```

## Related Issues

- QEP-015: Type annotations (function parameters might have same issue)
- QEP-032: Struct field syntax consistency

## Priority

**High** - This blocks proper use of typed optional fields throughout the codebase and violates the QEP-032 specification.
