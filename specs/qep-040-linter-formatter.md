# QEP-040: Rule-Based Linter and Formatter

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-07

## Abstract

This QEP proposes a rule-based linter and formatter for Quest, similar to Ruff for Python but simpler to start. The tool will be implemented in Rust as part of the Quest toolchain, providing fast code analysis and automatic formatting with configurable rules.

**Rating:** TBD

## Motivation

### Current Limitations

Quest currently lacks tooling for:
- **Code quality enforcement** - No way to enforce style guidelines
- **Automatic formatting** - Manual formatting is tedious and inconsistent
- **Best practice detection** - Common mistakes go unnoticed
- **Team consistency** - Different developers write code differently

### Problems This Causes

1. **Inconsistent codebases** - Each developer has their own style
2. **Time wasted on formatting** - Manual formatting takes time and focus
3. **Code review friction** - Style debates in reviews instead of logic discussions
4. **Subtle bugs** - Common anti-patterns aren't caught early
5. **Onboarding difficulty** - New contributors don't know the conventions

### Solution

A fast, configurable linter and formatter that:
- Runs in milliseconds (Rust performance)
- Integrates with editors (LSP support future)
- Enforces team style rules
- Auto-fixes formatting issues
- Detects common bugs and anti-patterns

```bash
# Format code
quest fmt src/

# Lint with auto-fix
quest lint --fix src/

# Check without fixing
quest lint src/
```

## Design Principles

### 1. Fast by Default

Built in Rust for speed:
- Parse entire codebase in milliseconds
- Enable "format on save" without lag
- Run in CI without slowing builds

### 2. Rule-Based Architecture

Each rule is independent and configurable:
- Easy to add new rules
- Can enable/disable per project
- Clear rule names and documentation

### 3. Auto-Fix First

Prefer auto-fixable rules:
- Formatting rules always auto-fix
- Lint rules fix when safe
- Manual fixes only when necessary

### 4. Configurable

Project-level configuration:
```toml
# .quest.toml or quest.toml
[linter]
max_line_length = 100
indent_size = 4
indent_style = "space"  # or "tab"

[linter.rules]
# Enable/disable specific rules
unused_variables = "error"    # error, warn, ignore
missing_docstrings = "warn"
prefer_single_quotes = "error"
```

### 5. Clear Error Messages

Helpful output with context:
```
src/main.q:15:5: error[unused-variable]: Variable 'x' is defined but never used
   |
15 |     let x = 10
   |         ^ unused variable
   |
   = help: Remove the variable or prefix with '_' to indicate intentionally unused
```

## Specification

### Command-Line Interface

```bash
# Format files/directories
quest fmt [OPTIONS] <PATH>...
  --check          Check formatting without modifying files
  --diff           Show formatting changes
  --config <FILE>  Use specific config file

# Lint files/directories
quest lint [OPTIONS] <PATH>...
  --fix            Auto-fix issues where possible
  --rules <RULES>  Only run specific rules (comma-separated)
  --ignore <RULES> Ignore specific rules
  --config <FILE>  Use specific config file
  --json           Output as JSON
  --format <FMT>   Output format: text, json, github

# Check both format and lint (CI mode)
quest check <PATH>...
```

### Configuration File Format

`.quest.toml` in project root:

```toml
[linter]
# Formatting options
max_line_length = 100
indent_size = 4
indent_style = "space"  # "space" or "tab"
quote_style = "double"  # "single" or "double"
trailing_comma = true
max_blank_lines = 2

# Lint rule configuration
[linter.rules]
# Error/warn/ignore for each rule
unused_variables = "error"
unused_imports = "error"
missing_docstrings = "warn"
prefer_single_quotes = "ignore"
no_shadowing = "warn"
explicit_return = "warn"

# Rule-specific options
[linter.rules.max_function_length]
level = "warn"
max_lines = 50

[linter.rules.max_complexity]
level = "warn"
max_complexity = 10

# Ignore patterns
[linter.ignore]
paths = ["test/**/*", "vendor/**/*"]
rules = ["missing_docstrings"]  # Ignore globally
```

