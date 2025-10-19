---
Number: QEP-063
Title: Universal Request/Response Types for Web Framework
Author: Claude (with Steven Ruppert)
Status: Proposal
Created: 2025-10-18
Related: QEP-060, QEP-061, QEP-062
---

# QEP-063: Universal Request/Response Types for Web Framework

## Overview

Propose strongly-typed `Request` and `Response` types for Quest's web framework to replace ad-hoc Dict-based request/response handling. These types would provide:

1. **Type safety** - Catch missing fields and type errors at compile time
2. **Better IDE support** - Autocomplete, type hints, documentation
3. **Self-documenting** - Clear API surface vs opaque Dict keys
4. **Evolution path** - Extend without breaking changes
5. **Performance** - Potential future optimization

## Current State (Dict-based, QEP-060/061/062)

### Request Dict (Current)
```quest
{
  "method": "GET",              # Str: HTTP method
  "path": "/post/hello",        # Str: URL path
  "query": {...},               # Dict: Parsed query params
  "headers": {...},             # Dict: HTTP headers
  "body": "",                   # Str: Request body
  "query_string": "page=1",     # Str: Raw query string
  "version": "HTTP/1.1",        # Str: HTTP version
  "client_ip": "127.0.0.1",     # Str: Client IP
  "params": {...},              # Dict: Route parameters (QEP-062)
  "_start_time": nil,           # Special: Middleware use
  "_context": {...}             # Special: Middleware context
}
```

### Response Dict (Current)
```quest
{
  "status": 200,                # Int: HTTP status code
  "headers": {...},             # Dict: Response headers
  "body": "...",                # Str: Response body
  "json": nil,                  # Auto-serialization (Axum extension)
  "cookies": nil                # Dict: Response cookies (planned)
}
```

### Problems with Dict-based API

1. **No type checking** - `req["method"]` returns `Nil` if typo'd to `req["methodd"]`
2. **No IDE support** - Can't autocomplete request fields
3. **Opaque keys** - Must memorize all valid dict keys
4. **Fragile contracts** - Easy to miss required fields
5. **No validation** - Invalid data passes silently
6. **Documentation scattered** - Spread across multiple QEP docs
7. **Error-prone middleware** - Accidental field mutations
8. **Hard to version** - Adding fields is implicit and undocumented

## Proposed Solution: Strong Types with Traits

### Request Type

```quest
pub type Request
  # Required fields (always present)
  method: Str              # HTTP method: GET, POST, PUT, DELETE, PATCH, HEAD, OPTIONS
  path: Str                # URL path (without query string)
  version: Str             # HTTP version (e.g., "HTTP/1.1")
  client_ip: Str           # Client IP address

  # Content
  headers: Dict            # HTTP headers (lowercase keys)
  body: Str?               # Request body (Nil if no body)

  # Query/Routing
  query: Dict              # Parsed query parameters
  query_string: Str?       # Raw query string (Nil if none)
  params: Dict?            # Route parameters from QEP-062 (Nil before routing)

  # Context (for middleware/handlers)
  context: Dict?           # Custom context (added by middleware)

  # Metadata
  content_type: Str?       # Content-Type header value
  content_length: Int?     # Content-Length (Nil if not set)
  user_agent: Str?         # User-Agent header
  referer: Str?            # Referer header

  # Lifecycle hooks (for middleware)
  _start_time: Time?       # When request arrived (for timing)

  # Getters
  fun method_is(name: Str) -> Bool
    # Case-insensitive HTTP method check
    self.method.upper() == name.upper()
  end

  fun is_json() -> Bool
    # Check if request has JSON content type
    self.content_type != nil and self.content_type.contains("application/json")
  end

  fun is_form() -> Bool
    # Check if request has form content type
    self.content_type != nil and self.content_type.contains("application/x-www-form-urlencoded")
  end

  fun get_header(name: Str) -> Str?
    # Get header value (case-insensitive)
    self.headers[name.lower()]
  end

  fun has_query_param(key: Str) -> Bool
    # Check if query parameter exists
    self.query[key] != nil
  end

  fun get_query_param(key: Str, default_value = nil)
    # Get query parameter with optional default
    self.query[key] or default_value
  end

  fun has_param(key: Str) -> Bool
    # Check if route parameter exists
    self.params != nil and self.params[key] != nil
  end

  fun get_param(key: Str)
    # Get route parameter
    if self.params == nil
      return nil
    end
    self.params[key]
  end
end
```

