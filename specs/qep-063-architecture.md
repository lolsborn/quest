# QEP-063: Universal Request/Response Types - Architecture

## Overview

A comprehensive redesign of Quest's web request/response system using:
1. **Strong typing** for type safety and IDE support
2. **Trait-based responses** for semantic response types
3. **Factory methods** for common HTTP status codes
4. **Complete replacement** of Dict-based API (breaking change, but cleaner)

## Type Hierarchy

```
HttpResponse (trait)
├── Response (generic implementation)
│   ├── OkResponse (200)
│   ├── CreatedResponse (201)
│   ├── BadRequestResponse (400)
│   ├── UnauthorizedResponse (401)
│   ├── ForbiddenResponse (403)
│   ├── NotFoundResponse (404)
│   ├── ConflictResponse (409)
│   ├── InternalErrorResponse (500)
│   └── ServiceUnavailableResponse (503)
└── Custom types (user-defined responses)

Request (concrete type)
├── Fields: method, path, version, client_ip, headers, body, etc.
├── Methods: method_is(), is_json(), get_header(), etc.
└── context: Dict (for middleware to share state)
```

## Request Type Design

```quest
pub type Request
  # HTTP metadata
  method: Str              # GET, POST, PUT, DELETE, PATCH, etc.
  path: Str                # /api/users/123
  version: Str             # HTTP/1.1
  client_ip: Str           # 127.0.0.1

  # Content
  headers: Dict            # All headers (lowercase keys)
  body: Str?               # Request body (nil if empty)

  # Query string
  query: Dict              # Parsed query parameters
  query_string: Str?       # Raw query string

  # Route parameters (added by router middleware)
  params: Dict?            # {id: 123, slug: "hello"}

  # Middleware context
  context: Dict?           # {user: user_obj, ...}

  # Common headers (convenience fields)
  content_type: Str?       # application/json
  content_length: Int?     # 1234
  user_agent: Str?         # Mozilla/5.0...
  referer: Str?            # https://example.com

  # Instance methods
  fun method_is(name: Str) -> Bool
  fun is_json() -> Bool
  fun is_form() -> Bool
  fun get_header(name: Str) -> Str?
  fun get_query_param(key: Str, default = nil)
  fun get_param(key: Str)
  fun has_param(key: Str) -> Bool
end
```

## Response Type Hierarchy

### HttpResponse Trait

All response types implement this interface:

```quest
trait HttpResponse
  fun get_status() -> Int           # HTTP status code
  fun get_headers() -> Dict         # Response headers
  fun get_body() -> Str?            # Response body
  fun set_header(name: Str, value: Str) -> Self
  fun set_body(content: Str) -> Self
  fun redirect(location: Str, permanent = false) -> Self
  fun to_dict() -> Dict             # For Rust conversion
end
```

### Factory Methods on Response Type

```quest
Response.ok(body)                                # 200
Response.created(json, location)                 # 201
Response.bad_request(message, details)           # 400
Response.unauthorized(message, challenge)        # 401
Response.forbidden(message)                      # 403
Response.not_found(message, path)                # 404
Response.conflict(message, conflicting_resource) # 409
Response.internal_error(message, error_id)       # 500
Response.service_unavailable(message, retry_after) # 503
Response.with_status(status, body)               # Generic
Response.json(data, status)                      # JSON response
```

### Specialized Response Types

Each semantic response type captures relevant data:

**OkResponse (200)**
- Minimal: just the body content

**CreatedResponse (201)**
- Includes Location header
- JSON data field
- Semantic: "Created" not just "200 OK"

**BadRequestResponse (400)**
- Message and optional details
- Always JSON
- For validation errors: `details: {field: "username", issue: "taken"}`

**UnauthorizedResponse (401)**
- Message and WWW-Authenticate challenge
- For APIs to indicate auth scheme

**NotFoundResponse (404)**
- Message and requested path
- For logging which path was missing

**ConflictResponse (409)**
- Message and conflicting resource reference
- For concurrent modification detection

**InternalErrorResponse (500)**
- Message and unique error_id
- error_id enables client-server error correlation

**ServiceUnavailableResponse (503)**
- Message and Retry-After header
- For maintenance windows

## Middleware Flow

```
HTTP Request
    ↓
[Rust Server] Converts HTTP → Request type
    ↓
middleware.1(req: Request) → Request | HttpResponse
    ↓
    returns Request? Continue chain
    returns HttpResponse? Short-circuit
    ↓
middleware.2(req: Request) → Request | HttpResponse
    ↓
router.dispatch_middleware(req) → Request | HttpResponse
    ↓
    No route match? Return req
    Route matched? Call handler, get HttpResponse back
    ↓
after_middleware.1(req, resp: HttpResponse) → HttpResponse
    ↓
after_middleware.2(req, resp: HttpResponse) → HttpResponse
    ↓
[Rust Server] Converts HttpResponse → HTTP Response
    ↓
HTTP Response
```

## Request/Response Conversion (Rust)

### HTTP to Request (Inbound)