### Architecture

```
quest-lint/
├── src/
│   ├── lib.rs           # Public API
│   ├── config.rs        # Configuration parsing
│   ├── parser.rs        # Reuse Quest parser
│   ├── formatter/
│   │   ├── mod.rs       # Formatter entry point
│   │   ├── indentation.rs
│   │   ├── spacing.rs
│   │   └── quotes.rs
│   ├── linter/
│   │   ├── mod.rs       # Linter entry point
│   │   ├── rule.rs      # Rule trait
│   │   ├── diagnostic.rs
│   │   └── rules/
│   │       ├── mod.rs
│   │       ├── unused_variables.rs
│   │       ├── unused_imports.rs
│   │       ├── missing_docstrings.rs
│   │       └── ...
│   └── main.rs          # CLI entry point
└── tests/
    ├── formatter/
    └── linter/
```

### Rule Trait

```rust
pub trait Rule {
    /// Rule identifier (e.g., "unused-variable")
    fn id(&self) -> &str;

    /// Human-readable description
    fn description(&self) -> &str;

    /// Check if rule is enabled in config
    fn is_enabled(&self, config: &Config) -> bool;

    /// Get severity level (error, warn, ignore)
    fn level(&self, config: &Config) -> Level;

    /// Check AST and return diagnostics
    fn check(&self, ast: &Program) -> Vec<Diagnostic>;

    /// Auto-fix if possible (returns modified source)
    fn fix(&self, source: &str, diagnostic: &Diagnostic) -> Option<String>;
}

pub struct Diagnostic {
    pub rule_id: String,
    pub level: Level,
    pub message: String,
    pub span: Span,
    pub help: Option<String>,
    pub auto_fixable: bool,
}

pub enum Level {
    Error,
    Warn,
    Ignore,
}
```

## Formatting Rules

### 1. Indentation

**Rule:** Consistent indentation (spaces or tabs)

**Before:**
```quest
fun example()
  let x = 10
    if x > 5
        puts("large")
  end
end
```

**After:**
```quest
fun example()
    let x = 10
    if x > 5
        puts("large")
    end
end
```

### 2. Line Length

**Rule:** Max line length (default 100)

**Before:**
```quest
let result = some_very_long_function_name(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8)
```

**After:**
```quest
let result = some_very_long_function_name(
    arg1, arg2, arg3, arg4,
    arg5, arg6, arg7, arg8
)
```

### 3. Quote Style

**Rule:** Consistent quotes (single or double)

**Before:**
```quest
let name = 'Alice'
let greeting = "Hello"
```

**After (double quotes):**
```quest
let name = "Alice"
let greeting = "Hello"
```

### 4. Trailing Whitespace

**Rule:** Remove trailing whitespace

**Before:**
```quest
let x = 10
let y = 20
```

**After:**
```quest
let x = 10
let y = 20
```

### 5. Blank Lines

**Rule:** Max consecutive blank lines (default 2)

**Before:**
```quest
fun foo()
    let x = 10
end



fun bar()
    let y = 20
end
```

**After:**
```quest
fun foo()
    let x = 10
end

fun bar()
    let y = 20
end
```

## Linting Rules

### Category: Code Quality

#### unused-variable

Detect variables that are defined but never used:

```quest
fun example()
    let x = 10  # ← Error: unused variable
    let y = 20
    puts(y)
end
```

**Fix:** Remove or prefix with `_`:
```quest
fun example()
    let _x = 10  # OK - explicitly unused
    let y = 20
    puts(y)
end
```

#### unused-import

Detect unused module imports:

```quest
use "std/math"
use "std/json"  # ← Warning: unused import

puts("Hello")
```

#### no-shadowing

Warn about variable shadowing:

```quest
let x = 10

fun foo()
    let x = 20  # ← Warning: shadows outer 'x'
    puts(x)
end
```

#### unreachable-code

Detect code after return:

```quest
fun example()
    return 10
    puts("never runs")  # ← Warning: unreachable
end
```

