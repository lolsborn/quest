# Test 6: Direct function calls (not passed as callbacks)

fun my_callback()
    puts("Inside callback function")
end

fun my_function(name)
    puts("my_function called: " .. name)
    my_callback()  # Direct call, not through parameter
end

puts("Test 6: Direct function call (not as callback)")

my_function("test")

puts("Test 6: Completed successfully")
