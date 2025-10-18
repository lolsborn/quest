# Quest Web Framework Ecosystem: QEP-060/061/062

## Overview

Three interconnected QEPs build the complete Quest web framework:

| QEP | Title | Status | Role |
|-----|-------|--------|------|
| **QEP-060** | Application-Centric Web Server | Phase 2 ✅ | Core HTTP server startup |
| **QEP-061** | Web Server Middleware System | Design ⏳ | Request/response interception |
| **QEP-062** | Flexible Path Parameter Routing | Design ⏳ | URL routing as middleware |

## Architecture Layers

```
┌─────────────────────────────────────────────────────┐
│ Application Code (user's server.q)                  │
│                                                     │
│ use "std/web" as web                               │
│ use "std/web/middleware/router" as router          │
│ use "std/web/middleware/logging" as logging        │
│                                                     │
│ router.get("/post/{slug}", handler)                │
│ web.use(logging.before)                            │
│ web.use(router.dispatch_middleware)                │
│ web.after(logging.after)                           │
│ web.run()                                          │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ Quest Middleware Layer (QEP-061)                    │
│                                                     │
│ Execute web.use() middlewares:                     │
│   • logging.before() - start timer                 │
│   • router.dispatch() - match route, inject params │
│                                                     │
│ Execute handler (static or dynamic)                │
│                                                     │
│ Execute web.after() middlewares:                   │
│   • logging.after() - log request/response         │
└─────────────────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────────────────┐
│ HTTP Server Layer (QEP-060)                         │
│                                                     │
│ Listen on host:port                                │
│ Parse HTTP requests                                │
│ Convert to Quest request dict                      │
│ Call Quest middleware chain                        │
│ Convert response dict to HTTP                      │
│ Send back to client                                │
│ Graceful shutdown on Ctrl+C                        │
└─────────────────────────────────────────────────────┘
              ↓
         [Network]
```

## QEP-060: Core HTTP Server (Phase 2 Complete)

### Current Status
- ✅ Phase 1: Native function framework
- ✅ Phase 2: Configuration extraction
- ⏳ Phase 3: HTTP server startup
- ⏳ Phase 4: Request/response handling

### API
```quest
use "std/web" as web

web.add_static("/public", "./public")
web.set_cors(origins: ["*"])

fun handle_request(req)
  {status: 200, body: "Hello"}
end

web.run(host: "0.0.0.0", port: 8080)
```

### Provides
- HTTP server lifecycle (startup, shutdown)
- Configuration management (quest.toml overrides)
- Request dict format
- Response dict format
- Static file serving (via Axum)

## QEP-061: Middleware System (Design Phase)

### Planned
- Request middlewares: `web.use(fn)` - can short-circuit with response
- After middlewares: `web.after(fn)` - modify response
- Error handling: Middleware errors return 500
- Static file visibility: Middlewares see all requests

### API
```quest
use "std/web" as web
use "std/time"

# Request middleware - add timing
web.use(fun (req)
  req["_start_time"] = time.now()
  return req
end)

# Response middleware - add headers and log
web.after(fun (req, resp)
  let duration = time.now().diff(req["_start_time"]).as_milliseconds()
  resp["headers"]["X-Response-Time"] = duration.str()
  logger.info(f"{req['path']} - {resp['status']} ({duration}ms)")
  return resp
end)

web.run()
```

### Provides
- Middleware registration
- Before/after hooks for all requests
- Request modification capability
- Response modification capability
- Short-circuiting (auth, rate limiting, etc.)

## QEP-062: Routing System (Design Phase)

### Planned
- Path parameter extraction: `/post/{slug}`
- Type conversion: `/user/{id<int>}`
- Pattern matching with priority
- Router as middleware (QEP-061 integration)
- Multiple router instances (modular apps)

### API
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  # ...
end)

router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Already Int
  # ...
end)

# Register router as middleware (explicit, not magic)
web.use(router.dispatch_middleware)

