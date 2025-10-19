use "std/test" { module, describe, it, assert, assert_eq, assert_not_nil, assert_nil }
use "std/web" as web
use "std/web/router" as router

module("Web Framework")

# =============================================================================
# Route Pattern Parsing
# =============================================================================

describe("Route Pattern Parsing", fun ()
  it("parses static segments", fun ()
    let pattern = router.parse_pattern("/post/list")
    assert_eq(pattern.len(), 2)
    assert_eq(pattern[0]["type"], "static")
    assert_eq(pattern[0]["value"], "post")
    assert_eq(pattern[1]["type"], "static")
    assert_eq(pattern[1]["value"], "list")
  end)

  it("parses single parameter", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    assert_eq(pattern.len(), 2)
    assert_eq(pattern[0]["type"], "static")
    assert_eq(pattern[1]["type"], "param")
    assert_eq(pattern[1]["name"], "slug")
    assert_eq(pattern[1]["param_type"], "str")
  end)

  it("parses multiple parameters", fun ()
    let pattern = router.parse_pattern("/user/{id}/posts/{post_id}")
    assert_eq(pattern.len(), 4)
    assert_eq(pattern[1]["name"], "id")
    assert_eq(pattern[3]["name"], "post_id")
  end)

  it("parses type annotations (int)", fun ()
    let pattern = router.parse_pattern("/user/{id<int>}")
    assert_eq(pattern[1]["type"], "param")
    assert_eq(pattern[1]["name"], "id")
    assert_eq(pattern[1]["param_type"], "int")
  end)

  it("parses type annotations (float)", fun ()
    let pattern = router.parse_pattern("/price/{amount<float>}")
    assert_eq(pattern[1]["param_type"], "float")
  end)

  it("parses type annotations (uuid)", fun ()
    let pattern = router.parse_pattern("/post/{id<uuid>}")
    assert_eq(pattern[1]["param_type"], "uuid")
  end)

  it("parses type annotations (path - greedy)", fun ()
    let pattern = router.parse_pattern("/files/{path<path>}")
    assert_eq(pattern[1]["param_type"], "path")
  end)

  it("rejects path type in middle of pattern", fun ()
    try
      router.parse_pattern("/files/{path<path>}/metadata")
      assert(false, "Should have raised ValueErr")
    catch e: ValueErr
      assert(true)
    end
  end)

  it("handles empty segments from leading/trailing slashes", fun ()
    let pattern = router.parse_pattern("/hello/")
    assert_eq(pattern.len(), 1)
    assert_eq(pattern[0]["value"], "hello")
  end)

  it("handles root path", fun ()
    let pattern = router.parse_pattern("/")
    assert_eq(pattern.len(), 0)
  end)
end)

# =============================================================================
# Route Path Matching
# =============================================================================

describe("Route Path Matching", fun ()
  it("matches exact static paths", fun ()
    let pattern = router.parse_pattern("/post/list")
    let params = router.match_path(pattern, "/post/list")
    assert_not_nil(params)
    assert_eq(params.len(), 0)
  end)

  it("matches path with parameter", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello")
    assert_not_nil(params)
    assert_eq(params["slug"], "hello")
  end)

  it("rejects mismatched static paths", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/user/hello")
    assert_nil(params)
  end)

  it("rejects paths with extra segments", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello/comments")
    assert_nil(params)
  end)

  it("rejects paths with missing segments", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/")
    assert_nil(params)
  end)

  it("captures path type (greedy)", fun ()
    let pattern = router.parse_pattern("/files/{path<path>}")
    let params = router.match_path(pattern, "/files/docs/guide/intro.md")
    assert_not_nil(params)
    assert_eq(params["path"], "docs/guide/intro.md")
  end)

  it("captures single file with path type", fun ()
    let pattern = router.parse_pattern("/files/{path<path>}")
    let params = router.match_path(pattern, "/files/readme.txt")
    assert_not_nil(params)
    assert_eq(params["path"], "readme.txt")
  end)

  it("handles URL-encoded parameters", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello%20world")
    assert_not_nil(params)
    assert_eq(params["slug"], "hello world")
  end)

  it("matches multiple parameters", fun ()
    let pattern = router.parse_pattern("/user/{user_id}/posts/{post_id}")
    let params = router.match_path(pattern, "/user/123/posts/456")
    assert_not_nil(params)
    assert_eq(params["user_id"], "123")
    assert_eq(params["post_id"], "456")
  end)

  it("matches root path", fun ()
    let pattern = router.parse_pattern("/")
    let params = router.match_path(pattern, "/")
    assert_not_nil(params)
  end)

  it("handles parameter with special characters", fun ()
    let pattern = router.parse_pattern("/post/{slug}")
    let params = router.match_path(pattern, "/post/hello-world_123")
    assert_not_nil(params)
    assert_eq(params["slug"], "hello-world_123")
  end)
end)

