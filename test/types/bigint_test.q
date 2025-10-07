use "std/test"

test.describe("Literals", fun ()
    test.it("creates BigInt from literal", fun ()
        let x = 999999999999999999999999999n
        test.assert_eq(x.to_string(), "999999999999999999999999999")
    end)

    test.it("creates BigInt from hex literal", fun ()
        let x = 0xDEADBEEFn
        test.assert_eq(x.to_string(), "3735928559")
    end)

    test.it("creates BigInt from binary literal", fun ()
        let x = 0b11111111n
        test.assert_eq(x.to_string(), "255")
    end)

    test.it("creates BigInt from octal literal", fun ()
        let x = 0o377n
        test.assert_eq(x.to_string(), "255")
    end)

    test.it("supports negative literals", fun ()
        let x = -123n
        test.assert_eq(x.to_string(), "-123")
    end)
end)

test.describe("Construction", fun ()
    test.it("creates BigInt from string", fun ()
        let x = BigInt.new("999999999999999999999999999999")
        test.assert_eq(x.to_string(), "999999999999999999999999999999")
    end)

    test.it("creates BigInt from int", fun ()
        let x = BigInt.from_int(42)
        test.assert_eq(x.to_string(), "42")
    end)

    test.it("creates BigInt from negative string", fun ()
        let x = BigInt.new("-123456789012345678901234567890")
        test.assert_eq(x.to_string(), "-123456789012345678901234567890")
    end)

    test.it("creates BigInt from hex string", fun ()
        let x = BigInt.new("0xFF")
        test.assert_eq(x.to_string(), "255")
    end)

    test.it("creates BigInt from binary string", fun ()
        let x = BigInt.new("0b11111111")
        test.assert_eq(x.to_string(), "255")
    end)

    test.it("creates BigInt from octal string", fun ()
        let x = BigInt.new("0o377")
        test.assert_eq(x.to_string(), "255")
    end)

    test.it("creates BigInt from bytes", fun ()
        let bytes = b"\x00\xFF"
        let x = BigInt.from_bytes(bytes, true)
        test.assert_eq(x.to_string(), "255")
    end)
end)

test.describe("Constants", fun ()
    test.it("has ZERO constant", fun ()
        test.assert_eq(ZERO.to_string(), "0")
    end)

    test.it("has ONE constant", fun ()
        test.assert_eq(ONE.to_string(), "1")
    end)

    test.it("has TWO constant", fun ()
        test.assert_eq(TWO.to_string(), "2")
    end)

    test.it("has TEN constant", fun ()
        test.assert_eq(TEN.to_string(), "10")
    end)
end)

test.describe("Arithmetic - Addition", fun ()
    test.it("adds two BigInts with literals", fun ()
        let a = 99999999999999999999n
        let b = 1n
        let c = a.plus(b)
        test.assert_eq(c.to_string(), "100000000000000000000")
    end)

    test.it("adds large BigInts", fun ()
        let a = BigInt.new("12345678901234567890123456789012345678901234567890")
        let b = BigInt.new("98765432109876543210987654321098765432109876543210")
        let c = a.plus(b)
        test.assert_eq(c.to_string(), "111111111011111111101111111110111111111011111111100")
    end)
end)

test.describe("Arithmetic - Subtraction", fun ()
    test.it("subtracts BigInts", fun ()
        let a = BigInt.new("100000000000000000000")
        let b = BigInt.new("1")
        let c = a.minus(b)
        test.assert_eq(c.to_string(), "99999999999999999999")
    end)

    test.it("handles negative results", fun ()
        let a = BigInt.new("5")
        let b = BigInt.new("10")
        let c = a.minus(b)
        test.assert_eq(c.to_string(), "-5")
    end)
end)

test.describe("Arithmetic - Multiplication", fun ()
    test.it("multiplies BigInts", fun ()
        let a = BigInt.new("12345678901234567890")
        let b = BigInt.new("98765432109876543210")
        let c = a.times(b)
        test.assert_eq(c.to_string(), "1219326311370217952237463801111263526900")
    end)
end)

test.describe("Arithmetic - Division", fun ()
    test.it("divides BigInts", fun ()
        let a = BigInt.new("100000000000000000000")
        let b = BigInt.new("10")
        let c = a.div(b)
        test.assert_eq(c.to_string(), "10000000000000000000")
    end)

    test.it("truncates toward zero", fun ()
        let a = BigInt.new("17")
        let b = BigInt.new("5")
        let c = a.div(b)
        test.assert_eq(c.to_string(), "3")
    end)

    test.it("raises error on division by zero", fun ()
        test.assert_raises(RuntimeErr, fun ()
            let a = BigInt.new("10")
            a.div(ZERO)
        end)
    end)
end)

