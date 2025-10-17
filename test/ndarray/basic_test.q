use "std/test" { module, describe, it, assert_eq, assert, assert_raises }
use "std/ndarray" as np

module("NDArray - Basic Operations")

describe("Array creation", fun ()
  it("creates zeros array", fun ()
    let m = np.zeros([3, 3])
    assert_eq(m.shape(), [3, 3])
    assert_eq(m.ndim(), 2)
    assert_eq(m.size(), 9)
  end)

  it("creates ones array", fun ()
    let m = np.ones([2, 4])
    assert_eq(m.shape(), [2, 4])
    assert_eq(m.size(), 8)
  end)

  it("creates full array with value", fun ()
    let m = np.full([2, 3], 5.0)
    assert_eq(m.shape(), [2, 3])
    assert_eq(m.size(), 6)
  end)

  it("creates identity matrix", fun ()
    let m = np.eye(3)
    assert_eq(m.shape(), [3, 3])
    assert_eq(m.size(), 9)
  end)

  it("creates 1D array", fun ()
    let v = np.zeros([5])
    assert_eq(v.shape(), [5])
    assert_eq(v.ndim(), 1)
  end)

  it("creates 3D array", fun ()
    let cube = np.zeros([2, 3, 4])
    assert_eq(cube.shape(), [2, 3, 4])
    assert_eq(cube.ndim(), 3)
    assert_eq(cube.size(), 24)
  end)
end)

describe("From nested arrays", fun ()
  it("creates 1D array from flat array", fun ()
    let v = np.array([1, 2, 3, 4, 5])
    assert_eq(v.shape(), [5])
    assert_eq(v.ndim(), 1)
  end)

  it("creates 2D array from nested arrays", fun ()
    let m = np.array([[1, 2, 3], [4, 5, 6]])
    assert_eq(m.shape(), [2, 3])
    assert_eq(m.ndim(), 2)
    assert_eq(m.size(), 6)
  end)

  it("creates 3D array from deeply nested arrays", fun ()
    let cube = np.array([
      [[1, 2], [3, 4]],
      [[5, 6], [7, 8]]
    ])
    assert_eq(cube.shape(), [2, 2, 2])
    assert_eq(cube.ndim(), 3)
    assert_eq(cube.size(), 8)
  end)

  it("handles floats in nested arrays", fun ()
    let m = np.array([[1.5, 2.5], [3.5, 4.5]])
    assert_eq(m.shape(), [2, 2])
  end)
end)

describe("arange and linspace", fun ()
  it("creates range array", fun ()
    let v = np.arange(0, 5)
    assert_eq(v.shape(), [5])
    assert_eq(v.size(), 5)
  end)

  it("creates range with step", fun ()
    let v = np.arange(0, 10, 2)
    assert_eq(v.shape(), [5])  # 0, 2, 4, 6, 8
  end)

  it("creates linspace array", fun ()
    let v = np.linspace(0, 10, 5)
    assert_eq(v.shape(), [5])  # 0, 2.5, 5, 7.5, 10
  end)
end)

describe("Properties", fun ()
  it("reports correct shape", fun ()
    let m = np.zeros([3, 4, 5])
    assert_eq(m.shape(), [3, 4, 5])
  end)

  it("reports correct ndim", fun ()
    let v = np.zeros([10])
    assert_eq(v.ndim(), 1)

    let m = np.zeros([3, 3])
    assert_eq(m.ndim(), 2)

    let cube = np.zeros([2, 2, 2])
    assert_eq(cube.ndim(), 3)
  end)

  it("reports correct size", fun ()
    let m = np.zeros([3, 4])
    assert_eq(m.size(), 12)
  end)
end)

describe("Reshape", fun ()
  it("reshapes 1D to 2D", fun ()
    let v = np.arange(0, 6)
    let m = v.reshape([2, 3])
    assert_eq(m.shape(), [2, 3])
    assert_eq(m.size(), 6)
  end)

  it("reshapes 2D to different 2D", fun ()
    let m1 = np.zeros([2, 6])
    let m2 = m1.reshape([3, 4])
    assert_eq(m2.shape(), [3, 4])
  end)

  it("reshapes to 1D", fun ()
    let m = np.zeros([2, 3, 4])
    let v = m.reshape([24])
    assert_eq(v.shape(), [24])
    assert_eq(v.ndim(), 1)
  end)

  it("raises error on incompatible reshape", fun ()
    let m = np.zeros([2, 3])
    try
      m.reshape([5, 5])  # 6 elements can't fit in 25
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("Transpose", fun ()
  it("transposes 2D array", fun ()
    let m = np.zeros([3, 4])
    let mt = m.transpose()
    assert_eq(mt.shape(), [4, 3])
  end)

  it("T alias for transpose", fun ()
    let m = np.zeros([2, 5])
    let mt = m.T()
    assert_eq(mt.shape(), [5, 2])
  end)

  it("raises error on non-2D transpose", fun ()
    let v = np.zeros([5])
    try
      v.transpose()
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("Matrix multiplication", fun ()
  it("multiplies compatible matrices", fun ()
    let a = np.zeros([3, 4])
    let b = np.zeros([4, 2])
    let c = a.dot(b)
    assert_eq(c.shape(), [3, 2])
  end)

  it("raises error on incompatible shapes", fun ()
    let a = np.zeros([3, 4])
    let b = np.zeros([3, 2])  # Wrong dimensions
    try
      a.dot(b)
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("Aggregations", fun ()
  it("sums all elements", fun ()
    let m = np.full([3, 3], 2.0)
    let total = m.sum()
    assert_eq(total, 18.0)  end)

  it("computes mean of all elements", fun ()
    let m = np.full([2, 5], 10.0)
    let avg = m.mean()
    assert_eq(avg, 10.0)  end)

  it("sums along axis 0", fun ()
    let m = np.ones([3, 4])
    let col_sums = m.sum(0)
    assert_eq(col_sums.shape(), [4])
  end)

  it("sums along axis 1", fun ()
    let m = np.ones([3, 4])
    let row_sums = m.sum(1)
    assert_eq(row_sums.shape(), [3])
  end)
end)

describe("Type checking", fun ()
  it("has correct type", fun ()
    let m = np.zeros([2, 2])
    assert_eq(m.cls(), "NDArray")
    assert(m.is("NDArray"))
    assert(m.is("ndarray"))
  end)

  it("is truthy when non-empty", fun ()
    let m = np.zeros([2, 2])
    assert(m, "Non-empty NDArray should be truthy")
  end)
end)

describe("Real-world examples", fun ()
  it("creates simple 2x2 matrix", fun ()
    let m = np.array([[1, 2], [3, 4]])
    assert_eq(m.shape(), [2, 2])
  end)

  it("works with NumPy-style alias", fun ()
    # np is already aliased at module level
    let m = np.eye(5)
    assert_eq(m.shape(), [5, 5])
  end)

  it("chains operations", fun ()
    let m = np.ones([3, 3])
    let result = m.transpose().reshape([9])
    assert_eq(result.shape(), [9])
  end)
end)
