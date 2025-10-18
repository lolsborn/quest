# std/web/middleware/logging.q
# HTTP request/response logging middleware for Quest web server (QEP-061)
#
# Features:
#   - Logs all requests (static files + dynamic routes)
#   - Configurable via std/log (levels, handlers, formatters)
#   - Apache Common Log Format (CLF) compatible
#   - Request timing with millisecond precision
#   - Respects X-Forwarded-For for proxy/load balancer setups

use "std/log" as log
use "std/time" as time

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
#   web.middleware(log_mw.before)
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
                let headers_dict = req["headers"]
                if headers_dict != nil
                    let keys = headers_dict.keys()
                    let i = 0
                    while i < keys.len()
                        let key = keys[i]
                        let value = headers_dict[key]
                        logger.debug(f"  {key}: {value}")
                        i = i + 1
                    end
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
