#!/usr/bin/env quest
# Demonstrates ticks_ms() for performance measurement

puts("=== ticks_ms() Demo ===")
puts()

# Show that ticks start at 0
puts("Program start (ticks at beginning):", ticks_ms(), "ms")
puts()

# Measure a simple loop
puts("Measuring loop performance...")
let start = ticks_ms()
let sum = 0
let i = 0
while i < 100000
    sum = sum + i
    i = i + 1
end
let finish = ticks_ms()
puts("Loop completed in:", finish - start, "ms")
puts("Sum:", sum)
puts()

# Measure multiple operations
puts("Measuring string operations...")
let start2 = ticks_ms()
let s = ""
let j = 0
while j < 1000
    s = s .. "x"
    j = j + 1
end
let finish2 = ticks_ms()
puts("String concatenation (1000x) took:", finish2 - start2, "ms")
puts("Final string length:", s.len())
puts()

puts("Total runtime so far:", ticks_ms(), "ms")
