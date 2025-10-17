use "std/test" { module, describe, it, assert_eq }

module("Elvis Operator (QEP-019)")

describe("Basic nil handling", fun ()
  it("returns left if not nil", fun ()
    let x = 5 ?: 10
    assert_eq(x, 5)
  end)

  it("returns right if left is nil", fun ()
    let x = nil ?: 10
    assert_eq(x, 10)
  end)

  it("works with variables", fun ()
    let a = 42
    let b = a ?: 99
    assert_eq(b, 42)
  end)

  it("uses default when variable is nil", fun ()
    let a = nil
    let b = a ?: 99
    assert_eq(b, 99)
  end)
end)

describe("Type preservation", fun ()
  it("works with strings", fun ()
    assert_eq("hello" ?: "world", "hello")
    assert_eq(nil ?: "world", "world")
  end)

  it("works with numbers", fun ()
    assert_eq(42 ?: 0, 42)
    assert_eq(nil ?: 0, 0)
  end)

  it("works with booleans", fun ()
    assert_eq(true ?: false, true)
    assert_eq(false ?: true, false, "false is not nil")
    assert_eq(nil ?: false, false)
  end)

  it("works with arrays", fun ()
    let arr = [1, 2] ?: []
    assert_eq(arr.len(), 2)

    let arr2 = nil ?: []
    assert_eq(arr2.len(), 0)
  end)

  it("works with dicts", fun ()
    let d = {"x": 10} ?: {}
    assert_eq(d.get("x"), 10)

    let d2 = nil ?: {}
    assert_eq(d2.keys().len(), 0)
  end)
end)

describe("Zero and false are not nil", fun ()
  it("zero is not treated as nil", fun ()
    let x = 0 ?: 10
    assert_eq(x, 0, "Zero should be returned, not default")
  end)

  it("false is not treated as nil", fun ()
    let x = false ?: true
    assert_eq(x, false, "False should be returned, not default")
  end)

  it("empty string is not treated as nil", fun ()
    let x = "" ?: "default"
    assert_eq(x, "", "Empty string should be returned")
  end)

  it("empty array is not treated as nil", fun ()
    let x = [] ?: [1, 2]
    assert_eq(x.len(), 0, "Empty array should be returned")
  end)
end)

describe("Chaining elvis operators", fun ()
  it("chains multiple defaults", fun ()
    let a = nil
    let b = nil
    let c = "final"

    let result = a ?: b ?: c
    assert_eq(result, "final")
  end)

  it("stops at first non-nil", fun ()
    let a = nil
    let b = "middle"
    let c = "final"

    let result = a ?: b ?: c
    assert_eq(result, "middle")
  end)

  it("all non-nil returns first", fun ()
    let a = "first"
    let b = "middle"
    let c = "final"

    let result = a ?: b ?: c
    assert_eq(result, "first")  end)

    it("chains with different types", fun ()
    let a = nil
    let b = nil
    let c = 42

    let result = a ?: b ?: c
    assert_eq(result, 42)
  end)
end)

describe("With expressions", fun ()
  it("works with arithmetic", fun ()
    let x = nil
    let result = x ?: 5 + 3
    assert_eq(result, 8)
  end)

  it("works with comparisons", fun ()
    let x = nil
    let result = x ?: 10 > 5
    assert_eq(result, true)
  end)

  it("works with method calls", fun ()
    let s = nil
    let result = s ?: "hello".upper()
    assert_eq(result, "HELLO")
  end)

  it("works with array access", fun ()
    let arr = [1, 2, 3]
    let x = nil
    let result = x ?: arr[1]
    assert_eq(result, 2)
  end)
end)

describe("Function call defaults", fun ()
  it("provides default for function returning nil", fun ()
    fun returns_nil()
      nil
    end

    let result = returns_nil() ?: 42
    assert_eq(result, 42)
  end)

  it("uses return value when non-nil", fun ()
    fun returns_value()
      100
    end

    let result = returns_value() ?: 42
    assert_eq(result, 100)
  end)

  it("function evaluated once", fun ()
    let call_count = 0

    fun track_calls()
      call_count = call_count + 1
      if call_count == 1
      nil
      else
      42
      end
    end

    let result = track_calls() ?: 99
    assert_eq(call_count, 1, "Function called exactly once")
    assert_eq(result, 99, "Got default")
  end)
end)

describe("Precedence", fun ()
  it("has lower precedence than arithmetic", fun ()
    let result = nil ?: 5 + 3
    assert_eq(result, 8, "Should be nil ?: (5 + 3)")
  end)

  it("has lower precedence than comparison", fun ()
    let result = nil ?: 10 > 5
    assert_eq(result, true, "Should be nil ?: (10 > 5)")
  end)

  it("has lower precedence than logical and", fun ()
    let result = nil ?: true and false
    assert_eq(result, false, "Should be nil ?: (true and false)")
  end)

  it("has lower precedence than logical or", fun ()
    let result = nil ?: false or true
    assert_eq(result, true, "Should be nil ?: (false or true)")
  end)
end)

describe("Edge cases", fun ()
  it("nested in expressions", fun ()
    let x = nil
    let result = (x ?: 5) + 3
    assert_eq(result, 8)
  end)

  it("both sides can be complex", fun ()
    let result = (1 + 2) ?: (3 + 4)
    assert_eq(result, 3, "Left is not nil")
    let result2 = nil ?: (3 + 4)
    assert_eq(result2, 7, "Right evaluated")
  end)

  it("works in assignments", fun ()
    let x = nil ?: 10
    assert_eq(x, 10)
  end)

  it("works in function arguments", fun ()
    fun take_arg(val)
      val
    end

    let result = take_arg(nil ?: 42)
    assert_eq(result, 42)  end)

    it("works in return statements", fun ()
    fun get_value(x)
      x ?: 100
    end

    assert_eq(get_value(50), 50)
    assert_eq(get_value(nil), 100)
  end)
end)
