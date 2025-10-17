use "std/test" { module, describe, it, assert, assert_eq }

module("Logical Operators")

describe("not operator", fun ()
  it("negates true to false", fun ()
    assert(not true == false)
  end)

  it("negates false to true", fun ()
    assert(not false == true)
  end)

  it("works with variables", fun ()
    let x = true
    assert(not x == false)
    let y = false
    assert(not y == true)
  end)

  it("supports double negation", fun ()
    assert(not not true == true)
    assert(not not false == false)
  end)

  it("supports triple negation", fun ()
    assert(not not not true == false)
    assert(not not not false == true)
  end)

  it("works with expressions in parentheses", fun ()
    assert(not (5 > 3) == false)
    assert(not (3 > 5) == true)
  end)

  it("works with comparisons", fun ()
    assert(not (5 == 5) == false)
    assert(not (5 != 5) == true)
  end)

  it("negates method results", fun ()
  let nums = [1, 2, 3]
    assert(not nums.empty())
    let empty = []
    let is_empty = empty.empty()
    assert(not not is_empty)
  end)
end)

describe("and operator", fun ()
  it("returns true when both operands are true", fun ()
    assert(true and true)
  end)

  it("returns false when first operand is false", fun ()
    assert(not (false and true))
  end)

  it("returns false when second operand is false", fun ()
    assert(not (true and false))
  end)

  it("returns false when both operands are false", fun ()
    assert(not (false and false))
  end)

  it("works with variables", fun ()
    let a = true
    let b = false
    assert(a and a)  assert(not (a and b))
    assert(not (b and a))
    assert(not (b and b))
  end)

  it("chains multiple conditions", fun ()
    assert(true and true and true)  assert(not (true and true and false))
    assert(not (false and true and true))
    end)

  it("works with comparisons", fun ()
    let x = 5
    let y = 10
    assert((x > 3) and (y > 8))
    assert(not ((x > 10) and (y > 8)))
  end)
end)

describe("or operator", fun ()
  it("returns true when both operands are true", fun ()
    assert(true or true)
  end)

  it("returns true when first operand is true", fun ()
    assert(true or false)
  end)

  it("returns true when second operand is true", fun ()
    assert(false or true)
  end)

  it("returns false when both operands are false", fun ()
    assert(not (false or false))
  end)

  it("works with variables", fun ()
    let a = true
    let b = false
    assert(a or a)
    assert(a or b)
    assert(b or a)
    assert(not (b or b))
  end)

  it("chains multiple conditions", fun ()
    assert(false or false or true)
    assert(not (false or false or false))
  end)

  it("works with comparisons", fun ()
    let x = 5
    assert((x < 3) or (x > 4))
    assert(not ((x < 3) or (x > 10)))
  end)
end)

describe("not with and/or", fun ()
  it("not has higher precedence than and", fun ()
    assert(not false and true, "should be (not false) and true")
    assert(not (false and true), "parentheses for clarity")
  end)

  it("not has higher precedence than or", fun ()
    assert(not false or false, "should be (not false) or false")
    assert(not (false or false), "parentheses override precedence")
  end)

  it("combines not with and", fun ()
    let a = true
    let b = false
    assert((not a and b) == false, "not a and b with a=true, b=false")
    assert(not (a and b) == true, "not (a and b) with a=true, b=false")
  end)

  it("combines not with or", fun ()
    let a = true
    let b = false
    assert((not a or b) == false, "not a or b with a=true, b=false")
    assert(not (a or b) == false, "not (a or b) with a=true, b=false")
  end)

  it("De Morgan's laws: not (a and b) == (not a) or (not b)", fun ()
    let a = true
    let b = false
    assert(not (a and b) == ((not a) or (not b)))
  end)

  it("De Morgan's laws: not (a or b) == (not a) and (not b)", fun ()
    let a = true
    let b = false
    assert(not (a or b) == ((not a) and (not b)))
  end)
end)

describe("complex logical expressions", fun ()
  it("combines and, or, not with parentheses", fun ()
    assert(not ((true and false) or (false and true)))
    assert((not false or false) and not false, "should be true")
  end)

  it("works with nested conditions", fun ()
    let x = 5
    let y = 10
    let z = 15
    assert(((x < y) and (y < z)) or (x == 0))
    assert(not ((x > y) and (y > z)) or true)
  end)

  it("evaluates complex boolean algebra", fun ()
    let a = true
    let b = false
    let c = true
    assert((a or b) and c)
    assert(not (a and b and c))
    assert((a or b) and (b or c))
  end)

  it("works in control flow conditions", fun ()
    let x = 10
    let result = 0

    if (x > 5) and (x < 15)
      result = 1
    end
    assert(result == 1)
  end)

  it("works with method calls in conditions", fun ()
    let nums = [1, 2, 3, 4, 5]
    assert((not nums.empty()) and (nums.len() > 3))
    end)
  end)

