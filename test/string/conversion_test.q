use "std/test"

test.module("String Conversion Methods")

test.describe("to_int() - basic conversions", fun ()
    test.it("converts decimal string to int", fun ()
        test.assert_eq("123".to_int(), 123)
        test.assert_eq("0".to_int(), 0)
        test.assert_eq("-456".to_int(), -456)
    end)

    test.it("handles whitespace", fun ()
        test.assert_eq("  123  ".to_int(), 123)
        test.assert_eq("\t789\n".to_int(), 789)
    end)

    test.it("handles underscores in numbers", fun ()
        test.assert_eq("1_000_000".to_int(), 1000000)
        test.assert_eq("123_456".to_int(), 123456)
    end)

    test.it("converts hexadecimal strings", fun ()
        test.assert_eq("0xFF".to_int(), 255)
        test.assert_eq("0x10".to_int(), 16)
        test.assert_eq("0xDEADBEEF".to_int(), 3735928559)
    end)

    test.it("converts binary strings", fun ()
        test.assert_eq("0b1010".to_int(), 10)
        test.assert_eq("0b11111111".to_int(), 255)
        test.assert_eq("0b0".to_int(), 0)
    end)

    test.it("converts octal strings", fun ()
        test.assert_eq("0o755".to_int(), 493)
        test.assert_eq("0o10".to_int(), 8)
        test.assert_eq("0o0".to_int(), 0)
    end)

    test.it("raises error on invalid input", fun ()
        # Test that invalid strings raise exceptions
        try
            "abc".to_int()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end

        try
            "123.45".to_int()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("to_float() - basic conversions", fun ()
    test.it("converts decimal string to float", fun ()
        test.assert_eq("3.14".to_float(), 3.14)
        test.assert_eq("0.0".to_float(), 0.0)
        test.assert_eq("-2.5".to_float(), -2.5)
    end)

    test.it("converts integer strings to float", fun ()
        test.assert_eq("42".to_float(), 42.0)
        test.assert_eq("-10".to_float(), -10.0)
    end)

    test.it("handles scientific notation", fun ()
        test.assert_eq("1e3".to_float(), 1000.0)
        test.assert_eq("1.5e2".to_float(), 150.0)
        test.assert_eq("2.5e-2".to_float(), 0.025)
    end)

    test.it("handles whitespace", fun ()
        test.assert_eq("  3.14  ".to_float(), 3.14)
    end)

    test.it("handles underscores", fun ()
        test.assert_eq("1_000.5".to_float(), 1000.5)
    end)

    test.it("raises error on invalid input", fun ()
        try
            "not a number".to_float()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("to_decimal() - arbitrary precision", fun ()
    test.it("converts decimal string to Decimal", fun ()
        let d = "123.456".to_decimal()
        test.assert_eq(d.to_string(), "123.456")
    end)

    test.it("converts integer string to Decimal", fun ()
        let d = "42".to_decimal()
        test.assert_eq(d.to_string(), "42")
    end)

    test.it("handles very precise decimals", fun ()
        let d = "0.12345678901234567890".to_decimal()
        test.assert(d.to_string().contains("0.12345"))
    end)

    test.it("handles negative decimals", fun ()
        let d = "-99.99".to_decimal()
        test.assert_eq(d.to_string(), "-99.99")
    end)

    test.it("handles whitespace", fun ()
        let d = "  12.34  ".to_decimal()
        test.assert_eq(d.to_string(), "12.34")
    end)

    test.it("raises error on invalid input", fun ()
        try
            "not_a_decimal".to_decimal()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("to_bigint() - arbitrary precision integers", fun ()
    test.it("converts decimal string to BigInt", fun ()
        let b = "12345".to_bigint()
        test.assert_eq(b.to_string(), "12345")
    end)

    test.it("handles very large numbers", fun ()
        let b = "999999999999999999999999".to_bigint()
        test.assert_eq(b.to_string(), "999999999999999999999999")
    end)

    test.it("converts negative BigInt", fun ()
        let b = "-123456789012345".to_bigint()
        test.assert_eq(b.to_string(), "-123456789012345")
    end)

    test.it("handles trailing 'n' syntax", fun ()
        let b = "123n".to_bigint()
        test.assert_eq(b.to_string(), "123")
    end)

    test.it("handles hexadecimal BigInt", fun ()
        let b = "0xFFFFFFFFFFFFFFFF".to_bigint()
        test.assert_eq(b.to_string(), "18446744073709551615")
    end)

    test.it("handles binary BigInt", fun ()
        let b = "0b11111111".to_bigint()
        test.assert_eq(b.to_string(), "255")
    end)

    test.it("handles octal BigInt", fun ()
        let b = "0o777".to_bigint()
        test.assert_eq(b.to_string(), "511")
    end)

    test.it("handles underscores", fun ()
        let b = "1_000_000_000".to_bigint()
        test.assert_eq(b.to_string(), "1000000000")
    end)

    test.it("handles whitespace", fun ()
        let b = "  999  ".to_bigint()
        test.assert_eq(b.to_string(), "999")
    end)

    test.it("raises error on invalid input", fun ()
        try
            "not_a_bigint".to_bigint()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end

        try
            "123.45".to_bigint()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)
end)

test.describe("Cross-type conversions", fun ()
    test.it("int string converts to all types", fun ()
        let s = "42"
        test.assert_eq(s.to_int(), 42)
        test.assert_eq(s.to_float(), 42.0)
        test.assert_eq(s.to_decimal().to_string(), "42")
        test.assert_eq(s.to_bigint().to_string(), "42")
    end)

    test.it("negative numbers work across types", fun ()
        let s = "-100"
        test.assert_eq(s.to_int(), -100)
        test.assert_eq(s.to_float(), -100.0)
        test.assert_eq(s.to_decimal().to_string(), "-100")
        test.assert_eq(s.to_bigint().to_string(), "-100")
    end)

    test.it("zero works across types", fun ()
        let s = "0"
        test.assert_eq(s.to_int(), 0)
        test.assert_eq(s.to_float(), 0.0)
        test.assert_eq(s.to_decimal().to_string(), "0")
        test.assert_eq(s.to_bigint().to_string(), "0")
    end)
end)

test.describe("Real-world use cases", fun ()
    test.it("parses user input as int with error handling", fun ()
        let valid = "3000"
        let result = valid.to_int()
        test.assert_eq(result, 3000)
        # Test error case
        try
            "invalid".to_int()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true)        end
    end)

    test.it("parses environment variable", fun ()
        let env_value = "5432"
        let port = env_value.to_int()
        test.assert_eq(port, 5432)    end)

    test.it("parses price with decimal", fun ()
        let price_str = "19.99"
        let price = price_str.to_decimal()
        test.assert_eq(price.to_string(), "19.99")
    end)

    test.it("parses large ID as bigint", fun ()
        let id_str = "1234567890123456789"
        let id = id_str.to_bigint()
        test.assert_eq(id.to_string(), "1234567890123456789")
    end)
end)
