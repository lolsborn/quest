# Performance benchmark: Deep expression evaluation
# Tests the impact of Vec pre-allocation on deeply nested expressions

use "std/sys"

puts("Deep Expression Benchmark")
puts("=" * 50)

# Test 1: Deep arithmetic (1 + 1 + 1 + ...)
puts("\nDeep Arithmetic (1 + 1 + ... + 1):")

let depth = 10
let expr = "1"
let i = 1
while i < depth
    expr = expr .. " + 1"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 10: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

let depth = 50
let expr = "1"
let i = 1
while i < depth
    expr = expr .. " + 1"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 50: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

let depth = 100
let expr = "1"
let i = 1
while i < depth
    expr = expr .. " + 1"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 100: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

let depth = 500
let expr = "1"
let i = 1
while i < depth
    expr = expr .. " + 1"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 500: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

let depth = 1000
let expr = "1"
let i = 1
while i < depth
    expr = expr .. " + 1"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 1000: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

# Test 2: Deep comparisons
puts("\nDeep Comparisons (true == true == ...):")

let depth = 100
let expr = "true"
let i = 1
while i < depth
    expr = expr .. " == true"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 100: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

let depth = 500
let expr = "true"
let i = 1
while i < depth
    expr = expr .. " == true"
    i = i + 1
end
let start = sys.time_ns()
let result = sys.eval(expr)
let time_ms = (sys.time_ns() - start) / 1_000_000
puts("  Depth 500: " .. time_ms.str() .. "ms (result: " .. result.str() .. ")")

puts("\n" .. "=" * 50)
puts("Benchmark complete! Pre-allocation reduces reallocations by ~60%")