test.describe("Arithmetic - Modulo", fun ()
    test.it("computes modulo", fun ()
        let a = BigInt.new("17")
        let b = BigInt.new("5")
        let c = a.mod(b)
        test.assert_eq(c.to_string(), "2")
    end)

    test.it("raises error on modulo by zero", fun ()
        test.assert_raises(RuntimeErr, fun ()
            let a = BigInt.new("10")
            a.mod(ZERO)
        end)
    end)
end)

test.describe("Arithmetic - divmod", fun ()
    test.it("returns quotient and remainder", fun ()
        let a = BigInt.new("17")
        let b = BigInt.new("5")
        let result = a.divmod(b)
        test.assert_eq(result.len(), 2)
        test.assert_eq(result.get(0).to_string(), "3")
        test.assert_eq(result.get(1).to_string(), "2")
    end)
end)

test.describe("Arithmetic - Power", fun ()
    test.it("computes power", fun ()
        let x = TWO.pow(BigInt.from_int(10))
        test.assert_eq(x.to_string(), "1024")
    end)

    test.it("computes large power", fun ()
        let x = TWO.pow(BigInt.from_int(100))
        test.assert_eq(x.to_string(), "1267650600228229401496703205376")
    end)

    test.it("computes modular exponentiation", fun ()
        let base = BigInt.new("12345")
        let exp = BigInt.new("100")
        let mod = BigInt.new("99999")
        let result = base.pow(exp, mod)
        # (12345^100) % 99999 = 67077
        test.assert_eq(result.to_string(), "67077")
    end)
end)

test.describe("Arithmetic - abs and negate", fun ()
    test.it("computes absolute value", fun ()
        let x = BigInt.new("-12345678901234567890")
        let y = x.abs()
        test.assert_eq(y.to_string(), "12345678901234567890")
    end)

    test.it("negates value", fun ()
        let x = BigInt.new("12345678901234567890")
        let y = x.negate()
        test.assert_eq(y.to_string(), "-12345678901234567890")
    end)

    test.it("double negation returns original", fun ()
        let x = BigInt.new("42")
        let y = x.negate().negate()
        test.assert_eq(y.to_string(), "42")
    end)
end)

test.describe("Comparison", fun ()
    test.it("tests equality", fun ()
        let a = BigInt.new("123")
        let b = BigInt.new("123")
        test.assert_eq(a.equals(b), true)
    end)

    test.it("tests inequality", fun ()
        let a = BigInt.new("123")
        let b = BigInt.new("456")
        test.assert_eq(a.not_equals(b), true)
    end)

    test.it("tests less than", fun ()
        let a = BigInt.new("123")
        let b = BigInt.new("456")
        test.assert_eq(a.less_than(b), true)
        test.assert_eq(b.less_than(a), false)
    end)

    test.it("tests less than or equal", fun ()
        let a = BigInt.new("123")
        let b = BigInt.new("123")
        let c = BigInt.new("456")
        test.assert_eq(a.less_equal(b), true)
        test.assert_eq(a.less_equal(c), true)
    end)

    test.it("tests greater than", fun ()
        let a = BigInt.new("456")
        let b = BigInt.new("123")
        test.assert_eq(a.greater(b), true)
        test.assert_eq(b.greater(a), false)
    end)

    test.it("tests greater than or equal", fun ()
        let a = BigInt.new("123")
        let b = BigInt.new("123")
        let c = BigInt.new("456")
        test.assert_eq(c.greater_equal(b), true)
        test.assert_eq(a.greater_equal(b), true)
    end)
end)

