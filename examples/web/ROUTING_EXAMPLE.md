# Quest Web App with Flexible Routing (QEP-062)

This example demonstrates Quest's modern web routing system with flexible path parameters, type conversion, and middleware support.

## Features Demonstrated

### 1. **Flexible Path Parameters** (QEP-062)
- **Static routes**: `/hello`, `/posts`, `/status`
- **String parameters**: `/posts/{slug}` - captures post slugs like "first-post"
- **Typed parameters**: `/users/{id<int>}` - captures numeric IDs, rejects non-numeric values
- **Greedy path capture**: `/files/{path<path>}` - captures multi-segment paths like "docs/guide.md"

### 2. **Request Middleware** (QEP-061)
- Adds request timing via `_start_time`
- Generates unique request IDs for tracking
- Runs for all requests (static + dynamic)

### 3. **Response Middleware** (QEP-061)
- Adds security headers (X-Content-Type-Options, X-Frame-Options)
- Calculates and reports response time in X-Response-Time header
- Adds request tracking ID to responses

### 4. **CORS Configuration**
- Allows requests from any origin (for demo purposes)
- Supports multiple HTTP methods and headers

### 5. **RESTful Patterns**
- GET routes for retrieving data
- POST routes for creating resources
- Mock data instead of real database (simplicity)

## Running the Example

```bash
cd /Users/steven/Projects/hacking/quest2
./target/release/quest examples/web/routing_app.q
```

## Testing Routes

### 1. Basic Routes
```bash
# Welcome page
curl http://localhost:3000/

# Simple text response
curl http://localhost:3000/hello
```

### 2. List Resources
```bash
# List all posts (returns JSON)
curl http://localhost:3000/posts
```

### 3. String Parameters
```bash
# Get specific post by slug
curl http://localhost:3000/posts/first-post
curl http://localhost:3000/posts/second-post
curl http://localhost:3000/posts/nonexistent  # Returns 404
```

### 4. Typed Integer Parameters
```bash
# Get user by numeric ID
curl http://localhost:3000/users/1
curl http://localhost:3000/users/42
curl http://localhost:3000/users/invalid  # Rejected - not numeric, returns 404
```

### 5. Greedy Path Capture
```bash
# Get file by path (multi-segment)
curl http://localhost:3000/files/readme.md
curl http://localhost:3000/files/docs/guide.md
curl http://localhost:3000/files/docs/api.md
curl http://localhost:3000/files/missing/file.txt  # Returns 404
```

### 6. POST Requests
```bash
# Create a new post
curl -X POST http://localhost:3000/posts \
  -H "Content-Type: application/json" \
  -d '{"title": "New Post", "slug": "new-post"}'
```

### 7. Health Check
```bash
curl http://localhost:3000/status
```

### 8. Check Middleware Headers
```bash
# All responses include middleware-added headers
curl -i http://localhost:3000/hello
# Look for:
#   X-Response-Time: 0ms
#   X-Request-ID: 127.0.0.1-<timestamp>
#   X-Content-Type-Options: nosniff
#   X-Frame-Options: DENY
```

## Code Structure

### Route Registration (QEP-062)
```quest
router.get("/posts/{slug}", fun (req)
  let slug = req["params"]["slug"]
  # Handle request...
end)

router.get("/users/{id<int>}", fun (req)
  let user_id = req["params"]["id"]  # Guaranteed to be an integer
  # Handle request...
end)

router.get("/files/{path<path>}", fun (req)
  let file_path = req["params"]["path"]  # Captures multi-segment paths
  # Handle request...
end)
```

### Request Middleware (QEP-061)
```quest
web.middleware(fun (req)
  # Middleware runs for ALL requests (static + dynamic)
  req["_start_time"] = time.now()
  return req
end)
```

### Response Middleware (QEP-061)
```quest
web.after(fun (req, resp)
  # Post-process all responses
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["X-Custom"] = "value"
  return resp
end)
```

## Pattern Types Available

- **`{slug}`** - String parameter (default), matches single path segment
- **`{id<int>}`** - Integer parameter, only matches numeric values
- **`{price<float>}`** - Float parameter, only matches floating-point numbers
- **`{id<uuid>}`** - UUID parameter, only matches valid UUIDs
- **`{path<path>}`** - Greedy path parameter, matches remaining path segments

## Error Handling

- **Type mismatch**: Non-numeric ID returns 404 via route rejection
- **Path not found**: Routes fall through to `handle_404()` handler
- **No handler defined**: Server returns 404 for all unhandled requests

## Key Concepts

### 1. Route Priority
- Longer/more specific routes match first
- Static segments have priority over dynamic parameters
- Within the same specificity, routes are matched in registration order

### 2. Type Safety
- `{id<int>}` ensures only valid integers match
- Invalid values cause route to be skipped (not an error)
- Type validation happens during route matching, not handler execution

### 3. URL Decoding
- Path parameters are automatically URL-decoded
- Spaces (%20), special characters (%2F), etc. are handled

### 4. Middleware Pipeline
1. Request comes in
2. Request middleware runs (adds timing, ID, etc.)
3. Route matching and handler execution
4. Response middleware runs (adds headers, timing, etc.)
5. Response sent to client

## Comparison with Other Approaches

### Before (Manual Routing)
```quest
fun handle_request(req)
  let path = req["path"]
  if path == "/users/1"
    # Handle user 1
  elif path == "/users/2"
    # Handle user 2
  # ... manual string parsing required
end
```

### After (QEP-062 Router)
```quest
router.get("/users/{id<int>}", fun (req)
  let user_id = req["params"]["id"]  # Already parsed and validated!
  # Handle any user ID
end)
```

## Next Steps

1. **Add a database**: Replace mock data with real database queries
2. **Add authentication**: Use middleware to check auth tokens
3. **Add validation**: Validate input before processing
4. **Add logging**: Use response middleware to log access
5. **Add caching**: Use middleware to add Cache-Control headers
6. **Serve templates**: Use `std/html/templates` to render pages

## See Also

- **QEP-062**: Flexible Path Parameter Routing
- **QEP-061**: Request/Response Middleware
- **QEP-060**: Application-Centric Web Server
- **std/web**: Web framework configuration
- **std/web/middleware/router**: Router implementation
