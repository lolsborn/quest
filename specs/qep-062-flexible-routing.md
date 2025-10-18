---
Number: QEP-062
Title: Flexible Path Parameter Routing
Author: Claude (with Steven Ruppert)
Status: Draft
Created: 2025-10-18
---

# QEP-062: Flexible Path Parameter Routing

## Overview

Add path parameter support to Quest's web framework, enabling patterns like `/post/:slug` and `/user/{id}` that automatically extract parameters into `req["params"]`. This eliminates manual string manipulation and brings Quest's routing on par with Flask, Express, FastAPI, and Sinatra.

## Problem Statement

### The Problem

Without path parameter support, web applications must manually extract route parameters using string manipulation:

```quest
# Manual approach without route parameters
let path = req["path"]
let slug = path.replace("/post/", "")  # Fragile string manipulation
```

### Issues with Manual Extraction

1. **Repetitive boilerplate**: Every dynamic route repeats the same extraction pattern
2. **Error-prone**: Easy to make mistakes in prefix/suffix handling
3. **No validation**: `/post/foo/bar/baz` matches `/post/` prefix (too permissive)
4. **Poor discoverability**: Reading code doesn't reveal the expected path structure
5. **Maintainability**: Changing a route requires updating both routing logic and extraction code

### Desired Solution

```quest
use "std/web/middleware/router" as router

router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]  # Automatic extraction
  let post = post_repo.find_by_slug(db, slug, true)
  # ...
end)

# With type checking
router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Already converted to Int
  # ...
end)

# File serving with path type (greedy capture)
router.get("/files/{path<path>}", fun (req)
  let file_path = req["params"]["path"]  # Captures "a/b/c.txt"
  # ...
end)
```

**Benefits**:
- ✅ Self-documenting: Path structure visible in decorator
- ✅ Automatic: No manual string manipulation
- ✅ Validated: Only matches expected path structure
- ✅ Type-safe: Built-in type conversion (`:id<int>`, `:uuid<uuid>`)
- ✅ Secure: Path type enables safe file serving with validation

## Design

### Routing as Middleware (QEP-061 Integration)

**Key architectural decision**: The router should be registered as **middleware**, not baked into the server. This allows users to:
1. Use the built-in `std/web/middleware/router` middleware (recommended)
2. Replace it with a custom router
3. Disable routing entirely (for pure static file serving)

**Architecture**:
```
Incoming Request
    ↓
[Middleware Chain - QEP-061]
    ↓
[std/web/middleware/router] ← Registered as middleware (this QEP)
    │
    ├─ Pattern matching
    ├─ Type conversion
    ├─ Inject req["params"]
    └─ Call handler
    ↓
[Other middlewares...]
    ↓
Response
```

**Default setup** (simple):
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Register routes on the default router
router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  # ...
end)

# IMPORTANT: Explicitly register router as middleware
# Router is NOT auto-registered - you must call web.use()
web.use(router.dispatch_middleware)

web.run()
```

**Multiple routers** (Express-style, modular apps):
```quest
use "std/web" as web
use "std/web/middleware/router" {Router}

# Create separate routers for different modules
let user_router = Router.new()
let product_router = Router.new()

# Define user routes
user_router.get("/", fun (req)
  return {status: 200, json: get_all_users()}
end)

user_router.get("/{id<int>}", fun (req)
  let id = req["params"]["id"]
  return {status: 200, json: get_user(id)}
end)

# Define product routes
product_router.get("/", fun (req)
  return {status: 200, json: get_all_products()}
end)

product_router.get("/{id<int>}", fun (req)
  let id = req["params"]["id"]
  return {status: 200, json: get_product(id)}
end)

# Mount routers at base paths
web.mount("/users", user_router)      # Routes: /users/, /users/:id
web.mount("/products", product_router)  # Routes: /products/, /products/:id

web.run()

# GET /users/      → user_router handles → get_all_users()
# GET /users/123   → user_router handles → get_user(123)
# GET /products/   → product_router handles → get_all_products()
# GET /products/45 → product_router handles → get_product(45)
```

**No router** (static-only server):
```quest
use "std/web" as web

# No routes defined, no routers mounted
web.add_static("/", "./public")  # Only serve static files

web.run()

# No router middleware is registered (no routes)
# All non-static requests → 404
```

### Pattern Syntax

Use **brace syntax** for path parameters: `/post/{slug}`

**Syntax**:
- Only brace syntax `{param}` is supported (e.g., `/post/{slug}`)
- Colon syntax `:param` is **not** supported
- Type annotations use angle brackets: `{param<type>}` (e.g., `{id<int>}`)

**Why braces?**
- Clearer visual separation from path segments
- Matches Flask, FastAPI, Axum, OpenAPI spec
- Works better with type annotations: `/user/{id<int>}`
- No ambiguity with special characters

**Examples**:
```quest
router.get("/post/{slug}", handler)                    # Single param
router.get("/user/{id}/posts/{post_id}", handler)      # Multiple params
router.get("/api/{version}/resource", handler)         # Version in path
router.get("/files/{path<path>}", handler)            # Greedy capture (file serving)
```

### Request Dictionary Extension

Add `params` field to request dict:

```quest
{
  "method": "GET",
  "path": "/post/hello-world",
  "params": {              # ← NEW
    "slug": "hello-world"
  },
  "query": {
    "page": "1"
  },
  "headers": {...},
  "body": "...",
  # ... (existing fields)
}
```

**Parameter handling**:
- All parameters are **URL-decoded** automatically
  - Example: `/post/hello%20world` → `req["params"]["slug"] = "hello world"`
- By default, parameters are **strings**
- Can be type-converted using type annotations: `{id<int>}`, `{id<uuid>}`, etc. (see Type Checking section below)

### Router Method API

Define routes using router methods:

```quest
use "std/web/middleware/router" as router

router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  return {status: 200, body: f"Post: {slug}"}
end)

