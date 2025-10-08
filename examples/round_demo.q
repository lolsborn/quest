#!/usr/bin/env quest
# Demonstrates math.round(n, places)

use "std/math" as math

puts("=== math.round() Demo ===")
puts()

puts("Round to nearest integer:")
puts("  math.round(3.7) =", math.round(3.7))
puts("  math.round(3.2) =", math.round(3.2))
puts("  math.round(3.5) =", math.round(3.5))
puts()

puts("Round to decimal places:")
puts("  math.round(3.14159, 2) =", math.round(3.14159, 2))
puts("  math.round(3.14159, 4) =", math.round(3.14159, 4))
puts("  math.round(123.456, 1) =", math.round(123.456, 1))
puts("  math.round(123.456, 0) =", math.round(123.456, 0))
puts()

puts("Practical examples:")
let price = 19.995
puts("  Price: $" .. math.round(price, 2).str())

let percentage = 66.666666
puts("  Percentage:", math.round(percentage, 1).str() .. "%")

let measurement = 12.3456789
puts("  Measurement:", math.round(measurement, 3).str(), "cm")
puts()

puts("Floating point precision:")
let imprecise = 0.1 + 0.2
puts("  0.1 + 0.2 =", imprecise)
puts("  Rounded to 10 places:", math.round(imprecise, 10))
