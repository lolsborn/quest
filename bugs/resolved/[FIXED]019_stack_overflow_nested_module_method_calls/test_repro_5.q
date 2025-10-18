# Test 5: Calling a callback that's a named function (not lambda)

fun my_callback()
    puts("Inside named callback function")
end

fun my_function(name, callback)
    puts("my_function called: " .. name)
    callback()
end

puts("Test 5: Using named function as callback")

my_function("test", my_callback)

puts("Test 5: Completed successfully")
