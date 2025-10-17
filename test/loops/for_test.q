use "std/test" {module, describe, it, assert_eq, assert}

module("Loop Tests - For")

describe("For Loops - Range Iteration", fun ()

  it("iterates over inclusive range with 'to'", fun ()
    let values = []
    for i in 0 to 4
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 0)  assert_eq(values[4], 4)
  end)

  it("handles single iteration range", fun ()
    let values = []
    for i in 5 to 5
      values.push(i)
    end
    assert_eq(values.len(), 1)
    assert_eq(values[0], 5)end)

  it("handles reverse range", fun ()
    let values = []
    for i in 5 to 1 step -1
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 5)  assert_eq(values[4], 1)
  end)

  it("uses step for counting by twos", fun ()
    let values = []
    for i in 0 to 10 step 2
      values.push(i)
    end
    assert_eq(values.len(), 6)
    assert_eq(values[0], 0)  assert_eq(values[5], 10)
  end)

  it("handles negative numbers in range", fun ()
    let values = []
    for i in -2 to 2
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], -2)  assert_eq(values[4], 2)
  end)

  it("'until' is exclusive (stops before end)", fun ()
    let values = []
    for i in 0 until 5
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 0)  assert_eq(values[4], 4)
  end)

  it("'to' is inclusive (includes end)", fun ()
    let values = []
    for i in 0 to 4
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[4], 4)
  end)

  it("'until' with step", fun ()
    let values = []
    for i in 0 until 10 step 2
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 0)  assert_eq(values[4], 8)
  end)

  it("'until' with negative step", fun ()
    let values = []
    for i in 5 until 0 step -1
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 5)  assert_eq(values[4], 1)
  end)

end)

describe("For Loops - Array Iteration", fun ()

  it("iterates over array elements", fun ()
    let items = ["a", "b", "c"]
    let result = []
    for item in items
      result.push(item)
    end
    assert_eq(result.len(), 3)
    assert_eq(result[0], "a")  assert_eq(result[2], "c")
  end)

  it("iterates over number array", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let results = []
    for n in numbers
      results.push(n * 2)
    end
    assert_eq(results.len(), 5)
    assert_eq(results[0], 2)  assert_eq(results[4], 10)
  end)

  it("handles empty array", fun ()
    let count = 0
    let items = []
    for x in items
      count = 1
    end
    assert_eq(count, 0)
  end)

  it("handles single element array", fun ()
    let values = []
    for elem in [42]
      values.push(elem)
    end
    assert_eq(values.len(), 1)
    assert_eq(values[0], 42)
  end)

end)

describe("For Loops - Dictionary Iteration", fun ()

  it("iterates over dict keys", fun ()
    let d = {"a": 1, "b": 2, "c": 3}
    let keys = []
    for key in d
      keys.push(key)
    end
    assert_eq(keys.len(), 3)
  end)

  it("iterates over dict with key and value", fun ()
    let d = {"x": 10, "y": 20}
    let values = []
    for key, value in d
      values.push(value)
    end
    assert_eq(values.len(), 2)
  end)

  it("can access both key and value", fun ()
    let d = {"name": "Alice", "age": 30}
    let found = false
    for k, v in d
      if k == "name" and v == "Alice"
        found = true
      end
    end
    assert(found, "should find name=Alice")
  end)

  it("handles empty dict", fun ()
    let count = 0
    for k in {}
      count = 1
    end
    assert_eq(count, 0)
  end)

end)

describe("For Loops - Nested Loops", fun ()

  it("supports nested for loops", fun ()
    let pairs = []
    for i in 0 to 2
      for j in 0 to 2
        pairs.push([i, j])
      end
    end
    assert_eq(pairs.len(), 9)
  end)

  it("creates 2D coordinate pairs", fun ()
    let pairs = []
    for row in 0 to 1
      for col in 0 to 1
        pairs.push([row, col])
      end
    end
    assert_eq(pairs.len(), 4)
    assert_eq(pairs[0][0], 0)
    assert_eq(pairs[0][1], 0)
    assert_eq(pairs[3][0], 1)
    assert_eq(pairs[3][1], 1)
  end)

end)

describe("For Loops - Continue Statement", fun ()

  it("continue skips rest of iteration", fun ()
    let values = []
    for i in 0 to 5
      if i == 2
        continue
      end
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[0], 0)
    assert_eq(values[1], 1)
    assert_eq(values[2], 3)
    assert_eq(values[3], 4)
  end)

  it("continue with array iteration", fun ()
    let items = ["a", "b", "c", "d"]
    let result = []
    for item in items
      if item == "b"
        continue
      end
      result.push(item)
    end
    assert_eq(result.len(), 3)
    assert_eq(result[0], "a")
    assert_eq(result[1], "c")
  end)

  it("continue with multiple conditions", fun ()
    let values = []
    for i in 0 to 10
      if i == 3
        continue
      end
      if i == 7
        continue
      end
      values.push(i)
    end
    assert_eq(values.len(), 9)
  end)

end)

describe("For Loops - Break Statement", fun ()

  it("break exits loop early", fun ()
    let values = []
    for i in 0 to 10
      if i == 5
        break
      end
      values.push(i)
    end
    assert_eq(values.len(), 5)
    assert_eq(values[4], 4)end)

  it("break with array iteration", fun ()
    let items = ["a", "b", "c", "d", "e"]
    let result = []
    for item in items
      if item == "c"
        break
      end
      result.push(item)
    end
    assert_eq(result.len(), 2)
    assert_eq(result[0], "a")
    assert_eq(result[1], "b")
  end)

  it("break in nested loop breaks inner only", fun ()
    let count = 0
    for i in 0 to 2
      for j in 0 to 5
        if j == 2
          break
        end
        count = 1
      end
    end
    assert_eq(count, 1)
  end)
end)

describe("For Loops - Combined Break and Continue", fun ()

  it("uses both break and continue", fun ()
    let values = []
    for i in 0 to 20
      if i == 3
        continue
      end
      if i == 8
        break
      end
      values.push(i)
    end
    # Collects: 0, 1, 2, 4, 5, 6, 7 (skips 3, stops at 8)
    assert_eq(values.len(), 7)
    assert_eq(values[0], 0)
    assert_eq(values[6], 7)
  end)

end)
