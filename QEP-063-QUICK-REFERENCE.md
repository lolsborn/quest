# QEP-063 Quick Reference

## TL;DR

Replace Quest's Dict-based request/response with **strongly-typed Request and Response types** using **traits for semantic response types** and **factory methods for common status codes**.

## Key Features

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
  params: Dict?  # Set by router
  context: Dict?  # For middleware

  # Methods: method_is(), is_json(), get_header(), get_param(), etc.
end
```

### Response Trait + Factory Methods
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

# Factory methods on Response type:
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

### Specialized Response Types
Each response status code has its own semantic type:
- **OkResponse** - minimal body only
- **CreatedResponse** - includes Location header and JSON
- **BadRequestResponse** - includes details dict for validation errors
- **UnauthorizedResponse** - includes WWW-Authenticate challenge
- **NotFoundResponse** - includes requested path for logging
- **ConflictResponse** - includes conflicting_resource reference
- **InternalErrorResponse** - includes unique error_id for correlation
- **ServiceUnavailableResponse** - includes Retry-After header

## Usage Examples

### Basic Handler
```quest
use "std/web" {Request, Response}
use "std/web/middleware/router" as router

router.get("/", fun (req: Request)
  Response.ok("Hello!")
end)
```

### Error Response
```quest
router.get("/post/{id<int>}", fun (req: Request)
  let post = db.find(req.get_param("id"))

  if post == nil
    return Response.not_found("Post not found", path: req.path)
  end

  return Response.json(post)
end)
```

### JSON API
```quest
router.post("/api/users", fun (req: Request)
  if not req.is_json()
    return Response.bad_request("Must be JSON")
  end

  let user = create_user(json.parse(req.body))
  return Response.created(json: user, location: f"/users/{user.id}")
end)
```

### Middleware
```quest
use "std/web" {Request, Response}

fun auth_middleware(req: Request) -> Request | Response
  let token = req.get_header("Authorization")

  if token == nil
    return Response.unauthorized("Bearer token required", challenge: "Bearer")
  end

  req.context = req.context or {}
  req.context["user"] = verify_token(token)

  return req
end
```

## Import Options

### Option 1: Qualified names (no selective import)
```quest
use "std/web" as web

fun handler(req: web.Request)
  return web.Response.ok()
end
```

### Option 2: Selective import (recommended, cleaner)
```quest
use "std/web" {Request, Response}

fun handler(req: Request)
  return Response.ok()
end
```

## Why This Design?

| Problem | Solution |
|---------|----------|
| Dict keys are magic strings | Types are self-documenting |
| Easy to send wrong status code | Factory methods ensure correctness |
| No IDE autocomplete | Full IDE support with types |
| Middleware state unclear | `req.context` dict is explicit |
| Can't validate responses | Trait ensures all responses implement interface |
| Boilerplate dict creation | Factory methods do it for you |

## Breaking Change

This completely replaces the Dict-based API from QEP-060/061/062.

**Before (Dict API):**
```quest
fun handle_request(req)
  if req["method"] == "POST"
    return {status: 201, json: {id: 1}}
  end
  return {status: 200, body: "OK"}
end
```

**After (Typed API):**
```quest
use "std/web" {Request, Response}

fun handle_request(req: Request)
  if req.method == "POST"
    return Response.created(json: {id: 1})
  end
  return Response.ok("OK")
end
```

## Files

- **specs/qep-063-universal-request-response-types.md** - Full specification with design rationale
- **specs/qep-063-architecture.md** - Type hierarchy and implementation phases
- **DESIGN-SUMMARY-QEP-063.md** - Extended overview with examples

## Implementation Phases

1. Define types in `std/web/types.q`
2. Update Rust HTTP conversion layer
3. Integrate with middleware system (QEP-061)
4. Integrate with router (QEP-062)
