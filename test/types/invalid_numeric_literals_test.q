use "std/test"

test.module("Invalid Numeric Literals")

test.describe("Malformed hex literals should error", fun ()
    test.it("rejects non-hex digits", fun ()
        # Note: eval() doesn't exist yet, so we'll test this differently
        # For now, we just document that 0xGHI should fail to parse
        test.skip(false, "Need eval() to test parse errors")
    end)

    test.it("rejects hex prefix without digits", fun ()
        test.skip(false, "Need eval() to test parse errors")
    end)
end)

test.describe("Malformed binary literals should error", fun ()
    test.it("rejects non-binary digits", fun ()
        test.skip(false, "Need eval() to test parse errors")
    end)

    test.it("rejects binary prefix without digits", fun ()
        test.skip(false, "Need eval() to test parse errors")
    end)
end)

test.describe("Malformed octal literals should error", fun ()
    test.it("rejects non-octal digits", fun ()
        test.skip(false, "Need eval() to test parse errors")
    end)

    test.it("rejects octal prefix without digits", fun ()
        test.skip(false, "Need eval() to test parse errors")
    end)
end)

test.describe("Valid edge cases that should work", fun ()
    test.it("handles zero in all bases", fun ()
        test.assert_eq(0x0, 0, nil)
        test.assert_eq(0b0, 0, nil)
        test.assert_eq(0o0, 0, nil)
    end)

    test.it("handles single digit in all bases", fun ()
        test.assert_eq(0x1, 1, nil)
        test.assert_eq(0b1, 1, nil)
        test.assert_eq(0o1, 1, nil)
    end)

    test.it("handles uppercase and lowercase prefixes", fun ()
        test.assert_eq(0xFF, 0xff, nil)
        test.assert_eq(0XFF, 0xff, nil)
        test.assert_eq(0B1111, 0b1111, nil)
        test.assert_eq(0O777, 0o777, nil)
    end)
end)

test.describe("Negative lookahead validation", fun ()
    test.it("hex can't be followed by more alphanumeric", fun ()
        # This would require eval() to properly test
        # 0xFFGG should fail because GG is not valid hex
        test.skip(false, "Need eval() to test parse errors")
    end)

    test.it("binary can't be followed by invalid digits", fun ()
        # 0b1012 should fail because 2 is not valid binary
        test.skip(false, "Need eval() to test parse errors")
    end)
end)

# Note: Most invalid literal tests require an eval() function to test
# parse errors. For now, we verify that valid literals work correctly
# and document the expected behavior for invalid literals in the QEP.
