# Test 1: Custom module with nested method calls
# Mimics the std/test pattern without the complexity

use "test_module" as mod

puts("Test 1: About to call mod.outer()")

mod.outer("test group", fun ()
    puts("Inside outer callback")
    mod.inner("test case")
end)

puts("Test 1: Completed successfully")
