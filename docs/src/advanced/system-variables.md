# System Variables

> **Note:** Quest has moved system information to the `sys` module instead of global variables. See [docs/std/sys.md](std/sys.md) for full documentation.

## The `sys` Module

Quest provides system information through the `sys` module, which is automatically available in all scripts without needing to import it.

### Quick Reference

- **`sys.argc`** - Number of command line arguments
- **`sys.argv`** - Array of command line argument strings
- **`sys.version`** - Quest version string
- **`sys.platform`** - Operating system name (darwin, linux, win32, etc.)
- **`sys.executable`** - Path to Quest executable
- **`sys.builtin_module_names`** - Array of available built-in modules

### Example

```quest
# script.q
puts("Version:", sys.version)
puts("Platform:", sys.platform)
puts("Number of arguments:", sys.argc)
puts("Arguments:", sys.argv)
```quest

```bash
$ quest script.q arg1 arg2
Version: 0.1.0
Platform: darwin
Number of arguments: 3
Arguments: [script.q, arg1, arg2]
```quest

## Command Line Arguments

### `sys.argc`

The number of command line arguments passed to the script, including the script name.

**Type:** Num

**Example:**
```quest
# script.q
puts("Number of arguments:", sys.argc)
```quest

```bash
$ quest script.q
Number of arguments: 1

$ quest script.q arg1 arg2
Number of arguments: 3
```quest

### `sys.argv`

An array containing all command line arguments. The first element (`sys.argv[0]`) is always the script name.

**Type:** Array of Str

**Example:**
```quest
# greet.q
if sys.argc < 2
    puts("Usage:", sys.argv[0], "<name>")
else
    puts("Hello,", sys.argv[1] .. "!")
end
```quest

```bash
$ quest greet.q
Usage: greet.q <name>

$ quest greet.q Alice
Hello, Alice!
```quest

## Working with Arguments

### Accessing Arguments

Access individual arguments by index:

```quest
let script_name = sys.argv[0]
let first_arg = sys.argv[1]
let second_arg = sys.argv[2]
```quest

### Checking Argument Count

Always check `sys.argc` before accessing arguments:

```quest
if sys.argc < 2
    puts("Error: Missing required argument")
else
    let input_file = sys.argv[1]
    # ... process file
end
```quest

### Processing All Arguments

Process all arguments except the script name:

```quest
# print_args.q
puts("Script: ", sys.argv[0])
puts("Arguments:")

let i = 1
if sys.argc > 1
    puts("  ", sys.argv[1])
end
if sys.argc > 2
    puts("  ", sys.argv[2])
end
if sys.argc > 3
    puts("  ", sys.argv[3])
end
# ... continue for expected number of args
```quest

**Note:** Quest doesn't have traditional for loops yet, so you need to check each argument explicitly.

### Parsing Flags and Options

Example of a script that handles flags:

```quest
# process.q
let verbose = false
let input_file = ""
let i = 1

# Check for -v flag
if sys.argc > 1 and sys.argv[1] == "-v"
    verbose = true
    i = 2
end

# Get input file
if sys.argc > i
    input_file = sys.argv[i]
else
    puts("Usage: ", sys.argv[0], " [-v] <input_file>")
end

if verbose
    puts("Processing: ", input_file)
end
```quest

```bash
$ quest process.q data.txt
$ quest process.q -v data.txt
Processing: data.txt
```quest

## Practical Examples

### File Processor

```quest
#!/usr/bin/env quest
# file_stats.q - Display file statistics

if sys.argc != 2
    puts("Usage: ", sys.argv[0], " <filename>")
else
    let filename = sys.argv[1]
    puts("File: ", filename)
    # Read and process file...
end
```quest

### Calculator

```quest
#!/usr/bin/env quest
# calc.q - Simple calculator

if sys.argc != 4
    puts("Usage: ", sys.argv[0], " <num1> <op> <num2>")
    puts("Example: ", sys.argv[0], " 5 + 3")
else
    let a = sys.argv[1]
    let op = sys.argv[2]
    let b = sys.argv[3]

    # Note: Convert strings to numbers first
    # (Quest will need string-to-number conversion)
    puts(a, " ", op, " ", b, " = result")
end
```quest

