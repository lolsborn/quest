# Varargs sum test

fun sum(*nums)
    nums.reduce(0, fun (acc, n) acc + n end)
end

puts("sum() = " .. sum().str())
puts("sum(1) = " .. sum(1).str())
puts("sum(1, 2, 3) = " .. sum(1, 2, 3).str())
puts("sum(1, 2, 3, 4, 5) = " .. sum(1, 2, 3, 4, 5).str())

fun greet(greeting, *names)
    let result = greeting
    names.each(fun (name) result = result .. " " .. name end)
    result
end

puts("\ngreet(\"Hello\") = " .. greet("Hello"))
puts("greet(\"Hello\", \"Alice\") = " .. greet("Hello", "Alice"))
puts("greet(\"Hello\", \"Alice\", \"Bob\") = " .. greet("Hello", "Alice", "Bob"))

fun connect(host, port = 8080, *extra)
    host .. ":" .. port.str() .. " (extras: " .. extra.len().str() .. ")"
end

puts("\nconnect(\"localhost\") = " .. connect("localhost"))
puts("connect(\"localhost\", 3000) = " .. connect("localhost", 3000))
puts("connect(\"localhost\", 3000, \"x\", \"y\") = " .. connect("localhost", 3000, "x", "y"))

puts("\nAll tests passed!")
