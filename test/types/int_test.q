# Test Int type functionality

use "std/test" as test

test.module("Int Type")

test.describe("Int Construction", fun ()
    test.it("creates Int from integer literal", fun ()
        let x = 42
        test.assert_eq(x.cls(), "Int", "Integer literal should create Int")
        test.assert_eq(x, 42, "Value should be 42")
    end)

    test.it("creates Int from negative literal", fun ()
        let x = -5
        test.assert_eq(x.cls(), "Int", "Negative integer should be Int")
        test.assert_eq(x, -5, "Value should be -5")
    end)

    test.it("creates Float from float literal", fun ()
        let x = 3.14
        test.assert_eq(x.cls(), "Float", "Float literal should create Float")
    end)

    test.it("creates Float from scientific notation", fun ()
        let x = 1e10
        test.assert_eq(x.cls(), "Float", "Scientific notation should create Float")
        test.assert_eq(x, 10000000000.0, nil)
    end)
end)

test.describe("Int Arithmetic", fun ()
    test.it("adds two Ints", fun ()
        let x = 5
        let y = 10
        let z = x + y
        test.assert_eq(z, 15, "5 + 10 should be 15")
        test.assert_eq(z.cls(), "Int", "Int + Int should return Int")
    end)

    test.it("subtracts two Ints", fun ()
        let x = 10
        let y = 3
        let z = x - y
        test.assert_eq(z, 7, "10 - 3 should be 7")
        test.assert_eq(z.cls(), "Int", "Int - Int should return Int")
    end)

    test.it("multiplies two Ints", fun ()
        let x = 5
        let y = 4
        let z = x * y
        test.assert_eq(z, 20, "5 * 4 should be 20")
        test.assert_eq(z.cls(), "Int", "Int * Int should return Int")
    end)

    test.it("divides two Ints", fun ()
        let x = 20
        let y = 4
        let z = x / y
        test.assert_eq(z, 5, "20 / 4 should be 5")
        test.assert_eq(z.cls(), "Int", "Int / Int should return Int")
    end)

    test.it("performs integer division", fun ()
        let x = 10
        let y = 3
        let z = x / y
        test.assert_eq(z, 3, "10 / 3 should be 3 (integer division)")
        test.assert_eq(z.cls(), "Int", "Int / Int should return Int")
    end)

    test.it("calculates modulo", fun ()
        let x = 10
        let y = 3
        let z = x % y
        test.assert_eq(z, 1, "10 % 3 should be 1")
        test.assert_eq(z.cls(), "Int", "Int % Int should return Int")
    end)
end)

test.describe("Mixed Int/Float Arithmetic", fun ()
    test.it("adds Int and Float returns Float", fun ()
        let x = 5
        let y = 3.14
        let z = x + y
        test.assert_near(z, 8.14, 0.001, "5 + 3.14 should be 8.14")
        test.assert_eq(z.cls(), "Float", "Int + Float should return Float")
    end)

    test.it("adds Float and Int returns Float", fun ()
        let x = 3.14
        let y = 5
        let z = x + y
        test.assert_near(z, 8.14, 0.001, "3.14 + 5 should be 8.14")
        test.assert_eq(z.cls(), "Float", "Float + Int should return Float")
    end)

    test.it("subtracts Int and Float returns Float", fun ()
        let x = 10
        let y = 3.5
        let z = x - y
        test.assert_near(z, 6.5, 0.001, "10 - 3.5 should be 6.5")
        test.assert_eq(z.cls(), "Float", "Int - Float should return Float")
    end)

    test.it("multiplies Int and Float returns Float", fun ()
        let x = 5
        let y = 2.5
        let z = x * y
        test.assert_near(z, 12.5, 0.001, "5 * 2.5 should be 12.5")
        test.assert_eq(z.cls(), "Float", "Int * Float should return Float")
    end)

    test.it("divides Int and Float returns Float", fun ()
        let x = 10
        let y = 2.5
        let z = x / y
        test.assert_near(z, 4.0, 0.001, "10 / 2.5 should be 4.0")
        test.assert_eq(z.cls(), "Float", "Int / Float should return Float")
    end)
end)

