use "std/test"
use "std/ndarray" as np

test.module("NDArray - Element Access")

test.describe("get() method", fun ()
    test.it("gets element from 2D array", fun ()
        let m = np.array([[1, 2, 3], [4, 5, 6]])
        test.assert_eq(m.get([0, 0]), 1.0, nil)
        test.assert_eq(m.get([0, 2]), 3.0, nil)
        test.assert_eq(m.get([1, 1]), 5.0, nil)
        test.assert_eq(m.get([1, 2]), 6.0, nil)
    end)

    test.it("gets element from 1D array", fun ()
        let v = np.array([10, 20, 30, 40])
        test.assert_eq(v.get([0]), 10.0, nil)
        test.assert_eq(v.get([2]), 30.0, nil)
        test.assert_eq(v.get([3]), 40.0, nil)
    end)

    test.it("gets element from 3D array", fun ()
        let cube = np.array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        test.assert_eq(cube.get([0, 0, 0]), 1.0, nil)
        test.assert_eq(cube.get([0, 1, 1]), 4.0, nil)
        test.assert_eq(cube.get([1, 0, 1]), 6.0, nil)
        test.assert_eq(cube.get([1, 1, 1]), 8.0, nil)
    end)

    test.it("raises error on wrong number of indices", fun ()
        let m = np.array([[1, 2], [3, 4]])
        try
            m.get([0])  # 2D array needs 2 indices
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)

    test.it("raises error on out of bounds", fun ()
        let m = np.array([[1, 2], [3, 4]])
        try
            m.get([5, 5])
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)

    test.it("raises error on non-integer indices", fun ()
        let m = np.array([[1, 2], [3, 4]])
        try
            m.get([0.5, 1])
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("Matrix element access patterns", fun ()
    test.it("iterates through matrix elements", fun ()
        let m = np.array([[1, 2], [3, 4]])
        let sum = 0

        sum = sum + m.get([0, 0])
        sum = sum + m.get([0, 1])
        sum = sum + m.get([1, 0])
        sum = sum + m.get([1, 1])

        test.assert_eq(sum, 10.0)    end)

    test.it("accesses diagonal elements", fun ()
        let m = np.eye(3)
        test.assert_eq(m.get([0, 0]), 1.0, nil)
        test.assert_eq(m.get([1, 1]), 1.0, nil)
        test.assert_eq(m.get([2, 2]), 1.0, nil)
        test.assert_eq(m.get([0, 1]), 0.0, nil)
    end)
end)
