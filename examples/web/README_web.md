# Quest Web Server Examples

## Hello Quest Web (`hello_quest_web.q`)

A comprehensive example demonstrating Quest's built-in web server capabilities.

### Running the Example

```bash
# Start the server (default port 8080)
quest serve examples/hello_quest_web.q

# Or specify a custom port
quest serve examples/hello_quest_web.q --port 3000

# Or specify host and port
quest serve examples/hello_quest_web.q --host 0.0.0.0 --port 8765
```

### Testing the Endpoints

Once the server is running, you can test it with curl or a web browser:

```bash
# Home page with links to all endpoints
curl http://localhost:8080/

# Hello with query parameter
curl http://localhost:8080/hello?name=Quest

# JSON response
curl http://localhost:8080/json

# Echo request details
curl http://localhost:8080/echo

# View request headers
curl http://localhost:8080/headers

# Cookie demo (with cookies)
curl -c cookies.txt -b cookies.txt http://localhost:8080/cookies

# Test 404 handling
curl http://localhost:8080/nonexistent
```

### Features Demonstrated

1. **Routing**: Path-based routing using if/elif/else
2. **Query Parameters**: Reading query params from `req["query"]`
3. **Request Headers**: Accessing headers via `req["headers"]`
4. **Cookies**: Reading from `req["cookies"]` and setting via response
5. **JSON Responses**: Using the `json` shorthand in responses
6. **Custom Headers**: Setting response headers
7. **Status Codes**: Returning custom HTTP status codes
8. **HTML Responses**: Serving HTML content
9. **Request Details**: Accessing method, path, body, version, remote_addr

### Request Dict Structure

The `handle_request(req)` function receives a Dict with:

```quest
{
    method: "GET",           # HTTP method
    path: "/hello",          # URL path
    query: {...},            # Query parameters as Dict
    headers: {...},          # HTTP headers as Dict (lowercase keys)
    cookies: {...},          # Cookies as Dict
    body: "...",             # Request body as string
    version: "HTTP/1.1",     # HTTP version
    remote_addr: "..."       # Client IP address
}
```

### Response Dict Structure

Return a Dict from `handle_request` with:

```quest
{
    status: 200,                    # HTTP status code (default: 200)
    headers: {                      # Optional custom headers
        "Content-Type": "text/html"
    },
    body: "Hello World",            # Response body (string)

    # OR use json shorthand (auto-sets Content-Type):
    json: {message: "Hello"},       # Automatically serialized

    # Optional cookies:
    cookies: {
        session_id: {
            value: "abc123",        # Cookie value
            max_age: 3600,          # Expiry in seconds
            path: "/",              # Cookie path
            http_only: true,        # HttpOnly flag
            secure: false,          # Secure flag
            same_site: "Lax"        # SameSite attribute
        }
    }
}
```

### Architecture

- **Thread-local Scopes**: Each worker thread gets its own Quest Scope
- **Module Code**: Top-level code runs once per thread (imports, setup, function definitions)
- **Request Handler**: `handle_request()` is called for every HTTP request
- **Blocking Execution**: Quest code runs in `spawn_blocking` thread pool (no async/await in Quest)
- **Multi-threaded**: Axum handles concurrency automatically

### Performance

The server is production-ready and handles concurrent requests efficiently:
- Module-level code executes once per worker thread
- `handle_request()` executes per request
- Thread-local Scopes avoid synchronization overhead
- Rust's async runtime provides excellent scalability

### Next Steps

For more advanced web server usage, see:
- Database integration examples (postgres, sqlite, mysql)
- Template rendering with `std/html/templates`
- HTTP client requests with `std/http/client`
- Session management and authentication patterns
