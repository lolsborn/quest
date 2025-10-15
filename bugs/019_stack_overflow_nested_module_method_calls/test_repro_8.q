# Test 8: Built-in method calls inside a function

fun test_builtin()
    puts("Testing built-in methods")
    let x = "hello"
    let y = x.len()
    puts("Length: " .. y.str())
end

puts("Test 8: Built-in method calls")

test_builtin()

puts("Test 8: Completed successfully")
