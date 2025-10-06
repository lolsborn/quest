# Type Methods Returning Nil Actually Return Self

## Issue

Type instance methods that explicitly `return nil` actually return the struct instance (self) instead of nil. This breaks any type method that legitimately wants to return nil.

## Current Behavior

```quest
type TestType
    int: value

    fun returns_nil()
        return nil
    end

    fun returns_value()
        return 42
    end
end

let t = TestType.new(value: 100)
let r1 = t.returns_nil()
let r2 = t.returns_value()

# Expected: r1 == nil
# Actual: r1 is a TestType instance (returns self!)
```

**Output:**
```
r1 == nil  # false (BUG!)
r2 == 42   # true (correct)
```

## Expected Behavior

Methods that `return nil` should return `QValue::Nil`, not the struct instance.

## Root Cause

**File**: `src/main.rs:1803-1809`

```rust
// If method returned nil, use updated self (for chaining mutating methods)
// Otherwise use the return value
result = if matches!(return_value, QValue::Nil(_)) {
    updated_self  // ← BUG: Returns self when nil returned
} else {
    return_value
};
```

The code assumes that `return nil` means "this was a mutating method, return self for chaining." But this breaks methods that legitimately want to return nil.

## Impact

- **Severity**: High
- **Affects**: All type instance methods
- **Tests Affected**: Log filter tests, handler tests, any code checking for nil returns
- **User Impact**: Cannot write type methods that return nil
- **Workaround**: Tests must avoid checking return values of methods that should return nil

## Examples of Broken Code

### Example 1: Handler.add_filter()
```quest
type Handler
    fun add_filter(filter)
        self.filters.push(filter)
        # Implicitly returns nil, but actually returns self!
    end
end

let handler = StreamHandler.new(...)
let result = handler.add_filter(filter)
# Expected: result == nil
# Actual: result == handler (BUG!)
```

### Example 2: Optional Return Methods
```quest
type Database
    fun find_user(id)
        if id == 1
            return User.new(...)
        else
            return nil  # User not found
        end
    end
end

let db = Database.new()
let user = db.find_user(999)
# Expected: user == nil
# Actual: user == db instance (BUG!)
```

### Example 3: Void Methods
```quest
type Logger
    fun log(message)
        puts(message)
        return nil  # Void method
    end
end

let logger = Logger.new()
let result = logger.log("test")
# Expected: result == nil
# Actual: result == logger (BUG!)
```

## Proposed Solution

### Option 1: Check if Method Actually Mutates

Only return `updated_self` if the struct was actually modified:

```rust
result = if matches!(return_value, QValue::Nil(_)) {
    // Check if self was actually modified
    if updated_self != result {  // Compare struct state
        updated_self  // Return updated self if changed
    } else {
        return_value  // Return nil if unchanged
    }
} else {
    return_value
};
```

### Option 2: Explicit Chaining Syntax

Require explicit syntax for method chaining:

```quest
# Explicit chaining with special syntax or keyword
obj.mutate_method().chain().another_method()

# Or just return self explicitly when chaining is wanted
fun mutate()
    self.field = 5
    return self  # Explicit
end
```

### Option 3: Never Auto-Return Self

Always return the actual return value, never substitute self:

```rust
result = return_value;  // Simple - always use actual return value
```

Then update the struct in scope if it changed:

```rust
// After method call, update variable if struct was modified
if original_result_id == Some(updated_self.id) {
    if let Some(var_name) = original_identifier {
        scope.set(&var_name, updated_self);
    }
}
```

## Recommendation

**Option 3** is cleanest - always return the actual return value. Methods that want chaining can `return self` explicitly.

This matches standard behavior in Ruby, Python, JavaScript, etc.

## Failing Tests

- `test/log/filters_test.q` - Had to work around in 2 tests
- Any future tests checking handler return values

## Related Code

- `src/main.rs:1746-1816` - Struct method handling
- `src/main.rs:1798` - call_user_function for struct methods
- `src/main.rs:1803-1809` - The problematic if/else

## Workaround

For testing, avoid checking return values:
```quest
# Don't do this:
let result = handler.add_filter(filter)
test.assert(result == nil)  # Fails!

# Do this instead:
handler.add_filter(filter)  # Ignore return value
# Test the side effect worked
test.assert(handler.filters.len() == 1)
```

## Status

**Open** - Discovered 2025-10-05

## Priority

**High** - Affects all type methods, breaks expected nil semantics
