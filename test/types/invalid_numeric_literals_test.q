use "std/test"
use "std/sys"

test.module("Invalid Numeric Literals")

test.describe("Malformed hex literals should error", fun ()
    test.it("rejects non-hex digits", fun ()
        # 0xGHI contains invalid hex digits (G, H, I)
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0xGHI")
        end, nil)
    end)

    test.it("rejects hex prefix without digits", fun ()
        # 0x without following digits should fail
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0x")
        end, nil)
    end)
end)

test.describe("Malformed binary literals should error", fun ()
    test.it("rejects non-binary digits", fun ()
        # 0b1012 contains invalid binary digit (2)
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0b1012")
        end, nil)
    end)

    test.it("rejects binary prefix without digits", fun ()
        # 0b without following digits should fail
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0b")
        end, nil)
    end)
end)

test.describe("Malformed octal literals should error", fun ()
    test.it("rejects non-octal digits", fun ()
        # 0o789 contains invalid octal digits (8, 9)
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0o789")
        end, nil)
    end)

    test.it("rejects octal prefix without digits", fun ()
        # 0o without following digits should fail
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0o")
        end, nil)
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
        # 0xFFGG should fail because GG is not valid hex
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0xFFGG")
        end, nil)
    end)

    test.it("binary can't be followed by invalid digits", fun ()
        # 0b1012 should fail because 2 is not valid binary
        test.assert_raises("ParseError", fun ()
            sys.eval("let x = 0b1012")
        end, nil)
    end)
end)
