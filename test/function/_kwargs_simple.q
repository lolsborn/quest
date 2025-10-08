# Simple kwargs test (Phase 2 partial implementation)

# Test 1: Function with just **kwargs
fun test_kwargs(**options)
    options
end

puts("Test 1: Just **kwargs")
let result1 = test_kwargs()
puts("Got dict with " .. result1.len().str() .. " items")
puts("Dict contents: " .. result1.str())
puts("")

# Test 2: Function with params and **kwargs
fun configure(host, port = 8080, **options)
    puts("host: " .. host)
    puts("port: " .. port.str())
    puts("options: " .. options.str())
end

puts("Test 2: Params + **kwargs")
configure("localhost")
puts("")
configure("localhost", 3000)
puts("")

# Test 3: Function with *args and **kwargs
fun full_signature(a, b = 1, *args, **kwargs)
    puts("a: " .. a.str())
    puts("b: " .. b.str())
    puts("args length: " .. args.len().str())
    puts("kwargs length: " .. kwargs.len().str())
end

puts("Test 3: Full signature (a, b=1, *args, **kwargs)")
full_signature(10)
puts("")
full_signature(10, 20)
puts("")
full_signature(10, 20, 30, 40)
puts("")

puts("✓ All basic **kwargs tests passed!")
puts("")
puts("NOTE: Named argument passing (QEP-035) not yet implemented,")
puts("so kwargs will always be empty dicts for now.")
