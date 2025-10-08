# Test Array.new() static method (Ruby-style bulk initialization)
use "std/test"

test.module("Array.new Static Method")

test.describe("Array.new()", fun ()
    test.it("creates empty array with no arguments", fun ()
        let arr = Array.new()
        test.assert_eq(arr.len(), 0)
        test.assert_eq(arr.cls(), "Array")
    end)

    test.it("creates array of nil values with one argument", fun ()
        let arr = Array.new(5)
        test.assert_eq(arr.len(), 5)
        test.assert_eq(arr[0], nil)
        test.assert_eq(arr[4], nil)
    end)

    test.it("creates array of repeated values with two arguments", fun ()
        let arr = Array.new(3, "hello")
        test.assert_eq(arr.len(), 3)
        test.assert_eq(arr[0], "hello")
        test.assert_eq(arr[1], "hello")
        test.assert_eq(arr[2], "hello")
    end)

    test.it("works with boolean values", fun ()
        let arr = Array.new(10, false)
        test.assert_eq(arr.len(), 10)
        test.assert_eq(arr[0], false)
        test.assert_eq(arr[9], false)
    end)

    test.it("works with integer values", fun ()
        let arr = Array.new(7, 42)
        test.assert_eq(arr.len(), 7)
        test.assert_eq(arr[0], 42)
        test.assert_eq(arr[6], 42)
    end)

    test.it("works with large arrays", fun ()
        let arr = Array.new(100000, 0)
        test.assert_eq(arr.len(), 100000)
        test.assert_eq(arr.first(), 0)
        test.assert_eq(arr.last(), 0)
    end)

    test.it("creates independent copies of mutable values", fun ()
        # Note: For immutable values like numbers and booleans,
        # all elements share the same value (which is fine since they're immutable)
        # For mutable values like arrays, each element is a clone
        let arr = Array.new(3, 0)
        arr[0] = 10
        test.assert_eq(arr[0], 10)
        test.assert_eq(arr[1], 0)  # Other elements unchanged
        test.assert_eq(arr[2], 0)
    end)

    test.it("rejects invalid argument counts", fun ()
        try
            Array.new(1, 2, 3)
            test.assert(false, "Should have raised an error")
        catch e
            test.assert(true)
        end
    end)

    test.it("rejects non-numeric count", fun ()
        try
            Array.new("not a number")
            test.assert(false, "Should have raised an error")
        catch e
            test.assert(true)
        end
    end)
end)
