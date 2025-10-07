# Fix: For Loop Per-Iteration Scoping

**Status**: ✅ **FIXED**
**Fixed Date**: 2025-10-07
**Files Modified**: `src/main.rs`

## Summary

Fixed for loops to create a fresh scope for each iteration, matching the behavior of while loops and other languages (Python, Ruby, JavaScript). Variables declared with `let` inside a for loop body are now properly scoped to that iteration only.

## Changes Made

### src/main.rs - Three Locations

**1. Array Iteration (lines ~1485-1527)**
- Moved `scope.push()` from before the loop to inside each iteration
- Added `scope.pop()` at the end of each iteration
- Added self mutation propagation after each iteration
- Added proper scope cleanup on break/continue

**2. Dict Iteration (lines ~1536-1578)**
- Same changes as array iteration
- Ensures fresh scope per key-value pair

**3. Range Iteration (lines ~1607-1652)**
- Moved `scope.push()` from before loop to inside each iteration
- Added `scope.pop()` at end of each iteration
- Self mutation propagation preserved
- Proper cleanup on break/continue

## Before (Broken)

```rust
// Array iteration - WRONG
scope.push();  // ← Once before loop
for (index, item) in elements.iter().enumerate() {
    scope.set(&first_var, item.clone());
    // Execute statements - can't use 'let' twice!
}
scope.pop();  // ← Once after loop
```

## After (Fixed)

```rust
// Array iteration - CORRECT
for (index, item) in elements.iter().enumerate() {
    scope.push();  // ← Fresh scope each iteration
    scope.set(&first_var, item.clone());
    // Execute statements - 'let' works every time!

    // Propagate self mutations
    if let Some(updated_self) = scope.get("self") {
        scope.pop();
        scope.set("self", updated_self);
    } else {
        scope.pop();
    }
}
```

## Test Results

### Bug Example (example.q)
```
Before: NameErr: Variable 'doubled' already declared in this scope
After:  Prints 2, 4, 6 correctly ✅
```

### Comprehensive Tests (test/loops/for_scope_test.q)
All 9 tests pass:
- ✅ Basic let declarations in loop body
- ✅ Multiple let declarations per iteration
- ✅ Variable shadowing
- ✅ Range loops with let
- ✅ Dict iteration with let
- ✅ Break with per-iteration scope
- ✅ Continue with per-iteration scope
- ✅ Nested loops with let
- ✅ Self mutations propagate correctly

### Full Test Suite
All existing tests pass - no regressions ✅

## Behavior Change

**Before:** Variables declared with `let` in for loop body persisted across iterations

**After:** Each iteration gets a fresh scope (like while loops)

## Code Examples Now Working

```quest
# Example 1: Basic let in loop
for i in [1, 2, 3]
    let doubled = i * 2  # ✅ Now works!
    puts(doubled)
end

# Example 2: Multiple variables
for item in items
    let price = item.base_price
    let tax = price * 0.08
    let total = price + tax
    puts(total)
end

# Example 3: Variable shadowing
let x = 100
for i in [1, 2, 3]
    let x = i * 10  # ✅ Shadows outer x
    puts(x)
end
puts(x)  # Still 100

# Example 4: Range iteration
for i in 1 to 10
    let squared = i * i
    puts(squared)
end

# Example 5: Self mutations still work
for i in [1, 2, 3]
    let amount = i
    counter.add(amount)  # Mutations propagate correctly
end
```

## Implementation Details

### Self Mutation Propagation

The fix preserves Quest's existing behavior where mutations to `self` inside type methods are propagated back to the parent scope:

```rust
// After each iteration
if let Some(updated_self) = scope.get("self") {
    scope.pop();
    scope.set("self", updated_self);
} else {
    scope.pop();
}
```

### Break/Continue Handling

Break and continue statements properly clean up the iteration scope before exiting:

```rust
Err(e) if e == "__LOOP_BREAK__" => {
    // Propagate self mutations before breaking
    if let Some(updated_self) = scope.get("self") {
        scope.pop();
        scope.set("self", updated_self);
    } else {
        scope.pop();
    }
    break 'outer;
}
```

## Consistency

This change makes for loops consistent with:

1. **While loops** (which already had per-iteration scoping)
2. **Other languages** (Python, Ruby, JavaScript all have fresh scope per iteration)
3. **User expectations** (most developers expect this behavior)

## Workarounds No Longer Needed

The varargs test file used while loops to work around this bug. After this fix, code can use the more natural for loop syntax:

```quest
# Before (workaround)
let i = 0
while i < numbers.len()
    total = total + numbers[i]
    i = i + 1
end

# After (idiomatic)
for num in numbers
    total = total + num
end
```

## Migration

**No breaking changes.** Existing code continues to work:
- Code that used assignment instead of `let` - still works
- Code that used while loops - still works
- Code that avoided temporaries - still works

The fix only enables new patterns that were previously broken.

## Performance Impact

**Minimal overhead:** Each iteration now pushes/pops one scope level. Quest's scope system uses `Rc<RefCell<HashMap>>` which makes push/pop very cheap (just vec operations).

## Related Issues

- While loops already had per-iteration scoping (correct)
- If/elif/else blocks create fresh scopes (correct)
- This fix brings for loops in line with the rest of Quest's scope semantics

## Files

- `src/main.rs` (lines 1476-1655) - For loop implementation
- `test/loops/for_scope_test.q` - New comprehensive tests (9 tests)
- `bugs/resolved/[FIXED]_018_for_loop_scope_sharing/` - Bug report and fix docs
