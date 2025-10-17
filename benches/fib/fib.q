#!/usr/bin/env quest

use "std/sys"

# Recursive Fibonacci (naive implementation for benchmarking)
fun fib(n)
    if n <= 1
        return n
    end
    fib(n - 1) + fib(n - 2)
end

# Verify correctness with small input
fun verify()
    let expected = [0, 1, 1, 2, 3, 5, 8, 13, 21, 34]
    let i = 0
    while i < expected.len()
        let result = fib(i)
        if result != expected[i]
            sys.fail("Verification failed: fib(" .. i.str() .. ") = " .. result.str() .. ", expected " .. expected[i].str())
        end
        i = i + 1
    end
end

# Main benchmark
verify()
let n = 35
let result = fib(n)
puts("fib(" .. n.str() .. ") = " .. result.str())
