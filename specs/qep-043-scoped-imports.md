# QEP-043: Scoped Imports and Module Aliasing

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-07
**Related:** QEP-018 (Dynamic Module Loading)

## Abstract

This QEP proposes **scoped import syntax** that allows importing specific functions/types from modules instead of requiring full module prefixes. It introduces two complementary patterns:

1. **Selective imports**: Import specific names from a module into the current scope
2. **Module aliasing with selective imports**: Combine aliased modules with selective imports

This improves ergonomics while maintaining clarity and avoiding namespace pollution.

## Motivation

### Current State

Quest currently requires full module prefixes for all module functions:

```quest
use "std/io"
use "std/os"

# Must always use full prefix
io.read("file.txt")
os.getcwd()
io.write("output.txt", data)
```

This is verbose when using the same functions repeatedly:

```quest
use "std/http/client" as http
use "std/encoding/json" as json

# Repetitive prefixes in data processing
let response = http.get("https://api.example.com/data")
let data = json.parse(response.text())
let modified = json.stringify(transform(data))
http.post("https://api.example.com/save", body: modified)
```

### Problems This Causes

1. **Verbosity** - Repetitive module prefixes clutter code
   ```quest
   io.read(io.join(os.getcwd(), "config.json"))
   # Multiple prefixes in a single expression
   ```

2. **Difficult refactoring** - Moving commonly-used functions requires updating all call sites
   ```quest
   # Want to use json.parse frequently
   json.parse(json.parse(json.parse(nested)))  # Tedious
   ```

3. **Inconsistent with type constructors** - Types are imported into scope but functions aren't
   ```quest
   use "std/uuid"

   # Type is available without prefix
   let id: Uuid = uuid.v4()  # But function needs prefix!
   ```

4. **No way to avoid naming conflicts** - Can't import two modules with same function names
   ```quest
   use "std/db/postgres" as pg
   use "std/db/mysql" as my

   # Both have 'connect' - must use prefixes
   pg.connect(...)
   my.connect(...)
   # Can't just say connect(...) for the one you use most
   ```

### Solution: Scoped Imports

```quest
# Import specific names into current scope
use "std/encoding/json" {parse, stringify}

let data = parse(response.text())  # No prefix needed!
let output = stringify(data)

# Combine with aliasing for rest of module
use "std/http/client" as http {get, post}

let response = get("https://api.example.com")  # Imported name
http.put("https://api.example.com/update")     # Prefixed for non-imported

# Rename imports to avoid conflicts
use "std/db/postgres" {connect as pg_connect}
use "std/db/mysql" {connect as my_connect}

pg_connect("postgres://...")
my_connect("mysql://...")
```

## Proposal

### Syntax

**Pattern 1: Selective imports only**
```quest
use "module/path" {name1, name2, name3}
```

**Pattern 2: Selective imports with renaming**
```quest
use "module/path" {name1 as alias1, name2, name3 as alias3}
```

**Pattern 3: Module alias + selective imports**
```quest
use "module/path" as alias {name1, name2}
```

**Pattern 4: Mix aliasing and renaming**
```quest
use "module/path" as alias {name1 as new_name, name2}
```

### Semantics

1. **Imported names** are bound in the current scope (no prefix required)
2. **Aliased module** (if provided) gives access to all module functions via prefix
3. **Name conflicts** with existing variables/functions raise an error
4. **Renamed imports** (`name as alias`) bind under the new name
5. **Type names** can be imported just like functions

### Grammar

```pest
use_statement = {
    "use" ~ string_literal ~ (as_clause)? ~ (import_list)? ~ newline
}

as_clause = { "as" ~ identifier }

import_list = {
    "{" ~ import_item ~ ("," ~ import_item)* ~ ","? ~ "}"
}

import_item = {
    identifier ~ (as_clause)?
}
```

### Evaluation

