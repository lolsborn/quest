---
Number: QEP-061
Title: Web Server Middleware System
Author: Claude (with Steven Ruppert)
Status: Draft
Created: 2025-10-18
---

# QEP-061: Web Server Middleware System

## Overview

Introduce a flexible middleware system for Quest's web server that allows users to intercept and modify requests/responses at the server level. This enables unified logging, authentication, CORS handling, and other cross-cutting concerns through Quest code.

## Status

**Draft** - Design proposal

## Problem Statement

Currently, Quest's web server has limited extensibility:

### 1. No Request/Response Interception

- **Static files**: Served by Axum with no Quest-level visibility or logging
- **Dynamic routes**: Logging must be manually added to every handler
- **No unified access logs**: Static and dynamic routes logged differently (or not at all)

Example from blog app ([index.q:161-183](examples/web/blog/index.q#L161-L183)):
```quest
fun handle_request(req)
    # Every handler must manually log
    let path = req["path"]
    let method = req["method"]
    let client_ip = get_client_ip(req) or "unknown"
    logger.info(f"{client_ip} {method} {path}")

    # ... dispatch to route handlers
end
```

**Problems**:
- Duplicate logging code
- Static files (CSS, JS, images) are never logged
- Hard to add cross-cutting concerns (auth, timing, headers)

### 2. Limited Before/After Hooks

QEP-051 added `web.before_request()` and `web.after_request()`, but they only work for **dynamic routes**. Static files bypass these hooks entirely.

### 3. No Server-Level Control

Users cannot:
- Add security headers to all responses (static + dynamic)
- Measure request timing for all routes
- Implement custom authentication that covers static assets
- Log all requests in a unified format

## Motivation

Modern web frameworks provide middleware systems for cross-cutting concerns:

**Express.js:**
```javascript
app.use((req, res, next) => {
  console.log(`${req.method} ${req.path}`);
  next();
});

app.use(express.static('public'));  // Middleware runs for static files too
```

**Flask:**
```python
@app.before_request
def log_request():
    print(f"{request.method} {request.path}")

@app.after_request
def add_headers(response):
    response.headers['X-Custom'] = 'value'
    return response
```

**Django:**
```python
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.middleware.common.CommonMiddleware',
]
```

**Quest should provide:**
```quest
use "std/web" as web

# Middleware runs for ALL requests (static + dynamic)
web.use(fun (req)
    let logger = log.get_logger("web.access")
    req["_start_time"] = time.now()
    return req
end)

web.after(fun (req, resp)
    let duration = time.now().diff(req["_start_time"]).as_milliseconds()
    logger.info(f"{req['client_ip']} {req['method']} {req['path']} - {resp['status']} ({duration}ms)")
    return resp
end)
```

## Design

### Architecture Overview

```
Incoming Request
    ↓
[Axum Layer - Rust]
    ↓
[Init Thread Scope]
    ↓
┌─────────────────────────────────────┐
│ Quest Middleware Chain (NEW)        │
│                                     │
│  1. Execute web.use() middlewares   │
│     - Can modify request            │
│     - Can short-circuit             │
│                                     │
│  2. Try serve static file           │
│     - Axum ServeDir                 │
│                                     │
│  3. Call handle_request()           │
│     - If no static file match       │
│                                     │
│  4. Execute web.after() middlewares │
│     - Can modify response           │
│     - Add headers, log, etc.        │
└─────────────────────────────────────┘
    ↓
Response
```

### API Design

#### Request Middlewares (`web.use()`)

Middleware receives request dict, returns:
- **Modified request** (to continue chain)
- **Response dict** (to short-circuit and skip handler)

```quest
# Signature: fun (req: Dict) -> Dict
web.use(middleware_fn)
```

**Example: Add request timing**
```quest
web.use(fun (req)
    req["_start_time"] = time.now()
    return req  # Continue chain
end)
```

**Example: Authentication (short-circuit)**
```quest
web.use(fun (req)
    if req["path"].startswith("/admin")
        let token = req["headers"]["authorization"]
        if token == nil
            # Return response to skip handler
            return {
                status: 401,
                headers: {"Content-Type": "application/json"},
                body: json.stringify({error: "Unauthorized"})
            }
        end
    end

    return req  # Continue chain
end)
```

#### Response Middlewares (`web.after()`)

Middleware receives request and response dicts, returns modified response:

```quest
# Signature: fun (req: Dict, resp: Dict) -> Dict
web.after(middleware_fn)
```

**Example: Access logging**
```quest
web.after(fun (req, resp)
    let start = req["_start_time"]
    if start != nil
        let duration = time.now().diff(start).as_milliseconds()
        let logger = log.get_logger("web.access")
        logger.info(f"{req['client_ip']} {req['method']} {req['path']} - {resp['status']} ({duration}ms)")
    end
    return resp
end)
```

**Example: Add security headers**
```quest
web.after(fun (req, resp)
    if resp["headers"] == nil
        resp["headers"] = {}
    end
    resp["headers"]["X-Content-Type-Options"] = "nosniff"
    resp["headers"]["X-Frame-Options"] = "DENY"
    resp["headers"]["X-XSS-Protection"] = "1; mode=block"
    return resp
end)
```

### Middleware Execution Order

1. **Request Phase**: Execute `web.use()` middlewares in registration order
   - If any returns response dict (has `status` field), short-circuit
   - Otherwise, pass modified request to next middleware

2. **Handler Phase**:
   - Try serve static file (Axum `ServeDir`)
   - If no match, call `handle_request()` function

3. **Response Phase**: Execute `web.after()` middlewares in registration order
   - Each receives original request and current response
   - Can modify response (add headers, transform body, etc.)

### Short-Circuiting

Middleware can bypass the handler by returning a response:

```quest
web.use(fun (req)
    # Detect type of return value
    if req has "status" field → treat as response, stop chain
    else → treat as modified request, continue chain
end)
```

Implementation: Check if returned dict has `status` field:

```rust
// In execute_quest_middlewares()
let result = call_middleware(middleware_fn, request_dict)?;

if let QValue::Dict(dict) = result {
    if dict.get("status").is_some() {
        // This is a response - short-circuit
        return MiddlewareResult::ShortCircuit(dict);
    } else {
        // This is modified request - continue
        request_dict = dict;
    }
}
```

### Error Handling

Middleware errors should not crash the server:

```rust
fn execute_quest_middlewares(middlewares: &[QUserFun], request_dict: &mut QDict) -> Result<MiddlewareResult, String> {
    for middleware in middlewares {
        match call_middleware(middleware, request_dict) {
            Ok(result) => {
                // Process result
            }
            Err(e) => {
                eprintln!("Middleware error: {}", e);
                // Return 500 error response
                return MiddlewareResult::ShortCircuit(create_error_response(500, e));
            }
        }
    }
    Ok(MiddlewareResult::Continue)
}
```

### Static File Handling

Middlewares run for **all requests**, including static files:

```rust
fn handle_request_sync(state: AppState, req: Request, client_ip: String) -> Response {
    // 1. Initialize scope
    init_thread_scope(&state.config)?;

    // 2. Convert to Quest dict
    let mut request_dict = http_request_to_dict_sync(req, client_ip)?;

    // 3. Execute request middlewares (NEW)
    match execute_quest_middlewares(&state, &mut request_dict)? {
        MiddlewareResult::ShortCircuit(response) => {
            // Run after middlewares before returning
            let final_response = execute_after_middlewares(&state, &request_dict, response)?;
            return dict_to_http_response(final_response);
        }
        MiddlewareResult::Continue => {}
    }

    // 4. Try static files
    if let Some(file_response) = try_serve_static_file(&path) {
        // Convert Axum response to Quest dict for after middlewares
        let response_dict = http_response_to_quest_dict(&file_response);
        let final_response = execute_after_middlewares(&state, &request_dict, response_dict)?;
        return dict_to_http_response(final_response);
    }

    // 5. Call handle_request()
    let response_dict = call_handler(&request_dict)?;

    // 6. Execute after middlewares
    let final_response = execute_after_middlewares(&state, &request_dict, response_dict)?;

    // 7. Convert to HTTP response
    dict_to_http_response(final_response)
}
```

**Key insight**: Convert Axum's static file response to Quest dict temporarily, run after middlewares, then convert back to HTTP response. This ensures logging/header middlewares work for static files.

### Configuration Storage

Add to `std/web.q`:

```quest
let _runtime_config = {
    "static_dirs": [],
    "cors": nil,
    "middlewares": [],        # NEW: Request middlewares (web.use)
    "after_middlewares": [],  # NEW: Response middlewares (web.after)
    "before_hooks": [],       # DEPRECATED: Use middlewares instead
    "after_hooks": [],        # DEPRECATED: Use after_middlewares instead
    "error_handlers": {},
    "redirects": {},
    "default_headers": {}
}

pub fun use(middleware_fn)
    _runtime_config["middlewares"].push(middleware_fn)
end

pub fun after(middleware_fn)
    _runtime_config["after_middlewares"].push(middleware_fn)
end
```

## Built-in Middleware Library

Ship common middleware patterns in `std/web/middleware`:

### `std/web/middleware/logging.q` (Detailed Implementation)

This middleware provides unified HTTP access logging through `std/log` for both static and dynamic routes.

#### Full Implementation

```quest
# std/web/middleware/logging.q
# HTTP request/response logging middleware for Quest web server
#
# Features:
#   - Logs all requests (static files + dynamic routes)
#   - Configurable via std/log (levels, handlers, formatters)
#   - Apache Common Log Format (CLF) compatible
#   - Request timing with millisecond precision
#   - Respects X-Forwarded-For for proxy/load balancer setups

use "std/log"
use "std/time"

# Create logging middleware with custom logger
#
# Arguments:
#   logger_name: Name of logger (default: "web.access")
#   format: Log format - "clf", "combined", or "detailed" (default: "clf")
#   include_headers: Include request headers in debug mode (default: false)
#
# Returns:
#   Dict with {before: Function, after: Function}
#
# Example:
#   let log_mw = logging.create_logger("web.access", format: "combined")
#   web.use(log_mw.before)
#   web.after(log_mw.after)
pub fun create_logger(logger_name = "web.access", format = "clf", include_headers = false)
    let logger = log.get_logger(logger_name)

    return {
        # Before middleware - capture request start time
        before: fun (req)
            req["_start_time"] = time.now()
            req["_log_include_headers"] = include_headers
            return req
        end,

        # After middleware - log completed request
        after: fun (req, resp)
            let start = req["_start_time"]
            if start == nil
                # No start time, skip logging
                return resp
            end

            let duration = time.now().diff(start).as_milliseconds()
            let msg = _format_log_message(req, resp, duration, format)

            # Log at appropriate level based on status code
            let status = resp["status"] or 0
            if status >= 500
                logger.error(msg)
            elif status >= 400
                logger.warning(msg)
            else
                logger.info(msg)
            end

            # Debug mode: log request headers
            if req["_log_include_headers"] and req["headers"] != nil
                logger.debug("Request headers:")
                let keys = req["headers"].keys()
                let i = 0
                while i < keys.len()
                    let key = keys[i]
                    let value = req["headers"][key]
                    logger.debug(f"  {key}: {value}")
                    i = i + 1
                end
            end

            return resp
        end
    }
end

# Format log message according to specified format
fun _format_log_message(req, resp, duration, format)
    let client_ip = _get_client_ip(req)
    let method = req["method"] or "GET"
    let path = req["path"] or "/"
    let query = req["query_string"] or ""
    let status = resp["status"] or 0
    let version = req["version"] or "HTTP/1.1"

    # Add query string to path if present
    let full_path = path
    if query != ""
        full_path = path .. "?" .. query
    end

    if format == "clf"
        # Apache Common Log Format
        # 127.0.0.1 - - [18/Oct/2025:12:34:56 +0000] "GET /index.html HTTP/1.1" 200 2326
        let timestamp = time.now_local().format("[%d/%b/%Y:%H:%M:%S %z]")
        let user = "-"  # Auth user (not implemented yet)
        let identity = "-"  # RFC 1413 identity (not used)
        let content_length = _get_response_length(resp)
        return f'{client_ip} {identity} {user} {timestamp} "{method} {full_path} {version}" {status} {content_length}'

    elif format == "combined"
        # Apache Combined Log Format (CLF + referer + user-agent)
        let timestamp = time.now_local().format("[%d/%b/%Y:%H:%M:%S %z]")
        let user = "-"
        let identity = "-"
        let content_length = _get_response_length(resp)
        let referer = req["referer"] or "-"
        let user_agent = req["user_agent"] or "-"
        return f'{client_ip} {identity} {user} {timestamp} "{method} {full_path} {version}" {status} {content_length} "{referer}" "{user_agent}"'

    elif format == "detailed"
        # Quest detailed format with timing
        return f"{client_ip} {method} {full_path} - {status} ({duration}ms)"

    else
        # Default: simple format
        return f"{client_ip} {method} {path} - {status} ({duration}ms)"
    end
end

# Get client IP, respecting X-Forwarded-For header
fun _get_client_ip(req)
    # Check for X-Forwarded-For header first (proxy/load balancer)
    if req["headers"] != nil and req["headers"]["x-forwarded-for"] != nil
        let xff = req["headers"]["x-forwarded-for"]
        # X-Forwarded-For can be comma-separated, take first IP
        let first_ip = xff.split(",")[0].trim()
        return first_ip
    end

    # Fall back to direct client IP
    return req["client_ip"] or "unknown"
end

# Get response content length from headers or body
fun _get_response_length(resp)
    # Try Content-Length header first
    if resp["headers"] != nil and resp["headers"]["Content-Length"] != nil
        return resp["headers"]["Content-Length"]
    end

    # Try to calculate from body
    if resp["body"] != nil
        if resp["body"].is("Str")
            return resp["body"].len().str()
        elif resp["body"].is("Bytes")
            return resp["body"].len().str()
        end
    end

    # Unknown length
    return "-"
end

# Create simple logger with defaults
pub fun simple_logger()
    return create_logger("web.access", format: "detailed", include_headers: false)
end

# Create detailed logger with headers
pub fun detailed_logger()
    return create_logger("web.access", format: "detailed", include_headers: true)
end

# Create Apache-compatible logger
pub fun apache_logger()
    return create_logger("web.access", format: "combined", include_headers: false)
end
```

#### Usage Examples

**Basic logging to stdout:**
```quest
use "std/web" as web
use "std/web/middleware/logging" as logging_mw

let log_mw = logging_mw.simple_logger()
web.use(log_mw.before)
web.after(log_mw.after)

# Output:
# [18/Oct/2025 12:34:56] INFO [web.access] 127.0.0.1 GET /index.html - 200 (5ms)
# [18/Oct/2025 12:34:57] INFO [web.access] 127.0.0.1 GET /static/style.css - 200 (2ms)
```

**Logging to file with Apache format:**
```quest
use "std/web" as web
use "std/web/middleware/logging" as logging_mw
use "std/log"

# Configure web.access logger
let web_logger = log.get_logger("web.access")
web_logger.set_level(log.INFO)

# Apache-style access.log (no colors)
let access_fmt = log.Formatter.new(
    format_string: "{message}",  # Just the message, no timestamp/level
    date_format: "",
    use_colors: false
)
let access_handler = log.FileHandler.new(
    filepath: "logs/access.log",
    mode: "a",
    level: log.INFO,
    formatter_obj: access_fmt
)
web_logger.add_handler(access_handler)

# Also log errors to separate file
let error_handler = log.FileHandler.new(
    filepath: "logs/error.log",
    mode: "a",
    level: log.ERROR  # Only log 4xx/5xx
)
web_logger.add_handler(error_handler)

# Setup middleware
let log_mw = logging_mw.apache_logger()
web.use(log_mw.before)
web.after(log_mw.after)

# logs/access.log:
# 127.0.0.1 - - [18/Oct/2025:12:34:56 +0000] "GET /index.html HTTP/1.1" 200 2326 "-" "Mozilla/5.0"
# 127.0.0.1 - - [18/Oct/2025:12:34:57 +0000] "GET /static/style.css HTTP/1.1" 200 1543 "http://localhost:3000/" "Mozilla/5.0"
#
# logs/error.log:
# [18/Oct/2025 12:35:12] ERROR [web.access] 127.0.0.1 - - [18/Oct/2025:12:35:12 +0000] "GET /missing.html HTTP/1.1" 404 1234
```

**Split static and dynamic logs:**
```quest
use "std/web" as web
use "std/web/middleware/logging" as logging_mw
use "std/log"

# Create two loggers: one for static, one for dynamic
let static_logger = log.get_logger("web.static")
let dynamic_logger = log.get_logger("web.dynamic")

# Configure handlers (e.g., separate files)
static_logger.add_handler(log.FileHandler.new(filepath: "logs/static.log", mode: "a"))
dynamic_logger.add_handler(log.FileHandler.new(filepath: "logs/dynamic.log", mode: "a"))

# Middleware that routes to different loggers
web.use(fun (req)
    req["_start_time"] = time.now()
    return req
end)

web.after(fun (req, resp)
    let start = req["_start_time"]
    if start == nil
        return resp
    end

    let duration = time.now().diff(start).as_milliseconds()
    let path = req["path"]
    let msg = f"{req['client_ip']} {req['method']} {path} - {resp['status']} ({duration}ms)"

    # Route to different logger based on path
    if path.startswith("/static") or path.startswith("/public")
        static_logger.info(msg)
    else
        dynamic_logger.info(msg)
    end

    return resp
end)
```

**Debug mode with headers:**
```quest
use "std/web" as web
use "std/web/middleware/logging" as logging_mw
use "std/log"

# Enable debug logging
let web_logger = log.get_logger("web.access")
web_logger.set_level(log.DEBUG)

# Create detailed logger with headers
let log_mw = logging_mw.detailed_logger()
web.use(log_mw.before)
web.after(log_mw.after)

# Output:
# [18/Oct/2025 12:34:56] INFO [web.access] 127.0.0.1 GET /api/users - 200 (12ms)
# [18/Oct/2025 12:34:56] DEBUG [web.access] Request headers:
# [18/Oct/2025 12:34:56] DEBUG [web.access]   host: localhost:3000
# [18/Oct/2025 12:34:56] DEBUG [web.access]   user-agent: Mozilla/5.0
# [18/Oct/2025 12:34:56] DEBUG [web.access]   accept: application/json
```

#### Integration with Blog Example

Before (manual logging in handler):
```quest
# index.q - OLD
fun handle_request(req)
    # Manual logging - duplicated, misses static files
    let path = req["path"]
    let method = req["method"]
    let client_ip = get_client_ip(req) or "unknown"
    let query = req["query_string"] or ""
    if query != ""
        query = "?" .. query
    end
    logger.info(f"{client_ip} {method} {path}{query}")

    # ... dispatch to routes
end
```

After (middleware-based logging):
```quest
# index.q - NEW
use "std/web" as web
use "std/web/middleware/logging" as logging_mw
use "std/log"

# Configure logging
let logger = log.get_logger("blog")
logger.set_level(log.INFO)

# Setup access logger
let web_logger = log.get_logger("web.access")
let access_handler = log.FileHandler.new(
    filepath: "blog.log",
    mode: "a",
    level: log.INFO
)
web_logger.add_handler(access_handler)

# Add logging middleware
let log_mw = logging_mw.create_logger("web.access", format: "detailed")
web.use(log_mw.before)
web.after(log_mw.after)

# Routes - no manual logging needed!
@Get(path: "/")
fun home_handler(req)
    # Just handle the request
    let posts = post_repo.find_all(db, true, nil, nil)
    # ...
end

# Now ALL requests logged (including /public/style.css)
```

### `std/web/middleware/cors.q`

```quest
pub fun create_cors(**options)
    let origins = options["origins"] or ["*"]
    let methods = options["methods"] or ["GET", "POST", "PUT", "DELETE"]
    let headers = options["headers"] or ["Content-Type", "Authorization"]

    return {
        after: fun (req, resp)
            if resp["headers"] == nil
                resp["headers"] = {}
            end

            # Add CORS headers
            if origins.contains("*")
                resp["headers"]["Access-Control-Allow-Origin"] = "*"
            else
                let origin = req["headers"]["origin"]
                if origin != nil and origins.contains(origin)
                    resp["headers"]["Access-Control-Allow-Origin"] = origin
                end
            end

            resp["headers"]["Access-Control-Allow-Methods"] = methods.join(", ")
            resp["headers"]["Access-Control-Allow-Headers"] = headers.join(", ")

            return resp
        end
    }
end
```

### `std/web/middleware/security.q`

```quest
pub fun security_headers()
    return {
        after: fun (req, resp)
            if resp["headers"] == nil
                resp["headers"] = {}
            end

            resp["headers"]["X-Content-Type-Options"] = "nosniff"
            resp["headers"]["X-Frame-Options"] = "DENY"
            resp["headers"]["X-XSS-Protection"] = "1; mode=block"
            resp["headers"]["Referrer-Policy"] = "strict-origin-when-cross-origin"

            return resp
        end
    }
end
```

### `std/web/middleware/static_cache.q`

```quest
pub fun static_cache(max_age = 3600)
    return {
        after: fun (req, resp)
            # Only cache static assets
            let path = req["path"]
            if path.matches("\\.(?:css|js|png|jpg|jpeg|gif|svg|ico|woff2?)$")
                if resp["headers"] == nil
                    resp["headers"] = {}
                end
                resp["headers"]["Cache-Control"] = "public, max-age=" .. max_age.str()
            end

            return resp
        end
    }
end
```

## Implementation Plan

### Phase 1: Core Middleware System

1. **Update `std/web.q`**:
   - Add `middlewares` and `after_middlewares` arrays to `_runtime_config`
   - Implement `web.use()` and `web.after()` functions
   - Update `_get_config()` to return middleware arrays

2. **Update `server.rs`**:
   - Add `execute_quest_middlewares()` function
   - Add `execute_after_middlewares()` function
   - Add `http_response_to_quest_dict()` helper
   - Modify `handle_request_sync()` to call middlewares

3. **Add configuration extraction** in `load_web_config()`:
   - Extract middleware arrays from Quest scope
   - Store flags in `ServerConfig` (similar to hooks)

### Phase 2: Static File Integration

1. Implement `http_response_to_quest_dict()` converter
2. Modify `try_serve_static_file()` to return Quest dict
3. Run after middlewares on static file responses
4. Test logging works for static files

### Phase 3: Built-in Middleware Library

1. Create `lib/std/web/middleware/logging.q`
2. Create `lib/std/web/middleware/cors.q`
3. Create `lib/std/web/middleware/security.q`
4. Create `lib/std/web/middleware/static_cache.q`
5. Add documentation and examples

### Phase 4: Migration & Deprecation

1. Update blog example to use middleware instead of manual logging
2. Deprecate `web.before_request()` / `web.after_request()`
3. Add migration guide
4. Update documentation

## Use Cases

### 1. Unified Access Logging

**Problem**: Static files not logged, duplicate code in handlers

**Solution**:
```quest
use "std/web/middleware/logging" as logging_mw

let log_mw = logging_mw.create_logger("web.access")
web.use(log_mw.before)
web.after(log_mw.after)

# Now ALL requests (static + dynamic) logged to std/log
```

### 2. Authentication for Admin Routes

**Problem**: Need to protect `/admin` routes including static assets

**Solution**:
```quest
web.use(fun (req)
    if req["path"].startswith("/admin")
        if not is_authenticated(req)
            return {
                status: 401,
                body: "Unauthorized"
            }
        end
    end
    return req
end)
```

### 3. Add Security Headers to All Responses

**Problem**: Need to add headers to both static and dynamic responses

**Solution**:
```quest
use "std/web/middleware/security" as security_mw

let sec = security_mw.security_headers()
web.after(sec.after)

# All responses (static CSS, dynamic HTML) get security headers
```

### 4. Request Timing and Metrics

**Problem**: Want to measure response time for all routes

**Solution**:
```quest
web.use(fun (req)
    req["_start_time"] = time.now()
    return req
end)

web.after(fun (req, resp)
    let duration = time.now().diff(req["_start_time"]).as_milliseconds()

    # Slow request warning
    if duration > 1000
        let logger = log.get_logger("web.performance")
        logger.warning(f"Slow request: {req['path']} took {duration}ms")
    end

    return resp
end)
```

### 5. Cache Control for Static Assets

**Problem**: Static files should have cache headers

**Solution**:
```quest
use "std/web/middleware/static_cache" as cache_mw

let cache = cache_mw.static_cache(max_age: 86400)  # 1 day
web.after(cache.after)

# All .css, .js, .png files get Cache-Control header
```

## Compatibility

### Breaking Changes

**None** - This is purely additive:
- New `web.use()` and `web.after()` functions
- Existing `web.before_request()` / `web.after_request()` continue to work

### Deprecation Path

1. Mark `web.before_request()` and `web.after_request()` as deprecated
2. Add warnings in documentation
3. Provide migration examples
4. Remove in 2-3 releases

**Migration**:
```quest
# Old (QEP-051)
web.before_request(fun (req) ... end)
web.after_request(fun (req, resp) ... end)

# New (QEP-061)
web.use(fun (req) ... return req end)
web.after(fun (req, resp) ... return resp end)
```

**Key difference**: New middlewares run for **all requests** (static + dynamic), old hooks only for dynamic routes.

## Testing Strategy

1. **Unit tests**: Middleware execution order, short-circuiting
2. **Integration tests**:
   - Logging middleware works for static files
   - Auth middleware blocks unauthorized requests
   - After middleware adds headers to all responses
3. **Performance tests**: Ensure middleware overhead is minimal
4. **Error handling tests**: Middleware errors don't crash server

## Open Questions

1. **Naming**: Is `web.use()` and `web.after()` clear? Alternatives:
   - `web.middleware()` / `web.after_middleware()`
   - `web.before()` / `web.after()`
   - Keep `web.use()` / `web.after()`? ✅ (Express-style)

2. **Error middleware**: Should there be a special error handler middleware like Express's `(err, req, resp, next)`?
   - Proposal: Add `web.on_error(fn)` for error recovery middleware

3. **Async middleware**: Future support for async operations?
   - Not needed now (Quest functions are sync)
   - Can add later if needed

4. **Middleware context**: Should middlewares share a context dict?
   - Proposal: Use request dict as context (`req["_context"] = {}`)

5. **Middleware ordering**: Should there be priority/ordering control?
   - Proposal: Start simple - registration order only
   - Can add priorities later if needed

## Success Criteria

- [ ] Middleware runs for all requests (static + dynamic)
- [ ] Logging middleware works with `std/log`
- [ ] Short-circuiting works (auth middleware blocks requests)
- [ ] After middleware can modify responses
- [ ] Blog example uses middleware for logging
- [ ] Documentation includes middleware examples
- [ ] No breaking changes to existing code

## References

- QEP-051: Web Framework API (current hooks)
- QEP-060: Application-Centric Web Server (related refactor)
- Express.js middleware: https://expressjs.com/en/guide/using-middleware.html
- Flask before/after request: https://flask.palletsprojects.com/en/stable/api/#flask.Flask.before_request
- Django middleware: https://docs.djangoproject.com/en/stable/topics/http/middleware/

## Related Work

- **QEP-051**: Added `before_request()` / `after_request()` hooks (only for dynamic routes)
- **QEP-060**: Plans to refactor server architecture (`web.run()`)
- **QEP-061** (this): Middleware system that works for all requests

These QEPs can be implemented independently:
- QEP-061 works with current `quest serve` architecture
- QEP-061 + QEP-060 together provide full control over server lifecycle
