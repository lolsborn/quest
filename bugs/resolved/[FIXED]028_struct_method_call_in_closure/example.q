# This demonstrates Bug #026: struct method calls fail in closures when the struct is retrieved from a collection

use "std/web/router" { Router }

# Create a router struct
let router = Router.new()
router.get("/hello", fun (req)
  return { status: 200, body: "OK" }
end)

# Store it in a dict (simulating what web.route does)
let registry = []
registry.push({ id: 0, router: router })

# Try to retrieve and call a method in a closure
let middleware = fun (req)
  puts("In middleware")
  let found_router = registry[0]["router"]
  puts("Found router, calling _dispatch...")
  # This will FAIL with: TypeErr: Type Router not found
  let resp = found_router._dispatch(req, nil)
  return resp
end

# WORKAROUND: Call method on module-level variable directly
let middleware_workaround = fun (req)
  # This works because we access the router directly from module scope
  let resp = router._dispatch(req, nil)
  return resp
end

# Test with workaround
let test_req = {method: "GET", path: "/hello"}
puts("Testing workaround:")
let result = middleware_workaround(test_req)
puts("Result: " .. result.str())
