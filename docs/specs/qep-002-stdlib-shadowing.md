# QEP-002: Standard Library Shadowing

**Status:** Proposed
**Version:** 1.0
**Last Updated:** 2025-10-03
**QEP:** 002

## Overview

Quest supports **hybrid standard library modules** where Rust-implemented stdlib modules can be extended or overridden by Quest code in the `lib/` directory. This allows:

- User customization of stdlib behavior
- Prototyping new stdlib features in Quest before Rust implementation
- Project-specific convenience wrappers around core functionality
- Gradual migration from Quest to Rust implementations
- Documentation of Rust-implemented functions in Quest syntax using `%` prefix

## Motivation

**Problem:** Standard library modules are implemented in Rust for performance, but users may want to:
1. Add convenience methods without modifying Quest's source
2. Override specific functions for testing or debugging
3. Extend stdlib with project-specific utilities
4. Prototype new stdlib features rapidly
5. Write comprehensive documentation without recompiling Rust

**Solution:** When importing a stdlib module, Quest checks for a corresponding `.q` file in the `lib/` directory and merges it with the Rust implementation, with Quest code taking precedence. Documentation-only declarations using `%` prefix allow documenting Rust implementations without replacing them.

## How It Works

### Module Resolution Order

When `use "std/math" as math` is executed:

1. **Load Rust implementation** (if it exists)
   - Built-in module registered in interpreter
   - All Rust-implemented functions/constants are available

2. **Check for Quest overlay** in `lib/` directory:
   - **File module:** `lib/` + module path + `.q`
     - Example: `std/math` → `lib/std/math.q`
     - Example: `std/encoding/json` → `lib/std/encoding/json.q`
   - **Directory module:** `lib/` + module path + `/index.q`
     - Example: `std/encoding` → `lib/std/encoding/index.q`
     - Example: `std/db` → `lib/std/db/index.q`
   - **Resolution priority:** Check file first (`.q`), then directory (`/index.q`)

3. **Merge implementations**
   - Start with Rust module's namespace
   - Execute Quest file with access to the Rust module
   - Quest code can add new members or replace existing ones
   - Final merged module is what the user receives

### File System Structure

```
project/
├── lib/
│   └── std/
│       ├── math.q              # File module: use "std/math"
│       ├── str.q               # File module: use "std/str"
│       ├── encoding/
│       │   ├── index.q         # Directory module: use "std/encoding"
│       │   ├── json.q          # File module: use "std/encoding/json"
│       │   └── b64.q           # File module: use "std/encoding/b64"
│       └── db/
│           ├── index.q         # Directory module: use "std/db"
│           ├── sqlite.q        # File module: use "std/db/sqlite"
│           └── postgres.q      # File module: use "std/db/postgres"
├── .settings.toml
└── main.q
```

**Resolution Examples:**

| Import Statement | Resolution Path (Priority Order) |
|-----------------|----------------------------------|
| `use "std/math"` | 1. `lib/std/math.q`<br>2. `lib/std/math/index.q` |
| `use "std/encoding"` | 1. `lib/std/encoding.q`<br>2. `lib/std/encoding/index.q` ✓ |
| `use "std/encoding/json"` | 1. `lib/std/encoding/json.q` ✓<br>2. `lib/std/encoding/json/index.q` |
| `use "std/db"` | 1. `lib/std/db.q`<br>2. `lib/std/db/index.q` ✓ |

### When to Use Directory Modules

**Use `index.q` (directory module) when:**
- Module needs to provide its own functionality AND have related sub-modules
- You want hierarchical organization without flattening the namespace
- Parent and children are separate, independent modules
- Example: `std/encoding` has its own functions, while `std/encoding/json` is a separate module

**Use `.q` file (file module) when:**
- Module is self-contained
- No sub-modules needed
- Simple, focused functionality

**Example - Encoding Module Structure:**
```
lib/std/encoding/
├── index.q        # std/encoding module (general encoding utilities)
├── json.q         # std/encoding/json module (JSON-specific)
├── b64.q          # std/encoding/b64 module (Base64-specific)
└── hex.q          # std/encoding/hex module (Hex-specific)
```

