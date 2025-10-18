# QEP-060 Phase 3+ Implementation Plan
## What Needs to be Done Before QEP-061 and QEP-062

This document outlines the remaining work needed in QEP-060 to provide a solid foundation for QEP-061 (Middleware System) and QEP-062 (Flexible Routing).

---

## Executive Summary

**Current Status**: QEP-060 Phase 2 is complete. Configuration extraction works, but HTTP server startup is not yet implemented.

**Critical Path**:
1. ✅ Phase 1-2: Foundation complete (native function, config extraction)
2. ⏳ **Phase 3 (BLOCKING): Actual HTTP server startup** - Required for ANY web functionality
3. ⏳ Phase 4: Static file serving with Axum integration
4. ⏳ Phase 5: Integration with middleware/routing systems

**Dependency Chain**:
- QEP-061 (Middleware) requires: Working HTTP server + request/response dict support
- QEP-062 (Routing) requires: Working HTTP server + middleware support + request dict with path

---

## Phase 3: HTTP Server Startup (CRITICAL)

### Current Blocker
The `web.run()` function currently:
- ✓ Extracts host/port from configuration
- ✓ Displays startup message
- ✗ **Does NOT start actual HTTP server**
- ✗ **Does NOT bind to port or listen for connections**

### What's Required
```rust
// src/modules/web.rs - web_run() function needs to:

1. Create ServerConfig struct with extracted configuration
   - host, port
   - static_dirs from web._get_config()
   - CORS config (if present)
   - Timeouts, max body size, etc.

2. Build Axum router
   - Add routes for both static files and dynamic handlers
   - Configure error handling

3. Start tokio runtime
   - Block_on async server startup
   - Listen on configured host:port

4. Register signal handlers
   - Ctrl+C (SIGINT)
   - SIGTERM
   - Graceful shutdown

5. Block until shutdown signal received
   - Server handles requests
   - Finish in-flight requests
   - Clean shutdown

6. Return Nil to script
   - Script execution continues after server stops
```

### Key Implementation Details

**ServerConfig Extraction** (from scope):
```rust
// Get web module from scope
// Call web._get_config() to get runtime config dict
// Extract:
//   - static_dirs: Vec<(String, String)>
//   - cors: Option<CorsConfig>
//   - has_before_hooks, has_after_hooks
//   - error_handlers
//   - default_headers
//   - redirects

// Get handle_request function from scope
// Verify it exists (unless static-only mode)
```

**Thread-Local Scope Management**:
```rust
// Currently: QUEST_SCOPE thread-local is set in init_thread_scope()
// Issue: init_thread_scope() is called per worker thread
//        (This caused double-execution in quest serve)
//
// Solution for Phase 3:
// - Freeze scope at web.run() time
// - Clone scope for each worker thread
// - Each thread gets its own scope copy
// - No double-execution (script runs once in main thread)
```

**Request Handling Flow**:
```
web.run() starts
  ↓
Create async server with tokio
  ↓
For each request:
  1. Create request dict from HTTP request
  2. Set up thread-local scope
  3. Call Quest handle_request(req)
  4. Convert Quest dict to HTTP response
  ↓
Server blocks until Ctrl+C
  ↓
Graceful shutdown
  ↓
Return Nil
```

### Estimated Scope
- ~200-300 lines of Rust code
- No breaking changes to existing APIs
- Leverages existing server infrastructure (already in src/server.rs)

---

## Phase 4: Static File and Dynamic Route Integration

### Requirement from QEP-061/062
Both require:
- ✓ Request dict with `path`, `method`, `headers`, `body`, `query`
- ✗ Proper static file serving via Axum middleware
- ✗ Request/response conversion that preserves Quest dicts
- ✗ Thread-safe request/response handling in tokio

### What's Required
```rust
// Integrate with Axum router in web.run()

1. Build Axum router with:
   - Static file directories (ServeDir middleware)
   - Dynamic route handler (calls handle_request)

2. Request dict conversion:
   - HTTP headers → dict
   - Query string → dict
   - Request body → dict
   - Client IP extraction

3. Response dict conversion:
   - Quest dict → HTTP response
   - Headers handling
   - Status codes
   - Body encoding

4. Error handling:
   - 404 for missing routes
   - 500 for handler errors
   - Proper HTTP error responses
```

### Estimated Scope
- ~200-300 lines of Rust
- Reuse existing dict conversion functions
- Integration with Axum's router and middleware

---

## Phase 5: Middleware System Integration (Requires Phase 3-4)

### For QEP-061 Support