### Response Trait

Define a common interface for all response types:

```quest
trait HttpResponse
  # All response types must implement these methods

  fun get_status() -> Int
    # Return HTTP status code
  end

  fun get_headers() -> Dict
    # Return response headers
  end

  fun get_body() -> Str?
    # Return response body (Nil for no body)
  end

  fun set_header(name: Str, value: Str) -> Self
    # Set a response header, return self for chaining
  end

  fun set_body(content: Str) -> Self
    # Set response body, return self for chaining
  end

  fun redirect(location: Str, permanent = false) -> Self
    # Set redirect, return self for chaining
  end

  fun to_dict() -> Dict
    # Convert to Dict representation (for backwards compatibility)
    # Returns {status: Int, headers: Dict, body: Str?}
  end
end
```

### Response Type (Base Implementation)

```quest
pub type Response
  impl HttpResponse

  # Fields
  status: Int              # HTTP status code
  headers: Dict?           # Response headers (auto-creates if nil)
  body: Str?               # Response body (Str or Nil)
  json: Dict?              # For JSON responses (auto-serialized)

  # Factory methods - Create specific response types
  static fun ok(body = nil) -> OkResponse
    OkResponse.new(body: body)
  end

  static fun created(json = nil) -> CreatedResponse
    CreatedResponse.new(json: json)
  end

  static fun bad_request(msg = nil) -> BadRequestResponse
    BadRequestResponse.new(message: msg or "Bad Request")
  end

  static fun unauthorized(msg = nil) -> UnauthorizedResponse
    UnauthorizedResponse.new(message: msg or "Unauthorized")
  end

  static fun forbidden(msg = nil) -> ForbiddenResponse
    ForbiddenResponse.new(message: msg or "Forbidden")
  end

  static fun not_found(msg = nil) -> NotFoundResponse
    NotFoundResponse.new(message: msg or "Not Found")
  end

  static fun conflict(msg = nil) -> ConflictResponse
    ConflictResponse.new(message: msg or "Conflict")
  end

  static fun internal_error(msg = nil) -> InternalErrorResponse
    InternalErrorResponse.new(message: msg or "Internal Server Error")
  end

  static fun service_unavailable(msg = nil) -> ServiceUnavailableResponse
    ServiceUnavailableResponse.new(message: msg or "Service Unavailable")
  end

  # Generic factory - create response with status and body
  static fun with_status(status: Int, body = nil) -> Response
    Response.new(status: status, body: body)
  end

  # Generic JSON response factory
  static fun json(data: Dict, status = 200) -> Response
    Response.new(status: status, json: data)
  end

  # Impl HttpResponse
  fun get_status() -> Int
    self.status
  end

  fun get_headers() -> Dict
    self.headers or {}
  end

  fun get_body() -> Str?
    self.body
  end

  fun set_header(name: Str, value: Str) -> Self
    if self.headers == nil
      self.headers = {}
    end
    self.headers[name.lower()] = value
    return self
  end

  fun set_body(content: Str) -> Self
    self.body = content
    self.json = nil
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    self.status = if permanent then 301 else 302 end
    self.set_header("Location", location)
    self.body = nil
    return self
  end

  fun to_dict() -> Dict
    return {
      "status": self.status,
      "headers": self.headers or {},
      "body": self.body,
      "json": self.json
    }
  end
end
```

### Specialized Response Types

Using factory methods and the trait, create semantic response types:

