# Fix for Bug 010: Mutable Type Fields

**Status**: ✅ FIXED
**Fixed**: 2025-10-05
**Files Modified**: `src/main.rs`

## Problem

Mutations to struct fields inside instance methods didn't persist when:
1. The mutation occurred inside control flow blocks (if/elif/else, while, for)
2. The method returned a non-nil value

## Root Cause

Control flow statements (if/elif/else, while, for) create subscopes for their blocks. When `self.field = value` was executed inside these blocks, it updated `self` in the child scope. When the scope was popped, the mutations were lost.

## Solution

Modified all control flow statements to propagate `self` mutations back to the parent scope:

### Changes in `src/main.rs`

**1. if/elif/else statements** (lines 1174-1180, 1196-1202, 1212-1218):
```rust
// Propagate self mutations back to parent scope
if let Some(updated_self) = scope.get("self") {
    scope.pop();
    scope.set("self", updated_self);
} else {
    scope.pop();
}
```

**2. while loops** (lines 1413-1418):
Same pattern applied after each loop iteration.

**3. for loops** (lines 1363-1369):
Same pattern applied after loop completes.

**4. Method calls** (lines 2108-2114):
Already updated to always propagate struct changes (removed nil-return check).

## Test Coverage

Added regression test: `test/regression/bug_010_test.q`

Tests cover:
- Simple field mutations
- Multiple mutations across calls
- Multiple instance independence
- Mutations in methods that return values
- Mutations with compound assignment operators
- Mutations inside if/else blocks (the critical case)

All tests pass ✅

## Impact

This fix enables:
- Parsers with position tracking
- Iterators with state
- State machines
- Any algorithm requiring mutable instance fields

This is essential OOP functionality now working correctly.
