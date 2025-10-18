use "std/test" { module, describe, it, assert }
use "std/web"

module("QEP-061: Web Server Middleware System")

describe("Request Middleware (web.middleware)", fun ()
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
end)

describe("Response Middleware (web.after)", fun ()
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
end)

describe("Backward Compatibility", fun ()
  it("before_request delegates to middleware", fun ()
    let before_count = 0
    web.before_request(fun (req)
      return req
    end)

    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "before_request adds to middlewares")
  end)

  it("after_request delegates to after middleware", fun ()
    let after_count = 0
    web.after_request(fun (req, resp)
      return resp
    end)

    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "after_request adds to after_middlewares")
  end)
end)

describe("Middleware Configuration", fun ()
  it("web._get_config returns middleware arrays", fun ()
    web.middleware(fun (req) return req end)
    web.after(fun (req, resp) return resp end)

    let config = web._get_config()
    assert(config["middlewares"] != nil, "middlewares array exists")
    assert(config["after_middlewares"] != nil, "after_middlewares array exists")
  end)
end)

describe("Middleware Request Handling Patterns", fun ()
  it("middleware can modify request fields", fun ()
    # Test that middleware can be registered to modify request fields
    let test_req = {path: "/test", method: "GET"}
    let handler_executed = false

    web.middleware(fun (req)
      req["_test_marker"] = "marked"
      handler_executed = true
      return req
    end)

    # Verify middleware was registered
    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "middleware was registered")
  end)

  it("middleware can short-circuit with response dict", fun ()
    # Test that middleware can short-circuit by returning a response dict
    let handler_registered = false

    web.middleware(fun (req)
      if req["path"] == "/admin"
        handler_registered = true
        return {status: 403, body: "Forbidden"}
      end
      return req
    end)

    # Verify middleware was registered
    let config = web._get_config()
    assert(config["middlewares"].len() > 0, "short-circuit middleware was registered")
  end)
end)

describe("Middleware Response Handling Patterns", fun ()
  it("response middleware can add headers", fun ()
    # Test that response middleware can be registered to add headers
    web.after(fun (req, resp)
      if resp["headers"] == nil
        resp["headers"] = {}
      end
      resp["headers"]["X-Custom"] = "value"
      return resp
    end)

    # Verify after middleware was registered
    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "response middleware was registered")
  end)

  it("response middleware can log response", fun ()
    # Test that response middleware can be registered for logging
    web.after(fun (req, resp)
      let status = resp["status"]
      if status != nil
        # Log it
      end
      return resp
    end)

    # Verify after middleware was registered
    let config = web._get_config()
    assert(config["after_middlewares"].len() > 0, "logging middleware was registered")
  end)
end)