**lib/std/encoding/index.q:**
```quest
"""
General encoding and decoding utilities.

For specific formats, see:
- std/encoding/json - JSON encoding/decoding
- std/encoding/b64 - Base64 encoding/decoding
- std/encoding/hex - Hexadecimal encoding/decoding
"""

# General encoding functions (part of std/encoding module itself)
fun detect_type(data)
    """Detect likely encoding type of string data."""
    if data.starts_with("{") or data.starts_with("[")
        "json"
    elif data.match("^[A-Fa-f0-9]+$")
        "hex"
    else
        "unknown"
    end
end

fun is_ascii(data)
    """Check if string contains only ASCII characters."""
    # Implementation...
end
```

**Usage - Independent Modules:**
```quest
# Import parent module for general utilities
use "std/encoding" as encoding
puts(encoding.detect_type('{"key": "value"}'))  # "json"
puts(encoding.is_ascii("hello"))  # true

# Import specific sub-modules independently
use "std/encoding/json" as json
use "std/encoding/b64" as b64

let data = {"key": "value"}
let json_str = json.stringify(data)
let encoded = b64.encode(json_str)
```

**Key Point:** `std/encoding`, `std/encoding/json`, and `std/encoding/b64` are **independent modules**. The parent module doesn't re-export children - it has its own distinct functionality.

## Documentation System

Quest uses a **lazy-loading documentation system** where documentation is only loaded from `lib/` overlay files when `_doc()` is called. This keeps Rust code lean and allows documentation to be updated without recompilation.

### Documentation Sources

**1. Module Documentation:**
- Module `_doc()` comes from the **first string literal** at the top of the overlay file
- Must appear before any code (can be after comments)
- Example: `math._doc()` loads from top of `lib/std/math.q`

**2. Rust Builtins - No Embedded Docs:**
- Rust implementations have **no** `_doc` strings stored
- Documentation is lazy-loaded from `lib/` overlay files on first `_doc()` call
- Uses `%` prefix declarations to mark documentation

**3. User-Defined Quest Functions - Inline Docstrings:**
- If the first statement after `fun` is a string literal, it becomes the `_doc()`
- Captured during function definition (stored in `QUserFun`)
- No special syntax needed
- Example:
  ```quest
  fun greet(name)
      """Greet someone by name."""
      "Hello, " .. name
  end

  puts(greet._doc())  # "Greet someone by name."
  ```

### Lazy Documentation Loading

**When `module._doc()` is called:**

1. **Check cache** - Is module doc already loaded?
2. **Load overlay** - Read `lib/{module_path}.q` or `lib/{module_path}/index.q`
3. **Parse first statement** - If it's a string literal, that's the module doc
4. **Cache result** - Store for future calls
5. **Return doc** - Or empty string if not found

**When `obj._doc()` is called on a Rust builtin function/type:**

1. **Check cache** - Is doc already loaded in memory?
2. **Load overlay** - Read `lib/{module_path}.q` or `lib/{module_path}/index.q`
3. **Parse for `%` declarations** - Find matching `%fun name(...)` followed by string
4. **Cache result** - Store for future calls
5. **Return doc** - Or empty string if not found

### Syntax for Rust Function Documentation

```quest
%fun function_name(params)

"""Documentation string"""
```

**Rules:**
1. Declaration starts with `%` followed by `fun`, `type`, or `trait`
2. The declaration is **parsed but ignored** (not registered in scope)
3. The **next line** must be a string literal (single, double, or triple-quoted)
4. That string is stored in a lazy-loaded cache for `_doc()` calls

### Supported Declaration Types

**Functions:**
```quest
%fun sin(x)

"""
Calculate the sine of x (in radians).

Parameters:
  x: Angle in radians (Num)

Returns: Num - Sine value between -1 and 1

Example:
  math.sin(0)      # 0.0
  math.sin(math.pi / 2)  # 1.0
"""
```

**Types:**
```quest
%type Connection

"""
Represents a database connection.

Methods:
  cursor() - Create a new cursor for executing queries
  close() - Close the connection
  commit() - Commit the current transaction
  rollback() - Roll back the current transaction
"""
```

