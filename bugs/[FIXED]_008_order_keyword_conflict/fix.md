# Fix for Bug #008: "order" Keyword Conflict

## Date Fixed
2025-10-05

## Root Cause Identified

The bug was in the **logical operator rules** in `src/quest.pest`:

```pest
# BEFORE (broken):
logical_or = { logical_and ~ ("or" ~ logical_and)* }
logical_and = { logical_not ~ ("and" ~ logical_not)* }
logical_not = { "not" ~ logical_not | bitwise_or }
```

The bare string `"or"` in the `logical_or` rule would match the "or" inside "order", treating "order.method()" as `or` + `der.method()`.

## The Fix

Added word boundaries to logical operator keywords:

```pest
# AFTER (fixed):
logical_or = { logical_and ~ (or_op ~ logical_and)* }
logical_and = { logical_not ~ (and_op ~ logical_not)* }
logical_not = { not_op ~ logical_not | bitwise_or }

// Operator keywords with word boundaries (prevent matching inside identifiers)
or_op = @{ "or" ~ !(ASCII_ALPHANUMERIC | "_") }
and_op = @{ "and" ~ !(ASCII_ALPHANUMERIC | "_") }
not_op = @{ "not" ~ !(ASCII_ALPHANUMERIC | "_") }
```

This ensures `or`, `and`, and `not` only match as standalone keywords, not as prefixes within identifiers.

## Changes Made

**File**: `src/quest.pest`
**Lines**: 199-206

## Verification

All of these now work correctly:

```quest
# Variable named "order"
let order = []
order.push(1)
puts(order.len())  # ✓ WORKS

# Field named "order"
type MyType
    array: order
end

let obj = MyType.new(order: [])
obj.order.push("item")  # ✓ WORKS

# Method accessing self.order
type Container
    array: order

    fun add(item)
        self.order.push(item)  # ✓ WORKS
    end
end

# Other identifiers also work
let android = []    # ✓ WORKS
let nothing = []    # ✓ WORKS
let ordering = []   # ✓ WORKS
```

## Testing

Tested with:
1. `/tmp/comprehensive_order_test.q` - All tests pass
2. `bugs/008_order_keyword_conflict/example.q` - Tests 1 and 2 now pass
3. Logical operators still work: `a or b`, `a and b`, `not a`

## Side Effects

None detected. The fix:
- ✅ Allows `order`, `android`, `nothing` as identifiers
- ✅ Preserves logical operator functionality
- ✅ No performance impact
- ✅ More consistent with keyword handling elsewhere in grammar

## Conclusion

Bug #008 is **FIXED**. Users can now use `order` as a variable/field name without issues.
