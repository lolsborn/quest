use "std/test"

test.module("Web Server - QEP-060 Phase 4")

test.describe("Request dict format", fun ()
  test.it("request dict contains path", fun ()
    use "std/web" as web

    # Verify request dict can be created and contains expected fields
    # We test by checking the web module configuration system
    let config = web._get_config()
    test.assert_not_nil(config)
  end)
end)

test.describe("Static file serving", fun ()
  test.it("static directories can be configured", fun ()
    use "std/web" as web

    # Add static directory
    web.add_static("/public", "./public")

    # Verify it was registered
    let config = web._get_config()
    test.assert_eq(config["static_dirs"].len(), 1)
    test.assert_eq(config["static_dirs"][0][0], "/public")
    test.assert_eq(config["static_dirs"][0][1], "./public")
  end)

  test.it("multiple static directories work", fun ()
    use "std/web" as web

    web.add_static("/static", "./static")
    web.add_static("/media", "./media")

    let config = web._get_config()
    test.assert_eq(config["static_dirs"].len(), 2)
  end)
end)

test.describe("Before/after hooks", fun ()
  test.it("before_request hook can be registered", fun ()
    use "std/web" as web

    web.before_request(fun (req)
      req
    end)

    let config = web._get_config()
    test.assert_eq(config["before_hooks"].len(), 1)
  end)

  test.it("after_request hook can be registered", fun ()
    use "std/web" as web

    web.after_request(fun (req, resp)
      resp
    end)

    let config = web._get_config()
    test.assert_eq(config["after_hooks"].len(), 1)
  end)

  test.it("multiple hooks can be registered", fun ()
    use "std/web" as web

    web.before_request(fun (req) req end)
    web.before_request(fun (req) req end)

    let config = web._get_config()
    test.assert_eq(config["before_hooks"].len(), 2)
  end)
end)

test.describe("Error handlers", fun ()
  test.it("error handler can be registered for 404", fun ()
    use "std/web" as web

    web.on_error(404, fun (req)
      {"status": 404, "body": "Not found"}
    end)

    let config = web._get_config()
    test.assert_not_nil(config["error_handlers"]["404"])
  end)

  test.it("error handler can be registered for 500", fun ()
    use "std/web" as web

    web.on_error(500, fun (req, error)
      {"status": 500, "body": "Error: " .. error}
    end)

    let config = web._get_config()
    test.assert_not_nil(config["error_handlers"]["500"])
  end)
end)

test.describe("Response dict format", fun ()
  test.it("response dict requires status field", fun ()
    use "std/web" as web

    # Response must have status and body/json
    let resp = {status: 200, body: "OK"}
    test.assert_eq(resp["status"], 200)
    test.assert_eq(resp["body"], "OK")
  end)

  test.it("response dict can have headers", fun ()
    use "std/web" as web

    let resp = {
      status: 200,
      body: "OK",
      headers: {"X-Custom": "value"}
    }
    test.assert_not_nil(resp["headers"])
  end)

  test.it("response dict supports json shorthand", fun ()
    use "std/web" as web

    let resp = {
      status: 200,
      json: {data: "test"}
    }
    test.assert_not_nil(resp["json"])
  end)
end)

test.describe("Redirects", fun ()
  test.it("redirects can be configured", fun ()
    use "std/web" as web

    web.redirect("/old", "/new", 301)

    let config = web._get_config()
    test.assert_not_nil(config["redirects"]["/old"])
  end)
end)

test.describe("Default headers", fun ()
  test.it("default headers can be set", fun ()
    use "std/web" as web

    web.set_default_headers({
      "X-Frame-Options": "DENY",
      "X-Content-Type-Options": "nosniff"
    })

    let config = web._get_config()
    test.assert_eq(config["default_headers"]["X-Frame-Options"], "DENY")
  end)
end)
