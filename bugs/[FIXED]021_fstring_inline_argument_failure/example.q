# Minimal reproduction of f-string inline argument bug with struct methods

type TestStruct
    fun print_msg(msg)
        puts("Received: " .. msg)
    end
end

let obj = TestStruct.new()
let name = "Alice"
let city = "NYC"

puts("=== Test 1: Variable assignment (WORKS) ===")
let msg = f"Hello {name} from {city}"
obj.print_msg(msg)

puts("\n=== Test 2: Inline f-string to struct method (FAILS) ===")
obj.print_msg(f"Hello {name} from {city}")

puts("\n=== Test 3: String concatenation (WORKS) ===")
obj.print_msg("Hello " .. name .. " from " .. city)

puts("\n=== Test 4: Regular function with inline f-string (WORKS) ===")
fun regular_func(msg)
    puts("Regular: " .. msg)
end
regular_func(f"Hello {name}")

puts("\n=== Expected output above: ===")
puts("# Test 2 should show: Received: Hello Alice from NYC")
puts("# But it shows error or nothing!")
