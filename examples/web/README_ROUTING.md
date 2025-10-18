# Quest Web Routing Examples

This directory contains examples demonstrating Quest's modern web framework with flexible routing (QEP-062) and middleware support (QEP-061).

## Quick Navigation

### 📚 Documentation
- **[ROUTING_QUICK_START.md](./ROUTING_QUICK_START.md)** - Fast reference and cheat sheet
- **[ROUTING_EXAMPLE.md](./ROUTING_EXAMPLE.md)** - Comprehensive routing guide with live examples
- **[MIDDLEWARE_ADVANCED.md](./MIDDLEWARE_ADVANCED.md)** - Advanced middleware patterns and short-circuiting

### 💻 Example Applications

#### 1. `routing_app.q` - Basic Web App with Routing
A complete web application showcasing flexible path parameters.

**Features:**
- Static routes: `/`, `/hello`, `/posts`, `/status`
- String parameters: `/posts/{slug}`
- Integer parameters: `/users/{id<int>}`
- Greedy path capture: `/files/{path<path>}`
- Request/response middleware
- CORS configuration
- Mock REST API endpoints
- JSON responses

**Run:**
```bash
./target/release/quest examples/web/routing_app.q
```

**Test:**
```bash
# List routes
curl http://localhost:3000/

# Get specific post
curl http://localhost:3000/posts/first-post

# Get user by ID (only accepts integers)
curl http://localhost:3000/users/42
curl http://localhost:3000/users/invalid  # Returns 404

# Get file with multi-segment path
curl http://localhost:3000/files/docs/guide.md
```

#### 2. `routing_middleware_advanced.q` - Authentication & Middleware
Advanced example showing authentication, middleware short-circuiting, and request transformation.

**Features:**
- Request logging middleware
- Authentication middleware with Bearer token validation
- Middleware short-circuiting (returns 401 without continuing)
- Request transformation (adding timing, user info, request ID)
- Response middleware (adding security headers, performance metrics)
- Protected routes that require valid tokens
- Public routes available to all

**Run:**
```bash
./target/release/quest examples/web/routing_middleware_advanced.q
```

**Test:**
```bash
# Public routes (work without auth)
curl http://localhost:3000/
curl http://localhost:3000/public/info
curl http://localhost:3000/health

# Protected routes (require valid token)
curl http://localhost:3000/admin/dashboard
# -> Returns 401 Unauthorized

# With valid token
curl -H "Authorization: Bearer valid-mytoken" \
  http://localhost:3000/admin/dashboard
# -> Returns 200 OK

# Invalid token
curl -H "Authorization: Bearer invalid-token" \
  http://localhost:3000/admin/dashboard
# -> Returns 401 Unauthorized
```

#### 3. `simple_app.q` - Original Simple Example
Basic static routing without parameters (for comparison).

## Core Concepts

### Flexible Path Parameters (QEP-062)

Quest supports powerful path parameter patterns:

```quest
router.get("/posts/{slug}", handler)        # String (default)
router.get("/users/{id<int>}", handler)     # Integer
router.get("/api/{value<float>}", handler)  # Float
router.get("/files/{id<uuid>}", handler)    # UUID
router.get("/logs/{path<path>}", handler)   # Greedy (multi-segment)
```

**Key Features:**
- Automatic type validation during route matching
- URL decoding of parameters
- Non-matching types result in route not matching (not errors)
- Greedy path parameters capture remaining path segments

### Request/Response Middleware (QEP-061)

Middleware runs for ALL requests (static files + dynamic routes):

```quest
# Request middleware (before handler)
web.middleware(fun (req)
  req["_start_time"] = time.now()
  return req
end)

# Response middleware (after handler)
web.after(fun (req, resp)
  let time = time.now().diff(req["_start_time"])
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["X-Response-Time"] = time.as_milliseconds().str() .. "ms"
  return resp
end)
```

**Key Features:**
- Request middleware can short-circuit with response
- Response middleware post-processes all responses
- Middleware runs in registration order
- Access to request/response information

## Common Routes

### Blog/CMS Pattern
```quest
router.get("/blog", list_posts)
router.get("/blog/{slug}", get_post)
router.post("/blog", create_post)
router.put("/blog/{slug}", update_post)
router.delete("/blog/{slug}", delete_post)
```

### REST API Pattern
```quest
router.get("/api/users", list_users)
router.get("/api/users/{id<int>}", get_user)
router.post("/api/users", create_user)
router.put("/api/users/{id<int>}", update_user)
router.delete("/api/users/{id<int>}", delete_user)
```

