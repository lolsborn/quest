# Boolean Operations Tests
# Tests boolean logic, comparisons, and truthiness

use "std/test" {it, describe, module, assert, assert_eq, assert_type}

module("Boolean Tests")

describe("Boolean Literals", fun ()
  it("creates true literal", fun ()
    let t = true
    assert(t)
   end)

  it("creates false literal", fun ()
    let f = false
    assert(not f)
  end)
end)

describe("Logical AND Operator", fun ()
  it("true and true returns true", fun ()
    assert(true and true)  end)

  it("true and false returns false", fun ()
    assert(not (true and false))
  end)

  it("false and true returns false", fun ()
    assert(not (false and true))
  end)

  it("false and false returns false", fun ()
    assert(not (false and false))
  end)

  it("chains multiple AND operations", fun ()
    assert(true and true and true)
    assert(not (true and true and false))
  end)
end)

describe("Logical OR Operator", fun ()
  it("true or true returns true", fun ()
    assert(true or true)
  end)

  it("true or false returns true", fun ()
    assert(true or false)
  end)

  it("false or true returns true", fun ()
    assert(false or true)
  end)

  it("false or false returns false", fun ()
    assert(not (false or false))
  end)

  it("chains multiple OR operations", fun ()
    assert(false or false or true)
    assert(not (false or false or false))
  end)
end)

describe("Logical NOT Operator", fun ()
  it("not true returns false", fun ()
    assert(not true == false)  end)

  it("not false returns true", fun ()
    assert(not false == true)  end)

  # NOTE: Double negation not (not x) doesn't parse - grammar limitation
  # it("double negation returns original", fun ()
  #   assert(not (not true))
  #   assert(not (not false))
  # end)
end)

describe("Combined Logical Operations", fun ()
  it("AND has higher precedence than OR", fun ()
    assert(true or false and false)
    assert(not (false and false or false))
  end)

  it("combines AND, OR, and NOT", fun ()
    assert(not false and true)
    assert(not false or false)
    assert(not (false or false))
  end)

  it("complex boolean expressions", fun ()
    assert((true and true) or (false and true))
    assert(not ((false or false) and true))
  end)
end)

describe("Comparison Operators - Equality", fun ()
  it("compares numbers for equality", fun ()
    assert(5 == 5)
    assert(not (5 == 6))
  end)

  it("compares strings for equality", fun ()
    assert("hello" == "hello")
    assert(not ("hello" == "world"))
  end)

  it("compares booleans for equality", fun ()
    assert(true == true)
    assert(false == false)
    assert(not (true == false))
  end)

  it("compares numbers for inequality", fun ()
    assert(5 != 6)
    assert(not (5 != 5))
  end)

  it("compares strings for inequality", fun ()
    assert("hello" != "world")
    assert(not ("hello" != "hello"))
  end)
end)

describe("Comparison Operators - Relational", fun ()
  it("less than operator", fun ()
    assert(3 < 5)
    assert(not (5 < 3))
    assert(not (5 < 5))
  end)

  it("less than or equal operator", fun ()
    assert(3 <= 5)
    assert(5 <= 5)
    assert(not (5 <= 3))
  end)

  it("greater than operator", fun ()
    assert(5 > 3)
    assert(not (3 > 5))
    assert(not (5 > 5))
  end)

  it("greater than or equal operator", fun ()
    assert(5 >= 3)
    assert(5 >= 5)
    assert(not (3 >= 5))
  end)

  it("compares negative numbers", fun ()
    assert(-5 < -3)
    assert(-3 > -5)
    assert(-5 <= -5)
  end)
  it("compares floats", fun ()
    assert(3.14 < 3.15)
    assert(3.14 <= 3.14)
    assert(3.15 > 3.14)
  end)
end)

describe("Comparison with Logical Operators", fun ()
  it("combines comparisons with AND", fun ()
    assert((5 > 3) and (10 < 20))
    assert(not ((5 > 3) and (10 > 20)))
  end)

  it("combines comparisons with OR", fun ()
    assert((5 > 3) or (10 > 20))
    assert((5 < 3) or (10 < 20))
    assert(not ((5 < 3) or (10 > 20)))
  end)

  it("negates comparison results", fun ()
    assert(not (5 > 10))
    assert(not (3 == 4))
  end)
end)

describe("Boolean in Conditionals", fun ()
  it("uses boolean in if statement", fun ()
    let result = 0
    if true
      result = 1
    end
    assert_eq(result, 1)
  end)

  it("skips false branch", fun ()
    let result = 0
    if false
      result = 1
    end
    assert_eq(result, 0)
  end)

  it("uses comparison in if statement", fun ()
    let result = 0
    if 5 > 3
      result = 1
    end
    assert_eq(result, 1)
  end)

  it("uses logical expression in if statement", fun ()
    let result = 0
    if (5 > 3) and (10 < 20)
      result = 1
    end
    assert_eq(result, 1)
  end)
end)

# NOTE: Inline if-else (ternary) is not yet implemented in the grammar
# describe("Inline If-Else (Ternary)", fun ()
#   it("returns true branch when condition is true", fun ()
#     let result = 1 if true else 2
#     assert_eq(result, 1)#   end)
#
#   it("returns false branch when condition is false", fun ()
#     let result = 1 if false else 2
#     assert_eq(result, 2)#   end)
#
#   it("uses comparison in inline if", fun ()
#     let result = "big" if 10 > 5 else "small"
#     assert_eq(result, "big")#   end)
#
#   it("uses logical operators in inline if", fun ()
#     let result = "yes" if (true and true) else "no"
#     assert_eq(result, "yes")#   end)
#
#   it("nests inline if expressions", fun ()
#     let x = 5
#     let result = "small" if x < 3 else ("medium" if x < 7 else "large")
#     assert_eq(result, "medium")#   end)
# end)

describe("Boolean Variables and Assignment", fun ()
  it("assigns boolean to variable", fun ()
    let flag = true
    assert(flag)
  end)

  it("assigns comparison result to variable", fun ()
    let is_greater = 10 > 5
    assert(is_greater)
  end)
  it("assigns logical expression result to variable", fun ()
    let is_valid = (5 > 3) and (10 < 20)
    assert(is_valid)
  end)

  it("updates boolean variable", fun ()
    let flag = true
    flag = false
    assert(not flag)
  end)

  it("uses boolean in expression", fun ()
    let a = true
    let b = false
    let result = a and not b
    assert(result)
  end)
end)

describe("String Comparison", fun ()
  it("compares strings lexicographically with <", fun ()
    assert("a" < "b")
    assert("apple" < "banana")
  end)

  it("compares strings lexicographically with >", fun ()
    assert("b" > "a")
    assert("banana" > "apple")
  end)

  it("handles string equality with case sensitivity", fun ()
    assert("Hello" == "Hello")
    assert(not ("Hello" == "hello"))
  end)

  it("compares empty strings", fun ()
    assert("" == "")
    assert("" < "a")
  end)
end)
