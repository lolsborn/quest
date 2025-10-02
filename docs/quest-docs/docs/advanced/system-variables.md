# System Variables

Quest provides system-level information through the `sys` module, which is automatically available in all scripts without needing to import it.

## Overview

The `sys` module gives you access to:

- Command-line arguments (`sys.argc` and `sys.argv`)
- Runtime information (`sys.version`, `sys.platform`, `sys.executable`)
- Available modules (`sys.builtin_module_names`)

For complete documentation, see the [sys Module](../stdlib/sys.md) page.

## Quick Example

```quest
# script.q - Display system information
puts("Quest version:", sys.version)
puts("Platform:", sys.platform)
puts("Script name:", sys.argv[0])
puts("Arguments:", sys.argc - 1)
```

```bash
$ quest script.q arg1 arg2
Quest version: 0.1.0
Platform: darwin
Script name: script.q
Arguments: 2
```

## Command-Line Arguments

The most commonly used system variables are for handling command-line arguments:

```quest
# greet.q
if sys.argc < 2
    puts("Usage:", sys.argv[0], "<name>")
else
    let name = sys.argv[1]
    puts("Hello,", name .. "!")
end
```

```bash
$ quest greet.q Alice
Hello, Alice!
```

## Key Differences from Other Languages

### Compared to Python

**Python:**
```python
import sys
print(sys.argv[0])      # Script name
print(len(sys.argv))    # Argument count
```

**Quest:**
```quest
# No import needed - sys is automatic
puts(sys.argv[0])       # Script name
puts(sys.argc)          # Argument count (dedicated variable)
```

### Compared to Bash

**Bash:**
```bash
echo $0        # Script name
echo $#        # Argument count
echo $1 $2     # Individual arguments
```

**Quest:**
```quest
puts(sys.argv[0])      # Script name
puts(sys.argc)         # Argument count
puts(sys.argv[1], sys.argv[2])  # Individual arguments
```

## Important Notes

- **Automatic availability:** The `sys` module is injected into script scope automatically
- **Script-only:** System variables are only available when running scripts, not in the REPL
- **Read-only:** All `sys` properties are read-only and cannot be modified
- **String arguments:** All command-line arguments in `sys.argv` are strings

## Complete Documentation

For detailed information about all `sys` module features, including:
- All available properties
- Platform-specific behavior
- Practical examples and patterns
- Best practices for argument parsing

See the complete [sys Module Documentation](../stdlib/sys.md).
