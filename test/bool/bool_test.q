# Boolean Operations Tests
# Tests boolean logic, comparisons, and truthiness

use "std/test" as test

test.module("Boolean Tests")

test.describe("Boolean Literals", fun ()
    test.it("creates true literal", fun ()
        let t = true
        test.assert(t)    end)

    test.it("creates false literal", fun ()
        let f = false
        test.assert(not f)    end)
end)

test.describe("Logical AND Operator", fun ()
    test.it("true and true returns true", fun ()
        test.assert(true and true)    end)

    test.it("true and false returns false", fun ()
        test.assert(not (true and false))
    end)

    test.it("false and true returns false", fun ()
        test.assert(not (false and true))
    end)

    test.it("false and false returns false", fun ()
        test.assert(not (false and false))
    end)

    test.it("chains multiple AND operations", fun ()
        test.assert(true and true and true)        test.assert(not (true and true and false))
    end)
end)

test.describe("Logical OR Operator", fun ()
    test.it("true or true returns true", fun ()
        test.assert(true or true)    end)

    test.it("true or false returns true", fun ()
        test.assert(true or false)    end)

    test.it("false or true returns true", fun ()
        test.assert(false or true)    end)

    test.it("false or false returns false", fun ()
        test.assert(not (false or false))
    end)

    test.it("chains multiple OR operations", fun ()
        test.assert(false or false or true)        test.assert(not (false or false or false))
    end)
end)

test.describe("Logical NOT Operator", fun ()
    test.it("not true returns false", fun ()
        test.assert(not true == false)    end)

    test.it("not false returns true", fun ()
        test.assert(not false == true)    end)

    # NOTE: Double negation not (not x) doesn't parse - grammar limitation
    # test.it("double negation returns original", fun ()
    #     test.assert(not (not true))
    #     test.assert(not (not false))
    # end)
end)

test.describe("Combined Logical Operations", fun ()
    test.it("AND has higher precedence than OR", fun ()
        test.assert(true or false and false)        test.assert(not (false and false or false))
    end)

    test.it("combines AND, OR, and NOT", fun ()
        test.assert(not false and true)        test.assert(not false or false)        test.assert(not (false or false))
    end)

    test.it("complex boolean expressions", fun ()
        test.assert((true and true) or (false and true))
        test.assert(not ((false or false) and true))
    end)
end)

test.describe("Comparison Operators - Equality", fun ()
    test.it("compares numbers for equality", fun ()
        test.assert(5 == 5)        test.assert(not (5 == 6))
    end)

    test.it("compares strings for equality", fun ()
        test.assert("hello" == "hello")        test.assert(not ("hello" == "world"))
    end)

    test.it("compares booleans for equality", fun ()
        test.assert(true == true)        test.assert(false == false)        test.assert(not (true == false))
    end)

    test.it("compares numbers for inequality", fun ()
        test.assert(5 != 6)        test.assert(not (5 != 5))
    end)

    test.it("compares strings for inequality", fun ()
        test.assert("hello" != "world")        test.assert(not ("hello" != "hello"))
    end)
end)

test.describe("Comparison Operators - Relational", fun ()
    test.it("less than operator", fun ()
        test.assert(3 < 5)        test.assert(not (5 < 3))
        test.assert(not (5 < 5))
    end)

    test.it("less than or equal operator", fun ()
        test.assert(3 <= 5)        test.assert(5 <= 5)        test.assert(not (5 <= 3))
    end)

    test.it("greater than operator", fun ()
        test.assert(5 > 3)        test.assert(not (3 > 5))
        test.assert(not (5 > 5))
    end)

    test.it("greater than or equal operator", fun ()
        test.assert(5 >= 3)        test.assert(5 >= 5)        test.assert(not (3 >= 5))
    end)

    test.it("compares negative numbers", fun ()
        test.assert(-5 < -3)        test.assert(-3 > -5)        test.assert(-5 <= -5)    end)

    test.it("compares floats", fun ()
        test.assert(3.14 < 3.15)        test.assert(3.14 <= 3.14)        test.assert(3.15 > 3.14)    end)
end)

test.describe("Comparison with Logical Operators", fun ()
    test.it("combines comparisons with AND", fun ()
        test.assert((5 > 3) and (10 < 20))
        test.assert(not ((5 > 3) and (10 > 20)))
    end)

    test.it("combines comparisons with OR", fun ()
        test.assert((5 > 3) or (10 > 20))
        test.assert((5 < 3) or (10 < 20))
        test.assert(not ((5 < 3) or (10 > 20)))
    end)

    test.it("negates comparison results", fun ()
        test.assert(not (5 > 10))
        test.assert(not (3 == 4))
    end)
end)

test.describe("Boolean in Conditionals", fun ()
    test.it("uses boolean in if statement", fun ()
        let result = 0
        if true
            result = 1
        end
        test.assert_eq(result, 1)    end)

    test.it("skips false branch", fun ()
        let result = 0
        if false
            result = 1
        end
        test.assert_eq(result, 0)    end)

    test.it("uses comparison in if statement", fun ()
        let result = 0
        if 5 > 3
            result = 1
        end
        test.assert_eq(result, 1)    end)

    test.it("uses logical expression in if statement", fun ()
        let result = 0
        if (5 > 3) and (10 < 20)
            result = 1
        end
        test.assert_eq(result, 1)    end)
end)

# NOTE: Inline if-else (ternary) is not yet implemented in the grammar
# test.describe("Inline If-Else (Ternary)", fun ()
#     test.it("returns true branch when condition is true", fun ()
#         let result = 1 if true else 2
#         test.assert_eq(result, 1)#     end)
#
#     test.it("returns false branch when condition is false", fun ()
#         let result = 1 if false else 2
#         test.assert_eq(result, 2)#     end)
#
#     test.it("uses comparison in inline if", fun ()
#         let result = "big" if 10 > 5 else "small"
#         test.assert_eq(result, "big")#     end)
#
#     test.it("uses logical operators in inline if", fun ()
#         let result = "yes" if (true and true) else "no"
#         test.assert_eq(result, "yes")#     end)
#
#     test.it("nests inline if expressions", fun ()
#         let x = 5
#         let result = "small" if x < 3 else ("medium" if x < 7 else "large")
#         test.assert_eq(result, "medium")#     end)
# end)

test.describe("Boolean Variables and Assignment", fun ()
    test.it("assigns boolean to variable", fun ()
        let flag = true
        test.assert(flag)    end)

    test.it("assigns comparison result to variable", fun ()
        let is_greater = 10 > 5
        test.assert(is_greater)    end)

    test.it("assigns logical expression result to variable", fun ()
        let is_valid = (5 > 3) and (10 < 20)
        test.assert(is_valid)    end)

    test.it("updates boolean variable", fun ()
        let flag = true
        flag = false
        test.assert(not flag)    end)

    test.it("uses boolean in expression", fun ()
        let a = true
        let b = false
        let result = a and not b
        test.assert(result)    end)
end)

test.describe("String Comparison", fun ()
    test.it("compares strings lexicographically with <", fun ()
        test.assert("a" < "b")        test.assert("apple" < "banana")    end)

    test.it("compares strings lexicographically with >", fun ()
        test.assert("b" > "a")        test.assert("banana" > "apple")    end)

    test.it("handles string equality with case sensitivity", fun ()
        test.assert("Hello" == "Hello")        test.assert(not ("Hello" == "hello"))
    end)

    test.it("compares empty strings", fun ()
        test.assert("" == "")        test.assert("" < "a")    end)
end)
