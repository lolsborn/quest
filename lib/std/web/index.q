# std/web - Web Framework API (QEP-051)
#
# Provides a unified web framework API for configuring Quest's web server.
# Users can configure static files, CORS, middleware, error handlers, and more
# programmatically in their Quest scripts, which are applied when running `quest serve`.

use "std/conf" as conf
use "std/web/router" as router_module

# =============================================================================
# Configuration Schema (QEP-053 compliant)
# =============================================================================

pub type Configuration
    pub host: Str?
    pub port: Int?
    pub max_body_size: Int?
    pub max_header_size: Int?
    pub request_timeout: Int?
    pub keepalive_timeout: Int?

    fun self.from_dict(dict)
        # Use the generated constructor with all fields
        let config = Configuration.new(
            host: dict["host"] or "127.0.0.1",
            port: dict["port"] or 3000,
            max_body_size: dict["max_body_size"] or 10485760,
            max_header_size: dict["max_header_size"] or 8192,
            request_timeout: dict["request_timeout"] or 30,
            keepalive_timeout: dict["keepalive_timeout"] or 60
        )

        return config
    end
end

# Register schema and load configuration (QEP-053)
conf.register_schema("std.web", Configuration)
pub let config = conf.get_config("std.web")

# =============================================================================
# HTTP Status Code Constants
# =============================================================================

# 1xx Informational
pub const HTTP_CONTINUE = 100
pub const HTTP_SWITCHING_PROTOCOLS = 101
pub const HTTP_PROCESSING = 102
pub const HTTP_EARLY_HINTS = 103

# 2xx Success
pub const HTTP_OK = 200
pub const HTTP_CREATED = 201
pub const HTTP_ACCEPTED = 202
pub const HTTP_NON_AUTHORITATIVE_INFORMATION = 203
pub const HTTP_NO_CONTENT = 204
pub const HTTP_RESET_CONTENT = 205
pub const HTTP_PARTIAL_CONTENT = 206
pub const HTTP_MULTI_STATUS = 207
pub const HTTP_ALREADY_REPORTED = 208
pub const HTTP_IM_USED = 226

# 3xx Redirection
pub const HTTP_MULTIPLE_CHOICES = 300
pub const HTTP_MOVED_PERMANENTLY = 301
pub const HTTP_FOUND = 302
pub const HTTP_SEE_OTHER = 303
pub const HTTP_NOT_MODIFIED = 304
pub const HTTP_USE_PROXY = 305
pub const HTTP_TEMPORARY_REDIRECT = 307
pub const HTTP_PERMANENT_REDIRECT = 308

# 4xx Client Errors
pub const HTTP_BAD_REQUEST = 400
pub const HTTP_UNAUTHORIZED = 401
pub const HTTP_PAYMENT_REQUIRED = 402
pub const HTTP_FORBIDDEN = 403
pub const HTTP_NOT_FOUND = 404
pub const HTTP_METHOD_NOT_ALLOWED = 405
pub const HTTP_NOT_ACCEPTABLE = 406
pub const HTTP_PROXY_AUTHENTICATION_REQUIRED = 407
pub const HTTP_REQUEST_TIMEOUT = 408
pub const HTTP_CONFLICT = 409
pub const HTTP_GONE = 410
pub const HTTP_LENGTH_REQUIRED = 411
pub const HTTP_PRECONDITION_FAILED = 412
pub const HTTP_PAYLOAD_TOO_LARGE = 413
pub const HTTP_URI_TOO_LONG = 414
pub const HTTP_UNSUPPORTED_MEDIA_TYPE = 415
pub const HTTP_RANGE_NOT_SATISFIABLE = 416
pub const HTTP_EXPECTATION_FAILED = 417
pub const HTTP_IM_A_TEAPOT = 418
pub const HTTP_MISDIRECTED_REQUEST = 421
pub const HTTP_UNPROCESSABLE_ENTITY = 422
pub const HTTP_LOCKED = 423
pub const HTTP_FAILED_DEPENDENCY = 424
pub const HTTP_TOO_EARLY = 425
pub const HTTP_UPGRADE_REQUIRED = 426
pub const HTTP_PRECONDITION_REQUIRED = 428
pub const HTTP_TOO_MANY_REQUESTS = 429
pub const HTTP_REQUEST_HEADER_FIELDS_TOO_LARGE = 431
pub const HTTP_UNAVAILABLE_FOR_LEGAL_REASONS = 451

