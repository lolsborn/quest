use "std/test"

test.module("Web Framework - QEP-060")

test.describe("web.add_static() function", fun ()
  test.it("registers static directory", fun ()
    use "std/web" as web

    # Static directories should be empty initially
    let config = web._get_config()
    test.assert_eq(config["static_dirs"].len(), 0)

    # Add a static directory
    web.add_static("/public", "./public")

    # Should now have one static directory
    config = web._get_config()
    test.assert_eq(config["static_dirs"].len(), 1)

    # Verify the entry
    let entry = config["static_dirs"][0]
    test.assert_eq(entry[0], "/public")
    test.assert_eq(entry[1], "./public")
  end)

  test.it("supports multiple static directories", fun ()
    use "std/web" as web

    web.add_static("/assets", "./assets")
    web.add_static("/uploads", "./uploads")

    let config = web._get_config()
    test.assert_eq(config["static_dirs"].len(), 2)
  end)

  test.it("requires url_path to start with /", fun ()
    use "std/web" as web

    let error_caught = false
    try
      web.add_static("public", "./public")
    catch e
      error_caught = true
    end

    test.assert_eq(error_caught, true)
  end)
end)

test.describe("web.run() function", fun ()
  test.it("web.run exists as a native function", fun ()
    use "std/web" as web

    # web.run should exist and be callable
    let run_fn = web.run
    test.assert_not_nil(run_fn)
  end)
end)