router.post("/api/user/{user_id}/comment", fun (req)
  let user_id = req["params"]["user_id"]
  let data = json.parse(req["body"])
  # Create comment...
  return {status: 201, json: {id: comment_id}}
end)
```

**Key design decision**: Router methods only, no decorators. Simple, explicit, functional style.

## Implementation Strategy

### Phase 1: Quest-Side Pattern Matching (Recommended Start)

Implement routing logic in Quest within a new module structure:
- Move existing `std/web.q` → `std/web/index.q`
- Create new `std/web/middleware/router.q` for routing logic

#### Why Quest-First?

1. **No Rust changes**: Can ship immediately
2. **Rapid iteration**: Easy to test and refine API
3. **Full control**: Can add Quest-specific features
4. **Transparent**: Users can inspect/debug routing logic
5. **Validates design**: Proves API before Rust optimization

#### Implementation

**Pattern Parser**:
```quest
# Parse "/post/{slug}" → [{type: "static", value: "post"}, {type: "param", name: "slug"}]
fun parse_pattern(pattern)
  let segments = []
  let parts = pattern.split("/")

  let i = 0
  while i < parts.len()
    let part = parts[i]

    if part == ""
      # Skip empty (leading/trailing slashes)
      i = i + 1
      continue
    elif part.starts_with("{") and part.ends_with("}")
      # Brace syntax: {slug} or {id<int>}
      let param_str = part.substr(1, part.len() - 1)  # Strip { and }
      let param_name = param_str
      let param_type = "str"  # Default type

      # Extract type if present: {id<int>}
      if param_str.contains("<")
        let angle_idx = param_str.index_of("<")
        param_name = param_str.substr(0, angle_idx)
        let type_end = param_str.index_of(">")
        param_type = param_str.substr(angle_idx + 1, type_end)
      end

      segments.push({type: "param", name: param_name, param_type: param_type})
    else
      # Static segment
      segments.push({type: "static", value: part})
    end

    i = i + 1
  end

  return segments
end
```

**Path Matcher**:
```quest
# Match "/post/hello" against parsed pattern → {slug: "hello"} or nil
# Includes URL decoding of captured parameters
fun match_path(segments, req_path)
  let parts = req_path.split("/")
  let params = {}

  let seg_idx = 0
  let part_idx = 0

  while part_idx < parts.len()
    let part = parts[part_idx]

    if part == ""
      part_idx = part_idx + 1
      continue
    end

    if seg_idx >= segments.len()
      return nil  # Too many segments
    end

    let segment = segments[seg_idx]

    if segment["type"] == "static"
      if part != segment["value"]
        return nil  # Mismatch
      end
    elif segment["type"] == "param"
      # URL-decode the captured parameter
      let decoded_value = url_decode(part)

      # Convert to appropriate type if specified
      let converted_value = convert_param(decoded_value, segment["param_type"])

      if converted_value == nil
        # Type validation failed
        return nil
      end

      params[segment["name"]] = converted_value
    end

    seg_idx = seg_idx + 1
    part_idx = part_idx + 1
  end

  if seg_idx != segments.len()
    return nil  # Too few segments
  end

  return params
end

# URL-decode a path segment (e.g., "hello%20world" → "hello world")
fun url_decode(encoded)
  # Built-in URL decoding (implementation in Rust)
  # Handles %XX hex escapes
  return encoded._url_decode()
end
```

**Route Registry & Dispatch** (Global Singleton):
```quest
# std/web/middleware/router.q

type Route
  pattern_segments  # Parsed pattern
  method           # "GET", "POST", etc.
  handler          # Decorated function
  priority         # Lower = higher priority

# Global route registry (singleton)
let ROUTES = []

fun register(method, pattern, handler)
  let segments = parse_pattern(pattern)
  let priority = calculate_priority(segments)  # Static=0, dynamic=1+param_count

  let route = Route._new()
  route.pattern_segments = segments
  route.method = method
  route.handler = handler
  route.priority = priority

  ROUTES.push(route)

  # Sort by priority after each registration
  sort_routes()
end

pub fun dispatch(req, not_found_handler)
  let path = req["path"]
  let method = req["method"]

  let i = 0
  while i < ROUTES.len()
    let route = ROUTES[i]

    if route.method != method
      i = i + 1
      continue
    end

    let params = match_path(route.pattern_segments, path)

    if params != nil
      # Match found!
      req["params"] = params
      return route.handler(req)
    end

    i = i + 1
  end

  # No match
  if not_found_handler != nil
    return not_found_handler(req)
  end

  return nil  # No route matched
end

# Utility for introspection
pub fun get_routes()
  return ROUTES
end

pub fun clear_routes()
  ROUTES = []
end
```

**Default Global Router** (simple apps):
```quest
# std/web/middleware/router.q exports a default router instance

use "std/web/middleware/router" as router

# Register routes on the default router
router.get("/users", fun (req)
  return {status: 200, json: get_all_users()}
end)

router.post("/users", fun (req)
  let data = json.parse(req["body"])
  return {status: 201, json: create_user(data)}
end)
```

**Router Instances** (modular apps, like Express):
```quest
# std/web/middleware/router.q

pub type Router
  routes  # Array of routes for this router instance

  static fun new()
    let router = Router._new()
    router.routes = []
    return router
  end

  # Register routes on this router instance
  pub fun get(pattern, handler)
    let segments = parse_pattern(pattern)
    let priority = calculate_priority(segments)

    let route = Route._new()
    route.pattern_segments = segments
    route.method = "GET"
    route.handler = handler
    route.priority = priority

    self.routes.push(route)
    sort_routes(self.routes)
  end

  pub fun post(pattern, handler)
    # Similar to get()
    # ...
  end

  pub fun put(pattern, handler)
    # ...
  end

  pub fun delete(pattern, handler)
    # ...
  end

  pub fun patch(pattern, handler)
    # ...
  end

  # Dispatch request to routes in this router
  fun _dispatch(req, not_found_handler)
    let path = req["path"]
    let method = req["method"]

    let i = 0
    while i < self.routes.len()
      let route = self.routes[i]

      if route.method != method
        i = i + 1
        continue
      end

      let params = match_path(route.pattern_segments, path)
      if params != nil
        req["params"] = params
        return route.handler(req)
      end

      i = i + 1
    end

    return nil  # No match
  end
end

# Default router instance (exported as module-level functions)
let _default_router = Router.new()

pub fun get(pattern, handler)
  _default_router.get(pattern, handler)
end

pub fun post(pattern, handler)
  _default_router.post(pattern, handler)