```rust
pub struct ImportDirective {
    pub module_path: String,
    pub module_alias: Option<String>,      // "as alias"
    pub selective_imports: Vec<ImportItem>, // {name1, name2}
}

pub struct ImportItem {
    pub original_name: String,
    pub local_name: String,  // Same as original, or renamed with "as"
}

fn eval_import(directive: ImportDirective, scope: &mut Scope) -> Result<(), String> {
    // 1. Load the module
    let module = load_module(&directive.module_path)?;

    // 2. If module alias provided, bind module object
    if let Some(alias) = directive.module_alias {
        scope.declare(&alias, QValue::Module(module.clone()))?;
    }

    // 3. Import selected names into scope
    for item in directive.selective_imports {
        // Get the function/type from module
        let value = module.get_member(&item.original_name)?;

        // Bind it in current scope (possibly renamed)
        scope.declare(&item.local_name, value)?;
    }

    Ok(())
}
```

## Examples

### Example 1: Basic Selective Import

```quest
use "std/encoding/json" {parse, stringify}

# No prefix needed for imported names
let data = parse('{"name": "Alice", "age": 30}')
puts(data["name"])

let output = stringify(data)
puts(output)
```

### Example 2: Import with Renaming

```quest
use "std/hash" {md5 as hash_md5, sha256 as hash_sha256}

let file_hash = hash_md5("file contents")
let secure_hash = hash_sha256("password123")
```

### Example 3: Module Alias + Selective Imports

```quest
use "std/http/client" as http {get, post}

# Imported functions: no prefix
let response = get("https://example.com")
post("https://example.com/submit", body: "data")

# Other functions: use alias
http.put("https://example.com/update", body: "data")
http.delete("https://example.com/resource/123")
```

### Example 4: Avoiding Name Conflicts

```quest
use "std/db/postgres" {connect as pg_connect, query as pg_query}
use "std/db/mysql" {connect as my_connect, query as my_query}

let pg_conn = pg_connect("postgres://localhost/mydb")
let my_conn = my_connect("mysql://localhost/mydb")

let pg_results = pg_query(pg_conn, "SELECT * FROM users")
let my_results = my_query(my_conn, "SELECT * FROM products")
```

### Example 5: Import Types and Functions

```quest
use "std/uuid" {v4, v7, Uuid}

# Type imported without prefix
let id1: Uuid = v4()
let id2: Uuid = v7()

fun process_id(id: Uuid)
    puts(id.to_string())
end

process_id(id1)
```

### Example 6: Math Module with Selective Imports

```quest
use "std/math" {sin, cos, tan, pi}

fun calculate_circle_area(radius)
    pi * radius * radius
end

fun calculate_triangle(angle, hypotenuse)
    let opposite = sin(angle) * hypotenuse
    let adjacent = cos(angle) * hypotenuse
    [opposite, adjacent]
end
```

### Example 7: Testing Framework Pattern

```quest
use "std/test" {describe, it, assert_eq, assert_raises}

describe("Calculator", fun ()
    it("adds numbers", fun ()
        assert_eq(add(2, 3), 5)
    end)

    it("handles division by zero", fun ()
        assert_raises(fun () divide(10, 0) end, ValueErr)
    end)
end)
```

## Rationale

### Why Add This?

1. **Reduces verbosity** - No need for repetitive prefixes for commonly-used functions
2. **Improves readability** - Code reads more naturally without constant prefixes
3. **Maintains clarity** - Explicit imports show exactly what's being used
4. **Prevents namespace pollution** - Only imported names enter scope, not entire module
5. **Flexible** - Can mix prefixed and un-prefixed access as needed
6. **Resolves conflicts** - Rename imports to avoid collisions

### Core Design Principle: Explicit Over Implicit

Quest's import system follows the principle of **explicit over implicit**:

- **Explicit imports required** - You must list exactly which names you want: `use "std/math" {sin, cos}`
- **No wildcard imports** - You cannot implicitly pollute local scope with `use "std/math" {*}`
- **Clear dependencies** - Anyone reading the code knows exactly what's imported and where it comes from
- **Fail fast on conflicts** - Name collisions are caught immediately at import time, not at runtime

