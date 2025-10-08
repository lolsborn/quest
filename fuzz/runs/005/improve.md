# Improvement Suggestions from Fuzz Session 005

## 1. Support Contextual Keywords

**Problem**: Keywords like `end`, `step`, `in`, `to`, `until` cannot be used as identifiers (variable names, parameter names, etc.) because they are globally reserved.

**Suggestion**: Implement contextual keywords that are only reserved in specific contexts:
- `end` only reserved when closing blocks
- `step`, `to`, `until` only reserved in range expressions
- `in` only reserved in for loops and match statements

**Benefit**: Allows natural naming like `make_range(start, end, step)` which is intuitive for users coming from Python, Ruby, JavaScript, etc.

**Example**:
```quest
# Should work but currently doesn't:
fun make_range(start, end, step = 1)
    # ...
end

# Must write instead:
fun make_range(start, finish, increment = 1)
    # ...
end
```

## 2. Support Function Calls in Default Parameters

**Problem**: Default parameter values only support literals and simple binary expressions, not function calls or complex expressions.

**Suggestion**: Allow arbitrary expressions in default parameters, including:
- Function calls: `fun foo(x = get_default())`
- Method calls: `fun foo(x = obj.method())`
- Complex expressions: `fun foo(x = compute_value() + 10)`

**Benefit**: Enables lazy evaluation patterns, factory functions, and more dynamic defaults per QEP-033 spec.

**Example**:
```quest
# Should work but currently doesn't:
fun with_timestamp(ts = time.now())
    # ...
end

fun with_uuid(id = uuid.v4())
    # ...
end
```

## 3. Support **kwargs in Lambdas

**Problem**: Lambda functions parse with `**kwargs` parameter but fail at runtime when keyword arguments are passed.

**Suggestion**: Complete the implementation of kwargs support in lambda evaluation to match regular function behavior.

**Benefit**: Enables functional programming patterns like decorators, higher-order functions, and callback wrappers that need to accept arbitrary keyword arguments.

**Example**:
```quest
# Should work but currently doesn't:
let make_config = fun (**opts) opts end
let config = make_config(host: "localhost", port: 8080)

# Useful for decorators and wrappers:
let with_logging = fun (func)
    fun (*args, **kwargs)
        puts("Calling " .. func._name())
        func(*args, **kwargs)
    end
end
```

## 4. Better Error Messages for Reserved Keywords

**Problem**: When a reserved keyword is used as an identifier, the error message is generic and unhelpful:
```
expected parameter, varargs, or kwargs
```

**Suggestion**: Detect when a keyword is used in an identifier context and provide specific error:
```
Parse error: 'end' is a reserved keyword and cannot be used as a parameter name
       Did you mean: finish, limit, bound?
```

**Benefit**: Much better developer experience - clear error messages reduce frustration and debugging time.

## 5. Support Multi-line Function Calls

**Problem**: Function calls with many named arguments cannot be split across lines for readability:
```quest
# Would be nice but doesn't parse:
let result = configure(
    host: "localhost",
    port: 8080,
    ssl: true,
    debug: false
)
```

**Status**: Needs investigation - may already be supported in newer grammar, but didn't work in this test.

**Benefit**: Improves code readability for functions with many parameters.

## 6. Documentation Clarifications

**Problem**: QEP-033 mentions that defaults can reference earlier parameters, but this doesn't work in practice (parser limitation with function calls).

**Suggestion**: Update documentation to clearly state current limitations:
- Default parameters can reference earlier params in simple expressions: `fun f(x, y = x + 1)`
- Default parameters cannot include function calls yet: `fun f(x = get())`  ❌
- List all reserved keywords that cannot be used as identifiers

**Benefit**: Aligns user expectations with implementation reality, reduces confusion.
