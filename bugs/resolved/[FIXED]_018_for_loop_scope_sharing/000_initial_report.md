# Bug: For Loops Share Scope Across Iterations

**Status**: 🔴 OPEN - MEDIUM PRIORITY

**Reported**: 2025-10-07

**Severity**: MEDIUM - Prevents using `let` declarations in for loop bodies

## Summary

For loops in Quest don't create a new scope for each iteration. Variables declared with `let` inside a for loop body persist across iterations, causing "Variable already declared" errors on the second iteration.

This is inconsistent with while loops (which work correctly) and standard behavior in Python, Ruby, JavaScript, etc.

## Minimal Reproduction

```quest
# This fails with "Variable 'doubled' already declared"
for i in [1, 2, 3]
    let doubled = i * 2  # ❌ Error on 2nd iteration
    puts(doubled)
end
```

**Error:**
```
NameErr: Variable 'doubled' already declared in this scope
```

## Expected Behavior

Each iteration should have a fresh scope (like while loops):

```quest
for i in [1, 2, 3]
    let doubled = i * 2  # ✅ Should work
    puts(doubled)
end

# Output:
# 2
# 4
# 6
```

## Comparison with While Loops

While loops work correctly because they create a new scope per iteration:

```quest
# This works fine!
let items = [1, 2, 3]
let idx = 0
while idx < items.len()
    let doubled = items[idx] * 2  # ✅ Works - fresh scope each iteration
    puts(doubled)
    idx = idx + 1
end

# Output:
# 2
# 4
# 6
```

## Root Cause

**For loops** (BROKEN):
- Call `scope.push()` ONCE before entering loop (line 1480, 1567 in src/main.rs)
- All iterations share the same scope
- Variables declared with `let` persist across iterations

```rust
// src/main.rs line ~1480
scope.push();  // ← Called once
let mut result = QValue::Nil(QNil);

match collection {
    QValue::Array(arr) => {
        for (index, item) in elements.iter().enumerate() {
            // All iterations use the same scope!
            scope.set(&first_var, item.clone());

            for stmt in iter.clone() {
                eval_pair(stmt.clone(), scope)?;  // ← Can't redeclare variables
            }
        }
    }
}

scope.pop();  // ← Popped once at end
```

**While loops** (CORRECT):
- Call `scope.push()` at the START of each iteration (line 1628)
- Call `scope.pop()` at the END of each iteration
- Each iteration gets a fresh scope

```rust
// src/main.rs line ~1619
'outer: loop {
    let condition = eval_pair(condition_expr.clone(), scope)?;
    if !condition.as_bool() { break; }

    scope.push();  // ← Fresh scope each iteration ✅

    for stmt in body_statements.iter() {
        eval_pair(stmt.clone(), scope)?;
    }

    // Propagate self mutations
    if let Some(updated_self) = scope.get("self") {
        scope.pop();  // ← Pop after each iteration ✅
        scope.set("self", updated_self);
    } else {
        scope.pop();
    }
}
```

## Affected For Loop Types

All three for loop variants are affected:

1. **Array/Dict iteration** (line ~1480-1548)
2. **Range iteration with "to"** (line ~1567-1606)
3. **Range iteration with "until"** (same code path)

## Workarounds

### Workaround 1: Use assignment instead of declaration

```quest
let doubled = nil  # Declare outside loop
for i in [1, 2, 3]
    doubled = i * 2  # Assignment works
    puts(doubled)
end
```

### Workaround 2: Use while loops

```quest
let items = [1, 2, 3]
let idx = 0
while idx < items.len()
    let doubled = items[idx] * 2  # Works in while loops
    puts(doubled)
    idx = idx + 1
end
```

### Workaround 3: Don't use temporary variables

```quest
for i in [1, 2, 3]
    puts(i * 2)  # No intermediate variable needed
end
```

## Impact

**Medium severity because:**
1. Common pattern: declaring temporary variables in loops
2. Inconsistent with while loops (confusing for users)
3. Inconsistent with other languages (Python, Ruby, JS all have per-iteration scope)
4. Workarounds exist but are less idiomatic