This design prevents the "where did this function come from?" problem common in languages with wildcard imports. Every imported name is explicitly declared at the top of the file.

### Design Decisions

**Q: Why no wildcard imports like `{*}`?**
A: Wildcard imports implicitly pollute the local scope, making it unclear where names come from. Explicit imports make dependencies obvious and prevent accidental namespace collisions. Quest prioritizes clarity over convenience.

**Q: Can I import from aliased modules?**
A: Yes! `use "module" as m {foo, bar}` gives you both `m.anything()` and `foo()`/`bar()`.

**Q: What happens if I import a name that conflicts with a local variable?**
A: Error! The import fails:
```quest
let parse = "my_parser"
use "std/json" {parse}  # Error: 'parse' already defined in scope
```

**Q: Can I rename module aliases?**
A: Yes, but only the module itself: `use "std/io" as file_io`. For individual functions, use `{name as new_name}`.

**Q: What about importing from nested modules?**
A: Works the same:
```quest
use "std/db/postgres" {connect, query}
use "std/http/client" as http {get, post}
```

**Q: Can I import types this way?**
A: Yes! Types are module members like functions:
```quest
use "std/uuid" {Uuid, v4, v7}
let id: Uuid = v4()
```

**Q: Does this work with user modules?**
A: Yes, any module path works:
```quest
use "lib/utils" {helper1, helper2}
use "src/models" {User, Product}
```

### Comparison to Other Languages

| Language   | Selective Import Syntax |
|------------|-------------------------|
| Python     | `from module import foo, bar` or `from module import foo as f` |
| JavaScript | `import {foo, bar} from 'module'` or `import {foo as f} from 'module'` |
| Rust       | `use module::{foo, bar}` or `use module::foo as f` |
| Go         | No selective imports (all or nothing) |
| **Quest**  | `use "module" {foo, bar}` or `use "module" {foo as f}` |

Quest's syntax is most similar to JavaScript ES6 imports, with module path as string (like Python).

## Design Constraints

### 1. Backward Compatibility

All existing code continues to work unchanged:

```quest
# Old style: still works
use "std/io"
io.read("file.txt")

# New style: opt-in
use "std/io" {read}
read("file.txt")
```

### 2. No Implicit Wildcards

Must explicitly list imported names:

```quest
# ✓ Explicit
use "std/math" {sin, cos, tan}

# ✗ Not supported in MVP (future enhancement)
use "std/math" {*}
```

**Rationale:** Explicit imports make dependencies clear and prevent accidental namespace pollution.

### 3. Name Conflicts Fail Fast

Importing a name that already exists is an error:

```quest
fun parse(text)
    # My custom parser
end

use "std/json" {parse}
# Error: Name 'parse' already defined in current scope
# Hint: Use 'parse as json_parse' to rename the import
```

### 4. Imports are Scope-Local

Imported names only visible in the file where imported:

```quest
# file1.q
use "std/io" {read}
read("file.txt")  # ✓ Works

# file2.q
read("file.txt")  # ✗ Error: 'read' not defined
# Must import in this file too
```

Imported names work in nested functions (file-scoped):

```quest
use "std/math" {sin}

fun outer()
    fun inner()
        sin(0)  # ✓ Works - imports are file-scoped
    end
    inner()
end
```

### 5. Shadowing Rules

Imported names cannot be shadowed by `let` declarations:

```quest
use "std/math" {sin}

# ✗ Error: Cannot redeclare 'sin' with let
let sin = "my_sine"
```

However, function parameters can shadow imported names:

```quest
use "std/math" {sin}

fun test(sin)  # ✓ Parameter shadows import in function scope
    puts(sin)  # Refers to parameter, not imported function
end

test("hello")  # Prints "hello"
sin(0)         # Still works outside function - refers to imported function
```

