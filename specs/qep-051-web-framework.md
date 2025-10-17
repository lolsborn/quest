---
Number: QEP-051
Title: Web Framework API
Author: Steven Ruppert
Status: Draft
Created: 2025-10-16
---

# QEP-051: Web Framework API

## Overview

Add a Quest-level web framework (`std/web` module) to provide programmatic control over server behavior. This allows users to configure static files, CORS, middleware, and error handlers directly in their Quest scripts, which are then applied when running `quest serve`.

## Status

**Draft** - Design phase, incorporating review feedback

## Goals

- Provide clean Quest API for server configuration
- Support multiple static file directories with custom mount points
- Enable CORS, timeouts, middleware, and error handlers
- Maintain simplicity for basic use cases
- Clear separation: Quest = config/logic, Rust = server runtime
- No threading complexity (configuration runs synchronously before server starts)

## Motivation

Currently, the web server has limited configuration:
- Static files must be in `public/` directory, mounted at `/public/*`
- No way to serve multiple static directories
- No programmatic CORS configuration
- No custom error handlers or middleware
- Limited control over timeouts and request limits

This makes it difficult to build real-world applications that need:
- Custom static asset organization (separate `/css`, `/js`, `/images` paths)
- API servers with CORS for frontend development
- Custom 404 pages and error handling
- Request logging and authentication middleware

A unified `std/web` framework module provides a clean, intuitive API for web development without nested module paths.

## Rationale

### Why Hybrid Configuration (Settings + Imperative API)?

**Declarative (`.settings.toml`):**
- Environment-specific config (dev/staging/prod ports, timeouts)
- Easy to version control and review
- Works with Quest's existing settings system
- Validated on startup (type checking, ranges)

**Imperative (function calls):**
- Application-specific logic (route-based static dirs, custom hooks)
- Functions can't be stored in TOML (hooks, error handlers)
- Dynamic configuration based on runtime conditions
- Natural for scripting use cases

**Best of both worlds:** Base config in TOML, customization in code.

### Why Configuration via Module (No server.start())?

- **Clear separation of concerns:** Quest = config/logic, Rust = server runtime
- **Avoids threading and scope isolation complexity:** Script runs once synchronously
- **Consistent with industry patterns:** nginx config vs nginx binary, Apache config vs httpd
- **Simpler mental model:** Configuration is setup, CLI is execution
- **Easier to test:** Just verify config is set correctly

### Why Before/After Hooks vs Middleware Classes?

- Simpler for common cases (logging, auth, headers)
- Consistent with Quest's functional style
- Can layer multiple hooks easily
- Lower learning curve than OOP middleware patterns

### Why These Specific APIs?

- **Static files:** Most requested feature for real-world apps
- **CORS:** Essential for API development with separate frontends
- **Hooks:** Flexible middleware without complex abstractions
- **Error handlers:** Professional error pages are table stakes
- **Request limits:** Security and stability requirements

## Design

### Hybrid Configuration Model

Quest web server uses a **hybrid configuration approach**:

1. **Declarative configuration** via `quest.toml` - Base configuration loaded at startup (see QEP-053)
2. **Imperative API** via `std/web` module - Scripts can modify/extend configuration
3. **Execution order**: Configuration → Script modifications → Server starts

This provides both convenience (sensible defaults in `quest.toml`) and flexibility (programmatic configuration in scripts).

### Module Structure

Create `lib/std/web.q` as a unified web framework module following QEP-053 pattern:

**lib/std/web.q:**
```quest
use "std/conf" as conf
use "std/validate" as v

pub type Configuration
    str?: host = "127.0.0.1"
    num?: port = 3000
    num?: max_body_size = 10485760  # 10MB
    num?: max_header_size = 8192    # 8KB
    num?: request_timeout = 30
    num?: keepalive_timeout = 60

    fun validate_port(value)
        v.range(1, 65535)(value)
    end

    fun validate_max_body_size(value)
        v.min(1024)(value)  # At least 1KB
    end

    fun validate_request_timeout(value)
        v.min(1)(value)
    end

    static fun from_dict(dict)
        # Standard QEP-053 factory method
        let config = Configuration.new()
        if dict.contains("host")
            config.host = dict["host"]
        end
        # ... etc
        return config
    end
end

# Register schema and load configuration (QEP-053)
conf.register_schema("std.web", Configuration)
pub let conf = conf.get_config("std.web")

# Runtime configuration state (for imperative API)
let _runtime_config = {
    "static_dirs": [],
    "cors": nil,
    "before_hooks": [],
    "after_hooks": [],
    "error_handlers": {},
    "redirects": {},
    "default_headers": {}
}

# Imperative API (modifies _runtime_config)
# ... exports defined below ...
```