describe("logical operators with truthy/falsy values", fun ()
  it("treats zero as false in boolean context", fun ()
    assert(not 0, "0 should be falsy")
  end)

  it("treats non-zero numbers as true", fun ()
  assert(1 and 5, "non-zero numbers should be truthy")
  assert(-1 and 99, "negative numbers should be truthy")
  end)

  it("treats empty string as false", fun ()
  assert(not "", "empty string should be falsy")
  end)

  it("treats non-empty string as true", fun ()
  assert("hello" and "world", "non-empty strings should be truthy")
  end)

  it("treats nil as false", fun ()
  assert(not nil, "nil should be falsy")
  end)

  it("combines different truthy/falsy types", fun ()
  assert(not (0 and 1), "0 and 1 should be falsy")
  assert(1 or 0, "1 or 0 should be truthy")
  assert(not ("" and "hello"), "empty string and non-empty should be falsy")
  end)
end)

describe("operator precedence", fun ()
  it("not > and > or", fun ()
    # not false and true or false
    # = (not false) and true or false
    # = true and true or false
    # = true or false
    # = true
    assert(not false and true or false)
  end)

  it("uses parentheses to override precedence", fun ()
    assert(not (false and true) or false)
    assert(not false and (true or false))
  end)

  it("comparison operators before logical", fun ()
    let x = 5
    assert(x > 3 and x < 10, "should be (x > 3) and (x < 10)")
    assert(not x > 10 or x < 0, "should be (not (x > 10)) or (x < 0)")
  end)
end)

describe("or operator returns values (not booleans)", fun ()
  it("returns first truthy value", fun ()
    let result = "hello" or "world"
    assert_eq(result, "hello", "Should return first truthy value")
  end)

  it("returns second value if first is nil", fun ()
    let result = nil or "default"
    assert_eq(result, "default", "Should return second value when first is nil")
  end)

  it("returns second value if first is false", fun ()
    let result = false or "backup"
    assert_eq(result, "backup", "Should return second value when first is false")
  end)

  it("returns first value if truthy", fun ()
    let result = "value" or nil
    assert_eq(result, "value", "Should return first truthy value")
  end)

  it("returns true when first value is true", fun ()
    let result = true or "ignored"
    assert_eq(result, true, "Should return true")
  end)

  it("chains multiple values", fun ()
    let result = nil or false or "found"
    assert_eq(result, "found", "Should return first truthy in chain")
  end)

  it("short-circuits evaluation", fun ()
    let counter = 0
    fun increment()
      counter = counter + 1
      "incremented"
    end

    let result = "first" or increment()
    assert_eq(result, "first", "Should return first")
    assert_eq(counter, 0, "Should not evaluate second operand")
  end)

  it("evaluates second operand when first is falsy", fun ()
    let counter = 0
    fun increment()
      counter = counter + 1
      "incremented"
    end

    let result = nil or increment()
    assert_eq(result, "incremented", "Should return second")
    assert_eq(counter, 1, "Should evaluate second operand")
  end)
end)

describe("and operator returns values (not booleans)", fun ()
  it("returns second value when both are truthy", fun ()
    let result = "first" and "second"
    assert_eq(result, "second", "Should return second value")
  end)

  it("returns first value if it's nil", fun ()
    let result = nil and "never"
    assert_eq(result, nil, "Should return nil")
  end)

  it("returns first value if it's false", fun ()
    let result = false and "never"
    assert_eq(result, false, "Should return false")
  end)

  it("returns first falsy in chain", fun ()
    let result = "first" and nil and "third"
    assert_eq(result, nil, "Should return first falsy value")
  end)

  it("returns last value if all truthy", fun ()
    let result = "first" and "second" and "third"
    assert_eq(result, "third", "Should return last value")
  end)

  it("short-circuits on false", fun ()
    let counter = 0
    fun increment()
      counter = counter + 1
      "incremented"
    end

    let result = false and increment()
    assert_eq(result, false, "Should return false")
    assert_eq(counter, 0, "Should not evaluate second operand")
  end)

  it("short-circuits on nil", fun ()
    let counter = 0
    fun increment()
      counter = counter + 1
      "incremented"
    end

    let result = nil and increment()
    assert_eq(result, nil, "Should return nil")
    assert_eq(counter, 0, "Should not evaluate second operand")
  end)

  it("evaluates second operand when first is truthy", fun ()
    let counter = 0
    fun increment()
      counter = counter + 1
      "incremented"
    end

    let result = "first" and increment()
    assert_eq(result, "incremented", "Should return second")
    assert_eq(counter, 1, "Should evaluate second operand")
  end)
end)

describe("practical use cases", fun ()
  it("default value pattern with or", fun ()
    let name = nil
    let display = name or "Anonymous"
    assert_eq(display, "Anonymous", "Should use default")

    name = "Alice"
    display = name or "Anonymous"
    assert_eq(display, "Alice", "Should use actual value")
  end)

  it("chaining fallbacks with or", fun ()
    let user_config = nil
    let system_config = nil
    let default_config = "default"

    let config = user_config or system_config or default_config
    assert_eq(config, "default", "Should use first non-nil")
  end)

  it("guard pattern with and", fun ()
    let user = {name: "Alice", active: true}

    let result = user["active"] and user["name"]
    assert_eq(result, "Alice", "Should return name if active")

    user["active"] = false
    result = user["active"] and user["name"]
    assert_eq(result, false, "Should return false if not active")
  end)
end)
