# Bug #021: F-String Inline Argument Failure

## Status
Open

## Summary
When an f-string is passed inline as an argument to a **struct method**, the method receives `nil` instead of the evaluated string. Regular functions work correctly. If the f-string is first assigned to a variable, it works correctly.

## Discovery
Found while debugging the blog example where `logger.info(f"{client_ip} {method} {path}")` produced no output, but the function was executing successfully.

## Impact
- High: Silent failures are difficult to debug
- Affects any code using inline f-strings as function arguments
- Workaround exists: assign f-string to variable first

## Reproduction

### Failing Case
```quest
use "std/log" as log

let logger = log.get_logger("test")
logger.set_level(log.INFO)
let handler = log.StreamHandler.new(level: log.INFO, formatter_obj: nil, filters: [])
logger.add_handler(handler)

let x = "hello"

# This produces NO output
logger.info(f"Message: {x}")
```

### Working Case
```quest
let x = "hello"
let msg = f"Message: {x}"
logger.info(msg)  # This works
```

## Test Results

### Simple function test
```quest
fun print_msg(msg)
    puts("Received: " .. msg)
end

let name = "Alice"

# Works
let msg = f"Hello {name}"
print_msg(msg)  # Output: "Received: Hello Alice"

# Fails - no output or error
print_msg(f"Hello {name}")  # Expected: "Received: Hello Alice", Actual: silent failure
```

### Concatenation works
```quest
print_msg("Hello " .. name)  # Works fine
```

## Root Cause Hypothesis
The f-string evaluation in the expression evaluator may not be properly handling the case where the f-string result needs to be immediately passed as an argument. Likely an issue in how arguments are evaluated/collected during function calls.

## Location
Likely in:
- `src/main.rs` - expression evaluation for f-strings
- `src/function_call.rs` - argument collection/evaluation

## Related Files
- `examples/web/blog/index.q` - Real-world occurrence at line 92
- `lib/std/log.q` - Logger module (victim, not cause)

## Fix Verification
After fix, these should all produce output:
1. `logger.info(f"test {var}")`
2. `any_function(f"test {var}")`
3. Nested: `func1(func2(f"test {var}"))`
4. Multiple args: `func(arg1, f"test {var}", arg3)`
