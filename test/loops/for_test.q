use "std/test" as test

test.module("Loop Tests - For")

test.describe("For Loops - Range Iteration", fun ()

test.it("iterates over inclusive range with 'to'", fun ()
    let values = []
    for i in 0 to 4
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[4], 4, nil)
end)

test.it("handles single iteration range", fun ()
    let values = []
    for i in 5 to 5
        values = values.push(i)
    end
    test.assert_eq(values.len(), 1, nil)
    test.assert_eq(values[0], 5, nil)
end)

test.it("handles reverse range", fun ()
    let values = []
    for i in 5 to 1 step -1
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 5, nil)
    test.assert_eq(values[4], 1, nil)
end)

test.it("uses step for counting by twos", fun ()
    let values = []
    for i in 0 to 10 step 2
        values = values.push(i)
    end
    test.assert_eq(values.len(), 6, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[5], 10, nil)
end)

test.it("handles negative numbers in range", fun ()
    let values = []
    for i in -2 to 2
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], -2, nil)
    test.assert_eq(values[4], 2, nil)
end)

test.it("'until' is exclusive (stops before end)", fun ()
    let values = []
    for i in 0 until 5
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[4], 4, nil)
end)

test.it("'to' is inclusive (includes end)", fun ()
    let values = []
    for i in 0 to 4
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[4], 4, nil)
end)

test.it("'until' with step", fun ()
    let values = []
    for i in 0 until 10 step 2
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[4], 8, nil)
end)

test.it("'until' with negative step", fun ()
    let values = []
    for i in 5 until 0 step -1
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 5, nil)
    test.assert_eq(values[4], 1, nil)
end)

end) # end Range Iteration

test.describe("For Loops - Array Iteration", fun ()

test.it("iterates over array elements", fun ()
    let items = ["a", "b", "c"]
    let result = []
    for item in items
        result = result.push(item)
    end
    test.assert_eq(result.len(), 3, nil)
    test.assert_eq(result[0], "a", nil)
    test.assert_eq(result[2], "c", nil)
end)

test.it("iterates over number array", fun ()
    let numbers = [1, 2, 3, 4, 5]
    let results = []
    for n in numbers
        results = results.push(n * 2)
    end
    test.assert_eq(results.len(), 5, nil)
    test.assert_eq(results[0], 2, nil)
    test.assert_eq(results[4], 10, nil)
end)

test.it("handles empty array", fun ()
    let count = 0
    let items = []
    for x in items
        count = 1
    end
    test.assert_eq(count, 0, nil)
end)

test.it("handles single element array", fun ()
    let values = []
    for elem in [42]
        values = values.push(elem)
    end
    test.assert_eq(values.len(), 1, nil)
    test.assert_eq(values[0], 42, nil)
end)

end) # end Array Iteration

test.describe("For Loops - Dictionary Iteration", fun ()

test.it("iterates over dict keys", fun ()
    let d = {"a": 1, "b": 2, "c": 3}
    let keys = []
    for key in d
        keys = keys.push(key)
    end
    test.assert_eq(keys.len(), 3, nil)
end)

test.it("iterates over dict with key and value", fun ()
    let d = {"x": 10, "y": 20}
    let values = []
    for key, value in d
        values = values.push(value)
    end
    test.assert_eq(values.len(), 2, nil)
end)

test.it("can access both key and value", fun ()
    let d = {"name": "Alice", "age": 30}
    let found = false
    for k, v in d
        if k == "name" and v == "Alice"
            found = true
        end
    end
    test.assert(found, "should find name=Alice")
end)

test.it("handles empty dict", fun ()
    let count = 0
    for k in {}
        count = 1
    end
    test.assert_eq(count, 0, nil)
end)

end) # end Dictionary Iteration

test.describe("For Loops - Nested Loops", fun ()

test.it("supports nested for loops", fun ()
    let pairs = []
    for i in 0 to 2
        for j in 0 to 2
            pairs = pairs.push([i, j])
        end
    end
    test.assert_eq(pairs.len(), 9, nil)
end)

test.it("creates 2D coordinate pairs", fun ()
    let pairs = []
    for row in 0 to 1
        for col in 0 to 1
            pairs = pairs.push([row, col])
        end
    end
    test.assert_eq(pairs.len(), 4, nil)
    test.assert_eq(pairs[0][0], 0, nil)
    test.assert_eq(pairs[0][1], 0, nil)
    test.assert_eq(pairs[3][0], 1, nil)
    test.assert_eq(pairs[3][1], 1, nil)
end)

end) # end Nested Loops

test.describe("For Loops - Continue Statement", fun ()

test.it("continue skips rest of iteration", fun ()
    let values = []
    for i in 0 to 5
        if i == 2
            continue
        end
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[1], 1, nil)
    test.assert_eq(values[2], 3, nil)
    test.assert_eq(values[3], 4, nil)
end)

test.it("continue with array iteration", fun ()
    let items = ["a", "b", "c", "d"]
    let result = []
    for item in items
        if item == "b"
            continue
        end
        result = result.push(item)
    end
    test.assert_eq(result.len(), 3, nil)
    test.assert_eq(result[0], "a", nil)
    test.assert_eq(result[1], "c", nil)
end)

test.it("continue with multiple conditions", fun ()
    let values = []
    for i in 0 to 10
        if i == 3
            continue
        end
        if i == 7
            continue
        end
        values = values.push(i)
    end
    test.assert_eq(values.len(), 9, nil)
end)

end) # end Continue Statement

test.describe("For Loops - Break Statement", fun ()

test.it("break exits loop early", fun ()
    let values = []
    for i in 0 to 10
        if i == 5
            break
        end
        values = values.push(i)
    end
    test.assert_eq(values.len(), 5, nil)
    test.assert_eq(values[4], 4, nil)
end)

test.it("break with array iteration", fun ()
    let items = ["a", "b", "c", "d", "e"]
    let result = []
    for item in items
        if item == "c"
            break
        end
        result = result.push(item)
    end
    test.assert_eq(result.len(), 2, nil)
    test.assert_eq(result[0], "a", nil)
    test.assert_eq(result[1], "b", nil)
end)

test.it("break in nested loop breaks inner only", fun ()
    let count = 0
    for i in 0 to 2
        for j in 0 to 5
            if j == 2
                break
            end
            count = 1
        end
    end
    test.assert_eq(count, 1, nil)
end)

end) # end Break Statement

test.describe("For Loops - Combined Break and Continue", fun ()

test.it("uses both break and continue", fun ()
    let values = []
    for i in 0 to 20
        if i == 3
            continue
        end
        if i == 8
            break
        end
        values = values.push(i)
    end
    # Collects: 0, 1, 2, 4, 5, 6, 7 (skips 3, stops at 8)
    test.assert_eq(values.len(), 7, nil)
    test.assert_eq(values[0], 0, nil)
    test.assert_eq(values[6], 7, nil)
end)

end) # end Combined Break and Continue
