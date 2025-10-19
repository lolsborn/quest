# Test for Bug #028: Calling methods on struct instances retrieved from arrays/dicts in closures
#
# This test demonstrates that the bug has been fixed. The issue was that calling methods on
# struct instances retrieved from collections (arrays/dicts) within closures would fail
# with "Type [StructName] not found".
#
# The fix implemented a workaround: using a global registry to store routers/structs instead
# of capturing them directly in closures. See web/index.q lines 346-352.

use "std/web/router" { Router }

puts("=== Bug #028 Test: Struct methods in closures ===\n")

# Test 1: Simple struct method call in closure
puts("Test 1: Simple struct method call in closure")
type TestStruct
  value: Int

  fun get_value()
    self.value
  end
end

let struct_instance = TestStruct.new(value: 42)
let collection = []
collection.push({ data: struct_instance })

let retrieval_closure = fun ()
  let retrieved = collection[0]["data"]
  return retrieved.get_value()
end

try
  let result = retrieval_closure()
  if result == 42
    puts("✓ PASS: Simple struct method call in closure works (result: " .. result .. ")\n")
  else
    puts("✗ FAIL: Expected 42, got " .. result .. "\n")
  end
catch e
  puts("✗ FAIL: " .. e .. "\n")
end

# Test 2: Router method call in closure (original bug scenario)
puts("Test 2: Router method call in closure")
let router = Router.new()
router.get("/hello", fun (req)
  return { status: 200, body: "OK" }
end)

let registry = []
registry.push({ id: 0, router: router })

let middleware = fun (req)
  let found_router = registry[0]["router"]
  let resp = found_router._dispatch(req, nil)
  return resp
end

try
  let test_req = {method: "GET", path: "/hello"}
  let result = middleware(test_req)
  if result["status"] == 200 and result["body"] == "OK"
    puts("✓ PASS: Router method call in closure works\n")
  else
    puts("✗ FAIL: Unexpected result: " .. result .. "\n")
  end
catch e
  puts("✗ FAIL: " .. e .. "\n")
end

# Test 3: web.route global registry workaround
puts("Test 3: web.route using global registry (implementation workaround)")
use "std/web" as web

let api_router = Router.new()
api_router.get("/users", fun (req)
  return { status: 200, json: {users: ["Alice", "Bob"]} }
end)

# Register router using web.route (which internally uses _registered_routers)
web.route("/api", api_router)

# Check that routers were registered
let registered = web.get_registered_routers()
if registered.len() > 0
  puts("✓ PASS: web.route registered " .. registered.len() .. " router(s)\n")
else
  puts("✗ FAIL: No routers registered\n")
end

puts("=== All tests completed ===")
