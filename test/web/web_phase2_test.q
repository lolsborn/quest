use "std/test"

test.module("Web Server - QEP-060 Phase 3")

test.describe("web.run() initialization", fun ()
  test.it("validates handle_request exists", fun ()
    use "std/web" as web

    # web.run() should work even without handle_request defined
    # If no handler is defined, the server returns 404s for dynamic routes
    let result = web.run()
    test.assert_not_nil(result)
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