# 5xx Server Errors
pub const HTTP_INTERNAL_SERVER_ERROR = 500
pub const HTTP_NOT_IMPLEMENTED = 501
pub const HTTP_BAD_GATEWAY = 502
pub const HTTP_SERVICE_UNAVAILABLE = 503
pub const HTTP_GATEWAY_TIMEOUT = 504
pub const HTTP_HTTP_VERSION_NOT_SUPPORTED = 505
pub const HTTP_VARIANT_ALSO_NEGOTIATES = 506
pub const HTTP_INSUFFICIENT_STORAGE = 507
pub const HTTP_LOOP_DETECTED = 508
pub const HTTP_NOT_EXTENDED = 510
pub const HTTP_NETWORK_AUTHENTICATION_REQUIRED = 511

# =============================================================================
# Runtime Configuration State (for imperative API)
# =============================================================================

let _runtime_config = {
    "static_dirs": [],
    "cors": nil,
    "middlewares": [],        # Request middlewares (web.use) - QEP-061
    "after_middlewares": [],  # Response middlewares (web.after) - QEP-061
    "error_handlers": {},
    "redirects": {},
    "default_headers": {}
}

let _registered_routers = []  # Registered router instances (QEP-062)

# =============================================================================
# Public API - Static File Serving
# =============================================================================

## Add static file directory
##
## Serves files from fs_path at url_path mount point.
##
## Examples:
##   web.static("/assets", "./public")
##   web.static("/css", "./static/css")
##   web.static("/", "./public")  # Serve SPA from root
##
## Route Precedence:
##   Longest (most specific) URL path wins when routes overlap:
##
##   web.static("/assets", "./public")
##   web.static("/assets/premium", "./special")
##
##   GET /assets/premium/video.mp4
##   → Serves from ./special/video.mp4 (longer path takes precedence)
##
##   GET /assets/common/style.css
##   → Serves from ./public/common/style.css (only matching route)
##
## Duplicate Routes:
##   If same url_path is registered twice, the last call wins:
##
##   web.static("/public", "./dir1")
##   web.static("/public", "./dir2")  # Replaces previous
##
## Behavior:
##   - Path traversal (..) is blocked automatically by server
##   - Returns 404 if file not found (falls through to handle_request)
##   - Automatic MIME type detection
##   - Last-Modified headers for browser caching
pub fun static(url_path: Str, fs_path: Str)
    # Validate url_path starts with /
    if not url_path.startswith("/")
        raise ValueErr.new("url_path must start with /: " .. url_path)
    end

    # If same url_path exists, replace it (last wins)
    let i = 0
    let found = false
    while i < _runtime_config["static_dirs"].len()
        let entry = _runtime_config["static_dirs"][i]
        if entry[0] == url_path
            _runtime_config["static_dirs"][i] = [url_path, fs_path]
            found = true
            i = _runtime_config["static_dirs"].len()  # Break out of loop
        end
        i = i + 1
    end

    if not found
        _runtime_config["static_dirs"].push([url_path, fs_path])
    end
end


# =============================================================================
# Public API - CORS Configuration
# =============================================================================

# Configure CORS (Cross-Origin Resource Sharing)
pub fun set_cors(**kwargs)
    let origins = kwargs["origins"] or ["*"]
    let methods = kwargs["methods"] or ["GET", "POST", "PUT", "DELETE"]
    let headers = kwargs["headers"] or ["Content-Type", "Authorization"]
    let credentials = kwargs["credentials"] or false

    _runtime_config["cors"] = {
        "origins": origins,
        "methods": methods,
        "headers": headers,
        "credentials": credentials
    }
end

# Disable CORS
pub fun disable_cors()
    _runtime_config["cors"] = nil
end

# =============================================================================
# Public API - Request Limits
# =============================================================================

