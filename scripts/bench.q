#!/usr/bin/env quest
# Simple Profiling Benchmark
#
# A focused benchmark script for profiling Quest's performance
#
# Usage:
#   ./scripts/profile-cpu.sh scripts/bench.q
#   ./scripts/profile-memory.sh scripts/bench.q

use "std/math" as math
use "std/encoding/json" as json
use "std/hash" as hash

puts("=== Quest Benchmark ===")
puts("")

# Arithmetic - lots of integer operations
fun bench_arithmetic()
    puts("1. Arithmetic (10000 iterations)")

    let sum = 0
    let i = 0
    while i < 10000
        sum = sum + (i * 3) - (i % 7) + (i / 2)
        i = i + 1
    end

    puts("   Result: " .. sum)
end

# String operations - concatenation and methods
fun bench_strings()
    puts("2. Strings (5000 iterations)")

    let text = "Hello"
    let upper = ""
    let len = 0
    let i = 0
    while i < 5000
        text = "Quest " .. i.to_string()
        upper = text.upper()
        len = text.len()
        i = i + 1
    end

    puts("   Final: " .. text)
end

# Arrays - creation, methods, iteration
fun bench_arrays()
    puts("3. Arrays (create 1000, map/filter/reduce)")

    # Create array (arrays are mutable)
    let arr = []
    let i = 0
    while i < 1000
        arr.push(i)  # Mutates in place, returns nil
        i = i + 1
    end

    # Map
    let doubled = arr.map(fun (x) x * 2 end)

    # Filter
    let evens = arr.filter(fun (x) x % 2 == 0 end)

    # Reduce
    let sum = arr.reduce(fun (acc, x) acc + x end, 0)

    puts("   Sum: " .. sum .. ", Evens: " .. evens.len())
end

# Dictionaries - creation and access
fun bench_dicts()
    puts("4. Dictionaries (500 entries)")

    let map = {}
    let i = 0
    while i < 500
        let key = "k" .. i.to_string()
        map[key] = i * i
        i = i + 1
    end

    # Access
    let sum = 0
    let j = 0
    while j < 500
        let key = "k" .. j.to_string()
        sum = sum + map.get(key)
        j = j + 1
    end

    puts("   Keys: " .. map.len() .. ", Sum: " .. sum)
end

# Recursion - fibonacci
fun fib(n)
    if n <= 1
        n
    else
        fib(n - 1) + fib(n - 2)
    end
end

fun bench_recursion()
    puts("5. Recursion (fibonacci 25)")

    let result = fib(25)

    puts("   Result: " .. result)
end

# JSON - encode/decode cycles
fun bench_json()
    puts("6. JSON (500 encode/decode cycles)")

    let data = {
        "name": "Quest",
        "version": "0.1.0",
        "numbers": [1, 2, 3, 4, 5],
        "nested": { "a": 1, "b": 2 }
    }

    let i = 0
    while i < 500
        let encoded = json.stringify(data)
        let decoded = json.parse(encoded)
        i = i + 1
    end

    puts("   Complete")
end

# Hashing - multiple hash algorithms
fun bench_hashing()
    puts("7. Hashing (1000 iterations)")

    let text = "The quick brown fox jumps over the lazy dog"
    let i = 0
    while i < 1000
        let m = hash.md5(text)
        let s1 = hash.sha1(text)
        let s256 = hash.sha256(text)
        i = i + 1
    end

    puts("   Complete")
end

# Math operations - trig and sqrt
fun bench_math()
    puts("8. Math (2000 sin/cos/sqrt operations)")

    let sum = 0.0
    let i = 0
    while i < 2000
        let angle = (i.to_f64() / 100.0) * math.pi
        let s = math.sin(angle)
        let c = math.cos(angle)
        let sq = math.sqrt(i.to_f64())
        sum = sum + s + c + sq
        i = i + 1
    end

    puts("   Sum: " .. sum.to_string())
end

# Control flow - loops and conditionals
fun is_prime(n)
    if n < 2
        false
    else
        let i = 2
        let result = true
        while i <= (n / 2)
            if n % i == 0
                result = false
            end
            i = i + 1
        end
        result
    end
end

fun bench_control()
    puts("9. Control flow (primes up to 200)")

    let count = 0
    let i = 2
    while i <= 200
        if is_prime(i)
            count = count + 1
        end
        i = i + 1
    end

    puts("   Primes found: " .. count)
end

# Closures - higher-order functions
fun make_multiplier(n)
    fun (x) n * x end
end

fun bench_closures()
    puts("10. Closures (5000 iterations)")

    let mul5 = make_multiplier(5)
    let mul10 = make_multiplier(10)

    let sum = 0
    let i = 0
    while i < 5000
        sum = sum + mul5(i) + mul10(i)
        i = i + 1
    end

    puts("   Sum: " .. sum)
end

# User-defined types
type Point
    x: Int
    y: Int

    fun magnitude()
        let dx = self.x * self.x
        let dy = self.y * self.y
        math.sqrt((dx + dy).to_f64())
    end
end

fun bench_types()
    puts("11. User types (create 1000 points)")

    let points = []
    let i = 0
    while i < 1000
        let p = Point.new(i, i * 2)
        points.push(p)  # Mutates in place, returns nil
        i = i + 1
    end

    let total = 0.0
    let j = 0
    while j < points.len()
        total = total + points[j].magnitude()
        j = j + 1
    end

    puts("   Points: " .. points.len() .. ", Total dist: " .. total.to_string())
end

# Run all benchmarks
puts("Starting...")
puts("")

bench_arithmetic()
bench_strings()
bench_arrays()
bench_dicts()
bench_recursion()
bench_json()
bench_hashing()
bench_math()
bench_control()
bench_closures()
bench_types()

puts("")
puts("=== Complete ===")
