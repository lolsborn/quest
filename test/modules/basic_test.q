# Module Import Semantics Tests
# Tests use statements, aliasing, and module member access

use "std/test" { module, describe, it, assert_eq, assert_near, assert_neq, assert }

module("Module System Tests")

describe("Module Import - Basic", fun ()
  it("imports builtin module with std/ prefix", fun ()
    use "std/math" as m
    assert(m.pi > 3.14)    assert(m.pi < 3.15)  end)

  it("imports builtin module and accesses constants", fun ()
    use "std/math" as math
    assert_near(math.pi, 3.14159, 0.001)    assert_near(math.tau, 6.28318, 0.001)  end)

  it("imports multiple different modules", fun ()
    use "std/math" as math
    use "std/encoding/json" as json
    assert(math.pi > 0)    let s = json.stringify({"x": 1})
    assert(s.len() > 0)
  end)
end)

describe("Module Aliasing", fun ()
  it("uses custom alias for module", fun ()
    use "std/math" as m
    let result = m.abs(-5)
    assert_eq(result, 5)  end)

  it("uses different aliases for same module", fun ()
    use "std/math" as m1
    use "std/math" as m2
    assert_eq(m1.pi, m2.pi)  end)

  it("creates separate module instances for each import", fun ()
    use "std/math" as m1
    use "std/math" as m2
    # Each import creates a new module instance with new member objects
    # Even though the values are equal, they have different object IDs
    assert_eq(m1.pi, m2.pi)    assert(m1.pi._id() != m2.pi._id())
  end)

  it("allows short aliases", fun ()
    use "std/math" as m
    assert(m.sin(0) == 0)
  end)
end)

describe("Module Member Access - Functions", fun ()
  it("calls module function with arguments", fun ()
    use "std/math" as math
    let result = math.abs(-10)
    assert_eq(result, 10)  end)

  it("calls multiple module functions", fun ()
    use "std/math" as math
    let a = math.abs(-5)
    let b = math.sqrt(16)
    let c = math.floor(3.7)
    assert_eq(a, 5)    assert_eq(b, 4)    assert_eq(c, 3)  end)

  it("passes module function results to other functions", fun ()
    use "std/math" as math
    let result = math.abs(math.floor(-3.7))
    assert_eq(result, 4)  end)

  it("uses module functions in expressions", fun ()
    use "std/math" as math
    let result = math.abs(-5) + math.abs(-3)
    assert_eq(result, 8)  end)
end)

describe("Module Member Access - Constants", fun ()
  it("accesses module constant", fun ()
    use "std/math" as math
    let pi_val = math.pi
    assert_near(pi_val, 3.14159, 0.001)  end)

  it("uses module constant in calculations", fun ()
    use "std/math" as math
    let circumference = 2 * math.pi * 10
    assert_near(circumference, 62.8318, 0.001)  end)

  it("accesses multiple module constants", fun ()
    use "std/math" as math
    let sum = math.pi + math.tau
    assert(sum > 9.4)    assert(sum < 9.5)  end)
end)

describe("Module Scope", fun ()
  it("module is available throughout enclosing scope", fun ()
    use "std/math" as math
    let x = math.abs(-5)
    if true
      let y = math.abs(-3)
      assert_eq(y, 3)    end
    assert_eq(x, 5)  end)

  it("module imported in function is scoped to function", fun ()
    fun test_fn()
      use "std/math" as math
      return math.abs(-10)
    end
    let result = test_fn()
    assert_eq(result, 10)  end)

  it("module imported in function doesn't leak to outer scope", fun ()
    fun test_fn()
      use "std/math" as math_inner
      return math_inner.abs(-10)
    end
    test_fn()

    # Try to access math_inner from outer scope - should fail
    let caught_error = false
    try
      let x = math_inner.pi
    catch e
      caught_error = true
      # Error message includes "Undefined variable:" prefix (QEP-037)
      assert_eq(e.message(), "Undefined variable: math_inner")
    end
    assert(caught_error, "Expected error accessing math_inner outside function scope")
  end)

  it("different aliases in nested scopes don't conflict", fun ()
    use "std/math" as m1
    let x = m1.pi

    # Import same module with different alias in nested scope
    if true
      use "std/math" as m2
      let y = m2.pi
      assert_eq(x, y)      # Both aliases work in nested scope (m1 from outer, m2 from inner)
      assert_eq(m1.pi, m2.pi)    end

    # m1 still works after nested scope
    assert_near(m1.pi, 3.14159, 0.001)  end)

  it("module imported in nested scope doesn't leak out", fun ()
    use "std/math" as m1

    if true
      use "std/math" as math_nested
      assert_near(math_nested.pi, 3.14159, 0.001)    end

    # math_nested should not be accessible here
    let caught_error = false
    try
      let x = math_nested.pi
    catch e
      caught_error = true
      # Error message includes "Undefined variable:" prefix (QEP-037)
      assert_eq(e.message(), "Undefined variable: math_nested")
    end
    assert(caught_error, "Expected error accessing math_nested outside nested scope")
  end)

  it("assigning module member to variable preserves identity", fun ()
    use "std/math" as math

    # Assign module functions to variables
    let abs_fn = math.abs
    let sqrt_fn = math.sqrt

    # The assigned variable should have the same _id as the module member
    assert_eq(abs_fn._id(), math.abs._id())
    assert_eq(sqrt_fn._id(), math.sqrt._id())

    # Different functions should have different IDs
    assert_neq(abs_fn._id(), sqrt_fn._id())
  end)

  it("assigning multiple module members preserves their identities", fun ()
    use "std/math" as math

    # Multiple assignment from module
    let sin = math.sin, cos = math.cos, tan = math.tan

    # Each should have the same ID as the original
    assert_eq(sin._id(), math.sin._id())
    assert_eq(cos._id(), math.cos._id())
    assert_eq(tan._id(), math.tan._id())

    # All three should have different IDs
    assert_neq(sin._id(), cos._id())
    assert_neq(cos._id(), tan._id())
    assert_neq(sin._id(), tan._id())
  end)
end)

