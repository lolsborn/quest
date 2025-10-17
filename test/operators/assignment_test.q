use "std/test" { it, describe, module, assert_eq, assert }

module("Operator Tests - Compound Assignment")

describe("Compound Assignment Operators", fun ()

# += operator
it("+= adds to numbers", fun ()
  let x = 10
  x += 5
  assert_eq(x, 15)
end)

it("+= concatenates strings", fun ()
  let s = "Hello"
  s += " World"
  assert_eq(s, "Hello World")
end)

it("+= concatenates arrays", fun ()
  let a = [1, 2, 3]
  a += [4, 5]
  assert_eq(a.len(), 5)
  assert_eq(a[3], 4)
  assert_eq(a[4], 5)
end)

it("+= works with array elements", fun ()
  let nums = [10, 20, 30]
  nums[1] += 5
  assert_eq(nums[1], 25)
end)

it("+= works with dict values", fun ()
  let d = {"count": 10}
  d["count"] += 5
  assert_eq(d["count"], 15)
end)

# -= operator
it("-= subtracts from numbers", fun ()
  let x = 20
  x -= 7
  assert_eq(x, 13)
end)

it("-= works with array elements", fun ()
  let nums = [10, 20, 30]
  nums[0] -= 3
  assert_eq(nums[0], 7)
end)

it("-= works with dict values", fun ()
  let d = {"value": 50}
  d["value"] -= 10
  assert_eq(d["value"], 40)
end)

# *= operator
it("*= multiplies numbers", fun ()
  let x = 3
  x *= 4
  assert_eq(x, 12)
end)

it("*= works with array elements", fun ()
  let nums = [2, 3, 4]
  nums[1] *= 5
  assert_eq(nums[1], 15)
end)

# /= operator
it("/= divides numbers", fun ()
  let x = 100
  x /= 4
  assert_eq(x, 25)
end)

it("/= works with array elements", fun ()
  let nums = [100, 50, 25]
  nums[0] /= 4
  assert_eq(nums[0], 25)
end)

# %= operator
it("%= calculates modulo", fun ()
  let x = 17
  x %= 5
  assert_eq(x, 2)
end)

it("%= works with array elements", fun ()
  let nums = [17, 23, 31]
  nums[1] %= 7
  assert_eq(nums[1], 2)
end)

# Chaining operations
it("allows chaining compound assignments", fun ()
  let x = 10
  x += 5
  x *= 2
  x -= 10
  assert_eq(x, 20)
end)

# Multiple variables
it("works with multiple variables independently", fun ()
  let a = 5
  let b = 10
  a += 3
  b -= 2
  assert_eq(a, 8)
  assert_eq(b, 8)
end)

# Edge cases
it("handles zero in operations", fun ()
  let x = 5
  x += 0
  assert_eq(x, 5)
  x *= 0
  assert_eq(x, 0)
end)

it("handles negative numbers", fun ()
  let x = 10
  x += -5
  assert_eq(x, 5)
  x -= -3
  assert_eq(x, 8)
end)

it("handles floating point", fun ()
  let x = 10.5
  x += 2.3
  assert(x > 12.7 and x < 12.9, "should be approximately 12.8")

  let y = 7.0
  y /= 2.0
  assert_eq(y, 3.5)
end)

end) # end of describe block
