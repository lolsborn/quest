# QEP-044: Cargo-Based Package Management for Quest

**Number**: 044
**Status**: Draft
**Author**: Steven
**Created**: 2025-10-07

---

**TL;DR**: Quest leverages Cargo directly for package management. No custom CLI tools needed - just `cargo add`, `cargo build`, `cargo publish`. Quest queries `cargo metadata` at startup to discover where dependencies are installed, then loads `.q` files from those paths.

**Configuration split**:
- `Cargo.toml` → Package management (dependencies, versioning) - standard Cargo
- `quest.toml` → Quest configuration (entry points, settings, build options) - Quest-specific

## Motivation

Quest currently lacks a standardized package management system for distributing and consuming third-party libraries. As the language grows, developers need:

1. **Dependency Management**: Easy way to declare, download, and manage Quest library dependencies
2. **Hybrid Libraries**: Support for packages that include both Quest scripts (`.q` files) and Rust native extensions (dynamic libraries)
3. **Version Control**: Semantic versioning and dependency resolution
4. **Community Ecosystem**: Central registry for discovering and sharing Quest packages
5. **Build Integration**: Seamless integration with Quest's existing Rust-based toolchain

Rather than building a package manager from scratch, we can leverage Cargo's mature ecosystem and infrastructure by creating a Quest package format that works within Cargo's framework.

## Proposal

### Package Structure

Quest packages are Cargo crates with a specific structure:

```
my-quest-lib/
├── Cargo.toml              # Package management (dependencies, versioning)
├── quest.toml              # Quest configuration (paths, settings, build)
├── src/
│   ├── lib.rs              # Optional: Rust native extensions
│   └── native/             # Rust code for native modules
├── quest/
│   ├── init.q              # Main Quest entry point
│   ├── module_a.q          # Quest library code
│   └── module_b.q          # More Quest code
├── examples/               # Example Quest scripts
└── README.md
```

### Cargo.toml - Package Management

**Purpose**: Dependencies, versioning, publishing (standard Cargo file)

```toml
[package]
name = "quest-http-server"
version = "0.1.0"
edition = "2021"
description = "HTTP server framework for Quest"
authors = ["Your Name <you@example.com>"]
license = "MIT"
repository = "https://github.com/user/quest-http-server"

[lib]
crate-type = ["cdylib"]     # For native extensions (optional)

[dependencies]
# Quest dependencies (for use statements in .q files)
quest-json = "^1.2"
quest-http = "~0.5.0"

# Rust dependencies (for native extension code in src/)
tokio = { version = "1", features = ["full"] }
reqwest = "0.12"
```

### quest.toml - Quest Configuration

**Purpose**: Quest-specific settings, paths, build configuration

```toml
[package]
type = "mixed"              # "pure" | "native" | "mixed"
entry = "quest/init.q"      # Main Quest entry point
quest_version = ">=0.9.0"   # Minimum Quest interpreter version

[native]
# Native library configuration (if type = "native" or "mixed")
lib_name = "quest_http_server"     # Override default library name
modules = ["http_server", "tls"]   # Exported native modules

[build]
# Optional build settings
compile_on_import = false          # Compile .q to bytecode on first import
check_syntax = true                # Validate syntax at build time

[exports]
# Documentation/IDE hints (what this package provides)
modules = ["server", "middleware", "router"]
functions = ["create_server", "listen"]

[settings]
# Runtime configuration
log_level = "info"
max_connections = 1000
```

**Key Points**:
- **Cargo.toml**: Standard Cargo file, handled by `cargo` commands
- **quest.toml**: Quest-specific config, read by Quest interpreter
- **Clear separation**: Package management vs. runtime configuration
- **Optional**: `quest.toml` not required for simple pure-Quest packages
- **Discovery**: Quest finds packages via `cargo metadata`, then looks for `quest.toml` in package root

### Package Types

1. **Pure Quest Packages** (`type = "pure"`):
   - Only `.q` script files
   - No Rust compilation needed
   - Fast installation (just file copy)
   - Example: utility libraries, pure algorithms

2. **Native Packages** (`type = "native"`):
   - Rust dynamic library (`.so`, `.dylib`, `.dll`)
   - Exposes Quest-compatible API
   - Example: system bindings, performance-critical code