Phase 3-4 must provide:
- ✓ Request dict format (with all required fields)
- ✓ Response dict format (status, headers, body)
- ✓ Thread-safe Quest scope access
- ✗ Middleware chain execution points

**What Phase 5 adds**:
```rust
// In request handler (after Phase 3-4):

1. Extract middlewares from config
   - web._get_config()["middlewares"]
   - web._get_config()["after_middlewares"]

2. Execute request middlewares:
   - Call each middleware with request dict
   - If any returns dict with "status" → short-circuit
   - Pass modified request to handler

3. Call handler (static or handle_request)

4. Execute after middlewares:
   - Call each middleware with (request, response)
   - Can modify response (add headers, etc.)

5. Return final response
```

This is mostly Rust code in request handler, not in web.run().

---

## Phase 6: Routing System Integration (Requires Phase 3-5)

### For QEP-062 Support

Phase 3-5 must provide:
- ✓ Request dict with path, method, params
- ✓ Middleware chain execution
- ✗ Path parameter extraction in request dict

**What Phase 6 adds**:
```quest
// In std/web/middleware/router.q (Quest code - NEW LOCATION):

1. Route registration API:
   router.get("/post/{slug}", handler)

2. Middleware dispatch:
   - Parse pattern: "/post/{slug}" → [static:"post", param:"slug"]
   - Match request path: "/post/hello" → {slug: "hello"}
   - Inject params into request dict
   - Call handler

3. Return from middleware as modified request

4. Handler receives request with req["params"]["slug"]
```

This is mostly Quest code, not Rust.

**Architectural Note**: Router is now explicitly placed in `std/web/middleware/router` to emphasize that:
- Routing is middleware, not a core HTTP server feature
- Users can replace it with custom routers
- Other middleware (logging, auth, etc.) can be composed alongside it
- Static-only servers don't require router at all

---

## Dependency Graph

```
Phase 3: HTTP Server Startup
├─ Prerequisite: None (can start immediately)
├─ Blockers for: Phase 4, 5, 6
└─ Enables: Basic web.run() functionality

Phase 4: Static Files + Dynamic Routes
├─ Prerequisite: Phase 3
├─ Blockers for: Phase 5, 6
└─ Enables: Actual request handling

Phase 5: Middleware System (QEP-061)
├─ Prerequisite: Phase 4
├─ Blockers for: Phase 6
└─ Enables: Before/after hooks, logging, auth middleware

Phase 6: Routing (QEP-062)
├─ Prerequisite: Phase 5
└─ Enables: Path parameters, modular routing
```

---

## Recommended Implementation Order

### Immediate (Next Work Session)
1. **Phase 3**: Implement actual server startup in web.run()
   - This is critical blocker for everything else
   - Relatively straightforward (follow existing server code pattern)
   - Estimated: 2-3 hours

### Short Term
2. **Phase 4**: Integrate static files and dynamic routes
   - Reuse dict conversion logic
   - Estimated: 2-3 hours

### Medium Term
3. **Phase 5**: Middleware system support
   - Implement middleware chain execution
   - Estimated: 1-2 hours

### Follow-up
4. **Phase 6**: Routing system
   - Mostly Quest code (easier to ship)
   - Estimated: 2-3 hours

---

## Critical Questions for Phase 3-4

