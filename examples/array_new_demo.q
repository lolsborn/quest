# Array.new() - Ruby-style bulk array initialization
#
# Demonstrates efficient creation of large arrays with repeated values
# This is much faster than using loops to populate arrays.

puts("=== Array.new() Demo ===\n")

# Empty array
puts("1. Empty array:")
let arr1 = Array.new()
puts("   Array.new() => " .. arr1.str())
puts("   Length: " .. arr1.len().str() .. "\n")

# Array of nil values
puts("2. Array of nil values:")
let arr2 = Array.new(5)
puts("   Array.new(5) => " .. arr2.str())
puts("   All elements are nil\n")

# Array of repeated values
puts("3. Array of repeated values:")
let arr3 = Array.new(3, "hello")
puts("   Array.new(3, \"hello\") => " .. arr3.str())
puts("")

# Practical example: Boolean flags
puts("4. Boolean flags array:")
let flags = Array.new(10, false)
puts("   Array.new(10, false) => " .. flags.str())
flags[3] = true
flags[7] = true
puts("   After setting flags[3] and flags[7] to true:")
puts("   " .. flags.str() .. "\n")

# Large array performance
puts("5. Large array creation:")
puts("   Creating 1,000,000 element array...")
let big_arr = Array.new(1000000, 0)
puts("   Success! Length: " .. big_arr.len().str())
puts("   First: " .. big_arr.first().str() .. ", Last: " .. big_arr.last().str() .. "\n")

# Comparison with manual initialization (for small arrays)
puts("6. Equivalent to manual initialization:")
puts("   Array.new(5, 42) is much faster than:")
puts("   let arr = []")
puts("   arr.push(42).push(42).push(42).push(42).push(42)")
let manual = []
manual.push(42).push(42).push(42).push(42).push(42)
let efficient = Array.new(5, 42)
puts("   Manual: " .. manual.str())
puts("   Array.new(5, 42): " .. efficient.str())
puts("   Both produce the same result, but Array.new() is much faster!\n")

# Use case: Initialize grid/matrix
puts("7. Initialize a grid (nested arrays):")
let grid = Array.new(3, 0)  # Can't nest Array.new() directly yet
grid[0] = [0, 0, 0]
grid[1] = [0, 0, 0]
grid[2] = [0, 0, 0]
puts("   3x3 grid: " .. grid.str())