3. **Mixed Packages** (`type = "mixed"`):
   - Both Quest scripts and native extensions
   - Quest code provides high-level API
   - Native code provides low-level performance
   - Example: database drivers, web frameworks

### Installation and Usage

#### Installing Packages

```bash
# Use Cargo directly - no custom CLI needed
cargo add quest-http-server
cargo add quest-json@1.2.3

# Or manually edit Cargo.toml
[dependencies]
quest-http-server = "0.1"
quest-json = "1.2"
```

#### Quest Code Usage

```quest
# Import from installed package
use "http-server" as server
use "http-server/middleware" as middleware

let app = server.new()
app.use(middleware.logger())
app.listen(port: 8080)
```

### Package Resolution via Cargo Metadata

**Key Insight**: Quest interpreter queries Cargo to find dependency paths using `cargo metadata`.

Quest package names follow convention: `quest-<name>` in Cargo, but referenced as `<name>` in Quest code.

**Resolution Algorithm**:

1. **Invoke Cargo**: Run `cargo metadata --format-version 1` in working directory
2. **Parse JSON**: Extract package info with paths to source code
3. **Build Path Map**: Create mapping from package name → filesystem path
4. **Resolve Import**: When Quest sees `use "http-server"`, look up `quest-http-server` in map
5. **Load Module**: Read `.q` files from `<package_path>/quest/` directory

**Example `cargo metadata` output**:
```json
{
  "packages": [
    {
      "name": "quest-http-server",
      "version": "0.1.0",
      "manifest_path": "/Users/user/.cargo/registry/src/.../quest-http-server-0.1.0/Cargo.toml",
      "metadata": {
        "quest": {
          "type": "pure",
          "entry": "quest/init.q",
          "quest_version": ">=0.9.0"
        }
      },
      "dependencies": [
        {
          "name": "quest-json",
          "req": "^1.2",
          "kind": null
        }
      ]
    }
  ]
}
```

**What Quest reads**:
- `name` → Package name for mapping
- `manifest_path` → Derive package root directory
- `metadata.quest` → Quest-specific config from `[package.metadata.quest]`
- `dependencies` → Already resolved by Cargo (with versions chosen)

**Path derivation**:
- `manifest_path` = `/path/to/quest-http-server-0.1.0/Cargo.toml`
- Package root = `/path/to/quest-http-server-0.1.0/`
- Quest code = `/path/to/quest-http-server-0.1.0/quest/init.q`

**Resolution Order**:
1. Check `QUEST_PATH` environment variable (manual overrides)
2. Query `cargo metadata` for dependency paths
3. Check built-in `std/` modules (backward compatibility)
4. Error if not found

### Native Extension API

Rust extensions expose Quest-compatible functions using a standard API:

```rust
use quest_runtime::{QValue, QObj, QModule, Result};

#[no_mangle]
pub extern "C" fn quest_module_init() -> *mut QModule {
    let mut module = QModule::new("http_server");

    module.add_function("listen", quest_listen);
    module.add_function("stop", quest_stop);

    Box::into_raw(Box::new(module))
}

fn quest_listen(args: &[QValue]) -> Result<QValue> {
    // Native implementation
    let port = args[0].as_int()?;
    // ... start server
    Ok(QValue::Nil)
}
```

### Build Process

Use standard Cargo commands directly:

1. **Pure Packages**: `cargo build` does nothing (no Rust code), `.q` files used in-place
2. **Native Packages**:
   - `cargo build` compiles Rust code to `.so`/`.dylib`/`.dll`
   - Dynamic library placed in `target/debug/` or `target/release/`
   - Quest wrapper `.q` file loads native lib with `sys.load_native()`
3. **Mixed Packages**: Cargo builds native lib, Quest code uses it

**No custom build tools needed** - Cargo handles everything.

### Package Registry

**Use crates.io** with `quest-` prefix convention:
- ✅ Existing infrastructure (versioning, authentication, CDN)
- ✅ No custom server to maintain
- ✅ Cargo tooling works out of the box
- ✅ Supply chain security features
- ⚠️ Must use `quest-` prefix to avoid namespace pollution

