use "std/test"

test.module("Scientific Notation")

test.describe("Basic scientific notation", fun ()
    test.it("parses positive exponent", fun ()
        let x = 1e3
        test.assert_eq(x, 1000.0, nil)
    end)

    test.it("parses negative exponent", fun ()
        let x = 1e-3
        test.assert_eq(x, 0.001, nil)
    end)

    test.it("parses with decimal mantissa", fun ()
        let x = 3.14e2
        test.assert_eq(x, 314.0, nil)
    end)

    test.it("handles large exponents", fun ()
        let x = 1e100
        test.assert(x > 0.0, "Should be positive")
        test.assert(not x.is_infinite(), "Should be finite")
    end)

    test.it("handles small exponents", fun ()
        let x = 1e-100
        test.assert(x > 0.0, "Should be positive")
        test.assert(x < 1.0, "Should be less than 1")
    end)

    test.it("supports uppercase E", fun ()
        let x = 1E5
        test.assert_eq(x, 100000.0, nil)
    end)

    test.it("supports explicit positive sign", fun ()
        let x = 1e+3
        test.assert_eq(x, 1000.0, nil)
    end)
end)

test.describe("Scientific notation creates Float type", fun ()
    test.it("1e10 is Float not Int", fun ()
        let x = 1e10
        test.assert_eq(x.cls(), "Float", nil)
    end)

    test.it("even without decimal point", fun ()
        let x = 5e2
        test.assert_eq(x.cls(), "Float", nil)
        test.assert_eq(x, 500.0, nil)
    end)
end)

test.describe("Real-world constants", fun ()
    test.it("parses physics constants", fun ()
        let c = 2.998e8              # Speed of light (m/s)
        let G = 6.674e-11            # Gravitational constant
        let h = 6.626e-34            # Planck constant

        test.assert(c > 0.0, "Speed of light should be positive")
        test.assert(G > 0.0, "G should be positive")
        test.assert(h > 0.0, "Planck constant should be positive")
    end)

    test.it("parses chemistry constants", fun ()
        let avogadro = 6.022e23      # Avogadro's number
        let molar_mass_h2o = 1.8e-2  # kg/mol

        test.assert(avogadro > 1e23, "Avogadro number should be huge")
        test.assert(molar_mass_h2o < 1.0, "Molar mass should be small")
    end)

    test.it("parses astronomical values", fun ()
        let earth_mass = 5.972e24    # kg
        let sun_radius = 6.96e8      # meters

        test.assert(earth_mass > 0.0, "Earth mass should be positive")
        test.assert(sun_radius > 0.0, "Sun radius should be positive")
    end)
end)

test.describe("Edge cases", fun ()
    test.it("handles zero exponent", fun ()
        let x = 5e0
        test.assert_eq(x, 5.0, nil)
    end)

    test.it("handles very large mantissa", fun ()
        let x = 999.999e10
        test.assert(x > 0.0, "Should be positive")
    end)

    test.it("handles multiple digits in exponent", fun ()
        let x = 1e100
        test.assert(not x.is_infinite(), "Should not overflow to infinity")
    end)
end)

test.describe("Mathematical operations", fun ()
    test.it("can add scientific notation numbers", fun ()
        let x = 1e3
        let y = 2e3
        let z = x + y
        test.assert_eq(z, 3000.0, nil)
    end)

    test.it("can multiply scientific notation numbers", fun ()
        let x = 1e5
        let y = 2e5
        let z = x * y
        test.assert_eq(z, 2e10, nil)
    end)

    test.it("can compare scientific notation numbers", fun ()
        let x = 1e10
        let y = 1e9
        test.assert(x > y, "1e10 should be greater than 1e9")
    end)
end)
