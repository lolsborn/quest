use "std/test" { it, describe, module, assert_eq}

module("Array Mutability")

describe("Mutating methods modify array in place", fun ()
  it("push() modifies array in place and returns nil", fun ()
    let arr = []

    let i = 0
    while i < 10
      let result = arr.push(i)
      assert_eq(result, arr, "push() returns array reference")
      i = i + 1
    end

    assert_eq(arr.len(), 10, "Array should have 10 elements after push")
    assert_eq(arr[0], 0, "First element should be 0")
    assert_eq(arr[9], 9, "Last element should be 9")
  end)

  it("pop() removes and returns last element", fun ()
    let arr = [1, 2, 3, 4, 5]

    let last = arr.pop()
    assert_eq(last, 5, "pop() should return last element")
    assert_eq(arr.len(), 4, "Array should have 4 elements after pop")
    assert_eq(arr[3], 4, "New last element should be 4")
  end)

  it("shift() removes and returns first element", fun ()
    let arr = [1, 2, 3, 4, 5]

    let first = arr.shift()
    assert_eq(first, 1, "shift() should return first element")
    assert_eq(arr.len(), 4, "Array should have 4 elements after shift")
    assert_eq(arr[0], 2, "New first element should be 2")
  end)

  it("unshift() adds element to beginning", fun ()
    let arr = [2, 3, 4]

    let result = arr.unshift(1)
    assert_eq(result, arr, "unshift() returns array reference")
    assert_eq(arr.len(), 4, "Array should have 4 elements")
    assert_eq(arr[0], 1, "First element should be 1")
    assert_eq(arr[3], 4, "Last element should be 4")
  end)

  it("reverse() reverses array in place", fun ()
    let arr = [1, 2, 3, 4, 5]

    let result = arr.reverse()
    assert_eq(result, arr, "reverse() returns array reference")
    assert_eq(arr[0], 5, "First element should be 5")
    assert_eq(arr[4], 1, "Last element should be 1")
  end)

  it("sort() sorts array in place", fun ()
    let arr = [5, 2, 8, 1, 9]

    let result = arr.sort()
    assert_eq(result, arr, "sort() returns array reference")
    assert_eq(arr[0], 1, "First element should be 1")
    assert_eq(arr[4], 9, "Last element should be 9")
  end)

  it("clear() removes all elements", fun ()
    let arr = [1, 2, 3, 4, 5]

    let result = arr.clear()
    assert_eq(result, arr, "clear() returns array reference")
    assert_eq(arr.len(), 0, "Array should be empty")
  end)

  it("insert() adds element at index", fun ()
    let arr = [1, 2, 4, 5]

    let result = arr.insert(2, 3)
    assert_eq(result, arr, "insert() returns array reference")
    assert_eq(arr.len(), 5, "Array should have 5 elements")
    assert_eq(arr[2], 3, "Element at index 2 should be 3")
  end)

  it("remove() removes first occurrence of value", fun ()
    let arr = [1, 2, 3, 2, 4]

    let was_found = arr.remove(2)
    assert_eq(was_found, true, "remove() should return true when element found")
    assert_eq(arr.len(), 4, "Array should have 4 elements")
    assert_eq(arr[1], 3, "Element at index 1 should now be 3")

    let was_not_found = arr.remove(99)
    assert_eq(was_not_found, false, "remove() should return false when element not found")
  end)

  it("remove_at() removes and returns element at index", fun ()
    let arr = [1, 2, 3, 4, 5]

    let removed = arr.remove_at(2)
    assert_eq(removed, 3, "remove_at() should return removed element")
    assert_eq(arr.len(), 4, "Array should have 4 elements")
    assert_eq(arr[2], 4, "Element at index 2 should now be 4")
  end)
end)

describe("Non-mutating methods return new arrays", fun ()
  it("sorted() returns new sorted array", fun ()
    let arr = [5, 2, 8, 1, 9]

    let sorted_arr = arr.sorted()
    assert_eq(sorted_arr[0], 1, "First element of sorted array should be 1")
    assert_eq(sorted_arr[4], 9, "Last element of sorted array should be 9")
    assert_eq(arr[0], 5, "Original array should be unchanged")
  end)

  it("reversed() returns new reversed array", fun ()
    let arr = [1, 2, 3, 4, 5]

    let reversed_arr = arr.reversed()
    assert_eq(reversed_arr[0], 5, "First element of reversed array should be 5")
    assert_eq(reversed_arr[4], 1, "Last element of reversed array should be 1")
    assert_eq(arr[0], 1, "Original array should be unchanged")
  end)

  it("map() returns new array with transformed elements", fun ()
    let arr = [1, 2, 3, 4, 5]

    let doubled = arr.map(fun (x) x * 2 end)
    assert_eq(doubled[0], 2, "First element should be doubled")
    assert_eq(arr[0], 1, "Original array should be unchanged")
  end)

  it("filter() returns new array with matching elements", fun ()
    let arr = [1, 2, 3, 4, 5]

    let evens = arr.filter(fun (x) x % 2 == 0 end)
    assert_eq(evens.len(), 2, "Should have 2 even numbers")
    assert_eq(arr.len(), 5, "Original array should be unchanged")
  end)

  it("slice() returns new subarray", fun ()
    let arr = [1, 2, 3, 4, 5]

    let sub = arr.slice(1, 4)
    assert_eq(sub.len(), 3, "Slice should have 3 elements")
    assert_eq(sub[0], 2, "First element should be 2")
    assert_eq(arr.len(), 5, "Original array should be unchanged")
  end)

  it("concat() returns new combined array", fun ()
    let arr1 = [1, 2, 3]
    let arr2 = [4, 5, 6]

    let combined = arr1.concat(arr2)
    assert_eq(combined.len(), 6, "Combined array should have 6 elements")
    assert_eq(arr1.len(), 3, "Original arrays should be unchanged")
    assert_eq(arr2.len(), 3, "Original arrays should be unchanged")
  end)
end)

describe("Array mutability with higher-order functions", fun ()
  it("works with array operations after push", fun ()
    let arr = []
    let i = 0
    while i < 5
      arr.push(i)
      i = i + 1
    end

    # Test map
    let doubled = arr.map(fun (x) x * 2 end)
    assert_eq(doubled.len(), 5, "Mapped array should have 5 elements")
    assert_eq(doubled[0], 0, "First mapped element should be 0")
    assert_eq(doubled[4], 8, "Last mapped element should be 8")

    # Test filter
    let evens = arr.filter(fun (x) x % 2 == 0 end)
    assert_eq(evens.len(), 3, "Should have 3 even numbers (0, 2, 4)")

    # Test reduce
    let sum = arr.reduce(fun (acc, x) acc + x end, 0)
    assert_eq(sum, 10, "Sum should be 10 (0+1+2+3+4)")
  end)
end)