end

pub fun put(pattern, handler)
  _default_router.put(pattern, handler)
end

pub fun delete(pattern, handler)
  _default_router.delete(pattern, handler)
end

pub fun patch(pattern, handler)
  _default_router.patch(pattern, handler)
end

# Middleware for default router
pub fun dispatch_middleware(req)
  let response = _default_router._dispatch(req, nil)
  if response != nil
    return response
  end
  return req  # No match, continue chain
end

# Utility functions
pub fun get_routes()
  return _default_router.routes
end

pub fun clear_routes()
  _default_router.routes = []
end
```

**Module-Level API** (default router):
```quest
# std/web/middleware/router.q

# Export module-level functions that use the default router
pub fun get(pattern, handler)
  _default_router.get(pattern, handler)
end

pub fun post(pattern, handler)
  _default_router.post(pattern, handler)
end

# ... put, delete, patch

# Middleware function for dispatching routes (exported for std/web to use)
pub fun dispatch_middleware(req)
  let response = _default_router._dispatch(req, nil)

  if response != nil
    # Route matched - return response to short-circuit
    return response
  end

  # No route matched - continue to next middleware
  return req
end
```

**Router Registration** (manual):
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/users", users_handler)
router.post("/users", create_user_handler)

# MUST explicitly register router middleware
web.use(router.dispatch_middleware)

web.run()
```

**No auto-registration**:
- Define routes with `router.get()` → just registers in router
- **Must call** `web.use(router.dispatch_middleware)` → adds to middleware chain
- Mounted routers via `web.mount()` → already registered as middleware
- No `web.use()` and no `web.mount()` → no routing (static-only mode)

#### Performance Considerations

**Cost per request**:
- **Parse overhead**: Already done at registration time (one-time cost)
- **Match overhead**: O(routes × segments) = O(n × m)
  - For 50 routes with avg 3 segments: ~150 comparisons
  - String comparison is fast in Rust-backed strings
- **Expected latency**: 1-5ms for typical apps (<100 routes)

**When is this acceptable?**
- Most Quest web apps: 10-50 routes (overhead negligible vs DB/network)
- Typical CRUD apps: 15-30 routes → <1ms routing overhead

**When to optimize?**
- Large apps (>100 routes): Consider Phase 2 (Axum integration)
- High-traffic APIs (>1000 req/s): Definitely use Phase 2

### Phase 2: Axum Integration (Future Optimization)

For production apps needing maximum performance, compile Quest patterns to Axum routes.

#### Architecture

**At `web.run()` time**:
1. Extract route patterns from Quest decorators
2. Compile compatible patterns to Axum routes
3. Keep complex patterns (regex, custom logic) in Quest fallback
4. Build hybrid router: Axum (fast path) → Quest (fallback)

#### Rust Implementation Sketch

```rust
// src/server.rs

fn build_router_from_quest(scope: &Scope) -> Router {
    let routes = extract_routes_from_decorators(scope);
    let mut router = Router::new();

    for route in routes {
        if is_axum_compatible(&route.pattern) {
            // Simple pattern: compile to Axum
            let axum_pattern = convert_to_axum_pattern(&route.pattern);  // :slug → :slug (same!)

            let handler = create_axum_handler(route.handler, scope.clone());

            match route.method.as_str() {
                "GET" => router = router.route(&axum_pattern, get(handler)),
                "POST" => router = router.route(&axum_pattern, post(handler)),
                // ...
                _ => {}
            }
        }
    }

    // Add Quest router as fallback for complex patterns
    router = router.fallback(quest_router_fallback);

    router
}

async fn create_axum_handler(
    quest_handler: QValue,
    scope: Arc<Scope>,
) -> impl IntoResponse {
    move |Path(params): Path<HashMap<String, String>>, req: Request| {
        // Convert Axum params to Quest dict
        let params_qvalue = hashmap_to_qdict(params);

        // Build Quest request dict
        let mut request_dict = http_request_to_dict_sync(req)?;
        request_dict.insert("params", params_qvalue);

        // Call Quest handler
        call_quest_function(quest_handler, request_dict, scope)
    }
}
```

#### Benefits of Hybrid Approach

1. **Transparent optimization**: No API changes, just faster
2. **Best of both**: Axum speed + Quest flexibility
3. **Gradual migration**: Add Rust support route-by-route
4. **Future-proof**: Can add Quest-only features (regex, type validation)

## Breaking Changes

**Removed**:
- Decorators (`@Get`, `@Post`, `@Put`, `@Delete`, `@Patch`)
- `match_type` parameter (prefix matching removed)

**New approach** (router methods):
```quest
router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  # ...
end)
```

## API Reference

### Pattern Syntax Examples

| Pattern | Request Path | `req["params"]` | Notes |
|---------|-------------|-----------------|-------|
| `/post/{slug}` | `/post/hello` | `{slug: "hello"}` (Str) | ✅ Matches |
| `/post/{slug}` | `/post/hello/comments` | - | ❌ Too many segments |
| `/post/{slug}` | `/post/` | - | ❌ Missing parameter |
| `/post/{slug}` | `/post/hello%20world` | `{slug: "hello world"}` | ✅ URL-decoded |
| `/user/{id}` | `/user/123` | `{id: "123"}` (Str) | ✅ Default is string |
| `/user/{id<int>}` | `/user/123` | `{id: 123}` (Int) | ✅ Type-converted |
| `/user/{id<int>}` | `/user/abc` | - | ❌ Type validation failed |
| `/user/{id<uuid>}` | `/user/550e8400-...` | `{id: Uuid(...)}` | ✅ UUID object |
| `/api/{version}/{resource}` | `/api/v1/users` | `{version: "v1", resource: "users"}` | ✅ Multiple params |
| `/files/{path<path>}` | `/files/a/b/c.txt` | `{path: "a/b/c.txt"}` | ✅ Greedy capture |
| `/files/{path<path>}` | `/files/single.txt` | `{path: "single.txt"}` | ✅ Single file |
| `/api/{version}/docs/{path<path>}` | `/api/v1/docs/guide/intro.html` | `{version: "v1", path: "guide/intro.html"}` | ✅ Mixed params |

### Router Method API