```quest
# 2xx Success Responses

pub type OkResponse
  impl HttpResponse
  body: Str?

  static fun new(body = nil) -> OkResponse
    OkResponse._new()
    # Auto-set status: 200
  end

  fun get_status() -> Int
    200
  end

  fun get_headers() -> Dict
    {}
  end

  fun get_body() -> Str?
    self.body
  end

  fun set_header(name: Str, value: Str) -> Self
    # OK responses typically don't have custom headers, but allow it
    return self
  end

  fun set_body(content: Str) -> Self
    self.body = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from OkResponse")
  end

  fun to_dict() -> Dict
    {status: 200, headers: {}, body: self.body}
  end
end

pub type CreatedResponse
  impl HttpResponse
  location: Str?
  json: Dict?

  static fun new(json = nil, location = nil) -> CreatedResponse
    let resp = CreatedResponse._new()
    resp.json = json
    resp.location = location
    return resp
  end

  fun get_status() -> Int
    201
  end

  fun get_headers() -> Dict
    let headers = {}
    if self.location != nil
      headers["Location"] = self.location
    end
    return headers
  end

  fun get_body() -> Str?
    # CreatedResponse uses JSON, not body
    nil
  end

  fun set_header(name: Str, value: Str) -> Self
    if name.lower() == "location"
      self.location = value
    end
    return self
  end

  fun set_body(content: Str) -> Self
    raise TypeErr.new("Cannot set body on CreatedResponse, use set_json()")
  end

  fun set_json(data: Dict, location = nil) -> Self
    self.json = data
    if location != nil
      self.location = location
    end
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from CreatedResponse")
  end

  fun to_dict() -> Dict
    {
      status: 201,
      headers: self.get_headers(),
      json: self.json
    }
  end
end

# 4xx Error Responses

pub type BadRequestResponse
  impl HttpResponse
  message: Str
  details: Dict?

  static fun new(message = "Bad Request", details = nil) -> BadRequestResponse
    let resp = BadRequestResponse._new()
    resp.message = message
    resp.details = details
    return resp
  end

  fun get_status() -> Int
    400
  end

  fun get_headers() -> Dict
    {"Content-Type": "application/json"}
  end

  fun get_body() -> Str?
    let response = {error: self.message}
    if self.details != nil
      response["details"] = self.details
    end
    json.stringify(response)
  end

  fun set_header(name: Str, value: Str) -> Self
    # Error responses have fixed headers
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from BadRequestResponse")
  end

  fun to_dict() -> Dict
    {
      status: 400,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

pub type UnauthorizedResponse
  impl HttpResponse
  message: Str
  challenge: Str?  # WWW-Authenticate header value

  static fun new(message = "Unauthorized", challenge = nil) -> UnauthorizedResponse
    let resp = UnauthorizedResponse._new()
    resp.message = message
    resp.challenge = challenge
    return resp
  end

  fun get_status() -> Int
    401
  end

  fun get_headers() -> Dict
    let headers = {"Content-Type": "application/json"}
    if self.challenge != nil
      headers["WWW-Authenticate"] = self.challenge
    end
    return headers
  end

  fun get_body() -> Str?
    json.stringify({error: self.message})
  end

  fun set_header(name: Str, value: Str) -> Self
    if name.lower() == "www-authenticate"
      self.challenge = value
    end
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from UnauthorizedResponse")
  end

  fun to_dict() -> Dict
    {
      status: 401,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

pub type ForbiddenResponse
  impl HttpResponse
  message: Str

  static fun new(message = "Forbidden") -> ForbiddenResponse
    let resp = ForbiddenResponse._new()
    resp.message = message
    return resp
  end

  fun get_status() -> Int
    403
  end

  fun get_headers() -> Dict
    {"Content-Type": "application/json"}
  end

  fun get_body() -> Str?
    json.stringify({error: self.message})
  end

  fun set_header(name: Str, value: Str) -> Self
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from ForbiddenResponse")
  end

  fun to_dict() -> Dict
    {
      status: 403,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

pub type NotFoundResponse
  impl HttpResponse
  message: Str
  path: Str?  # The requested path for logging

  static fun new(message = "Not Found", path = nil) -> NotFoundResponse
    let resp = NotFoundResponse._new()
    resp.message = message
    resp.path = path
    return resp
  end

  fun get_status() -> Int
    404
  end

  fun get_headers() -> Dict
    {"Content-Type": "application/json"}
  end

  fun get_body() -> Str?
    let body = {error: self.message}
    if self.path != nil
      body["path"] = self.path
    end
    json.stringify(body)
  end

  fun set_header(name: Str, value: Str) -> Self
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from NotFoundResponse")
  end

  fun to_dict() -> Dict
    {
      status: 404,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

pub type ConflictResponse
  impl HttpResponse
  message: Str
  conflicting_resource: Str?

  static fun new(message = "Conflict", conflicting_resource = nil) -> ConflictResponse
    let resp = ConflictResponse._new()
    resp.message = message
    resp.conflicting_resource = conflicting_resource
    return resp
  end

  fun get_status() -> Int
    409
  end

  fun get_headers() -> Dict
    {"Content-Type": "application/json"}
  end

  fun get_body() -> Str?
    let body = {error: self.message}
    if self.conflicting_resource != nil
      body["conflicting"] = self.conflicting_resource
    end
    json.stringify(body)
  end

  fun set_header(name: Str, value: Str) -> Self
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from ConflictResponse")
  end

  fun to_dict() -> Dict
    {
      status: 409,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

# 5xx Server Error Responses

pub type InternalErrorResponse
  impl HttpResponse
  message: Str
  error_id: Str?  # Unique error identifier for logging

  static fun new(message = "Internal Server Error", error_id = nil) -> InternalErrorResponse
    let resp = InternalErrorResponse._new()
    resp.message = message
    resp.error_id = error_id
    return resp
  end

  fun get_status() -> Int
    500
  end

  fun get_headers() -> Dict
    {"Content-Type": "application/json"}
  end

  fun get_body() -> Str?
    let body = {error: self.message}
    if self.error_id != nil
      body["error_id"] = self.error_id
    end
    json.stringify(body)
  end

  fun set_header(name: Str, value: Str) -> Self
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from InternalErrorResponse")
  end

  fun to_dict() -> Dict
    {
      status: 500,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end

pub type ServiceUnavailableResponse
  impl HttpResponse
  message: Str
  retry_after: Int?  # Seconds until service available

  static fun new(message = "Service Unavailable", retry_after = nil) -> ServiceUnavailableResponse
    let resp = ServiceUnavailableResponse._new()
    resp.message = message
    resp.retry_after = retry_after
    return resp
  end

  fun get_status() -> Int
    503
  end

  fun get_headers() -> Dict
    let headers = {"Content-Type": "application/json"}
    if self.retry_after != nil
      headers["Retry-After"] = self.retry_after.str()
    end
    return headers
  end

  fun get_body() -> Str?
    json.stringify({error: self.message})
  end

  fun set_header(name: Str, value: Str) -> Self
    if name.lower() == "retry-after"
      self.retry_after = value.to_int()
    end
    return self
  end

  fun set_body(content: Str) -> Self
    self.message = content
    return self
  end

  fun redirect(location: Str, permanent = false) -> Self
    raise TypeErr.new("Cannot redirect from ServiceUnavailableResponse")
  end

  fun to_dict() -> Dict
    {
      status: 503,
      headers: self.get_headers(),
      body: self.get_body()
    }
  end
end
```

