#!/usr/bin/env quest
# Example: Using time.ticks_ms() for performance logging

use "std/time" as time

puts("=== Performance Logging Example ===")
puts()

# Simple timing wrapper function
fun time_operation(name, operation)
    let start = time.ticks_ms()
    let result = operation()
    let elapsed = time.ticks_ms() - start
    puts("[PERF]", name, "completed in", elapsed, "ms")
    return result
end

# Example 1: Time a computation
puts("Example 1: Timing a computation")
time_operation("Sum calculation", fun ()
    let sum = 0
    let i = 0
    while i < 100000
        sum = sum + i
        i = i + 1
    end
    return sum
end)
puts()

# Example 2: Time string operations
puts("Example 2: Timing string operations")
time_operation("String building", fun ()
    let s = ""
    let i = 0
    while i < 1000
        s = s .. "x"
        i = i + 1
    end
    return s.len()
end)
puts()

# Example 3: Compare different approaches
puts("Example 3: Comparing array operations")

let start1 = time.ticks_ms()
let arr1 = []
let i = 0
while i < 1000
    arr1 = arr1.push(i)
    i = i + 1
end
let time1 = time.ticks_ms() - start1
puts("Method 1 (push):", time1, "ms")

let start2 = time.ticks_ms()
let arr2 = []
let j = 0
while j < 1000
    arr2 = arr2.push(j * 2)
    j = j + 1
end
let time2 = time.ticks_ms() - start2
puts("Method 2 (push with calculation):", time2, "ms")

puts()
puts("Total execution time:", time.ticks_ms(), "ms")
