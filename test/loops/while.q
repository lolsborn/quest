# While Loop Tests
# Tests basic while loop functionality

use "std/test" as test

test.describe("While Loop - Basic", fun ()
    test.it("loops with counter", fun ()
        let i = 0
        let count = 0
        while i < 3
            count = count + 1
            i = i + 1
        end
        test.assert_eq(count, 3, nil)
        test.assert_eq(i, 3, nil)
    end)

    test.it("accumulates values", fun ()
        let sum = 0
        let i = 1
        while i <= 5
            sum = sum + i
            i = i + 1
        end
        test.assert_eq(sum, 15, nil)
    end)

    test.it("executes zero times when condition is false", fun ()
        let executed = false
        while false
            executed = true
        end
        test.assert(!executed, nil)
    end)

    test.it("executes once when condition becomes false", fun ()
        let i = 0
        let count = 0
        while i < 1
            count = count + 1
            i = i + 1
        end
        test.assert_eq(count, 1, nil)
    end)
end)

test.describe("While Loop - Conditions", fun ()
    test.it("uses comparison in condition", fun ()
        let x = 10
        let result = 0
        while x > 5
            result = result + 1
            x = x - 1
        end
        test.assert_eq(result, 5, nil)
        test.assert_eq(x, 5, nil)
    end)

    test.it("uses logical and in condition", fun ()
        let x = 0
        let y = 0
        while x < 3 and y < 3
            x = x + 1
            y = y + 1
        end
        test.assert_eq(x, 3, nil)
        test.assert_eq(y, 3, nil)
    end)

    test.it("uses logical or in condition", fun ()
        let x = 0
        let y = 0
        while x < 3 or y < 2
            x = x + 1
            y = y + 1
        end
        test.assert_eq(x, 3, nil)
        test.assert_eq(y, 3, nil)
    end)

    test.it("uses negation in condition", fun ()
        let done = false
        let count = 0
        while !done
            count = count + 1
            if count >= 3
                done = true
            end
        end
        test.assert_eq(count, 3, nil)
    end)
end)

test.describe("While Loop - Nested", fun ()
    test.it("nests while loops", fun ()
        let outer = 0
        let total = 0
        while outer < 3
            let inner = 0
            while inner < 2
                total = total + 1
                inner = inner + 1
            end
            outer = outer + 1
        end
        test.assert_eq(total, 6, nil)
    end)

    test.it("inner loop doesn't affect outer", fun ()
        let i = 0
        let j_total = 0
        while i < 3
            let j = 0
            while j < 2
                j = j + 1
                j_total = j_total + j
            end
            i = i + 1
        end
        test.assert_eq(i, 3, nil)
        test.assert_eq(j_total, 9, nil)
    end)
end)

test.describe("While Loop - Scope", fun ()
    test.it("loop body has own scope", fun ()
        let outer_var = 10
        let i = 0
        while i < 2
            let inner_var = 20
            i = i + 1
        end
        # inner_var not accessible here
        test.assert_eq(outer_var, 10, nil)
    end)

    test.it("modifies outer scope variables", fun ()
        let x = 0
        while x < 5
            x = x + 1
        end
        test.assert_eq(x, 5, nil)
    end)

    test.it("declares variables in loop body", fun ()
        let sum = 0
        let i = 0
        while i < 3
            let val = i * 2
            sum = sum + val
            i = i + 1
        end
        test.assert_eq(sum, 6, nil)
    end)
end)

test.describe("While Loop - Edge Cases", fun ()
    test.it("handles large iteration count", fun ()
        let i = 0
        while i < 100
            i = i + 1
        end
        test.assert_eq(i, 100, nil)
    end)

    test.it("works with complex condition updates", fun ()
        let x = 1
        while x < 10
            x = x * 2
        end
        test.assert_eq(x, 16, nil)
    end)

    test.it("condition evaluated each iteration", fun ()
        let numbers = [1, 2, 3]
        let i = 0
        while i < numbers.len()
            i = i + 1
        end
        test.assert_eq(i, 3, nil)
    end)

    test.it("works with function calls in condition", fun ()
        fun should_continue(n)
            n < 5
        end

        let x = 0
        while should_continue(x)
            x = x + 1
        end
        test.assert_eq(x, 5, nil)
    end)
end)

test.describe("While Loop - Array Processing", fun ()
    test.it("processes array elements", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let i = 0
        let sum = 0
        while i < numbers.len()
            sum = sum + numbers[i]
            i = i + 1
        end
        test.assert_eq(sum, 15, nil)
    end)

    test.it("builds array in loop", fun ()
        let result = []
        let i = 0
        while i < 3
            result = result.push(i * 2)
            i = i + 1
        end
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], 0, nil)
        test.assert_eq(result[1], 2, nil)
        test.assert_eq(result[2], 4, nil)
    end)
end)

test.describe("While Loop - Dictionary Processing", fun ()
    test.it("processes dictionary keys", fun ()
        let d = {"a": 1, "b": 2, "c": 3}
        let keys = d.keys()
        let i = 0
        let sum = 0
        while i < keys.len()
            sum = sum + d[keys[i]]
            i = i + 1
        end
        test.assert_eq(sum, 6, nil)
    end)
end)

test.run()
