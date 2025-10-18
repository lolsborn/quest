# Advanced Middleware Patterns in Quest (QEP-061)

This example demonstrates advanced middleware techniques including short-circuiting, authentication, and request transformation.

## Key Features

### 1. **Middleware Short-Circuiting**
Middleware can return a response dict with a `status` field to immediately end the request pipeline and return the response to the client.

```quest
web.middleware(fun (req)
  if is_unauthorized(req)
    # Short-circuit: return 401 instead of continuing
    return {
      status: 401,
      json: {error: "Unauthorized"},
      headers: {Content-Type: "application/json"}
    }
  end
  return req  # Continue to next middleware/handler
end)
```

### 2. **Request Transformation**
Middleware can add computed fields to requests for use by handlers.

```quest
web.middleware(fun (req)
  req["_user"] = extract_user_from_token(req)
  req["_start_time"] = time.now()
  return req
end)
```

### 3. **Response Post-Processing**
Response middleware runs after the handler and can transform responses before they're sent.

```quest
web.after(fun (req, resp)
  # Add security headers to all responses
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["X-Content-Type-Options"] = "nosniff"
  return resp
end)
```

### 4. **Middleware Pipeline Order**
Middleware runs in the order it's registered:

```
Request arrives
  ↓
Logging middleware (logs request)
  ↓
Authentication middleware (checks auth, may short-circuit)
  ↓
Request transformation middleware (adds _user, _start_time)
  ↓
Route matching and handler execution
  ↓
Response middleware (adds headers, timing)
  ↓
Response sent to client
```

## Running the Example

```bash
./target/release/quest examples/web/routing_middleware_advanced.q
```

## Testing

### Public Routes (No Authentication)

```bash
# Welcome page
curl http://localhost:3000/

# Public info endpoint
curl http://localhost:3000/public/info

# Health check (works without auth)
curl http://localhost:3000/health
```

### Protected Routes (Authentication Required)

```bash
# Without auth - returns 401
curl http://localhost:3000/admin/dashboard

# With valid token - returns 200
curl -H "Authorization: Bearer valid-mytoken" \
  http://localhost:3000/admin/dashboard

# With invalid token - returns 401
curl -H "Authorization: Bearer invalid-token" \
  http://localhost:3000/admin/dashboard

# Private API (also requires auth)
curl -H "Authorization: Bearer valid-abc123" \
  http://localhost:3000/api/private/data
```

## Middleware Implementation Details

### 1. Logging Middleware
```quest
web.middleware(fun (req)
  let now = time.now().str()
  puts(f"[{now}] {req['method']} {req['path']} from {req['client_ip']}")
  return req
end)
```
- Runs first for every request
- Logs method, path, and client IP
- Returns modified request to continue pipeline

### 2. Authentication Middleware
```quest
web.middleware(fun (req)
  if req["path"].startswith("/admin")
    let headers = req["headers"] or {}
    let auth = headers["authorization"] or ""

    if not auth.startswith("Bearer valid-")
      # Short-circuit with 401 response
      return {status: 401, ...}
    end

    req["_auth_token"] = auth.slice(7, auth.len())
  end

  return req
end)
```
- Checks for Authorization header on protected routes
- Returns 401 response to short-circuit if unauthorized
- Stores token in request for handler use

### 3. Request Transformation Middleware
```quest
web.middleware(fun (req)
  req["_start_time"] = time.now()
  req["_request_id"] = "req-" .. time.now().milliseconds()

  if req["_auth_token"] != nil
    req["_user"] = {
      id: extract_user_id(req["_auth_token"]),
      authenticated: true
    }
  end

  return req
end)
```
- Adds timing and request ID fields
- Extracts user information for handler use
- Runs after authentication (so auth token is available)

### 4. Response Middleware
```quest
web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end

  # Add security headers to all responses
  resp["headers"]["X-Content-Type-Options"] = "nosniff"

  # Add timing header
  if req["_start_time"] != nil
    let ms = time.now().diff(req["_start_time"]).as_milliseconds()
    resp["headers"]["X-Response-Time"] = ms.str() .. "ms"
  end

  return resp
end)
```
- Runs AFTER handler execution
- Adds security headers to all responses
- Includes response timing information

## Common Patterns

### Pattern 1: Authentication Guard
```quest
web.middleware(fun (req)
  if is_protected_route(req["path"]) and not is_authenticated(req)
    return {status: 401, ...}  # Short-circuit
  end
  return req
end)
```

### Pattern 2: Request Enrichment
```quest
web.middleware(fun (req)
  req["_trace_id"] = generate_trace_id()
  req["_start_time"] = time.now()
  req["_user"] = extract_user(req)
  return req
end)
```

### Pattern 3: Rate Limiting
```quest
web.middleware(fun (req)
  let client_ip = req["client_ip"]
  if is_rate_limited(client_ip)
    return {status: 429, ...}  # Too Many Requests
  end
  return req
end)
```

### Pattern 4: Request Logging & Metrics
```quest
web.after(fun (req, resp)
  let elapsed = time.now().diff(req["_start_time"]).as_milliseconds()
  log_request(req, resp, elapsed)

  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["X-Response-Time"] = elapsed.str() .. "ms"

  return resp
end)
```

### Pattern 5: CORS Headers
```quest
web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end
  resp["headers"]["Access-Control-Allow-Origin"] = "*"
  resp["headers"]["Access-Control-Allow-Methods"] = "GET, POST, PUT, DELETE"
  return resp
end)
```

## Comparison with Filter/Decorator Patterns

### Traditional Approach (Decorators)
```quest
@AuthRequired
@LogRequest
fun get_user(id)
  # Function decorated with multiple decorators
end
```

### Quest Middleware Approach
```quest
web.middleware(fun (req) ... end)     # Logging
web.middleware(fun (req) ... end)     # Auth check
router.get("/users/{id}", fun (req) ... end)  # Handler
web.after(fun (req, resp) ... end)    # Response processing
```

**Advantages of middleware approach:**
- Applies to ALL routes automatically
- Runs consistently across all endpoints
- Easy to add/remove for entire application
- Clear pipeline visibility
- No decorator syntax needed

## Headers Added by Example

All responses include these headers from middleware:

```
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
X-Response-Time: 2ms
X-Request-ID: 127.0.0.1-1729276800123
Access-Control-Allow-Origin: *
```

## Performance Considerations

1. **Middleware ordering**: Put expensive middleware (auth, rate-limiting) after cheaper middleware (logging)
2. **Short-circuit early**: If a middleware rejects the request, it stops the pipeline immediately
3. **Avoid duplicating work**: Store computed values in request context instead of recomputing in handlers

## Next Steps

1. **Add rate limiting**: Track requests per IP, return 429 if exceeded
2. **Add request/response logging**: Log full request/response details
3. **Add metrics collection**: Time handler execution, track error rates
4. **Add JWT validation**: Validate JWT tokens instead of simple string prefix
5. **Add request validation**: Validate headers, content-type, etc. early in pipeline

## See Also

- **QEP-061**: Request/Response Middleware
- **QEP-062**: Flexible Path Parameter Routing
- [routing_app.q](./routing_app.q) - Basic routing example
- [ROUTING_EXAMPLE.md](./ROUTING_EXAMPLE.md) - Routing documentation
