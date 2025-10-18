# Test 2: Module method call WITHOUT nested call
# Just the outer call with no inner module reference

use "test_module" as mod

puts("Test 2: Module method with callback that doesn't call module methods")

mod.outer("test group", fun ()
    puts("Inside callback - no module calls")
    let x = 1 + 1
    puts("Result: " .. x.str())
end)

puts("Test 2: Completed successfully")
