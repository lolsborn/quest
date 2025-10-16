fun test()
    puts("In function")
    return 42
    puts("After return in function")
end

puts("Before function call")
let result = test()
puts("Result: " .. result.str())

# Test return with value at top level
puts("Top level before return")
return 99
puts("Top level after return")
