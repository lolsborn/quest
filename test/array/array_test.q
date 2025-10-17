# Array Basic Tests
# Tests fundamental array operations

use "std/test" {it, describe, module, assert_eq, assert_neq, assert_type, assert, assert_nil}

module("Array Tests")

describe("Array Creation", fun ()
  it("creates empty array", fun ()
    let empty = []
    assert_eq(empty.len(), 0, "empty array has length 0")
    assert(empty.empty(), "empty() returns true for []")
  end)

  it("creates array with elements", fun ()
    let numbers = [1, 2, 3, 4, 5]
    assert_eq(numbers.len(), 5, "array has 5 elements")
    assert(not numbers.empty(), "empty() returns false for non-empty array")
  end)

  it("creates mixed type array", fun ()
    let mixed = [1, "hello", true, nil]
    assert_eq(mixed.len(), 4, "mixed array has 4 elements")
  end)

  it("creates nested array", fun ()
    let nested = [[1, 2], [3, 4]]
    assert_eq(nested.len(), 2, "nested array has 2 elements")
  end)
end)

describe("Array Access", fun ()
  let numbers = [10, 20, 30, 40, 50]

  it("accesses by index", fun ()
    assert_eq(numbers[0], 10, "first element")
    assert_eq(numbers[2], 30, "middle element")
    assert_eq(numbers[4], 50, "last element")
  end)

  it("supports negative indexing", fun ()
    assert_eq(numbers[-1], 50, "last element with -1")
    assert_eq(numbers[-2], 40, "second to last with -2")
  end)

  it("uses get() method", fun ()
    assert_eq(numbers.get(0), 10, "get(0)")
    assert_eq(numbers.get(3), 40, "get(3)")
  end)

  it("uses first() and last()", fun ()
    assert_eq(numbers.first(), 10, "first()")
    assert_eq(numbers.last(), 50, "last()")
  end)
end)

describe("Array Mutating Operations", fun ()
  it("push() mutates in place and returns nil", fun ()
    let arr = [1, 2, 3]
    let result = arr.push(4)
    assert_eq(result, arr, "push returns array reference")
    assert_eq(arr.len(), 4, "array length increased")
    assert_eq(arr[3], 4, "new element at end")
  end)

  it("pop() mutates in place and returns removed element", fun ()
    let arr = [1, 2, 3]
    let result = arr.pop()
    assert_eq(result, 3, "pop returns removed element")
    assert_eq(arr.len(), 2, "array length decreased")
    assert_eq(arr[1], 2, "last element is now 2")
  end)

  it("unshift() mutates in place and returns nil", fun ()
    let arr = [2, 3, 4]
    let result = arr.unshift(1)
    assert_eq(result, arr, "unshift returns array reference")
    assert_eq(arr[0], 1, "new element at beginning")
    assert_eq(arr.len(), 4, "length increased")
  end)

  it("shift() mutates in place and returns removed element", fun ()
    let arr = [1, 2, 3, 4]
    let result = arr.shift()
    assert_eq(result, 1, "shift returns removed element")
    assert_eq(arr[0], 2, "first element is now 2")
    assert_eq(arr.len(), 3, "length decreased")
  end)
end)

describe("Array Utility Methods", fun ()
  it("reverse() mutates in place and returns nil", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let result = numbers.reverse()
    assert_eq(result, numbers, "reverse returns array reference")
    assert_eq(numbers[0], 5, "first is now last")
    assert_eq(numbers[4], 1, "last is now first")
  end)

  it("reversed() returns new reversed array", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let reversed = numbers.reversed()
    assert_eq(reversed[0], 5, "reversed first is original last")
    assert_eq(reversed[4], 1, "reversed last is original first")
    assert_eq(numbers[0], 1, "original array unchanged")
  end)

  it("slice() extracts subarray", fun ()
    let numbers = [0, 1, 2, 3, 4, 5]
    let sliced = numbers.slice(1, 4)
    assert_eq(sliced.len(), 3, "slice has 3 elements")
    assert_eq(sliced[0], 1, "slice starts at index 1")
    assert_eq(sliced[2], 3, "slice ends before index 4")
  end)

  it("slice() handles negative indices", fun ()
    let numbers = [0, 1, 2, 3, 4]
    let sliced = numbers.slice(-3, -1)
    assert_eq(sliced.len(), 2, "negative slice length")
    assert_eq(sliced[0], 2, "negative start index")
  end)

  it("concat() combines arrays", fun ()
    let first = [1, 2, 3]
    let second = [4, 5, 6]
    let combined = first.concat(second)
    assert_eq(combined.len(), 6, "combined length")
    assert_eq(combined[3], 4, "second array starts at index 3")
  end)

  it("join() creates string", fun ()
    let words = ["a", "b", "c"]
    let joined = words.join(", ")
    assert_eq(joined, "a, b, c", "joined with separator")
  end)

  it("contains() checks for value", fun ()
    let numbers = [1, 2, 3, 4, 5]
    assert(numbers.contains(3), "contains 3")
    assert(not numbers.contains(99), "does not contain 99")
  end)

  it("index_of() finds position", fun ()
    let numbers = [10, 20, 30, 20, 40]
    assert_eq(numbers.index_of(20), 1, "finds first occurrence")
    assert_eq(numbers.index_of(99), -1, "returns -1 if not found")
  end)

  it("count() counts occurrences", fun ()
    let numbers = [1, 2, 2, 3, 2, 4]
    assert_eq(numbers.count(2), 3, "counts all occurrences")
    assert_eq(numbers.count(5), 0, "returns 0 if not found")
  end)

  it("sort() mutates in place and returns nil", fun ()
    let numbers = [5, 2, 8, 1, 9]
    let result = numbers.sort()
    assert_eq(result, numbers, "sort returns array reference")
    assert_eq(numbers[0], 1, "smallest first")
    assert_eq(numbers[4], 9, "largest last")
  end)

  it("sorted() returns new sorted array", fun ()
    let numbers = [5, 2, 8, 1, 9]
    let sorted = numbers.sorted()
    assert_eq(sorted[0], 1, "sorted smallest first")
    assert_eq(sorted[4], 9, "sorted largest last")
    assert_eq(numbers[0], 5, "original array unchanged")
  end)
end)