### Execution Model

1. **Startup**: Quest loads `quest.toml` and environment-specific overrides (QEP-053)
2. **User runs**: `quest serve --port 3000 app.q`
3. **Script execution**: `app.q` loads `std/web`, which loads configuration via `std/conf`
4. **Script modifications**: User calls `web.add_static()`, etc. to modify runtime configuration
5. **Server start**: After script completes, Rust reads configuration and starts server

**quest.toml example:**
```toml
[std.web]
host = "0.0.0.0"
port = 8080
max_body_size = 52428800  # 50MB
request_timeout = 60
keepalive_timeout = 120
```

**app.q example:**
```quest
use "std/web" as web

# Base config comes from quest.toml (via std/conf)
# Access via web.conf.host, web.conf.port, etc.

# Add application-specific runtime configuration
web.add_static('/assets', './public')
web.add_static('/images', './static/images')
web.set_cors(origins: ["https://example.com"], methods: ["GET", "POST"])

fun handle_request(request)
    {"status": 200, "body": "Hello on port " .. web.conf.port}
end

# Run with: quest serve app.q
# Server uses port 8080 from quest.toml + static dirs from script
```

### Core API Methods

#### 1. Static File Serving

**Priority: HIGH** - Your first request, most commonly needed

```quest
# Add static file directory
web.add_static(url_path: Str, fs_path: Str)

# Examples
web.add_static('/assets', '/home/user/public')     # Absolute path
web.add_static('/css', './static/css')             # Relative path
web.add_static('/images', './images')              # Multiple directories
web.add_static('/', './public')                    # Root mount (serve SPA)

# Behavior
# - Files in fs_path are served at url_path
# - Example: ./static/css/style.css → /css/style.css
# - Supports nested paths: /css/vendor/bootstrap.css
# - 404 if file not found (falls through to handle_request)
# - Automatic MIME type detection
# - Last-modified headers for caching
# - Path traversal protection (../ is blocked automatically)
```

**Static File Precedence:**

When multiple routes overlap, the **longest (most specific) path wins**:

```quest
web.add_static('/assets', './public')
web.add_static('/assets/premium', './special')

# GET /assets/premium/video.mp4
# → Serves from ./special/video.mp4 (longer path takes precedence)

# GET /assets/common/style.css
# → Serves from ./public/common/style.css (only matching route)
```

This "longest path wins" behavior is:
- **Intuitive:** Specific paths override general ones
- **Order-independent:** Works regardless of registration order
- **Predictable:** Similar to nginx location matching

If you call `add_static()` twice with the **same URL path**, the second call **replaces** the first:

```quest
web.add_static('/public', './dir1')
web.add_static('/public', './dir2')  # /public/* now serves from ./dir2
```

**Implementation:** Routes are automatically sorted by path length (longest first) before being registered with the server.

#### 2. CORS Configuration

**Priority: HIGH** - Essential for API development with separate frontends

```quest
# Configure CORS (Cross-Origin Resource Sharing)
web.set_cors(
    origins: Array[Str],        # Allowed origins (or ["*"] for all)
    methods: Array[Str],         # Allowed methods
    headers: Array[Str],         # Allowed headers
    credentials: Bool           # Allow cookies/auth
)

# Examples
# Development: Allow all origins
web.set_cors(
    origins: ["*"],
    methods: ["GET", "POST", "PUT", "DELETE"],
    headers: ["Content-Type", "Authorization"]
)

# Production: Specific origins
web.set_cors(
    origins: ["https://example.com", "https://app.example.com"],
    methods: ["GET", "POST"],
    headers: ["Content-Type"],
    credentials: true
)

# Disable CORS (default behavior)
web.disable_cors()
```