### File Server Pattern
```quest
router.get("/files/{path<path>}", serve_file)
router.post("/files/{path<path>}", upload_file)
router.delete("/files/{path<path>}", delete_file)
```

## Middleware Patterns

### Authentication
```quest
web.middleware(fun (req)
  if protected_route(req["path"])
    let token = extract_token(req)
    if not valid_token(token)
      return {status: 401, body: "Unauthorized"}
    end
  end
  return req
end)
```

### Request Logging
```quest
web.middleware(fun (req)
  puts(f"{req['method']} {req['path']} from {req['client_ip']}")
  return req
end)
```

### Response Timing
```quest
web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  let time = time.now().diff(req["_start_time"]).as_milliseconds()
  resp["headers"]["X-Response-Time"] = time.str() .. "ms"
  return resp
end)
```

## Request and Response Objects

### Request Dict
```quest
{
  "method": "GET",
  "path": "/posts/hello",
  "query": {page: "1"},
  "headers": {host: "localhost:3000"},
  "body": "",
  "client_ip": "127.0.0.1",
  "version": "HTTP/1.1",
  "params": {slug: "hello"}  # Set by router
}
```

### Response Dict
```quest
{
  "status": 200,
  "body": "Hello",                    # OR
  # "json": {key: "value"},           # Auto-serialized
  "headers": {"Content-Type": "text/plain"}
}
```

## Comparison with Other Web Frameworks

### Quest Routing
- ✅ Dynamic parameter patterns with type validation
- ✅ Greedy path capture for flexible routes
- ✅ URL decoding built-in
- ✅ Middleware short-circuiting
- ✅ Runs on all requests (static + dynamic)
- ✅ Clean Quest syntax (no special decorators)

### Before (Manual String Matching)
```quest
fun handle_request(req)
  let path = req["path"]
  if path == "/posts/hello"
    # Hard-coded route
  elif path.startswith("/posts/")
    # Manual parameter extraction
    let slug = path.slice(7, path.len())
  end
end
```

### After (Flexible Router)
```quest
router.get("/posts/{slug}", fun (req)
  let slug = req["params"]["slug"]
end)
```

## Performance Tips

1. **Order middleware by cost**: Put cheap middleware (logging) before expensive middleware (auth)
2. **Short-circuit early**: If a middleware rejects, it stops immediately
3. **Cache computed values**: Store in request context instead of recomputing in handlers
4. **Use typed parameters**: Type validation happens during routing, not in handlers

## Testing Routes

Use `curl` to test different endpoints:

```bash
# Basic GET
curl http://localhost:3000/

# With query parameters
curl "http://localhost:3000/posts?page=1&limit=10"

# With headers
curl -H "Authorization: Bearer token" \
  http://localhost:3000/admin

# POST with JSON
curl -X POST http://localhost:3000/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"New Post"}'

# Verbose output (see headers)
curl -i http://localhost:3000/
```

## Next Steps

1. Start with [ROUTING_QUICK_START.md](./ROUTING_QUICK_START.md) for quick reference
2. Run [routing_app.q](./routing_app.q) to see routing in action
3. Check [ROUTING_EXAMPLE.md](./ROUTING_EXAMPLE.md) for detailed patterns
4. Explore [routing_middleware_advanced.q](./routing_middleware_advanced.q) for middleware
5. Read [MIDDLEWARE_ADVANCED.md](./MIDDLEWARE_ADVANCED.md) for advanced patterns

## Troubleshooting

**Route not matching?**
- Check parameter types (e.g., `/users/invalid` won't match `/users/{id<int>}`)
- Verify exact path spelling
- Use `curl -i` to see actual response

**Handler not called?**
- Ensure `handle_request()` function calls `router.dispatch_middleware()`
- Check middleware isn't short-circuiting unexpectedly
- Verify route is registered

**Middleware runs for static files?**
- Yes, that's intentional! (QEP-061)
- Request middleware runs for all requests
- Response middleware also runs for static file responses

## References

- **QEP-061**: [Request/Response Middleware Specification](../../specs/qep-061-request-response-middleware.md)
- **QEP-062**: [Flexible Path Parameter Routing](../../lib/std/web/middleware/router.q)
- **Web Module**: [std/web Configuration API](../../lib/std/web/index.q)
- **Standard Library**: [std/web/middleware/router.q Router Implementation](../../lib/std/web/middleware/router.q)

## Contributing

To add new examples:
1. Create a new `.q` file in this directory
2. Add comprehensive comments
3. Include a matching `.md` documentation file
4. Update this README with a link

Enjoy building web apps with Quest! 🚀
