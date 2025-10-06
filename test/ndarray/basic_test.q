use "std/test"
use "std/ndarray" as np

test.module("NDArray - Basic Operations")

test.describe("Array creation", fun ()
    test.it("creates zeros array", fun ()
        let m = np.zeros([3, 3])
        test.assert_eq(m.shape(), [3, 3], nil)
        test.assert_eq(m.ndim(), 2, nil)
        test.assert_eq(m.size(), 9, nil)
    end)

    test.it("creates ones array", fun ()
        let m = np.ones([2, 4])
        test.assert_eq(m.shape(), [2, 4], nil)
        test.assert_eq(m.size(), 8, nil)
    end)

    test.it("creates full array with value", fun ()
        let m = np.full([2, 3], 5.0)
        test.assert_eq(m.shape(), [2, 3], nil)
        test.assert_eq(m.size(), 6, nil)
    end)

    test.it("creates identity matrix", fun ()
        let m = np.eye(3)
        test.assert_eq(m.shape(), [3, 3], nil)
        test.assert_eq(m.size(), 9, nil)
    end)

    test.it("creates 1D array", fun ()
        let v = np.zeros([5])
        test.assert_eq(v.shape(), [5], nil)
        test.assert_eq(v.ndim(), 1, nil)
    end)

    test.it("creates 3D array", fun ()
        let cube = np.zeros([2, 3, 4])
        test.assert_eq(cube.shape(), [2, 3, 4], nil)
        test.assert_eq(cube.ndim(), 3, nil)
        test.assert_eq(cube.size(), 24, nil)
    end)
end)

test.describe("From nested arrays", fun ()
    test.it("creates 1D array from flat array", fun ()
        let v = np.array([1, 2, 3, 4, 5])
        test.assert_eq(v.shape(), [5], nil)
        test.assert_eq(v.ndim(), 1, nil)
    end)

    test.it("creates 2D array from nested arrays", fun ()
        let m = np.array([[1, 2, 3], [4, 5, 6]])
        test.assert_eq(m.shape(), [2, 3], nil)
        test.assert_eq(m.ndim(), 2, nil)
        test.assert_eq(m.size(), 6, nil)
    end)

    test.it("creates 3D array from deeply nested arrays", fun ()
        let cube = np.array([
            [[1, 2], [3, 4]],
            [[5, 6], [7, 8]]
        ])
        test.assert_eq(cube.shape(), [2, 2, 2], nil)
        test.assert_eq(cube.ndim(), 3, nil)
        test.assert_eq(cube.size(), 8, nil)
    end)

    test.it("handles floats in nested arrays", fun ()
        let m = np.array([[1.5, 2.5], [3.5, 4.5]])
        test.assert_eq(m.shape(), [2, 2], nil)
    end)
end)

test.describe("arange and linspace", fun ()
    test.it("creates range array", fun ()
        let v = np.arange(0, 5)
        test.assert_eq(v.shape(), [5], nil)
        test.assert_eq(v.size(), 5, nil)
    end)

    test.it("creates range with step", fun ()
        let v = np.arange(0, 10, 2)
        test.assert_eq(v.shape(), [5], nil)  # 0, 2, 4, 6, 8
    end)

    test.it("creates linspace array", fun ()
        let v = np.linspace(0, 10, 5)
        test.assert_eq(v.shape(), [5], nil)  # 0, 2.5, 5, 7.5, 10
    end)
end)

test.describe("Properties", fun ()
    test.it("reports correct shape", fun ()
        let m = np.zeros([3, 4, 5])
        test.assert_eq(m.shape(), [3, 4, 5], nil)
    end)

    test.it("reports correct ndim", fun ()
        let v = np.zeros([10])
        test.assert_eq(v.ndim(), 1, nil)

        let m = np.zeros([3, 3])
        test.assert_eq(m.ndim(), 2, nil)

        let cube = np.zeros([2, 2, 2])
        test.assert_eq(cube.ndim(), 3, nil)
    end)

    test.it("reports correct size", fun ()
        let m = np.zeros([3, 4])
        test.assert_eq(m.size(), 12, nil)
    end)
end)

