# Quest Serve Command - Specification

## Overview

Add a multi-threaded web server to Quest via the `quest serve` command. The server runs Quest scripts on every HTTP request with complete isolation (no shared state between requests). Each request creates a fresh interpreter instance.

## Goals

- Enable web application development in Quest
- Complete request isolation (separate Scope per request)
- Integration with existing Quest features (templates, databases, HTTP client)
- Simple request/response contract via Dicts
- Support for .settings.toml configuration files
- Production-ready performance with async/multi-threaded architecture

## Architecture

### Web Framework

**Choice: axum 0.7**
- Modern, ergonomic API
- Built on tokio (already in use for HTTP client)
- Excellent performance
- Strong ecosystem integration
- Tower middleware support

### Request Flow

```
HTTP Request
    ↓
Axum Handler (async)
    ↓
Create fresh Scope (complete isolation)
    ↓
Load .settings.toml (if exists)
    ↓
Set environment variables from [os.environ]
    ↓
Load user's Quest script
    ↓
Call handle_request(request_dict) function
    ↓
Script returns response_dict
    ↓
Convert to HTTP response
    ↓
Send response to client
```

### Request Isolation

**Critical:** Each request must have ZERO shared state.

- New `Scope` created per request
- Fresh script load and execution
- Independent variable namespace
- Separate module imports
- No global state between requests

**Performance consideration:** Script parsing/compilation may be cached in future, but execution state is always isolated.

### Error Handling

- **Script errors** → 500 Internal Server Error response
- **Missing handle_request()** → Error on server startup
- **Invalid response Dict** → 500 with error message
- **Timeout exceeded** → 503 Service Unavailable
- **Parse errors** → Error on server startup (fail fast)

## Request Dictionary Format

The server converts incoming HTTP requests to a Quest Dict and passes it to the user's `handle_request()` function.

```quest
{
    "method": "GET",           # HTTP method (GET, POST, PUT, DELETE, etc.)
    "path": "/users/123",      # URL path
    "query": {                 # Query parameters as Dict
        "filter": "active",
        "limit": "10"
    },
    "headers": {               # Request headers (lowercase keys)
        "content-type": "application/json",
        "authorization": "Bearer token123",
        "user-agent": "Mozilla/5.0..."
    },
    "body": "...",             # Request body (String or Bytes)
    "cookies": {               # Parsed cookies
        "session": "abc123",
        "user_id": "456"
    },
    "remote_addr": "127.0.0.1:54321",  # Client IP and port
    "version": "HTTP/1.1"      # HTTP version
}
```

## Response Dictionary Format

The user's script must return a Dict with the following structure:

**Minimal response:**
```quest
{
    "status": 200,
    "body": "Hello, World!"
}
```

**Full response:**
```quest
{
    "status": 200,
    "headers": {
        "content-type": "text/html",
        "cache-control": "no-cache",
        "x-custom-header": "value"
    },
    "cookies": {                    # Optional: Set cookies
        "session": {
            "value": "abc123",
            "max_age": 3600,        # Seconds
            "path": "/",
            "domain": "example.com",
            "secure": true,
            "http_only": true,
            "same_site": "Lax"      # "Strict", "Lax", or "None"
        }
    },
    "body": "<html>...</html>"
}
```

**JSON response shorthand:**
```quest
{
    "status": 200,
    "json": {"users": [...]}    # Automatically sets content-type and serializes
}
```

**Redirect response:**
```quest
{
    "status": 302,
    "headers": {"location": "/new-path"}
}
```

## User Script Interface

Every Quest script used with `quest serve` must define a `handle_request` function:

```quest
fun handle_request(request)
    # request is Dict with method, path, headers, body, etc.
    # Must return Dict with status, headers, body

    {
        "status": 200,
        "headers": {"content-type": "text/plain"},
        "body": "Hello, World!"
    }
end
```

**Validation on startup:**
- Server checks that `handle_request` function exists
- Server fails to start if function is missing or has wrong signature
- Early validation prevents runtime errors

