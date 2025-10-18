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

    # web.run should accept named arguments and return successfully
    # (Server can run even without handle_request - it just returns 404s)
    let result = web.run(host: "127.0.0.1", port: 8080)
    test.assert_not_nil(result)
  end)

  test.it("web.run is callable without arguments", fun ()
    use "std/web" as web

    # web.run should accept no arguments and return successfully
    # (Uses defaults from quest.toml or built-in defaults)
    let result = web.run()
    test.assert_not_nil(result)
  end)
end)
