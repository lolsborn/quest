use "std/test"

test.module("Bitwise Operators")

test.describe("Bitwise OR (|)", fun ()
    test.it("performs bitwise OR", fun ()
        test.assert_eq(5 | 3, 7, "5 | 3 = 7 (0101 | 0011 = 0111)")
        test.assert_eq(0b1010 | 0b0101, 0b1111, "Binary OR")
        test.assert_eq(0xFF | 0x00, 0xFF, "0xFF | 0x00 = 0xFF")
    end)

    test.it("handles zero", fun ()
        test.assert_eq(0 | 0, 0, nil)
        test.assert_eq(42 | 0, 42, nil)
        test.assert_eq(0 | 42, 42, nil)
    end)

    test.it("is commutative", fun ()
        test.assert_eq(5 | 3, 3 | 5, nil)
        test.assert_eq(0xFF | 0x0F, 0x0F | 0xFF, nil)
    end)
end)

test.describe("Bitwise AND (&)", fun ()
    test.it("performs bitwise AND", fun ()
        test.assert_eq(5 & 3, 1, "5 & 3 = 1 (0101 & 0011 = 0001)")
        test.assert_eq(0b1010 & 0b0110, 0b0010, "Binary AND")
        test.assert_eq(0xFF & 0x0F, 0x0F, "Masking low bits")
    end)

    test.it("handles zero", fun ()
        test.assert_eq(0 & 0, 0, nil)
        test.assert_eq(42 & 0, 0, "AND with 0 gives 0")
        test.assert_eq(0 & 42, 0, nil)
    end)

    test.it("is commutative", fun ()
        test.assert_eq(5 & 3, 3 & 5, nil)
        test.assert_eq(0xFF & 0x0F, 0x0F & 0xFF, nil)
    end)

    test.it("masks bits efficiently", fun ()
        test.assert_eq(255 & 0xFF, 255, nil)
        test.assert_eq(256 & 0xFF, 0, "256 mod 256 via masking")
        test.assert_eq(257 & 0xFF, 1, "257 mod 256 via masking")
    end)
end)

test.describe("Bitwise XOR (^)", fun ()
    test.it("performs bitwise XOR", fun ()
        test.assert_eq(5 ^ 3, 6, "5 ^ 3 = 6 (0101 ^ 0011 = 0110)")
        test.assert_eq(0b1010 ^ 0b0110, 0b1100, "Binary XOR")
        test.assert_eq(0xFF ^ 0xFF, 0, "XOR with self gives 0")
    end)

    test.it("handles zero", fun ()
        test.assert_eq(0 ^ 0, 0, nil)
        test.assert_eq(42 ^ 0, 42, "XOR with 0 gives original")
        test.assert_eq(0 ^ 42, 42, nil)
    end)

    test.it("is commutative", fun ()
        test.assert_eq(5 ^ 3, 3 ^ 5, nil)
        test.assert_eq(0xFF ^ 0x0F, 0x0F ^ 0xFF, nil)
    end)

    test.it("is self-inverse", fun ()
        test.assert_eq(42 ^ 17 ^ 17, 42, "XOR twice returns original")
        test.assert_eq(5 ^ 5, 0, "XOR with self gives 0")
    end)
end)

test.describe("Left shift (<<)", fun ()
    test.it("shifts bits left", fun ()
        test.assert_eq(1 << 0, 1, nil)
        test.assert_eq(1 << 1, 2, nil)
        test.assert_eq(1 << 8, 256, nil)
        test.assert_eq(1 << 16, 65536, nil)
    end)

    test.it("is equivalent to multiplication by powers of 2", fun ()
        test.assert_eq(5 << 1, 10, "5 * 2")
        test.assert_eq(5 << 2, 20, "5 * 4")
        test.assert_eq(5 << 3, 40, "5 * 8")
    end)

    test.it("handles zero shift", fun ()
        test.assert_eq(42 << 0, 42, nil)
    end)
end)

test.describe("Right shift (>>)", fun ()
    test.it("shifts bits right", fun ()
        test.assert_eq(256 >> 0, 256, nil)
        test.assert_eq(256 >> 1, 128, nil)
        test.assert_eq(256 >> 8, 1, nil)
        test.assert_eq(255 >> 1, 127, nil)
    end)

    test.it("is equivalent to integer division by powers of 2", fun ()
        test.assert_eq(20 >> 1, 10, "20 / 2")
        test.assert_eq(20 >> 2, 5, "20 / 4")
        test.assert_eq(20 >> 3, 2, "20 / 8 (truncated)")
    end)

    test.it("handles zero shift", fun ()
        test.assert_eq(42 >> 0, 42, nil)
    end)
end)

test.describe("Bitwise NOT (~)", fun ()
    test.it("performs bitwise complement", fun ()
        test.assert_eq(~0, -1, "NOT 0 is -1 (two's complement)")
        test.assert_eq(~(-1), 0, "NOT -1 is 0")
    end)

    test.it("follows two's complement rules", fun ()
        test.assert_eq(~5, -6, "~5 = -6")
        test.assert_eq(~(-6), 5, "~(-6) = 5")
        test.assert_eq(~0xFF, -256, nil)
    end)

    test.it("double NOT returns original", fun ()
        test.assert_eq(~(~42), 42, nil)
        test.assert_eq(~(~0), 0, nil)
    end)
end)

test.describe("Combined operations", fun ()
    test.it("combines shifts and OR", fun ()
        let packed = (1 << 8) | (1 << 4) | 1
        test.assert_eq(packed, 273, "0x111")
    end)

    test.it("extracts bytes with AND", fun ()
        test.assert_eq(0xDEADBEEF & 0xFF, 0xEF, "Extract low byte")
        test.assert_eq((0xDEADBEEF >> 8) & 0xFF, 0xBE, "Extract second byte")
    end)

    test.it("toggles bits with XOR", fun ()
        let value = 0b1010
        let toggled = value ^ 0b1111
        test.assert_eq(toggled, 0b0101, "Toggle all bits")
    end)

    test.it("clears bits with AND NOT", fun ()
        let value = 0b1111
        let cleared = value & (~0b1010)
        test.assert_eq(cleared, 0b0101, "Clear specific bits")
    end)
end)

test.describe("Practical use cases", fun ()
    test.it("packs RGB color values", fun ()
        let r = 255
        let g = 128
        let b = 64
        let color = (r << 16) | (g << 8) | b
        test.assert_eq(color, 16744512, "RGB(255, 128, 64)")
    end)

    test.it("unpacks RGB color values", fun ()
        let color = 16744512
        let r = (color >> 16) & 0xFF
        let g = (color >> 8) & 0xFF
        let b = color & 0xFF
        test.assert_eq(r, 255, "Red channel")
        test.assert_eq(g, 128, "Green channel")
        test.assert_eq(b, 64, "Blue channel")
    end)

    test.it("fast modulo with power of 2", fun ()
        test.assert_eq(257 & 0xFF, 1, "257 % 256")
        test.assert_eq(1027 & 0x3FF, 3, "1027 % 1024")
    end)

    test.it("checks if number is even or odd", fun ()
        test.assert_eq(42 & 1, 0, "42 is even")
        test.assert_eq(43 & 1, 1, "43 is odd")
    end)

    test.it("swaps bytes", fun ()
        fun swap16(n)
            ((n & 0xFF) << 8) | ((n >> 8) & 0xFF)
        end

        test.assert_eq(swap16(0x1234), 0x3412, "Byte swap")
    end)
end)
