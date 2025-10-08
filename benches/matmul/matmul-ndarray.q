#!/usr/bin/env quest
# Matrix multiplication using Quest's NDArray module

use "std/ndarray" as np
use "std/sys" as sys

# Build matrix as nested array, then convert to NDArray
fun build_matrix(n, seed)
    let tmp = seed / n.to_f64() / n.to_f64()
    let matrix = []
    let i = 0
    while i < n
        let row = []
        let j = 0
        while j < n
            let i_f = i.to_f64()
            let j_f = j.to_f64()
            row.push(tmp * (i_f - j_f) * (i_f + j_f))
            j = j + 1
        end
        matrix.push(row)
        i = i + 1
    end
    np.array(matrix)
end

# Matrix multiplication using ndarray.dot()
fun matmul(a, b)
    a.dot(b)
end

# Calculate result
fun calc(n)
    # Ensure n is even
    let n_even = (n / 2) * 2
    let a = build_matrix(n_even, 1.0)
    let b = build_matrix(n_even, 2.0)
    let d = matmul(a, b)
    d.get([n_even / 2, n_even / 2])
end

# Main
let n = 100
if sys.argc > 1
    n = sys.argv[1].to_int()
end

# Verify correctness
let left = calc(101)
let right = -18.67
if (left - right).abs() > 0.1
    sys.fail(left.str() .. " != " .. right.str())
end

# Run benchmark
let results = calc(n)

puts(results)
