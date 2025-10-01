# Basic Math Operations Tests
# Tests fundamental arithmetic operations

use "std/test" as test

test.describe("Addition", fun ()
    test.it("adds positive numbers", fun ()
        test.assert_eq(2 + 3, 5, "2 + 3 should equal 5")
    end)

    test.it("adds negative numbers", fun ()
        test.assert_eq(-5 + (-3), -8, "-5 + -3 should equal -8")
    end)

    test.it("adds positive and negative", fun ()
        test.assert_eq(10 + (-4), 6, "10 + -4 should equal 6")
    end)

    test.it("adds zero", fun ()
        test.assert_eq(42 + 0, 42, "42 + 0 should equal 42")
    end)
end)

test.describe("Subtraction", fun ()
    test.it("subtracts positive numbers", fun ()
        test.assert_eq(10 - 3, 7, "10 - 3 should equal 7")
    end)

    test.it("subtracts negative numbers", fun ()
        test.assert_eq(5 - (-3), 8, "5 - -3 should equal 8")
    end)

    test.it("subtracts to negative", fun ()
        test.assert_eq(3 - 10, -7, "3 - 10 should equal -7")
    end)
end)

test.describe("Multiplication", fun ()
    test.it("multiplies positive numbers", fun ()
        test.assert_eq(4 * 5, 20, "4 * 5 should equal 20")
    end)

    test.it("multiplies by zero", fun ()
        test.assert_eq(100 * 0, 0, "100 * 0 should equal 0")
    end)

    test.it("multiplies negative numbers", fun ()
        test.assert_eq(-3 * -4, 12, "-3 * -4 should equal 12")
    end)

    test.it("multiplies positive and negative", fun ()
        test.assert_eq(6 * (-2), -12, "6 * -2 should equal -12")
    end)
end)

test.describe("Division", fun ()
    test.it("divides evenly", fun ()
        test.assert_eq(20 / 4, 5, "20 / 4 should equal 5")
    end)

    test.it("divides with remainder", fun ()
        test.assert_eq(7 / 2, 3.5, "7 / 2 should equal 3.5")
    end)

    test.it("divides negative numbers", fun ()
        test.assert_eq(-12 / 3, -4, "-12 / 3 should equal -4")
    end)
end)

test.describe("Modulo", fun ()
    test.it("calculates remainder", fun ()
        test.assert_eq(10 % 3, 1, "10 % 3 should equal 1")
    end)

    test.it("modulo with zero remainder", fun ()
        test.assert_eq(15 % 5, 0, "15 % 5 should equal 0")
    end)
end)

test.describe("Operator Precedence", fun ()
    test.it("multiplication before addition", fun ()
        test.assert_eq(2 + 3 * 4, 14, "2 + 3 * 4 should equal 14")
    end)

    test.it("parentheses override precedence", fun ()
        test.assert_eq((2 + 3) * 4, 20, "(2 + 3) * 4 should equal 20")
    end)

    test.it("complex expression", fun ()
        test.assert_eq(10 - 2 * 3 + 4, 8, "10 - 2 * 3 + 4 should equal 8")
    end)
end)