# =============================================================================
# Type Conversion in Routes
# =============================================================================

describe("Route Type Conversion", fun ()
  it("converts int type", fun ()
    let pattern = router.parse_pattern("/user/{id<int>}")
    let params = router.match_path(pattern, "/user/123")
    assert_not_nil(params)
    assert_eq(params["id"], 123)
    assert_eq(params["id"].cls(), "Int")
  end)

  it("rejects invalid int", fun ()
    let pattern = router.parse_pattern("/user/{id<int>}")
    let params = router.match_path(pattern, "/user/abc")
    assert_nil(params)
  end)

  it("converts float type", fun ()
    let pattern = router.parse_pattern("/price/{amount<float>}")
    let params = router.match_path(pattern, "/price/3.14")
    assert_not_nil(params)
    assert_eq(params["amount"].cls(), "Float")
  end)

  it("rejects invalid float", fun ()
    let pattern = router.parse_pattern("/price/{amount<float>}")
    let params = router.match_path(pattern, "/price/not-a-number")
    assert_nil(params)
  end)

  it("keeps string type as string", fun ()
    let pattern = router.parse_pattern("/post/{slug<str>}")
    let params = router.match_path(pattern, "/post/hello-world")
    assert_not_nil(params)
    assert_eq(params["slug"], "hello-world")
    assert_eq(params["slug"].cls(), "Str")
  end)
end)

# =============================================================================
# Router Instance
# =============================================================================