### 6. Module Caching

Modules are loaded once and cached. Multiple imports from the same module do not reload:

```quest
use "mymodule" {foo}      # Loads module, imports foo
use "mymodule" as m       # Reuses cached module, adds alias 'm'
use "mymodule" {bar}      # Reuses cached module, imports bar

# All three imports share the same module instance
```

### 7. Circular Import Detection

Circular imports are detected and raise an error:

```quest
# module_a.q
use "module_b" {foo}

fun bar()
    "bar from A"
end

# module_b.q
use "module_a" {bar}  # Error: Circular import detected

fun foo()
    "foo from B"
end
```

**Error message:**
```
Error: Circular import detected
  module_a -> module_b -> module_a

This creates an import cycle. Consider:
1. Moving shared code to a third module
2. Using lazy loading with sys.load_module() inside functions
```

## Implementation Notes

### Parser Changes

**Grammar updates:**

```pest
use_statement = {
    "use" ~ string_literal ~ (as_clause)? ~ (import_list)? ~ newline
}

as_clause = { "as" ~ identifier }

import_list = {
    "{" ~ import_item ~ ("," ~ import_item)* ~ ","? ~ "}"
}

import_item = {
    identifier ~ (as_clause)?
}
```

**Example parse tree:**

```quest
use "std/json" as json {parse as json_parse, stringify}
```

Parses to:
```
use_statement
  ├─ string_literal: "std/json"
  ├─ as_clause: "json"
  └─ import_list
      ├─ import_item
      │   ├─ identifier: "parse"
      │   └─ as_clause: "json_parse"
      └─ import_item
          └─ identifier: "stringify"
```

### AST Representation

```rust
pub struct UseStatement {
    pub module_path: String,
    pub module_alias: Option<String>,
    pub imports: Vec<ImportItem>,
}

pub struct ImportItem {
    pub name: String,
    pub alias: Option<String>,  // Renamed import
}
```

### Evaluator Implementation

```rust
fn eval_use_statement(stmt: UseStatement, scope: &mut Scope) -> Result<(), String> {
    // 1. Load module (with circular import detection and caching)
    let module = load_module_with_cache(&stmt.module_path, scope)?;

    // 2. Bind module alias if provided
    if let Some(alias) = stmt.module_alias {
        if scope.has_name(&alias) {
            return Err(format!("Name '{}' already defined in scope", alias));
        }
        scope.declare(&alias, QValue::Module(module.clone()))?;
    }

    // 3. Import selected names
    for import in stmt.imports {
        let local_name = import.alias.as_ref().unwrap_or(&import.name);

        // Check for conflicts
        if scope.has_name(local_name) {
            return Err(format!(
                "Name '{}' already defined in scope\nHint: Use '{} as {}' to rename the import",
                local_name,
                import.name,
                format!("{}_imported", local_name)
            ));
        }

        // Get member from module
        let value = module.get_member(&import.name)
            .ok_or_else(|| format!(
                "Module '{}' has no member '{}'",
                stmt.module_path,
                import.name
            ))?;

        // Bind to local scope
        scope.declare(local_name, value)?;
    }

    Ok(())
}
```

### Module Loading with Circular Import Detection

```rust
// Scope tracks module loading stack to detect cycles
impl Scope {
    pub fn is_loading_module(&self, path: &str) -> bool {
        self.module_loading_stack.contains(path)
    }

    pub fn push_loading_module(&mut self, path: String) {
        self.module_loading_stack.push(path);
    }

    pub fn pop_loading_module(&mut self) {
        self.module_loading_stack.pop();
    }
}

fn load_module_with_cache(path: &str, scope: &mut Scope) -> Result<Rc<QModuleValue>, String> {
    // Check for circular imports
    if scope.is_loading_module(path) {
        let cycle = format!("{} -> {}", scope.module_loading_stack.join(" -> "), path);
        return Err(format!(
            "Circular import detected: {}\n\nConsider:\n1. Moving shared code to a third module\n2. Using lazy loading with sys.load_module() inside functions",
            cycle
        ));
    }

    // Check module cache
    if let Some(cached) = scope.module_cache.get(path) {
        return Ok(cached.clone());
    }

    // Load module
    scope.push_loading_module(path.to_string());
    let module = load_module_internal(path, scope)?;
    scope.pop_loading_module();

    // Cache for future imports
    scope.module_cache.insert(path.to_string(), module.clone());

    Ok(module)
}
```

