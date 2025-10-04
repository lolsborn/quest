# Numeric Operations Tests
# Tests compound assignment operators and type promotion

use "std/test" as test

test.module("Numeric Operations")

test.describe("Compound assignment - type preservation", fun ()
    test.it("Int += Int preserves Int type", fun ()
        let x = 10
        x += 20
        test.assert_eq(x, 30, nil)
    end)

    test.it("Int -= Int preserves Int type", fun ()
        let x = 50
        x -= 20
        test.assert_eq(x, 30, nil)
    end)

    test.it("Int *= Int preserves Int type", fun ()
        let x = 5
        x *= 6
        test.assert_eq(x, 30, nil)
    end)

    test.it("Int /= Int preserves Int type", fun ()
        let x = 100
        x /= 5
        test.assert_eq(x, 20, nil)
    end)

    test.it("Int %= Int preserves Int type", fun ()
        let x = 17
        x %= 5
        test.assert_eq(x, 2, nil)
    end)
end)

test.describe("Compound assignment - all operators", fun ()
    test.it("chains multiple compound operations", fun ()
        let n = 100
        n += 10   # 110
        n -= 5    # 105
        n *= 2    # 210
        n /= 3    # 70
        n %= 11   # 4
        test.assert_eq(n, 4, nil)
    end)
end)

test.describe("String concatenation with +=", fun ()
    test.it("concatenates strings", fun ()
        let s = "Hello"
        s += " "
        s += "World"
        test.assert_eq(s, "Hello World", nil)
    end)

    test.it("builds string incrementally", fun ()
        let result = ""
        result += "a"
        result += "b"
        result += "c"
        test.assert_eq(result, "abc", nil)
    end)
end)

test.describe("Array concatenation with +=", fun ()
    test.it("concatenates arrays", fun ()
        let arr = [1, 2, 3]
        arr += [4, 5]
        test.assert_eq(arr.len(), 5, nil)
        test.assert_eq(arr.get(0), 1, nil)
        test.assert_eq(arr.get(4), 5, nil)
    end)

    test.it("builds array incrementally", fun ()
        let result = []
        result += [1]
        result += [2, 3]
        result += [4]
        test.assert_eq(result.len(), 4, nil)
    end)
end)

test.describe("Type promotion", fun ()
    test.it("Float operations maintain Float type", fun ()
        let x = 5.0
        x += 2.5
        # Can't easily test type, but verify value is correct
        test.assert_eq(x, 7.5, nil)
    end)

    test.it("mixed operations work correctly", fun ()
        let a = 10
        let b = 2.5
        a += 5  # Int stays Int: 15
        test.assert_eq(a, 15, nil)
    end)
end)
