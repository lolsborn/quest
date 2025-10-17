# Trigonometric Functions Tests
# Tests math module trig functions

use "std/test" { module, describe, it, assert_near, assert }
use "std/math"

module("Math Tests - Trigonometry")

describe("Sine Function", fun ()
  it("calculates sin(0)", fun ()
    assert_near(math.sin(0), 0, 0.0001)
  end)

  it("calculates sin(pi/2)", fun ()
    assert_near(math.sin(math.pi / 2), 1, 0.0001)
  end)

  it("calculates sin(pi)", fun ()
    assert_near(math.sin(math.pi), 0, 0.0001)
  end)

  it("calculates sin(3*pi/2)", fun ()
    assert_near(math.sin(3 * math.pi / 2), -1, 0.0001)
  end)

  it("calculates sin(2*pi)", fun ()
    assert_near(math.sin(2 * math.pi), 0, 0.0001)
  end)
end)

describe("Cosine Function", fun ()
  it("calculates cos(0)", fun ()
    assert_near(math.cos(0), 1, 0.0001)
  end)

  it("calculates cos(pi/2)", fun ()
    assert_near(math.cos(math.pi / 2), 0, 0.0001)
  end)

  it("calculates cos(pi)", fun ()
    assert_near(math.cos(math.pi), -1, 0.0001)
  end)

  it("calculates cos(3*pi/2)", fun ()
    assert_near(math.cos(3 * math.pi / 2), 0, 0.0001)
  end)

  it("calculates cos(2*pi)", fun ()
    assert_near(math.cos(2 * math.pi), 1, 0.0001)
  end)
end)

describe("Tangent Function", fun ()
  it("calculates tan(0)", fun ()
    assert_near(math.tan(0), 0, 0.0001)
  end)

  it("calculates tan(pi/4)", fun ()
    assert_near(math.tan(math.pi / 4), 1, 0.0001)
  end)

  it("calculates tan(pi)", fun ()
    assert_near(math.tan(math.pi), 0, 0.0001)
  end)

  it("calculates tan(-pi/4)", fun ()
    assert_near(math.tan(0 - math.pi / 4), -1, 0.0001)
  end)
end)

describe("Inverse Sine (arcsin)", fun ()
  it("calculates asin(0)", fun ()
    assert_near(math.asin(0), 0, 0.0001)
  end)

  it("calculates asin(1)", fun ()
    assert_near(math.asin(1), math.pi / 2, 0.0001)
  end)

  it("calculates asin(-1)", fun ()
    assert_near(math.asin(-1), 0 - math.pi / 2, 0.0001)
  end)

  it("calculates asin(0.5)", fun ()
    assert_near(math.asin(0.5), math.pi / 6, 0.0001)
  end)
end)

describe("Inverse Cosine (arccos)", fun ()
  it("calculates acos(1)", fun ()
    assert_near(math.acos(1), 0, 0.0001)
  end)

  it("calculates acos(0)", fun ()
    assert_near(math.acos(0), math.pi / 2, 0.0001)
  end)

  it("calculates acos(-1)", fun ()
    assert_near(math.acos(-1), math.pi, 0.0001)
  end)

  it("calculates acos(0.5)", fun ()
    assert_near(math.acos(0.5), math.pi / 3, 0.0001)
  end)
end)

describe("Inverse Tangent (arctan)", fun ()
  it("calculates atan(0)", fun ()
    assert_near(math.atan(0), 0, 0.0001)
  end)

  it("calculates atan(1)", fun ()
    assert_near(math.atan(1), math.pi / 4, 0.0001)
  end)

  it("calculates atan(-1)", fun ()
    assert_near(math.atan(-1), 0 - math.pi / 4, 0.0001)
  end)

  it("calculates atan of large values", fun ()
    let result = math.atan(1000)
    assert(result > 1.5 and result < 1.6, "atan(1000) should be close to pi/2")
  end)
end)

describe("Pythagorean Identity", fun ()
  it("sin^2(x) + cos^2(x) = 1 for x = pi/6", fun ()
    let x = math.pi / 6
    let sin_x = math.sin(x)
    let cos_x = math.cos(x)
    assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001)  end)

  it("sin^2(x) + cos^2(x) = 1 for x = pi/3", fun ()
    let x = math.pi / 3
    let sin_x = math.sin(x)
    let cos_x = math.cos(x)
    assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001)  end)

  it("sin^2(x) + cos^2(x) = 1 for x = 1.234", fun ()
    let x = 1.234
    let sin_x = math.sin(x)
    let cos_x = math.cos(x)
    assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001)  end)
end)

describe("Tangent Identity", fun ()
  it("tan(x) = sin(x) / cos(x) for x = pi/6", fun ()
    let x = math.pi / 6
    let tan_direct = math.tan(x)
    let tan_ratio = math.sin(x) / math.cos(x)
    assert_near(tan_direct, tan_ratio, 0.0001)  end)

  it("tan(x) = sin(x) / cos(x) for x = pi/4", fun ()
    let x = math.pi / 4
    let tan_direct = math.tan(x)
    let tan_ratio = math.sin(x) / math.cos(x)
    assert_near(tan_direct, tan_ratio, 0.0001)  end)
end)

describe("Inverse Function Properties", fun ()
  it("asin(sin(x)) approx x for x in [-pi/2, pi/2]", fun ()
    let x = 0.5
    assert_near(math.asin(math.sin(x)), x, 0.0001)
  end)

  it("acos(cos(x)) approx x for x in [0, pi]", fun ()
    let x = 1.0
    assert_near(math.acos(math.cos(x)), x, 0.0001)
  end)

  it("atan(tan(x)) approx x for x in (-pi/2, pi/2)", fun ()
    let x = 0.7
    assert_near(math.atan(math.tan(x)), x, 0.0001)
  end)
end)

describe("Special Angle Values", fun ()
  it("sin(30deg) = 0.5", fun ()
    assert_near(math.sin(math.pi / 6), 0.5, 0.0001)
  end)

  it("cos(60deg) = 0.5", fun ()
    assert_near(math.cos(math.pi / 3), 0.5, 0.0001)
  end)

  it("sin(45deg) = cos(45deg)", fun ()
    let angle = math.pi / 4
    assert_near(math.sin(angle), math.cos(angle), 0.0001)
  end)

  it("sin(45deg) = sqrt(2)/2", fun ()
    let sqrt2_over_2 = math.sqrt(2) / 2
    assert_near(math.sin(math.pi / 4), sqrt2_over_2, 0.0001)
  end)
end)