## Implementation Strategy: Complete Replacement

This proposal is for a **complete replacement** of the Dict-based request/response system - not a gradual migration. This provides:

1. **Clean slate** - No legacy Dict API to maintain
2. **Better design** - Traits enable semantic response types (NotFoundResponse, CreatedResponse, etc.)
3. **Type safety throughout** - IDE support and compile-time checking everywhere
4. **Cleaner documentation** - Single, unified API

### Implementation Steps

1. **Create `std/web/types.q`** (new module):
   - Define `Request` type with all fields and methods
   - Define `HttpResponse` trait (interface all responses implement)
   - Define response type implementations: `OkResponse`, `NotFoundResponse`, `BadRequestResponse`, `UnauthorizedResponse`, `ForbiddenResponse`, `ConflictResponse`, `InternalErrorResponse`, `ServiceUnavailableResponse`, `CreatedResponse`

2. **Update `std/web/index.q`**:
   - Export all types and factory methods
   - Example: `Response.ok()`, `Response.not_found()`, `Response.unauthorized()`, etc.

3. **Update Rust server layer** (`src/server.rs`):
   - HTTP request → `Request` type conversion at entry point
   - Response trait → HTTP response conversion before sending
   - Implement trait serialization for all response types

4. **Update middleware system** (QEP-061 implementation):
   - Middleware receives `Request`, returns `Request | HttpResponse`
   - Trait allows any response type to be returned
   - Short-circuit when response is returned (not a request)

