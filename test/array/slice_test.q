# Array slice() Method Tests
# Comprehensive tests for array slicing with positive and negative indices

use "std/test" {it, describe, module, assert_eq, assert_type}

module("Array slice() Tests")

describe("Basic Slicing", fun ()
  it("slices middle elements", fun ()
    let arr = [0, 1, 2, 3, 4, 5]
    let result = arr.slice(1, 4)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 1)    assert_eq(result[1], 2)    assert_eq(result[2], 3)  end)

  it("slices from start", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(0, 3)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 0)    assert_eq(result[2], 2)  end)

  it("slices to end", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(2, 5)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 2)    assert_eq(result[2], 4)  end)

  it("slices single element", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(2, 3)
    assert_eq(result.len(), 1)
    assert_eq(result[0], 2)  end)

  it("slices entire array", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(0, 5)
    assert_eq(result.len(), 5)
    assert_eq(result[0], 0)    assert_eq(result[4], 4)  end)
end)

describe("Negative Indices", fun ()
  it("uses negative start index", fun ()
    let arr = [0, 1, 2, 3, 4, 5]
    let result = arr.slice(-3, 6)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 3)    assert_eq(result[2], 5)  end)

  it("uses negative end index", fun ()
    let arr = [0, 1, 2, 3, 4, 5]
    let result = arr.slice(0, -2)
    assert_eq(result.len(), 4)
    assert_eq(result[0], 0)    assert_eq(result[3], 3)  end)

  it("uses both negative indices", fun ()
    let arr = [0, 1, 2, 3, 4, 5]
    let result = arr.slice(-4, -1)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 2)    assert_eq(result[2], 4)  end)

  it("handles -1 as last element (exclusive)", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(0, -1)
    assert_eq(result.len(), 4)
    assert_eq(result[3], 3)  end)

  it("slices from negative to positive", fun ()
    let arr = [0, 1, 2, 3, 4, 5]
    let result = arr.slice(-4, 4)
    assert_eq(result.len(), 2)
    assert_eq(result[0], 2)    assert_eq(result[1], 3)  end)
end)

describe("Edge Cases", fun ()
  it("returns empty array when start equals end", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(2, 2)
    assert_eq(result.len(), 0)
  end)

  it("returns empty array when start > end", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(4, 2)
    assert_eq(result.len(), 0)
  end)

  it("handles start beyond array length", fun ()
    let arr = [0, 1, 2]
    let result = arr.slice(10, 20)
    assert_eq(result.len(), 0)
  end)

  it("handles end beyond array length", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(2, 100)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 2)    assert_eq(result[2], 4)  end)

  it("handles negative index beyond start", fun ()
    let arr = [0, 1, 2, 3, 4]
    let result = arr.slice(-100, 3)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 0)    assert_eq(result[2], 2)  end)

  it("handles empty array", fun ()
    let arr = []
    let result = arr.slice(0, 0)
    assert_eq(result.len(), 0)
  end)

  it("slices single-element array", fun ()
    let arr = [42]
    let result = arr.slice(0, 1)
    assert_eq(result.len(), 1)
    assert_eq(result[0], 42)  end)

  it("negative slice on single element", fun ()
    let arr = [42]
    let result = arr.slice(-1, 1)
    assert_eq(result.len(), 1)
    assert_eq(result[0], 42)  end)
end)

describe("Practical Use Cases", fun ()
  it("extracts head of array", fun ()
    let arr = [1, 2, 3, 4, 5]
    let head = arr.slice(0, 3)
    assert_eq(head.len(), 3)
    assert_eq(head[0], 1)    assert_eq(head[2], 3)  end)

  it("extracts tail of array", fun ()
    let arr = [1, 2, 3, 4, 5]
    let tail = arr.slice(-3, 5)
    assert_eq(tail.len(), 3)
    assert_eq(tail[0], 3)    assert_eq(tail[2], 5)  end)

  it("removes first element", fun ()
    let arr = [1, 2, 3, 4, 5]
    let without_first = arr.slice(1, 5)
    assert_eq(without_first.len(), 4)
    assert_eq(without_first[0], 2)  end)

  it("removes last element", fun ()
    let arr = [1, 2, 3, 4, 5]
    let without_last = arr.slice(0, -1)
    assert_eq(without_last.len(), 4)
    assert_eq(without_last[3], 4)  end)

  it("removes first and last elements", fun ()
    let arr = [1, 2, 3, 4, 5]
    let middle = arr.slice(1, -1)
    assert_eq(middle.len(), 3)
    assert_eq(middle[0], 2)    assert_eq(middle[2], 4)  end)

  it("gets middle third of array", fun ()
    let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9]
    let third = arr.slice(3, 6)
    assert_eq(third.len(), 3)
    assert_eq(third[0], 4)    assert_eq(third[2], 6)  end)
end)

describe("Immutability", fun ()
  it("does not modify original array", fun ()
    let original = [1, 2, 3, 4, 5]
    let sliced = original.slice(1, 4)
    assert_eq(original.len(), 5)
    assert_eq(original[0], 1)    assert_eq(original[4], 5)  end)

  it("creates independent copy", fun ()
    let original = [1, 2, 3, 4, 5]
    let sliced = original.slice(1, 4)
    sliced.push(99)
    assert_eq(original.len(), 5, "original unchanged")
    assert_eq(sliced.len(), 4, "sliced modified")
    assert_eq(sliced[3], 99, "new element added to slice")
  end)
end)

describe("Different Types", fun ()
  it("slices string array", fun ()
    let words = ["hello", "world", "from", "quest"]
    let result = words.slice(1, 3)
    assert_eq(result.len(), 2)
    assert_eq(result[0], "world")    assert_eq(result[1], "from")  end)

  it("slices mixed type array", fun ()
    let mixed = [1, "two", 3, "four", 5]
    let result = mixed.slice(1, 4)
    assert_eq(result.len(), 3)
    assert_eq(result[0], "two")    assert_eq(result[1], 3)    assert_eq(result[2], "four")  end)

  it("slices nested arrays", fun ()
    let nested = [[1, 2], [3, 4], [5, 6], [7, 8]]
    let result = nested.slice(1, 3)
    assert_eq(result.len(), 2)
    assert_eq(result[0][0], 3)    assert_eq(result[1][1], 6)  end)
end)
