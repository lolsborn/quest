# Test 3: Regular function (not from module) that takes a callback

fun my_function(name, callback)
    puts("my_function called: " .. name)
    callback()
end

puts("Test 3: Non-module function with callback")

my_function("test", fun ()
    puts("Inside callback")
end)

puts("Test 3: Completed successfully")