**Publishing**: Standard `cargo publish` workflow

## Rationale

### Why Cargo?

1. **Mature Infrastructure**: Battle-tested dependency resolution, versioning, caching
2. **Native Integration**: Quest is written in Rust, natural fit
3. **Hybrid Support**: Cargo already handles mixed Rust/script scenarios
4. **Security**: Supply chain security, checksums, signature verification
5. **Tooling**: Existing tools (cargo-edit, cargo-audit, etc.) work out of the box
6. **No Reinvention**: Focus Quest development on language features, not package management

### Why Not Pure Quest Format?

- Would require building entire package manager from scratch
- Dependency resolution is complex (SAT solving)
- Need build system for native extensions anyway
- Cargo's infrastructure is free and proven

### Alternatives Considered

1. **NPM-style Package Manager**:
   - Pro: Familiar to many developers
   - Con: Requires Node.js, separate toolchain
   - Con: Doesn't handle native compilation well

2. **Custom Binary Format**:
   - Pro: Complete control
   - Con: Years of development effort
   - Con: Small ecosystem initially

3. **Git Submodules**:
   - Pro: Simple, no infrastructure
   - Con: No versioning, manual dependency management
   - Con: No central discovery

## Examples

### Example 1: Pure Quest Package

**Package: quest-color** (terminal colors)

```toml
# Cargo.toml
[package]
name = "quest-color"
version = "0.1.0"
edition = "2021"
description = "Terminal color utilities for Quest"
license = "MIT"

[package.metadata.quest]
type = "pure"
# entry defaults to "quest/init.q" if omitted
```

```quest
# quest/init.q
const RED = "\e[31m"
const GREEN = "\e[32m"
const BLUE = "\e[34m"
const RESET = "\e[0m"

fun red(text)
    RED .. text .. RESET
end

fun green(text)
    GREEN .. text .. RESET
end

fun blue(text)
    BLUE .. text .. RESET
end
```

**Usage**:

```quest
use "color"

puts(color.red("Error!"))
puts(color.green("Success!"))
```

### Example 2: Native Package

**Package: quest-blake3** (fast hashing)

```toml
# Cargo.toml
[package]
name = "quest-blake3"
version = "1.0.0"

[lib]
crate-type = ["cdylib"]

[dependencies]
blake3 = "1.5"
quest-runtime = "0.1"

[package.metadata.quest]
type = "native"
entry = "quest/init.q"
```

```rust
// src/lib.rs
use quest_runtime::{QValue, QModule, Result, qerr};

#[no_mangle]
pub extern "C" fn quest_module_init() -> *mut QModule {
    let mut module = QModule::new("blake3");
    module.add_function("hash", quest_blake3_hash);
    Box::into_raw(Box::new(module))
}

fn quest_blake3_hash(args: &[QValue]) -> Result<QValue> {
    let data = args[0].as_bytes()?;
    let hash = blake3::hash(&data);
    Ok(QValue::Str(hash.to_hex().to_string()))
}
```

```quest
# quest/init.q
# Thin wrapper around native module
let _native = sys.load_native("libquest_blake3")

fun hash(data)
    _native.hash(data)
end
```

**Usage**:

```quest
use "blake3"

let hash = blake3.hash(b"hello world")
puts(hash)  # Fast native implementation
```

### Example 3: Mixed Package

**Package: quest-sqlite** (database with native driver + Quest API)

```toml
# Cargo.toml
[package]
name = "quest-sqlite"
version = "0.2.0"
edition = "2021"
description = "SQLite database driver for Quest"
license = "MIT"

[lib]
crate-type = ["cdylib"]

[dependencies]
# Rust dependencies for native code
rusqlite = "0.31"
quest-runtime = "0.1"

# Quest dependencies (also regular Cargo deps!)
quest-sql-common = "0.1"

[package.metadata.quest]
type = "mixed"
entry = "quest/init.q"
```

```rust
// src/lib.rs - Native SQLite bindings
use quest_runtime::{QValue, QModule, Result};
use rusqlite::Connection;

#[no_mangle]
pub extern "C" fn quest_module_init() -> *mut QModule {
    let mut module = QModule::new("sqlite_native");
    module.add_function("connect", quest_sqlite_connect);
    module.add_function("query", quest_sqlite_query);
    Box::into_raw(Box::new(module))
}

// Native implementation details...
```

