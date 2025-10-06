# Solution: Bug 005 - Literal Keyword Prefix Identifiers

## Problem
The `boolean` and `nil` rules in the Pest grammar lacked word boundary checks, causing the parser to match these literals even when they appeared as prefixes of longer identifiers. This resulted in parse errors for valid identifiers like `nilable`, `truely`, and `falsey`.

## Root Cause
In `src/quest.pest`, the literal keyword rules were defined as:
```pest
boolean = { "true" | "false" }
nil = { "nil" }
```

Unlike control flow keywords (which use `keyword` rule with word boundary checks), these literal rules would match partial strings. For example, when parsing `nilable`, the parser would match `nil` and then fail to parse `able` as a continuation.

## Solution
Added word boundary checks to both rules using the atomic modifier (`@`) and negative lookahead for alphanumeric characters or underscores:

```pest
boolean = @{ ("true" | "false") ~ !(ASCII_ALPHANUMERIC | "_") }
nil = @{ "nil" ~ !(ASCII_ALPHANUMERIC | "_") }
```

This ensures that:
- `nil` only matches when NOT followed by alphanumeric or underscore
- `true` and `false` only match when NOT followed by alphanumeric or underscore
- Identifiers like `nilable`, `truely`, `falsey` are now parsed as complete identifiers

The pattern `~ !(ASCII_ALPHANUMERIC | "_")` is consistent with how the `keyword` rule handles word boundaries (lines 246-252).

## Files Changed
- `src/quest.pest` (lines 301-302)

## Verification
- Original test case: `bugs/005_literal_keyword_prefix_identifiers/test.q` now runs successfully
- Regression test added: `test/regression/bug_005_test.q` (5 tests, all passing)

## Status
✅ Fixed and tested
