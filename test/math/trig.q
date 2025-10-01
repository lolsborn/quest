# Trigonometric Functions Tests
# Tests math module trig functions

use "std/test" as test
use "std/math" as math

test.describe("Sine Function", fun ()
    test.it("calculates sin(0)", fun ()
        test.assert_near(math.sin(0), 0, 0.0001, nil)
    end)

    test.it("calculates sin(pi/2)", fun ()
        test.assert_near(math.sin(math.pi / 2), 1, 0.0001, nil)
    end)

    test.it("calculates sin(pi)", fun ()
        test.assert_near(math.sin(math.pi), 0, 0.0001, nil)
    end)

    test.it("calculates sin(3*pi/2)", fun ()
        test.assert_near(math.sin(3 * math.pi / 2), -1, 0.0001, nil)
    end)

    test.it("calculates sin(2*pi)", fun ()
        test.assert_near(math.sin(2 * math.pi), 0, 0.0001, nil)
    end)
end)

test.describe("Cosine Function", fun ()
    test.it("calculates cos(0)", fun ()
        test.assert_near(math.cos(0), 1, 0.0001, nil)
    end)

    test.it("calculates cos(pi/2)", fun ()
        test.assert_near(math.cos(math.pi / 2), 0, 0.0001, nil)
    end)

    test.it("calculates cos(pi)", fun ()
        test.assert_near(math.cos(math.pi), -1, 0.0001, nil)
    end)

    test.it("calculates cos(3*pi/2)", fun ()
        test.assert_near(math.cos(3 * math.pi / 2), 0, 0.0001, nil)
    end)

    test.it("calculates cos(2*pi)", fun ()
        test.assert_near(math.cos(2 * math.pi), 1, 0.0001, nil)
    end)
end)

test.describe("Tangent Function", fun ()
    test.it("calculates tan(0)", fun ()
        test.assert_near(math.tan(0), 0, 0.0001, nil)
    end)

    test.it("calculates tan(pi/4)", fun ()
        test.assert_near(math.tan(math.pi / 4), 1, 0.0001, nil)
    end)

    test.it("calculates tan(pi)", fun ()
        test.assert_near(math.tan(math.pi), 0, 0.0001, nil)
    end)

    test.it("calculates tan(-pi/4)", fun ()
        test.assert_near(math.tan(0 - math.pi / 4), -1, 0.0001, nil)
    end)
end)

test.describe("Inverse Sine (arcsin)", fun ()
    test.it("calculates asin(0)", fun ()
        test.assert_near(math.asin(0), 0, 0.0001, nil)
    end)

    test.it("calculates asin(1)", fun ()
        test.assert_near(math.asin(1), math.pi / 2, 0.0001, nil)
    end)

    test.it("calculates asin(-1)", fun ()
        test.assert_near(math.asin(-1), 0 - math.pi / 2, 0.0001, nil)
    end)

    test.it("calculates asin(0.5)", fun ()
        test.assert_near(math.asin(0.5), math.pi / 6, 0.0001, nil)
    end)
end)

test.describe("Inverse Cosine (arccos)", fun ()
    test.it("calculates acos(1)", fun ()
        test.assert_near(math.acos(1), 0, 0.0001, nil)
    end)

    test.it("calculates acos(0)", fun ()
        test.assert_near(math.acos(0), math.pi / 2, 0.0001, nil)
    end)

    test.it("calculates acos(-1)", fun ()
        test.assert_near(math.acos(-1), math.pi, 0.0001, nil)
    end)

    test.it("calculates acos(0.5)", fun ()
        test.assert_near(math.acos(0.5), math.pi / 3, 0.0001, nil)
    end)
end)

test.describe("Inverse Tangent (arctan)", fun ()
    test.it("calculates atan(0)", fun ()
        test.assert_near(math.atan(0), 0, 0.0001, nil)
    end)

    test.it("calculates atan(1)", fun ()
        test.assert_near(math.atan(1), math.pi / 4, 0.0001, nil)
    end)

    test.it("calculates atan(-1)", fun ()
        test.assert_near(math.atan(-1), 0 - math.pi / 4, 0.0001, nil)
    end)

    test.it("calculates atan of large values", fun ()
        let result = math.atan(1000)
        test.assert(result > 1.5 and result < 1.6, "atan(1000) should be close to pi/2")
    end)
end)

test.describe("Pythagorean Identity", fun ()
    test.it("sin^2(x) + cos^2(x) = 1 for x = pi/6", fun ()
        let x = math.pi / 6
        let sin_x = math.sin(x)
        let cos_x = math.cos(x)
        test.assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001, nil)
    end)

    test.it("sin^2(x) + cos^2(x) = 1 for x = pi/3", fun ()
        let x = math.pi / 3
        let sin_x = math.sin(x)
        let cos_x = math.cos(x)
        test.assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001, nil)
    end)

    test.it("sin^2(x) + cos^2(x) = 1 for x = 1.234", fun ()
        let x = 1.234
        let sin_x = math.sin(x)
        let cos_x = math.cos(x)
        test.assert_near(sin_x * sin_x + cos_x * cos_x, 1, 0.0001, nil)
    end)
end)

test.describe("Tangent Identity", fun ()
    test.it("tan(x) = sin(x) / cos(x) for x = pi/6", fun ()
        let x = math.pi / 6
        let tan_direct = math.tan(x)
        let tan_ratio = math.sin(x) / math.cos(x)
        test.assert_near(tan_direct, tan_ratio, 0.0001, nil)
    end)

    test.it("tan(x) = sin(x) / cos(x) for x = pi/4", fun ()
        let x = math.pi / 4
        let tan_direct = math.tan(x)
        let tan_ratio = math.sin(x) / math.cos(x)
        test.assert_near(tan_direct, tan_ratio, 0.0001, nil)
    end)
end)

test.describe("Inverse Function Properties", fun ()
    test.it("asin(sin(x)) approx x for x in [-pi/2, pi/2]", fun ()
        let x = 0.5
        test.assert_near(math.asin(math.sin(x)), x, 0.0001, nil)
    end)

    test.it("acos(cos(x)) approx x for x in [0, pi]", fun ()
        let x = 1.0
        test.assert_near(math.acos(math.cos(x)), x, 0.0001, nil)
    end)

    test.it("atan(tan(x)) approx x for x in (-pi/2, pi/2)", fun ()
        let x = 0.7
        test.assert_near(math.atan(math.tan(x)), x, 0.0001, nil)
    end)
end)

test.describe("Special Angle Values", fun ()
    test.it("sin(30deg) = 0.5", fun ()
        test.assert_near(math.sin(math.pi / 6), 0.5, 0.0001, nil)
    end)

    test.it("cos(60deg) = 0.5", fun ()
        test.assert_near(math.cos(math.pi / 3), 0.5, 0.0001, nil)
    end)

    test.it("sin(45deg) = cos(45deg)", fun ()
        let angle = math.pi / 4
        test.assert_near(math.sin(angle), math.cos(angle), 0.0001, nil)
    end)

    test.it("sin(45deg) = sqrt(2)/2", fun ()
        let sqrt2_over_2 = math.sqrt(2) / 2
        test.assert_near(math.sin(math.pi / 4), sqrt2_over_2, 0.0001, nil)
    end)
end)
