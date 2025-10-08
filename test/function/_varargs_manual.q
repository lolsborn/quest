# Manual test for varargs

fun sum(*nums)
    let total = 0
    for n in nums
        total = total + n
    end
    total
end

puts("Testing varargs:")
puts("sum() = " .. sum().str())
puts("sum(1) = " .. sum(1).str())
puts("sum(1, 2, 3) = " .. sum(1, 2, 3).str())
puts("sum(1, 2, 3, 4, 5) = " .. sum(1, 2, 3, 4, 5).str())

fun greet(greeting, *names)
    let result = greeting
    for name in names
        result = result .. " " .. name
    end
    result
end

puts("\nTesting mixed params + varargs:")
puts("greet(\"Hello\") = " .. greet("Hello"))
puts("greet(\"Hello\", \"Alice\") = " .. greet("Hello", "Alice"))
puts("greet(\"Hello\", \"Alice\", \"Bob\") = " .. greet("Hello", "Alice", "Bob"))

fun connect(host, port = 8080, *extra)
    host .. ":" .. port.str() .. " (extras: " .. extra.len().str() .. ")"
end

puts("\nTesting required + optional + varargs:")
puts("connect(\"localhost\") = " .. connect("localhost"))
puts("connect(\"localhost\", 3000) = " .. connect("localhost", 3000))
puts("connect(\"localhost\", 3000, \"x\", \"y\") = " .. connect("localhost", 3000, "x", "y"))

puts("\nAll tests passed!")