## CLI Interface

### Basic Usage

```bash
# Run specific script
quest serve app.q

# Run index.q in directory
quest serve .
quest serve ./myapp

# Run with custom port
quest serve --port 8080 app.q
quest serve -p 3000 app.q

# Bind to specific host
quest serve --host 0.0.0.0 app.q
quest serve -h 127.0.0.1 app.q

# Both host and port
quest serve --host 0.0.0.0 --port 8000 app.q
quest serve -h 0.0.0.0 -p 8000 app.q

# Help
quest serve --help
```

### Default Behavior

- Default host: `127.0.0.1` (localhost only)
- Default port: `3000`
- If directory provided, looks for `index.q`
- Loads `.settings.toml` from script directory
- Logs startup message with URL
- Graceful shutdown on Ctrl+C

### Command-Line Arguments

```
quest serve [OPTIONS] <SCRIPT>

Arguments:
  <SCRIPT>  Path to Quest script file or directory (uses index.q)

Options:
  -h, --host <HOST>    Host to bind to [default: 127.0.0.1]
  -p, --port <PORT>    Port to bind to [default: 3000]
  --help               Print help information
```

## Configuration: .settings.toml

The server automatically loads `.settings.toml` from the script's directory before executing requests.

### File Location

1. Look in same directory as script file
2. If script is `index.q`, look in that directory
3. If not found, server starts without settings (not an error)

### Format

```toml
# Environment variables - automatically set before script execution
[os.environ]
DATABASE_URL = "postgresql://localhost/mydb"
API_KEY = "secret_key_123"
SMTP_HOST = "smtp.gmail.com"
SMTP_PORT = "587"

# Database configuration
[database]
pool_size = 10
timeout = 30
retry_attempts = 3

# Application settings
[app]
name = "My Quest App"
debug = true
version = "1.0.0"

# Any arbitrary sections
[features]
enable_analytics = false
max_upload_size = 10485760  # 10 MB
```

### Access via std/settings

See `std_settings.md` for full module specification.

## Implementation Plan

### 1. Dependencies (Cargo.toml)

```toml
axum = "0.7"
tower = "0.4"
tower-http = { version = "0.5", features = ["trace"] }
hyper = { version = "1.0", features = ["full"] }
```

### 2. New Files

**src/server.rs** (~500-600 lines)
- `ServerConfig` struct
- `start_server(config)` - Main entry point
- `create_app()` - Build axum Router
- `handle_request()` - Per-request handler
- Request/response conversion utilities
- Error handling middleware
- Logging setup

**src/modules/settings/mod.rs** (~200 lines)
- Parse .settings.toml
- Create settings module
- Runtime access functions
- See `std_settings.md` for details

### 3. Modified Files

**src/main.rs**
- Add "serve" subcommand detection
- Call `handle_serve_command()`

**src/commands.rs**
- Add `handle_serve_command(args)`
- Parse CLI arguments
- Load script and validate
- Check for `handle_request` function
- Start server

**src/modules/mod.rs**
- Add `pub mod settings;`
- Export settings module functions

## Request Handler Implementation

```rust
// src/server.rs

async fn handle_quest_request(
    config: Arc<ServerConfig>,
    req: Request<Body>
) -> Result<Response<Body>, StatusCode> {
    // Convert HTTP request to Quest Dict
    let request_dict = match http_request_to_dict(req).await {
        Ok(dict) => dict,
        Err(e) => {
            error!("Failed to convert request: {}", e);
            return Err(StatusCode::INTERNAL_SERVER_ERROR);
        }
    };

    // Create fresh Scope (complete isolation)
    let mut scope = Scope::new();

    // Load settings if available
    if let Some(ref settings_path) = config.settings_path {
        if let Ok(settings) = load_settings_toml(settings_path) {
            // Set environment variables
            if let Some(environ) = settings.get("os.environ") {
                set_environment_variables(environ);
            }

            // Register settings module
            scope.insert("settings", create_settings_module(settings));
        }
    }

    // Execute script
    let result = eval_expression(&config.script_source, &mut scope);

    // Call handle_request function
    let handler = scope.get("handle_request")
        .ok_or(StatusCode::INTERNAL_SERVER_ERROR)?;

    let response_value = match handler {
        QValue::UserFun(func) => {
            call_user_function(func, vec![request_dict], &mut scope)
        }
        _ => return Err(StatusCode::INTERNAL_SERVER_ERROR)
    };

    // Convert Quest response Dict to HTTP response
    match dict_to_http_response(response_value) {
        Ok(response) => Ok(response),
        Err(e) => {
            error!("Invalid response from script: {}", e);
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        }
    }
}
```

