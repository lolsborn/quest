---
Number: QEP-060
Title: Application-Centric Web Server Architecture
Author: Claude (with Steven Ruppert)
Status: Draft
Created: 2025-10-18
---

# QEP-060: Application-Centric Web Server Architecture

## Overview

Refactor Quest's web server from a command-driven architecture (`quest serve app.q`) to an application-centric pattern where scripts directly configure and start their own web servers via `web.run()`, matching industry-standard frameworks like Flask, FastAPI, Express, and Sinatra.

## Status

**Draft** - Architectural redesign proposal

## Problem Statement

The current `quest serve` architecture has fundamental issues:

### 1. Double Script Execution
Scripts execute twice:
- **First**: In `load_quest_web_config()` to extract configuration
- **Second**: In `init_thread_scope()` for each async worker thread

**Consequences**:
- Duplicate log messages (every log appears N times where N = worker threads)
- Module-level side effects happen multiple times
- Confusing developer experience
- Difficult to debug initialization issues

### 2. Complex Thread-Local Management
Each worker thread needs its own scope, leading to:
- Complex synchronization between config extraction and runtime
- Static directories stored in `ServerConfig` then checked at runtime
- Brittle state management across thread boundaries

### 3. Unnatural Developer Experience
Current flow:
```bash
$ quest serve app.q  # Command starts server
# Script is "loaded" by the command
# Configuration is "extracted"
```

Every other framework:
```bash
$ python app.py      # Script starts server
$ node app.js
$ ruby app.rb
$ quest app.q        # Should work the same!
```

### 4. Static File Serving Complexity
The current implementation tried three different approaches:
1. Axum `ServeDir` at startup (caused duplicate routes)
2. Runtime checking with `try_serve_static_file()` (causes repeated Quest function calls)
3. Config clearing before reload (brittle workaround)

None feel natural because they're fighting against the architecture.

## Motivation

Modern web frameworks follow a simple pattern:

**Flask:**
```python
app = Flask(__name__)

@app.route('/')
def home():
    return 'Hello'

app.run(host='0.0.0.0', port=8080)  # Blocks here
```

**FastAPI:**
```python
app = FastAPI()

@app.get('/')
def home():
    return {'message': 'Hello'}

uvicorn.run(app, host='0.0.0.0', port=8080)  # Blocks here
```

**Express:**
```javascript
const app = express();

app.get('/', (req, res) => res.send('Hello'));

app.listen(8080);  // Blocks here
```

**Quest should be:**
```quest
use "std/web" as web
use "std/web/router" as router

web.static("/public", "./public")

router.get("/", fun (req)
  return {status: 200, body: "Hello"}
end)

web.use(router.dispatch_middleware)
web.run(host: "0.0.0.0", port: 8080)  # Blocks here
```

**Key insight**: The script IS the application. Configuration and routing are just imperative statements that modify the application state before starting the server.

## Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│  app.q                                              │
│                                                     │
│  use "std/web" as web                              │
│  use "std/web/router" as router                    │
│                                                     │
│  # Configuration (modifies web module state)       │
│  web.static("/public", "./public")                 │
│  web.cors(origins: ["*"])                          │
│                                                     │
│  # Route registration (explicit methods)           │
│  router.get("/", home_handler)                     │
│  router.post("/api/data", api_handler)             │
│                                                     │
│  # Register router middleware                      │
│  web.use(router.dispatch_middleware)               │
│                                                     │
│  # Start server (blocks)                           │
│  web.run()  ← EXECUTION BLOCKS HERE               │
│                                                     │
└─────────────────────────────────────────────────────┘
               ↓
      Rust: web.run() implementation
               ↓
    1. Extract config from web module state
    2. Extract routes from router instance (already registered)
    3. Build Axum router with middleware chain
    4. Start server (blocks until shutdown)
```

### Execution Flow

#### Current (Broken)
```
quest serve app.q
  ├─ load_quest_web_config()
  │    ├─ Execute app.q (logs appear)
  │    └─ Extract config to ServerConfig
  ├─ start_server()
  │    └─ For each worker thread:
  │         └─ init_thread_scope()
  │              └─ Execute app.q AGAIN (logs appear AGAIN)
  └─ handle_request_sync()
       └─ try_serve_static_file()
            └─ Call web._get_config() AGAIN (on every request)
```

#### Proposed (Clean)
```
quest app.q
  ├─ Execute app.q ONCE
  │    ├─ Module-level code runs (imports, setup, logs)
  │    ├─ web.static() modifies web module state
  │    ├─ router.get()/post()/etc. register routes explicitly
  │    ├─ web.use() registers router middleware
  │    └─ web.run() is called
  └─ Rust: web.run() implementation
       ├─ Extract all config/routes from CURRENT scope
       ├─ Clone scope for each worker thread
       ├─ Build Axum router with middleware chain
       └─ Start server (blocks until Ctrl+C)
```

### API Design

#### `web.run()`

```quest
# Basic usage
web.run()