web.run()
```

### Provides
- Route registration (GET, POST, PUT, DELETE, PATCH)
- Path parameter extraction
- Type conversion in URLs
- URL decoding
- Pattern priority (static routes first)

## File Structure After All Phases

```
lib/std/web/
├── index.q                          # Main API: add_static, set_cors, use, after, run
├── middleware/
│   ├── router.q                     # QEP-062: Routing (path params, methods)
│   ├── logging.q                    # QEP-061: Example - HTTP access logging
│   ├── cors.q                       # QEP-061: Example - CORS handling
│   ├── auth.q                       # QEP-061: Example - Authentication
│   └── [other middleware...]
├── router/
│   ├── index.q                      # Convenience exports
│   └── Router.q                     # Router type for custom instances
└── [utilities, types, etc.]

Also: Move current std/web.q → std/web/index.q
```

## Integration Timeline

### Phase 3 (QEP-060)
Prerequisite for all middleware/routing:
1. HTTP server startup
2. Request/response dict conversion
3. Static file integration

### Phase 5 (QEP-061)
Requires Phase 3-4:
1. Middleware chain execution
2. Before/after hooks
3. Error handling in middleware

### Phase 6 (QEP-062)
Requires Phase 3-5:
1. Route registration API
2. Pattern parsing
3. Path parameter extraction
4. Register as middleware

## Usage Examples

### Static-Only Server (QEP-060 alone)
```quest
use "std/web" as web

web.add_static("/", "./public")
web.run()
```

### With Logging (QEP-060 + QEP-061)
```quest
use "std/web" as web
use "std/web/middleware/logging" as logging

web.add_static("/public", "./public")
web.use(logging.create_logger("web.access").before)
web.after(logging.create_logger("web.access").after)

fun handle_request(req)
  {status: 200, body: "Hello"}
end

web.run()
```

### With Routing (QEP-060 + QEP-061 + QEP-062)
```quest
use "std/web" as web
use "std/web/middleware/router" as router
use "std/web/middleware/logging" as logging

router.get("/", fun (req) {status: 200, body: "Home"} end)
router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  {status: 200, body: f"Post: {slug}"}
end)

web.use(logging.create_logger().before)
web.use(router.dispatch_middleware)
web.after(logging.create_logger().after)

web.run()
```

### With Authentication (QEP-060 + QEP-061 + QEP-062 + custom middleware)
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Custom auth middleware
fun auth_middleware(req)
  if req["path"].starts_with("/admin")
    let token = req["headers"]["authorization"]
    if token == nil
      # Short-circuit with 401
      return {status: 401, body: "Unauthorized"}
    end
  end
  return req  # Continue chain
end

router.get("/api/public", fun (req)
  {status: 200, json: {message: "public"}}
end)

router.get("/admin/dashboard", fun (req)
  {status: 200, json: {message: "admin only"}}
end)

web.use(auth_middleware)        # Check auth first
web.use(router.dispatch_middleware)

web.run()
```

## Design Principles

1. **Middleware-First**: Everything (including routing) is middleware
2. **Explicit Over Implicit**: No magic auto-registration
3. **Composable**: Middleware can be mixed in any order
4. **Replaceable**: Users can replace router with custom implementation
5. **Transparent**: Users control and see the middleware chain
6. **Optional**: Static servers don't need routing

## Success Criteria

### Phase 3 (QEP-060)
- [ ] HTTP server actually listens on port
- [ ] Ctrl+C triggers graceful shutdown
- [ ] No script double-execution
- [ ] Config from quest.toml is used

### Phase 5 (QEP-061)
- [ ] Middleware chain executes in order
- [ ] Before middlewares can modify requests
- [ ] After middlewares can modify responses
- [ ] Middleware errors don't crash server

### Phase 6 (QEP-062)
- [ ] Path parameters extracted correctly
- [ ] Type conversions work
- [ ] Router registers as middleware
- [ ] Multiple routers can be composed

## Conclusion

Quest's web framework will provide modern middleware-based architecture matching industry-standard frameworks (Express, Flask, Django), while maintaining Quest's philosophy of explicit, composable, and understandable code.

The three QEPs work together to provide:
- ✅ Core HTTP server (QEP-060)
- ✅ Flexible request/response interception (QEP-061)
- ✅ Modern URL routing with parameters (QEP-062)
