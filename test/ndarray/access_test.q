use "std/test" { module, describe, it, assert_eq, assert, assert_raises }
use "std/ndarray" as np

module("NDArray - Element Access")

describe("get() method", fun ()
  it("gets element from 2D array", fun ()
    let m = np.array([[1, 2, 3], [4, 5, 6]])
    assert_eq(m.get([0, 0]), 1.0)
    assert_eq(m.get([0, 2]), 3.0)
    assert_eq(m.get([1, 1]), 5.0)
    assert_eq(m.get([1, 2]), 6.0)
  end)

  it("gets element from 1D array", fun ()
    let v = np.array([10, 20, 30, 40])
    assert_eq(v.get([0]), 10.0)
    assert_eq(v.get([2]), 30.0)
    assert_eq(v.get([3]), 40.0)
  end)

  it("gets element from 3D array", fun ()
    let cube = np.array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
    assert_eq(cube.get([0, 0, 0]), 1.0)
    assert_eq(cube.get([0, 1, 1]), 4.0)
    assert_eq(cube.get([1, 0, 1]), 6.0)
    assert_eq(cube.get([1, 1, 1]), 8.0)
  end)

  it("raises error on wrong number of indices", fun ()
    let m = np.array([[1, 2], [3, 4]])
    try
      m.get([0])  # 2D array needs 2 indices
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)

  it("raises error on out of bounds", fun ()
    let m = np.array([[1, 2], [3, 4]])
    try
      m.get([5, 5])
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)

  it("raises error on non-integer indices", fun ()
    let m = np.array([[1, 2], [3, 4]])
    try
      m.get([0.5, 1])
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("Matrix element access patterns", fun ()
  it("iterates through matrix elements", fun ()
    let m = np.array([[1, 2], [3, 4]])
    let sum = 0

    sum = sum + m.get([0, 0])
    sum = sum + m.get([0, 1])
    sum = sum + m.get([1, 0])
    sum = sum + m.get([1, 1])

    assert_eq(sum, 10.0)  end)

  it("accesses diagonal elements", fun ()
    let m = np.eye(3)
    assert_eq(m.get([0, 0]), 1.0)
    assert_eq(m.get([1, 1]), 1.0)
    assert_eq(m.get([2, 2]), 1.0)
    assert_eq(m.get([0, 1]), 0.0)
  end)
end)
