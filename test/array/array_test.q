# Array Basic Tests
# Tests fundamental array operations

use "std/test" as test

test.module("Array Tests")

test.describe("Array Creation", fun ()
    test.it("creates empty array", fun ()
        let empty = []
        test.assert_eq(empty.len(), 0, "empty array has length 0")
        test.assert(empty.empty(), "empty() returns true for []")
    end)

    test.it("creates array with elements", fun ()
        let numbers = [1, 2, 3, 4, 5]
        test.assert_eq(numbers.len(), 5, "array has 5 elements")
        test.assert(not numbers.empty(), "empty() returns false for non-empty array")
    end)

    test.it("creates mixed type array", fun ()
        let mixed = [1, "hello", true, nil]
        test.assert_eq(mixed.len(), 4, "mixed array has 4 elements")
    end)

    test.it("creates nested array", fun ()
        let nested = [[1, 2], [3, 4]]
        test.assert_eq(nested.len(), 2, "nested array has 2 elements")
    end)
end)

test.describe("Array Access", fun ()
    let numbers = [10, 20, 30, 40, 50]

    test.it("accesses by index", fun ()
        test.assert_eq(numbers[0], 10, "first element")
        test.assert_eq(numbers[2], 30, "middle element")
        test.assert_eq(numbers[4], 50, "last element")
    end)

    test.it("supports negative indexing", fun ()
        test.assert_eq(numbers[-1], 50, "last element with -1")
        test.assert_eq(numbers[-2], 40, "second to last with -2")
    end)

    test.it("uses get() method", fun ()
        test.assert_eq(numbers.get(0), 10, "get(0)")
        test.assert_eq(numbers.get(3), 40, "get(3)")
    end)

    test.it("uses first() and last()", fun ()
        test.assert_eq(numbers.first(), 10, "first()")
        test.assert_eq(numbers.last(), 50, "last()")
    end)
end)

test.describe("Array Mutating Operations", fun ()
    test.it("push() mutates in place and returns nil", fun ()
        let arr = [1, 2, 3]
        let result = arr.push(4)
        test.assert_nil(result, "push returns nil")
        test.assert_eq(arr.len(), 4, "array length increased")
        test.assert_eq(arr[3], 4, "new element at end")
    end)

    test.it("pop() mutates in place and returns removed element", fun ()
        let arr = [1, 2, 3]
        let result = arr.pop()
        test.assert_eq(result, 3, "pop returns removed element")
        test.assert_eq(arr.len(), 2, "array length decreased")
        test.assert_eq(arr[1], 2, "last element is now 2")
    end)

    test.it("unshift() mutates in place and returns nil", fun ()
        let arr = [2, 3, 4]
        let result = arr.unshift(1)
        test.assert_nil(result, "unshift returns nil")
        test.assert_eq(arr[0], 1, "new element at beginning")
        test.assert_eq(arr.len(), 4, "length increased")
    end)

    test.it("shift() mutates in place and returns removed element", fun ()
        let arr = [1, 2, 3, 4]
        let result = arr.shift()
        test.assert_eq(result, 1, "shift returns removed element")
        test.assert_eq(arr[0], 2, "first element is now 2")
        test.assert_eq(arr.len(), 3, "length decreased")
    end)
end)

test.describe("Array Utility Methods", fun ()
    test.it("reverse() mutates in place and returns nil", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let result = numbers.reverse()
        test.assert_nil(result, "reverse returns nil")
        test.assert_eq(numbers[0], 5, "first is now last")
        test.assert_eq(numbers[4], 1, "last is now first")
    end)

    test.it("reversed() returns new reversed array", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let reversed = numbers.reversed()
        test.assert_eq(reversed[0], 5, "reversed first is original last")
        test.assert_eq(reversed[4], 1, "reversed last is original first")
        test.assert_eq(numbers[0], 1, "original array unchanged")
    end)

    test.it("slice() extracts subarray", fun ()
        let numbers = [0, 1, 2, 3, 4, 5]
        let sliced = numbers.slice(1, 4)
        test.assert_eq(sliced.len(), 3, "slice has 3 elements")
        test.assert_eq(sliced[0], 1, "slice starts at index 1")
        test.assert_eq(sliced[2], 3, "slice ends before index 4")
    end)

    test.it("slice() handles negative indices", fun ()
        let numbers = [0, 1, 2, 3, 4]
        let sliced = numbers.slice(-3, -1)
        test.assert_eq(sliced.len(), 2, "negative slice length")
        test.assert_eq(sliced[0], 2, "negative start index")
    end)

    test.it("concat() combines arrays", fun ()
        let first = [1, 2, 3]
        let second = [4, 5, 6]
        let combined = first.concat(second)
        test.assert_eq(combined.len(), 6, "combined length")
        test.assert_eq(combined[3], 4, "second array starts at index 3")
    end)

    test.it("join() creates string", fun ()
        let words = ["a", "b", "c"]
        let joined = words.join(", ")
        test.assert_eq(joined, "a, b, c", "joined with separator")
    end)

    test.it("contains() checks for value", fun ()
        let numbers = [1, 2, 3, 4, 5]
        test.assert(numbers.contains(3), "contains 3")
        test.assert(not numbers.contains(99), "does not contain 99")
    end)

    test.it("index_of() finds position", fun ()
        let numbers = [10, 20, 30, 20, 40]
        test.assert_eq(numbers.index_of(20), 1, "finds first occurrence")
        test.assert_eq(numbers.index_of(99), -1, "returns -1 if not found")
    end)

    test.it("count() counts occurrences", fun ()
        let numbers = [1, 2, 2, 3, 2, 4]
        test.assert_eq(numbers.count(2), 3, "counts all occurrences")
        test.assert_eq(numbers.count(5), 0, "returns 0 if not found")
    end)

    test.it("sort() mutates in place and returns nil", fun ()
        let numbers = [5, 2, 8, 1, 9]
        let result = numbers.sort()
        test.assert_nil(result, "sort returns nil")
        test.assert_eq(numbers[0], 1, "smallest first")
        test.assert_eq(numbers[4], 9, "largest last")
    end)

    test.it("sorted() returns new sorted array", fun ()
        let numbers = [5, 2, 8, 1, 9]
        let sorted = numbers.sorted()
        test.assert_eq(sorted[0], 1, "sorted smallest first")
        test.assert_eq(sorted[4], 9, "sorted largest last")
        test.assert_eq(numbers[0], 5, "original array unchanged")
    end)
end)

