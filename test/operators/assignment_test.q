use "std/test" as test

test.module("Operator Tests - Compound Assignment")

test.describe("Compound Assignment Operators", fun ()

# += operator
test.it("+= adds to numbers", fun ()
    let x = 10
    x += 5
    test.assert_eq(x, 15)end)

test.it("+= concatenates strings", fun ()
    let s = "Hello"
    s += " World"
    test.assert_eq(s, "Hello World")end)

test.it("+= concatenates arrays", fun ()
    let a = [1, 2, 3]
    a += [4, 5]
    test.assert_eq(a.len(), 5)
    test.assert_eq(a[3], 4)    test.assert_eq(a[4], 5)end)

test.it("+= works with array elements", fun ()
    let nums = [10, 20, 30]
    nums[1] += 5
    test.assert_eq(nums[1], 25)end)

test.it("+= works with dict values", fun ()
    let d = {"count": 10}
    d["count"] += 5
    test.assert_eq(d["count"], 15)end)

# -= operator
test.it("-= subtracts from numbers", fun ()
    let x = 20
    x -= 7
    test.assert_eq(x, 13)end)

test.it("-= works with array elements", fun ()
    let nums = [10, 20, 30]
    nums[0] -= 3
    test.assert_eq(nums[0], 7)end)

test.it("-= works with dict values", fun ()
    let d = {"value": 50}
    d["value"] -= 10
    test.assert_eq(d["value"], 40)end)

# *= operator
test.it("*= multiplies numbers", fun ()
    let x = 3
    x *= 4
    test.assert_eq(x, 12)end)

test.it("*= works with array elements", fun ()
    let nums = [2, 3, 4]
    nums[1] *= 5
    test.assert_eq(nums[1], 15)end)

# /= operator
test.it("/= divides numbers", fun ()
    let x = 100
    x /= 4
    test.assert_eq(x, 25)end)

test.it("/= works with array elements", fun ()
    let nums = [100, 50, 25]
    nums[0] /= 4
    test.assert_eq(nums[0], 25)end)

# %= operator
test.it("%= calculates modulo", fun ()
    let x = 17
    x %= 5
    test.assert_eq(x, 2)end)

test.it("%= works with array elements", fun ()
    let nums = [17, 23, 31]
    nums[1] %= 7
    test.assert_eq(nums[1], 2)end)

# Chaining operations
test.it("allows chaining compound assignments", fun ()
    let x = 10
    x += 5
    x *= 2
    x -= 10
    test.assert_eq(x, 20)end)

# Multiple variables
test.it("works with multiple variables independently", fun ()
    let a = 5
    let b = 10
    a += 3
    b -= 2
    test.assert_eq(a, 8)    test.assert_eq(b, 8)end)

# Edge cases
test.it("handles zero in operations", fun ()
    let x = 5
    x += 0
    test.assert_eq(x, 5)
    x *= 0
    test.assert_eq(x, 0)end)

test.it("handles negative numbers", fun ()
    let x = 10
    x += -5
    test.assert_eq(x, 5)
    x -= -3
    test.assert_eq(x, 8)end)

test.it("handles floating point", fun ()
    let x = 10.5
    x += 2.3
    test.assert(x > 12.7 and x < 12.9, "should be approximately 12.8")

    let y = 7.0
    y /= 2.0
    test.assert_eq(y, 3.5)end)

end) # end of describe block