#### 3. Request Limits

**Priority: MEDIUM** - Important for security and stability

```quest
# Set maximum request body size (bytes)
web.set_max_body_size(size: Int)

# Set maximum header size (bytes)
web.set_max_header_size(size: Int)

# Examples
web.set_max_body_size(10 * 1024 * 1024)   # 10 MB
web.set_max_body_size(100 * 1024)         # 100 KB for APIs
web.set_max_header_size(16 * 1024)        # 16 KB headers

# Defaults
# - max_body_size: 10 MB
# - max_header_size: 8 KB
```

#### 4. Timeout Configuration

**Priority: MEDIUM** - Prevents resource exhaustion

```quest
# Set request timeout (seconds)
web.set_request_timeout(seconds: Int)

# Set keep-alive timeout (seconds)
web.set_keepalive_timeout(seconds: Int)

# Examples
web.set_request_timeout(30)      # 30 seconds per request
web.set_keepalive_timeout(60)    # Keep connections alive 60 seconds

# Defaults
# - request_timeout: 30 seconds
# - keepalive_timeout: 60 seconds
```

#### 5. Middleware/Hooks

**Priority: HIGH** - Extremely useful for logging, auth, headers

```quest
# Before request hook (runs before handle_request)
web.before_request(handler: Fun)

# After request hook (runs after handle_request)
web.after_request(handler: Fun)

# Examples

# Logging middleware
web.before_request(fun (req)
    puts(req["method"], " ", req["path"])
    return req  # Must return request (can modify)
end)

# Add security headers
web.after_request(fun (req, resp)
    resp["headers"]["X-Frame-Options"] = "DENY"
    resp["headers"]["X-Content-Type-Options"] = "nosniff"
    return resp  # Must return response
end)

# Authentication
web.before_request(fun (req)
    if req["path"].starts_with("/api/")
        let token = req["headers"]["authorization"]
        if not validate_token(token)
            # Return response early (short-circuits to after_request)
            return {
                "status": 401,
                "json": {"error": "Unauthorized"}
            }
        end
    end
    return req
end)

# Multiple hooks execute in registration order
web.before_request(hook1)
web.before_request(hook2)  # Runs after hook1
```

**Hook Signatures:**

```quest
# Before hook
fun before_hook(request: Dict) -> Dict | Dict
    # Return request to continue, or response Dict to short-circuit
end

# After hook
fun after_hook(request: Dict, response: Dict) -> Dict
    # Return modified response
end
```

**Hook Return Value Detection:**

Before hooks can return either a **request dict** (continue to next hook/handler) or a **response dict** (short-circuit, skip remaining hooks and handler).

Rust distinguishes between them by checking if the returned dict has a `status` field:

```rust
// Check for response indicators
fn is_response_dict(dict: &QDict) -> bool {
    dict.contains_key("status")
}
```

Examples:

```quest
# Return request (continue)
fun before_hook(req)
    req["processed"] = true
    return req  # Continue to next hook/handler
end

# Return response (short-circuit)
fun before_hook(req)
    return {
        "status": 401,
        "json": {"error": "Unauthorized"}
    }  # Skip remaining hooks and handler
end
```

#### 6. Error Handlers

**Priority: MEDIUM** - Polished error pages, custom handling

```quest
# Register error handler for specific status code
web.on_error(status: Int, handler: Fun)

# Examples

# Custom 404 page
web.on_error(404, fun (req)
    {
        "status": 404,
        "headers": {"content-type": "text/html"},
        "body": render_template("404.html", {"path": req["path"]})
    }
end)

# Custom 500 page
web.on_error(500, fun (req, error)
    log_error(error)  # Log to file
    {
        "status": 500,
        "body": "Internal Server Error"
    }
end)

# Generic error handler (catches all not handled specifically)
web.on_error(0, fun (req, error)
    {
        "status": 500,
        "json": {"error": "Something went wrong"}
    }
end)
```

**Error Handler Signatures:**