**Not critical because:**
1. Workarounds available (use assignment or while loops)
2. Doesn't affect existing code that doesn't use `let` in loops
3. The varargs test file works around it by using while loops

## Examples Affected

### Example 1: Computing derived values

```quest
# Broken
for user in users
    let display_name = user.name .. " (" .. user.email .. ")"  # ❌
    puts(display_name)
end

# Workaround
for user in users
    puts(user.name .. " (" .. user.email .. ")")  # No temp variable
end
```

### Example 2: Multiple temporary variables

```quest
# Broken
for item in items
    let price = item.base_price  # ❌ First iteration: OK
    let tax = price * 0.08       # ❌ First iteration: OK
    let total = price + tax      # ❌ Second iteration: all fail
    puts(total)
end

# Workaround
for item in items
    price = item.base_price  # Need to declare outside loop
    tax = price * 0.08
    total = price + tax
    puts(total)
end
```

### Example 3: Loop over ranges

```quest
# Broken
for i in 1 to 10
    let squared = i * i  # ❌
    puts(squared)
end

# Workaround
for i in 1 to 10
    puts(i * i)
end
```

## Comparison with Other Languages

All major languages create fresh scope per iteration:

**Python:**
```python
for i in [1, 2, 3]:
    doubled = i * 2  # ✅ Works
    print(doubled)
```

**Ruby:**
```ruby
[1, 2, 3].each do |i|
  doubled = i * 2  # ✅ Works
  puts doubled
end
```

**JavaScript:**
```javascript
for (let i of [1, 2, 3]) {
  let doubled = i * 2;  // ✅ Works
  console.log(doubled);
}
```

**Quest while loops:**
```quest
let i = 0
while i < 3
    let doubled = (i + 1) * 2  # ✅ Works
    puts(doubled)
    i = i + 1
end
```

**Quest for loops:**
```quest
for i in [1, 2, 3]
    let doubled = i * 2  # ❌ Broken
    puts(doubled)
end
```

## Why Varargs Tests Use While Loops

The varargs test file (`test/function/varargs_test.q`) uses while loops specifically to avoid this bug:

```quest
# From varargs_test.q lines 10-16
fun sum(*numbers)
    let total = 0
    let i = 0
    while i < numbers.len()  # Uses while, not for!
        total = total + numbers[i]
        i = i + 1
    end
    total
end
```

This is a workaround, not a deliberate choice. With the fix, it could be written more idiomatically:

```quest
fun sum(*numbers)
    let total = 0
    for num in numbers
        total = total + num  # No temp variable needed
    end
    total
end
```

## Solution

Make for loops behave like while loops by creating a new scope for each iteration:

1. Move `scope.push()` from before the loop to inside the iteration
2. Add `scope.pop()` at the end of each iteration
3. Propagate `self` mutations after each iteration (existing pattern)

## Test Cases

```quest
# Test 1: Basic let in loop body
for i in [1, 2, 3]
    let doubled = i * 2
    assert doubled == i * 2
end

# Test 2: Multiple lets
for i in [1, 2, 3]
    let x = i
    let y = x * 2
    let z = y + 1
    assert z == i * 2 + 1
end

# Test 3: Variable shadowing
let x = 10
for i in [1, 2, 3]
    let x = i  # Shadows outer x
    assert x == i
end
assert x == 10  # Outer x unchanged

# Test 4: Range iteration
for i in 1 to 3
    let squared = i * i
    assert squared == i * i
end

# Test 5: Dict iteration
for key, value in {a: 1, b: 2}
    let combined = key .. value._str()
    puts(combined)
end
```

## Related Issues

- While loops already implement per-iteration scoping correctly
- If/elif/else blocks create new scopes (correct)
- Type methods need `self` mutation propagation (already handled)

## Priority

**Medium** because:
1. Common use case affected
2. Inconsistent with while loops and other languages
3. Easy workarounds exist
4. Not blocking any critical functionality
5. Likely users have already adapted to using while loops or assignments

## Files

- `bugs/018_for_loop_scope_sharing/000_initial_report.md` (this file)
- `bugs/018_for_loop_scope_sharing/example.q` (reproduction)
- `src/main.rs` lines 1456-1608 (for loop implementation)
- `test/function/varargs_test.q` (uses workaround)