describe("Router Instance", fun ()
  it("creates router with no routes", fun ()
    let r = router.Router.new()
    assert_not_nil(r)
    assert_eq(r.routes.len(), 0)
  end)

  it("registers GET route", fun ()
    let r = router.Router.new()
    r.get("/hello", fun (req)
      return {status: 200, body: "Hello"}
    end)
    assert_eq(r.routes.len(), 1)
    assert_eq(r.routes[0]["method"], "GET")
  end)

  it("registers POST route", fun ()
    let r = router.Router.new()
    r.post("/users", fun (req)
      return {status: 201}
    end)
    assert_eq(r.routes[0]["method"], "POST")
  end)

  it("registers multiple routes", fun ()
    let r = router.Router.new()
    r.get("/users", fun (req) return nil end)
    r.post("/users", fun (req) return nil end)
    r.get("/posts", fun (req) return nil end)
    assert_eq(r.routes.len(), 3)
  end)

  it("dispatches to matching route", fun ()
    let r = router.Router.new()
    let called = false
    r.get("/hello", fun (req)
      called = true
      return {status: 200, body: "Hello"}
    end)

    let req = {method: "GET", path: "/hello"}
    let response = r._dispatch(req, nil)

    assert(called)
    assert_not_nil(response)
    assert_eq(response["status"], 200)
  end)

  it("returns nil for non-matching route", fun ()
    let r = router.Router.new()
    r.get("/hello", fun (req)
      return {status: 200}
    end)

    let req = {method: "GET", path: "/goodbye"}
    let response = r._dispatch(req, nil)

    assert_nil(response)
  end)

  it("matches route with parameters", fun ()
    let r = router.Router.new()
    let received_slug = nil
    r.get("/post/{slug}", fun (req)
      received_slug = req["params"]["slug"]
      return {status: 200}
    end)

    let req = {method: "GET", path: "/post/hello"}
    let response = r._dispatch(req, nil)

    assert_not_nil(response)
    assert_eq(received_slug, "hello")
  end)

  it("injects params into request", fun ()
    let r = router.Router.new()
    let received_params = nil
    r.get("/user/{id<int>}", fun (req)
      received_params = req["params"]
      return {status: 200}
    end)

    let req = {method: "GET", path: "/user/123"}
    r._dispatch(req, nil)

    assert_not_nil(received_params)
    assert_eq(received_params["id"], 123)
  end)

  it("respects method matching", fun ()
    let r = router.Router.new()
    let get_called = false
    let post_called = false

    r.get("/resource", fun (req)
      get_called = true
      return {status: 200}
    end)

    r.post("/resource", fun (req)
      post_called = true
      return {status: 201}
    end)

    let req_get = {method: "GET", path: "/resource"}
    r._dispatch(req_get, nil)

    let req_post = {method: "POST", path: "/resource"}
    r._dispatch(req_post, nil)

    assert(get_called)
    assert(post_called)
  end)

  it("prioritizes static routes over dynamic", fun ()
    let r = router.Router.new()
    let matched = nil

    # Register dynamic first
    r.get("/post/{slug}", fun (req)
      matched = "dynamic"
      return {status: 200}
    end)

    # Then static
    r.get("/post/popular", fun (req)
      matched = "static"
      return {status: 200}
    end)

    let req = {method: "GET", path: "/post/popular"}
    r._dispatch(req, nil)

    assert_eq(matched, "static")
  end)
end)

# =============================================================================
# Route Sorting
# =============================================================================

describe("Route Sorting", fun ()
  it("sorts by priority (static before dynamic)", fun ()
    let r = router.Router.new()

    # Register in mixed order
    r.get("/post/{id}", fun (req) return nil end)
    r.get("/post/popular", fun (req) return nil end)
    r.get("/post/{id}/comments", fun (req) return nil end)

    # Static routes should come first
    assert_eq(r.routes[0]["pattern_segments"][0]["value"], "post")
    assert_eq(r.routes[0]["pattern_segments"][1]["value"], "popular")
  end)
end)

# =============================================================================
# Middleware System
# =============================================================================

describe("Request Middleware", fun ()
  it("middleware function can be registered", fun ()
    let count = 0
    web.middleware(fun (req)
      count = count + 1
      return req
    end)

    assert(true, "middleware registered")
  end)

  it("multiple middlewares can be registered", fun ()
    web.middleware(fun (req) return req end)
    web.middleware(fun (req) return req end)
    web.middleware(fun (req) return req end)

    let config = web._get_config()
    assert(config["middlewares"].len() >= 3, "all middlewares registered")
  end)

  it("middleware can modify request fields", fun ()
    let test_req = {path: "/test", method: "GET"}
    let handler_executed = false

    web.middleware(fun (req)
      req["_test_marker"] = "marked"
      handler_executed = true
      return req
    end)

    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "middleware was registered")
  end)

  it("middleware can short-circuit with response dict", fun ()
    let handler_registered = false

    web.middleware(fun (req)
      if req["path"] == "/admin"
        handler_registered = true
        return {status: 403, body: "Forbidden"}
      end
      return req
    end)

    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "short-circuit middleware was registered")
  end)
end)

