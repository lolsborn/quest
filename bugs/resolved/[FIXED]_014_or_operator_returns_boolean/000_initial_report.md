# Bug: 'or' Operator Returns Boolean Instead of First Truthy Value

**Status**: 🔴 OPEN

**Reported**: 2025-10-05

**Severity**: HIGH - Breaks idiomatic null-coalescing pattern

## Summary

Quest's `or` operator returns a boolean (`true`/`false`) instead of returning the first truthy operand like Python, Ruby, JavaScript, and most other scripting languages do.

## Minimal Reproduction

```quest
let x = "hello" or "world"
puts(x)  # Prints: "true" (should print: "hello")

let y = nil or "default"
puts(y)  # Prints: "true" (should print: "default")
```

## Current Behavior

```quest
"hello" or "world"  # → true  (boolean)
nil or "default"     # → true  (boolean)
false or "backup"    # → true  (boolean)
```

## Expected Behavior

Like Python, Ruby, JavaScript:

```quest
"hello" or "world"  # → "hello"  (first truthy value)
nil or "default"     # → "default" (second value if first is nil/false)
false or "backup"    # → "backup" (second value if first is false)
true or "ignored"    # → true (first value is truthy)
```

## Standard Pattern (Broken in Quest)

This pattern is idiomatic in all major scripting languages:

**Python:**
```python
value = config.get("key") or "default"  # Returns the value or default
```

**Ruby:**
```ruby
value = config["key"] || "default"  # Returns the value or default
```

**JavaScript:**
```javascript
value = obj.prop || "default"  // Returns the value or default
```

**Lua:**
```lua
value = config.key or "default"  -- Returns the value or default
```

**Perl:**
```perl
$value = $config{key} // "default";  # (// is Perl's version)
```

Currently, this pattern doesn't work in Quest because `or` returns boolean.

## Impact

This breaks:
- ✅ Default value patterns: `value or "default"`
- ✅ Null-coalescing: `optional_result or fallback`
- ✅ Short-circuit evaluation for values (not just booleans)
- ✅ Guard patterns: `result or return_early()`

## Examples That Break

### Example 1: Default Values
```quest
# Common pattern in other languages:
let name = os.getenv("NAME") or "Anonymous"
# Currently returns: true
# Should return: env value or "Anonymous"
```

### Example 2: Chaining Fallbacks
```quest
# Try multiple sources:
let config = user_config or system_config or default_config
# Currently returns: true
# Should return: first non-nil config
```

### Example 3: Debugging Output
```quest
# Print value or placeholder:
puts("Value: " .. (result or "none"))
# Currently prints: "Value: true"
# Should print: "Value: none" (if result is nil)
```

### Example 4: Return First Valid
```quest
fun get_value()
    expensive_lookup() or cached_value or compute_default()
end
# Currently returns: true
# Should return: first non-nil value
```

## Comparison with Elvis Operator

Quest has the Elvis operator `?:` which DOES work correctly:

```quest
nil ?: "default"     # → "default" ✅
"value" ?: "default" # → "value" ✅
```

But `or` should also follow this pattern for consistency with other languages.

## Correct Semantics

The `or` operator should:
1. Evaluate left operand
2. If truthy (not nil, not false), return it
3. Otherwise, evaluate and return right operand

```rust
// Pseudocode for correct behavior:
fn eval_or(left_expr, right_expr, scope) {
    let left = eval(left_expr, scope);
    if left.is_truthy() {
        return left;  // Return the value, not true!
    } else {
        return eval(right_expr, scope);
    }
}
```

## Current Implementation (Wrong)

Quest currently does:
```rust
// Pseudocode for current (wrong) behavior:
fn eval_or(left_expr, right_expr, scope) {
    let left = eval(left_expr, scope);
    if left.is_truthy() {
        return QValue::Bool(true);  // ← BUG: Returns boolean!
    } else {
        let right = eval(right_expr, scope);
        return QValue::Bool(right.is_truthy());  // ← BUG: Returns boolean!
    }
}
```

## Same Issue with `and` Operator

The `and` operator likely has the same issue:

```quest
# Should return last value if all truthy:
"first" and "second" and "third"  # Should be "third", probably returns true

# Should return first falsy value:
"first" and nil and "third"  # Should be nil, probably returns false
```

## Test Cases

```quest
# or operator
assert ("hello" or "world") == "hello"
assert (nil or "default") == "default"
assert (false or "backup") == "backup"
assert (0 or "nonzero") == 0  # 0 is truthy in Quest
assert ("" or "empty") == ""  # Empty string is truthy

# and operator
assert ("first" and "second") == "second"
assert (nil and "never") == nil
assert (false and "never") == false
assert ("first" and nil and "third") == nil
```

## Priority

**HIGH** because:
1. Standard behavior in all major scripting languages
2. Breaks idiomatic null-coalescing pattern
3. Makes Quest inconsistent with developer expectations
4. Elvis operator (`?:`) already exists and works correctly
5. Common pattern for default values and fallbacks

## Workaround

Use Elvis operator or if statement:

```quest
# Instead of: value or "default"
value ?: "default"  # Works correctly

# Or:
if value != nil
    value
else
    "default"
end
```

But this is verbose compared to the `or` pattern.

## Related

- Elvis operator (`?:`) works correctly
- `and` operator likely has the same issue
- This is NOT a bug with if expressions (those work correctly)

## Files

- `bugs/014_or_operator_returns_boolean/000_initial_report.md` (this file)
- `bugs/014_or_operator_returns_boolean/test_or_operator.q` - Demonstrates the bug
- `bugs/014_or_operator_returns_boolean/minimal_repro.q` - Shows if expressions work fine
- `bugs/014_or_operator_returns_boolean/test_return_type.q` - Confirms if returns correct value