# With configuration
web.run(
  host: "0.0.0.0",
  port: 8080
)
```

**Behavior**:
- Blocks indefinitely until server receives shutdown signal (Ctrl+C or SIGTERM)
- Reads all configuration from `web` module state
- Builds and starts HTTP server
- Handles Ctrl+C gracefully by registering signal handler
- Finishes in-flight requests before stopping
- Returns when server stops (script ends)

**Implementation** (Rust side):
```rust
// Called when Quest code executes: web.run(...)
pub fn web_run(args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, EvalError> {
    // 1. Extract configuration from web module
    let web_module = scope.get("web").ok_or("web module not loaded")?;
    let config = extract_config_from_module(&web_module, args)?;

    // 2. Extract static dirs
    let static_dirs = extract_static_dirs(&web_module)?;

    // 3. Extract middleware chain (registered via web.use() calls)
    let middleware = extract_middleware_chain(&web_module)?;

    // 4. Freeze scope for request handling (read-only)
    let frozen_scope = Arc::new(scope.clone());

    // 5. Register signal handler for Ctrl+C
    setup_signal_handler();

    // 6. Build and start server (blocks until signal)
    tokio::runtime::Runtime::new()?.block_on(async {
        start_web_server(config, static_dirs, middleware, frozen_scope).await
    })?;

    Ok(QValue::Nil(QNil))
}
```

**Key Implementation Details**:
- Routes are registered explicitly via `router.get()`, `router.post()`, etc. during script execution (see QEP-062)
- Middleware is registered explicitly via `web.use()` during script execution, including router dispatch middleware
- Scope is frozen (cloned to `Arc<Scope>`) at `web.run()` time, making it read-only for all request handlers
- Configuration, middleware, and static files are extracted once and shared across all requests
- Signal handler catches SIGINT (Ctrl+C) and SIGTERM to initiate graceful shutdown
- In-flight requests are allowed to complete; new requests after signal are rejected with 503
- Script execution resumes (returns Nil) after server stops

#### `web.static()`

```quest
# Add static directory
web.static(url_path: Str, fs_path: Str)

# Examples
web.static("/public", "./public")
web.static("/uploads", "./uploads")
web.static("/", "./dist")  # SPA mode
```

**Behavior**:
- Immediately registers static directory in web module state
- Stores as `(url_path, fs_path)` pairs in array
- No Axum interaction until `web.run()` is called
- Can be called conditionally:
  ```quest
  if os.getenv("ENABLE_UPLOADS") != nil
    web.static("/uploads", "./uploads")
  end
  ```

#### Route Registration

Routes are registered explicitly using router methods (see QEP-062 for routing details):

```quest
use "std/web/router" as router

router.get("/", fun (req)
  return {status: 200, body: "Hello"}
end)

router.post("/api/upload", fun (req)
  return {status: 200, body: "OK"}
end)

web.use(router.dispatch_middleware)  # Register router as middleware
```

**See also**: QEP-062 for flexible path parameter routing (router methods, pattern syntax, type checking)

### Configuration Precedence

1. **quest.toml** (base defaults) - loaded via `std/conf` system
2. **Command-line args** to `web.run()` (highest priority)

```toml
# quest.toml
[web]
host = "127.0.0.1"
port = 3000
```

```quest
# Overrides port from quest.toml
web.run(port: 8080)
```

**Note**: Environment variable overrides (QUEST_WEB_PORT, etc.) are handled by user scripts if desired, not by the web framework itself. Users can implement this via `os.getenv()` before calling `web.run()`.

### Static File Serving

Static files are served via Axum middleware, built at server startup:

```rust
// In start_web_server()
let mut app = Router::new();

// Add static file directories (sorted by specificity)
let mut sorted_static_dirs = static_dirs.clone();
sorted_static_dirs.sort_by(|a, b| b.0.len().cmp(&a.0.len()));

for (url_path, fs_path) in sorted_static_dirs {
    let serve_dir = ServeDir::new(fs_path);
    app = app.nest_service(url_path, get_service(serve_dir));
}

// Add dynamic routes
app = app.route("/*path", any(handle_request));
```

**Benefits**:
- No runtime Quest function calls
- No duplicate route registration
- Axum handles all path matching efficiently
- Standard Rust performance


## Migration Path

### Minimal Breaking Changes

**Old (current):**
```bash
quest serve app.q
```

**New:**
```bash
quest app.q
```

**Script changes:**
```quest
# OLD: No explicit server start (command-driven)
use "std/web" as web
web.add_static("/public", "./public")
# Routes via decorators (to be removed)
# Implicit: quest serve starts it

# NEW: Explicit server start (application-centric)
use "std/web" as web
use "std/web/router" as router
web.static("/public", "./public")
# Routes via router methods (see QEP-062)
router.get("/", handler)
web.use(router.dispatch_middleware)
web.run()  # ← Add this line
```

### Compatibility Shim

Keep `quest serve` as deprecated command that:
1. Reads script
2. Appends `\nweb.run()` if not present
3. Executes via `quest <script>`
4. Prints deprecation warning

### Example Migration: Blog App

**Before:**
```quest
# examples/web/blog/index.q
use "std/web" as web

web.add_static("/public", "./public")
web.add_static("/uploads", "./uploads")

# Routes via decorators (to be replaced)

# Script ends, quest serve starts server
```

**After:**
```quest
# examples/web/blog/index.q
use "std/web" as web
use "std/web/router" as router

web.static("/public", "./public")
web.static("/uploads", "./uploads")

# Routes via router methods (see QEP-062)
router.get("/", home_handler)

web.use(router.dispatch_middleware)
web.run()  # ← Add these lines
```

**Run:**
```bash
# Old
quest serve examples/web/blog/index.q

# New
quest examples/web/blog/index.q
```

## Implementation Plan

### Phase 1: Core Infrastructure
1. Implement `web.run()` native function
2. Refactor config extraction to read from scope at `web.run()` time
3. Remove `load_quest_web_config()` double-execution
4. Update server startup to use config from `web.run()`

### Phase 2: Static Files
1. Remove runtime `try_serve_static_file()`
2. Build Axum `ServeDir` at startup from config
3. Test precedence rules (longest path wins)

### Phase 3: Router Integration (QEP-062)
1. Implement flexible routing with path parameters (QEP-062)
2. Ensure router middleware integrates with middleware chain
3. Extract routes via middleware during `web.run()`

### Phase 4: Migration
1. Update blog example
2. Update documentation
3. Add `quest serve` compatibility shim
4. Deprecation warnings

### Phase 5: Advanced Features (Future)
1. Hot reload support (watches files, restarts process)
2. Custom shutdown hooks
3. Request metrics/telemetry

## Alternatives Considered

### 1. Keep `quest serve` + Fix Double Execution

**Approach**: Cache config in thread-local storage, only execute once per thread.

**Rejected because**:
- Still doesn't match industry patterns
- Developer confusion ("why does Quest need a special command?")
- Complexity of managing thread-local state
- Doesn't fix the fundamental architectural issue

### 2. Application Factory Pattern

**Approach**: Scripts return app object, `quest serve` calls `create_app()`:
```quest
fun create_app()
  let app = web.Application.new()
  app.static("/public", "./public")
  app.get("/", home_handler)
  return app
end
```

**Rejected because**:
- More complex than needed
- Still requires special `quest serve` command
- Less intuitive for simple scripts
- Quest isn't Go/Rust (no explicit app objects needed)

### 3. Hybrid: Both Patterns

**Approach**: Support both `quest app.q` (with `web.run()`) and `quest serve app.q` (without).

**Rejected because**:
- Two ways to do the same thing
- Confusing for newcomers
- Maintenance burden
- Better to have one obvious way

## Compatibility

### Breaking Changes

1. **Scripts must call `web.run()`**
   - Mitigation: Compatibility shim in `quest serve`
   - Migration: Add one line to existing scripts

2. **`quest serve` deprecated**
   - Mitigation: Keep as alias with warnings
   - Timeline: Deprecate in next release, remove in 2 releases

### Non-Breaking

- All `web.static()`, `web.cors()`, etc. APIs remain the same
- Decorators work identically
- Configuration system unchanged
- Static file behavior unchanged

## Testing Strategy

1. **Unit tests**: Config extraction from module state
2. **Integration tests**: Full app startup and request handling
3. **Migration tests**: Verify blog example works
4. **Performance tests**: Ensure no regression
5. **Hot reload tests**: File watching (Phase 5)

## Documentation Updates

1. Update `docs/web-framework.md` with new pattern
2. Add migration guide
3. Update blog example
4. Add troubleshooting section (common errors)
5. Compare to Flask/FastAPI (for Python devs)

## Success Criteria

- [ ] Scripts execute exactly once (no duplicate logs)
- [ ] `web.run()` blocks until server stops
- [ ] Static files work without runtime Quest calls
- [ ] Blog example runs with one-line change
- [ ] No thread-local complexity
- [ ] Clear, intuitive developer experience
- [ ] Matches Flask/FastAPI mental model

## References

- QEP-051: Web Framework API (current implementation)
- QEP-003: Function Decorators
- Flask documentation: https://flask.palletsprojects.com/
- FastAPI documentation: https://fastapi.tiangolo.com/
- Express.js documentation: https://expressjs.com/

## Open Questions

1. **Should `web.run()` accept host/port args, or only read from quest.toml?**
   - **Decision**: Accept args (overrides toml), matches Flask/FastAPI ✅

2. **What happens if script calls `web.run()` twice?**
   - **Decision**: Second call raises error: "Server already running" ✅

3. **Should we support non-blocking mode (`web.run(background: true)`)?**
   - **Decision**: No, keep it simple. Use OS-level tools (`&`, `nohup`, systemd) ✅

4. **How to handle Ctrl+C gracefully?**
   - **Decision**: Register signal handler, finish in-flight requests, then stop ✅

5. **How should routing be implemented?**
   - **Decision**: Via explicit router methods with QEP-062 (see QEP-062 for implementation) ✅

## Timeline

- **Week 1**: Phase 1 (Core Infrastructure)
- **Week 2**: Phase 2 (Static Files) + Phase 3 (Decorator Registry)
- **Week 3**: Phase 4 (Migration) + Testing
- **Week 4**: Documentation + Phase 5 (Advanced Features)

Total: ~1 month for full implementation and migration.