describe("Array Higher-Order Functions", fun ()
  it("map() transforms elements", fun ()
    let numbers = [1, 2, 3, 4]
    let doubled = numbers.map(fun (x) x * 2 end)
    assert_eq(doubled[0], 2, "first element doubled")
    assert_eq(doubled[3], 8, "last element doubled")
  end)

  it("filter() selects elements", fun ()
    let numbers = [1, 2, 3, 4, 5, 6]
    let evens = numbers.filter(fun (x) x % 2 == 0 end)
    assert_eq(evens.len(), 3, "three even numbers")
    assert_eq(evens[0], 2, "first even is 2")
  end)

  it("reduce() accumulates value", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let sum = numbers.reduce(fun (acc, x) acc + x end, 0)
    assert_eq(sum, 15, "sum of 1-5 is 15")
  end)

  it("any() checks existence", fun ()
    let numbers = [1, 2, 3, 4, 5]
    assert(numbers.any(fun (x) x > 3 end), "has number > 3")
    assert(not numbers.any(fun (x) x > 10 end), "no number > 10")
  end)

  it("all() checks universal property", fun ()
    let numbers = [2, 4, 6, 8]
    assert(numbers.all(fun (x) x % 2 == 0 end), "all are even")
    assert(not numbers.all(fun (x) x > 5 end), "not all > 5")
  end)

  it("find() returns first match", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let found = numbers.find(fun (x) x > 2 end)
    assert_eq(found, 3, "finds first number > 2")
  end)

  it("find() returns nil if not found", fun ()
    let numbers = [1, 2, 3]
    let found = numbers.find(fun (x) x > 10 end)
    assert_nil(found, "returns nil when not found")
  end)

  it("find_index() returns position", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let idx = numbers.find_index(fun (x) x > 2 end)
    assert_eq(idx, 2, "finds index of first > 2")
  end)

  it("find_index() returns -1 if not found", fun ()
    let numbers = [1, 2, 3]
    let idx = numbers.find_index(fun (x) x > 10 end)
    assert_eq(idx, -1, "returns -1 when not found")
  end)

  it("each() iterates with side effects", fun ()
    let sum = 0
    let numbers = [1, 2, 3, 4, 5]
    numbers.each(fun (x) sum = sum + x end)
    assert_eq(sum, 15, "each can modify outer variables")
  end)

  it("each() provides index", fun ()
    let last_idx = 0
    let numbers = [10, 20, 30]
    numbers.each(fun (x, i) last_idx = i end)
    assert_eq(last_idx, 2, "receives index parameter")
  end)
end)

describe("Array Edge Cases", fun ()
  it("handles empty array operations", fun ()
    let empty = []
    let empty2 = []
    empty.reverse()
    empty2.sort()
    assert_eq(empty.len(), 0, "reverse empty leaves length 0")
    assert_eq(empty2.len(), 0, "sort empty leaves length 0")
    assert(not empty.contains(1), "empty does not contain anything")
  end)

  it("works with single element", fun ()
    let single = [42]
    assert_eq(single.first(), 42, "first of single")
    assert_eq(single.last(), 42, "last of single")
    let single2 = [42]
    single2.reverse()
    assert_eq(single2[0], 42, "reverse single unchanged")
  end)
end)
