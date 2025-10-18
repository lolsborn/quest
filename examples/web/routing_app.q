# Quest Web App with Flexible Routing (QEP-062)
# Demonstrates the new router middleware system with pattern matching and type conversion
#
# Run with: quest examples/web/routing_app.q
# Then visit:
#   http://localhost:3000/
#   http://localhost:3000/hello
#   http://localhost:3000/posts
#   http://localhost:3000/posts/my-first-post
#   http://localhost:3000/users/42
#   http://localhost:3000/users/invalid
#   http://localhost:3000/files/docs/readme.md
#

use "std/web" as web
use "std/web/middleware/router" as router
use "std/time"
use "std/encoding/json" as json

# =============================================================================
# Configuration
# =============================================================================

# Add static file serving
web.add_static("/public", "./public")

# Configure CORS to allow requests from anywhere (for demo)
web.set_cors(
  origins: ["*"],
  methods: ["GET", "POST", "PUT", "DELETE"],
  headers: ["Content-Type", "Authorization"]
)

# =============================================================================
# Request Middleware - Add request timing
# =============================================================================

web.middleware(fun (req)
  req["_start_time"] = time.now()
  req["_request_id"] = req["client_ip"] .. "-" .. time.now().milliseconds()
  return req
end)

# =============================================================================
# Response Middleware - Add response headers and timing info
# =============================================================================

web.after(fun (req, resp)
  if resp["headers"] == nil
    resp["headers"] = {}
  end

  # Add security headers
  resp["headers"]["X-Content-Type-Options"] = "nosniff"
  resp["headers"]["X-Frame-Options"] = "DENY"

  # Add response timing header
  if req["_start_time"] != nil
    let duration = time.now().diff(req["_start_time"])
    resp["headers"]["X-Response-Time"] = duration.as_milliseconds().str() .. "ms"
  end

  # Add request ID for tracking
  if req["_request_id"] != nil
    resp["headers"]["X-Request-ID"] = req["_request_id"]
  end

  return resp
end)

# =============================================================================
# Route Registration - Define handlers for different routes
# =============================================================================

# GET /
router.get("/", fun (req)
  {
    status: 200,
    body: "Welcome to Quest Web Router Demo!\n\nTry these routes:\n" ..
          "  GET /hello\n" ..
          "  GET /posts\n" ..
          "  GET /posts/{slug}\n" ..
          "  GET /users/{id}\n" ..
          "  GET /files/{path}\n"
  }
end)

# GET /hello
router.get("/hello", fun (req)
  {
    status: 200,
    body: "Hello from Quest Router!\nServer time: " .. time.now().str()
  }
end)

# GET /posts - List all posts
router.get("/posts", fun (req)
  let posts = [
    {id: 1, title: "First Post", slug: "first-post"},
    {id: 2, title: "Second Post", slug: "second-post"},
    {id: 3, title: "Third Post", slug: "third-post"}
  ]

  {
    status: 200,
    json: {
      posts: posts,
      count: posts.len()
    }
  }
end)

# GET /posts/{slug} - Get a specific post by slug
router.get("/posts/{slug}", fun (req)
  let slug = req["params"]["slug"]

  # Mock post lookup
  let posts = {
    "first-post": {id: 1, title: "First Post", slug: "first-post", content: "This is the first post"},
    "second-post": {id: 2, title: "Second Post", slug: "second-post", content: "This is the second post"},
    "third-post": {id: 3, title: "Third Post", slug: "third-post", content: "This is the third post"}
  }

  if posts.contains(slug)
    {
      status: 200,
      json: posts[slug],
      headers: {"Content-Type": "application/json"}
    }
  else
    {
      status: 404,
      json: {error: "Post not found", slug: slug},
      headers: {"Content-Type": "application/json"}
    }
  end
end)

# GET /users/{id<int>} - Get a user by numeric ID
router.get("/users/{id<int>}", fun (req)
  let user_id = req["params"]["id"]

  # Mock user lookup (use string keys, convert Int to string for lookup)
  let users = {
    "1": {id: 1, name: "Alice", email: "alice@example.com", role: "admin"},
    "2": {id: 2, name: "Bob", email: "bob@example.com", role: "user"},
    "42": {id: 42, name: "The Answer", email: "42@example.com", role: "bot"}
  }

  let user_key = user_id.str()
  if users.contains(user_key)
    {
      status: 200,
      json: users[user_key],
      headers: {"Content-Type": "application/json"}
    }
  else
    {
      status: 404,
      json: {
        error: "User not found",
        user_id: user_id,
        message: "Try: /users/1, /users/2, or /users/42"
      },
      headers: {"Content-Type": "application/json"}
    }
  end
end)

# GET /files/{path} - Get a file (greedy path capture)
router.get("/files/{path<path>}", fun (req)
  let file_path = req["params"]["path"]

  # Mock file lookup
  let files = {
    "readme.md": {name: "readme.md", file_type: "markdown", size: 1024},
    "docs/guide.md": {name: "docs/guide.md", file_type: "markdown", size: 2048},
    "docs/api.md": {name: "docs/api.md", file_type: "markdown", size: 4096}
  }

  if files.contains(file_path)
    {
      status: 200,
      json: files[file_path],
      headers: {"Content-Type": "application/json"}
    }
  else
    {
      status: 404,
      json: {
        error: "File not found",
        path: file_path,
        available: ["readme.md", "docs/guide.md", "docs/api.md"]
      },
      headers: {"Content-Type": "application/json"}
    }
  end
end)

# POST /posts - Create a new post
router.post("/posts", fun (req)
  let body = req["body"]

  # In a real app, you'd parse JSON from the request body
  # For now, just return a mock response

  {
    status: 201,
    json: {
      id: 4,
      title: "New Post",
      slug: "new-post",
      created_at: time.now().str()
    },
    headers: {"Content-Type": "application/json"}
  }
end)

# GET /status - Health check endpoint
router.get("/status", fun (req)
  {
    status: 200,
    json: {
      status: "ok",
      timestamp: time.now().str(),
      uptime: "N/A"
    },
    headers: {"Content-Type": "application/json"}
  }
end)

# =============================================================================
# Error Handling - 404 for unmapped routes
# =============================================================================

fun handle_404(req)
  {
    status: 404,
    json: {
      error: "Not Found",
      path: req["path"],
      method: req["method"],
      message: "No route matches this request. Try GET /"
    },
    headers: {"Content-Type": "application/json"}
  }
end

# =============================================================================
# Request Handler - Main entry point for all dynamic requests
# =============================================================================

fun handle_request(req)
  # Use the router middleware to dispatch to registered routes
  let response = router.dispatch_middleware(req)

  # If router returned a request (no route matched), return 404
  if response["status"] == nil
    return handle_404(req)
  end

  return response
end

# =============================================================================
# Server Startup
# =============================================================================

puts("Starting Quest Web Router Demo...")
puts("Configuration:")
puts("  Host: 127.0.0.1")
puts("  Port: 3000")
puts("  Static files: /public -> ./public")
puts("")
puts("Available routes:")
puts("  GET  /")
puts("  GET  /hello")
puts("  GET  /posts")
puts("  GET  /posts/{slug}")
puts("  GET  /users/{id}")
puts("  GET  /files/{path}")
puts("  POST /posts")
puts("  GET  /status")
puts("")
puts("Press Ctrl+C to stop")
puts("")

web.run()

puts("Server stopped.")