## Examples

### Example 1: Hello World

**hello.q**
```quest
fun handle_request(request)
    {
        "status": 200,
        "headers": {"content-type": "text/plain"},
        "body": "Hello, World!"
    }
end
```

Run: `quest serve hello.q`

### Example 2: Echo Server

**echo.q**
```quest
use "std/encoding/json" as json

fun handle_request(request)
    {
        "status": 200,
        "headers": {"content-type": "application/json"},
        "json": {
            "method": request.method,
            "path": request.path,
            "query": request.query,
            "headers": request.headers
        }
    }
end
```

### Example 3: HTML Templates

**app.q**
```quest
use "std/html/templates" as templates

let tmpl = templates.from_dir("templates/**/*.html")

fun handle_request(request)
    if request.path == "/"
        let html = tmpl.render("home.html", {
            "title": "Welcome",
            "user": request.query.name or "Guest"
        })
        {
            "status": 200,
            "headers": {"content-type": "text/html"},
            "body": html
        }
    elif request.path == "/about"
        let html = tmpl.render("about.html", {"title": "About Us"})
        {"status": 200, "headers": {"content-type": "text/html"}, "body": html}
    else
        {"status": 404, "body": "Not Found"}
    end
end
```

Run: `quest serve app.q`

### Example 4: JSON API with Database

**api.q**
```quest
use "std/encoding/json" as json
use "std/db/sqlite" as db
use "std/settings" as settings

# Open database connection
let db_path = settings.get("database.path") or "app.db"
let conn = db.connect(db_path)

fun handle_request(request)
    if request.method == "GET" and request.path == "/api/users"
        # Fetch users from database
        let cursor = conn.cursor()
        cursor.execute("SELECT id, name, email FROM users")
        let users = cursor.fetch_all()

        {
            "status": 200,
            "headers": {"content-type": "application/json"},
            "json": {"users": users}
        }

    elif request.method == "POST" and request.path == "/api/users"
        # Parse JSON body
        let data = json.parse(request.body)

        # Insert into database
        let cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO users (name, email) VALUES (?, ?)",
            [data.name, data.email]
        )
        conn.commit()

        {
            "status": 201,
            "headers": {"content-type": "application/json"},
            "json": {"id": cursor.row_count(), "message": "User created"}
        }

    else
        {
            "status": 404,
            "headers": {"content-type": "application/json"},
            "json": {"error": "Not found"}
        }
    end
end
```

**.settings.toml**
```toml
[database]
path = "production.db"
```

Run: `quest serve api.q`

### Example 5: Routing with Pattern Matching

**routes.q**
```quest
use "std/regex" as regex

fun handle_request(request)
    let path = request.path

    # Home page
    if path == "/"
        {"status": 200, "body": "Home Page"}

    # User profile: /users/123
    elif regex.match("^/users/(\\d+)$", path)
        let captures = regex.captures("^/users/(\\d+)$", path)
        let user_id = captures.1
        {"status": 200, "body": "User profile: " .. user_id}

    # API endpoints
    elif path.starts_with("/api/")
        handle_api_request(request)

    # Static files
    elif path.starts_with("/static/")
        handle_static(request)

    # 404
    else
        {"status": 404, "body": "Page not found"}
    end
end

fun handle_api_request(request)
    {"status": 200, "json": {"message": "API endpoint"}}
end

fun handle_static(request)
    {"status": 200, "body": "Static file content"}
end
```