```quest
# For 4xx errors (client errors, no exception)
fun error_handler_4xx(request: Dict) -> Dict
end

# For 5xx errors (server errors, includes exception)
fun error_handler_5xx(request: Dict, error: Str) -> Dict
end
```

**Error Handler Safety:**

Error handlers **must not raise exceptions**. If an error handler fails:

1. Rust catches the exception
2. Returns generic 500 response with no custom handling
3. Logs the error handler failure

**Best practice:** Keep error handlers simple and defensive:

```quest
web.on_error(500, fun (req, error)
    try
        log_error(error)  # Might fail
    catch e
        # Swallow error, don't propagate
    end
    {"status": 500, "body": "Internal Server Error"}
end)
```

#### 7. Redirects

**Priority: LOW** - Nice to have, but can be done in handle_request

```quest
# Add permanent or temporary redirect
web.redirect(from: Str, to: Str, status: Int = 302)

# Examples
web.redirect("/old-path", "/new-path", 301)       # Permanent
web.redirect("/docs", "/documentation")           # Temporary (302)
web.redirect("/home", "/")                        # Simplify URLs

# Behavior
# - Processed before handle_request
# - Returns {status: 301/302, headers: {location: to}}
# - Supports wildcards? (Phase 2)
```

#### 8. Default Response Headers

**Priority: MEDIUM** - Security headers, common across all responses

```quest
# Set default headers for all responses
web.set_default_headers(headers: Dict)

# Examples
web.set_default_headers({
    "X-Frame-Options": "DENY",
    "X-Content-Type-Options": "nosniff",
    "X-XSS-Protection": "1; mode=block",
    "Strict-Transport-Security": "max-age=31536000"
})

# Behavior
# - Applied to all responses (unless overridden)
# - Response-specific headers take precedence
# - Useful for security headers
```

### Full Example

```quest
use "std/web" as web
use "std/html/templates" as templates

# Load templates once
let tmpl = templates.from_dir("templates/**/*.html")

# Configure static files
web.add_static('/css', './static/css')
web.add_static('/js', './static/js')
web.add_static('/images', './static/images')

# Configure CORS for API routes
web.set_cors(
    origins: ["http://localhost:5173"],  # Vite dev server
    methods: ["GET", "POST", "PUT", "DELETE"],
    headers: ["Content-Type", "Authorization"],
    credentials: true
)

# Security headers
web.set_default_headers({
    "X-Frame-Options": "SAMEORIGIN",
    "X-Content-Type-Options": "nosniff"
})

# Request logging
web.before_request(fun (req)
    puts("[", time.now().iso(), "] ", req["method"], " ", req["path"])
    return req
end)

# Authentication for admin routes
web.before_request(fun (req)
    if req["path"].starts_with("/admin/")
        let session = req["cookies"]["session"]
        if not validate_session(session)
            return {
                "status": 302,
                "headers": {"location": "/login"}
            }
        end
    end
    return req
end)

# Custom 404
web.on_error(404, fun (req)
    {
        "status": 404,
        "headers": {"content-type": "text/html"},
        "body": tmpl.render("404.html", {"path": req["path"]})
    }
end)

# Route handler
fun handle_request(request)
    let path = request["path"]

    if path == "/"
        let html = tmpl.render("home.html", {"title": "Home"})
        {"status": 200, "headers": {"content-type": "text/html"}, "body": html}
    elif path == "/api/users"
        {"status": 200, "json": get_users()}
    else
        {"status": 404, "body": "Not found"}
    end
end

# Run with: quest serve --port 3000 app.q
```

## Security Considerations

### Path Traversal Protection

- `tower_http::ServeDir` automatically prevents `../` path traversal attacks
- No additional Quest-level validation required
- Static files are safely confined to configured directories

### CORS Configuration

- **Development:** Using `origins: ["*"]` is convenient but insecure
- **Production:** Always specify exact origins: `["https://app.example.com"]`
- Be cautious with `credentials: true` (allows cookies/auth)

### Request Size Limits

- Default 10MB body size prevents basic DoS attacks
- Adjust based on your use case (smaller for APIs, larger for file uploads)
- Header size limit (8KB) prevents header overflow attacks

### Error Handlers

