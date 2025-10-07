use "std/test"

test.module("Digit Separators")

test.describe("Underscores in integers", fun ()
    test.it("works with small numbers", fun ()
        test.assert_eq(1_000, 1000)    end)

    test.it("works with millions", fun ()
        test.assert_eq(1_000_000, 1000000)    end)

    test.it("works with billions", fun ()
        test.assert_eq(7_900_000_000, 7900000000)    end)

    test.it("allows arbitrary grouping", fun ()
        test.assert_eq(12_34_56, 123456)    end)
end)

test.describe("Underscores in floats", fun ()
    test.it("works in decimal part", fun ()
        test.assert_eq(3.141_592, 3.141592)    end)

    test.it("works in integer part", fun ()
        test.assert_eq(1_000.5, 1000.5)    end)

    test.it("works in both parts", fun ()
        test.assert_eq(1_234.567_89, 1234.56789)    end)
end)

test.describe("Underscores in scientific notation", fun ()
    test.it("works in mantissa", fun ()
        let x = 6.022_140_76e23
        test.assert(x > 0.0, "Should be positive")
    end)

    test.it("works in exponent", fun ()
        let x = 1e1_00
        test.assert(x > 0.0, "Should be positive")
    end)

    test.it("works in both", fun ()
        let x = 1_000e1_0
        test.assert(x > 0.0, "Should be positive")
    end)
end)

test.describe("Underscores in binary literals", fun ()
    test.it("groups by nibbles", fun ()
        test.assert_eq(0b1111_0000, 240)    end)

    test.it("groups by bytes", fun ()
        test.assert_eq(0b1111_0000_1010_0101, 61605)    end)

    test.it("allows irregular grouping", fun ()
        test.assert_eq(0b1_0_1_0, 10)    end)
end)

test.describe("Underscores in hexadecimal literals", fun ()
    test.it("groups by bytes", fun ()
        test.assert_eq(0xFF_00, 65280)    end)

    test.it("groups RGB color", fun ()
        test.assert_eq(0xFF_80_00, 16744448)    end)

    test.it("works with irregular grouping", fun ()
        test.assert_eq(0xDEAD_BEEF, 3735928559)    end)
end)

test.describe("Underscores in octal literals", fun ()
    test.it("groups by threes", fun ()
        test.assert_eq(0o755_644, 252836)    end)

    test.it("works with file permissions", fun ()
        test.assert_eq(0o7_5_5, 493)    end)
end)

test.describe("Real-world use cases", fun ()
    test.it("financial numbers", fun ()
        let million = 1_000_000
        let billion = 1_000_000_000
        let national_debt = 31_400_000_000_000

        test.assert_eq(million, 1000000)        test.assert_eq(billion, 1000000000)        test.assert_eq(national_debt, 31400000000000)    end)

    test.it("scientific constants", fun ()
        let pi = 3.141_592_653_589_793
        let e = 2.718_281_828_459_045

        test.assert(pi > 3.14, "Pi should be > 3.14")
        test.assert(e > 2.71, "e should be > 2.71")
    end)

    test.it("IPv4 address as binary", fun ()
        let ip = 0b11000000_10101000_00000001_00000001
        test.assert_eq(ip, 3232235777, "Should be 192.168.1.1")
    end)

    test.it("color with separators", fun ()
        let orange = 0xFF_88_00
        test.assert_eq(orange, 16746496)    end)
end)
