# Bugs Found in Fuzz Test 006

## Bug #1: Decorator Type Lookup Fails for Local Types

**Severity:** High

**Description:**
When using `@TypeName.new()` syntax for decorators where `TypeName` is defined in the same file, the decorator system fails with "Decorator 'TypeName.new' not found".

**Reproduction:**
```quest
type LogArgs
    func
    fun _call(*args, **kwargs)
        return self.func(*args, **kwargs)
    end
    fun _name() return self.func._name() end
    fun _doc() return self.func._doc() end
    fun _id() return self.func._id() end
end

# This fails with "Decorator 'LogArgs.new' not found"
@LogArgs.new(call_count: 0)
fun test_func()
    return "hello"
end
```

**Expected Behavior:**
The decorator should be looked up in the current scope and applied to the function.

**Actual Behavior:**
RuntimeErr: Decorator 'LogArgs.new' not found

**Impact:**
- Cannot define custom decorator types in user code
- Forces all decorators to be imported from stdlib
- Breaks decorator composition patterns

**Possible Cause:**
The decorator resolution phase happens before type definitions are fully registered, or decorators only look in a global decorator registry rather than the general variable scope.

## Bug #2: Decorator Instance Creation with Required Fields

**Severity:** Medium

**Description:**
When trying to use an already-instantiated decorator type (e.g., `@log1` where `log1 = LogArgs.new(...)`), the system complains about missing required field 'func'.

**Reproduction:**
```quest
let log1 = LogArgs.new(call_count: 0)

@log1
fun test()
    return "test"
end
```

**Error:**
ArgErr: Required field 'func' not provided and has no default

**Expected Behavior:**
The decorator instance should be used directly, with `func` being set automatically to the decorated function.

**Actual Behavior:**
Error about missing 'func' field.

**Impact:**
- Cannot reuse decorator instances
- Cannot create decorator instances with configuration outside of the decoration site
- Limits decorator patterns

## Observations

The decorator system (QEP-003) appears to have limited integration with:
1. User-defined types in local scope
2. Instance-based decorator usage (vs. class-based at decoration time)
3. Decorator resolution timing relative to type definitions

**Recommendation:**
Review the decorator lookup and application mechanism to ensure:
- Decorators can reference types defined in the current scope
- The `func` field can be automatically set during decoration
- Decorator instances can be pre-created and reused
