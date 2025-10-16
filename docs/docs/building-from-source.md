# Building from Source

This guide explains how to build Quest from source code. This is useful if you want to:

- Contribute to Quest development
- Use the latest unreleased features
- Customize the build
- Debug or profile the interpreter

## Prerequisites

You'll need:

- **Rust toolchain** (rustc, cargo) - Install from [rust-lang.org](https://rust-lang.org)
- **Git** - To clone the repository

## Clone the Repository

```bash
git clone https://github.com/lolsborn/quest.git
cd quest
```

## Build the Project

Build Quest in release mode for optimal performance:

```bash
cargo build --release
```

The build process will:
1. Download and compile dependencies
2. Compile the Quest interpreter
3. Create the executable at `./target/release/quest`

### Debug Build

For development, you can build without optimizations:

```bash
cargo build
```

This creates a debug build at `./target/debug/quest` that compiles faster but runs slower.

## Running the Built Executable

After building, you can run Quest directly:

```bash
./target/release/quest
```

Or run a script:

```bash
./target/release/quest your_script.q
```

## Adding to Your PATH

To use the `quest` command from anywhere, you have several options:

### Option 1: Create an Alias

Add to `~/.bashrc` or `~/.zshrc`:

```bash
alias quest='/path/to/quest/target/release/quest'
```

Then reload your shell:

```bash
source ~/.bashrc  # or ~/.zshrc
```

### Option 2: Symlink to a PATH Directory

```bash
sudo ln -s /path/to/quest/target/release/quest /usr/local/bin/quest
```

### Option 3: Add to PATH

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="/path/to/quest/target/release:$PATH"
```

## Running Tests

Quest has a comprehensive test suite:

```bash
# Run Rust unit tests
cargo test

# Run Quest test suite
./target/release/quest scripts/test.q test/

# Verbose output
./target/release/quest scripts/test.q -v test/
```

## Development Workflow

### Watch for Changes

Use `cargo watch` for automatic rebuilds during development:

```bash
cargo install cargo-watch
cargo watch -x build
```

### Running Examples

Quest includes example programs in the `examples/` directory:

```bash
./target/release/quest examples/hello.q
```

### Debugging

Build with debug symbols and run with debugger:

```bash
cargo build
lldb ./target/debug/quest  # macOS
gdb ./target/debug/quest   # Linux
```

## Troubleshooting

### Build Failures

If the build fails:

1. Ensure Rust is up to date: `rustup update`
2. Clean the build directory: `cargo clean`
3. Try rebuilding: `cargo build --release`

### Missing Dependencies

On Linux, you may need additional system packages:

```bash
# Ubuntu/Debian
sudo apt-get install build-essential pkg-config libssl-dev

# Fedora
sudo dnf install gcc pkg-config openssl-devel
```

## Next Steps

- Return to [Getting Started](./getting-started.md) to learn how to use Quest
- Read the [Language Reference](./language/index.md) for language documentation
- Explore the [Standard Library](./stdlib/index.md) for available modules