```quest
use "std/web/middleware/router" as router

# Single parameter
router.get("/post/{slug}", fun (req)
  let slug = req["params"]["slug"]
  # ...
end)

# Multiple parameters
router.get("/user/{user_id}/posts/{post_id}", fun (req)
  let user_id = req["params"]["user_id"]
  let post_id = req["params"]["post_id"]
  # ...
end)

# Exact match (no params)
router.get("/admin", fun (req)
  # No params extracted
end)

# Type-checked parameters
router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Int, not Str
  # ...
end)

router.get("/post/{id<uuid>}", fun (req)
  let id = req["params"]["id"]  # Uuid object
  # ...
end)

# All HTTP methods
router.get("/resource", handler)
router.post("/resource", handler)
router.put("/resource/{id}", handler)
router.patch("/resource/{id}", handler)
router.delete("/resource/{id}", handler)
```

### Route Matching Examples

**Example 1: Request `/post/popular`**

With these two routes registered in order:
```quest
router.get("/post/popular", fun (req)
  # ✅ Matches (static route)
  return {status: 200, body: "Popular post"}
end)

router.get("/post/{slug}", fun (req)
  # Won't match this one (first route matched)
  return {status: 200, body: f"Post: {req["params"]["slug"]}"}
end)
```

Result: First route matches, second route not evaluated.

**Example 2: Request `/post/hello-world`**

Same routes:
```quest
router.get("/post/popular", fun (req)
  # ❌ Doesn't match (hello-world ≠ popular)
  return {status: 200, body: "Popular post"}
end)

router.get("/post/{slug}", fun (req)
  # ✅ Matches (slug = "hello-world")
  return {status: 200, body: f"Post: {req["params"]["slug"]}"}
end)
```

Result: First route doesn't match, second route matches and handles request.

## Testing Strategy

### Unit Tests

```quest
use "std/test" as test
use "std/web/middleware/router" as router

test.describe("Pattern Parsing", fun ()
  test.it("parses static segments", fun ()
    let pattern = router.parse_pattern("/post/list")
    test.assert_eq(pattern.len(), 2)
    test.assert_eq(pattern[0]["type"], "static")
    test.assert_eq(pattern[0]["value"], "post")
  end)

  test.it("parses brace parameters", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    test.assert_eq(pattern[1]["type"], "param")
    test.assert_eq(pattern[1]["name"], "slug")
  end)

  test.it("parses multiple parameters", fun ()
    let pattern = router.parse_pattern("/user/{id}/posts/{post}")
    test.assert_eq(pattern.len(), 4)
    test.assert_eq(pattern[1]["name"], "id")
    test.assert_eq(pattern[3]["name"], "post")
  end)

  test.it("parses type annotations", fun ()
    let pattern = router.parse_pattern("/user/{id<int>}")
    test.assert_eq(pattern[1]["type"], "param")
    test.assert_eq(pattern[1]["name"], "id")
    test.assert_eq(pattern[1]["param_type"], "int")
  end)
end)

test.describe("Path Matching", fun ()
  test.it("matches exact patterns", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello")
    test.assert_not_nil(params)
    test.assert_eq(params["slug"], "hello")
  end)

  test.it("rejects mismatched paths", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/user/hello")
    test.assert_nil(params)
  end)

  test.it("rejects paths with extra segments", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello/comments")
    test.assert_nil(params)
  end)

  test.it("rejects paths with missing segments", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/")
    test.assert_nil(params)
  end)

  test.it("captures path parameters (greedy)", fun ()
    let pattern = router.parse_pattern("/files/{path<path>}")
    let params = router.match_path(pattern, "/files/docs/guide/intro.md")
    test.assert_not_nil(params)
    test.assert_eq(params["path"], "docs/guide/intro.md")
  end)

  test.it("URL-decodes parameters", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello%20world")
    test.assert_not_nil(params)
    test.assert_eq(params["slug"], "hello world")
  end)

  test.it("rejects path type in middle of pattern", fun ()
    try
      router.parse_pattern("/files/{path<path>}/metadata")
      test.assert(false, "Should have raised error")
    catch e: ValueErr
      test.assert(true)
    end
  end)
end)

test.describe("Route Matching", fun ()
  test.it("matches first route that fits pattern", fun ()
    router.clear_routes()

    let matched = nil

    router.get("/post/popular", fun (req)
      matched = "static"
      return {status: 200}
    end)

    router.get("/post/{slug}", fun (req)
      matched = "dynamic"
      return {status: 200}
    end)

    let req = {method: "GET", path: "/post/popular"}
    let resp = router.dispatch(req, nil)

    test.assert_eq(matched, "static")
  end)
end)
```

### Integration Tests

```quest
test.describe("Router Integration", fun ()
  test.it("injects params into request", fun ()
    router.clear_routes()

    let received_slug = nil

    router.get("/post/{slug}", fun (req)
      received_slug = req["params"]["slug"]
      return {status: 200, body: "OK"}
    end)

    let req = {method: "GET", path: "/post/test-post"}
    let resp = router.dispatch(req, nil)

    test.assert_eq(received_slug, "test-post")
    test.assert_eq(resp["status"], 200)
  end)
end)
```

### Manual Testing

```bash
# Create a simple test server
quest test_router.q

# Test pattern routes
curl http://localhost:3000/post/hello-world
curl http://localhost:3000/user/123
curl http://localhost:3000/files/docs/readme.txt

# Should all extract parameters correctly
```

## Implementation Checklist

### Phase 1: Basic Pattern Matching & Router API

- [ ] Create `std/web/middleware/router.q` module
- [ ] Create `parse_pattern()` function (with type annotation support)
- [ ] Create `match_path()` function
- [ ] Implement URL decoding for parameters
- [ ] Implement `convert_param()` for type conversion
- [ ] Add `priority` calculation
- [ ] Implement `Route` type with priority
- [ ] Implement route sorting by priority
- [ ] Implement `Router` type with instance methods (`get`, `post`, `put`, `delete`, `patch`)
- [ ] Implement `Router._dispatch(req)` method
- [ ] Create default router instance `_default_router`
- [ ] Export module-level functions (`get`, `post`, etc.) that use default router
- [ ] Implement `dispatch_middleware()` for QEP-061 integration
- [ ] Implement `get_routes()` and `clear_routes()` utilities
- [ ] Write unit tests for pattern matching (20+ test cases)
- [ ] Write tests for URL decoding (5+ test cases)
- [ ] Write tests for type conversion (10+ test cases)
- [ ] Write tests for router instances (10+ test cases)
- [ ] Update documentation

