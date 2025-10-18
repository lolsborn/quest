use "std/test"

test.module("Web Server - QEP-060")

test.describe("web.run() native function", fun ()
  test.it("web.run function exists", fun ()
    use "std/web" as web

    # web.run should exist as a native function
    let run_fn = web.run
    test.assert_not_nil(run_fn)
  end)

  test.it("web.run is callable with named arguments", fun ()
    use "std/web" as web

    # web.run should accept named arguments but return error for Phase 1
    let error_caught = false
    try
      web.run(host: "127.0.0.1", port: 8080)
    catch e
      error_caught = true
      # Verify it's a RuntimeErr
      test.assert_eq(e._type(), "RuntimeErr")
    end

    test.assert_eq(error_caught, true)
  end)

  test.it("web.run is callable without arguments", fun ()
    use "std/web" as web

    let error_caught = false
    try
      web.run()
    catch e
      error_caught = true
      test.assert_eq(e._type(), "RuntimeErr")
    end

    test.assert_eq(error_caught, true)
  end)
end)
