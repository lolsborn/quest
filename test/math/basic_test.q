# Basic Math Operations Tests
# Tests fundamental arithmetic operations

use "std/test" { module, describe, it, assert_eq }

module("Math Tests - Basic")

describe("Addition", fun ()
  it("adds positive numbers", fun ()
    assert_eq(2 + 3, 5, "2 + 3 should equal 5")
  end)

  it("adds negative numbers", fun ()
    assert_eq(-5 + (-3), -8, "-5 + -3 should equal -8")
  end)

  it("adds positive and negative", fun ()
    assert_eq(10 + (-4), 6, "10 + -4 should equal 6")
  end)

  it("adds zero", fun ()
    assert_eq(42 + 0, 42, "42 + 0 should equal 42")
  end)
end)

describe("Subtraction", fun ()
  it("subtracts positive numbers", fun ()
    assert_eq(10 - 3, 7, "10 - 3 should equal 7")
  end)

  it("subtracts negative numbers", fun ()
    assert_eq(5 - (-3), 8, "5 - -3 should equal 8")
  end)

  it("subtracts to negative", fun ()
    assert_eq(3 - 10, -7, "3 - 10 should equal -7")
  end)
end)

describe("Multiplication", fun ()
  it("multiplies positive numbers", fun ()
    assert_eq(4 * 5, 20, "4 * 5 should equal 20")
  end)

  it("multiplies by zero", fun ()
    assert_eq(100 * 0, 0, "100 * 0 should equal 0")
  end)

  it("multiplies negative numbers", fun ()
    assert_eq(-3 * -4, 12, "-3 * -4 should equal 12")
  end)

  it("multiplies positive and negative", fun ()
    assert_eq(6 * (-2), -12, "6 * -2 should equal -12")
  end)
end)

describe("Division", fun ()
  it("divides evenly", fun ()
    assert_eq(20 / 4, 5, "20 / 4 should equal 5")
  end)

  it("integer division truncates (type-preserving)", fun ()
    assert_eq(7 / 2, 3, "7 / 2 should equal 3 (integer division)")
    assert_eq(10 / 3, 3, "10 / 3 should equal 3 (truncates)")
  end)

  it("float division is exact", fun ()
    assert_eq(7.0 / 2.0, 3.5, "7.0 / 2.0 should equal 3.5")
    assert_eq(10.0 / 3.0, 3.3333333333333335, "10.0 / 3.0 is exact float division")
  end)

  it("divides negative numbers", fun ()
    assert_eq(-12 / 3, -4, "-12 / 3 should equal -4")
  end)
end)

describe("Modulo", fun ()
  it("calculates remainder", fun ()
    assert_eq(10 % 3, 1, "10 % 3 should equal 1")
  end)

  it("modulo with zero remainder", fun ()
    assert_eq(15 % 5, 0, "15 % 5 should equal 0")
  end)
end)

describe("Type-Preserving Arithmetic", fun ()
  it("int + int = int", fun ()
    let result = 5 + 3
    assert_eq(result, 8, "5 + 3 should equal 8")
    assert_eq(result.cls(), "Int", "Result should be Int type")
  end)

  it("float + float = float", fun ()
    let result = 5.0 + 3.0
    assert_eq(result, 8.0, "5.0 + 3.0 should equal 8.0")
    assert_eq(result.cls(), "Float", "Result should be Float type")
  end)

  it("int * int = int", fun ()
    let result = 7 * 3
    assert_eq(result, 21, "7 * 3 should equal 21")
    assert_eq(result.cls(), "Int", "Result should be Int type")
  end)

  it("float * float = float", fun ()
    let result = 7.0 * 3.0
    assert_eq(result, 21.0, "7.0 * 3.0 should equal 21.0")
    assert_eq(result.cls(), "Float", "Result should be Float type")
  end)

  it("int / int = int (truncates)", fun ()
    let result = 7 / 2
    assert_eq(result, 3, "7 / 2 should equal 3 (truncated)")
    assert_eq(result.cls(), "Int", "Result should be Int type")
  end)

  it("float / float = float (exact)", fun ()
    let result = 7.0 / 2.0
    assert_eq(result, 3.5, "7.0 / 2.0 should equal 3.5")
    assert_eq(result.cls(), "Float", "Result should be Float type")
  end)
end)

describe("Type Promotion (Mixed Operations)", fun ()
  it("int + float = float", fun ()
    let result = 5 + 3.0
    assert_eq(result, 8.0, "5 + 3.0 should equal 8.0")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("float + int = float", fun ()
    let result = 5.0 + 3
    assert_eq(result, 8.0, "5.0 + 3 should equal 8.0")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("int * float = float", fun ()
    let result = 7 * 2.0
    assert_eq(result, 14.0, "7 * 2.0 should equal 14.0")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("float * int = float", fun ()
    let result = 7.0 * 2
    assert_eq(result, 14.0, "7.0 * 2 should equal 14.0")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("int / float = float", fun ()
    let result = 7 / 2.0
    assert_eq(result, 3.5, "7 / 2.0 should equal 3.5")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("float / int = float", fun ()
    let result = 7.0 / 2
    assert_eq(result, 3.5, "7.0 / 2 should equal 3.5")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("subtraction also promotes", fun ()
    let result = 10 - 3.5
    assert_eq(result, 6.5, "10 - 3.5 should equal 6.5")
    assert_eq(result.cls(), "Float", "Result should be Float (promoted)")
  end)

  it("modulo promotes to float", fun ()
    let result = 10 % 3.0
    assert_eq(result.cls(), "Float", "Int % Float should return Float")
  end)
end)

describe("Operator Precedence", fun ()
  it("multiplication before addition", fun ()
    assert_eq(2 + 3 * 4, 14, "2 + 3 * 4 should equal 14")
  end)

  it("parentheses override precedence", fun ()
    assert_eq((2 + 3) * 4, 20, "(2 + 3) * 4 should equal 20")
  end)

  it("complex expression", fun ()
    assert_eq(10 - 2 * 3 + 4, 8, "10 - 2 * 3 + 4 should equal 8")
  end)
end)