### 1. Scope Freezing Strategy
**Question**: When we freeze scope at web.run() time, how do we handle:
- ✓ handle_request function reference (works)
- ✓ Static config like static_dirs (works)
- ? Module-level variables defined after web.run()? (shouldn't happen)
- ? Request-scoped state? (each request gets thread-local scope copy)

**Answer**: Use Arc<Scope> shared across all worker threads. Each worker thread gets a clone.

### 2. Thread Safety
**Question**: How do we ensure thread-safe Quest scope access?
- Scope uses Rc<RefCell<>> for interior mutability
- Rc is not Send/Sync

**Current Solution in server.rs**:
- thread_local! { QUEST_SCOPE }
- Each thread gets its own Scope copy

**Phase 3 should maintain this** for compatibility.

### 3. Error Handling
**Question**: What happens if handle_request() panics or returns invalid dict?
- Should return 500 error
- Shouldn't crash server

**Answer**: Wrap call_user_function in try/catch with proper error response.

### 4. Static File Serving
**Question**: Should static files be served by Axum middleware or Quest?

**Design Decision (from server.rs existing code)**:
- Use Axum's ServeDir for actual file serving (fast, efficient)
- Quest sees static files as 200 responses that middlewares can modify
- This is the existing pattern - maintain it

---

## Testing Strategy for Phase 3

### Unit Tests (test/web/)
```quest
test.it("web.run() starts server on configured port", fun ()
  # This will be tricky - can't really test blocking server
  # Maybe test configuration extraction only
end)

test.it("handle_request is called for requests", fun ()
  # Mock request handling
end)
```

### Integration Tests
- Manual testing with simple_app.q
- Test with curl: `curl http://localhost:3000/`
- Test Ctrl+C graceful shutdown
- Test multiple static directories
- Test error handling

### Performance Tests
- Verify no regressions vs current `quest serve`
- Test under load (many concurrent requests)

---

## Breaking Changes

### Phase 3
- ✗ None - extends Phase 2, doesn't change API

### Phase 4
- ✗ None - extends Phase 3, doesn't change API

### Phase 5 (QEP-061)
- ✓ Changes middleware API (before_hooks/after_hooks → use/after)
- ✓ Static files now visible to after middlewares
- Mitigation: Keep old hooks working for backwards compat

### Phase 6 (QEP-062)
- ✗ None - new feature, doesn't break existing code

---

## Rollout Plan

### Phase 3 Checkpoint
```
Before Phase 3:
  ✓ web.run() extracts config
  ✓ Displays startup message
  ✓ Returns Nil

After Phase 3:
  ✓ web.run() actually starts HTTP server
  ✓ Serves requests to http://localhost:port
  ✓ Returns Nil after shutdown
```

### Phase 4 Checkpoint
```
Before Phase 4:
  ✓ Server starts but doesn't handle requests

After Phase 4:
  ✓ Server serves static files from configured dirs
  ✓ Dynamic routes call handle_request()
  ✓ Request dicts contain path, method, headers, body
  ✓ Responses properly converted to HTTP
```

### Phase 5 Checkpoint
```
Before Phase 5:
  ✓ Basic request/response handling works

After Phase 5:
  ✓ Middleware chain executes
  ✓ Before middlewares can modify requests
  ✓ After middlewares can modify responses
  ✓ Middleware errors don't crash server
```

### Phase 6 Checkpoint
```
Before Phase 6:
  ✓ Middleware system works

After Phase 6:
  ✓ Path parameters extracted and available
  ✓ Routes register with patterns
  ✓ Routing middleware dispatches to handlers
```

---

## Success Criteria for Phase 3

- [ ] `web.run()` binds to configured host:port
- [ ] Server accepts HTTP connections
- [ ] Server handles Ctrl+C gracefully
- [ ] handle_request() is called for requests
- [ ] Responses are sent back to clients
- [ ] No double-script-execution
- [ ] Configuration from quest.toml is used
- [ ] Command-line args to web.run() override config
- [ ] All existing tests still pass
- [ ] New tests verify basic server functionality

---

## Success Criteria for Phases 4-6

### Phase 4
- [ ] Static files served from configured directories
- [ ] handle_request() receives proper request dicts
- [ ] Responses are properly converted to HTTP
- [ ] 404 for missing routes

### Phase 5
- [ ] Middleware functions can modify requests
- [ ] Middleware functions can short-circuit with responses
- [ ] After middlewares run for all requests
- [ ] Middleware errors return 500
- [ ] Static files visible to middleware

### Phase 6
- [ ] Path parameters extracted from routes
- [ ] req["params"] populated correctly
- [ ] Type conversions work ({id<int>})
- [ ] Multiple routers can be mounted
- [ ] URL decoding handled properly

---

## Risk Assessment

### Phase 3 (HTTP Server Startup)
- **Risk Level**: Medium
- **Main Risk**: Thread-local scope management
- **Mitigation**: Follow existing server.rs patterns
- **Fallback**: Revert to previous approach if issues

### Phase 4 (Static Files + Routes)
- **Risk Level**: Low
- **Main Risk**: Dict conversion edge cases
- **Mitigation**: Extensive testing with various request types
- **Fallback**: Use existing dict_to_http_response functions

### Phase 5 (Middleware)
- **Risk Level**: Low
- **Main Risk**: Middleware error propagation
- **Mitigation**: Wrap errors with proper context
- **Fallback**: Return 500 on middleware error

### Phase 6 (Routing)
- **Risk Level**: Very Low
- **Main Risk**: None (mostly Quest code)
- **Mitigation**: Test routing patterns thoroughly
- **Fallback**: Simple linear search if performance issues

---

## Conclusion

QEP-060 Phase 3 is the critical blocker. Once Phase 3 is complete:
- QEP-061 can be implemented with middleware support
- QEP-062 can be implemented with routing support
- Both can coexist without conflicts

**Recommended Next Step**: Begin Phase 3 (HTTP Server Startup) immediately.
