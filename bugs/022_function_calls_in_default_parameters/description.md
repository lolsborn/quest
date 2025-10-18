# Bug #022: Function Calls Not Supported in Default Parameters

**Status:** Open
**Severity:** High
**Priority:** P1
**Discovered:** 2025-10-17 (Fuzz Testing Report Analysis)
**Component:** Parser / Function Parameters

---

## Summary

Function calls cannot be used as default parameter values. The parser fails when attempting to parse function calls in default parameter positions, even though QEP-033 specifies that default parameters should be evaluated at call time.

---

## Impact

- **Limits default parameter expressiveness** - Cannot use factory functions, computed defaults, or any dynamic initialization patterns
- **Blocks common patterns** - Cannot use timestamps (`time.now()`), UUIDs (`uuid.v4()`), or factory functions as defaults
- **Inconsistent with documented behavior** - QEP-033 mentions defaults evaluated at call time, suggesting function calls should work
- **User frustration** - Feature works in Python, JavaScript, Ruby, etc.

---

## Current Behavior

```quest
fun increment()
  1
end

fun test(x = increment())
  x
end
```

**Error:**
```
Parse error in function body:  --> 1:1
  |
1 | )
  | ^---
  |
  = expected program
```

---

## Expected Behavior

Function calls should be valid expressions in default parameter positions:

```quest
fun increment()
  1
end

fun test(x = increment())
  x
end

puts(test())     # Should print: 1
puts(test(5))    # Should print: 5
```

### Common Use Cases

```quest
use "std/uuid" as uuid
use "std/time" as time

# Fresh UUID each call
fun create_record(id = uuid.v4())
  {id: id, data: "..."}
end

# Timestamp at call time
fun log_message(msg, timestamp = time.now())
  puts(f"{timestamp}: {msg}")
end

# Factory function
fun get_default_config()
  {host: "localhost", port: 8080}
end

fun connect(config = get_default_config())
  # ...
end
```

---

## Root Cause

The parser's expression handling for default parameters is too restrictive. It likely only accepts:
- Literals (numbers, strings, booleans, nil)
- Binary expressions (arithmetic, comparisons)
- References to earlier parameters

But does not accept:
- Function calls (method calls)
- Array/dict constructors
- Complex expressions

---

## Reproduction

### Minimal Test Case

```quest
fun increment()
  1
end

fun test(x = increment())
  x
end

puts(test())
```

**Result:** Parse error

### Works: Literals and Binary Expressions

```quest
fun test(x = 5)           # OK - literal
fun test(x = 2 + 3)       # OK - binary expression
fun test(x, y = x + 1)    # OK - reference to earlier param
```

### Fails: Function Calls

```quest
fun get_default() 42 end
fun test(x = get_default())  # FAIL - parse error
```

---

## Suggested Fix

Extend the parser's grammar for default parameter values to accept full expressions, including method calls:

```pest
// In quest.pest
default_value = { "=" ~ expression }  // Should include method_call

// Ensure expression includes:
expression = {
  // ... existing rules ...
  | method_call
  | function_call
  // ...
}
```

The evaluation logic already exists (QEP-033 states defaults are evaluated at call time), so this is primarily a parser enhancement.

---

## Related Issues

- **Fuzz Report Improvement #1:** Support function calls in default parameters
- **QEP-033:** Default parameters specification

---

## Test Coverage Required

1. Simple function call as default ✓
2. Function call with arguments as default
3. Method calls on objects as default
4. Chained method calls as default
5. Function calls referencing earlier parameters
6. Lambda calls as defaults
7. Static method calls as defaults (e.g., `Type.method()`)

---

## Acceptance Criteria

- [ ] Function calls parse correctly in default parameter positions
- [ ] Defaults are evaluated at call time (not definition time)
- [ ] Works with functions, methods, lambdas
- [ ] Works in combination with required and varargs parameters
- [ ] Error handling for failed default evaluation at call time
- [ ] All existing tests pass

---

## Priority Justification

**P1 (High Priority)** because:

1. **High user impact** - Common pattern in modern languages
2. **Completes QEP-033** - Feature documented as working but incomplete
3. **Clear implementation path** - Parser enhancement
4. **Unlocks important use cases** - Timestamps, UUIDs, factories
5. **Relatively isolated change** - Primarily parser work

---

## Notes

- Current workaround: Check for nil and generate value inside function body
- This is a parser limitation, not a runtime limitation
- Similar patterns work in other parts of Quest (function bodies, etc.)