# Set maximum request body size (bytes)
pub fun set_max_body_size(size: Int)
    config.max_body_size = size
end

# Set maximum header size (bytes)
pub fun set_max_header_size(size: Int)
    config.max_header_size = size
end

# =============================================================================
# Public API - Timeout Configuration
# =============================================================================

# Set request timeout (seconds)
pub fun set_request_timeout(seconds: Int)
    config.request_timeout = seconds
end

# Set keep-alive timeout (seconds)
pub fun set_keepalive_timeout(seconds: Int)
    config.keepalive_timeout = seconds
end

# =============================================================================
# Public API - Middleware/Hooks
# =============================================================================

# Before request hook (DEPRECATED - use web.middleware() instead)
# Kept for backwards compatibility, now adds to middleware
pub fun before_request(handler)
    _runtime_config["middlewares"].push(handler)
end

# After request hook (DEPRECATED - use web.after() instead)
# Kept for backwards compatibility, now adds to after_middlewares
pub fun after_request(handler)
    _runtime_config["after_middlewares"].push(handler)
end

# =============================================================================
# Public API - Middleware System (QEP-061)
# =============================================================================

## Quest request middleware (runs for all requests - static + dynamic)
##
## Request middleware receives request dict, returns:
## - Modified request (to continue chain)
## - Response dict with 'status' field (to short-circuit and skip handler)
##
## Signature: fun (req: Dict) -> Dict
##
## Examples:
##   # Add request timing
##   web.middleware(fun (req)
##       req["_start_time"] = time.now()
##       return req
##   end)
##
##   # Authentication (short-circuit)
##   web.middleware(fun (req)
##       if req["path"].startswith("/admin") and not is_authenticated(req)
##           return {status: 401, body: "Unauthorized"}
##       end
##       return req
##   end)
pub fun middleware(middleware_fn)
    _runtime_config["middlewares"].push(middleware_fn)
end

## Response middleware (runs after response is generated)
##
## Receives request and response dicts, returns modified response.
##
## Signature: fun (req: Dict, resp: Dict) -> Dict
##
## Examples:
##   # Add security headers
##   web.after(fun (req, resp)
##       if resp["headers"] == nil
##           resp["headers"] = {}
##       end
##       resp["headers"]["X-Content-Type-Options"] = "nosniff"
##       return resp
##   end)
##
##   # Access logging
##   web.after(fun (req, resp)
##       let duration = time.now().diff(req["_start_time"]).as_milliseconds()
##       puts(f"{req['method']} {req['path']} - {resp['status']} ({duration}ms)")
##       return resp
##   end)
pub fun after(middleware_fn)
    _runtime_config["after_middlewares"].push(middleware_fn)
end

## Register a Router instance at a base path (QEP-062)
##
## Registers a router for a specific URL path prefix. The router's routes
## will be matched relative to the base path.
##
## Signature:
##   web.route(base_path: Str, router: Router) -> Nil
##
## Examples:
##   # Register API router at /api
##   let api_router = Router.new()
##   api_router.get("/users", users_handler)
##   web.route("/api", api_router)
##   # GET /api/users → routes to users_handler
##
##   # Multiple routers
##   let user_router = Router.new()
##   user_router.get("/", list_users)
##   web.route("/users", user_router)
##
##   let product_router = Router.new()
##   product_router.get("/", list_products)
##   web.route("/products", product_router)
pub fun route(base_path: Str, router_instance)
    # Validate base_path starts with /
    if not base_path.startswith("/")
        raise ValueErr.new("base_path must start with /: " .. base_path)
    end

    # Store the router in a global registry instead of capturing it in closure
    # This avoids issues with calling methods on captured struct instances
    let router_index = _registered_routers.len()
    _registered_routers.push({
        base_path: base_path,
        router: router_instance
    })

    # Create middleware that strips base path and dispatches to router
    # NOTE: We capture router_index as an integer to avoid closure type issues
    let middleware_fn = fun (req)
        let path = req["path"]

        # Check if path starts with base_path
        if path.startswith(base_path)
            # Strip base path and dispatch to router
            let original_path = path

            # Special handling for root path "/" - don't strip it
            if base_path == "/"
                # When base_path is "/", use the full path as-is
                req["path"] = path
            else
                # Strip the base_path prefix using slice (not replace, which replaces all occurrences)
                let stripped = path.slice(base_path.len(), path.len())

                # Ensure path starts with /
                if stripped == ""
                    req["path"] = "/"
                elif not stripped.startswith("/")
                    req["path"] = "/" .. stripped
                else
                    req["path"] = stripped
                end
            end

            # Get the router from the registry using the captured index
            let found_router = nil
            if router_index < _registered_routers.len()
                found_router = _registered_routers[router_index]["router"]
            end

            # Try to dispatch to registered router
            let response = nil
            if found_router != nil
                try
                    # Use module-level dispatch_router function to avoid type lookup issues in thread-local scope
                    response = router_module.dispatch_router(found_router, req)
                catch e
                    # If dispatch fails, continue to next middleware
                    req["path"] = original_path
                    return req
                end
            end

            if response != nil
                # Route matched - restore original path and return response
                req["path"] = original_path
                return response
            end

            # No match - restore original path and continue chain
            req["path"] = original_path
        end

        return req  # No match, continue chain
    end

    # Register as middleware
    middleware(middleware_fn)
