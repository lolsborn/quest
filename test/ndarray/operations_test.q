use "std/test"
use "std/ndarray" as np

test.module("NDArray - Operations")

test.describe("Element-wise operations", fun ()
    test.it("adds two arrays", fun ()
        let a = np.array([[1, 2], [3, 4]])
        let b = np.array([[5, 6], [7, 8]])
        let c = a.add(b)

        let result = c.to_array()
        test.assert_eq(result[0][0], 6.0, nil)   # 1 + 5
        test.assert_eq(result[0][1], 8.0, nil)   # 2 + 6
        test.assert_eq(result[1][0], 10.0, nil)  # 3 + 7
        test.assert_eq(result[1][1], 12.0, nil)  # 4 + 8
    end)

    test.it("subtracts two arrays", fun ()
        let a = np.array([[10, 20], [30, 40]])
        let b = np.array([[1, 2], [3, 4]])
        let c = a.sub(b)

        let result = c.to_array()
        test.assert_eq(result[0][0], 9.0)        test.assert_eq(result[1][1], 36.0)    end)

    test.it("multiplies two arrays element-wise", fun ()
        let a = np.array([[2, 3], [4, 5]])
        let b = np.array([[1, 2], [3, 4]])
        let c = a.mul(b)

        let result = c.to_array()
        test.assert_eq(result[0][0], 2.0, nil)   # 2 * 1
        test.assert_eq(result[0][1], 6.0, nil)   # 3 * 2
        test.assert_eq(result[1][0], 12.0, nil)  # 4 * 3
        test.assert_eq(result[1][1], 20.0, nil)  # 5 * 4
    end)

    test.it("divides two arrays element-wise", fun ()
        let a = np.array([[10, 20], [30, 40]])
        let b = np.array([[2, 4], [5, 8]])
        let c = a.div(b)

        let result = c.to_array()
        test.assert_eq(result[0][0], 5.0)        test.assert_eq(result[0][1], 5.0)        test.assert_eq(result[1][0], 6.0)        test.assert_eq(result[1][1], 5.0)    end)

    test.it("raises error on shape mismatch", fun ()
        let a = np.zeros([2, 3])
        let b = np.zeros([3, 2])

        try
            a.add(b)
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("Scalar operations", fun ()
    test.it("adds scalar to array", fun ()
        let a = np.array([[1, 2], [3, 4]])
        let b = a.add_scalar(10)

        let result = b.to_array()
        test.assert_eq(result[0][0], 11.0)        test.assert_eq(result[1][1], 14.0)    end)

    test.it("subtracts scalar from array", fun ()
        let a = np.array([[10, 20], [30, 40]])
        let b = a.sub_scalar(5)

        let result = b.to_array()
        test.assert_eq(result[0][0], 5.0)        test.assert_eq(result[1][1], 35.0)    end)

    test.it("multiplies array by scalar", fun ()
        let a = np.array([[1, 2], [3, 4]])
        let b = a.mul_scalar(2.5)

        let result = b.to_array()
        test.assert_eq(result[0][0], 2.5)        test.assert_eq(result[0][1], 5.0)        test.assert_eq(result[1][0], 7.5)        test.assert_eq(result[1][1], 10.0)    end)

    test.it("divides array by scalar", fun ()
        let a = np.array([[10, 20], [30, 40]])
        let b = a.div_scalar(10)

        let result = b.to_array()
        test.assert_eq(result[0][0], 1.0)        test.assert_eq(result[0][1], 2.0)        test.assert_eq(result[1][0], 3.0)        test.assert_eq(result[1][1], 4.0)    end)
end)

test.describe("Min/Max aggregations", fun ()
    test.it("finds minimum of all elements", fun ()
        let m = np.array([[5, 2, 9], [1, 8, 3]])
        test.assert_eq(m.min(), 1.0, nil)
    end)

    test.it("finds maximum of all elements", fun ()
        let m = np.array([[5, 2, 9], [1, 8, 3]])
        test.assert_eq(m.max(), 9.0, nil)
    end)

    test.it("finds min along axis 0", fun ()
        let m = np.array([[5, 2, 9], [1, 8, 3]])
        let mins = m.min(0)
        let result = mins.to_array()
        test.assert_eq(result[0], 1.0, nil)  # min of column 0
        test.assert_eq(result[1], 2.0, nil)  # min of column 1
        test.assert_eq(result[2], 3.0, nil)  # min of column 2
    end)

    test.it("finds max along axis 1", fun ()
        let m = np.array([[5, 2, 9], [1, 8, 3]])
        let maxs = m.max(1)
        let result = maxs.to_array()
        test.assert_eq(result[0], 9.0, nil)  # max of row 0
        test.assert_eq(result[1], 8.0, nil)  # max of row 1
    end)
end)

test.describe("Standard deviation and variance", fun ()
    test.it("computes std of all elements", fun ()
        let m = np.array([[1, 2], [3, 4]])
        let std_val = m.std()
        # Standard deviation of [1, 2, 3, 4] ≈ 1.118
        test.assert(std_val > 1.0)        test.assert(std_val < 1.5)    end)

    test.it("computes variance of all elements", fun ()
        let m = np.array([[1, 2], [3, 4]])
        let var_val = m.var()
        # Variance of [1, 2, 3, 4] = 1.25
        test.assert_eq(var_val, 1.25)    end)

    test.it("computes std along axis", fun ()
        let m = np.full([3, 4], 5.0)
        let std_ax = m.std(0)
        # All values same, so std should be 0
        let result = std_ax.to_array()
        test.assert_eq(result[0], 0.0)    end)

    test.it("computes var along axis", fun ()
        let m = np.array([[1, 2], [3, 4]])
        let var_ax = m.var(0)
        # Variance along columns
        test.assert(var_ax.is("NDArray"), nil)
    end)
end)

test.describe("Utility methods", fun ()
    test.it("flattens multi-dimensional array", fun ()
        let m = np.array([[1, 2, 3], [4, 5, 6]])
        let flat = m.flatten()

        test.assert_eq(flat.shape(), [6], nil)
        test.assert_eq(flat.ndim(), 1, nil)

        let result = flat.to_array()
        test.assert_eq(result[0], 1.0)        test.assert_eq(result[5], 6.0)    end)

    test.it("copies array", fun ()
        let a = np.ones([2, 2])
        let b = a.copy()

        test.assert_eq(a.shape(), b.shape(), nil)
        test.assert_neq(a._id(), b._id(), nil)
    end)

    test.it("converts to nested Quest arrays", fun ()
        let m = np.array([[1, 2], [3, 4]])
        let arr = m.to_array()

        test.assert(arr.is("Array"), nil)
        test.assert_eq(arr[0][0], 1.0)        test.assert_eq(arr[0][1], 2.0)        test.assert_eq(arr[1][0], 3.0)        test.assert_eq(arr[1][1], 4.0)    end)

    test.it("converts 1D array to Quest array", fun ()
        let v = np.array([1, 2, 3, 4, 5])
        let arr = v.to_array()

        test.assert_eq(arr.len(), 5, nil)
        test.assert_eq(arr[0], 1.0)        test.assert_eq(arr[4], 5.0)    end)

    test.it("converts 3D array to nested arrays", fun ()
        let cube = np.array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
        let arr = cube.to_array()

        test.assert_eq(arr.len(), 2, nil)
        test.assert_eq(arr[0][0][0], 1.0)        test.assert_eq(arr[1][1][1], 8.0)    end)
end)

test.describe("Combined operations", fun ()
    test.it("chains element-wise and scalar operations", fun ()
        let a = np.array([[1, 2], [3, 4]])
        let b = np.array([[2, 2], [2, 2]])

        let result = a.add(b).mul_scalar(2)
        let arr = result.to_array()

        test.assert_eq(arr[0][0], 6.0, nil)   # (1+2)*2
        test.assert_eq(arr[1][1], 12.0, nil)  # (4+2)*2
    end)

    test.it("combines aggregations with reshaping", fun ()
        let m = np.arange(1, 13).reshape([3, 4])
        let total = m.sum()

        # Sum of 1+2+...+12 = 78
        test.assert_eq(total, 78.0)    end)

    test.it("works with real numeric data", fun ()
        let data = np.array([[1.5, 2.5, 3.5], [4.5, 5.5, 6.5]])
        let normalized = data.sub_scalar(data.mean()).div_scalar(data.std())

        test.assert(normalized.is("NDArray"), nil)
        test.assert_eq(normalized.shape(), [2, 3], nil)
    end)
end)
