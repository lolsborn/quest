use "std/test" { module, describe, it, assert_eq }

module("Bitwise Operators")

describe("Bitwise OR (|)", fun ()
  it("performs bitwise OR", fun ()
    assert_eq(5 | 3, 7, "5 | 3 = 7 (0101 | 0011 = 0111)")
    assert_eq(0b1010 | 0b0101, 0b1111, "Binary OR")
    assert_eq(0xFF | 0x00, 0xFF, "0xFF | 0x00 = 0xFF")
  end)

  it("handles zero", fun ()
    assert_eq(0 | 0, 0)    assert_eq(42 | 0, 42)    assert_eq(0 | 42, 42)  end)

  it("is commutative", fun ()
    assert_eq(5 | 3, 3 | 5)    assert_eq(0xFF | 0x0F, 0x0F | 0xFF)  end)
end)

describe("Bitwise AND (&)", fun ()
  it("performs bitwise AND", fun ()
    assert_eq(5 & 3, 1, "5 & 3 = 1 (0101 & 0011 = 0001)")
    assert_eq(0b1010 & 0b0110, 0b0010, "Binary AND")
    assert_eq(0xFF & 0x0F, 0x0F, "Masking low bits")
  end)

  it("handles zero", fun ()
    assert_eq(0 & 0, 0)    assert_eq(42 & 0, 0, "AND with 0 gives 0")
    assert_eq(0 & 42, 0)  end)

  it("is commutative", fun ()
    assert_eq(5 & 3, 3 & 5)    assert_eq(0xFF & 0x0F, 0x0F & 0xFF)  end)

  it("masks bits efficiently", fun ()
    assert_eq(255 & 0xFF, 255)    assert_eq(256 & 0xFF, 0, "256 mod 256 via masking")
    assert_eq(257 & 0xFF, 1, "257 mod 256 via masking")
  end)
end)

describe("Bitwise XOR (^)", fun ()
  it("performs bitwise XOR", fun ()
    assert_eq(5 ^ 3, 6, "5 ^ 3 = 6 (0101 ^ 0011 = 0110)")
    assert_eq(0b1010 ^ 0b0110, 0b1100, "Binary XOR")
    assert_eq(0xFF ^ 0xFF, 0, "XOR with self gives 0")
  end)

  it("handles zero", fun ()
    assert_eq(0 ^ 0, 0)    assert_eq(42 ^ 0, 42, "XOR with 0 gives original")
    assert_eq(0 ^ 42, 42)  end)

  it("is commutative", fun ()
    assert_eq(5 ^ 3, 3 ^ 5)    assert_eq(0xFF ^ 0x0F, 0x0F ^ 0xFF)  end)

  it("is self-inverse", fun ()
    assert_eq(42 ^ 17 ^ 17, 42, "XOR twice returns original")
    assert_eq(5 ^ 5, 0, "XOR with self gives 0")
  end)
end)

describe("Left shift (<<)", fun ()
  it("shifts bits left", fun ()
    assert_eq(1 << 0, 1)    assert_eq(1 << 1, 2)    assert_eq(1 << 8, 256)    assert_eq(1 << 16, 65536)  end)

  it("is equivalent to multiplication by powers of 2", fun ()
    assert_eq(5 << 1, 10, "5 * 2")
    assert_eq(5 << 2, 20, "5 * 4")
    assert_eq(5 << 3, 40, "5 * 8")
  end)

  it("handles zero shift", fun ()
    assert_eq(42 << 0, 42)  end)
end)

describe("Right shift (>>)", fun ()
  it("shifts bits right", fun ()
    assert_eq(256 >> 0, 256)    assert_eq(256 >> 1, 128)    assert_eq(256 >> 8, 1)    assert_eq(255 >> 1, 127)  end)

  it("is equivalent to integer division by powers of 2", fun ()
    assert_eq(20 >> 1, 10, "20 / 2")
    assert_eq(20 >> 2, 5, "20 / 4")
    assert_eq(20 >> 3, 2, "20 / 8 (truncated)")
  end)

  it("handles zero shift", fun ()
    assert_eq(42 >> 0, 42)  end)
end)

describe("Bitwise NOT (~)", fun ()
  it("performs bitwise complement", fun ()
    assert_eq(~0, -1, "NOT 0 is -1 (two's complement)")
    assert_eq(~(-1), 0, "NOT -1 is 0")
  end)

  it("follows two's complement rules", fun ()
    assert_eq(~5, -6, "~5 = -6")
    assert_eq(~(-6), 5, "~(-6) = 5")
    assert_eq(~0xFF, -256)  end)

  it("double NOT returns original", fun ()
    assert_eq(~(~42), 42)
    assert_eq(~(~0), 0)
  end)
end)

describe("Combined operations", fun ()
  it("combines shifts and OR", fun ()
    let packed = (1 << 8) | (1 << 4) | 1
    assert_eq(packed, 273, "0x111")
  end)

  it("extracts bytes with AND", fun ()
    assert_eq(0xDEADBEEF & 0xFF, 0xEF, "Extract low byte")
    assert_eq((0xDEADBEEF >> 8) & 0xFF, 0xBE, "Extract second byte")
  end)

  it("toggles bits with XOR", fun ()
    let value = 0b1010
    let toggled = value ^ 0b1111
    assert_eq(toggled, 0b0101, "Toggle all bits")
  end)

  it("clears bits with AND NOT", fun ()
    let value = 0b1111
    let cleared = value & (~0b1010)
    assert_eq(cleared, 0b0101, "Clear specific bits")
  end)
end)

describe("Practical use cases", fun ()
  it("packs RGB color values", fun ()
    let r = 255
    let g = 128
    let b = 64
    let color = (r << 16) | (g << 8) | b
    assert_eq(color, 16744512, "RGB(255, 128, 64)")
  end)

  it("unpacks RGB color values", fun ()
    let color = 16744512
    let r = (color >> 16) & 0xFF
    let g = (color >> 8) & 0xFF
    let b = color & 0xFF
    assert_eq(r, 255, "Red channel")
    assert_eq(g, 128, "Green channel")
    assert_eq(b, 64, "Blue channel")
  end)

  it("fast modulo with power of 2", fun ()
    assert_eq(257 & 0xFF, 1, "257 % 256")
    assert_eq(1027 & 0x3FF, 3, "1027 % 1024")
  end)

  it("checks if number is even or odd", fun ()
    assert_eq(42 & 1, 0, "42 is even")
    assert_eq(43 & 1, 1, "43 is odd")
  end)

  it("swaps bytes", fun ()
    fun swap16(n)
      ((n & 0xFF) << 8) | ((n >> 8) & 0xFF)
    end

    assert_eq(swap16(0x1234), 0x3412, "Byte swap")
  end)
end)