test.describe("Int Comparisons", fun ()
    test.it("compares two Ints with ==", fun ()
        test.assert(5 == 5, "5 should equal 5")
        test.assert(not (5 == 10), "5 should not equal 10")
    end)

    test.it("compares two Ints with !=", fun ()
        test.assert(5 != 10, "5 should not equal 10")
        test.assert(not (5 != 5), "5 should equal 5")
    end)

    test.it("compares two Ints with <", fun ()
        test.assert(5 < 10, "5 should be less than 10")
        test.assert(not (10 < 5), "10 should not be less than 5")
        test.assert(not (5 < 5), "5 should not be less than 5")
    end)

    test.it("compares two Ints with >", fun ()
        test.assert(10 > 5, "10 should be greater than 5")
        test.assert(not (5 > 10), "5 should not be greater than 10")
        test.assert(not (5 > 5), "5 should not be greater than 5")
    end)

    test.it("compares two Ints with <=", fun ()
        test.assert(5 <= 10, "5 should be less than or equal to 10")
        test.assert(5 <= 5, "5 should be less than or equal to 5")
        test.assert(not (10 <= 5), "10 should not be less than or equal to 5")
    end)

    test.it("compares two Ints with >=", fun ()
        test.assert(10 >= 5, "10 should be greater than or equal to 5")
        test.assert(5 >= 5, "5 should be greater than or equal to 5")
        test.assert(not (5 >= 10), "5 should not be greater than or equal to 10")
    end)

    test.it("compares Int and Num", fun ()
        test.assert(5 == 5.0, "Int 5 should equal Num 5.0")
        test.assert(5 < 10.5, "Int 5 should be less than Num 10.5")
        test.assert(10 > 5.5, "Int 10 should be greater than Num 5.5")
    end)
end)

test.describe("Int Methods", fun ()
    test.it("converts to Float with to_f64", fun ()
        let x = 42
        let y = x.to_f64()
        test.assert_eq(y.cls(), "Float", "to_f64 should return Float")
        test.assert_near(y, 42.0, 0.001, "Value should be 42.0")
    end)

    test.it("converts to string with to_string", fun ()
        let x = 42
        let s = x.to_string()
        test.assert_eq(s, "42", "to_string should return '42'")
    end)

    test.it("calculates absolute value", fun ()
        let x = -42
        let y = x.abs()
        test.assert_eq(y, 42, "abs(-42) should be 42")
        test.assert_eq(y.cls(), "Int", "abs should return Int")
    end)

    test.it("has _id method", fun ()
        let x = 42
        let id = x._id()
        test.assert(id > 0, "_id should return positive number")
    end)

    test.it("has cls method", fun ()
        let x = 42
        test.assert_eq(x.cls(), "Int", "cls should return 'Int'")
    end)

    test.it("has _str method", fun ()
        let x = 42
        test.assert_eq(x._str(), "42", "_str should return '42'")
    end)
end)

test.describe("Int Edge Cases", fun ()
    test.it("detects overflow in addition", fun ()
        let big = 9223372036854775807  # i64::MAX
        test.assert_raises(fun ()
            big + 1
        end, "Integer overflow in addition", nil)
    end)

    test.it("detects overflow in subtraction", fun ()
        # Can't test subtraction overflow easily without causing parse errors
        test.skip(false, "Subtraction overflow test skipped - need better approach")
    end)

    test.it("detects overflow in multiplication", fun ()
        let big = 9223372036854775807
        test.assert_raises(fun ()
            big * 2
        end, "Integer overflow in multiplication", nil)
    end)

    test.it("detects division by zero", fun ()
        let x = 10
        test.assert_raises(fun ()
            x / 0
        end, "Division by zero", nil)
    end)

    test.it("detects modulo by zero", fun ()
        let x = 10
        test.assert_raises(fun ()
            x % 0
        end, "Modulo by zero", nil)
    end)

    test.it("handles zero correctly", fun ()
        let x = 0
        test.assert_eq(x.cls(), "Int", "Zero should be Int")
        test.assert_eq(x, 0, "Value should be 0")
    end)

    test.it("handles negative zero", fun ()
        let x = -0
        test.assert_eq(x, 0, "-0 should equal 0")
    end)
end)

test.describe("Int Truthiness", fun ()
    test.it("zero is falsy", fun ()
        let x = 0
        test.assert(not x, "0 should be falsy")
    end)

    test.it("non-zero positive is truthy", fun ()
        let x = 42
        test.assert(x, "42 should be truthy")
    end)

    test.it("non-zero negative is truthy", fun ()
        let x = -5
        test.assert(x, "-5 should be truthy")
    end)
end)