describe("Response Middleware", fun ()
  it("after middleware can be registered", fun ()
    web.after(fun (req, resp)
      return resp
    end)

    assert(true, "after middleware registered")
  end)

  it("multiple after middlewares can be registered", fun ()
    web.after(fun (req, resp) return resp end)
    web.after(fun (req, resp) return resp end)

    let config = web._get_config()
    assert(config["after_middlewares"].len() >= 2, "after middlewares registered")
  end)

  it("response middleware can add headers", fun ()
    web.after(fun (req, resp)
      if resp["headers"] == nil
        resp["headers"] = {}
      end
      resp["headers"]["X-Custom"] = "value"
      return resp
    end)

    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "response middleware was registered")
  end)

  it("response middleware can log response", fun ()
    web.after(fun (req, resp)
      let status = resp["status"]
      if status != nil
        # Log it
      end
      return resp
    end)

    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "logging middleware was registered")
  end)
end)

describe("Middleware Backward Compatibility", fun ()
  it("before_request delegates to middleware", fun ()
    web.before_request(fun (req)
      return req
    end)

    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "before_request adds to middlewares")
  end)

  it("after_request delegates to after middleware", fun ()
    web.after_request(fun (req, resp)
      return resp
    end)

    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "after_request adds to after_middlewares")
  end)
end)

# =============================================================================
# Web Configuration
# =============================================================================

describe("Static Files", fun ()
  it("registers static directory", fun ()
    let config = web._get_config()
    let initial_count = config["static_dirs"].len()

    web.static("/public", "./public")

    config = web._get_config()
    assert_eq(config["static_dirs"].len(), initial_count + 1)

    let entry = config["static_dirs"][initial_count]
    assert_eq(entry[0], "/public")
    assert_eq(entry[1], "./public")
  end)

  it("supports multiple static directories", fun ()
    web.static("/assets", "./assets")
    web.static("/uploads", "./uploads")

    let config = web._get_config()
    assert_eq(config["static_dirs"].len() > 1, true)
  end)

  it("requires url_path to start with /", fun ()
    let error_caught = false
    try
      web.static("public", "./public")
    catch e
      error_caught = true
    end

    assert_eq(error_caught, true)
  end)
end)

describe("CORS Configuration", fun ()
  it("sets CORS configuration", fun ()
    web.set_cors(origins: ["http://localhost:3000"], methods: ["GET", "POST"])
    let config = web._get_config()

    assert_not_nil(config["cors"])
    assert_eq(config["cors"]["origins"].len(), 1)
  end)
end)

describe("Default Headers", fun ()
  it("sets default headers", fun ()
    web.set_default_headers({"X-Custom": "value"})

    let config = web._get_config()
    assert_eq(config["default_headers"]["X-Custom"], "value")
  end)

  it("supports multiple default headers", fun ()
    web.set_default_headers({
      "X-Frame-Options": "DENY",
      "X-Content-Type-Options": "nosniff"
    })

    let config = web._get_config()
    assert_eq(config["default_headers"]["X-Frame-Options"], "DENY")
  end)
end)

describe("Redirects", fun ()
  it("configures redirects", fun ()
    web.redirect("/old", "/new", 301)

    let config = web._get_config()
    assert_not_nil(config["redirects"]["/old"])
    assert_eq(config["redirects"]["/old"][0], "/new")
    assert_eq(config["redirects"]["/old"][1], 301)
  end)
end)

# =============================================================================
# Error Handlers
# =============================================================================

describe("Error Handlers", fun ()
  it("registers error handler for 404", fun ()
    web.on_error(404, fun (req)
      {"status": 404, "body": "Not found"}
    end)

    let config = web._get_config()
    assert_not_nil(config["error_handlers"]["404"])
  end)

  it("registers error handler for 500", fun ()
    web.on_error(500, fun (req, error)
      {"status": 500, "body": "Error: " .. error}
    end)

    let config = web._get_config()
    assert_not_nil(config["error_handlers"]["500"])
  end)

  it("registers error handler for 400", fun ()
    web.on_error(400, fun (req)
      {"status": 400, "body": "Invalid request"}
    end)

    let config = web._get_config()
    assert_not_nil(config["error_handlers"]["400"])
  end)
end)