### Category: Best Practices

#### missing-docstrings

Warn about missing docstrings on public functions:

```quest
# ← Warning: missing docstring
fun public_api(x)
    x * 2
end
```

**Fix:**
```quest
# Doubles the input value
fun public_api(x)
    x * 2
end
```

#### explicit-return

Prefer explicit return statements:

```quest
fun add(x, y)
    x + y  # ← Warning: implicit return
end
```

**Fix:**
```quest
fun add(x, y)
    return x + y
end
```

#### prefer-const

Suggest const for immutable values:

```quest
let PI = 3.14159  # ← Warning: use 'const' for constants
```

**Fix:**
```quest
const PI = 3.14159
```

### Category: Complexity

#### max-function-length

Warn about overly long functions:

```quest
fun very_long_function()
    # ... 100+ lines ...
end
# ← Warning: function exceeds 50 lines
```

#### max-complexity

Warn about high cyclomatic complexity:

```quest
fun complex_function(x)
    if x > 0
        if x < 10
            if x % 2 == 0
                # ... many nested conditions ...
            end
        end
    end
end
# ← Warning: cyclomatic complexity 15 (max 10)
```

### Category: Potential Bugs

#### division-by-zero

Detect obvious division by zero:

```quest
let x = 10 / 0  # ← Error: division by zero
```

#### missing-nil-check

Warn about potential nil access:

```quest
fun foo(x)
    x.method()  # ← Warning: 'x' might be nil
end
```

#### type-mismatch

Detect type mismatches (when types are annotated):

```quest
fun add(x: Int, y: Int)
    return x + y
end

add(10, "20")  # ← Error: expected int, got str
```

## Examples

### Example 1: Basic Formatting

**Input (`main.q`):**
```quest
use "std/io"
fun greet(name,greeting="Hello")
{puts(greeting..', '..name)}
let x=10
if x>5{puts('large')}
```

**Command:**
```bash
quest fmt main.q
```

**Output:**
```quest
use "std/io"

fun greet(name, greeting = "Hello")
    puts(greeting .. ", " .. name)
end

let x = 10
if x > 5
    puts("large")
end
```

### Example 2: Linting with Auto-Fix

**Input:**
```quest
fun calculate()
    let unused = 10
    let result = 20
    return result
end
```

**Command:**
```bash
quest lint --fix main.q
```

**Output:**
```
main.q:2:9: warning[unused-variable]: Variable 'unused' is defined but never used
  |
2 |     let unused = 10
  |         ^^^^^^ unused variable
  |
  = help: Remove or prefix with '_'

Fixed 1 issue automatically.
```

**Modified file:**
```quest
fun calculate()
    let result = 20
    return result
end
```

### Example 3: CI Integration

```yaml
# .github/workflows/lint.yml
name: Lint

on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Quest
        run: cargo install --path .
      - name: Check formatting
        run: quest fmt --check src/
      - name: Run linter
        run: quest lint src/
```

### Example 4: Editor Integration

**VS Code settings:**
```json
{
  "quest.formatOnSave": true,
  "quest.lintOnSave": true,
  "quest.maxLineLength": 100
}
```

## Implementation Plan

### Phase 1: Formatter Core (MVP)
- [ ] Command-line interface (`quest fmt`)
- [ ] Configuration file parsing (`.quest.toml`)
- [ ] Basic formatting rules:
  - [ ] Indentation normalization
  - [ ] Whitespace cleanup
  - [ ] Blank line limits
  - [ ] Quote style normalization
- [ ] `--check` mode (exit code for CI)
- [ ] `--diff` mode (show changes)

### Phase 2: Linter Core (MVP)
- [ ] Command-line interface (`quest lint`)
- [ ] Rule trait and diagnostic system
- [ ] Basic lint rules:
  - [ ] unused-variable
  - [ ] unused-import
  - [ ] unreachable-code
  - [ ] division-by-zero
- [ ] `--fix` mode for auto-fixable rules
- [ ] Configuration for rule levels

