use "std/test"

test.module("Array Mutability")

test.describe("Mutating methods modify array in place", fun ()
    test.it("push() modifies array in place and returns nil", fun ()
        let arr = []

        let i = 0
        while i < 10
            let result = arr.push(i)
            test.assert_nil(result, "push() should return nil")
            i = i + 1
        end

        test.assert_eq(arr.len(), 10, "Array should have 10 elements after push")
        test.assert_eq(arr[0], 0, "First element should be 0")
        test.assert_eq(arr[9], 9, "Last element should be 9")
    end)

    test.it("pop() removes and returns last element", fun ()
        let arr = [1, 2, 3, 4, 5]

        let last = arr.pop()
        test.assert_eq(last, 5, "pop() should return last element")
        test.assert_eq(arr.len(), 4, "Array should have 4 elements after pop")
        test.assert_eq(arr[3], 4, "New last element should be 4")
    end)

    test.it("shift() removes and returns first element", fun ()
        let arr = [1, 2, 3, 4, 5]

        let first = arr.shift()
        test.assert_eq(first, 1, "shift() should return first element")
        test.assert_eq(arr.len(), 4, "Array should have 4 elements after shift")
        test.assert_eq(arr[0], 2, "New first element should be 2")
    end)

    test.it("unshift() adds element to beginning", fun ()
        let arr = [2, 3, 4]

        let result = arr.unshift(1)
        test.assert_nil(result, "unshift() should return nil")
        test.assert_eq(arr.len(), 4, "Array should have 4 elements")
        test.assert_eq(arr[0], 1, "First element should be 1")
        test.assert_eq(arr[3], 4, "Last element should be 4")
    end)

    test.it("reverse() reverses array in place", fun ()
        let arr = [1, 2, 3, 4, 5]

        let result = arr.reverse()
        test.assert_nil(result, "reverse() should return nil")
        test.assert_eq(arr[0], 5, "First element should be 5")
        test.assert_eq(arr[4], 1, "Last element should be 1")
    end)

    test.it("sort() sorts array in place", fun ()
        let arr = [5, 2, 8, 1, 9]

        let result = arr.sort()
        test.assert_nil(result, "sort() should return nil")
        test.assert_eq(arr[0], 1, "First element should be 1")
        test.assert_eq(arr[4], 9, "Last element should be 9")
    end)

    test.it("clear() removes all elements", fun ()
        let arr = [1, 2, 3, 4, 5]

        let result = arr.clear()
        test.assert_nil(result, "clear() should return nil")
        test.assert_eq(arr.len(), 0, "Array should be empty")
    end)

    test.it("insert() adds element at index", fun ()
        let arr = [1, 2, 4, 5]

        let result = arr.insert(2, 3)
        test.assert_nil(result, "insert() should return nil")
        test.assert_eq(arr.len(), 5, "Array should have 5 elements")
        test.assert_eq(arr[2], 3, "Element at index 2 should be 3")
    end)

    test.it("remove() removes first occurrence of value", fun ()
        let arr = [1, 2, 3, 2, 4]

        let was_found = arr.remove(2)
        test.assert_eq(was_found, true, "remove() should return true when element found")
        test.assert_eq(arr.len(), 4, "Array should have 4 elements")
        test.assert_eq(arr[1], 3, "Element at index 1 should now be 3")

        let was_not_found = arr.remove(99)
        test.assert_eq(was_not_found, false, "remove() should return false when element not found")
    end)

    test.it("remove_at() removes and returns element at index", fun ()
        let arr = [1, 2, 3, 4, 5]

        let removed = arr.remove_at(2)
        test.assert_eq(removed, 3, "remove_at() should return removed element")
        test.assert_eq(arr.len(), 4, "Array should have 4 elements")
        test.assert_eq(arr[2], 4, "Element at index 2 should now be 4")
    end)
end)

test.describe("Non-mutating methods return new arrays", fun ()
    test.it("sorted() returns new sorted array", fun ()
        let arr = [5, 2, 8, 1, 9]

        let sorted_arr = arr.sorted()
        test.assert_eq(sorted_arr[0], 1, "First element of sorted array should be 1")
        test.assert_eq(sorted_arr[4], 9, "Last element of sorted array should be 9")
        test.assert_eq(arr[0], 5, "Original array should be unchanged")
    end)

    test.it("reversed() returns new reversed array", fun ()
        let arr = [1, 2, 3, 4, 5]

        let reversed_arr = arr.reversed()
        test.assert_eq(reversed_arr[0], 5, "First element of reversed array should be 5")
        test.assert_eq(reversed_arr[4], 1, "Last element of reversed array should be 1")
        test.assert_eq(arr[0], 1, "Original array should be unchanged")
    end)

    test.it("map() returns new array with transformed elements", fun ()
        let arr = [1, 2, 3, 4, 5]

        let doubled = arr.map(fun (x) x * 2 end)
        test.assert_eq(doubled[0], 2, "First element should be doubled")
        test.assert_eq(arr[0], 1, "Original array should be unchanged")
    end)

    test.it("filter() returns new array with matching elements", fun ()
        let arr = [1, 2, 3, 4, 5]

        let evens = arr.filter(fun (x) x % 2 == 0 end)
        test.assert_eq(evens.len(), 2, "Should have 2 even numbers")
        test.assert_eq(arr.len(), 5, "Original array should be unchanged")
    end)

    test.it("slice() returns new subarray", fun ()
        let arr = [1, 2, 3, 4, 5]

        let sub = arr.slice(1, 4)
        test.assert_eq(sub.len(), 3, "Slice should have 3 elements")
        test.assert_eq(sub[0], 2, "First element should be 2")
        test.assert_eq(arr.len(), 5, "Original array should be unchanged")
    end)

    test.it("concat() returns new combined array", fun ()
        let arr1 = [1, 2, 3]
        let arr2 = [4, 5, 6]

        let combined = arr1.concat(arr2)
        test.assert_eq(combined.len(), 6, "Combined array should have 6 elements")
        test.assert_eq(arr1.len(), 3, "Original arrays should be unchanged")
        test.assert_eq(arr2.len(), 3, "Original arrays should be unchanged")
    end)
end)

test.describe("Array mutability with higher-order functions", fun ()
    test.it("works with array operations after push", fun ()
        let arr = []
        let i = 0
        while i < 5
            arr.push(i)
            i = i + 1
        end

        # Test map
        let doubled = arr.map(fun (x) x * 2 end)
        test.assert_eq(doubled.len(), 5, "Mapped array should have 5 elements")
        test.assert_eq(doubled[0], 0, "First mapped element should be 0")
        test.assert_eq(doubled[4], 8, "Last mapped element should be 8")

        # Test filter
        let evens = arr.filter(fun (x) x % 2 == 0 end)
        test.assert_eq(evens.len(), 3, "Should have 3 even numbers (0, 2, 4)")

        # Test reduce
        let sum = arr.reduce(fun (acc, x) acc + x end, 0)
        test.assert_eq(sum, 10, "Sum should be 10 (0+1+2+3+4)")
    end)
end)