### Module System Integration

**Only public (`pub`) members can be imported:**

```rust
pub trait QModule {
    fn get_member(&self, name: &str) -> Option<QValue>;
    fn list_public_members(&self) -> Vec<String>;
}

impl QModule for QModuleValue {
    fn get_member(&self, name: &str) -> Option<QValue> {
        // Only return public functions and types
        self.public_functions.get(name)
            .or_else(|| self.public_types.get(name))
            .cloned()
    }

    fn list_public_members(&self) -> Vec<String> {
        self.public_functions.keys()
            .chain(self.public_types.keys())
            .cloned()
            .collect()
    }
}
```

**User modules must explicitly mark exports as `pub`:**

```quest
# mymodule.q

pub fun exported_function()
    "This can be imported"
end

fun internal_helper()
    "This cannot be imported - private"
end

pub type ExportedType
    pub field: Int
end

type InternalType
    # This cannot be imported - private
end
```

**Attempting to import private members fails:**

```quest
use "mymodule" {internal_helper}
# Error: Module 'mymodule' has no public member 'internal_helper'
```

## Testing Strategy

### Unit Tests

```quest
use "std/test" {describe, it, assert_eq, assert_raises}

describe("Scoped imports", fun ()
    it("imports functions into scope", fun ()
        use "std/math" {sin, cos}

        assert_eq(sin(0), 0)
        assert_eq(cos(0), 1)
    end)

    it("supports renaming imports", fun ()
        use "std/hash" {md5 as hash_md5}

        let result = hash_md5("test")
        assert_eq(result.len(), 32)  # MD5 is 32 hex chars
    end)

    it("combines module alias with selective imports", fun ()
        use "std/io" as io {read}

        # Imported function works without prefix
        assert_raises(fun () read("nonexistent.txt") end, IOErr)

        # Other functions need prefix
        assert_raises(fun () io.write("test.txt", "data") end)
    end)

    it("rejects conflicting names", fun ()
        let parse = "my_parser"

        assert_raises(fun ()
            use "std/json" {parse}
        end, NameErr)
    end)

    it("imports types and functions together", fun ()
        use "std/uuid" {Uuid, v4}

        let id: Uuid = v4()
        assert_eq(id.q_type(), "Uuid")
    end)

    it("only imports public members", fun ()
        # Assume mymodule has private function 'internal_helper'
        assert_raises(fun ()
            use "mymodule" {internal_helper}
        end, ImportErr)
    end)

    it("detects circular imports", fun ()
        # module_a imports module_b which imports module_a
        assert_raises(fun ()
            use "test/fixtures/circular_a"
        end, ImportErr)
    end)
end)
```

### Integration Tests

```quest
# test/imports/scoped_imports_test.q

use "std/test" {module, describe, it, assert_eq}
use "std/encoding/json" {parse, stringify}
use "std/http/client" as http {get}

module("Scoped imports integration")

describe("JSON processing", fun ()
    it("works without prefixes", fun ()
        let data = {name: "Alice", age: 30}
        let json_str = stringify(data)
        let parsed = parse(json_str)

        assert_eq(parsed["name"], "Alice")
        assert_eq(parsed["age"], 30)
    end)
end)

describe("HTTP with mixed imports", fun ()
    it("combines imported and prefixed calls", fun ()
        # 'get' is imported
        let response = get("https://httpbin.org/json")

        # 'post' needs prefix
        # http.post(...) would work if we imported it
    end)
end)
```