```quest
# quest/init.q - High-level Quest API
let _native = sys.load_native("libquest_sqlite")
use "sql-common" as sql

type Connection
    _handle

    fun query(sql_str, *params)
        let result = _native.query(self._handle, sql_str, params)
        sql.ResultSet.new(result)
    end

    fun execute(sql_str, *params)
        _native.execute(self._handle, sql_str, params)
    end

    fun close()
        _native.close(self._handle)
    end
end

fun connect(path)
    let handle = _native.connect(path)
    Connection.new(_handle: handle)
end
```

**Usage**:

```quest
use "sqlite"

let db = sqlite.connect("data.db")
let rows = db.query("SELECT * FROM users WHERE age > ?", 18)

for row in rows
    puts(row["name"])
end

db.close()
```

### Example 4: Package Dependencies

**Package: quest-web-framework** (depends on multiple packages)

```toml
# Cargo.toml
[package]
name = "quest-web-framework"
version = "0.1.0"
edition = "2021"
description = "Web framework for Quest"
license = "MIT"

[dependencies]
# All Quest dependencies listed here (Cargo handles resolution)
quest-http = "^0.5"
quest-router = "^0.2"
quest-templates = "^1.0"
quest-json = "^1.2"

[package.metadata.quest]
type = "pure"
entry = "quest/init.q"
```

**No separate dependency section needed** - Quest packages are just regular Cargo dependencies!

```quest
# quest/init.q
use "http" as http
use "router" as router
use "templates" as templates
use "json"

type Application
    _router
    _server

    fun route(path, handler)
        self._router.add(path, handler)
    end

    fun listen(port)
        let server = http.Server.new(port: port)
        server.on_request(self._router.handle)
        server.start()
        self._server = server
    end
end

fun new()
    Application.new(
        _router: router.Router.new(),
        _server: nil
    )
end
```

**Usage**:

```quest
use "web-framework" as web

let app = web.new()

app.route("/users", fun (req, res)
    let users = get_users()
    res.json(users)
end)

app.listen(port: 8080)
puts("Server running on http://localhost:8080")
```

## Implementation Notes

### Phase 1: Cargo Integration (MVP)

1. **Cargo Metadata Integration** (Quest interpreter):
   ```rust
   use std::process::Command;
   use serde_json::Value;

   fn get_cargo_packages() -> HashMap<String, PackageInfo> {
       let output = Command::new("cargo")
           .args(&["metadata", "--format-version", "1"])
           .output()
           .expect("Failed to run cargo metadata");

       let metadata: Value = serde_json::from_slice(&output.stdout).unwrap();

       // Build map: package name -> filesystem path
       let mut packages = HashMap::new();
       for pkg in metadata["packages"].as_array().unwrap() {
           let name = pkg["name"].as_str().unwrap();
           let manifest = pkg["manifest_path"].as_str().unwrap();
           let root = Path::new(manifest).parent().unwrap();

           // Store package info
           packages.insert(name.to_string(), PackageInfo {
               root: root.to_path_buf(),
               version: pkg["version"].as_str().unwrap().to_string(),
               quest_metadata: pkg["metadata"]["quest"].clone(),
           });
       }
       packages
   }
   ```

2. **Module Resolution** (update `use` statement handler):
   ```rust
   fn resolve_quest_module(name: &str) -> Result<PathBuf, String> {
       // 1. Check QUEST_PATH environment variable
       if let Ok(quest_path) = env::var("QUEST_PATH") {
           for dir in quest_path.split(':') {
               let candidate = Path::new(dir).join(name);
               if candidate.exists() {
                   return Ok(candidate);
               }
           }
       }

       // 2. Query cargo metadata (cache result for performance)
       let packages = get_cargo_packages();
       let cargo_name = format!("quest-{}", name);

       if let Some(pkg_info) = packages.get(&cargo_name) {
           let entry = pkg_info.quest_metadata["entry"]
               .as_str()
               .unwrap_or("quest/init.q");
           return Ok(pkg_info.root.join(entry));
       }

       // 3. Check built-in std/ modules
       if name.starts_with("std/") {
           let std_path = Path::new("lib").join(name).with_extension("q");
           if std_path.exists() {
               return Ok(std_path);
           }
       }

       Err(format!("Module not found: {}", name))
   }
   ```