## Security Considerations

### Input Validation
- Request body size limit: 10 MB (configurable)
- Header count limit: 100 headers
- Header size limit: 8 KB per header
- Query parameter validation
- Path traversal prevention

### Request Timeouts
- Default request timeout: 30 seconds
- Script execution timeout: 60 seconds (prevents infinite loops)
- Configurable via settings

### Environment Isolation
- Each request runs in fresh Scope
- No global state mutation
- Environment variables only set per-request
- Database connections should be per-request or pooled safely

### Error Message Handling
- Production mode: Generic error messages to clients
- Development mode: Detailed error messages (optional flag)
- Always log full errors server-side

## Performance Considerations

### Multi-threading
- Axum/tokio handles concurrency automatically
- Each request runs on tokio thread pool
- Blocking Quest execution wrapped in spawn_blocking

### Optimization Opportunities
- Cache parsed AST (future optimization)
- Connection pooling for databases
- Template pre-loading
- Static file serving bypass Quest execution

### Benchmarks (Target)
- Simple "Hello World": 5000+ req/s
- JSON API with database: 1000+ req/s
- Template rendering: 500+ req/s

## Testing Strategy

### Unit Tests
- Request → Dict conversion
- Dict → Response conversion
- Settings loading
- Error handling

### Integration Tests
**test/server/basic_test.q**
```quest
use "std/http/client" as http
use "std/test" as test

test.module("Web Server")

test.describe("Basic requests", fun ()
    test.it("responds to GET /", fun ()
        let resp = http.get("http://localhost:3000/")
        test.assert_eq(resp.status(), 200, nil)
    end)
end)
```

### Manual Testing
- Create sample applications
- Test with curl, browsers
- Load testing with `wrk` or similar tools

## Documentation

**docs/docs/webserver.md** (~500 lines)
- Getting started guide
- CLI usage
- Request/response format
- Routing patterns
- Database integration
- Template usage
- Configuration with .settings.toml
- Error handling
- Deployment guide
- Performance tuning

**Update CLAUDE.md**
- Add serve command documentation
- Add usage examples
- Link to webserver.md

## Phase 1 Deliverables

✅ Basic HTTP server with axum
✅ Request Dict → Script → Response Dict
✅ CLI integration (quest serve)
✅ Complete isolation (fresh Scope per request)
✅ .settings.toml loading and std/settings module
✅ Error handling with appropriate status codes
✅ Examples (hello, HTML templates, JSON API, routing)
✅ Documentation (webserver.md, CLAUDE.md updates)
✅ Basic tests

## Future Enhancements (Phase 2+)

- **Response streaming** - For large responses, SSE, etc.
- **WebSocket support** - Real-time bidirectional communication
- **Static file serving** - Optimized bypass for static assets
- **Hot reloading** - Watch script file for changes
- **Middleware system** - Logging, auth, rate limiting as Quest functions
- **Session management** - Built-in session store
- **Request logging** - Structured logging for all requests
- **Metrics/monitoring** - Prometheus endpoints
- **Graceful shutdown** - Finish in-flight requests
- **SSL/TLS support** - HTTPS configuration
- **Cluster mode** - Multiple worker processes
- **Development UI** - Built-in request inspector

## Open Questions

1. Should we support async/await in Quest scripts? (Future consideration)
2. Should static file serving be built-in or separate? (Nginx proxy recommended for production)
3. Should we support WebSockets in Phase 1? (Probably Phase 2)
4. How to handle long-running requests? (Streaming in Phase 2)
5. Should we provide rate limiting? (Third-party middleware or Phase 2)

## Success Criteria

- ✅ Can build simple web apps in pure Quest
- ✅ Complete request isolation (no shared state bugs)
- ✅ Integration with templates, databases, HTTP client
- ✅ Clear error messages for common mistakes
- ✅ Good performance (1000+ req/s for simple responses)
- ✅ Easy to get started (quest serve app.q)
- ✅ Production-ready (error handling, timeouts, security)