### Phase 2: Mounted Routers

- [ ] Implement `web.mount(base_path, router)` in `std/web/index.q`
- [ ] Add path stripping logic for mounted routers
- [ ] Add `get_mounted_routers()` for introspection
- [ ] Write tests for mounted routers with base paths
- [ ] Test middleware ordering (mounted vs default router)
- [ ] Document router instance API and mounting

### Phase 3: Polish & Edge Cases

- [ ] Handle trailing slashes (configurable)
- [ ] Handle empty path segments
- [ ] Error handling (duplicate routes, invalid patterns)
- [ ] Route introspection (`get_routes()`, `print_routes()`)
- [ ] Better error messages for type validation failures
- [ ] Add `path` type for wildcard file serving
- [ ] Performance testing (100+ routes)

### Phase 4: Axum Integration (Future)

- [ ] Detect Axum-compatible patterns
- [ ] Implement `convert_to_axum_pattern()`
- [ ] Build hybrid router (Axum + Quest fallback)
- [ ] Extract params from Axum `Path<HashMap<>>`
- [ ] Benchmark: Quest vs Axum vs Hybrid
- [ ] Documentation on when to use each

## Performance Benchmarks

### Expected Performance (Phase 1)

**Small app (10 routes)**:
- Routing overhead: <0.5ms per request
- Total latency: 1-5ms (including Quest handler)

**Medium app (50 routes)**:
- Routing overhead: 1-2ms per request
- Total latency: 5-10ms

**Large app (200 routes)**:
- Routing overhead: 5-10ms per request
- Total latency: 10-20ms

**Acceptable for**:
- Internal tools
- Content management systems
- Admin dashboards
- Most Quest web apps

### Phase 2 Performance (Axum)

**Any app size**:
- Routing overhead: <0.1ms (negligible)
- Axum radix tree: O(log n) lookups

**Use when**:
- High-traffic public APIs (>1000 req/s)
- Microservices
- Real-time applications
- >100 routes

## Type Checking on Route Parameters

### Syntax

Use angle brackets to specify parameter types in braces: `{param<type>}`

```quest
router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Already parsed as Int
  # ...
end)

router.get("/post/{id<uuid>}", fun (req)
  let id = req["params"]["id"]  # Already parsed as Uuid
  # ...
end)
```

### Supported Types

| Type | Example | Validation | Conversion |
|------|---------|------------|------------|
| `int` | `{id<int>}` | Must be valid integer | `"123"` → `123` (Int) |
| `float` | `{price<float>}` | Must be valid float | `"3.14"` → `3.14` (Float) |
| `uuid` | `{id<uuid>}` | Must be valid UUID v4 | `"550e8400-..."` → Uuid object |
| `str` | `{slug<str>}` | Any string (default) | No conversion (returns decoded string) |
| `path` | `{file<path>}` | Captures rest of path (greedy) | `"a/b/c"` → `"a/b/c"` |

### Implementation

**Parser Extension**:
```quest
fun parse_pattern(pattern)
  let segments = []
  let parts = pattern.split("/")

  let i = 0
  while i < parts.len()
    let part = parts[i]

    if part == ""
      # Skip empty segments (leading/trailing slashes)
      i = i + 1
      continue
    elif part.starts_with("{") and part.ends_with("}")
      # Parse {name<type>} or {name}
      # Only brace syntax is supported (no colon syntax)
      let param_str = part.substr(1, part.len() - 1)  # Strip { and }
      let param_name = param_str
      let param_type = "str"  # Default type

      # Extract type annotation if present: {id<int>}
      if param_str.contains("<")
        let angle_idx = param_str.index_of("<")
        param_name = param_str.substr(0, angle_idx)
        let type_end = param_str.index_of(">")
        param_type = param_str.substr(angle_idx + 1, type_end)
      end

      segments.push({
        type: "param",
        name: param_name,
        param_type: param_type
      })

      # Validate: path type must be last segment
      if param_type == "path"
        # Check if there are more non-empty segments after this
        let j = i + 1
        while j < parts.len()
          if parts[j] != ""
            raise ValueErr.new("path type parameter must be last segment in pattern")
          end
          j = j + 1
        end
      end
    else
      # Static segment
      segments.push({type: "static", value: part})
    end

    i = i + 1
  end

  return segments
end
```

**Type Conversion in Matcher**:
```quest
fun match_path(segments, req_path)
  let parts = req_path.split("/")
  let params = {}

  let seg_idx = 0
  let part_idx = 0

  while part_idx < parts.len()
    let part = parts[part_idx]

    if part == ""
      part_idx = part_idx + 1
      continue
    end

    if seg_idx >= segments.len()
      return nil  # Too many segments
    end

    let segment = segments[seg_idx]

    if segment["type"] == "static"
      if part != segment["value"]
        return nil  # Mismatch
      end
    elif segment["type"] == "param"
      # Check if this is a path type (greedy capture)
      if segment["param_type"] == "path"
        # Capture all remaining segments
        let remaining_parts = []
        while part_idx < parts.len()
          if parts[part_idx] != ""
            remaining_parts.push(parts[part_idx])
          end
          part_idx = part_idx + 1
        end

        # Join with / to reconstruct path, then URL-decode
        let path_value = remaining_parts.join("/")
        path_value = url_decode(path_value)
        params[segment["name"]] = path_value

        # Must be last segment
        seg_idx = seg_idx + 1
        break  # Done matching
      else
        # Regular parameter - single segment
        # URL-decode the segment
        let decoded_value = url_decode(part)

        # Convert based on param_type
        let converted_value = convert_param(decoded_value, segment["param_type"])

        if converted_value == nil
          # Type validation failed
          return nil
        end

        params[segment["name"]] = converted_value
      end
    end

    seg_idx = seg_idx + 1
    part_idx = part_idx + 1
  end

  if seg_idx != segments.len()
    return nil  # Too few segments
  end

  return params
end

# URL-decode a path segment (e.g., "hello%20world" → "hello world")
fun url_decode(encoded)
  # Built-in URL decoding (implementation in Rust)
  # Handles %XX hex escapes, returns decoded string
  return encoded._url_decode()
end

fun convert_param(value, param_type)
  if param_type == "str"
    return value  # Return decoded string as-is
  elif param_type == "int"
    try
      return value.to_int()
    catch
      return nil  # Invalid int
    end
  elif param_type == "float"
    try
      return value.to_float()
    catch
      return nil  # Invalid float
    end
  elif param_type == "uuid"
    try
      return uuid.parse(value)
    catch
      return nil  # Invalid UUID
    end
  elif param_type == "path"
    # Special handling - captures rest of path (already decoded in match_path)
    return value
  else
    # Unknown type, treat as string
    return value
  end
end
```

