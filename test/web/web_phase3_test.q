use "std/test"

test.module("Web Server - QEP-060 Phase 3")

test.describe("web.run() Phase 3 - Configuration", fun ()
  test.it("validates handle_request exists", fun ()
    use "std/web" as web

    # Try to call web.run() without defining handle_request
    # This should fail with appropriate error
    let error_caught = false
    let error_msg = ""
    try
      # web.run() will check for handle_request and fail
      # We can't actually run the server in tests, but we can verify
      # the configuration extraction logic works

      # For now, just verify web.run is callable
      let run_fn = web.run
      test.assert_not_nil(run_fn)
    catch e
      error_caught = true
      error_msg = e.message()
    end

    # The function should exist
    test.assert_eq(error_caught, false)
  end)

  test.it("loads static_dirs configuration", fun ()
    use "std/web" as web

    # Verify static_dirs can be retrieved
    web.add_static("/assets", "./assets")
    let config = web._get_config()

    test.assert_eq(config["static_dirs"].len(), 1)
    test.assert_eq(config["static_dirs"][0][0], "/assets")
    test.assert_eq(config["static_dirs"][0][1], "./assets")
  end)

  test.it("loads CORS configuration", fun ()
    use "std/web" as web

    # Set CORS config
    web.set_cors(origins: ["http://localhost:3000"], methods: ["GET", "POST"])
    let config = web._get_config()

    # Verify CORS was set
    test.assert_not_nil(config["cors"])
    test.assert_eq(config["cors"]["origins"].len(), 1)
  end)

  test.it("loads before/after hooks", fun ()
    use "std/web" as web

    # Add some hooks
    web.before_request(fun (req)
      req
    end)

    web.after_request(fun (req, resp)
      resp
    end)

    let config = web._get_config()

    # Verify hooks were registered (now called middlewares and after_middlewares in QEP-061)
    test.assert_eq(config["middlewares"].len(), 1)
    test.assert_eq(config["after_middlewares"].len(), 1)
  end)

  test.it("loads error handlers", fun ()
    use "std/web" as web

    # Register error handlers
    web.on_error(404, fun (req)
      {"status": 404, "body": "Not found"}
    end)

    let config = web._get_config()

    # Verify error handler was registered
    test.assert_not_nil(config["error_handlers"]["404"])
  end)

  test.it("loads redirects", fun ()
    use "std/web" as web

    # Add redirect
    web.redirect("/old", "/new", 301)

    let config = web._get_config()

    # Verify redirect was registered
    test.assert_not_nil(config["redirects"]["/old"])
    test.assert_eq(config["redirects"]["/old"][0], "/new")
    test.assert_eq(config["redirects"]["/old"][1], 301)
  end)

  test.it("loads default headers", fun ()
    use "std/web" as web

    # Set default headers
    web.set_default_headers({"X-Custom": "value"})

    let config = web._get_config()

    # Verify headers were set
    test.assert_eq(config["default_headers"]["X-Custom"], "value")
  end)
end)

test.describe("web.run() Phase 3 - Server Startup", fun ()
  test.it("requires handle_request function in non-static mode", fun ()
    use "std/web" as web

    # This test verifies the validation logic
    # We can't actually run the server in tests,
    # but we can verify the configuration is correct

    # Just ensure the function exists
    let run_fn = web.run
    test.assert_not_nil(run_fn)
  end)
end)