test.describe("Reshape", fun ()
    test.it("reshapes 1D to 2D", fun ()
        let v = np.arange(0, 6)
        let m = v.reshape([2, 3])
        test.assert_eq(m.shape(), [2, 3], nil)
        test.assert_eq(m.size(), 6, nil)
    end)

    test.it("reshapes 2D to different 2D", fun ()
        let m1 = np.zeros([2, 6])
        let m2 = m1.reshape([3, 4])
        test.assert_eq(m2.shape(), [3, 4], nil)
    end)

    test.it("reshapes to 1D", fun ()
        let m = np.zeros([2, 3, 4])
        let v = m.reshape([24])
        test.assert_eq(v.shape(), [24], nil)
        test.assert_eq(v.ndim(), 1, nil)
    end)

    test.it("raises error on incompatible reshape", fun ()
        let m = np.zeros([2, 3])
        try
            m.reshape([5, 5])  # 6 elements can't fit in 25
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)
end)

test.describe("Transpose", fun ()
    test.it("transposes 2D array", fun ()
        let m = np.zeros([3, 4])
        let mt = m.transpose()
        test.assert_eq(mt.shape(), [4, 3], nil)
    end)

    test.it("T alias for transpose", fun ()
        let m = np.zeros([2, 5])
        let mt = m.T()
        test.assert_eq(mt.shape(), [5, 2], nil)
    end)

    test.it("raises error on non-2D transpose", fun ()
        let v = np.zeros([5])
        try
            v.transpose()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)
end)

test.describe("Matrix multiplication", fun ()
    test.it("multiplies compatible matrices", fun ()
        let a = np.zeros([3, 4])
        let b = np.zeros([4, 2])
        let c = a.dot(b)
        test.assert_eq(c.shape(), [3, 2], nil)
    end)

    test.it("raises error on incompatible shapes", fun ()
        let a = np.zeros([3, 4])
        let b = np.zeros([3, 2])  # Wrong dimensions
        try
            a.dot(b)
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)
end)

test.describe("Aggregations", fun ()
    test.it("sums all elements", fun ()
        let m = np.full([3, 3], 2.0)
        let total = m.sum()
        test.assert_eq(total, 18.0, nil)
    end)

    test.it("computes mean of all elements", fun ()
        let m = np.full([2, 5], 10.0)
        let avg = m.mean()
        test.assert_eq(avg, 10.0, nil)
    end)

    test.it("sums along axis 0", fun ()
        let m = np.ones([3, 4])
        let col_sums = m.sum(0)
        test.assert_eq(col_sums.shape(), [4], nil)
    end)

    test.it("sums along axis 1", fun ()
        let m = np.ones([3, 4])
        let row_sums = m.sum(1)
        test.assert_eq(row_sums.shape(), [3], nil)
    end)
end)

test.describe("Type checking", fun ()
    test.it("has correct type", fun ()
        let m = np.zeros([2, 2])
        test.assert_eq(m.cls(), "NDArray", nil)
        test.assert(m.is("NDArray"), nil)
        test.assert(m.is("ndarray"), nil)
    end)

    test.it("is truthy when non-empty", fun ()
        let m = np.zeros([2, 2])
        test.assert(m, "Non-empty NDArray should be truthy")
    end)
end)

test.describe("Real-world examples", fun ()
    test.it("creates simple 2x2 matrix", fun ()
        let m = np.array([[1, 2], [3, 4]])
        test.assert_eq(m.shape(), [2, 2], nil)
    end)

    test.it("works with NumPy-style alias", fun ()
        # np is already aliased at module level
        let m = np.eye(5)
        test.assert_eq(m.shape(), [5, 5], nil)
    end)

    test.it("chains operations", fun ()
        let m = np.ones([3, 3])
        let result = m.transpose().reshape([9])
        test.assert_eq(result.shape(), [9], nil)
    end)
end)
