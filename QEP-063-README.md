# QEP-063: Universal Request/Response Types for Web Framework

## Overview

A comprehensive specification for redesigning Quest's web request/response system with:

- **Strongly-typed Request type** with all HTTP metadata and helper methods
- **HttpResponse trait** that all response types implement
- **Semantic response type classes** (NotFoundResponse, CreatedResponse, etc.) with domain-specific fields
- **Factory methods** for clean, concise handler code
- **Complete replacement** of Dict-based API (no backwards compatibility, cleaner codebase)

## Documents

### 1. Quick Reference (`QEP-063-QUICK-REFERENCE.md`)
**Start here** - 2-minute overview with usage examples and why this design is better.

### 2. Design Summary (`DESIGN-SUMMARY-QEP-063.md`)
Mid-level overview including:
- Type architecture
- Factory methods vs specialized response types
- Benefits vs current Dict API
- Basic examples

### 3. Full Specification (`specs/qep-063-universal-request-response-types.md`)
Complete spec with:
- Full Request type definition
- Response trait definition
- All specialized response types (OkResponse, NotFoundResponse, etc.)
- Comprehensive examples for every use case
- Design decisions with rationale
- Implementation checklist

### 4. Architecture Guide (`specs/qep-063-architecture.md`)
Technical deep dive including:
- Type hierarchy diagrams
- Module structure
- Middleware flow diagram
- Rust conversion layer specification
- Implementation phases

## Key Features

### Request Type
```quest
type Request
  method: Str              # HTTP method
  path: Str                # URL path
  version: Str             # HTTP version
  client_ip: Str           # Client IP
  headers: Dict            # HTTP headers
  body: Str?               # Request body
  query: Dict              # Parsed query params
  query_string: Str?       # Raw query string
  params: Dict?            # Route parameters (added by router)
  context: Dict?           # Middleware state

  fun method_is(name: Str) -> Bool
  fun is_json() -> Bool
  fun get_header(name: Str) -> Str?
  fun get_param(key: Str)
  # ... and more helper methods
end
```

### Response Factory Methods
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
Response.json(data, status)
```

### Specialized Response Types
Each HTTP status code has a semantic type with domain-specific fields:

| Type | Status | Special Fields |
|------|--------|-----------------|
| OkResponse | 200 | body |
| CreatedResponse | 201 | Location header, json |
| BadRequestResponse | 400 | message, details dict |
| UnauthorizedResponse | 401 | message, WWW-Authenticate challenge |
| ForbiddenResponse | 403 | message |
| NotFoundResponse | 404 | message, path (for logging) |
| ConflictResponse | 409 | message, conflicting_resource |
| InternalErrorResponse | 500 | message, error_id (for correlation) |
| ServiceUnavailableResponse | 503 | message, Retry-After |

## Example: Complete Handler

```quest
use "std/web" {Request, Response}
use "std/web/middleware/router" as router

# Authentication middleware
fun require_auth(req: Request) -> Request | Response
  let token = req.get_header("Authorization")

  if token == nil
    return Response.unauthorized("Bearer token required", challenge: "Bearer")
  end

  req.context = req.context or {}
  req.context["user"] = verify_token(token)

  return req  # Continue to next middleware
end

# Route handler
router.get("/api/user/{id<int>}", fun (req: Request)
  let user = db.find(req.get_param("id"))

  if user == nil
    return Response.not_found("User not found", path: req.path)
  end

  return Response.json(user)
end)

# Register middleware and router
web.use(require_auth)
web.use(router.dispatch_middleware)
web.run()
```

## Design Highlights

### 1. Factory Methods (Clean API)
```quest
# Instead of: {status: 404, body: "Not Found"}
Response.not_found()

# Instead of: {status: 201, headers: {"Location": "/users/123"}, json: user}
Response.created(json: user, location: "/users/123")
```

### 2. Semantic Types (Type Safety)
Each response type has domain-specific fields, preventing errors:
```quest
# NotFoundResponse specifically stores the requested path
Response.not_found(message: "...", path: req.path)

# UnauthorizedResponse specifically stores the auth challenge
Response.unauthorized(message: "...", challenge: "Bearer")

# InternalErrorResponse stores unique error ID for correlation
Response.internal_error(message: "...", error_id: error_id)
```

### 3. Request Context (Middleware State)
```quest
# Auth middleware stores user
req.context = req.context or {}
req.context["user"] = user_obj

# Handler retrieves user
let user = req.context["user"]

# Clear, no magic strings
```

### 4. Trait-Based Design (Extensible)
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

# All response types implement this trait
# Easy to extend with custom response types
```

## Import Options

### Option 1: Qualified Names
```quest
use "std/web" as web

fun handler(req: web.Request)
  return web.Response.ok()
end
```

### Option 2: Selective Import (Recommended)
```quest
use "std/web" {Request, Response}

fun handler(req: Request)
  return Response.ok()
end
```

## Benefits vs Current Dict API

| Aspect | Dict API | Typed API |
|--------|----------|-----------|
| IDE autocomplete | ❌ No | ✅ Yes |
| Type checking | ❌ None | ✅ Full |
| Response semantics | ❌ All dicts | ✅ Type tells you what it is |
| Status code safety | ❌ Easy to get wrong | ✅ Factory prevents errors |
| Documentation | ❌ String keys to remember | ✅ Self-documenting types |
| Middleware state | ❌ Magic strings in dict | ✅ req.context is explicit |
| Boilerplate | ❌ Manual dict creation | ✅ Factory methods do it |

## Breaking Changes

**This is a breaking change by design:**
- Dict-based request/response API is completely replaced
- New typed API requires updating handler functions
- Migration is usually simpler (less boilerplate)
- Cleaner codebase long-term

## Integration with Other QEPs

- **QEP-060** (HTTP Server Startup) - Converts HTTP to Request type
- **QEP-061** (Middleware System) - Middleware works with typed Request/Response
- **QEP-062** (Flexible Routing) - Router populates req.params with typed values

All three QEPs are enhanced by having strong types throughout.

## Implementation Phases

1. **Phase 1**: Create `std/web/types.q` with Request, HttpResponse trait, response types
2. **Phase 2**: Update Rust server layer for HTTP ↔ type conversion
3. **Phase 3**: Integrate with middleware system (QEP-061)
4. **Phase 4**: Integrate with router (QEP-062)

## Reading Guide

1. **5 minutes**: Read `QEP-063-QUICK-REFERENCE.md`
2. **15 minutes**: Read `DESIGN-SUMMARY-QEP-063.md`
3. **30+ minutes**: Read `specs/qep-063-universal-request-response-types.md` for full details
4. **Technical**: Read `specs/qep-063-architecture.md` for implementation guidance

## Summary

This QEP proposes a complete redesign of Quest's web request/response system using:
- **Strong typing** for IDE support and type safety
- **Factory methods** for concise, clear handler code
- **Semantic response types** with domain-specific fields
- **Trait-based design** for extensibility
- **Complete replacement** of Dict API for cleaner codebase

The result is cleaner, more maintainable web code with better IDE support and fewer runtime errors.
