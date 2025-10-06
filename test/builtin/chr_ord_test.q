use "std/test"

test.module("Built-in Functions - chr and ord")

test.describe("chr() - codepoint to character", fun ()
    test.it("converts ASCII codepoints", fun ()
        test.assert_eq(chr(65), "A", nil)
        test.assert_eq(chr(90), "Z", nil)
        test.assert_eq(chr(97), "a", nil)
        test.assert_eq(chr(122), "z", nil)
    end)

    test.it("converts digits", fun ()
        test.assert_eq(chr(48), "0", nil)
        test.assert_eq(chr(57), "9", nil)
    end)

    test.it("converts special characters", fun ()
        test.assert_eq(chr(32), " ", nil)
        test.assert_eq(chr(33), "!", nil)
        test.assert_eq(chr(64), "@", nil)
    end)

    test.it("converts Unicode characters", fun ()
        test.assert_eq(chr(8364), "€", nil)  # Euro sign
        test.assert_eq(chr(9731), "☃", nil)  # Snowman
        test.assert_eq(chr(128077), "👍", nil)  # Thumbs up
    end)

    test.it("handles low codepoints", fun ()
        test.assert_eq(chr(0).len(), 1, nil)  # Null byte exists
        test.assert_eq(chr(10), "\n", nil)
        test.assert_eq(chr(13), "\r", nil)
        test.assert_eq(chr(9), "\t", nil)
    end)

    test.it("raises error on invalid codepoint", fun ()
        try
            chr(0xFFFFFFFF)  # Invalid Unicode
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)

    test.it("works with floats", fun ()
        test.assert_eq(chr(65.7), "A", nil)  # Truncates to 65
    end)
end)

test.describe("ord() - character to codepoint", fun ()
    test.it("converts ASCII characters", fun ()
        test.assert_eq(ord("A"), 65, nil)
        test.assert_eq(ord("Z"), 90, nil)
        test.assert_eq(ord("a"), 97, nil)
        test.assert_eq(ord("z"), 122, nil)
    end)

    test.it("converts digits", fun ()
        test.assert_eq(ord("0"), 48, nil)
        test.assert_eq(ord("9"), 57, nil)
    end)

    test.it("converts special characters", fun ()
        test.assert_eq(ord(" "), 32, nil)
        test.assert_eq(ord("!"), 33, nil)
        test.assert_eq(ord("@"), 64, nil)
    end)

    test.it("converts Unicode characters", fun ()
        test.assert_eq(ord("€"), 8364, nil)  # Euro sign
        test.assert_eq(ord("☃"), 9731, nil)  # Snowman
        test.assert_eq(ord("👍"), 128077, nil)  # Thumbs up
    end)

    test.it("takes first character of multi-char string", fun ()
        test.assert_eq(ord("Hello"), 72, nil)  # H
        test.assert_eq(ord("ABC"), 65, nil)    # A
    end)

    test.it("raises error on empty string", fun ()
        try
            ord("")
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)
end)

test.describe("String.ord() method", fun ()
    test.it("works as method on string", fun ()
        test.assert_eq("A".ord(), 65, nil)
        test.assert_eq("Z".ord(), 90, nil)
    end)

    test.it("handles Unicode", fun ()
        test.assert_eq("€".ord(), 8364, nil)
        test.assert_eq("👍".ord(), 128077, nil)
    end)

    test.it("takes first character", fun ()
        test.assert_eq("Hello".ord(), 72, nil)
    end)

    test.it("raises error on empty string", fun ()
        try
            "".ord()
            test.assert(false, "Should have raised exception")
        catch e
            test.assert(true, nil)
        end
    end)
end)

test.describe("chr and ord roundtrip", fun ()
    test.it("roundtrips ASCII", fun ()
        test.assert_eq(chr(ord("A")), "A", nil)
        test.assert_eq(chr(ord("z")), "z", nil)
        test.assert_eq(ord(chr(65)), 65, nil)
        test.assert_eq(ord(chr(122)), 122, nil)
    end)

    test.it("roundtrips Unicode", fun ()
        test.assert_eq(chr(ord("€")), "€", nil)
        test.assert_eq(chr(ord("👍")), "👍", nil)
        test.assert_eq(ord(chr(8364)), 8364, nil)
    end)

    test.it("roundtrips using method syntax", fun ()
        test.assert_eq(chr("A".ord()), "A", nil)
        test.assert_eq(chr(65).ord(), 65, nil)
    end)
end)

test.describe("Real-world use cases", fun ()
    test.it("builds string from codepoints", fun ()
        let msg = chr(72) .. chr(101) .. chr(108) .. chr(108) .. chr(111)
        test.assert_eq(msg, "Hello", nil)
    end)

    test.it("gets codepoint range", fun ()
        let a_code = "A".ord()
        let z_code = "Z".ord()
        test.assert_eq(z_code - a_code, 25, nil)  # 26 letters, 0-indexed
    end)

    test.it("shifts characters", fun ()
        # Simple Caesar cipher
        let shifted = chr("A".ord() + 3)
        test.assert_eq(shifted, "D", nil)
    end)

    test.it("checks character ranges", fun ()
        let ch = "M"
        let code = ch.ord()
        let is_uppercase = code >= 65 and code <= 90
        test.assert(is_uppercase, nil)
    end)

    test.it("converts case manually", fun ()
        # Uppercase to lowercase (add 32)
        let upper = "A"
        let lower = chr(upper.ord() + 32)
        test.assert_eq(lower, "a", nil)
    end)
end)