3. **Caching Strategy**:
   - Parse `cargo metadata` output **once** at interpreter startup
   - Cache the package map in memory
   - Invalidate cache if `Cargo.toml` changes (watch file mtime)

4. **Performance Optimization**:
   - `cargo metadata` typically takes ~50-200ms
   - Run once, not per `use` statement
   - Consider async execution if startup time is critical

### Phase 2: Native Extensions

1. **Quest Runtime API** (`quest-runtime` crate):
   - Stable ABI for native extensions
   - Export `QValue`, `QObj`, `QModule` types
   - C-compatible interface (`extern "C"`)
   - Version with semantic versioning

2. **Dynamic Library Loading**:
   ```rust
   // In Quest interpreter
   use libloading::{Library, Symbol};

   fn load_native_module(name: &str) -> Result<QValue, String> {
       // Find library path via cargo metadata
       let lib_name = format!("libquest_{}", name);
       let lib_path = find_native_library(&lib_name)?;

       unsafe {
           let lib = Library::new(lib_path)?;
           let init: Symbol<extern "C" fn() -> *mut QModule> =
               lib.get(b"quest_module_init")?;

           let module = init();
           Ok(QValue::Module(module))
       }
   }
   ```

3. **Native Library Discovery**:
   - Check `target/debug/` and `target/release/` directories
   - Use `cargo metadata` to find dependency target paths
   - Support platform-specific extensions (`.so`, `.dylib`, `.dll`)

### Phase 3: Enhanced Features

1. **Dependency Validation**:
   - Check Quest version compatibility from `package.metadata.quest`
   - Validate transitive dependencies
   - Warn about version conflicts

2. **Development Experience**:
   - Better error messages for missing packages
   - Suggestions: "Did you forget to add 'quest-http' to Cargo.toml?"
   - Documentation links in error messages

3. **Tooling** (optional convenience commands):
   - `cargo quest-init` - Scaffold new Quest package
   - `cargo quest-test` - Run Quest test suite
   - `cargo quest-check` - Validate package structure

   These would be separate `cargo` plugins, not Quest interpreter features.

### Technical Considerations

1. **ABI Stability**:
   - Native extensions must be compatible across Quest patch versions
   - Major version bumps can break ABI
   - Document ABI guarantees clearly

2. **Dynamic Loading**:
   - Use `libloading` for cross-platform dynamic library loading
   - Handle platform-specific library extensions (`.so`, `.dylib`, `.dll`)
   - Graceful error handling for missing libraries

3. **Name Collision**:
   - Packages use `quest-` prefix on crates.io
   - Quest code imports without prefix (`use "http"` not `use "quest-http"`)
   - Maintain mapping in package metadata

4. **Workspace Support**:
   - Multi-package projects (monorepos)
   - Shared dependencies across workspace
   - Path-based local dependencies

5. **Version Resolution**:
   - Leverage Cargo's resolver (latest version by default)
   - Support for version constraints (^, ~, =, >=, <)
   - Handle transitive dependencies automatically

6. **Installation Paths** (managed by Cargo):
   ```
   ~/.cargo/
   └── registry/
       └── src/
           └── github.com-1ecc6299db9ec823/
               ├── quest-http-0.5.0/
               │   ├── Cargo.toml
               │   ├── quest/
               │   │   └── init.q        # Quest scripts
               │   └── src/
               │       └── lib.rs         # Optional native code
               └── quest-json-1.2.3/
                   ├── Cargo.toml
                   └── quest/
                       └── init.q
   ```

   **No custom installation directories** - Cargo downloads everything to its registry cache, and `cargo metadata` tells Quest where to find it.

### Migration Path

1. **Existing `std/` modules**: Keep as built-in, no changes required
2. **Third-party code**: Can gradually adopt package system
3. **Backward compatibility**: `use "std/http"` continues to work alongside `use "http"` from packages
4. **No breaking changes**: Current Quest code works unchanged