```rust
fn http_to_request(http_req: &Request, client_ip: &str) -> QValue {
    // Create Request struct instance
    let request = QStruct::new_from_type("Request");

    request.set_field("method", QValue::Str(http_req.method.to_string()));
    request.set_field("path", QValue::Str(extract_path(http_req)));
    request.set_field("version", QValue::Str(format!("{:?}", http_req.version)));
    request.set_field("client_ip", QValue::Str(client_ip.to_string()));

    // Convert headers Dict
    let headers_dict = convert_headers_to_dict(http_req.headers());
    request.set_field("headers", headers_dict);

    // Parse body
    request.set_field("body", QValue::Str(body_string));

    // Parse query string
    let query_dict = parse_query_string(query_string);
    request.set_field("query", query_dict);
    request.set_field("query_string", QValue::Str(query_string));

    // Initialize optional fields
    request.set_field("params", QValue::Nil);  // Set by router
    request.set_field("context", QValue::Nil); // Set by middleware

    QValue::Struct(request)
}
```

### Response (Trait) to HTTP (Outbound)

```rust
fn response_to_http(response: &QValue) -> HttpResponse {
    // Response is a struct implementing HttpResponse trait

    let status = call_method(response, "get_status()")?.as_int()?;
    let headers = call_method(response, "get_headers()")?.as_dict()?;
    let body = call_method(response, "get_body()")?.as_str()?;

    let mut http_response = HttpResponse::builder()
        .status(status)
        .body(body)?;

    for (key, value) in headers.iter() {
        http_response = http_response.header(key, value);
    }

    Ok(http_response.build()?)
}
```

## Module Structure

```
std/web/
├── index.q              # Main web module (exports)
├── types.q              # Request & Response types
├── middleware/
│   ├── router.q         # Routing middleware
│   ├── logging.q        # Access logging
│   ├── cors.q           # CORS headers
│   └── security.q       # Security headers
└── _internal.q          # Internal helpers
```

## Usage Examples

### Simple Handler

```quest
use "std/web/middleware/router" as router

router.get("/", fun (req: Request)
  return Response.ok("Hello!")
end)
```

### JSON API

```quest
router.post("/api/users", fun (req: Request)
  if not req.is_json()
    return Response.bad_request("Must be JSON")
  end

  let data = json.parse(req.body)
  let user = db.create_user(data)

  return Response.created(json: user, location: f"/users/{user.id}")
end)
```

### Error Responses

```quest
router.get("/api/user/{id<int>}", fun (req: Request)
  let user = db.find_user(req.get_param("id"))

  if user == nil
    return Response.not_found("User not found", path: req.path)
  end

  return Response.json(user)
end)
```

### Middleware

```quest
fun auth_middleware(req: Request) -> Request | HttpResponse
  if not verify_token(req.get_header("Authorization"))
    return Response.unauthorized("Invalid token")
  end
  return req
end

web.use(auth_middleware)
```

## Key Design Decisions

### 1. **Trait-based responses** enable:
- Multiple response type implementations
- Type safety (each response type has specific fields)
- Semantic clarity (NotFoundResponse vs generic Response)
- Easy to extend with custom response types

### 2. **Factory methods** provide:
- Clear, fluent API: `Response.ok()`, `Response.not_found()`
- Auto-correct HTTP status codes (can't do 200 with not_found)
- Good IDE autocomplete
- Concise handlers

### 3. **Request.params starts as nil** because:
- Before router middleware runs, params don't exist
- Explicit nil makes it clear when params are available
- Router middleware populates params

### 4. **Request.context for middleware state**:
- Shared dict for middleware to add data
- Auth middleware: `req.context["user"] = user`
- Handler accesses: `let user = req.context["user"]`
- Clean separation: no hidden state

### 5. **Complete replacement** instead of gradual migration:
- Cleaner codebase (no legacy dict API)
- Better for long-term maintenance
- Migration is usually simpler (less boilerplate)
- Pairs well with QEP-062 routing

## Benefits vs Current Dict API

| Aspect | Dict API | Typed API |
|--------|----------|-----------|
| Type checking | None | Full (IDE catches errors) |
| IDE support | No autocomplete | Full autocomplete |
| Documentation | String keys to remember | Self-documenting types |
| Response semantics | All dicts (200 vs 404 unclear) | Type tells you response type |
| Error responses | Manually craft dict | Factory methods |
| Middleware state | Dict keys (magic strings) | Request.context (typed) |
| Extensibility | Can't validate | Trait-based (validated) |

## Implementation Phases

### Phase 1: Types & Core
- Create `std/web/types.q` with Request, HttpResponse trait, response types
- Export from `std/web/index.q`
- Basic factory methods work

### Phase 2: Rust Integration
- HTTP → Request conversion
- HttpResponse trait → HTTP conversion
- Server passes typed Request to handlers
- Receives typed HttpResponse from handlers

### Phase 3: Middleware (QEP-061)
- Middleware works with Request/HttpResponse
- Short-circuiting based on response type
- After-middleware receives typed responses

### Phase 4: Router (QEP-062)
- Router handlers receive typed Request
- Params injected into req.params
- Handlers return HttpResponse

## Success Metrics

✅ All handlers use typed Request/HttpResponse
✅ Semantic response types prevent status code mistakes
✅ Middleware state clear (req.context)
✅ IDE autocomplete throughout
✅ Code simpler and clearer than Dict API
✅ No performance regression
