# Hello Quest Web Server Example
#
# This example demonstrates the basic usage of Quest's built-in web server.
# Run with: quest serve examples/hello_quest_web.q
#
# Features demonstrated:
# - Basic routing based on request path
# - Reading request method, path, query params, headers
# - Returning JSON responses
# - Setting custom status codes and headers
# - Setting cookies

use "std/encoding/json"
use "std/time"
use "std/log"

# Note: Don't configure logging at module level in web server context
# to avoid issues with threaded initialization

# Main request handler - called for every HTTP request
# The request is passed as a Dict with the following keys:
#   - method: HTTP method (GET, POST, etc.)
#   - path: URL path
#   - query: Dict of query parameters
#   - headers: Dict of HTTP headers
#   - cookies: Dict of cookies
#   - body: Request body as string
#   - version: HTTP version
#   - remote_addr: Client address
fun handle_request(req)
    # NOTE: Logging is currently disabled in web server context due to interpreter bug
    # log.error("Received request: ")
    # Route based on path
    let path = req["path"]

    if path == "/"
        return home_handler(req)
    elif path == "/hello"
        return hello_handler(req)
    elif path == "/json"
        return json_handler(req)
    elif path == "/echo"
        return echo_handler(req)
    elif path == "/headers"
        return headers_handler(req)
    elif path == "/cookies"
        return cookies_handler(req)
    else
        return not_found_handler(req)
    end
end

# Home page handler
fun home_handler(req)
    let html = """<!DOCTYPE html>
<html>
<head><title>Quest Web Server</title></head>
<body>
    <h1>Welcome to Quest Web Server!</h1>
    <p>Try these endpoints:</p>
    <ul>
        <li><a href='/hello?name=World'>/hello?name=World</a> - Greet with query params</li>
        <li><a href='/json'>/json</a> - Return JSON data</li>
        <li><a href='/echo'>/echo</a> - Echo back request details</li>
        <li><a href='/headers'>/headers</a> - Show request headers</li>
        <li><a href='/cookies'>/cookies</a> - Set and read cookies</li>
    </ul>
</body>
</html>"""

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: html
    }
end

# Hello handler with query parameter
fun hello_handler(req)
    let name = "Stranger"

    # Get name from query parameters
    if req["query"].contains("name")
        name = req["query"]["name"]
    end

    return {
        status: 200,
        body: "Hello, " .. name .. "!"
    }
end

# JSON response handler
fun json_handler(req)
    let data = {
        message: "Hello from Quest!",
        version: "1.0",
        timestamp: 1234567890,
        features: ["routing", "json", "cookies", "headers"],
        nested: {
            example: true,
            count: 42
        }
    }

    # Use json shorthand - automatically serializes and sets Content-Type
    return {
        status: 200,
        json: data
    }
end

# Echo handler - returns request details
fun echo_handler(req)
    let echo_data = {
        method: req["method"],
        path: req["path"],
        query: req["query"],
        headers: req["headers"],
        cookies: req["cookies"],
        body: req["body"],
        version: req["version"],
        remote_addr: req["remote_addr"]
    }

    return {
        status: 200,
        json: echo_data
    }
end

# Headers handler - demonstrates custom headers
fun headers_handler(req)
    let headers_html = """<!DOCTYPE html>
<html>
<head><title>Request Headers</title></head>
<body>
    <h1>Your Request Headers</h1>
    <pre>""" .. json.stringify(req["headers"], indent: 2) .. """</pre>
</body>
</html>"""

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8",
            "X-Custom-Header": "Quest-Powered",
            "X-Request-Id": "12345"
        },
        body: headers_html
    }
end

# Cookies handler - demonstrates setting and reading cookies
fun cookies_handler(req)
    let visit_count = 1

    # Check if visit_count cookie exists
    if req["cookies"].contains("visit_count")
        visit_count = req["cookies"]["visit_count"].int() + 1
    end

    let html = """<!DOCTYPE html>
<html>
<head><title>Cookie Demo</title></head>
<body>
    <h1>Cookie Demo</h1>
    <p>This is visit #""" .. visit_count.str() .. """</p>
    <p>Refresh the page to increment the counter!</p>
    <p>Your cookies: <pre>""" .. json.stringify(req["cookies"], indent: 2) .. """</pre></p>
</body>
</html>"""

    return {
        status: 200,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        cookies: {
            visit_count: {
                value: visit_count.str(),
                max_age: 3600,
                path: "/",
                http_only: false,
                secure: false
            },
            session_id: {
                value: "quest-session-" .. visit_count.str(),
                max_age: 86400,
                path: "/"
            }
        },
        body: html
    }
end

# 404 handler
fun not_found_handler(req)
    return {
        status: 404,
        headers: {
            "Content-Type": "text/html; charset=utf-8"
        },
        body: """<!DOCTYPE html>
<html>
<head><title>404 Not Found</title></head>
<body>
    <h1>404 - Page Not Found</h1>
    <p>The path '""" .. req["path"] .. """' was not found.</p>
    <p><a href='/'>Go home</a></p>
</body>
</html>"""
    }
end

puts("Quest web server initialized!")
puts("Routes configured: /, /hello, /json, /echo, /headers, /cookies")
