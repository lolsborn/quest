# std/web - Web Framework API (QEP-051)
#
# Provides a unified web framework API for configuring Quest's web server.
# Users can configure static files, CORS, middleware, error handlers, and more
# programmatically in their Quest scripts, which are applied when running `quest serve`.

use "std/conf" as conf

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

    static fun from_dict(dict)
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
    "before_hooks": [],
    "after_hooks": [],
    "error_handlers": {},
    "redirects": {},
    "default_headers": {}
}

# =============================================================================
# Public API - Static File Serving
# =============================================================================

## Add static file directory
##
## Serves files from fs_path at url_path mount point.
##
## Examples:
##   web.add_static("/assets", "./public")
##   web.add_static("/css", "./static/css")
##   web.add_static("/", "./public")  # Serve SPA from root
##
## Route Precedence:
##   Longest (most specific) URL path wins when routes overlap:
##
##   web.add_static("/assets", "./public")
##   web.add_static("/assets/premium", "./special")
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
##   web.add_static("/public", "./dir1")
##   web.add_static("/public", "./dir2")  # Replaces previous
##
## Behavior:
##   - Path traversal (..) is blocked automatically by server
##   - Returns 404 if file not found (falls through to handle_request)
##   - Automatic MIME type detection
##   - Last-Modified headers for browser caching
pub fun add_static(url_path: Str, fs_path: Str)
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

# Before request hook (runs before handle_request)
# Handler signature: fun (request: Dict) -> Dict | Dict
# Return request to continue, or response Dict to short-circuit
pub fun before_request(handler)
    _runtime_config["before_hooks"].push(handler)
end

# After request hook (runs after handle_request)
# Handler signature: fun (request: Dict, response: Dict) -> Dict
# Return modified response
pub fun after_request(handler)
    _runtime_config["after_hooks"].push(handler)
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
% fun run(**kwargs)
    "Start the HTTP server (blocking). QEP-060 Phase 2: Config extraction complete."