5. **Update router** (QEP-062 implementation):
   - Route handlers receive `Request` parameter
   - Route handlers return `HttpResponse` (any response type)
   - Route parameters injected into `req.params`

### Migration from Current Dict API

For the blog example and any existing code:

**Before (Dict API)**:
```quest
fun handle_request(req)
  let method = req["method"]
  let path = req["path"]

  if method == "GET" and path == "/"
    return {status: 200, body: "Hello"}
  end

  return {status: 404, body: "Not Found"}
end
```

**After (Typed API)**:
```quest
use "std/web/router" as router

router.get("/", fun (req: Request)
  return Response.ok("Hello")
end)

# 404 handled automatically by router
```

## Design Decisions

### 1. Request.params Starts as Nil

- **Why**: Params only populated after routing middleware
- **Before routing**: `req.params` is `nil` (not empty dict)
- **After routing**: `req.params` is populated dict
- **Check**: `if req.params != nil and req.params["id"] != nil`

### 2. Response Headers are Lowercase

- **Why**: HTTP headers are case-insensitive, normalize to lowercase
- **Implementation**: `req.get_header("Content-Type")` handles case conversion
- **Storage**: Headers stored lowercase in dict

### 3. Content-Type and Other Headers as Fields

- **Why**: Common headers get dedicated fields for ergonomics
- **Benefit**: `req.content_type` vs `req.get_header("Content-Type")`
- **Sync**: Dedicated fields stay in sync with headers dict

### 4. Context Dict for Middleware State

- **Why**: Middleware needs to pass state (e.g., authenticated user)
- **Design**: `req.context` is shared dict, mutations visible to all middleware
- **Example**: `req.context["user"] = user_obj` in auth middleware

### 5. Factory Methods on Response

- **Why**: Common status codes should be obvious
- **Builder pattern**: Chain methods for fluent API
- **Example**: `Response.ok().set_header("X-Custom", "value")`

## Benefits

### Compile-Time Safety
```quest
# Old (runtime error: typo'd key)
let method = req["mehtod"]  # Oops! Returns Nil

# New (compile-time error: field doesn't exist)
let method = req.mehtod     # Type error caught immediately
```

### IDE Support
```quest
# Old (no autocomplete)
req[           # No suggestions

# New (full autocomplete)
req.           # Suggests: method, path, headers, body, params, query, etc.
```

### Middleware Clarity
```quest
# Old (opaque what middleware does)
web.use(fun (req)
  req["_start_time"] = time.now()
  return req
end)

# New (clear contract)
web.use(fun (req: Request) -> Request
  req.context["start_time"] = time.now()
  return req
end)
```

### Documentation
```quest
# Types serve as documentation
pub type Request
  method: Str              # HTTP method
  path: Str                # URL path
  params: Dict?            # Route params (Nil before routing)
end

# vs reading Dict format in 3 different QEP docs
```

## Implementation Details

### Request Conversion (Rust)

In `src/server.rs`, convert HTTP request to Request type:

