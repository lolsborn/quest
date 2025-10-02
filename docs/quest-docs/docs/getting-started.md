# Getting Started

This guide will help you install Quest and write your first program.

## Prerequisites

Quest is implemented in Rust. To build from source, you'll need:

- Rust toolchain (rustc, cargo) - Install from [rust-lang.org](https://rust-lang.org)
- Git (to clone the repository)

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/yourusername/quest.git
cd quest
```

2. Build the project:
```bash
cargo build --release
```

3. The Quest executable will be located at:
```bash
./target/release/quest
```

4. (Optional) Add to your PATH or create an alias:
```bash
# Add to ~/.bashrc or ~/.zshrc
alias quest='/path/to/quest/target/release/quest'
```

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
./target/release/quest
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
./target/release/quest hello.q
```

Output:
```text
Hello, World!
The sum of 5 and 10 is 15
```

### Using Standard Input

Quest can also read from standard input:

```bash
echo 'puts("Hello from stdin!")' | ./target/release/quest
```

Or:

```bash
./target/release/quest < script.q
```

## Project Scripts with `quest run`

Quest supports a project configuration file (`project.yaml`) that lets you define named scripts, similar to `npm run` in Node.js.

### Creating project.yaml

Create a `project.yaml` file in your project root:

```yaml
scripts:
  test: test/run.q
  hello: examples/hello.q
  build: ./build.sh
  format: /usr/bin/rustfmt
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

1. Quest looks for `project.yaml` in the current directory
2. Finds the script path in the `scripts:` section
3. If the path ends in `.q`, Quest runs it as a Quest script
4. Otherwise, Quest spawns it as an executable
5. All paths are resolved relative to the `project.yaml` file location

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
Script: test/run.q
Args: [arg1, arg2]
```

### Example Workflow

```bash
# Create project.yaml
cat > project.yaml << 'EOF'
scripts:
  test: test/run.q
  hello: examples/hello.q
  clean: rm -rf build/
EOF

# Run scripts
quest run test          # Runs test/run.q
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