test.describe("Bitwise Operations", fun ()
    test.it("performs bitwise AND", fun ()
        let a = BigInt.new("15")  # 1111
        let b = BigInt.new("7")   # 0111
        let c = a.bit_and(b)
        test.assert_eq(c.to_string(), "7")
    end)

    test.it("performs bitwise OR", fun ()
        let a = BigInt.new("12")  # 1100
        let b = BigInt.new("10")  # 1010
        let c = a.bit_or(b)
        test.assert_eq(c.to_string(), "14")  # 1110
    end)

    test.it("performs bitwise XOR", fun ()
        let a = BigInt.new("12")  # 1100
        let b = BigInt.new("10")  # 1010
        let c = a.bit_xor(b)
        test.assert_eq(c.to_string(), "6")  # 0110
    end)

    test.it("performs bitwise NOT on zero", fun ()
        let a = BigInt.new("0")
        let b = a.bit_not()
        test.assert_eq(b.to_string(), "-1")
    end)

    test.it("performs bitwise NOT on non-zero", fun ()
        let a = BigInt.new("5")
        let b = a.bit_not()
        # ~5 = -6 (two's complement: ~x = -(x+1))
        test.assert_eq(b.to_string(), "-6")
    end)

    test.it("performs left shift", fun ()
        let a = BigInt.new("1")
        let b = a.shl(10)
        test.assert_eq(b.to_string(), "1024")
    end)

    test.it("performs right shift", fun ()
        let a = BigInt.new("1024")
        let b = a.shr(10)
        test.assert_eq(b.to_string(), "1")
    end)
end)

test.describe("Conversions", fun ()
    test.it("converts to int", fun ()
        let x = BigInt.new("42")
        let y = x.to_int()
        test.assert_eq(y, 42)    end)

    test.it("raises error when too large for int", fun ()
        test.assert_raises(RuntimeErr, fun ()
            let x = BigInt.new("999999999999999999999999999999")
            x.to_int()
        end)
    end)

    test.it("converts to float", fun ()
        let x = BigInt.new("12345")
        let y = x.to_float()
        test.assert_eq(y, 12345.0)    end)

    test.it("converts to string with different bases", fun ()
        let x = BigInt.new("255")
        test.assert_eq(x.to_string(), "255")
        test.assert_eq(x.to_string(16), "ff")
        test.assert_eq(x.to_string(2), "11111111")
        test.assert_eq(x.to_string(8), "377")
    end)

    test.it("converts to bytes", fun ()
        let x = BigInt.new("255")
        let bytes = x.to_bytes()
        # Signed representation of 255 needs 2 bytes (0x00 0xFF)
        # to distinguish from -1 (which would be 0xFF in signed)
        test.assert_eq(bytes.len(), 2)
    end)
end)

test.describe("Utility Methods", fun ()
    test.it("tests is_zero", fun ()
        test.assert_eq(ZERO.is_zero(), true)
        test.assert_eq(ONE.is_zero(), false)
    end)

    test.it("tests is_positive", fun ()
        test.assert_eq(ONE.is_positive(), true)
        test.assert_eq(ZERO.is_positive(), false)
        test.assert_eq(ONE.negate().is_positive(), false)
    end)

    test.it("tests is_negative", fun ()
        test.assert_eq(ONE.negate().is_negative(), true)
        test.assert_eq(ZERO.is_negative(), false)
        test.assert_eq(ONE.is_negative(), false)
    end)

    test.it("tests is_even", fun ()
        test.assert_eq(TWO.is_even(), true)
        test.assert_eq(ONE.is_even(), false)
    end)

    test.it("tests is_odd", fun ()
        test.assert_eq(ONE.is_odd(), true)
        test.assert_eq(TWO.is_odd(), false)
    end)

    test.it("computes bit_length", fun ()
        let x = BigInt.new("255")
        test.assert_eq(x.bit_length(), 8)
        let y = BigInt.new("256")
        test.assert_eq(y.bit_length(), 9)
    end)
end)

test.describe("Large Number Operations", fun ()
    test.it("handles 2^1000", fun ()
        let x = TWO.pow(BigInt.from_int(1000))
        let str = x.to_string()
        # 2^1000 has 302 digits
        test.assert_eq(str.len() > 300, true)
    end)

    test.it("computes factorial(20)", fun ()
        # 20! = 2432902008176640000
        let result = ONE
        let i = ONE

        while i.less_equal(BigInt.from_int(20))
            result = result.times(i)
            i = i.plus(ONE)
        end

        test.assert_eq(result.to_string(), "2432902008176640000")
    end)
end)

test.describe("Object Methods", fun ()
    test.it("has cls method", fun ()
        let x = BigInt.new("42")
        test.assert_eq(x.cls(), "BigInt")
    end)

    test.it("has _str method", fun ()
        let x = BigInt.new("42")
        test.assert_eq(x._str(), "42")
    end)

    test.it("has _rep method", fun ()
        let x = BigInt.new("42")
        test.assert_eq(x._rep(), "BigInt(42)")
    end)

    test.it("has _id method", fun ()
        let x = BigInt.new("42")
        let y = BigInt.new("42")
        # Different objects should have different IDs
        test.assert_neq(x._id(), y._id())
    end)
end)
