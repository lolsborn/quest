#!/usr/bin/env quest
# Written by Steven Osborn; distributed under the MIT license
# Quest implementation

use "std/sys"

# Transpose matrix b for cache-efficient access
fun transposed(n_size, p_size, matrix_b)
    let b2 = []
    let i = 0
    while i < n_size
        let row = []
        let j = 0
        while j < p_size
            row.push(0.0)
            j = j + 1
        end
        b2.push(row)
        i = i + 1
    end

    let i2 = 0
    while i2 < n_size
        let j2 = 0
        while j2 < p_size
            let row = b2[j2]
            row[i2] = matrix_b[i2][j2]
            j2 = j2 + 1
        end
        i2 = i2 + 1
    end
    b2
end

# Perform matrix multiplication
fun multiplication(m_size, n_size, p_size, matrix_a, matrix_b2)
    let c = []
    let i = 0
    while i < m_size
        let row = []
        let j = 0
        while j < p_size
            row.push(0.0)
            j = j + 1
        end
        c.push(row)
        i = i + 1
    end

    let i2 = 0
    while i2 < m_size
        let j2 = 0
        while j2 < p_size
            let ai = matrix_a[i2]
            let b2j = matrix_b2[j2]
            let s = 0.0
            let k = 0
            while k < n_size
                s = s + (ai[k] * b2j[k])
                k = k + 1
            end
            let row = c[i2]
            row[j2] = s
            j2 = j2 + 1
        end
        i2 = i2 + 1
    end
    c
end

# Matrix multiplication: A × B
fun matmul(matrix_a, matrix_b)
    let m = matrix_a.len()
    let n = matrix_a[0].len()
    let p = matrix_b[0].len()

    # Transpose b
    let b2 = transposed(n, p, matrix_b)

    # Multiply
    multiplication(m, n, p, matrix_a, b2)
end

# Generate matrix with specific seed
fun matgen(num, seed)
    let tmp = seed / num.to_f64() / num.to_f64()
    let a = []
    let i = 0
    while i < num
        let row = []
        let j = 0
        while j < num
            let i_f = i.to_f64()
            let j_f = j.to_f64()
            row.push(tmp * (i_f - j_f) * (i_f + j_f))
            j = j + 1
        end
        a.push(row)
        i = i + 1
    end
    a
end

# Calculate result
fun calc(n)
    # Ensure n is even
    let n_even = (n / 2) * 2
    let a = matgen(n_even, 1.0)
    let b = matgen(n_even, 2.0)
    let c = matmul(a, b)
    c[n_even / 2][n_even / 2]
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
