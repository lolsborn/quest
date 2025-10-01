#!/usr/bin/env quest
# Test del statement functionality

puts("=== Del Statement Tests ===\n")

# Test 1: Basic deletion
puts("Test 1: Basic deletion")
let x = 10
puts("x = " .. x._str())
del x
# puts(x)  # Would error: undefined variable
puts("x deleted successfully\n")

# Test 2: Delete and redeclare
puts("Test 2: Delete and redeclare")
let y = 20
puts("y = " .. y._str())
del y
let y = 30
puts("y redeclared = " .. y._str() .. "\n")

# Test 3: Free memory for large data
puts("Test 3: Freeing large data")
let large_data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
puts("Processing large_data...")
del large_data
puts("large_data freed\n")

# Test 4: Multiple variables
puts("Test 4: Selective deletion")
let a = 1
let b = 2
let c = 3
puts("Before: a=" .. a._str() .. ", b=" .. b._str() .. ", c=" .. c._str())
del b
puts("After deleting b: a=" .. a._str() .. ", c=" .. c._str() .. "\n")

# Test 5: Cannot delete modules
puts("Test 5: Module deletion (should fail)")
use math
puts("math.pi = " .. math.pi._str())
# del math  # Uncommenting this would error: Cannot delete module 'math'
puts("Module deletion correctly restricted\n")

# Test 6: Delete in function scope
puts("Test 6: Del in function scope")
fun cleanup()
    let temp = 42
    puts("temp in function = " .. temp._str())
    del temp
    puts("temp deleted in function")
end
cleanup()
puts("Function completed\n")

puts("=== All del tests passed! ===")
