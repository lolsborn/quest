use "std/test" as test

test.module("Multiple Let Assignment")

test.describe("Basic multiple assignment", fun ()
    test.it("assigns multiple variables in one statement", fun ()
        let a = 1, b = 2, c = 3
        test.assert_eq(a, 1, nil)
        test.assert_eq(b, 2, nil)
        test.assert_eq(c, 3, nil)
    end)

    test.it("assigns two variables", fun ()
        let x = 10, y = 20
        test.assert_eq(x, 10, nil)
        test.assert_eq(y, 20, nil)
    end)

    test.it("works with single assignment", fun ()
        let solo = 42
        test.assert_eq(solo, 42, nil)
    end)
end)

test.describe("Assignments with expressions", fun ()
    test.it("evaluates expressions left to right", fun ()
        let x = 5 + 3, y = x * 2, z = y - 1
        test.assert_eq(x, 8, nil)
        test.assert_eq(y, 16, nil)
        test.assert_eq(z, 15, nil)
    end)

    test.it("can reference previously declared variables", fun ()
        let base = 10
        let a = base, b = base * 2, c = base + b
        test.assert_eq(a, 10, nil)
        test.assert_eq(b, 20, nil)
        test.assert_eq(c, 30, nil)
    end)
end)

test.describe("Different types", fun ()
    test.it("works with strings", fun ()
        let name = "Alice", greeting = "Hello"
        test.assert_eq(name, "Alice", nil)
        test.assert_eq(greeting, "Hello", nil)
    end)

    test.it("works with arrays", fun ()
        let arr1 = [1, 2, 3], arr2 = [4, 5]
        test.assert_eq(arr1.len(), 3, nil)
        test.assert_eq(arr2.len(), 2, nil)
    end)

    test.it("works with booleans", fun ()
        let t = true, f = false
        test.assert_eq(t, true, nil)
        test.assert_eq(f, false, nil)
    end)

    test.it("works with mixed types", fun ()
        let number = 42, text = "text", flag = true
        test.assert_type(number, "Num", nil)
        test.assert_type(text, "Str", nil)
        test.assert_type(flag, "Bool", nil)
    end)
end)
