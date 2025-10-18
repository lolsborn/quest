# QEP-063 Design Summary: Universal Request/Response Types

## What Was Created

Two comprehensive specification documents for a redesign of Quest's web request/response system:

1. **specs/qep-063-universal-request-response-types.md** (33KB)
   - Full specification with rationale, design decisions, examples
   - Response trait + specialized response type classes
   - Factory methods for common HTTP status codes
   - Migration path from Dict API

2. **specs/qep-063-architecture.md** (11KB)
   - Visual architecture overview
   - Type hierarchy diagrams
   - Module structure
   - Implementation phases
   - Conversion layers (HTTP ↔ Quest types)

## Key Architecture

### Request Type
```quest
type Request
  method: Str
  path: Str
  version: Str
  client_ip: Str
  headers: Dict
  body: Str?
  query: Dict
  query_string: Str?
  params: Dict?  # Populated by router
  context: Dict?  # For middleware state
  content_type: Str?
  user_agent: Str?
  referer: Str?

  # Methods: method_is(), is_json(), get_header(), get_param(), etc.
end
```

### Response Trait + Semantic Response Types
```quest
trait HttpResponse
  get_status() -> Int
  get_headers() -> Dict
  get_body() -> Str?
  set_header(name, value) -> Self
  set_body(content) -> Self
  redirect(location, permanent) -> Self
  to_dict() -> Dict
end

# Specialized implementations with domain-specific fields:
OkResponse(200)
CreatedResponse(201) - includes Location header, JSON
BadRequestResponse(400) - includes details for validation errors
UnauthorizedResponse(401) - includes WWW-Authenticate challenge
ForbiddenResponse(403)
NotFoundResponse(404) - includes requested path for logging
ConflictResponse(409) - includes conflicting_resource reference
InternalErrorResponse(500) - includes unique error_id for correlation
ServiceUnavailableResponse(503) - includes Retry-After header
```

### Factory Methods
```quest
Response.ok(body)
Response.created(json, location)
Response.bad_request(message, details)
Response.unauthorized(message, challenge)
Response.forbidden(message)
Response.not_found(message, path)
Response.conflict(message, conflicting_resource)
Response.internal_error(message, error_id)
Response.service_unavailable(message, retry_after)
Response.with_status(status, body)
Response.json(data, status)
```

## Design Highlights

### 1. Factory Methods (as you requested!)
- Instead of generic `Response.new(status: 404)`, use `Response.not_found()`
- Type system prevents wrong status codes (can't call `ok()` and get 404)
- IDE autocomplete shows all available response types
- Self-documenting: `Response.unauthorized()` is clearer than `{status: 401}`

### 2. Semantic Response Types
- Each status code has its own type with relevant fields
- `NotFoundResponse` includes path field for logging
- `UnauthorizedResponse` includes WWW-Authenticate challenge
- `ConflictResponse` includes conflicting_resource reference
- `InternalErrorResponse` includes unique error_id for client-server correlation

### 3. Trait-Based Design
- `HttpResponse` trait defines common interface
- All response types implement the trait
- Middleware can work with any response type
- Easy to extend with custom response types

### 4. Request Context for Middleware
- `req.context` is shared dict for middleware to store state
- Auth middleware: `req.context["user"] = user_obj`
- Handler accesses: `let user = req.context["user"]`
- No magic strings or hidden state

### 5. Complete Replacement (Not Gradual Migration)
- Dict-based API is completely replaced
- Cleaner codebase, no legacy code to maintain
- Breaking change, but benefits are worth it
- Simpler code in most cases (routing + factories)

## Import Semantics

Types are exported from `std/web`, so they're accessed via the module namespace unless explicitly imported:

```quest
# Option 1: Use qualified names (web.Request, web.Response)
use "std/web" as web

router.get("/", fun (req: web.Request)
  return web.Response.ok("Hello!")
end)
```

```quest
# Option 2: Use selective import (cleaner)
use "std/web" {Request, Response}
use "std/web/middleware/router" as router

router.get("/", fun (req: Request)
  return Response.ok("Hello!")
end)
```

## Examples

### Simple Handler
```quest
use "std/web" {Request, Response}
use "std/web/middleware/router" as router

router.get("/", fun (req: Request)
  return Response.ok("Hello!")
end)
```

### Error Handling
```quest
use "std/web" {Request, Response}
use "std/web/middleware/router" as router

router.get("/post/{id<int>}", fun (req: Request)
  let post = db.find(req.get_param("id"))

  if post == nil
    return Response.not_found("Post not found", path: req.path)
  end

  return Response.json(post)
end)
```

### Authentication Middleware
```quest
use "std/web" {Request, Response}

fun require_auth(req: Request) -> Request | Response
  let token = req.get_header("Authorization")

  if token == nil
    return Response.unauthorized("Bearer token required", challenge: "Bearer")
  end

  let user = verify_token(token)
  if user == nil
    return Response.unauthorized()
  end

  req.context = req.context or {}
  req.context["user"] = user

  return req  # Continue to next middleware
end
```

## Benefits vs Current Dict API

| Aspect | Dict | Typed |
|--------|------|-------|
| **Type checking** | None | Full IDE support |
| **Response semantics** | All dicts | Semantic types |
| **Error responses** | Manually craft dict | `Response.not_found()` |
| **IDE autocomplete** | No | Yes |
| **Documentation** | String keys | Self-documenting |
| **Middleware state** | Magic strings | `req.context` |
| **Validation** | None | Type validates |
| **Status code safety** | Easy to get wrong | Trait ensures correctness |

## Integration with QEP-060, QEP-061, QEP-062

- **QEP-060** (HTTP Server Startup): Converts HTTP requests to Request types at entry point
- **QEP-061** (Middleware System): Middleware works with Request/HttpResponse traits
- **QEP-062** (Flexible Routing): Routers receive typed Request, populate `req.params`

All three QEPs are enhanced by having strong types throughout the framework.

## Implementation Phases

1. **Phase 1**: Create types in `std/web/types.q`, export from `std/web/index.q`
2. **Phase 2**: Update Rust server layer for HTTP ↔ type conversion
3. **Phase 3**: Implement middleware system with typed Request/Response
4. **Phase 4**: Implement router with typed handlers

## Files to Read

- Main spec: `specs/qep-063-universal-request-response-types.md`
- Architecture: `specs/qep-063-architecture.md`

Both include detailed examples, design rationale, and implementation guidance.
