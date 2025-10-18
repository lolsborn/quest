# Quest Web Routing - Quick Start Guide

Fast reference for using Quest's router and middleware systems (QEP-061, QEP-062).

## Basic Setup

```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define a handler function
fun handle_request(req)
  let response = router.dispatch_middleware(req)
  if response["status"] == nil
    return {status: 404, body: "Not Found"}
  end
  return response
end

# Start the server
web.run()
```

## Defining Routes

### Static Routes
```quest
router.get("/", fun (req)
  {status: 200, body: "Home"}
end)

router.post("/submit", fun (req)
  {status: 200, body: "Submitted"}
end)

router.put("/update", fun (req)
  {status: 200, body: "Updated"}
end)

router.delete("/remove", fun (req)
  {status: 200, body: "Deleted"}
end)

router.patch("/modify", fun (req)
  {status: 200, body: "Modified"}
end)
```

### Dynamic Routes

#### String Parameter (default)
```quest
router.get("/posts/{slug}", fun (req)
  let slug = req["params"]["slug"]
  {status: 200, body: f"Post: {slug}"}
end)

# Matches: /posts/hello, /posts/my-post
# Does NOT match: /posts/hello/world
```

#### Integer Parameter
```quest
router.get("/users/{id<int>}", fun (req)
  let user_id = req["params"]["id"]
  {status: 200, body: f"User: {user_id}"}
end)

# Matches: /users/42, /users/123
# Does NOT match: /users/invalid, /users/42.5
```

#### Greedy Path Parameter
```quest
router.get("/files/{path<path>}", fun (req)
  let file = req["params"]["path"]
  {status: 200, body: f"File: {file}"}
end)

# Matches: /files/readme.md, /files/docs/guide.md, /files/a/b/c.txt
# Captures everything after /files/
```

#### Other Types
```quest
router.get("/api/{value<float>}", fun (req)
  let value = req["params"]["value"]  # 3.14
end)

router.get("/resource/{id<uuid>}", fun (req)
  let id = req["params"]["id"]  # UUID
end)
```

## Request Object

```quest
# All requests include these fields:
let req = {
  "method": "GET",          # HTTP method
  "path": "/posts/hello",   # URL path
  "query": {},              # Parsed query params
  "headers": {},            # HTTP headers
  "body": "",               # Request body
  "query_string": "a=1",    # Raw query string
  "client_ip": "127.0.0.1", # Client IP
  "version": "HTTP/1.1",    # HTTP version
  "params": {}              # Route parameters (set by router)
}
```

## Response Object

```quest
# Return response dicts with these fields:
let response = {
  "status": 200,                     # HTTP status (required)
  "body": "Hello",                   # Text body
  # OR
  "json": {key: "value"},            # Auto-serialized JSON
  # PLUS
  "headers": {                       # Optional headers
    "Content-Type": "text/plain"
  }
}
```

## Middleware

### Request Middleware (runs BEFORE handler)
```quest
web.middleware(fun (req)
  # Modify request or return response to short-circuit
  req["_user_id"] = extract_user_id(req)
  return req  # Continue to next middleware/handler
end)

web.middleware(fun (req)
  # Can return response to short-circuit pipeline
  if not is_authorized(req)
    return {status: 401, body: "Unauthorized"}
  end
  return req
end)
```

### Response Middleware (runs AFTER handler)
```quest
web.after(fun (req, resp)
  # Modify response before sending
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["X-Processed"] = "true"
  return resp
end)
```

## Configuration

### Static Files
```quest
web.add_static("/public", "./public")
web.add_static("/assets", "./assets")
```

### CORS
```quest
web.set_cors(
  origins: ["http://localhost:3000", "https://example.com"],
  methods: ["GET", "POST", "PUT"],
  headers: ["Content-Type", "Authorization"]
)
```

### Redirects
```quest
web.redirect("/old-path", "/new-path", 301)
```

### Error Handlers
```quest
web.on_error(404, fun (req)
  {status: 404, body: "Not Found"}
end)

web.on_error(500, fun (req, error)
  {status: 500, body: "Server Error: " .. error}
end)
```

### Default Headers
```quest
web.set_default_headers({
  "X-Custom": "value",
  "Cache-Control": "no-cache"
})
```

## Common Patterns

### JSON API
```quest
router.get("/api/data", fun (req)
  {
    status: 200,
    json: {data: [1, 2, 3]},
    headers: {Content-Type: "application/json"}
  }
end)
```

### Redirect
```quest
router.get("/old", fun (req)
  {
    status: 301,
    headers: {Location: "/new"}
  }
end)
```

### Authentication Guard (Middleware)
```quest
web.middleware(fun (req)
  if req["path"].startswith("/admin")
    if not req["headers"]["authorization"]
      return {status: 401, body: "Unauthorized"}
    end
  end
  return req
end)
```

### Request Timing
```quest
web.middleware(fun (req)
  req["_start"] = time.now()
  return req
end)

web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  let ms = time.now().diff(req["_start"]).as_milliseconds()
  resp["headers"]["X-Response-Time"] = ms.str() .. "ms"
  return resp
end)
```

### Conditional Routing
```quest
router.get("/resource/{id<int>}", fun (req)
  let id = req["params"]["id"]

  if id > 1000
    {status: 404, body: "Not found"}
  else
    {status: 200, json: {id: id}}
  end
end)
```

## Running Examples

```bash
# Basic routing example
./target/release/quest examples/web/routing_app.q

# Advanced middleware patterns
./target/release/quest examples/web/routing_middleware_advanced.q

# Original simple app
./target/release/quest examples/web/simple_app.q
```

## Request/Response Flow

```
1. HTTP request arrives at server
   ↓
2. Request middleware runs (in order)
   - Can modify request
   - Can short-circuit with response
   ↓
3. Route matching
   - Router checks all registered routes
   - First matching route's handler runs
   ↓
4. Handler execution
   - Returns response dict
   ↓
5. Response middleware runs (in order)
   - Can modify response
   ↓
6. Response sent to client
```

## Status Codes

```quest
use "std/web" as web

web.HTTP_OK                    # 200
web.HTTP_CREATED              # 201
web.HTTP_BAD_REQUEST          # 400
web.HTTP_UNAUTHORIZED         # 401
web.HTTP_FORBIDDEN            # 403
web.HTTP_NOT_FOUND            # 404
web.HTTP_INTERNAL_SERVER_ERROR # 500
```

## Debugging

```quest
# Log all registered routes
let routes = router.get_routes()
puts(routes)

# Clear all routes (for testing)
router.clear_routes()

# Log requests in middleware
web.middleware(fun (req)
  puts(f"{req['method']} {req['path']}")
  return req
end)
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Route not matching | Check parameter types (e.g., `{id<int>}` won't match "abc") |
| Handler not called | Router may not be finding a match, check exact path |
| Middleware runs twice | Multiple `web.middleware()` calls will register separately |
| 404 for all requests | Make sure `handle_request()` function is defined |
| Headers not appearing | Initialize `resp["headers"]` dict before adding headers |

## Next Resources

- [ROUTING_EXAMPLE.md](./ROUTING_EXAMPLE.md) - Detailed routing guide
- [MIDDLEWARE_ADVANCED.md](./MIDDLEWARE_ADVANCED.md) - Middleware patterns
- [QEP-061](../specs/qep-061-request-response-middleware.md) - Middleware spec
- [QEP-062](../lib/std/web/middleware/router.q) - Router implementation
