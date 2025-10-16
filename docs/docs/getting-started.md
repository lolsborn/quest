# Getting Started

This guide will help you install Quest and write your first program.

## Installation

### Install via Cargo

The easiest way to install Quest is using Cargo, Rust's package manager:

```bash
cargo install vibequest
```

This will download, compile, and install Quest. The `quest` executable will be available in your PATH (typically `~/.cargo/bin/quest`).

**Note**: You'll need Rust installed. If you don't have it, install from [rust-lang.org](https://rust-lang.org) or use [rustup](https://rustup.rs).

### Building from Source

If you want to build Quest from source or contribute to development, see the [Building from Source](./building-from-source.md) guide.

## Command Line Options

Quest provides several command-line options:

```bash
quest --help      # Display help information
quest -h          # Short form of --help
quest --version   # Display version information
quest -v          # Short form of --version
```

### Getting Help

To see all available options and usage examples:

```bash
quest --help
```

This displays:
- All available modes (REPL, script execution, run command)
- Command-line options
- Example usage
- Information about accessing script arguments

## The REPL

Quest includes an interactive Read-Eval-Print Loop (REPL) for experimentation and learning.

### Starting the REPL

Run Quest without arguments to start the REPL:

```bash
quest
```

You'll see a prompt:

```text
quest>
```

### REPL Features

The REPL supports:

- **Multi-line input**: Start blocks with `if`, `fun`, `while`, `for` and the REPL will continue accepting input until `end`
- **Variable persistence**: Variables declared with `let` persist across REPL sessions
- **Automatic printing**: Expression results are automatically displayed (except `nil`)
- **Error recovery**: Syntax or runtime errors won't crash the REPL

### Example REPL Session

```text
quest> let x = 10
quest> x.plus(5)
15
quest> let greet = fun (name)
  ..>     "Hello, " .. name
  ..> end
quest> greet("World")
"Hello, World"
quest> for i in 0 to 3
  ..>     puts(i)
  ..> end
0
1
2
3
```

## Running Script Files

Quest can execute programs from files with the `.q` extension.

### Your First Script

Create a file called `hello.q`:

```quest
# hello.q - Your first Quest program

let name = "World"
puts("Hello, ", name, "!")

# Calculate something
let x = 5
let y = 10
puts("The sum of ", x, " and ", y, " is ", x.plus(y))
```

Run it:

```bash
quest hello.q
```

Output:
```text
Hello, World!
The sum of 5 and 10 is 15
```

### Using Standard Input

Quest can also read from standard input:

```bash
echo 'puts("Hello from stdin!")' | quest
```

Or:

```bash
quest < script.q
```

## Project Scripts with `quest run`

Quest supports a project configuration file (`quest.toml`) that lets you define named scripts, similar to `npm run` in Node.js.

### Creating quest.toml

Create a `quest.toml` file in your project root. The file can contain project metadata and script definitions:

```toml
# Project metadata (optional)
name = "my-quest-project"
version = "0.1.0"
description = "My Quest application"
authors = ["Your Name"]
license = "MIT"
homepage = "https://github.com/username/project"
repository = "https://github.com/username/project"
keywords = ["quest", "scripting"]

# Scripts (required for quest run command)
[scripts]
test = "scripts/test.q"
hello = "examples/hello.q"
build = "./build.sh"
format = "/usr/bin/rustfmt"
```

#### Metadata Fields

All metadata fields are optional but help document your project:

- **`name`**: Project name (string)
- **`version`**: Semantic version (e.g., "0.1.0")
- **`description`**: Brief project description
- **`authors`**: List of author names
- **`license`**: License identifier (e.g., "MIT", "Apache-2.0")
- **`homepage`**: Project website URL
- **`repository`**: Source repository URL
- **`keywords`**: List of keywords for discoverability

#### Scripts Section

The `scripts` section maps script names to file paths or executables:

```toml
[scripts]
# Quest scripts (.q files)
test = "scripts/test.q"
hello = "examples/hello.q"

# Shell scripts
build = "./build.sh"

# System executables
format = "/usr/bin/rustfmt"
echo = "/bin/echo"
```

### Running Scripts

Use the `run` command to execute named scripts:

```bash
quest run test
quest run hello arg1 arg2
```

The `run` command is case-insensitive:

```bash
quest RUN test
quest Run hello
```

### How It Works

When you run `quest run <script_name>`:

1. Quest looks for `quest.toml` in the current directory
2. Finds the script path in the `[scripts]` section
3. If the path ends in `.q`, Quest runs it as a Quest script
4. Otherwise, Quest spawns it as an executable
5. All paths are resolved relative to the config file location

### Passing Arguments

Arguments after the script name are passed to the script:

```bash
quest run test --verbose
quest run build release
```

For Quest scripts (`.q` files), arguments are available via `sys.argv`:

```quest
# test.q
puts("Script:", sys.argv[0])
puts("Args:", sys.argv[1..-1])
```

Running `quest run test arg1 arg2` would output:
```text
Script: scripts/test.q
Args: [arg1, arg2]
```

### Example Workflow

```bash
# Create quest.toml
cat > quest.toml << 'EOF'
[scripts]
test = "scripts/test.q"
hello = "examples/hello.q"
clean = "rm -rf build/"
EOF

# Run scripts
quest run test          # Runs scripts/qtest
quest run hello World   # Runs examples/hello.q with argument "World"
quest run clean         # Executes: rm -rf build/
```

## Basic Syntax Overview

Here's a quick reference to get you started:

### Variables

```quest
let x = 42              # Declare with let
x = 100                 # Assign (must be declared first)
```

### Data Types

```quest
let num = 42            # Numbers (integers and floats)
let str = "hello"       # Strings
let bool = true         # Booleans (true/false)
let arr = [1, 2, 3]    # Arrays
let dict = {"key": "value"}  # Dictionaries
let nothing = nil       # Nil
```

### Functions

```quest
fun add(a, b)
    a.plus(b)
end

# Lambdas
let double = fun (x) x.times(2) end
```

### Control Flow

```quest
# If/elif/else
if condition
    # code
elif other_condition
    # code
else
    # code
end

# While loops
while condition
    # code
end

# For loops
for i in 0 to 10
    # code
end

for item in array
    # code
end
```

### Operators

```quest
# Arithmetic
x.plus(y)    # or x + y
x.minus(y)   # or x - y
x.times(y)   # or x * y
x.div(y)     # or x / y

# Comparison
x == y
x != y
x < y
x > y

# Logical
x and y
x or y
not x

# String concatenation
"hello" .. " " .. "world"
```

## Next Steps

Now that you have Quest installed and understand the basics:

- Explore the [Language Reference](./language/index.md) for complete language documentation
- Check out the [Standard Library](./stdlib/index.md) to see available modules and functions
- Read about [Control Flow](./language/control-flow.md) and [Loops](./language/loops.md)
- Learn about the [Object System](./language/objects.md)

## Getting Help

- Read the error messages carefully—Quest provides helpful error messages
- Use the REPL to experiment and test ideas
- Check the [Examples](./examples/index.md) section for common patterns