```rust
fn http_request_to_quest_request(
    http_req: &Request,
    client_ip: &str,
) -> Result<QValue, String> {
    let mut request_dict = QDict::new();

    request_dict.insert("method", QValue::Str(http_req.method.to_string()));
    request_dict.insert("path", QValue::Str(extract_path(http_req)));
    request_dict.insert("version", QValue::Str(format!("{:?}", http_req.version)));
    request_dict.insert("client_ip", QValue::Str(client_ip.to_string()));

    // ... populate headers, body, query, etc.

    // Create Request struct from dict
    let request_type = scope.get_type("Request");
    let request_instance = request_type.construct(request_dict)?;

    Ok(request_instance)
}
```

### Response Conversion (Rust)

Convert Response type back to HTTP response:

```rust
fn quest_response_to_http_response(
    response: &QValue,
) -> Result<HttpResponse, String> {
    let response_struct = response.as_struct()?;

    let status = response_struct.get_field("status")?.as_int()?;
    let body = response_struct.get_field("body")?.as_str()?;

    // ... build HttpResponse with status, body, headers

    Ok(http_response)
}
```

### Backwards Compatibility

Dict-based request/response still works because:

1. Types implement `.to_dict()` method
2. Dict methods work on type instances
3. Middleware can accept `Dict` or `Request`
4. Functions can work with both

```quest
# Both signatures work
fun handler1(req: Dict) -> Dict
  # Old style - Dict access
  return {status: 200}
end

fun handler2(req: Request) -> Response
  # New style - Type access
  return Response.ok()
end

# Can mix in same middleware chain
web.use(handler1)  # Dict API
web.use(handler2)  # Type API
```

## Migration Path for Users

### Step 1: Add Type Hints (Non-breaking)
```quest
# Before
fun my_handler(req)
  return {status: 200, body: "OK"}
end

# After (add type hints)
fun my_handler(req: Request) -> Response
  return Response.ok()
end
```

### Step 2: Use Typed Methods
```quest
# Before
return {status: 200, body: "Hello", headers: {"X-Custom": "value"}}

# After
return Response.ok("Hello").set_header("X-Custom", "value")
```

### Step 3: Use Helper Methods
```quest
# Before
if req["method"] == "POST"
  # ...
end

# After
if req.method_is("POST")
  # ...
end
```

### Step 4: Full Migration
```quest
# Before
let status = req["status"]
let path = req["path"]

# After
let status = req.status
let path = req.path
```

## Questions & Discussion

### Q1: Should Request/Response be mutable?

**Current proposal**: YES (mutable)
- Middleware needs to mutate request/response
- Simpler mental model
- Aligns with dict behavior

**Alternative**: Immutable with builder pattern
- Harder for middleware
- More functional style

### Q2: Should context be typed?

**Current proposal**: Dict (untyped)
- Flexible for middleware to add anything
- Easier for users

**Alternative**: Typed dict or separate fields
- More type safety
- Less flexible

### Q3: What about cookies?

**Current proposal**: Deferred to QEP-064
- Cookies are complex (security, encoding)
- Separate from core request/response types
- Can add later without breaking

### Q4: Should we support header shortcuts?

**Current proposal**: YES
- `req.content_type`, `req.user_agent`, `req.referer`
- Other headers via `get_header()`

**Alternative**: Everything via `get_header()`
- More consistent
- More verbose

### Q5: Should Response have builder pattern?

**Current proposal**: YES
```quest
Response.ok().set_header("X-Custom", "value")
```

**Alternative**: No chaining
```quest
let resp = Response.new(status: 200)
resp.set_header("X-Custom", "value")
resp
```

## Import Semantics

Types are defined in `std/web`, so without explicit import, use qualified names:

```quest
use "std/web" as web

# Without selective import, types are accessed via web namespace
router.get("/", fun (req: web.Request)
  return web.Response.ok("Hello!")
end)
```

**OR use selective import for cleaner code:**

```quest
use "std/web" {Request, Response}
use "std/web/router" as router

# Now can use unqualified names
router.get("/", fun (req: Request)
  return Response.ok("Hello!")
end)
```

## Examples

### Simple Handler with Semantic Response Types (with selective import)
```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.get("/", fun (req: Request)
  return Response.ok("Hello, World!")
end)

web.use(router.dispatch_middleware)
web.run()
```