## References

- [Cargo Book](https://doc.rust-lang.org/cargo/)
- [crates.io](https://crates.io/)
- [Cargo Registry Protocol](https://doc.rust-lang.org/cargo/reference/registry-index.html)
- [Python's Extension Module System](https://docs.python.org/3/extending/extending.html)
- [Node.js Native Addons](https://nodejs.org/api/addons.html)
- [Ruby Gems](https://guides.rubygems.org/)
- QEP-001: Database API (standardized module interface)
- QEP-018: Dynamic Code Execution (`sys.eval`, `sys.load_module`)

## Future Enhancements

1. **Binary Caching**: Pre-compiled native extensions for common platforms
2. **IDE Integration**: Auto-completion from installed packages (via `cargo metadata`)
3. **Dependency Audit**: Use `cargo audit` for security scanning
4. **Feature Flags**: Use Cargo's feature system for optional functionality
5. **Workspace Support**: Multi-package Quest projects using Cargo workspaces
6. **Private Registries**: Use Cargo's alternate registry support for corporate packages

## Open Questions

1. **Cargo metadata performance**: Is ~50-200ms startup overhead acceptable? Should we cache across invocations?
2. **Native library discovery**: How to reliably find compiled `.so`/`.dylib`/`.dll` files for dependencies in `target/`?
3. **Multi-version packages**: If `quest-http` v0.5 and v0.6 are both in dependency tree, which one does `use "http"` import?
4. **Quest version compatibility**: How to enforce minimum Quest interpreter version for packages?
5. **Path-based dependencies**: Should local `path = "../my-quest-lib"` dependencies work?
6. **REPL mode**: How does package resolution work when Quest is not run from a Cargo project directory?

## Key Benefits Summary

✅ **Zero custom tooling** - Use `cargo add`, `cargo build`, `cargo publish` directly
✅ **Automatic dependency resolution** - Cargo handles version conflicts and transitive deps
✅ **No installation step** - `.q` files used directly from Cargo registry cache
✅ **Native extensions** - Rust dynamic libraries integrate seamlessly
✅ **Existing ecosystem** - Leverage crates.io, `cargo-edit`, `cargo-audit`, etc.
✅ **Simple implementation** - Just parse `cargo metadata` JSON and map paths

## Complete Workflow Example

### Creating a Quest Project with Dependencies

```bash
# 1. Create new Cargo project (Quest app)
cargo new my-quest-app
cd my-quest-app

# 2. Add Quest dependencies
cargo add quest-http-client
cargo add quest-json

# 3. Write Quest code
cat > src/main.q << 'EOF'
use "http-client" as http
use "json"

let response = http.get("https://api.github.com/users/octocat")
let data = json.parse(response.body())

puts(f"User: {data["login"]}")
puts(f"Name: {data["name"]}")
EOF

# 4. Run Quest script
quest src/main.q
```

**What happens**:
1. Quest interpreter starts
2. Runs `cargo metadata --format-version 1`
3. Parses JSON to find:
   - `quest-http-client` → `~/.cargo/registry/src/.../quest-http-client-0.5.0/`
   - `quest-json` → `~/.cargo/registry/src/.../quest-json-1.2.3/`
4. When `use "http-client"` executes:
   - Looks up `quest-http-client` in package map
   - Finds `quest/init.q` in that directory
   - Loads and evaluates it
5. Module is now available as `http`

### Publishing a Quest Package

```bash
# 1. Create package
cargo new --lib quest-my-cool-lib
cd quest-my-cool-lib

# 2. Set up package structure
mkdir -p quest
cat > quest/init.q << 'EOF'
fun greet(name)
    "Hello, " .. name .. "!"
end

fun farewell(name)
    "Goodbye, " .. name .. "!"
end
EOF

# 3. Add metadata to Cargo.toml
cat >> Cargo.toml << 'EOF'

[package.metadata.quest]
type = "pure"
entry = "quest/init.q"
EOF

# 4. Publish to crates.io
cargo publish
```

**Now anyone can use it**:
```bash
cargo add quest-my-cool-lib
```

```quest
use "my-cool-lib" as lib
puts(lib.greet("World"))  # Hello, World!
```
