# Simple test of iterative evaluator
puts("Testing iterative evaluator:")

# Test literals
puts("nil: " .. nil.str())
puts("true: " .. true.str())
puts("false: " .. false.str())
puts("42: " .. 42.str())
puts("3.14: " .. 3.14.str())
puts("hello: " .. "hello")

# Test addition
puts("1 + 2 = " .. (1 + 2).str())
puts("10 - 3 = " .. (10 - 3).str())
puts("1 + 2 + 3 = " .. (1 + 2 + 3).str())
