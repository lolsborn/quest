# Bug #021: `return` at top level of script throws Error: __FUNCTION_RETURN__

## Description

When using `return` at the top level of a script (not inside a function), Quest throws an error `Error: __FUNCTION_RETURN__` instead of cleanly exiting the script.

## Expected Behavior

`return` at the top level of a script should cleanly exit the script, similar to how `sys.exit(0)` works. This is common behavior in many scripting languages where `return` can be used to exit early from the main script body.

## Actual Behavior

Quest throws an error:
```
Error: __FUNCTION_RETURN__
```

This error appears to be an internal control flow value leaking into the user-facing output.

## Impact

- Scripts that want to exit early must use `sys.exit()` instead of `return`
- Confusing error message that doesn't explain what went wrong
- Inconsistent with expectations from other scripting languages (Python, Ruby, etc.)

## Example

See `example.q` for reproduction case.

## Workaround

Use `sys.exit(0)` instead of `return` at the top level of scripts.

## Discovered

While implementing the database migration system for the blog example (`examples/web/blog/migrate.q`). The script used `return` to exit early when no migrations were pending, which triggered this error.

## Related Code

The error string `__FUNCTION_RETURN__` suggests this is related to how Quest handles function returns internally. The evaluator likely uses a special control flow mechanism for returns that isn't being caught when used at the script top level.