### Type Conversion Failures

When a URL parameter doesn't parse as the specified type, the route **doesn't match** and routing continues.

**Behavior**:
- ✅ `GET /user/123` → Matches (id = 123 as Int)
- ❌ `GET /user/abc` → **Doesn't match** (not a valid int) → 404 or next route

**Example with type-specific and fallback routes**:
```quest
# Specific route (requires int)
router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Int
  return {status: 200, json: get_user(id)}
end)

# Fallback route (accepts any string)
router.get("/user/{name}", fun (req)
  let name = req["params"]["name"]  # String
  return {status: 200, json: search_user_by_name(name)}
end)

# GET /user/123    → First route matches (123 is valid int)
# GET /user/alice  → First route doesn't match, falls through to second route
```

**Error Responses** (no built-in type error response):

Option 1: Add catch-all 404 handler after all routes
```quest
router.get("/user/{id<int>}", users_by_id)

# Matches /user/123, doesn't match /user/abc
# /user/abc continues to next middleware or 404
```

Option 2: Use less strict types, validate in handler
```quest
router.get("/user/{id}", fun (req)
  let id_str = req["params"]["id"]

  try
    let id = id_str.to_int()
    return get_user(id)
  catch
    return {status: 400, json: {error: "Invalid user ID"}}
  end
end)
```

Option 3: Type-based routing (most elegant)
```quest
router.get("/post/{id<int>}", posts_by_id)        # /post/123
router.get("/post/{slug}", posts_by_slug)         # /post/hello-world
# Type validation prevents conflicts
```

### Examples

**Integer ID validation**:
```quest
router.get("/user/{id<int>}", fun (req)
  let id = req["params"]["id"]  # Int, not Str
  # id.cls() == "Int"

  let user = db.execute("SELECT * FROM users WHERE id = ?", [id])
  return {status: 200, json: user}
end)

# GET /user/123     → ✅ Matches, id = 123 (Int)
# GET /user/abc     → ❌ No match (type validation failed)
# GET /user/12.5    → ❌ No match (not an int)
```

**UUID validation**:
```quest
use "std/uuid" as uuid

router.get("/post/{id<uuid>}", fun (req)
  let id = req["params"]["id"]  # Uuid object

  let post = db.execute("SELECT * FROM posts WHERE id = ?", [id])
  return {status: 200, json: post}
end)

# GET /post/550e8400-e29b-41d4-a716-446655440000  → ✅ Matches
# GET /post/not-a-uuid                            → ❌ No match (invalid UUID)
```

**Path parameter (file serving)**:
```quest
use "std/io" as io

router.get("/files/{path<path>}", fun (req)
  let file_path = req["params"]["path"]  # Captures everything after /files/

  # GET /files/docs/readme.txt     → path = "docs/readme.txt"
  # GET /files/a/b/c/image.png     → path = "a/b/c/image.png"
  # GET /files/single.txt          → path = "single.txt"

  return {status: 200, body: io.read(file_path)}
end)
```

**Important**: `path` type must be the **last segment** in the pattern (it's greedy and captures everything remaining).

**Mixed types**:
```quest
router.get("/api/{version<int>}/user/{id<uuid>}", fun (req)
  let version = req["params"]["version"]  # Int
  let user_id = req["params"]["id"]      # Uuid

  if version == 1
    return handle_v1(user_id)
  else
    return handle_v2(user_id)
  end
end)
```

### The `path` Type (Greedy Capture)

The `path` type is **special** - it captures **all remaining path segments**, including slashes. This makes it perfect for file serving and nested resource paths.

**How it works**:
1. When matcher encounters `:name<path>`, it stops normal segment-by-segment matching
2. Collects all remaining path segments
3. Joins them with `/` to reconstruct the full path
4. Must be the **last parameter** in the pattern (greedy = consumes everything)

**Valid patterns**:
```quest
router.get("/files/{path<path>}", handler)              # ✅ Last segment
router.get("/api/{version}/docs/{path<path>}", handler) # ✅ Last segment after version
```

**Invalid patterns**:
```quest
router.get("/files/{path<path>}/metadata", handler) # ❌ Can't have segments after path type
router.get("/{path<path>}/{other<path>}", handler)  # ❌ Can't have multiple path types
```

**Example with validation**:
```quest
use "std/io" as io

router.get("/files/{path<path>}", fun (req)
  let file_path = req["params"]["path"]  # e.g., "docs/guide/intro.md"

  # Security: validate path doesn't escape directory
  if file_path.contains("..")
    return {status: 403, body: "Forbidden"}
  end

  # Construct full path
  let full_path = "./public/" .. file_path

  if not io.exists(full_path)
    return {status: 404, body: "File not found"}
  end

  return {status: 200, body: io.read(full_path)}
end)

# GET /files/docs/readme.txt        → path = "docs/readme.txt"
# GET /files/images/logo.png        → path = "images/logo.png"
# GET /files/a/b/c/d/deep/file.txt  → path = "a/b/c/d/deep/file.txt"
```

### Type Safety Benefits

1. **Automatic validation**: Invalid types return 404/400 automatically
2. **Less boilerplate**: No need for manual `to_int()` calls
3. **Self-documenting**: Route signature shows expected types
4. **Database safety**: Typed params prevent SQL type mismatches
5. **Error prevention**: Can't accidentally use string as int
6. **Path safety**: `path` type enables secure file serving with validation

### Performance

**Type conversion overhead**:
- `int`: `value.to_int()` → ~100ns per conversion
- `float`: `value.to_float()` → ~100ns
- `uuid`: `uuid.parse()` → ~500ns (parses hex, validates)
- Negligible compared to database/network (~1-100ms)

## Future Enhancements (Post-MVP)

### Regex Constraints
```quest
router.get("/post/{slug<str:[a-z0-9-]+>}", fun (req)
  # Slug validated against regex
end)
```

### Optional Parameters
```quest
router.get("/posts/{page?}", fun (req)
  let page = req["params"]["page"] or "1"
  # ...
end)
```

### Multiple Routes to Same Handler
```quest
# Same handler, multiple paths
let view_item = fun (req)
  let slug = req["params"]["slug"]
  # ...
end

router.get("/item/{slug}", view_item)
router.get("/content/{slug}", view_item)
```

### Custom User Types (Future Enhancement)

**Note**: This is a potential future improvement, not part of the MVP.

Allow users to define custom type converters for route parameters:

```quest
# Future syntax (not implemented)
router.register_type("username", fun (value)
  # Validate username format
  if not value.matches("^[a-zA-Z0-9_-]{3,20}$")
    return nil  # Invalid
  end
  return value
end)

router.get("/user/{name<username>}", fun (req)
  let username = req["params"]["name"]  # Already validated
  # ...
end)
```

This would enable:
- Custom validation logic (email, phone, slug formats)
- Database lookups (convert ID to object: `:id<user>` → User object)
- Domain-specific types (`:coords<gps>`, `:color<hex>`)
- Reusable validation across routes

**Implementation considerations**:
- Registry of custom type converters
- Error handling for validation failures
- Performance impact of custom validation
- Integration with existing built-in types

This feature could be explored in a future QEP once the basic type system is proven in production.

## Common Pitfalls and Best Practices

### Pitfall: Forgetting to Register Router Middleware

**Problem**:
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/api/users", fun (req)
  return {status: 200, json: get_all_users()}
end)

