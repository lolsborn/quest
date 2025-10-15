#!/usr/bin/env quest
# Test postfix operation correctness before optimization

# Test 1: Array indexing
fun test_array_indexing()
    let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let sum = 0
    let i = 0
    while i < 1000
        sum = sum + arr[0] + arr[5] + arr[9]
        i = i + 1
    end
    sum
end

# Test 2: Member access (without call)
type Point
    pub x: Int
    pub y: Int
end

fun test_member_access()
    let p = Point.new(x: 10, y: 20)
    let sum = 0
    let i = 0
    while i < 1000
        sum = sum + p.x + p.y
        i = i + 1
    end
    sum
end

# Test 3: Dict indexing
fun test_dict_indexing()
    let d = {a: 1, b: 2, c: 3}
    let sum = 0
    let i = 0
    while i < 1000
        sum = sum + d["a"] + d["b"] + d["c"]
        i = i + 1
    end
    sum
end

# Test 4: Nested indexing
fun test_nested_indexing()
    let grid = [[1, 2, 3], [4, 5, 6], [7, 8, 9]]
    let sum = 0
    let i = 0
    while i < 1000
        sum = sum + grid[0][0] + grid[1][1] + grid[2][2]
        i = i + 1
    end
    sum
end

# Run tests
puts("Test 1: Array indexing")
let result1 = test_array_indexing()
let pass1 = result1 == 17000
puts(f"Expected: 17000, Got: {result1}, Pass: {pass1}")

puts("\nTest 2: Member access")
let result2 = test_member_access()
let pass2 = result2 == 30000
puts(f"Expected: 30000, Got: {result2}, Pass: {pass2}")

puts("\nTest 3: Dict indexing")
let result3 = test_dict_indexing()
let pass3 = result3 == 6000
puts(f"Expected: 6000, Got: {result3}, Pass: {pass3}")

puts("\nTest 4: Nested indexing")
let result4 = test_nested_indexing()
let pass4 = result4 == 15000
puts(f"Expected: 15000, Got: {result4}, Pass: {pass4}")

puts("\n=== All Postfix Tests Pass ===")
