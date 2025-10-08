# QEP-041: Indexed Assignment Tests
use "std/test"

test.module("QEP-041: Indexed Assignment")

test.describe("Array indexed assignment", fun ()
    test.it("assigns to valid index", fun ()
        let arr = [1, 2, 3]
        arr[1] = 10
        test.assert_eq(arr[1], 10)
        test.assert_eq(arr[0], 1)
        test.assert_eq(arr[2], 3)
    end)

    test.it("assigns to first element", fun ()
        let arr = [1, 2, 3]
        arr[0] = 100
        test.assert_eq(arr[0], 100)
    end)

    test.it("assigns to last element", fun ()
        let arr = [1, 2, 3]
        arr[2] = 999
        test.assert_eq(arr[2], 999)
    end)

    test.it("supports negative indices", fun ()
        let arr = [1, 2, 3, 4, 5]
        arr[-1] = 50
        test.assert_eq(arr[4], 50)
        arr[-2] = 40
        test.assert_eq(arr[3], 40)
    end)

    test.it("raises IndexErr on out of bounds - positive", fun ()
        let arr = [1, 2, 3]
        test.assert_raises(IndexErr, fun () arr[10] = 99 end)
    end)

    test.it("raises IndexErr on out of bounds - negative", fun ()
        let arr = [1, 2, 3]
        test.assert_raises(IndexErr, fun () arr[-10] = 99 end)
    end)

    test.it("works with empty array at valid index", fun ()
        let arr = [nil]
        arr[0] = 42
        test.assert_eq(arr[0], 42)
    end)
end)

test.describe("Dict indexed assignment", fun ()
    test.it("updates existing key", fun ()
        let d = {a: 1, b: 2}
        d["a"] = 10
        test.assert_eq(d["a"], 10)
        test.assert_eq(d["b"], 2)
    end)

    test.it("inserts new key", fun ()
        let d = {a: 1}
        d["b"] = 2
        test.assert_eq(d["a"], 1)
        test.assert_eq(d["b"], 2)
    end)

    test.it("updates multiple keys", fun ()
        let d = {x: 1, y: 2, z: 3}
        d["x"] = 10
        d["y"] = 20
        d["z"] = 30
        test.assert_eq(d["x"], 10)
        test.assert_eq(d["y"], 20)
        test.assert_eq(d["z"], 30)
    end)

    test.it("assigns nil value", fun ()
        let d = {a: 1}
        d["a"] = nil
        test.assert_nil(d["a"])
    end)
end)

test.describe("Compound assignment operators", fun ()
    test.it("supports += on array element", fun ()
        let arr = [5, 10, 15]
        arr[1] += 5
        test.assert_eq(arr[1], 15)
    end)

    test.it("supports -= on array element", fun ()
        let arr = [100, 50, 25]
        arr[0] -= 20
        test.assert_eq(arr[0], 80)
    end)

    test.it("supports *= on array element", fun ()
        let arr = [2, 3, 4]
        arr[1] *= 10
        test.assert_eq(arr[1], 30)
    end)

    test.it("supports /= on array element", fun ()
        let arr = [100, 50, 25]
        arr[0] /= 4
        test.assert_eq(arr[0], 25)
    end)

    test.it("supports %= on array element", fun ()
        let arr = [17, 23, 31]
        arr[0] %= 5
        test.assert_eq(arr[0], 2)
    end)

    test.it("supports += on dict value", fun ()
        let d = {count: 10}
        d["count"] += 5
        test.assert_eq(d["count"], 15)
    end)

    test.it("supports string concatenation with +=", fun ()
        let arr = ["hello", "world"]
        arr[0] += " there"
        test.assert_eq(arr[0], "hello there")
    end)
end)

test.describe("Nested indexing", fun ()
    test.it("assigns to 2D array - [i][j]", fun ()
        let grid = [[1, 2], [3, 4], [5, 6]]
        grid[0][1] = 20
        test.assert_eq(grid[0][1], 20)
        test.assert_eq(grid[0][0], 1)
    end)

    test.it("assigns to deeply nested array", fun ()
        let nested = [[[1, 2], [3, 4]], [[5, 6], [7, 8]]]
        nested[0][1][0] = 99
        test.assert_eq(nested[0][1][0], 99)
        test.assert_eq(nested[0][1][1], 4)
    end)

    test.it("supports compound ops on nested array", fun ()
        let grid = [[10, 20], [30, 40]]
        grid[1][0] += 5
        test.assert_eq(grid[1][0], 35)
    end)

    test.it("supports negative indices in nested arrays", fun ()
        let grid = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
        grid[-1][-1] = 99
        test.assert_eq(grid[2][2], 99)
    end)
end)

test.describe("Immutability checks", fun ()
    test.it("rejects string indexed assignment", fun ()
        let s = "hello"
        test.assert_raises(TypeErr, fun () s[0] = "H" end)
    end)

    test.it("rejects bytes indexed assignment", fun ()
        let b = b"hello"
        test.assert_raises(TypeErr, fun () b[0] = 72 end)
    end)

    test.it("allows array of strings with string reassignment", fun ()
        let arr = ["hello", "world"]
        arr[0] = "goodbye"
        test.assert_eq(arr[0], "goodbye")
    end)
end)

test.describe("Type validation", fun ()
    test.it("raises TypeErr for non-indexable type", fun ()
        let x = 42
        test.assert_raises(TypeErr, fun () x[0] = 1 end)
    end)

    test.it("raises TypeErr for function", fun ()
        fun f() 42 end
        test.assert_raises(TypeErr, fun () f[0] = 1 end)
    end)
end)

test.describe("Mixed operations", fun ()
    test.it("combines array and dict assignment", fun ()
        let arr = [{a: 1}, {b: 2}]
        arr[0]["a"] = 10
        test.assert_eq(arr[0]["a"], 10)
    end)

    test.it("assigns with expression on right side", fun ()
        let arr = [1, 2, 3]
        arr[1] = arr[0] + arr[2]
        test.assert_eq(arr[1], 4)
    end)

    test.it("assigns result of function call", fun ()
        fun double(x) x * 2 end
        let arr = [5, 10, 15]
        arr[1] = double(arr[0])
        test.assert_eq(arr[1], 10)
    end)

    test.it("evaluates index only once", fun ()
        let calls = 0
        fun get_index()
            calls = calls + 1
            0
        end

        let arr = [1, 2, 3]
        arr[get_index()] = 10
        test.assert_eq(calls, 1)
    end)
end)

test.describe("Reference semantics", fun ()
    test.it("mutation visible across references", fun ()
        let arr1 = [1, 2, 3]
        let arr2 = arr1
        arr2[0] = 100
        test.assert_eq(arr1[0], 100)
    end)

    test.it("dict mutation visible across references", fun ()
        let d1 = {a: 1}
        let d2 = d1
        d2["a"] = 999
        test.assert_eq(d1["a"], 999)
    end)
end)

test.describe("Edge cases", fun ()
    test.it("assigns to same index multiple times", fun ()
        let arr = [1, 2, 3]
        arr[0] = 10
        arr[0] = 20
        arr[0] = 30
        test.assert_eq(arr[0], 30)
    end)

    test.it("assigns various types to array", fun ()
        let arr = [1, "two", true]
        arr[0] = "one"
        arr[1] = 2
        arr[2] = nil
        test.assert_eq(arr[0], "one")
        test.assert_eq(arr[1], 2)
        test.assert_nil(arr[2])
    end)

    test.it("handles large array indices", fun ()
        let arr = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        arr[9] = 999
        test.assert_eq(arr[9], 999)
    end)
end)
