# Test 4: Function that receives callback but doesn't call it

fun my_function(name, callback)
    puts("my_function called: " .. name)
    puts("Callback received but NOT called")
    # callback()  # <-- NOT calling it
end

puts("Test 4: Passing callback without calling it")

my_function("test", fun ()
    puts("Inside callback")
end)

puts("Test 4: Completed successfully")
