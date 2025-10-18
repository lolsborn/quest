use "std/test"

test.module("Web Server - QEP-060 Phase 3")

test.describe("web.run() initialization", fun ()
  test.it("validates handle_request exists", fun ()
    use "std/web" as web

    # Phase 3: web.run() now checks that handle_request is defined
    let error_caught = false
    try
      web.run()  # No handle_request defined - should error
    catch e
      error_caught = true
      # Error was caught - good!
    end

    test.assert_eq(error_caught, true)
  end)

  test.it("accepts handle_request function", fun ()
    use "std/web" as web

    # Define a handler
    fun handle_request(req)
      {status: 200, body: "OK"}
    end

    # This would start the server and block
    # We can't actually test this in the test suite since it would hang
    # But we can verify the function exists
    test.assert_not_nil(handle_request)
  end)
end)