test.describe("Array Higher-Order Functions", fun ()
    test.it("map() transforms elements", fun ()
        let numbers = [1, 2, 3, 4]
        let doubled = numbers.map(fun (x) x * 2 end)
        test.assert_eq(doubled[0], 2, "first element doubled")
        test.assert_eq(doubled[3], 8, "last element doubled")
    end)

    test.it("filter() selects elements", fun ()
        let numbers = [1, 2, 3, 4, 5, 6]
        let evens = numbers.filter(fun (x) x % 2 == 0 end)
        test.assert_eq(evens.len(), 3, "three even numbers")
        test.assert_eq(evens[0], 2, "first even is 2")
    end)

    test.it("reduce() accumulates value", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let sum = numbers.reduce(fun (acc, x) acc + x end, 0)
        test.assert_eq(sum, 15, "sum of 1-5 is 15")
    end)

    test.it("any() checks existence", fun ()
        let numbers = [1, 2, 3, 4, 5]
        test.assert(numbers.any(fun (x) x > 3 end), "has number > 3")
        test.assert(not numbers.any(fun (x) x > 10 end), "no number > 10")
    end)

    test.it("all() checks universal property", fun ()
        let numbers = [2, 4, 6, 8]
        test.assert(numbers.all(fun (x) x % 2 == 0 end), "all are even")
        test.assert(not numbers.all(fun (x) x > 5 end), "not all > 5")
    end)

    test.it("find() returns first match", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let found = numbers.find(fun (x) x > 2 end)
        test.assert_eq(found, 3, "finds first number > 2")
    end)

    test.it("find() returns nil if not found", fun ()
        let numbers = [1, 2, 3]
        let found = numbers.find(fun (x) x > 10 end)
        test.assert_nil(found, "returns nil when not found")
    end)

    test.it("find_index() returns position", fun ()
        let numbers = [1, 2, 3, 4, 5]
        let idx = numbers.find_index(fun (x) x > 2 end)
        test.assert_eq(idx, 2, "finds index of first > 2")
    end)

    test.it("find_index() returns -1 if not found", fun ()
        let numbers = [1, 2, 3]
        let idx = numbers.find_index(fun (x) x > 10 end)
        test.assert_eq(idx, -1, "returns -1 when not found")
    end)

    test.it("each() iterates with side effects", fun ()
        let sum = 0
        let numbers = [1, 2, 3, 4, 5]
        numbers.each(fun (x) sum = sum + x end)
        test.assert_eq(sum, 15, "each can modify outer variables")
    end)

    test.it("each() provides index", fun ()
        let last_idx = 0
        let numbers = [10, 20, 30]
        numbers.each(fun (x, i) last_idx = i end)
        test.assert_eq(last_idx, 2, "receives index parameter")
    end)
end)

test.describe("Array Edge Cases", fun ()
    test.it("handles empty array operations", fun ()
        let empty = []
        let empty2 = []
        empty.reverse()
        empty2.sort()
        test.assert_eq(empty.len(), 0, "reverse empty leaves length 0")
        test.assert_eq(empty2.len(), 0, "sort empty leaves length 0")
        test.assert(not empty.contains(1), "empty does not contain anything")
    end)

    test.it("works with single element", fun ()
        let single = [42]
        test.assert_eq(single.first(), 42, "first of single")
        test.assert_eq(single.last(), 42, "last of single")
        let single2 = [42]
        single2.reverse()
        test.assert_eq(single2[0], 42, "reverse single unchanged")
    end)
end)