# Forgot to register router middleware!
web.run()

# GET /api/users → 404
```

**Why this happens**:
- `router.get()` registers route in router's routes array
- But router middleware is NOT added to middleware chain
- Without `web.use(router.dispatch_middleware)`, router never runs
- All dynamic requests → 404

**Solution**:
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/api/users", fun (req)
  return {status: 200, json: get_all_users()}
end)

# MUST explicitly register router middleware
web.use(router.dispatch_middleware)

web.run()
```

### Pitfall: Mixing Default and Mounted Routers

**Problem**:
```quest
use "std/web" as web
use "std/web/middleware/router" as router {Router}

# Define routes on default router
router.get("/api/users", users_handler)

# Mount a router instance at same path
let api_router = Router.new()
api_router.get("/users", users_handler)
web.mount("/api", api_router)

# Register default router
web.use(router.dispatch_middleware)

web.run()

# GET /api/users → which router handles it?
```

**Why this is confusing**:
- Middleware runs in registration order
- Mounted router middleware registered first (by `web.mount()`)
- Default router middleware registered second (by `web.use()`)
- Request goes to mounted router first
- If mounted router matches `/users`, it short-circuits
- Default router never gets a chance at `/api/users`

**Solutions**:

1. **Use one routing style consistently**:
```quest
# Option A: Default router only
router.get("/api/users", users_handler)
web.use(router.dispatch_middleware)
web.run()
```

```quest
# Option B: Router instances only
let api_router = Router.new()
api_router.get("/users", users_handler)
web.mount("/api", api_router)
web.run()
```

2. **Mix carefully** (be explicit about order):
```quest
# Default router for root paths
router.get("/", home_handler)
router.get("/about", about_handler)

# Register default router FIRST
web.use(router.dispatch_middleware)

# Mounted routers for sub-paths (registered after)
let api_router = Router.new()
api_router.get("/users", users_handler)
web.mount("/api", api_router)

web.run()
# GET /        → default router
# GET /about   → default router
# GET /api/users → mounted router (no conflict)
```

### Best Practice: Explicit Router Registration

For clarity, you can explicitly register the router:

```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/api/users", fun (req)
  # ...
end)

# Explicitly register router
web.use(router.dispatch_middleware)

web.run()
```

## Decided Questions

1. ~~**Should we support both `:param` and `{param}` syntax?**~~
   - **✅ Decided**: Use only `{param}` syntax (clearer, matches OpenAPI/FastAPI/Axum)
   - Colon syntax `:param` is **not supported**

2. ~~**Should params be URL-decoded?**~~
   - **✅ Decided**: YES, always URL-decode (standard web behavior)
   - Example: `/post/hello%20world` → `{slug: "hello world"}`

3. ~~**Should router middleware be auto-registered?**~~
   - **✅ Decided**: NO, explicit registration only
   - Users must call `web.use(router.dispatch_middleware)` manually
   - This makes middleware chain visible and explicit

## Open Questions

1. **How to handle trailing slashes?**
   - Should `/post` match `/post/`?
   - **Recommendation**: Normalize by default (`/post` = `/post/`), add `strict_trailing_slash` config

2. **What if pattern has duplicate param names?**
   - Example: `/post/{id}/edit/{id}` (invalid)
   - **Recommendation**: Error during registration

3. **How to handle conflicting routes?**
   - Example: `/post/{slug}` and `/post/{id}` (both match same paths, type checking helps distinguish)
   - **Recommendation**: First match wins (specificity-based priority)

## Success Criteria

- ✅ Patterns like `/post/{slug}` automatically extract params
- ✅ Parameters are URL-decoded automatically (e.g., `%20` → space)
- ✅ Router method API (`router.get()`, `router.post()`, etc.)
- ✅ Decorators removed (`@Get`, `@Post` no longer used)
- ✅ Explicit router registration (`web.use(router.dispatch_middleware)`)
- ✅ Router is NOT auto-registered (user must explicitly call `web.use()`)
- ✅ Static routes take priority over dynamic routes
- ✅ Only brace syntax `{param}` supported (no colon syntax)
- ✅ Type checking for route parameters (`{id<int>}`, `{id<uuid>}`)
- ✅ Router instances for modular apps (`Router.new()`)
- ✅ Mounting routers at base paths (`web.mount("/api", router)`)
- ✅ Performance acceptable (<5ms overhead for <100 routes)
- ✅ Test coverage >90%
- ✅ Documentation with examples

