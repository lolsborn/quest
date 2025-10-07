# Simplest possible varargs test

fun get_args(*args)
    args
end

puts("Test 1: No args")
let result1 = get_args()
puts("Length: " .. result1.len()._str())

puts("\nTest 2: One arg")
let result2 = get_args(42)
puts("Length: " .. result2.len()._str())
puts("First: " .. result2[0]._str())

puts("\nTest 3: Multiple args")
let result3 = get_args(1, 2, 3)
puts("Length: " .. result3.len()._str())
puts("First: " .. result3[0]._str())
puts("Second: " .. result3[1]._str())
puts("Third: " .. result3[2]._str())

puts("\nAll tests passed!")