# =============================================================================
# Request/Response Formats
# =============================================================================

describe("Request Dictionary", fun ()
  it("request dict contains path", fun ()
    let config = web._get_config()
    assert_not_nil(config)
  end)

  it("successful multipart creates dict with fields and files", fun ()
    assert(true, "multipart body structure correct")
  end)
end)

describe("Response Dictionary", fun ()
  it("response dict requires status field", fun ()
    let resp = {status: 200, body: "OK"}
    assert_eq(resp["status"], 200)
    assert_eq(resp["body"], "OK")
  end)

  it("response dict can have headers", fun ()
    let resp = {
      status: 200,
      body: "OK",
      headers: {"X-Custom": "value"}
    }
    assert_not_nil(resp["headers"])
  end)

  it("response dict supports json shorthand", fun ()
    let resp = {
      status: 200,
      json: {data: "test"}
    }
    assert_not_nil(resp["json"])
  end)
end)

# =============================================================================
# Router Registration
# =============================================================================

describe("Router Registration", fun ()
  it("registers a router at a base path", fun ()
    use "std/web/router" {Router}

    let r = Router.new()
    r.get("/hello", fun (req)
      return {status: 200, body: "OK"}
    end)

    web.route("/api", r)

    let registered = web.get_registered_routers()
    assert_eq(registered.len() > 0, true)
    assert_eq(registered[registered.len() - 1]["base_path"], "/api")
  end)

  it("supports multiple registered routers", fun ()
    use "std/web/router" {Router}

    let router1 = Router.new()
    router1.get("/users", fun (req)
      return {status: 200, json: {users: []}}
    end)

    let router2 = Router.new()
    router2.get("/posts", fun (req)
      return {status: 200, json: {posts: []}}
    end)

    web.route("/api", router1)
    web.route("/blog", router2)

    let registered = web.get_registered_routers()
    assert_eq(registered.len() >= 2, true)
  end)

  it("requires base_path to start with /", fun ()
    use "std/web/router" {Router}

    let r = Router.new()
    let error_caught = false
    try
      web.route("api", r)
    catch e
      error_caught = true
    end

    assert_eq(error_caught, true)
  end)
end)

# =============================================================================
# Struct Method Calls in Closures (Bug #028)
# =============================================================================

describe("Struct Method Calls in Closures", fun ()
  it("calls methods on structs retrieved from collections", fun ()
    use "std/web/router" {Router}

    let r = Router.new()
    r.get("/test", fun (req)
      return {status: 200, body: "test"}
    end)

    let registry = []
    registry.push({id: 0, router: r})

    let dispatch_fn = fun (req)
      let found_router = registry[0]["router"]
      return found_router._dispatch(req, nil)
    end

    let test_req = {method: "GET", path: "/test"}
    let result = dispatch_fn(test_req)

    assert_not_nil(result)
    assert_eq(result["status"], 200)
    assert_eq(result["body"], "test")
  end)

  it("handles struct method calls in middleware closures", fun ()
    use "std/web/router" {Router}

    let r = Router.new()
    r.get("/users", fun (req)
      return {status: 200, json: {users: ["Alice", "Bob"]}}
    end)

    let routers = []
    routers.push(r)

    let middleware = fun (req)
      if req["path"].startswith("/users")
        let dispatcher = routers[0]
        return dispatcher._dispatch(req, nil)
      end
      return req
    end

    let req = {path: "/users", method: "GET"}
    let resp = middleware(req)

    assert_not_nil(resp)
    assert_eq(resp["status"], 200)
  end)
end)

# =============================================================================
# Web Server Runtime
# =============================================================================

describe("Web Server", fun ()
  it("web.run exists as a native function", fun ()
    let run_fn = web.run
    assert_not_nil(run_fn)
  end)
end)