- **Never** leak sensitive information in error messages
- Log detailed errors server-side, show generic messages to clients
- Be careful with stack traces in production

### Input Validation

- Quest code in `handle_request` must validate all user input
- Don't trust headers, query params, or body content
- Use parameterized queries for database access

### Timeout Protection

- Default 30s request timeout prevents resource exhaustion
- Adjust based on expected operation times
- Keep-alive timeout (60s) balances performance and resource usage

## Implementation Plan

### Phase 1: Core Infrastructure (Rust Side)

**Extend ServerConfig struct** to support:
- Static file directories (Vec of url_path, fs_path tuples)
- CORS configuration
- Request limits (body size, header size)
- Timeouts (request, keepalive)
- Hooks stored as QUserFun
- Error handlers stored as QUserFun
- Redirects and default headers

**Middleware integration** using tower-http layers for CORS, timeouts, and request limits.

**Hook execution** in request handler with short-circuit detection.

### Phase 2: Quest Module (lib/std/web.q)

**Module structure:**

```quest
# lib/std/web.q
# Quest-level API for web framework

# Global configuration object (used by Rust when starting server)
let _config = {
    "static_dirs": [],
    "cors": nil,
    "max_body_size": 10 * 1024 * 1024,
    "max_header_size": 8 * 1024,
    "request_timeout": 30,
    "keepalive_timeout": 60,
    "before_hooks": [],
    "after_hooks": [],
    "error_handlers": {},
    "redirects": {},
    "default_headers": {}
}

# Exported functions
let exports = {}

exports.add_static = fun (url_path, fs_path)
    _config["static_dirs"].push([url_path, fs_path])
end

exports.set_cors = fun (*args, **kwargs)
    _config["cors"] = {
        "origins": kwargs["origins"],
        "methods": kwargs["methods"],
        "headers": kwargs["headers"] or [],
        "credentials": kwargs["credentials"] or false
    }
end

exports.disable_cors = fun ()
    _config["cors"] = nil
end

exports.set_max_body_size = fun (size)
    _config["max_body_size"] = size
end

exports.set_max_header_size = fun (size)
    _config["max_header_size"] = size
end

exports.set_request_timeout = fun (seconds)
    _config["request_timeout"] = seconds
end

exports.set_keepalive_timeout = fun (seconds)
    _config["keepalive_timeout"] = seconds
end

exports.before_request = fun (handler)
    _config["before_hooks"].push(handler)  # Store function directly!
end

exports.after_request = fun (handler)
    _config["after_hooks"].push(handler)
end

exports.on_error = fun (status, handler)
    _config["error_handlers"][status.str()] = handler
end

exports.redirect = fun (from, to, status = 302)
    _config["redirects"][from] = [to, status]
end

exports.set_default_headers = fun (headers)
    _config["default_headers"] = headers
end

# Internal functions for Rust to retrieve configuration
exports._get_config = fun ()
    return _config
end

return exports
```

### Phase 3: Rust-Quest Bridge

**Simplified function storage (no threading needed!):**

```rust
// After executing app.q, retrieve config and hooks
pub fn load_web_config(scope: &mut Scope) -> Result<ServerConfig, String> {
    // Get config dict
    let config_value = call_quest_function("web._get_config", vec![], scope)?;
    let config_dict = config_value.as_dict()?;

    // Parse config dict into ServerConfig struct
    let static_dirs = parse_static_dirs(config_dict.get("static_dirs"))?;
    let cors = parse_cors_config(config_dict.get("cors"))?;
    // ... etc

    // Get hooks (as QValue::UserFun)
    let before_hooks_value = call_quest_function("web._get_before_hooks", vec![], scope)?;
    let before_hooks_array = before_hooks_value.as_array()?;
    let mut before_hooks = Vec::new();
    for hook_func in before_hooks_array {
        // Extract QValue::UserFun and store for later execution
        if let QValue::UserFun(func) = hook_func {
            before_hooks.push(func.clone());
        }
    }

    // Same for after_hooks and error_handlers
    // ...

    Ok(ServerConfig {
        static_dirs,
        cors,
        before_hooks,
        after_hooks,
        error_handlers,
        // ...
    })
}
```