### Phase 3: Additional Rules
- [ ] Code quality rules:
  - [ ] no-shadowing
  - [ ] missing-docstrings
  - [ ] explicit-return
  - [ ] prefer-const
- [ ] Complexity rules:
  - [ ] max-function-length
  - [ ] max-complexity
  - [ ] max-parameters
- [ ] Best practice rules:
  - [ ] missing-nil-check
  - [ ] prefer-early-return
  - [ ] no-nested-ifs

### Phase 4: Advanced Features
- [ ] JSON output for editor integration
- [ ] GitHub Actions format (annotations)
- [ ] Rule documentation generator
- [ ] Performance optimizations (parallel processing)
- [ ] Watch mode (`--watch`)

### Phase 5: LSP Integration (Future)
- [ ] Language server protocol support
- [ ] Real-time linting in editors
- [ ] Code actions (quick fixes)
- [ ] Hover documentation for rules

## Testing Strategy

### Formatter Tests

```rust
#[test]
fn test_indentation_normalization() {
    let input = r#"
fun foo()
  let x = 10
    if x > 5
        puts("large")
  end
end
"#;

    let expected = r#"
fun foo()
    let x = 10
    if x > 5
        puts("large")
    end
end
"#;

    assert_eq!(format_code(input), expected);
}
```

### Linter Tests

```rust
#[test]
fn test_unused_variable_detection() {
    let source = r#"
fun foo()
    let x = 10
    let y = 20
    puts(y)
end
"#;

    let diagnostics = lint_code(source);
    assert_eq!(diagnostics.len(), 1);
    assert_eq!(diagnostics[0].rule_id, "unused-variable");
    assert_eq!(diagnostics[0].level, Level::Error);
}
```

## Benefits

1. **Improved code quality** - Catch bugs early
2. **Consistent style** - Automatic formatting
3. **Faster development** - No manual formatting
4. **Better reviews** - Focus on logic, not style
5. **Easy onboarding** - Clear conventions
6. **CI integration** - Enforce standards
7. **Editor support** - Real-time feedback

## Limitations

1. **Initial scope** - Start simple, grow over time
2. **AST-based only** - No semantic analysis initially
3. **Configuration complexity** - Too many options can overwhelm
4. **False positives** - Some rules may have edge cases
5. **Performance** - Large codebases need optimization

## Future Enhancements

1. **Custom rules** - Plugin system for project-specific rules
2. **Auto-fix suggestions** - Multiple fix options for one issue
3. **Rule explanations** - Detailed documentation in output
4. **Incremental linting** - Only check changed files
5. **Rule groups** - Preset configurations (strict, relaxed, etc.)
6. **Git integration** - Only lint changed lines
7. **Performance profiling** - Show which rules are slow

## Alternatives Considered

### Alternative 1: Separate Tools

**Rejected:** Having separate `qfmt` and `qlint` tools adds complexity.

**Decision:** Unified `quest` CLI with subcommands.

### Alternative 2: Python Implementation

**Rejected:** Would be slower and require Python dependency.

**Decision:** Rust for performance and integration with main Quest binary.

### Alternative 3: No Auto-Fix

**Rejected:** Manual fixes are tedious and error-prone.

**Decision:** Auto-fix is a core feature for formatter and safe lint rules.

## References

- [Ruff](https://github.com/astral-sh/ruff) - Fast Python linter in Rust
- [rustfmt](https://github.com/rust-lang/rustfmt) - Rust code formatter
- [clippy](https://github.com/rust-lang/rust-clippy) - Rust linter
- [ESLint](https://eslint.org/) - JavaScript linter
- [Black](https://github.com/psf/black) - Python code formatter
- [Prettier](https://prettier.io/) - Opinionated code formatter

## See Also

- [QEP-015: Type Annotations](qep-015-type-annotations.md) - For type checking rules
- [QEP-039: Bytecode Interpreter](qep-039-hybrid-bytecode-interpreter.md) - Performance considerations

## Copyright

This document is placed in the public domain.
