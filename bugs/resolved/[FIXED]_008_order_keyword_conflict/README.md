# Bug #008: "order" Keyword Conflict in Member Access

## Issue

Using "order" as a variable/field name works fine UNTIL you try to access its members. The parser incorrectly tokenizes `order.method()` as `or` + `der.method()`.

## Current Behavior

```quest
# Declaration and assignment work fine
let order = []              # ✓ WORKS
let order = "test"          # ✓ WORKS
puts(order)                 # ✓ WORKS

# Member access FAILS
order.push("item")          # ✗ ERROR: Undefined variable: der
order.len()                 # ✗ ERROR: Undefined variable: der

# Field access also fails
type MyType
    array: order
end

let obj = MyType.new(order: [])  # ✓ WORKS
obj.order.push("item")           # ✗ ERROR: Undefined variable: der
```

**Error:** `Undefined variable: der`

The parser tokenizes `order.` as `or` + `der.` when followed by member access.

## Expected Behavior

`order.method()` should be parsed as:
- `order` (identifier)
- `.` (dot operator)
- `method()` (method call)

Not as:
- `or` (keyword)
- `der.method()` (member access on undefined variable)

## Root Cause

**Member access parsing issue with keyword-prefix identifiers.**

The problem occurs when:
1. An identifier starts with a keyword (`order` starts with `or`)
2. It's immediately followed by a dot (`.`)
3. The parser is processing member access

**What works:**
- ✅ `let order = value` - Declaration works (identifier rule correctly matches)
- ✅ `puts(order)` - Simple reference works
- ✅ `fun f(order)` - Parameter works
- ✅ `"text" .. order` - Expression works

**What fails:**
- ❌ `order.method()` - Member access fails (tokenized as `or` + `der.method()`)
- ❌ `self.order.method()` - Nested access fails (same issue)

**Why it happens:**
The parser likely has a lookahead or tokenization issue specifically in the postfix/member-access rule where it's re-tokenizing `order.` and splitting it at the keyword boundary instead of respecting the identifier that was already parsed.

## Impact

- **Severity**: Medium
- **Scope**: Only affects identifiers starting with `or` when used in member access
- **Workaround**: Use different names (e.g., `events`, `sequence`, `items`, `ordering`)
- **Tested - Other keywords work fine**:
  - ✅ `android.method()` - WORKS (doesn't conflict with `and`)
  - ✅ `nothing.method()` - WORKS (doesn't conflict with `not`)
  - ✅ `formula.method()` - WORKS (doesn't conflict with `for`)
  - ✅ `ordering.method()` - WORKS (even though it starts with `or`)
  - ❌ `order.method()` - FAILS (specific to exact keyword match)

## Reproduction

```quest
# Minimal test case
let order = []
order.push("item")  # ERROR: Undefined variable: der

# Also fails in types
type Test
    array: order

    fun test()
        self.order.push("x")  # ERROR: Undefined variable: der
    end
end
```

**Interesting:** This works fine:
```quest
let ordering = []
ordering.push("item")  # ✓ WORKS

let order = "value"
puts(order)  # ✓ WORKS (no member access)
```

## Related Code

- Lexer/tokenizer in src/quest.pest
- Identifier parsing rules
- Keyword matching logic

## Workaround

Avoid using exactly `order` as a variable/field name when member access is needed:
- ✅ Use `events`, `sequence`, `items`, `ordering` (note: `ordering` works!)
- ❌ Avoid `order` specifically when calling methods on it
- ✅ Other keyword-prefixed names work fine (`android`, `nothing`, `formula`)

## Status

**FIXED** - 2025-10-05

See `fix.md` for implementation details.

## Test Case

Created `/tmp/test_order_field.q` demonstrating the issue.

## Fix Strategy

The issue is NOT in the keyword rule (which already has word boundaries: `~ !(ASCII_ALPHANUMERIC | "_")`).

The bug is likely in the **postfix/member access parsing** where the parser is re-tokenizing or doing lookahead.

Possible locations:
1. **Postfix rule** in quest.pest - Check how member access is parsed
2. **Identifier lookahead** - Parser might be splitting `order.` before checking identifier rule
3. **Expression context** - Member access might not properly respect identifier boundaries

**Debug approach:**
1. Add debug output to postfix parsing
2. Check if Pest is correctly matching `order` as identifier before seeing `.`
3. Investigate why `ordering.method()` works but `order.method()` doesn't

**Quick fix:** Since the keyword rule already has word boundaries and other tests show `android`, `nothing` work fine, this might be a very specific edge case with the exact string "order" + dot. May need to trace through Pest's parsing of this specific combination.

## Notes

Discovered while implementing QEP-011 Phase 3 tests. Using "order" as a field name caused tests to fail with cryptic error messages.
