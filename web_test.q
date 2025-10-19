use "std/web"
use "std/web/router" { Router }

let router = Router.new()
router.get("/hello/", fun (req)
  return {
    "status": 200,
    "body": "Hello, World!"
  }
end)
router.get("/number/{name<str>}", fun (req)
  let num = req["params"]["name"]
  puts(num.cls())
  num = num + 1
  return {
    "status": 200,
    "body": f"you guessed {num}!"
  }
end)

# Register router using web.route() with proper global registry (QEP-062)
web.route("/", router)

web.static("/static", ".")

web.run("127.0.0.1", 3005)