## Error Messages

### Unknown Import Name

```
Error: Module 'std/json' has no member 'decode'
  at line 5: use "std/json" {parse, decode}

Available members: parse, stringify

Hint: Did you mean 'parse'?
```

### Name Conflict

```
Error: Name 'parse' already defined in current scope
  at line 10: use "std/json" {parse}

Previous definition at line 5:
  fun parse(text)

Hint: Use 'parse as json_parse' to rename the import
```

### Private Member Import

```
Error: Module 'mymodule' has no public member 'internal_helper'
  at line 8: use "mymodule" {internal_helper}

The member 'internal_helper' exists but is private.

Hint: Only 'pub' members can be imported. Check the module definition.
```

### Circular Import

```
Error: Circular import detected
  at line 1: use "module_b" {foo}

Import cycle: module_a -> module_b -> module_a

This creates an import cycle. Consider:
1. Moving shared code to a third module
2. Using lazy loading with sys.load_module() inside functions
```

### Cannot Redeclare Imported Name

```
Error: Cannot redeclare 'sin' - already imported
  at line 5: let sin = "my_sine"

'sin' was imported from 'std/math' at line 1:
  use "std/math" {sin}

Hint: Use a different variable name or rename the import:
  use "std/math" {sin as math_sin}
```

## Benefits

1. **Ergonomics** - Less typing, cleaner code
2. **Clarity** - Explicit imports show dependencies
3. **Flexibility** - Mix prefixed/un-prefixed as needed
4. **Safety** - Name conflicts detected early
5. **Standard** - Similar to Python/JavaScript/Rust

## Limitations

### 1. No Wildcard Imports in MVP

```quest
# Not supported in MVP
use "std/math" {*}

# Must list explicitly
use "std/math" {sin, cos, tan, pi, sqrt, abs}
```

**Future enhancement:** Add `{*}` for wildcard imports with opt-in.

### 2. No Re-exports

Can't re-export imported names from one module to another:

```quest
# module_a.q
use "std/json" {parse}

# module_b.q
use "module_a"
# Can't access 'parse' through module_a
```

**Future enhancement:** Add re-export syntax (e.g., `pub use`).

### 3. Must Import at File Level

Imports must be at the top of the file, not inside functions:

```quest
# ✓ Valid
use "std/io" {read}

fun process()
    read("file.txt")
end

# ✗ Invalid
fun process()
    use "std/io" {read}  # Error: imports must be at file level
    read("file.txt")
end
```

**Rationale:** Keeps imports visible and prevents scope confusion.

## Future Enhancements

### 1. Wildcard Imports

```quest
use "std/math" {*}

# All functions available
let result = sin(pi / 4) + cos(pi / 3) + tan(pi / 6)
```

**Concerns:** Can pollute namespace, makes dependencies unclear.

**Proposal:** Require explicit opt-in:
```quest
use "std/math" {*}  # Warning: importing all names from std/math
```

### 2. Re-exports

```quest
# lib/utils.q
pub use "std/json" {parse, stringify}
pub use "std/hash" {md5, sha256}

# main.q
use "lib/utils" {parse, md5}  # Re-exported names available
```

### 3. Nested Imports

```quest
use "std" {
    io.{read, write},
    os.{getcwd, chdir},
    json.{parse, stringify}
}
```

### 4. Conditional Imports

```quest
if sys.platform == "windows"
    use "std/os/windows" {get_registry}
else
    use "std/os/unix" {get_env}
end
```

### 5. Import Aliases for Entire Paths

```quest
use "really/long/nested/path/to/module" as short {foo, bar}
```

## Style Guide

### When to Use Selective Imports

✅ **Use selective imports for:**
- Frequently-used functions (called 5+ times)
- Testing utilities (`assert_eq`, `describe`, `it`)
- Mathematical functions (`sin`, `cos`, `pi`)
- Common utilities (`parse`, `stringify`)