### Alternative without selective import
```quest
use "std/web" as web
use "std/web/router" as router

router.get("/", fun (req: web.Request)
  return web.Response.ok("Hello, World!")
end)

web.use(router.dispatch_middleware)
web.run()
```

### JSON API with Factory Methods

```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.post("/api/users", fun (req: Request)
  if not req.is_json()
    return Response.bad_request("Content-Type must be application/json")
  end

  let data = json.parse(req.body or "{}")

  # Validate required fields
  if data["name"] == nil
    return Response.bad_request("Missing 'name' field", details: {field: "name"})
  end

  let user = create_user(data)

  # Factory method returns CreatedResponse with Location header
  return Response.created(json: user, location: f"/users/{user['id']}")
end)
```

### Error Handling with Specific Response Types
```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.get("/post/{id<int>}", fun (req: Request)
  let post_id = req.get_param("id")

  let post = db.query("SELECT * FROM posts WHERE id = ?", [post_id])

  if post == nil
    # NotFoundResponse includes path and context
    return Response.not_found("Post not found", path: req.path)
  end

  return Response.ok(json.stringify(post))
end)

router.delete("/post/{id<int>}", fun (req: Request)
  let post_id = req.get_param("id")
  let post = db.query("SELECT * FROM posts WHERE id = ?", [post_id])

  if post == nil
    return Response.not_found()
  end

  # Check for conflicts (e.g., post already deleted by another request)
  if post["deleted"] == true
    return Response.conflict("Post was already deleted by another operation", conflicting_resource: f"/posts/{post_id}")
  end

  db.execute("DELETE FROM posts WHERE id = ?", [post_id])

  # No content response for successful deletion
  return Response.with_status(204)
end)
```

### Middleware with Request Context
```quest
use "std/web" {Request, Response}
use "std/web/router" as router

fun auth_middleware(req: Request) -> Request | Response
  let token = req.get_header("Authorization")

  if token == nil
    # UnauthorizedResponse with challenge for browsers
    return Response.unauthorized("Bearer token required", challenge: "Bearer")
  end

  let user = verify_token(token)
  if user == nil
    return Response.unauthorized()
  end

  # Store authenticated user in context for handlers
  req.context = req.context or {}
  req.context["user"] = user

  return req
end

# Protected route
router.get("/api/profile", fun (req: Request)
  let user = req.context["user"]

  if user == nil
    return Response.unauthorized()
  end

  return Response.json({
    id: user.id,
    name: user.name,
    email: user.email
  })
end)
```

### File Download with Semantic Response

```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.get("/files/{path<path>}", fun (req: Request)
  let file_path = req.get_param("path")

  # Security: prevent directory traversal
  if file_path.contains("..")
    return Response.forbidden("Directory traversal not allowed")
  end

  let full_path = f"./files/{file_path}"

  if not io.exists(full_path)
    return Response.not_found("File not found", path: file_path)
  end

  let contents = io.read(full_path)

  return Response.ok(contents)
    .set_content_type("application/octet-stream")
    .set_header("Content-Disposition", f'attachment; filename="{file_path}"')
end)
```

### Graceful Error Handling
```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.post("/api/data", fun (req: Request)
  if not req.is_json()
    return Response.bad_request("Content-Type must be application/json")
  end

  try
    let data = json.parse(req.body or "{}")
    let result = process_data(data)
    return Response.created(json: result)
  catch e: ValueErr
    return Response.bad_request(f"Invalid request: {e.message()}")
  catch e: Err
    # Unique error ID for server logs
    let error_id = uuid.v4().str()
    log.error(f"[{error_id}] Request failed: {e.message()}")
    return Response.internal_error("Server error", error_id: error_id)
  end
end)
```

### Service Degradation
```quest
use "std/web" {Request, Response}
use "std/web/router" as router

router.get("/api/status", fun (req: Request)
  let status = check_system_health()

  if not status["healthy"]
    # ServiceUnavailableResponse with Retry-After header
    return Response.service_unavailable(
      "System maintenance in progress",
      retry_after: 300  # Retry after 5 minutes
    )
  end

  return Response.json({
    status: "ok",
    uptime: status["uptime"]
  })
end)
```

