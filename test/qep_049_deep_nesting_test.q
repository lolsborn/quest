# QEP-049: Deep Nesting Prevention Tests
# Tests that the iterative evaluator handles deep nesting without stack overflow

use "std/test" as test
use "std/sys" as sys

test.module("QEP-049: Deep Nesting Prevention")

test.describe("Deeply nested arithmetic", fun ()
    test.it("handles 100 levels of nested additions", fun ()
        let result = ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            ((((((((((
            1
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)
            + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1) + 1)

        test.assert_eq(result, 101, "100 levels of nesting should work")
    end)

    test.it("handles 1000 levels via sys.eval", fun ()
        let depth = 1000
        let expr = "1"
        let i = 0
        while i < depth
            expr = "(" .. expr .. " + 1)"
            i = i + 1
        end

        let result = sys.eval(expr)
        test.assert_eq(result, 1001, "1000 levels should evaluate correctly")
    end)
end)

test.describe("Deeply nested boolean expressions", fun ()
    test.it("handles nested AND operations", fun ()
        let result = ((true and true) and (true and true)) and
                     ((true and true) and (true and true))
        test.assert_eq(result, true, "Nested AND should work")
    end)

    test.it("handles nested OR operations", fun ()
        let result = ((true or false) or (false or false)) or
                     ((false or false) or (false or true))
        test.assert_eq(result, true, "Nested OR should work")
    end)

    test.it("handles mixed logical operators", fun ()
        let result = ((true and true) or (false and true)) and
                     ((true or false) and (true and true))
        test.assert_eq(result, true, "Mixed logical operators should work")
    end)
end)

test.describe("Deeply nested string concatenation", fun ()
    test.it("handles nested string concat", fun ()
        let result = (("a" .. "b") .. ("c" .. "d")) ..
                     ((("e" .. "f") .. "g") .. (("h" .. "i") .. "j"))
        test.assert_eq(result, "abcdefghij", "Nested concat should work")
    end)
end)

test.describe("Deeply nested comparisons", fun ()
    test.it("handles nested equality checks", fun ()
        let result = ((1 == 1) == true) and ((2 == 2) == true)
        test.assert_eq(result, true, "Nested comparisons should work")
    end)

    test.it("handles nested ordering checks", fun ()
        let result = ((1 < 2) and (2 < 3)) and ((3 < 4) and (4 < 5))
        test.assert_eq(result, true, "Nested ordering should work")
    end)
end)

test.describe("Complex nested expressions", fun ()
    test.it("handles mixed operators", fun ()
        let result = (((1 + 2) * 3 - 4) * ((5 + 6) * (7 - 8))) +
                     (((9 * 10) - (11 + 12)) * ((13 - 14) + (15 * 16)))
        test.assert_eq(result, 15958, "Complex mixed operators should work")
    end)

    test.it("handles method calls in nested expressions", fun ()
        let arr = [1, 2, 3]
        let arr2 = [4, 5, 6]
        let result = (arr.len() + arr2.len()) * (arr.get(0) + arr2.get(0))
        test.assert_eq(result, 30, "Method calls in expressions should work")
    end)
end)

test.describe("Nested if statements", fun ()
    test.it("handles deeply nested if statements", fun ()
        let x = 5
        let result = "none"

        if x > 0
            if x > 1
                if x > 2
                    if x > 3
                        if x > 4
                            if x > 5
                                result = "too deep"
                            else
                                result = "depth 6"
                            end
                        end
                    end
                end
            end
        end

        test.assert_eq(result, "depth 6", "10 levels of nested ifs should work")
    end)

    test.it("handles complex conditions in nested ifs", fun ()
        let x = 10
        let y = 20
        let result = "none"

        if x > 5 and y > 15
            if x < 15 and y < 25
                if (x + y) == 30
                    if (x * 2) == y
                        result = "all conditions met"
                    end
                end
            end
        end

        test.assert_eq(result, "all conditions met", "Complex nested conditions should work")
    end)

    test.it("handles method calls in if conditions", fun ()
        let arr = [10, 20, 30]
        let result = "none"

        if arr.len() > 0 and arr.get(0) == 10
            result = "found"
        end

        test.assert_eq(result, "found", "Method calls in conditions should work")
    end)
end)