✅ **Use module aliases for:**
- Infrequently-used functions
- Large modules (many functions)
- When namespace is important for clarity

### Examples

```quest
# ✓ Good: Frequently-used functions
use "std/encoding/json" {parse, stringify}
use "std/test" {describe, it, assert_eq}

# ✓ Good: Module alias + selective imports
use "std/http/client" as http {get, post}

# ✗ Bad: Too many selective imports
use "std/io" {read, write, append, exists, remove, mkdir, ...}
# Better:
use "std/io" as io

# ✗ Bad: Importing rarely-used functions
use "std/os" {set_file_permissions}  # Only used once
# Better:
use "std/os" as os
os.set_file_permissions(...)
```

## Migration Guide

### Before (Current Syntax)

```quest
use "std/encoding/json" as json
use "std/http/client" as http

let response = http.get("https://api.example.com/data")
let data = json.parse(response.text())
let modified = json.stringify(transform(data))
http.post("https://api.example.com/save", body: modified)
```

### After (With Scoped Imports)

```quest
use "std/encoding/json" {parse, stringify}
use "std/http/client" as http {get, post}

let response = get("https://api.example.com/data")
let data = parse(response.text())
let modified = stringify(transform(data))
post("https://api.example.com/save", body: modified)
```

**Backward compatible:** Old syntax still works, new syntax is opt-in.

## Implementation Checklist

- [ ] Update grammar to support `{name1, name2}` syntax
- [ ] Update grammar to support `{name as alias}` syntax
- [ ] Parse import lists into AST
- [ ] Implement selective import evaluation
- [ ] Check for name conflicts during import
- [ ] Support importing types and functions
- [ ] Add error messages for unknown imports
- [ ] Add "did you mean" suggestions
- [ ] Write comprehensive unit tests
- [ ] Write integration tests
- [ ] Update documentation
- [ ] Update CLAUDE.md with examples

## References

- [Python imports](https://docs.python.org/3/reference/import.html)
- [JavaScript ES6 modules](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules)
- [Rust use declarations](https://doc.rust-lang.org/reference/items/use-declarations.html)
- [Go imports](https://go.dev/doc/effective_go#import)
- QEP-018: Dynamic Module Loading

## Appendix: Complete Syntax Examples

```quest
# Pattern 1: Selective imports only
use "std/math" {sin, cos, tan}

# Pattern 2: Selective imports with renaming
use "std/hash" {md5 as hash_md5, sha256 as hash_sha256}

# Pattern 3: Module alias + selective imports
use "std/http/client" as http {get, post}

# Pattern 4: Mix everything
use "std/db/postgres" as pg {connect as pg_connect, query}

# Pattern 5: Multiple imports from same module family
use "std/encoding/json" {parse as json_parse, stringify as json_stringify}
use "std/encoding/xml" {parse as xml_parse, stringify as xml_stringify}

# Pattern 6: Import types and functions
use "std/uuid" {Uuid, v4, v7, parse}

# Pattern 7: Testing pattern (common use case)
use "std/test" {describe, it, assert_eq, assert_neq, assert_raises}

describe("My tests", fun ()
    it("works", fun ()
        assert_eq(1 + 1, 2)
    end)
end)
```

---

## Changelog

**2025-10-07 - Reviewed and Clarified:**
- ✅ Added section on **Shadowing Rules** - `let` cannot redeclare imports, but function parameters can shadow
- ✅ Added section on **Module Caching** - modules loaded once and shared across imports
- ✅ Added section on **Circular Import Detection** - errors with helpful suggestions
- ✅ Added section on **Module Loading Implementation** - detection and caching strategy
- ✅ Clarified **Public-only imports** - only `pub` members can be imported from user modules
- ✅ Added error messages for private member imports and circular imports
- ✅ Added test cases for circular imports and private member access
- ✅ Confirmed file-scoped imports work in nested functions

**Status:** Reviewed - Ready for implementation