### Middleware Logging with Semantic Responses
```quest
use "std/web" {Request, HttpResponse}
use "std/log" as log

fun logging_middleware(req: Request) -> Request
  req.context = req.context or {}
  req.context["start_time"] = time.now()
  return req
end

fun logging_after(req: Request, resp: HttpResponse) -> HttpResponse
  let duration = time.now().diff(req.context["start_time"]).as_milliseconds()
  let logger = log.get_logger("web.access")

  # Log all requests with semantic response info
  let status = resp.get_status()
  let log_level = if status >= 500 then log.ERROR elif status >= 400 then log.WARNING else log.INFO end

  logger.log(
    log_level,
    f"{req.client_ip} {req.method} {req.path} - {status} ({duration}ms)"
  )

  return resp
end

web.use(logging_middleware)
web.after(logging_after)
```

## Implementation Checklist

- [ ] Define `Request` type in `std/web/types.q` (new module)
- [ ] Define `Response` type in `std/web/types.q`
- [ ] Export from `std/web.q`
- [ ] Implement Request conversion in Rust (`http_to_request`)
- [ ] Implement Response conversion in Rust (`response_to_http`)
- [ ] Add `.to_dict()` methods for backwards compatibility
- [ ] Update middleware examples to use new types
- [ ] Update blog example to use new types
- [ ] Documentation with migration guide
- [ ] Type checking in router middleware
- [ ] Test coverage for both Dict and Type APIs
- [ ] Performance benchmarks (should be identical)

## Performance Considerations

### Expected Impact
- **Zero overhead**: Types compile to same dict operations
- **Same memory**: Identical representation as current dicts
- **Same runtime**: No type checking at runtime (Quest is dynamically typed)
- **Better IDE**: Type hints improve editor performance

### Optimization Opportunities (Future)
- Struct access faster than dict lookup (potential optimization)
- Field shortcuts (e.g., `req.method` faster than dict access)
- JIT could optimize field access

## Architecture Overview

### Type Hierarchy

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

### Middleware Flow

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

### Module Structure

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

## Request/Response Conversion (Rust Implementation)

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

## Breaking Changes (By Design)

**This is a breaking change** - intentionally:
- Dict-based request/response API is completely replaced
- New typed API requires updating handler functions
- Migration is straightforward (usually simpler code)
- Benefit: Cleaner codebase, better type safety

**Note**: This change pairs well with QEP-062 (routing), which also moves away from manual dict manipulation toward explicit router API.

## Success Criteria

- ✅ Request and Response types fully specified
- ✅ Can be used interchangeably with dicts
- ✅ Middleware works with typed handlers
- ✅ Type hints improve IDE support
- ✅ Examples updated to new types
- ✅ Documentation clear on migration path
- ✅ All existing code still works
- ✅ No performance regression

## Related QEPs

- **QEP-060**: Application-Centric Web Server (uses request/response)
- **QEP-061**: Web Middleware System (passes request/response)
- **QEP-062**: Flexible Routing (adds `params` to request)
- **QEP-064** (future): Response Cookies

## References

- Express.js Request/Response: https://expressjs.com/en/api/req.html
- Flask Request/Response: https://flask.palletsprojects.com/en/stable/api/
- Axum Request/Response: https://docs.rs/axum/latest/axum/
- Quest current dict API: `std/web.q`, QEP-060, QEP-061, QEP-062

---

## Proposal Summary

**Goal**: Add optional strongly-typed `Request` and `Response` types to Quest's web framework.

**Scope**: Types coexist with existing Dict API, full backwards compatibility.

**Benefits**:
- Type safety and IDE support
- Self-documenting API
- Cleaner middleware code
- Clear evolution path

**Timeline**: Can be implemented incrementally without blocking other QEPs.

**Next Steps**:
1. Review and discuss design decisions above
2. Clarify any ambiguous points
3. Begin Phase 1 implementation (new type definitions)
4. Migrate examples incrementally in Phase 2
