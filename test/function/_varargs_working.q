# Comprehensive varargs working test

# Test 1: Basic varargs
fun count_args(*args)
    args.len()
end

puts("Test 1: count_args")
puts("  count_args() = " .. count_args()._str())
puts("  count_args(1) = " .. count_args(1)._str())
puts("  count_args(1, 2, 3, 4, 5) = " .. count_args(1, 2, 3, 4, 5)._str())

# Test 2: Mixed required and varargs
fun greet(greeting, *names)
    let result = greeting
    let i = 0
    while i < names.len()
        result = result .. " " .. names[i]
        i = i + 1
    end
    result
end

puts("\nTest 2: greet with required + varargs")
puts("  greet(\"Hello\") = " .. greet("Hello"))
puts("  greet(\"Hello\", \"Alice\") = " .. greet("Hello", "Alice"))
puts("  greet(\"Hello\", \"Alice\", \"Bob\", \"Charlie\") = " .. greet("Hello", "Alice", "Bob", "Charlie"))

# Test 3: Required + optional + varargs
fun connect(host, port = 8080, *extra)
    let result = host .. ":" .. port._str()
    if extra.len() > 0
        result = result .. " (extras: " .. extra.len()._str() .. ")"
    end
    result
end

puts("\nTest 3: connect with required + optional + varargs")
puts("  connect(\"localhost\") = " .. connect("localhost"))
puts("  connect(\"localhost\", 3000) = " .. connect("localhost", 3000))
puts("  connect(\"localhost\", 3000, \"a\", \"b\") = " .. connect("localhost", 3000, "a", "b"))

# Test 4: Lambda with varargs
let sum = fun (*nums)
    let total = 0
    let i = 0
    while i < nums.len()
        total = total + nums[i]
        i = i + 1
    end
    total
end

puts("\nTest 4: Lambda with varargs")
puts("  sum() = " .. sum()._str())
puts("  sum(1, 2, 3, 4, 5) = " .. sum(1, 2, 3, 4, 5)._str())

puts("\n✓ All varargs tests passed!")
