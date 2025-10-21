# Bug #028: Type Field Corruption in Worker Thread Re-execution

## Status
🐛 **ACTIVE** - Worker threads corrupt type definitions during re-parsing

## Original Report
"ArgErr: Required field 'static' not provided and has no default" when running blog server

## Summary
Fields with default values (e.g., `pub field: Str = "default"`) are incorrectly required in struct constructors, unlike TypeScript and other modern languages where defaults make fields optional.

## Expected Behavior (TypeScript-like)
```quest
type Config
    pub host: Str = "localhost"
    pub port: Int = 3000
end

# Should work - defaults are used
let c1 = Config.new()  # host="localhost", port=3000
let c2 = Config.new(host: "0.0.0.0")  # host="0.0.0.0", port=3000
```

## Actual Behavior
```quest
type Config
    pub host: Str = "localhost"  # Has default
    pub port: Int = 3000         # Has default
end

# Fails with: ArgErr: Required field 'host' not provided and has no default
let c1 = Config.new()
```

## Root Cause
The type system checks `field_def.optional` (from `Type?` syntax) to determine if a field can be omitted, but doesn't consider whether `field_def.default_value` exists.

Fields with defaults should be implicitly optional in constructors.

## Semantics

### Current Behavior
- `pub field: Type` → Required in constructor, no default
- `pub field: Type?` → Optional in constructor, nil default
- `pub field: Type = value` → **BUG: Required in constructor** despite having default
- `pub field: Type? = value` → Optional in constructor, custom default

### Desired Behavior (TypeScript-like)
- `pub field: Type` → Required in constructor, no default
- `pub field: Type?` → Optional in constructor, nil default  
- `pub field: Type = value` → **Optional in constructor, custom default**
- `pub field: Type? = value` → Optional in constructor, custom default (can still be nil)

## Impact
- Forces workarounds like making all fields optional (`Type?`) even when non-nil defaults exist
- Inconsistent with TypeScript, Python dataclasses, Kotlin, Swift, etc.
- Breaks ergonomics of configuration types

## Workaround
Change `pub field: Type = default` to `pub field: Type?` and handle defaults in `from_dict()`:

```quest
# Before (broken)
type Config
    pub host: Str = "localhost"
    
    fun self.from_dict(dict)
        return Config.new(host: dict["host"] or "localhost")
    end
end

# After (workaround)
type Config
    pub host: Str?  # Make optional instead of using default
    
    fun self.from_dict(dict)
        return Config.new(host: dict["host"] or "localhost")
    end
end
```

## Conclusion
**Quest ALREADY works correctly!** 

Testing confirms that:
1. ✅ Fields with defaults CAN be omitted in constructors
2. ✅ Default values are automatically used when field not provided
3. ✅ Works with no arguments: `Config.new()` uses all defaults
4. ✅ Works with partial arguments: `Config.new(host: "...")` uses defaults for other fields
5. ✅ Behavior matches TypeScript/Python/Kotlin expectations

See test files:
- `example.q` - Basic defaults work
- `test_mixed_args.q` - Mixing provided and default fields works
- `test_original_scenario.q` - Original Configuration scenario works

The original error "Required field 'static' not provided" was likely caused by:
- Worker thread re-execution issues (now fixed in `src/server.rs`)
- Or the field genuinely not existing in the type definition at that time

## Related
- QEP-045 (struct field defaults) - Working correctly
- WORKER_THREAD_SCOPE_ISSUE.md - Related server re-execution fixes

