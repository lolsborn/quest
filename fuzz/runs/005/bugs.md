# Bugs Found in Fuzz Session 005

## Bug 1: Reserved Keyword `step` Cannot Be Used as Parameter Name

**Severity**: Medium

**Description**: The keyword `step` is reserved for range expressions (`0 to 10 step 2`) but the parser doesn't allow it as a parameter name, leading to confusing parse errors.

**Examples**:
```quest
# Fails - 'step' as parameter
fun make_range(start, end = 10, step = 1)
    # ...
end

# Fails - even without defaults
fun test(start, step)
    return start + step
end

# Works - using different name
fun make_range(start, end = 10, increment = 1)
    # ...
end
```

**Error**:
```
Parse error:  --> 2:17
  |
2 | fun test(start, step = 1)
  |                 ^---
  |
  = expected parameter, varargs, or kwargs
```

**Expected**: Either `step` should be usable as a parameter name (contextual keyword), or the error message should clearly state "`step` is a reserved keyword."

**Actual**: Confusing parse error that doesn't mention keywords.

**Workaround**: Use alternative names like `increment`, `stride`, `delta`.

**Root Cause**: `step` is listed in the reserved keywords but provides no helpful error message.

**Impact**: Confusing for users, especially when writing range/iteration utilities where `step` is a natural parameter name.

## Bug 2: Reserved Keyword `end` Cannot Be Used as Parameter Name

**Severity**: Medium

**Description**: Similar to `step`, the keyword `end` (used to terminate blocks) cannot be used as a parameter name, causing confusing parse errors.

**Example**:
```quest
fun make_range(start, end = 10)  # Fails - 'end' is reserved
fun make_range(start, finish = 10)  # Works
```

**Impact**: Common parameter names like `end`, `start`, `step` cannot be used, which is unexpected for users familiar with other languages where these are valid identifiers.

## Suggested Improvement

**Better Error Messages**: When a reserved keyword is used as an identifier, the parser should provide a clear error like:
```
Parse error: 'end' is a reserved keyword and cannot be used as a parameter name
```

Instead of the current generic message:
```
expected parameter, varargs, or kwargs
```

## Bug 3: Lambdas Don't Support **kwargs Parameter

**Severity**: Medium

**Description**: Lambda functions cannot accept `**kwargs` parameter, even though regular functions support it.

**Example**:
```quest
# Regular function - works
fun collect_kwargs(**options)
    return options
end

# Lambda - fails at runtime
let make_dict = fun (**kw) kw end
let d = make_dict(x: 1, y: 2, z: 3)  # ArgErr: Unknown keyword arguments
```

**Error**:
```
ArgErr: Unknown keyword arguments: x, y, z
```

**Expected**: Lambdas should support all parameter types that regular functions support, including `**kwargs`.

**Actual**: Lambda parses successfully but fails at runtime when keyword arguments are passed.

**Root Cause**: Lambda evaluation may not properly handle kwargs parameter type.

**Impact**: Limits functional programming patterns - can't create higher-order functions that accept arbitrary keyword arguments.

## Bug 4: Function Calls Not Supported in Default Parameter Values

**Severity**: High

**Description**: Default parameter values cannot be function calls, even though the grammar should support arbitrary expressions.

**Example**:
```quest
fun get_default()
    return 10
end

fun test(x = get_default())  # Parse error
    return x
end
```

**Error**:
```
Parse error in function body:  --> 1:1
  |
1 | )
  | ^---
  |
  = expected program
```

**Expected**: Default parameters should accept any valid expression, including function calls.

**Actual**: Parser fails when encountering function call syntax in default values.

**Workaround**: Use simple literal values for defaults, compute complex defaults inside the function body.

**Root Cause**: The parser's expression handling for default parameters may not include method calls in the allowed expression types.

**Impact**: Severely limits default parameter expressiveness - can't use factory functions, computed defaults, or any dynamic initialization.
