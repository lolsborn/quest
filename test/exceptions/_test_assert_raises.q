# Test assert_raises() with exception handling

use "std/test" as test

puts("Testing assert_raises()")

# Test 1: Verify exception is raised
puts("\nTest 1: Exception is raised properly")
test.assert_raises("Error", fun()
    raise "something went wrong"
end, nil)
puts("✓ assert_raises caught expected exception")

# Test 2: Exception objects have properties
puts("\nTest 2: Exception object properties")
try
    raise "test message"
catch ex
    puts("  Type: " .. ex.type())
    puts("  Message: " .. ex.message())
end
puts("✓ Exception properties work")

puts("\nAll assert_raises tests passed!")
