use "std/test" { module, describe, it, assert_eq, assert, assert_raises, assert_neq }
use "std/ndarray" as np

module("NDArray - Operations")

describe("Element-wise operations", fun ()
  it("adds two arrays", fun ()
    let a = np.array([[1, 2], [3, 4]])
    let b = np.array([[5, 6], [7, 8]])
    let c = a.add(b)

    let result = c.to_array()
    assert_eq(result[0][0], 6.0)   # 1 + 5
    assert_eq(result[0][1], 8.0)   # 2 + 6
    assert_eq(result[1][0], 10.0)  # 3 + 7
    assert_eq(result[1][1], 12.0)  # 4 + 8
  end)

  it("subtracts two arrays", fun ()
    let a = np.array([[10, 20], [30, 40]])
    let b = np.array([[1, 2], [3, 4]])
    let c = a.sub(b)

    let result = c.to_array()
    assert_eq(result[0][0], 9.0)
    assert_eq(result[1][1], 36.0)
  end)

  it("multiplies two arrays element-wise", fun ()
    let a = np.array([[2, 3], [4, 5]])
    let b = np.array([[1, 2], [3, 4]])
    let c = a.mul(b)

    let result = c.to_array()
    assert_eq(result[0][0], 2.0)   # 2 * 1
    assert_eq(result[0][1], 6.0)   # 3 * 2
    assert_eq(result[1][0], 12.0)  # 4 * 3
    assert_eq(result[1][1], 20.0)  # 5 * 4
  end)

  it("divides two arrays element-wise", fun ()
    let a = np.array([[10, 20], [30, 40]])
    let b = np.array([[2, 4], [5, 8]])
    let c = a.div(b)

    let result = c.to_array()
    assert_eq(result[0][0], 5.0)
    assert_eq(result[0][1], 5.0)
    assert_eq(result[1][0], 6.0)
    assert_eq(result[1][1], 5.0)
  end)

  it("raises error on shape mismatch", fun ()
    let a = np.zeros([2, 3])
    let b = np.zeros([3, 2])

    try
      a.add(b)
      assert(false, "Should have raised exception")
    catch e
      assert(true)
    end
  end)
end)

describe("Scalar operations", fun ()
  it("adds scalar to array", fun ()
    let a = np.array([[1, 2], [3, 4]])
    let b = a.add_scalar(10)

    let result = b.to_array()
    assert_eq(result[0][0], 11.0)
    assert_eq(result[1][1], 14.0)
  end)

  it("subtracts scalar from array", fun ()
    let a = np.array([[10, 20], [30, 40]])
    let b = a.sub_scalar(5)

    let result = b.to_array()
    assert_eq(result[0][0], 5.0)
    assert_eq(result[1][1], 35.0)
  end)

  it("multiplies array by scalar", fun ()
    let a = np.array([[1, 2], [3, 4]])
    let b = a.mul_scalar(2.5)

    let result = b.to_array()
    assert_eq(result[0][0], 2.5)
    assert_eq(result[0][1], 5.0)
    assert_eq(result[1][0], 7.5)
    assert_eq(result[1][1], 10.0)
  end)

  it("divides array by scalar", fun ()
    let a = np.array([[10, 20], [30, 40]])
    let b = a.div_scalar(10)

    let result = b.to_array()
    assert_eq(result[0][0], 1.0)
    assert_eq(result[0][1], 2.0)
    assert_eq(result[1][0], 3.0)
    assert_eq(result[1][1], 4.0)
  end)
end)

describe("Min/Max aggregations", fun ()
  it("finds minimum of all elements", fun ()
    let m = np.array([[5, 2, 9], [1, 8, 3]])
    assert_eq(m.min(), 1.0)
  end)

  it("finds maximum of all elements", fun ()
    let m = np.array([[5, 2, 9], [1, 8, 3]])
    assert_eq(m.max(), 9.0)
  end)

  it("finds min along axis 0", fun ()
    let m = np.array([[5, 2, 9], [1, 8, 3]])
    let mins = m.min(0)
    let result = mins.to_array()
    assert_eq(result[0], 1.0)  # min of column 0
    assert_eq(result[1], 2.0)  # min of column 1
    assert_eq(result[2], 3.0)  # min of column 2
  end)

  it("finds max along axis 1", fun ()
    let m = np.array([[5, 2, 9], [1, 8, 3]])
    let maxs = m.max(1)
    let result = maxs.to_array()
    assert_eq(result[0], 9.0)  # max of row 0
    assert_eq(result[1], 8.0)  # max of row 1
  end)
end)