end

## Get list of registered routers (QEP-062)
##
## Returns array of {base_path, router} objects for introspection and debugging.
pub fun get_registered_routers()
    return _registered_routers
end

# =============================================================================
# Public API - Error Handlers
# =============================================================================

# Register error handler for specific status code
# Handler signature:
#   - For 4xx: fun (request: Dict) -> Dict
#   - For 5xx: fun (request: Dict, error: Str) -> Dict
pub fun on_error(status: Int, handler)
    _runtime_config["error_handlers"][status.str()] = handler
end

# =============================================================================
# Public API - Redirects
# =============================================================================

# Add permanent or temporary redirect
pub fun redirect(from: Str, target: Str, status: Int = 302)
    _runtime_config["redirects"][from] = [target, status]
end

# =============================================================================
# Public API - Default Response Headers
# =============================================================================

# Set default headers for all responses
pub fun set_default_headers(headers)
    _runtime_config["default_headers"] = headers
end

# =============================================================================
# Internal API - For Rust to retrieve configuration
# =============================================================================

# Get runtime configuration (called by Rust after script execution)
pub fun _get_config()
    return _runtime_config
end

# Get base configuration (from quest.toml)
pub fun _get_base_config()
    return config
end

# =============================================================================
# QEP-060: Application-Centric Web Server
# =============================================================================

## Start the web server (blocking)
##
## QEP-060: Application-Centric Web Server Architecture
## This is the main entry point for starting a Quest web server.
##
## Signature:
##   web.run(host: Str?, port: Int?) -> Nil
##
## Behavior:
##   - Reads all configuration from web module state (static dirs, CORS, etc.)
##   - Blocks indefinitely until server receives shutdown signal (Ctrl+C or SIGTERM)
##   - Performs graceful shutdown (finishes in-flight requests)
##   - Script execution resumes (returns Nil) after server stops
##
## Examples:
##   web.run()                     # Use defaults (127.0.0.1:3000)
##   web.run("0.0.0.0", 8080)      # Override host and port
##
## Notes:
##   - This is a native function implemented in Rust (QEP-060)
##   - Phase 2 Status: Configuration extraction working, startup message displayed
##   - Phase 3+: Full HTTP server integration with Axum and tokio
##   - Only one server can run per script
##   - Configuration precedence: quest.toml < command-line args to web.run()
##
## Implementation Status (QEP-060):
##   Phase 1: ✓ Native function framework, module integration
##   Phase 2: ✓ Config extraction, startup message display
##   Phase 3: ⏳ HTTP server startup with Axum
##   Phase 4: ⏳ Static files, dynamic routes, middleware
##   Phase 5: ⏳ Migration guide, blog example update
# NOTE: web.run() is implemented as a native Rust function in src/modules/web.rs
# Do NOT define a Quest version here - it would shadow the native implementation