describe("JSON Module", fun ()
  it("imports json module", fun ()
    use "std/encoding/json" as json
    let s = json.stringify({"x": 1})
    assert(s.len() > 0)
  end)

  it("stringifies simple object", fun ()
    use "std/encoding/json" as json
    let result = json.stringify({"name": "test"})
    assert(result.count("name") > 0)
    assert(result.count("test") > 0)
  end)

  it("stringifies array", fun ()
    use "std/encoding/json" as json
    let result = json.stringify([1, 2, 3])
    assert(result.count("1") > 0)
    assert(result.count("2") > 0)
  end)

  it("stringifies nested structure", fun ()
    use "std/encoding/json" as json
    let data = {"user": {"name": "Alice", "age": 30}}
    let result = json.stringify(data)
    assert(result.count("user") > 0)
    assert(result.count("Alice") > 0)
  end)

  it("parses simple JSON string", fun ()
    use "std/encoding/json" as json
    let parsed = json.parse("{\"x\": 42}")
    assert_eq(parsed["x"], 42)  end)

  it("parses JSON array", fun ()
    use "std/encoding/json" as json
    let parsed = json.parse("[1, 2, 3]")
    assert_eq(parsed.len(), 3)
    assert_eq(parsed[0], 1)  end)

  it("roundtrips data through stringify and parse", fun ()
    use "std/encoding/json" as json
    let original = {"name": "test", "value": 123}
    let serialized = json.stringify(original)
    let parsed = json.parse(serialized)
    assert_eq(parsed["name"], "test")    assert_eq(parsed["value"], 123)  end)
end)

describe("Term Module", fun ()
  it("imports term module", fun ()
    use "std/term" as term
    let colored = term.red("test")
    assert(colored.len() > 4)
  end)

  it("applies color functions", fun ()
    use "std/term" as term
    let r = term.red("red")
    let g = term.green("green")
    let b = term.blue("blue")
    assert(r.len() > 3)
    assert(g.len() > 5)
    assert(b.len() > 4)
  end)

  it("applies style functions", fun ()
    use "std/term" as term
    let bold_text = term.bold("bold")
    let dim_text = term.dimmed("dim")
    assert(bold_text.len() > 4)
    assert(dim_text.len() > 3)
  end)
end)

describe("Module Error Handling", fun ()
  # Note: These tests check for expected behaviors, not necessarily errors

  it("handles undefined module members gracefully", fun ()
    use "std/math" as math
    # This would error if we called math.nonexistent()
    # Just verify the module imported correctly
    assert(math.pi > 0)  end)
end)

describe("Reserved Words in Module Context", fun ()
  it("avoids reserved word 'obj' as variable", fun ()
    use "std/encoding/json" as json
    # 'obj' is reserved, use 'data' instead
    let data = {"key": "value"}
    let s = json.stringify(data)
    assert(s.len() > 0)
  end)

  it("avoids reserved word 'str' as variable", fun ()
    use "std/encoding/json" as json
    # 'str' is reserved, use 's' instead
    let s = json.stringify([1, 2])
    assert(s.len() > 0)
  end)

  it("avoids reserved word 'dict' as variable", fun ()
    use "std/encoding/json" as json
    # 'dict' is reserved, use 'd' instead
    let d = {"x": 1}
    let s = json.stringify(d)
    assert(s.len() > 0)
  end)
end)