**Much simpler** because there's no multi-threading - the script runs once, synchronously, before the server starts.

**ServerConfig updated to store functions directly:**

```rust
pub struct ServerConfig {
    pub host: String,
    pub port: u16,
    pub script_source: String,
    pub script_path: String,

    // Static files: Vec of (url_path, fs_path)
    pub static_dirs: Vec<(String, String)>,

    // CORS configuration
    pub cors: Option<CorsConfig>,

    // Request limits
    pub max_body_size: usize,
    pub max_header_size: usize,

    // Timeouts
    pub request_timeout: u64,
    pub keepalive_timeout: u64,

    // Hooks (stored as Quest UserFun directly!)
    pub before_hooks: Vec<QUserFun>,
    pub after_hooks: Vec<QUserFun>,

    // Error handlers (status code → UserFun)
    pub error_handlers: HashMap<u16, QUserFun>,

    // Redirects (from → (to, status))
    pub redirects: HashMap<String, (String, u16)>,

    // Default headers
    pub default_headers: HashMap<String, String>,
}
```

## Skipped Features (For This QEP)

The following features are explicitly **NOT** included in this QEP:

### 1. SSL/TLS Configuration
**Reason:** Complex, requires cert management, most production deployments use reverse proxy (nginx/Caddy) for SSL termination.

**Future QEP:** Add if there's strong demand for development use.

```quest
# NOT IN THIS QEP
server.enable_ssl(
    cert_file: "/path/to/cert.pem",
    key_file: "/path/to/key.pem"
)
```

### 2. Rate Limiting
**Reason:** Complex, requires state management, better handled by reverse proxy or third-party service in production.

**Future QEP:** Could be added as middleware layer.

```quest
# NOT IN THIS QEP
server.set_rate_limit(
    requests: 100,
    per: 60,
    by: "client_ip"
)
```

### 3. Static Directory Priority
**Reason:** Adds complexity, unclear use case. First match wins (simple rule).

**Alternative:** Use more specific paths or organize files better.

```quest
# NOT IN THIS QEP
server.add_static('/public', './public', priority: 1)
server.add_static('/public', './fallback', priority: 2)

# Instead: Be explicit
server.add_static('/public/main', './public')
server.add_static('/public/fallback', './fallback')
```

### 4. Compression
**Reason:** Low priority, reverse proxy handles this better, marginal benefit for dynamic content.

**Future QEP:** Could be added if benchmarks show significant benefit.

```quest
# NOT IN THIS QEP
server.enable_compression(["gzip", "br", "deflate"])
server.set_compression_level(6)
```

## Testing Strategy

### Unit Tests (Rust)

```rust
#[test]
fn test_static_file_routing() {
    let config = ServerConfig {
        static_dirs: vec![
            ("/css".to_string(), "./static/css".to_string()),
            ("/js".to_string(), "./static/js".to_string()),
        ],
        // ...
    };

    // Test that routes are created correctly
}

#[test]
fn test_cors_configuration() {
    // Test CORS headers are set correctly
}

#[test]
fn test_before_hook_execution() {
    // Test hooks execute in order
}

#[test]
fn test_hook_short_circuit() {
    // Test before hook can return response early
}
```

### Integration Tests (Quest)

```quest
# test/server/config_test.q

use "std/test" as test
use "std/web" as web
use "std/http/client" as http

test.module("Web Framework Configuration")

test.describe("Static files", fun ()
    test.it("serves files from multiple directories", fun ()
        # Start test server with config
        # Make requests to /css/style.css, /js/app.js
        # Assert correct content returned
    end)
end)

test.describe("CORS", fun ()
    test.it("sets CORS headers correctly", fun ()
        # Make request with Origin header
        # Assert CORS headers in response
    end)
end)

test.describe("Middleware", fun ()
    test.it("executes before hooks in order", fun ()
        # Configure multiple before hooks
        # Assert execution order
    end)

    test.it("allows before hook to short-circuit", fun ()
        # Configure auth hook that returns 401
        # Assert handle_request not called
    end)
end)
```

### Manual Testing

