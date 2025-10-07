use "std/test"

test.module("Numeric Bases")

test.describe("Binary literals", fun ()
    test.it("parses binary", fun ()
        test.assert_eq(0b1010, 10)        test.assert_eq(0b11111111, 255)    end)

    test.it("parses zero", fun ()
        test.assert_eq(0b0, 0)    end)

    test.it("creates Int type", fun ()
        let x = 0b1010
        test.assert_eq(x.cls(), "Int")
    end)

    test.it("supports uppercase B", fun ()
        test.assert_eq(0B1111, 15)    end)

    test.it("handles large binary numbers", fun ()
        let x = 0b11111111111111111111111111111111
        test.assert(x > 0, "Should be positive")
    end)
end)

test.describe("Hexadecimal literals", fun ()
    test.it("parses hex", fun ()
        test.assert_eq(0xFF, 255)        test.assert_eq(0xDEADBEEF, 3735928559)    end)

    test.it("parses zero", fun ()
        test.assert_eq(0x0, 0)    end)

    test.it("is case-insensitive", fun ()
        test.assert_eq(0xff, 0xFF)        test.assert_eq(0xAbCd, 0xABCD)        test.assert_eq(0xabcd, 0xABCD)    end)

    test.it("creates Int type", fun ()
        let x = 0xFF
        test.assert_eq(x.cls(), "Int")
    end)

    test.it("supports uppercase X", fun ()
        test.assert_eq(0XFF, 255)    end)

    test.it("handles color codes", fun ()
        let red = 0xFF0000
        let green = 0x00FF00
        let blue = 0x0000FF
        let white = 0xFFFFFF

        test.assert_eq(red, 16711680)        test.assert_eq(green, 65280)        test.assert_eq(blue, 255)        test.assert_eq(white, 16777215)    end)
end)

test.describe("Octal literals", fun ()
    test.it("parses octal", fun ()
        test.assert_eq(0o755, 493)        test.assert_eq(0o777, 511)    end)

    test.it("parses zero", fun ()
        test.assert_eq(0o0, 0)    end)

    test.it("creates Int type", fun ()
        let x = 0o755
        test.assert_eq(x.cls(), "Int")
    end)

    test.it("supports uppercase O", fun ()
        test.assert_eq(0O755, 493)    end)

    test.it("handles file permissions", fun ()
        let rwxrxrx = 0o755
        let rwr_r_ = 0o644
        let rwxrwxrwx = 0o777
        let r__r__r__ = 0o444

        test.assert_eq(rwxrxrx, 493)        test.assert_eq(rwr_r_, 420)        test.assert_eq(rwxrwxrwx, 511)        test.assert_eq(r__r__r__, 292)    end)
end)

test.describe("Mixed bases in expressions", fun ()
    test.it("can mix binary and decimal", fun ()
        let x = 0b1010 + 5
        test.assert_eq(x, 15)    end)

    test.it("can mix hex and decimal", fun ()
        let x = 0xFF + 1
        test.assert_eq(x, 256)    end)

    test.it("can mix octal and decimal", fun ()
        let x = 0o10 + 2
        test.assert_eq(x, 10)    end)

    test.it("can compare different bases", fun ()
        test.assert(0xFF == 255, "0xFF should equal 255")
        test.assert(0b1111 == 15, "0b1111 should equal 15")
        test.assert(0o10 == 8, "0o10 should equal 8")
    end)
end)

test.describe("Real-world use cases", fun ()
    test.it("bit flags", fun ()
        let READ = 0b001
        let WRITE = 0b010
        let EXECUTE = 0b100
        let RW = READ | WRITE
        let RWX = READ | WRITE | EXECUTE

        test.assert_eq(READ, 1)        test.assert_eq(WRITE, 2)        test.assert_eq(EXECUTE, 4)        test.assert_eq(RW, 3)        test.assert_eq(RWX, 7)    end)

    test.it("bit masking", fun ()
        let flags = 0b10101010
        let mask = 0b11110000
        let result = flags & mask

        test.assert_eq(result, 0b10100000)    end)

    test.it("color extraction with bitwise AND", fun ()
        let color = 0xFF8800  # Orange
        let green_mask = 0x00FF00
        let green_channel = color & green_mask

        test.assert_eq(green_channel, 0x008800)    end)
end)
