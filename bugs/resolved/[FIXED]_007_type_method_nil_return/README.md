# Bug 007: Type Methods Returning Nil Actually Return Self

**Status**: Open
**Severity**: High
**Discovered**: 2025-10-05
**Affects**: All type instance methods

## Quick Summary

When a type instance method returns `nil`, the interpreter returns the struct instance (self) instead. This breaks any code that checks return values.

## Reproduction

```bash
./target/release/quest bugs/007_type_method_nil_return/example.q
```

## Expected vs Actual

**Expected:**
```quest
type T
    fun m() return nil end
end
T.new().m() == nil  # Should be true
```

**Actual:**
```quest
T.new().m() == nil  # Is false!
# Returns the T instance instead
```

## Files

- `description.md` - Detailed technical analysis
- `example.q` - Minimal reproduction case

## Fix Required

Change `src/main.rs:1803-1809` to always return the actual return value, never substitute self.