```bash
# Create example app with all features
quest examples/web/full_config.q

# Test with curl
curl http://localhost:3000/css/style.css
curl -H "Origin: http://example.com" http://localhost:3000/api/users
curl http://localhost:3000/old-path  # Should redirect

# Load testing
wrk -t4 -c100 -d30s http://localhost:3000/
```

## Documentation

### Update docs/docs/webserver.md

Add sections:
- **Configuration API** - Overview of `std/web`
- **Static Files** - How to serve multiple directories
- **CORS** - Enable CORS for API development
- **Middleware** - Before/after hooks for logging, auth
- **Error Handlers** - Custom 404/500 pages
- **Full Example** - Complete app showing all features

### Update CLAUDE.md

Add:
```markdown
## Web Framework

Quest provides a unified web framework via `std/web`:

```quest
use "std/web" as web

web.add_static('/assets', './public')
web.set_cors(origins: ["*"], methods: ["GET", "POST"])
web.before_request(fun (req) ... end)

fun handle_request(request)
    {"status": 200, "body": "Hello"}
end

# Run with: quest serve app.q
```

See [Web Server docs](docs/docs/webserver.md) for full details.
```

## Migration Path

### Existing Code (CLI-based)

```bash
# Old way: CLI arguments only
quest serve --port 3000 app.q
```

**Still works!** No breaking changes.

### New Code (Configuration API)

```quest
# New way: Configuration in script
use "std/web" as web

web.add_static('/assets', './public')
web.set_cors(origins: ["*"])

fun handle_request(request)
    {"status": 200, "body": "Hello"}
end

# Run with: quest serve --port 3000 app.q
```

### CLI Override Behavior

CLI arguments **override** script configuration:

```bash
quest serve --port 8080 app.q
# CLI port 8080 takes precedence over any script config
```

## Success Criteria

- ✅ Can serve static files from multiple directories
- ✅ Can enable CORS programmatically
- ✅ Can add logging middleware
- ✅ Can customize error pages
- ✅ Configuration is clean and intuitive
- ✅ No breaking changes to existing `quest serve`
- ✅ All tests pass
- ✅ Documentation complete with examples

## Implementation Decisions

1. **Function storage:** Store Quest UserFun directly in module scope, retrieve after script execution. Simple and clean since there's no multi-threading.

2. **CLI vs programmatic priority:** CLI args override script config (allows overrides for testing).

3. **Error handler signatures:** Different signatures - 5xx handlers get error message, 4xx handlers don't.

4. **Static file precedence:** Same URL path = second call replaces first. Different URL paths = both work independently.

5. **Hook short-circuiting:** Check for `status` field in returned dict to distinguish request vs response.

6. **Error handler safety:** If error handler fails, return generic 500 response and log the failure.

## Timeline

### Week 1: Core Infrastructure (Rust)
- Extend `ServerConfig` struct
- Implement static file routing (tower-http ServeDir)
- Implement CORS layer (tower-http CorsLayer)
- Implement timeout/limit layers

### Week 2: Quest Module (Configuration Only)
- Implement `lib/std/web.q` (config API only)
- Store configuration in module scope
- Implement function storage for hooks (simple arrays)
- Export config retrieval functions for Rust

### Week 3: Rust-Quest Bridge
- Load and execute script via `quest serve app.q`
- Retrieve configuration from Quest module
- Extract hooks/error handlers as `QValue::UserFun`
- Start server with configured settings
- Implement hook execution in request handler

### Week 4: Testing & Documentation
- Unit tests (Rust) - Config loading, middleware application
- Integration tests (Quest) - End-to-end server testing
- Manual testing / examples
- Documentation updates (webserver.md, CLAUDE.md)

## References

- [QEP-053: Module Configuration System](qep-053-module-configuration-system.md) - Configuration schema and loading system
- [QEP-028: Serve Command](qep-028-serve-command.md) - Original web server spec
- Related: [QEP-052: File Upload Support](qep-052-file-upload-support.md) - Complementary file handling features
- axum middleware: https://docs.rs/axum/latest/axum/middleware/
- tower-http: https://docs.rs/tower-http/latest/tower_http/
- CORS spec: https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
