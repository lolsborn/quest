# Quest Web App with Advanced Middleware Patterns (QEP-061)
# Demonstrates middleware short-circuiting, authentication, and request transformation
#
# Run with: quest examples/web/routing_middleware_advanced.q
# Then visit:
#   http://localhost:3000/
#   http://localhost:3000/admin  (requires auth)
#   http://localhost:3000/api/data
#

use "std/web" as web
use "std/web/middleware/router" as router
use "std/time"

# =============================================================================
# Middleware 1: Request Logging (runs for all requests)
# =============================================================================

web.middleware(fun (req)
  let now = time.now().str()
  puts(f"[{now}] {req['method']} {req['path']} from {req['client_ip']}")
  return req
end)

# =============================================================================
# Middleware 2: Authentication Check with Short-Circuiting
# =============================================================================

web.middleware(fun (req)
  # Check if this is a protected route
  if req["path"].startswith("/admin") or req["path"].startswith("/api/private")
    # Check for authorization header
    let headers = req["headers"] or {}
    let auth_header = headers["authorization"] or ""

    # For demo: accept Bearer tokens starting with "valid-"
    if not auth_header.startswith("Bearer valid-")
      # Short-circuit: return 401 response instead of continuing
      return {
        status: 401,
        json: {
          error: "Unauthorized",
          message: "Missing or invalid Authorization header",
          example: "Authorization: Bearer valid-token123"
        },
        headers: {Content-Type: "application/json"}
      }
    end

    # Extract token and store in request context
    let token = auth_header.slice(7, auth_header.len())  # Remove "Bearer "
    req["_auth_token"] = token
  end

  return req
end)

# =============================================================================
# Middleware 3: Request Transformation (add computed fields)
# =============================================================================

web.middleware(fun (req)
  # Add request timing
  req["_start_time"] = time.now()

  # Add request ID for tracking
  req["_request_id"] = req["client_ip"] .. "-" .. time.now().milliseconds()

  # Add user info from auth token (mock)
  if req["_auth_token"] != nil
    let token = req["_auth_token"]
    req["_user"] = {
      id: token.hash_code() % 1000,  # Mock user ID from token
      token: token,
      authenticated: true
    }
  else
    req["_user"] = {id: nil, authenticated: false}
  end

  return req
end)

# =============================================================================
# Middleware 4: Response Middleware (add timing and tracking headers)
# =============================================================================

web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end

  # Add security headers
  resp["headers"]["X-Content-Type-Options"] = "nosniff"
  resp["headers"]["X-Frame-Options"] = "DENY"
  resp["headers"]["X-XSS-Protection"] = "1; mode=block"

  # Add performance headers
  if req["_start_time"] != nil
    let duration = time.now().diff(req["_start_time"])
    resp["headers"]["X-Response-Time"] = duration.as_milliseconds().str() .. "ms"
  end

  # Add request tracking
  if req["_request_id"] != nil
    resp["headers"]["X-Request-ID"] = req["_request_id"]
  end

  # Add CORS headers
  resp["headers"]["Access-Control-Allow-Origin"] = "*"

  return resp
end)

# =============================================================================
# Routes
# =============================================================================

# Public routes (no auth required)
router.get("/", fun (req)
  {
    status: 200,
    body: "Welcome to Advanced Middleware Demo\n\n" ..
          "Public routes:\n" ..
          "  GET /\n" ..
          "  GET /public/info\n\n" ..
          "Protected routes (require 'Authorization: Bearer valid-<token>' header):\n" ..
          "  GET /admin/dashboard\n" ..
          "  GET /api/private/data\n",
    headers: {Content-Type: "text/plain"}
  }
end)

router.get("/public/info", fun (req)
  {
    status: 200,
    json: {
      message: "This is public information",
      timestamp: time.now().str(),
      request_id: req["_request_id"]
    },
    headers: {Content-Type: "application/json"}
  }
end)

# Protected routes (require authentication)
router.get("/admin/dashboard", fun (req)
  {
    status: 200,
    json: {
      dashboard: "admin",
      user_id: req["_user"]["id"],
      authenticated_as: req["_user"]["token"],
      timestamp: time.now().str()
    },
    headers: {Content-Type: "application/json"}
  }
end)

router.get("/api/private/data", fun (req)
  {
    status: 200,
    json: {
      data: [
        {id: 1, value: "secret1"},
        {id: 2, value: "secret2"},
        {id: 3, value: "secret3"}
      ],
      accessed_by: req["_user"]["token"],
      timestamp: time.now().str()
    },
    headers: {Content-Type: "application/json"}
  }
end)

# Health check
router.get("/health", fun (req)
  {
    status: 200,
    json: {
      status: "ok",
      timestamp: time.now().str(),
      authenticated: req["_user"]["authenticated"]
    },
    headers: {Content-Type: "application/json"}
  }
end)

# =============================================================================
# Error Handler
# =============================================================================

fun handle_404(req)
  {
    status: 404,
    json: {
      error: "Not Found",
      path: req["path"],
      message: "No route matches this request"
    },
    headers: {Content-Type: "application/json"}
  }
end

# =============================================================================
# Main Request Handler
# =============================================================================

fun handle_request(req)
  # Use router to dispatch to handlers
  let response = router.dispatch_middleware(req)

  # If no route matched, return 404
  if response["status"] == nil
    return handle_404(req)
  end

  return response
end

# =============================================================================
# Server Startup
# =============================================================================

puts("Starting Advanced Middleware Demo...")
puts("")
puts("Testing routes:")
puts("")
puts("Public routes (no auth needed):")
puts("  curl http://localhost:3000/")
puts("  curl http://localhost:3000/public/info")
puts("")
puts("Protected routes (require valid token):")
puts("  curl http://localhost:3000/admin/dashboard")
puts("    -> 401 Unauthorized without token")
puts("")
puts("  curl -H 'Authorization: Bearer valid-mytoken' \\")
puts("    http://localhost:3000/admin/dashboard")
puts("    -> 200 OK with token starting with 'valid-'")
puts("")
puts("  curl -H 'Authorization: Bearer invalid-token' \\")
puts("    http://localhost:3000/admin/dashboard")
puts("    -> 401 Unauthorized with invalid token")
puts("")
puts("Health check (works with or without auth):")
puts("  curl http://localhost:3000/health")
puts("")
puts("Press Ctrl+C to stop")
puts("")

web.run()

puts("Server stopped.")