### Multi-File Processor

```quest
#!/usr/bin/env quest
# process_files.q

if sys.argc < 2
    puts("Usage: ", sys.argv[0], " <file1> [file2] [file3] ...")
else
    puts("Processing ", sys.argc - 1, " files:")

    if sys.argc > 1
        puts("  ", sys.argv[1])
    end
    if sys.argc > 2
        puts("  ", sys.argv[2])
    end
    if sys.argc > 3
        puts("  ", sys.argv[3])
    end
end
```quest

## Differences from Other Languages

### Bash

```bash
# Bash
echo "Script: $0"
echo "First arg: $1"
echo "All args: $@"
echo "Arg count: $#"
```quest

```quest
# Quest
puts("Script: ", sys.argv[0])
puts("First arg: ", sys.argv[1])
puts("All args: ", sys.argv)
puts("Arg count: ", sys.argc)
```quest

### Python

```python
# Python
import sys
print(f"Script: {sys.argv[0]}")
print(f"Args: {sys.argv[1:]}")
print(f"Count: {len(sys.argv)}")
```quest

```quest
# Quest
puts("Script: ", sys.argv[0])
# No direct way to slice arrays yet
puts("Count: ", sys.argc)
```quest

### Node.js

```javascript
// Node.js
console.log("Script:", process.argv[1]);
console.log("Args:", process.argv.slice(2));
console.log("Count:", process.argv.length);
```quest

```quest
# Quest
puts("Script: ", sys.argv[0])
puts("Args: ", sys.argv)
puts("Count: ", sys.argc)
```quest

## Behavior in Different Contexts

### Script Files

When running a script file:
- `sys.argv[0]` is the script filename
- Additional arguments follow in `sys.argv[1]`, `sys.argv[2]`, etc.

```bash
$ quest script.q arg1 arg2
# sys.argc = 3
# sys.argv = ["script.q", "arg1", "arg2"]
```quest

### Piped Input

When piping code to Quest:
- `sys.argv[0]` is the Quest executable path
- No additional arguments available

```bash
$ echo 'puts(sys.argv[0])' | quest
# sys.argc = 1
# sys.argv = ["./quest"]
```quest

### Interactive REPL

In the REPL, `sys.argc` and `sys.argv` are not available since there's no script context.

## Best Practices

### 1. Always Validate Arguments

```quest
if sys.argc < 2
    puts("Error: Missing required argument")
    puts("Usage: ", sys.argv[0], " <filename>")
    # Exit would be useful here
end
```quest

### 2. Provide Usage Information

```quest
fun show_usage()
    puts("Usage: ", sys.argv[0], " [options] <input>")
    puts("Options:")
    puts("  -v, --verbose    Enable verbose output")
    puts("  -h, --help       Show this help")
end

if sys.argc < 2
    show_usage()
end
```quest

### 3. Handle Edge Cases

```quest
# Check for empty arguments
if sys.argc > 1 and sys.argv[1] == ""
    puts("Error: Empty argument provided")
end
```quest

### 4. Store Arguments in Named Variables

```quest
let program_name = sys.argv[0]
let input_file = ""
let output_file = ""

if sys.argc > 1
    input_file = sys.argv[1]
end

if sys.argc > 2
    output_file = sys.argv[2]
end
```quest

## Limitations

- **No argument slicing:** Cannot easily get `sys.argv[1:]` (all args except script name)
- **No iteration:** Must check each argument index explicitly
- **No type conversion:** Arguments are always strings, need manual conversion
- **No REPL access:** `sys.argc` and `sys.argv` only available in scripts

## Future Enhancements

Quest may add:
- Array slicing: `sys.argv[1:]` to skip script name
- For loops: Iterate over all arguments
- Argument parsing library: Built-in flag/option parsing
- Type conversion: `str.to_num()`, `str.to_bool()`
- Exit codes: Ability to exit with specific status

## Summary

- **`sys.argc`** - Number of command line arguments (including script name)
- **`sys.argv`** - Array of command line argument strings
- **`sys.argv[0]`** - Always the script filename
- Available automatically in all scripts
- Arguments are always strings
- Check `sys.argc` before accessing `sys.argv` elements

Use these variables to build flexible command-line tools in Quest!