## Timeline

- **Week 1**: Phase 1 implementation (Quest-side routing)
- **Week 2**: Testing, documentation, and edge case handling
- **Week 3**: Polish and performance tuning
- **Future**: Phase 2 (Axum integration) when needed


## Middleware Integration Details

### How Router Registers as Middleware

The router provides a `dispatch_middleware()` function that `std/web` automatically registers:

```quest
# std/web/middleware/router.q

# Router just provides the middleware function
pub fun dispatch_middleware(req)
  # Try to dispatch to a registered route
  let response = dispatch(req, nil)

  if response != nil
    # Route matched - short-circuit (return response)
    return response
  end

  # No route matched - continue to next middleware
  return req
end
```

```quest
# std/web.q

# std/web automatically registers the router middleware if routes exist
fun _init_default_middlewares()
  use "std/web/middleware/router" as router

  # Only register if global router has routes
  if router.get_routes().len() > 0
    use(router.dispatch_middleware)
  end
end
```

**Key insight**: Clean separation of concerns:

```
┌─────────────────────────────────────────┐
│ Application Code                        │
│                                         │
│  router.get("/post/{slug}", handler)    │
│  router.post("/post", create_handler)   │
│                                         │
│  ↓ (registering routes in router)      │
│                                         │
│  _default_router.routes = [{            │
│    pattern: "/post/{slug}",             │
│    handler: handler_fn                  │
│  }, ...]                                │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ std/web/middleware/router.q                        │
│                                         │
│  pub fun dispatch_middleware(req)       │
│    # Look up route in _default_router   │
│    # Match pattern                      │
│    # Call handler                       │
│  end                                    │
└─────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────┐
│ std/web/index.q                         │
│                                         │
│  # User explicitly registers middleware │
│  web.use(router.dispatch_middleware)    │
│                                         │
└─────────────────────────────────────────┘
```

**Key design points**:
1. **Router methods** (`router.get()`, `router.post()`) → Register routes explicitly
2. **Router middleware** (`dispatch_middleware`) → Pattern matching + dispatch logic
3. **`std/web`** → Orchestrates middleware chain (user controls order)

**Benefits**:
- Explicit registration (no magic)
- Clear middleware chain control
- Users can replace router entirely
- Testable: Each layer can be tested independently

**Important**: Router middleware must be explicitly registered:
```quest
use "std/web" as web
use "std/web/middleware/router" as router

# Define routes
router.get("/api/users", handler)

# MUST explicitly register middleware
web.use(router.dispatch_middleware)

web.run()

# Without web.use(): GET /api/users → 404 (router never runs)
```

### Execution Flow

**With default router**:
```
Request
  ↓
web.use middlewares (logging, auth, etc.)
  ↓
router.dispatch_middleware ← Checks for route match
  ↓
  Match found? → Return response (short-circuit)
  No match?    → Return req (continue chain)
  ↓
Static file serving (Axum ServeDir)
  ↓
  File found? → Return file response
  No file?    → Continue
  ↓
404 (no handler matched, no static file found)
```

**Without router** (disabled or not registered):
```
Request
  ↓
web.use middlewares (logging, auth, etc.)
  ↓
Static file serving (Axum ServeDir)
  ↓
  File found? → Return file response
  No file?    → Continue
  ↓
404 (no router, no static file found)
```

**With custom router**:
```quest
use "std/web" as web

# Disable default router
web.disable_default_router()

# Register custom router as middleware
web.use(fun (req)
  if req["path"].starts_with("/api/")
    # Custom API routing logic
    return my_api_router(req)
  end
  return req  # Pass through for other routes
end)
```

### API for Custom Routers

```quest
# Disable the automatic router middleware
web.disable_default_router()

# Or set a custom router
web.set_router(custom_router_fn)
```

**Implementation in `std/web.q`**:
```quest
let _mounted_routers = []  # Array of {base_path, router} objects

# Mount a router instance at a base path (Express-style)
pub fun mount(base_path, router_instance)
  # Create middleware that strips base path and dispatches to router
  let middleware_fn = fun (req)
    let path = req["path"]

    # Check if path starts with base_path
    if path.starts_with(base_path)
      # Strip base path and dispatch to router
      let original_path = path
      req["path"] = path.replace(base_path, "")

      # Ensure path starts with /
      if req["path"] == "" or not req["path"].starts_with("/")
        req["path"] = "/" .. req["path"]
      end

      # Try to dispatch to mounted router
      let response = router_instance._dispatch(req, nil)

      # Restore original path
      req["path"] = original_path

      if response != nil
        return response  # Route matched
      end
    end

    return req  # No match, continue chain
  end

  # Register as middleware
  use(middleware_fn)

  # Track mounted routers for introspection
  _mounted_routers.push({
    base_path: base_path,
    router: router_instance
  })
end

# Called during web.run() to register default middleware
fun _init_default_middlewares()
  use "std/web/middleware/router" as router

  # Only register global router if it has routes
  if router.get_routes().len() > 0
    use(router.dispatch_middleware)
  end

  # Mounted routers already registered via web.mount()
end

# Get list of mounted routers
pub fun get_mounted_routers()
  return _mounted_routers
end
```

## Module Structure

After implementation, Quest's web module will be organized as:
```
std/web/
  ├── index.q      # Main web framework (moved from std/web.q)
  └── router.q     # Route pattern matching and dispatching
```

Both modules will be accessible via:
```quest
use "std/web" as web           # Imports std/web/index.q
use "std/web/middleware/router" as router # Imports std/web/middleware/router.q
```

## References

- **QEP-061**: Web Server Middleware System (routing as middleware)
- QEP-051: Web Framework API
- QEP-060: Application-Centric Web Server Architecture
- QEP-003: Function Decorators
- Axum routing: https://docs.rs/axum/latest/axum/routing/
- Flask routing: https://flask.palletsprojects.com/en/stable/quickstart/#routing
- Express routing: https://expressjs.com/en/guide/routing.html
