# Quest Syntax Highlighting for Docusaurus

This document explains the custom Quest syntax highlighting implementation for the documentation site.

## Overview

The documentation site now has full syntax highlighting support for Quest code blocks. When you use ` ```quest ` in markdown files, the code will be syntax highlighted with proper colors for keywords, strings, comments, etc.

## Files Created

### 1. `/docs/src/theme/prism-include-languages.js`
This file integrates the Quest language definition with Docusaurus. The Quest language definition is defined inline in this file. It defines:

- **Comments**: `# comment syntax`
- **Strings**: Both regular strings `"text"` and multi-line docstrings `"""text"""`
- **Keywords**: `if`, `elif`, `else`, `end`, `while`, `for`, `in`, `fun`, `return`, `let`, `use`, `as`, `type`, `trait`, `impl`, `static`, `and`, `or`, `not`, `nil`, `true`, `false`
- **Built-in functions**: `puts`, `print`, `len`, `ticks_ms`
- **Function calls**: Highlights function names before `()`
- **Numbers**: Integers, floats, hex numbers, scientific notation
- **Operators**: All Quest operators including `..`, `++`, `--`, `==`, `!=`, etc.
- **Property access**: Method calls and member access with `.`
- **Booleans**: `true`, `false`
- **Constants**: `nil`
- **Class names**: Capitalized identifiers (Type names)

### 2. `/docs/docusaurus.config.ts` (modified)
Updated the Prism configuration to include Quest as an additional language:

```typescript
prism: {
  theme: prismThemes.github,
  darkTheme: prismThemes.dracula,
  additionalLanguages: ['quest'],  // ← Added this line
},
```

## Usage in Documentation

Simply use the `quest` language identifier in code fences:

````markdown
```quest
let greeting = "Hello, World!"
puts(greeting)

fun fibonacci(n)
    if n <= 1
        n
    else
        fibonacci(n - 1) + fibonacci(n - 2)
    end
end

puts(fibonacci(10))
```
````

## Language Alias

The syntax highlighter also supports `q` as an alias for `quest`:

````markdown
```q
# This also works!
let x = 42
```
````

## Color Themes

The syntax highlighting adapts to both light and dark themes:
- **Light mode**: Uses GitHub theme
- **Dark mode**: Uses Dracula theme

Both themes will properly colorize Quest code according to the token types defined in `prism-quest.js`.

## Testing

To verify syntax highlighting is working:

1. Start the dev server: `npm start`
2. Navigate to any documentation page with Quest code examples
3. Check that:
   - Keywords are highlighted (e.g., `if`, `let`, `fun`)
   - Strings are colored differently
   - Comments are distinct
   - Functions and methods are highlighted
   - Operators are visible

## Extending the Syntax Definition

To add more syntax highlighting rules, edit `/docs/src/theme/prism-quest.js`:

1. Add new patterns to the language definition
2. Use appropriate token types: `keyword`, `string`, `comment`, `function`, `operator`, etc.
3. Order matters - patterns are matched in the order they appear
4. Use the `greedy` flag for patterns that should capture as much as possible

Example of adding a new keyword:

```javascript
'keyword': /\b(?:if|elif|else|end|while|for|in|fun|return|let|use|as|type|trait|impl|static|and|or|not|nil|true|false|break|continue)\b/,
//                                                                                                                    ^^^^^^^^^^^^^ add new keywords here
```

## Troubleshooting

If syntax highlighting isn't working:

1. **Clear cache**: `npm run clear` then `npm run build`
2. **Check browser console**: Look for JavaScript errors
3. **Verify language tag**: Make sure code blocks use ` ```quest ` not ` ```javascript ` or other tags
4. **Rebuild**: Stop the dev server and run `npm run build` to verify no build errors

## Future Enhancements

Potential improvements:

- Add support for f-strings with embedded expressions
- Highlight module names after `use` keyword
- Add special highlighting for type annotations
- Support for regex patterns if Quest adds them
- Highlight magic methods like `_str`, `_rep`, `_doc`
