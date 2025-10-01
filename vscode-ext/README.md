# Quest VSCode Extension

Language support for the Quest programming language.

## Features

- **Syntax Highlighting**: Full syntax highlighting for Quest code
- **Language Server**: IntelliSense, diagnostics, and code completion
- **Auto-completion**: Keywords, built-in functions, and methods
- **Hover Information**: Documentation on hover for functions and keywords
- **Diagnostics**: Real-time error detection for unbalanced if/end blocks
- **Auto-closing Pairs**: Automatic closing of parentheses, brackets, and quotes
- **Code Folding**: Fold if/fun/while/for blocks

## Installation

### From Source

1. Install dependencies:
   ```bash
   cd vscode-ext
   npm install
   cd client && npm install && cd ..
   cd server && npm install && cd ..
   ```

2. Compile the extension:
   ```bash
   npm run compile
   ```

3. Open the `vscode-ext` directory in VSCode and press F5 to launch the extension in debug mode.

### Installing the Extension

To install the extension permanently:

```bash
vsce package
code --install-extension quest-vscode-0.1.0.vsix
```

## Quest Language Features

Quest is a Ruby-inspired programming language where everything is an object. Key features:

- Object-oriented with method calls on all values
- Dynamic typing
- REPL with multi-line support
- Control flow: if/elif/else blocks
- Variables with `let` declarations
- Built-in functions: `puts()`, `print()`

### Example Code

```quest
# Variables
let x = 10
let name = "Quest"

# Method calls
puts(3.plus(5))
puts("hello".upper())

# Control flow
if x > 5
    puts("x is large")
else
    puts("x is small")
end

# Inline if
let result = "positive" if x > 0 else "negative"
```

## Development

- `npm run compile`: Compile TypeScript
- `npm run watch`: Watch for changes and compile
- Press F5 in VSCode to launch extension development host

## License

MIT
