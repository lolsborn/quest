#!/usr/bin/env quest

use "std/sys"

let UPPER_BOUND = 5000000
let PREFIX = 32338

# Sieve type for Atkin sieve algorithm
type Sieve
    limit: Int
    prime: Array

    fun self.create(limit)
        let prime: Array = Array.new(limit + 1, false)
        Sieve.new(limit: limit, prime: prime)
    end

    fun to_list()
        let result = [2, 3]
        let prime_array = self.prime
        let limit = self.limit
        let p = 5
        while p <= limit
            if prime_array[p]
                result.push(p)
            end
            p = p + 1
        end
        result
    end

    fun omit_squares()
        let prime_array = self.prime
        let limit = self.limit
        let r = 5
        while r * r < limit
            if prime_array[r]
                let r_squared = r * r
                let i = r_squared
                while i < limit
                    prime_array[i] = false
                    i = i + r_squared
                end
            end
            r = r + 1
        end
        self
    end

    fun loop_y(x)
        let prime_array = self.prime
        let limit = self.limit
        let y = 1
        while y * y < limit
            # Inline step1
            let n1 = (4 * x * x) + (y * y)
            if n1 <= limit and (n1 % 12 == 1 or n1 % 12 == 5)
                prime_array[n1] = not prime_array[n1]
            end

            # Inline step2
            let n2 = (3 * x * x) + (y * y)
            if n2 <= limit and n2 % 12 == 7
                prime_array[n2] = not prime_array[n2]
            end

            # Inline step3
            let n3 = (3 * x * x) - (y * y)
            if x > y and n3 <= limit and n3 % 12 == 11
                prime_array[n3] = not prime_array[n3]
            end

            y = y + 1
        end
    end

    fun loop_x()
        let limit = self.limit
        let x = 1
        while x * x < limit
            self.loop_y(x)
            x = x + 1
        end
    end

    fun calc()
        self.loop_x()
        self.omit_squares()
    end
end

# Find all primes with given prefix (simplified without trie)
fun find(upper_bound, prefix)
    let sieve = Sieve.create(upper_bound)
    let primes = sieve.calc()
    let prime_list = primes.to_list()

    # Filter primes that start with prefix
    let str_prefix = prefix.str()
    prime_list.filter(fun (p)
        let prime_str = p.str()
        prime_str.len() >= str_prefix.len() and prime_str.startswith(str_prefix)
    end)
end

# Verify correctness
fun verify()
    let left = [2, 23, 29]
    let right = find(100, 2)
    if left != right
        sys.fail("Verification failed: " .. left.str() .. " != " .. right.str())
    end
end

# Main
verify()
let results = find(UPPER_BOUND, PREFIX)
puts(results)
