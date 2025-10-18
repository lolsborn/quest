# Test 7: Most basic case - one function calling another

fun helper()
    puts("Helper function")
end

fun main_fn()
    puts("Main function")
    helper()
end

puts("Test 7: Basic function calling another function")

main_fn()

puts("Test 7: Completed successfully")