describe("Standard deviation and variance", fun ()
  it("computes std of all elements", fun ()
    let m = np.array([[1, 2], [3, 4]])
    let std_val = m.std()
    # Standard deviation of [1, 2, 3, 4] ≈ 1.118
    assert(std_val > 1.0)
    assert(std_val < 1.5)
  end)

  it("computes variance of all elements", fun ()
    let m = np.array([[1, 2], [3, 4]])
    let var_val = m.var()
    # Variance of [1, 2, 3, 4] = 1.25
    assert_eq(var_val, 1.25)
  end)

  it("computes std along axis", fun ()
    let m = np.full([3, 4], 5.0)
    let std_ax = m.std(0)
    # All values same, so std should be 0
    let result = std_ax.to_array()
    assert_eq(result[0], 0.0)
  end)

  it("computes var along axis", fun ()
    let m = np.array([[1, 2], [3, 4]])
    let var_ax = m.var(0)
    # Variance along columns
    assert(var_ax.is("NDArray"))
  end)
end)

describe("Utility methods", fun ()
  it("flattens multi-dimensional array", fun ()
    let m = np.array([[1, 2, 3], [4, 5, 6]])
    let flat = m.flatten()

    assert_eq(flat.shape(), [6])
    assert_eq(flat.ndim(), 1)

    let result = flat.to_array()
    assert_eq(result[0], 1.0)    assert_eq(result[5], 6.0)  end)

  it("copies array", fun ()
    let a = np.ones([2, 2])
    let b = a.copy()

    assert_eq(a.shape(), b.shape())
    assert_neq(a._id(), b._id())
  end)

  it("converts to nested Quest arrays", fun ()
    let m = np.array([[1, 2], [3, 4]])
    let arr = m.to_array()

    assert(arr.is("Array"))
    assert_eq(arr[0][0], 1.0)
    assert_eq(arr[0][1], 2.0)
    assert_eq(arr[1][0], 3.0)
    assert_eq(arr[1][1], 4.0)
  end)

  it("converts 1D array to Quest array", fun ()
    let v = np.array([1, 2, 3, 4, 5])
    let arr = v.to_array()

    assert_eq(arr.len(), 5)
    assert_eq(arr[0], 1.0)    assert_eq(arr[4], 5.0)  end)

  it("converts 3D array to nested arrays", fun ()
    let cube = np.array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
    let arr = cube.to_array()

    assert_eq(arr.len(), 2)
    assert_eq(arr[0][0][0], 1.0)
    assert_eq(arr[1][1][1], 8.0)
  end)
end)

describe("Combined operations", fun ()
  it("chains element-wise and scalar operations", fun ()
    let a = np.array([[1, 2], [3, 4]])
    let b = np.array([[2, 2], [2, 2]])

    let result = a.add(b).mul_scalar(2)
    let arr = result.to_array()

    assert_eq(arr[0][0], 6.0)   # (1+2)*2
    assert_eq(arr[1][1], 12.0)  # (4+2)*2
  end)

  it("combines aggregations with reshaping", fun ()
    let m = np.arange(1, 13).reshape([3, 4])
    let total = m.sum()

    # Sum of 1+2+...+12 = 78
    assert_eq(total, 78.0)  end)

  it("works with real numeric data", fun ()
    let data = np.array([[1.5, 2.5, 3.5], [4.5, 5.5, 6.5]])
    let normalized = data.sub_scalar(data.mean()).div_scalar(data.std())

    assert(normalized.is("NDArray"))
    assert_eq(normalized.shape(), [2, 3])
  end)
end)