**Traits:**
```quest
%trait Drawable

"""
Objects that can be rendered to the screen.

Required methods:
  draw() - Render the object
  bounds() - Get the bounding box as {x, y, width, height}
"""
```

### How It Works

1. **Parser Phase:**
   - Grammar recognizes `%fun`, `%type`, `%trait` as special declaration forms
   - Parses the declaration syntax (validates parameter names, etc.)
   - Extracts function/type/trait name

2. **Evaluator Phase:**
   - Skips execution of the declaration (doesn't register it)
   - Reads the next line for a string literal
   - Stores mapping: `name → doc_string` in a special registry

3. **Module Merging Phase:**
   - When merging Rust module with Quest overlay
   - For each Rust function/type, check doc registry
   - If doc exists, override the Rust `_doc()` with Quest version

### Example: Full Module Documentation

**lib/std/math.q:**
```quest
# Module-level documentation (first string literal in file)
"""
Mathematical functions and constants.

This module provides trigonometric functions, rounding operations,
and mathematical constants like pi and e.

Example:
  use "std/math" as math
  let angle = math.pi / 4
  let result = math.sin(angle)  # ~0.707
"""

# Document Rust-implemented functions
%fun sin(x)

"""
Calculate the sine of x.

Parameters:
  x: Num - Angle in radians

Returns: Num - Sine value between -1 and 1

Example:
  math.sin(0)           # 0.0
  math.sin(math.pi)     # ~0.0 (floating point)
  math.sin(math.pi / 2) # 1.0
"""

%fun cos(x)

"""
Calculate the cosine of x.

Parameters:
  x: Num - Angle in radians

Returns: Num - Cosine value between -1 and 1
"""

%fun sqrt(x)

"""
Calculate the square root of x.

Parameters:
  x: Num - Non-negative number

Returns: Num - Square root of x

Raises: ValueError if x < 0
"""

# Add new Quest-implemented function
fun degrees(radians)
    """Convert radians to degrees."""
    radians * 180 / __builtin__.pi
end

# Re-export Rust implementations (now with docs!)
let sin = __builtin__.sin
let cos = __builtin__.cos
let sqrt = __builtin__.sqrt
let pi = __builtin__.pi
```

**Result:**
```quest
use "std/math" as math

# Get module documentation
puts(math._doc())
# Outputs: "Mathematical functions and constants.\n\nThis module provides..."

# Get function documentation
puts(math.sin._doc())
# Outputs: "Calculate the sine of x.\n\nParameters:\n  x: Num - Angle in radians..."

let result = math.sin(0)  # Still calls Rust implementation
```

### String Literal Formats

All string formats are supported for documentation:

**Double quotes:**
```quest
%fun example()

"Short one-line description"
```

**Triple quotes (recommended for multi-line):**
```quest
%fun example()

"""
Multi-line documentation
with formatting preserved.

Supports markdown:
- Bullet points
- **Bold text**
- Code: `example()`
"""
```

**F-strings (evaluated at overlay load time):**
```quest
let VERSION = "1.0"

%fun example()

f"""
Documentation for version {VERSION}
"""
```

### Grammar Changes

**New rules in `quest.pest`:**

```pest
statement = _{
    doc_declaration
  | let_statement
  | assignment
  | if_statement
  | fun_declaration
  | type_declaration
  | trait_declaration
  | expression
}

doc_declaration = {
    "%" ~ (doc_fun | doc_type | doc_trait) ~ NEWLINE ~ doc_string
}

doc_fun = { "fun" ~ identifier ~ "(" ~ parameter_list? ~ ")" }
doc_type = { "type" ~ identifier }
doc_trait = { "trait" ~ identifier }

doc_string = {
    string_literal
  | fstring_literal
}
```

### Implementation Details

**Doc Cache Structure (Lazy-Loaded):**
```rust
// Global cache for lazy-loaded documentation
// Key format: "module_path:item_name" (e.g., "std/math:sin")
// Module docs: "module_path:__module__" (e.g., "std/math:__module__")
lazy_static! {
    static ref DOC_CACHE: RwLock<HashMap<String, String>> = RwLock::new(HashMap::new());
}

fn get_or_load_doc(module_path: &str, item_name: &str) -> String {
    let cache_key = format!("{}:{}", module_path, item_name);

    // Check cache first
    {
        let cache = DOC_CACHE.read().unwrap();
        if let Some(doc) = cache.get(&cache_key) {
            return doc.clone();
        }
    }

    // Not cached - load from lib/ overlay
    let doc = load_doc_from_overlay(module_path, item_name);

    // Cache for future calls
    {
        let mut cache = DOC_CACHE.write().unwrap();
        cache.insert(cache_key, doc.clone());
    }

    doc
}

fn load_doc_from_overlay(module_path: &str, item_name: &str) -> String {
    // Try file module first: lib/path.q
    let file_path = format!("lib/{}.q", module_path);
    let dir_path = format!("lib/{}/index.q", module_path);

    let overlay_path = if std::path::Path::new(&file_path).exists() {
        file_path
    } else if std::path::Path::new(&dir_path).exists() {
        dir_path
    } else {
        return String::new();  // No overlay file
    };

    let source = match std::fs::read_to_string(&overlay_path) {
        Ok(s) => s,
        Err(_) => return String::new(),
    };

    // Parse file for documentation
    if item_name == "__module__" {
        // Looking for module doc (first string literal)
        extract_module_doc(&source)
    } else {
        // Looking for %fun/%type/%trait declaration
        extract_item_doc(&source, item_name)
    }
}
```

**Rust Builtin Functions - No Doc Storage:**
```rust
// OLD WAY (don't do this):
QValue::Fun(QFun::new(
    "sin".to_string(),
    "math".to_string(),
    "Calculate sine...".to_string(),  // ❌ Don't store doc in Rust
))

// NEW WAY:
QValue::Fun(QFun::new(
    "sin".to_string(),
    "math".to_string(),
    String::new(),  // ✅ Empty string - will lazy load from lib/
))
```

**_doc() Method Implementation:**
```rust
impl QFun {
    fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "_doc" => {
                // Lazy load documentation
                let doc = get_or_load_doc(&self.module, &self.name);
                Ok(QValue::Str(QString::new(doc)))
            }
            _ => Err(format!("Unknown method: {}", method_name))
        }
    }
}
```

**Doc Declaration Evaluation (During Script Execution):**
```rust
fn eval_doc_declaration(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    // %fun declarations are IGNORED during normal script execution
    // They're only parsed when lazy-loading docs via _doc() calls

    // Skip the declaration entirely
    Ok(QValue::Nil(QNil))
}
```

**User Function Docstrings (Inline):**
```rust
fn eval_fun_declaration(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    let mut inner = pair.into_inner();
    let name = inner.next().unwrap().as_str().to_string();
    let params = parse_params(inner.next().unwrap());
    let body = inner.next().unwrap();

    // Check if first statement in body is a string literal
    let mut body_inner = body.into_inner();
    let first_stmt = body_inner.peek();

    let doc = if let Some(stmt) = first_stmt {
        if is_string_literal(stmt) {
            // Extract docstring
            eval_pair(stmt, scope)?.as_str()?
        } else {
            String::new()
        }
    } else {
        String::new()
    };

    let user_fun = QUserFun::new(name.clone(), params, body, doc);
    scope.set(&name, QValue::UserFun(user_fun));

    Ok(QValue::Nil(QNil))
}
```

**Module Loading (No Doc Merging):**
```rust
fn load_module(module_path: &str, scope: &mut Scope) -> Result<QValue, String> {
    // Load Rust module
    let rust_module = get_builtin_module(module_path)?;

    // Check for Quest overlay (file first, then directory)
    let file_path = format!("lib/{}.q", module_path);
    let dir_path = format!("lib/{}/index.q", module_path);

    let overlay_path = if std::path::Path::new(&file_path).exists() {
        Some(file_path)
    } else if std::path::Path::new(&dir_path).exists() {
        Some(dir_path)
    } else {
        None
    };

    if let Some(path) = overlay_path {
        let mut overlay_scope = Scope::new();
        overlay_scope.set("__builtin__", rust_module.clone());

        let overlay_source = std::fs::read_to_string(&path)?;
        eval_expression(&overlay_source, &mut overlay_scope)?;

        // Merge namespaces (no doc handling here - lazy loaded later)
        let mut merged_members = HashMap::new();

        // Add Rust members
        if let QValue::Module(m) = &rust_module {
            for (name, value) in m.members() {
                merged_members.insert(name.clone(), value.clone());
            }
        }

        // Overlay Quest additions/replacements
        for (key, value) in overlay_scope.variables() {
            if key != "__builtin__" {
                merged_members.insert(key.clone(), value.clone());
            }
        }

        Ok(QValue::Module(QModule::new(module_path.to_string(), merged_members)))
    } else {
        Ok(rust_module)
    }
}
```

### Benefits

1. **Lean Rust Code:** No doc strings stored in Rust - keeps binaries small
2. **Lazy Loading:** Documentation only loaded when `_doc()` is called
3. **No Recompilation:** Update docs without rebuilding Quest interpreter
4. **Single Source:** Documentation lives alongside overlay code
5. **Rich Formatting:** Use triple-quoted strings for markdown/formatting
6. **Fast Startup:** Module loading doesn't parse documentation
7. **Memory Efficient:** Docs cached only when accessed

### Use Case: Comprehensive Stdlib Docs

**lib/std/io.q:**
```quest
%fun read(path)

"""
Read entire file contents as a string.

Parameters:
  path: Str - File path (absolute or relative to CWD)

Returns: Str - File contents decoded as UTF-8

Raises:
  IOError - File doesn't exist or can't be read
  UnicodeError - File contains invalid UTF-8

Example:
  let content = io.read("config.json")
  let lines = content.split("\n")

See also: io.write(), io.append()
"""

%fun write(path, content)

"""
Write string to file (overwrites existing content).

Parameters:
  path: Str - File path
  content: Str - String to write (will be UTF-8 encoded)

Returns: Nil

Raises:
  IOError - Can't write to file (permissions, etc.)

Example:
  io.write("output.txt", "Hello, World!")

Warning: This OVERWRITES existing files. Use io.append() to add to files.
"""

%fun glob(pattern)

"""
Find files matching a glob pattern.

Parameters:
  pattern: Str - Glob pattern (* and ** wildcards)

Returns: Array[Str] - List of matching file paths

Example:
  io.glob("*.q")           # All .q files in current dir
  io.glob("src/**/*.rs")   # All .rs files in src/ (recursive)
  io.glob("test_*.q")      # Files starting with test_

Patterns:
  * - Matches any characters except /
  ** - Matches any characters including /
  ? - Matches single character
  [abc] - Matches one character from set
"""

# Re-export all with docs
let read = __builtin__.read
let write = __builtin__.write
let append = __builtin__.append
let remove = __builtin__.remove
let exists = __builtin__.exists
let is_file = __builtin__.is_file
let is_dir = __builtin__.is_dir
let size = __builtin__.size
let glob = __builtin__.glob
let glob_match = __builtin__.glob_match
```

## Quest Overlay File Format

Quest overlay files have access to a special `__builtin__` variable containing the original Rust implementation.

### Example: Extending `std/math`

**lib/std/math.q:**
```quest
# Access to Rust implementation via __builtin__
# __builtin__ contains: {pi: 3.14159..., sin: <fun>, cos: <fun>, ...}

# Add new convenience function
fun degrees(radians)
    radians * 180 / __builtin__.pi
end

fun radians(degrees)
    degrees * __builtin__.pi / 180
end

# Add new constant
let tau = __builtin__.pi * 2

# Override existing function (for debugging)
fun sin(x)
    puts("DEBUG: sin(", x, ")")
    __builtin__.sin(x)  # Call original Rust implementation
end

# Re-export everything from builtin that we didn't override
let pi = __builtin__.pi
let e = __builtin__.e
let cos = __builtin__.cos
let tan = __builtin__.tan
let sqrt = __builtin__.sqrt
let abs = __builtin__.abs
let floor = __builtin__.floor
let ceil = __builtin__.ceil
let round = __builtin__.round
```

**Usage in user code:**
```quest
use "std/math" as math

puts(math.tau)              # 6.283... (from Quest overlay)
puts(math.degrees(math.pi)) # 180 (from Quest overlay)
puts(math.sin(1.0))         # Prints debug message, returns sin(1.0)
puts(math.cos(0))           # 1.0 (original Rust implementation)
```

## Use Cases

### 1. Adding Convenience Wrappers

**lib/std/str.q:**
```quest
# Re-export all builtin methods
let upper = __builtin__.upper
let lower = __builtin__.lower
let trim = __builtin__.trim
# ... (all other builtin methods)

# Add convenience method
fun title_case(s)
    # Convert "hello world" to "Hello World"
    let words = s.split(" ")
    let titled = words.map(fun (word) word.capitalize() end)
    titled.join(" ")
end

fun snake_to_camel(s)
    let parts = s.split("_")
    let first = parts[0]
    let rest = parts[1:].map(fun (p) p.capitalize() end)
    first .. rest.join("")
end
```

### 2. Project-Specific Extensions

**lib/std/encoding/json.q:**
```quest
# Re-export builtins
let parse = __builtin__.parse
let stringify = __builtin__.stringify

# Add project-specific method
fun load_config(path)
    use "std/io" as io
    let content = io.read(path)
    parse(content)
end

fun save_config(path, data)
    use "std/io" as io
    let json = stringify(data, {pretty: true})
    io.write(path, json)
end
```

### 3. Testing and Debugging

**lib/std/db/postgres.q:**
```quest
# Wrap database operations with logging
let _original_connect = __builtin__.connect

fun connect(conn_string)
    puts("[DB] Connecting to: ", conn_string)
    let conn = _original_connect(conn_string)
    puts("[DB] Connection established")
    conn
end

# Re-export other functions
let version = __builtin__.version
```

### 4. Prototyping New Features

**lib/std/math.q:**
```quest
# Prototype new functions before implementing in Rust
fun clamp(value, min_val, max_val)
    if value < min_val
        min_val
    elif value > max_val
        max_val
    else
        value
    end
end

fun lerp(a, b, t)
    a + (b - a) * t
end

fun smoothstep(a, b, t)
    let clamped = clamp(t, 0.0, 1.0)
    let scaled = clamped * clamped * (3.0 - 2.0 * clamped)
    lerp(a, b, scaled)
end

# Re-export builtins
let pi = __builtin__.pi
let sin = __builtin__.sin
# ... etc
```

## Implementation Details

### Module Loading Process

```rust
fn load_module(module_path: &str, scope: &mut Scope) -> Result<QValue, String> {
    // 1. Check if Rust implementation exists
    let rust_module = get_builtin_module(module_path)?;

    // 2. Check for Quest overlay
    let overlay_path = format!("lib/{}.q", module_path);

    if std::path::Path::new(&overlay_path).exists() {
        // 3. Load Quest overlay with __builtin__ in scope
        let mut overlay_scope = Scope::new();
        overlay_scope.set("__builtin__", rust_module.clone());

        // 4. Execute overlay file
        let overlay_source = std::fs::read_to_string(&overlay_path)?;
        eval_expression(&overlay_source, &mut overlay_scope)?;

        // 5. Build merged module from overlay scope
        let mut merged_members = HashMap::new();

        // Copy all variables from overlay scope (except __builtin__)
        for (key, value) in overlay_scope.variables() {
            if key != "__builtin__" {
                merged_members.insert(key.clone(), value.clone());
            }
        }

        // 6. Return merged module
        Ok(QValue::Module(QModule::new(
            module_path.to_string(),
            merged_members
        )))
    } else {
        // No overlay, return Rust module as-is
        Ok(rust_module)
    }
}
```

### `__builtin__` Special Variable

- Type: `QValue::Module`
- Contains: All functions and constants from the Rust implementation
- Scope: Only available in overlay files during module loading
- Purpose: Allows Quest code to reference original implementations

### Re-export Pattern

Since Quest doesn't have a `from module import *` or `export * from module` syntax, overlay files must explicitly re-export any builtin members they want to keep:

```quest
# Manual re-export (verbose but explicit)
let pi = __builtin__.pi
let sin = __builtin__.sin
let cos = __builtin__.cos

# Or use a helper pattern
fun _copy_from_builtin(names)
    let result = {}
    for name in names
        result[name] = __builtin__.get(name)
    end
    result
end
```

**Note:** This verbosity is intentional - it makes overlay files explicit about what they're exposing.

## Limitations and Considerations

### 1. Performance

- Quest overlays execute on every module import
- If overlays are used frequently, consider caching
- Heavy computation in overlay files will slow imports

### 2. Module Identity

- Shadowed modules are still identified as their original type
- `math.sin._module()` returns `"std/math"` even if shadowed

### 3. Circular Dependencies

- Overlay files can import other modules
- Be careful of circular imports: `lib/std/a.q` uses `std/b`, `lib/std/b.q` uses `std/a`
- Interpreter should detect and error on circular dependencies

### 4. Debugging

- Errors in overlay files should clearly indicate the overlay file path
- Stack traces should show both Rust and Quest function calls

### 5. No Builtin Modification

- Overlay files cannot modify the `__builtin__` object
- They can only add to or replace the final module namespace

## Configuration

### Disabling Shadowing

Projects can disable shadowing via `.settings.toml`:

```toml
[interpreter]
allow_stdlib_shadowing = false  # Default: true
```

When disabled, Quest will not check for overlay files and only load Rust implementations.

### Custom Overlay Directory

```toml
[interpreter]
stdlib_overlay_dir = "lib"  # Default: "lib"
```

Allows projects to use a different directory structure.

## Security Considerations

1. **Trusted Code Only:** Overlay files have full access to the Rust stdlib implementation
2. **No Sandboxing:** Overlay code runs with same privileges as user code
3. **Version Control:** Overlay files should be committed to version control
4. **Code Review:** Changes to stdlib overlays should be reviewed carefully

## Implementation Considerations

### Directory Module Support

**Current Implementation:**
Quest's module system may need refactoring to support directory modules with `index.q`:

1. **Module Path Resolution:**
   - Currently: `use "std/math"` → load `std/math` builtin
   - With directory support: Check `lib/std/math.q` then `lib/std/math/index.q`

2. **Module Identity:**
   - `std/encoding` (from `index.q`) and `std/encoding/json` are distinct modules
   - Each has separate namespace, documentation, and state
   - No automatic parent-child relationship

3. **Import System Changes:**
   - File system checks added to module resolution
   - May need to track both Rust builtins and file-based modules
   - Circular dependency detection becomes more important

4. **Potential Challenges:**
   - Module caching strategy (file-based vs builtin)
   - Import path parsing (distinguish `std/encoding` module from `std/encoding` directory)
   - Error messages when both file and directory exist

### Migration Path

### Phase 1: Basic Implementation
- Load Rust module
- Check for overlay file (`.q` then `/index.q`)
- Execute overlay with `__builtin__` in scope
- Merge namespaces
- No directory module support yet (all modules are `.q` files)

### Phase 2: Directory Module Support
- Implement file vs directory resolution
- Support `index.q` in module directories
- Update module identity tracking
- Test nested module hierarchies

### Phase 3: Optimization
- Cache merged modules
- Lazy loading of overlays
- Better error messages
- Performance profiling

### Phase 4: Tooling
- CLI command to list shadowed modules
- Warnings for unused `__builtin__` references
- Helper functions for module introspection

## Testing Strategy

```quest
# test/stdlib_shadowing/math_overlay.q
use "std/test" as test

test.module("Standard Library Shadowing - Math")

test.describe("Extended math module", fun ()
    test.it("loads original Rust functions", fun ()
        use "std/math" as math
        let result = math.sin(0)
        test.assert_eq(result, 0, nil)
    end)

    test.it("includes Quest overlay additions", fun ()
        use "std/math" as math
        test.assert(math.tau != nil, "tau constant should exist")
        test.assert(math.degrees != nil, "degrees function should exist")
    end)

    test.it("Quest functions can call Rust implementations", fun ()
        use "std/math" as math
        let result = math.degrees(math.pi)
        test.assert_near(result, 180.0, 0.001)
    end)
end)
```

## Examples

### Example 1: Documentation + Extension (Recommended Pattern)

**lib/std/math.q:**
```quest
# Document Rust implementations with %
%fun sin(x)
"""Calculate sine of x (radians). Returns -1 to 1."""

%fun cos(x)
"""Calculate cosine of x (radians). Returns -1 to 1."""

%fun pi
"""Mathematical constant π ≈ 3.14159"""

# Add Quest extensions
fun degrees(radians)
    """Convert radians to degrees."""
    radians * 180 / __builtin__.pi
end

fun radians(degrees)
    """Convert degrees to radians."""
    degrees * __builtin__.pi / 180
end

let tau = __builtin__.pi * 2  # τ = 2π

# Re-export Rust implementations (now with docs!)
let pi = __builtin__.pi
let sin = __builtin__.sin
let cos = __builtin__.cos
let sqrt = __builtin__.sqrt
```

### Example 2: Simple Extension

**lib/std/math.q:**
```quest
let pi = __builtin__.pi
let sin = __builtin__.sin
let cos = __builtin__.cos

# Add convenience constant
let tau = pi * 2
```

### Example 3: Wrapper with Logging

**lib/std/io.q:**
```quest
use "std/os" as os

let _read = __builtin__.read
let _write = __builtin__.write

fun read(path)
    if os.getenv("DEBUG_IO") != nil
        puts("[IO] Reading: ", path)
    end
    _read(path)
end

fun write(path, content)
    if os.getenv("DEBUG_IO") != nil
        puts("[IO] Writing: ", path)
    end
    _write(path, content)
end

# Re-export others
let append = __builtin__.append
let remove = __builtin__.remove
let exists = __builtin__.exists
```

### Example 4: Directory Module with index.q

**lib/std/encoding/index.q:**
```quest
"""
General encoding and decoding utilities.

This module provides utilities that work across different encoding formats.
For format-specific operations, see:
  - std/encoding/json - JSON encoding/decoding
  - std/encoding/b64 - Base64 encoding/decoding
"""

# Functions specific to the std/encoding module itself
fun detect_type(data)
    """Detect the likely encoding type of string data."""
    if data.starts_with("{") or data.starts_with("[")
        "json"
    elif data.match("^[A-Fa-f0-9]+$")
        "hex"
    elif data.match("^[A-Za-z0-9+/]+=*$")
        "base64"
    else
        "unknown"
    end
end

fun is_printable(data)
    """Check if string contains only printable characters."""
    # Implementation...
end

%fun detect_type(data)

"""
Detect the likely encoding type of string data.

Parameters:
  data: Str - String to analyze

Returns: Str - One of "json", "hex", "base64", "unknown"
"""
```

**Usage:**
```quest
# Import parent module (has its own functionality)
use "std/encoding" as encoding
puts(encoding.detect_type('{"key": "value"}'))  # "json"

# Import sub-modules independently
use "std/encoding/json" as json
use "std/encoding/b64" as b64

let data = {"key": "value"}
let json_str = json.stringify(data)  # Use json module
let encoded = b64.encode(json_str)    # Use b64 module

# Parent and children are separate - no cross-access
# encoding.json would be nil (not re-exported)
```

### Example 5: Full Replacement

**lib/std/mymodule.q:**
```quest
# Completely ignore __builtin__ and provide pure Quest implementation
fun my_function()
    "This is a Quest-only implementation"
end

let my_constant = 42
```

## Open Questions

1. Should overlay files be able to access `__builtin__.__builtin__`? (nested shadowing)
2. Should there be a way to list all shadowed modules at runtime?
3. Should Quest warn if overlay file doesn't use `__builtin__`?
4. Should there be a standard helper for bulk re-exporting?

## Future Enhancements

1. **Selective Re-export:** `export * from __builtin__ except [sin, cos]`
2. **Overlay Composition:** Multiple overlay layers
3. **Hot Reloading:** Reload overlays without restarting
4. **Performance Profiling:** Track overlay execution time
