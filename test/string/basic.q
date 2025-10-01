# Basic String Tests
# Tests fundamental string operations and methods

use "std/test" as test

test.module("String Tests - Basic")

test.describe("String Creation", fun ()
    test.it("creates simple strings", fun ()
        let s = "hello"
        test.assert_eq(s, "hello", nil)
    end)

    test.it("creates empty strings", fun ()
        let s = ""
        test.assert_eq(s.len(), 0, nil)
    end)

    test.it("creates strings with spaces", fun ()
        let s = "hello world"
        test.assert_eq(s, "hello world", nil)
    end)

    test.it("creates multi-line strings", fun ()
        let s = """hello
world"""
        test.assert_eq(s.len(), 11, "should be 'hello\\nworld' (11 chars)")
        test.assert(s.count("\n") > 0, "should contain newline character")
    end)
end)

test.describe("String Length", fun ()
    test.it("returns correct length for empty string", fun ()
        test.assert_eq("".len(), 0, nil)
    end)

    test.it("returns correct length for single char", fun ()
        test.assert_eq("a".len(), 1, nil)
    end)

    test.it("returns correct length for multi-char", fun ()
        test.assert_eq("hello".len(), 5, nil)
    end)

    test.it("counts spaces in length", fun ()
        test.assert_eq("hello world".len(), 11, nil)
    end)
end)

test.describe("String Concatenation", fun ()
    test.it("concatenates two strings with ..", fun ()
        let result = "hello" .. " " .. "world"
        test.assert_eq(result, "hello world", nil)
    end)

    test.it("concatenates empty strings", fun ()
        let result = "" .. "test"
        test.assert_eq(result, "test", nil)
    end)

    test.it("concatenates with concat method", fun ()
        let result = "hello".concat(" world")
        test.assert_eq(result, "hello world", nil)
    end)

    test.it("chains multiple concatenations", fun ()
        let result = "a" .. "b" .. "c" .. "d"
        test.assert_eq(result, "abcd", nil)
    end)
end)

test.describe("String Case Methods", fun ()
    test.it("converts to uppercase", fun ()
        test.assert_eq("hello".upper(), "HELLO", nil)
    end)

    test.it("converts to lowercase", fun ()
        test.assert_eq("HELLO".lower(), "hello", nil)
    end)

    test.it("capitalizes first letter", fun ()
        test.assert_eq("hello".capitalize(), "Hello", nil)
    end)

    test.it("converts to title case", fun ()
        test.assert_eq("hello world".title(), "Hello World", nil)
    end)

    test.it("handles mixed case", fun ()
        test.assert_eq("HeLLo WoRLd".lower(), "hello world", nil)
    end)
end)

test.describe("String Trimming", fun ()
    test.it("trims whitespace from both ends", fun ()
        test.assert_eq("  hello  ".trim(), "hello", nil)
    end)

    test.it("trims whitespace from left", fun ()
        test.assert_eq("  hello".ltrim(), "hello", nil)
    end)

    test.it("trims whitespace from right", fun ()
        test.assert_eq("hello  ".rtrim(), "hello", nil)
    end)

    test.it("handles strings with no whitespace", fun ()
        test.assert_eq("hello".trim(), "hello", nil)
    end)

    test.it("handles strings with only whitespace", fun ()
        test.assert_eq("   ".trim(), "", nil)
    end)
end)

test.describe("String Comparison", fun ()
    test.it("compares equal strings", fun ()
        test.assert("hello".eq("hello"), nil)
    end)

    test.it("compares different strings", fun ()
        test.assert("hello".neq("world"), nil)
    end)

    test.it("uses == operator", fun ()
        test.assert("test" == "test", nil)
    end)

    test.it("uses != operator", fun ()
        test.assert("test" != "other", nil)
    end)

    test.it("case sensitive comparison", fun ()
        test.assert("Hello".neq("hello"), nil)
    end)
end)

test.describe("String Search Methods", fun ()
    test.it("checks if string starts with substring", fun ()
        test.assert("hello world".startswith("hello"), nil)
    end)

    test.it("checks if string ends with substring", fun ()
        test.assert("hello world".endswith("world"), nil)
    end)

    test.it("counts occurrences of substring", fun ()
        test.assert_eq("hello hello".count("hello"), 2, nil)
    end)

    test.it("counts single character", fun ()
        test.assert_eq("hello".count("l"), 2, nil)
    end)

    test.it("returns 0 for non-existent substring", fun ()
        test.assert_eq("hello".count("x"), 0, nil)
    end)
end)

test.describe("String Type Checking", fun ()
    test.it("checks if string is alphanumeric", fun ()
        test.assert("hello123".isalnum(), nil)
    end)

    test.it("checks if string is alphabetic", fun ()
        test.assert("hello".isalpha(), nil)
    end)

    test.it("checks if string is ASCII", fun ()
        test.assert("hello123".isascii(), nil)
    end)

    test.it("checks if string is digit", fun ()
        test.assert("12345".isdigit(), nil)
    end)

    test.it("checks if string is numeric", fun ()
        test.assert("12345".isnumeric(), nil)
    end)

    test.it("checks if string is lowercase", fun ()
        test.assert("hello".islower(), nil)
    end)

    test.it("checks if string is uppercase", fun ()
        test.assert("HELLO".isupper(), nil)
    end)

    test.it("checks if string is whitespace", fun ()
        test.assert("   ".isspace(), nil)
    end)

    test.it("detects non-alphanumeric strings", fun ()
        test.assert(!"hello!".isalnum(), nil)
    end)

    test.it("detects mixed case strings", fun ()
        test.assert(!"Hello".islower(), nil)
        test.assert(!"Hello".isupper(), nil)
    end)
end)

test.describe("String Edge Cases", fun ()
    test.it("handles very long strings", fun ()
        let long = "a" .. "b" .. "c" .. "d" .. "e" .. "f" .. "g" .. "h" .. "i" .. "j"
        test.assert_eq(long.len(), 10, nil)
    end)

    test.it("handles repeated operations", fun ()
        let s = "test"
        let s2 = s.upper().lower().capitalize()
        test.assert_eq(s2, "Test", nil)
    end)

    test.it("handles empty string operations", fun ()
        test.assert_eq("".upper(), "", nil)
        test.assert_eq("".trim(), "", nil)
    end)
end)

test.describe("String with Numbers", fun ()
    test.it("concatenates strings and numbers", fun ()
        let s = "count: " .. "5"
        test.assert(s.count("5") == 1, nil)
    end)

    test.it("works with numeric strings", fun ()
        test.assert("123".isdigit(), nil)
        test.assert("123".isnumeric(), nil)
    end)
end)

test.describe("String isdecimal()", fun ()
    test.it("returns true for decimal strings", fun ()
        test.assert("123".isdecimal(), "123 should be decimal")
        test.assert("0".isdecimal(), "0 should be decimal")
        test.assert("999".isdecimal(), "999 should be decimal")
    end)

    test.it("returns false for non-decimal strings", fun ()
        test.assert(!"12.3".isdecimal(), "12.3 should not be decimal (has period)")
        test.assert(!"abc".isdecimal(), "abc should not be decimal")
        test.assert(!"12a".isdecimal(), "12a should not be decimal")
        test.assert(!"".isdecimal(), "empty string should not be decimal")
    end)

    test.it("returns false for negative numbers", fun ()
        test.assert(!"-123".isdecimal(), "-123 should not be decimal (has sign)")
    end)
end)

test.describe("String istitle()", fun ()
    test.it("returns true for title case strings", fun ()
        test.assert("Hello World".istitle(), "Hello World is title case")
        test.assert("The Quick Brown Fox".istitle(), "The Quick Brown Fox is title case")
        test.assert("Hello-World".istitle(), "Hello-World is title case (hyphen separates)")
        test.assert("A".istitle(), "A is title case")
    end)

    test.it("returns false for non-title case strings", fun ()
        test.assert(!"hello world".istitle(), "hello world is not title case")
        test.assert(!"Hello world".istitle(), "Hello world is not title case")
        test.assert(!"HELLO WORLD".istitle(), "HELLO WORLD is not title case")
        test.assert(!"hELLO".istitle(), "hELLO is not title case")
        test.assert(!"".istitle(), "empty string is not title case")
    end)

    test.it("handles mixed alphanumeric", fun ()
        test.assert("Test123".istitle(), "Test123 is title case")
        test.assert("Test 123 Case".istitle(), "Test 123 Case is title case")
    end)
end)

test.describe("String expandtabs()", fun ()
    test.it("expands tabs with default size 8", fun ()
        let s = "a\tb"
        let expanded = s.expandtabs()
        test.assert(expanded.len() > s.len(), "expanded should be longer")
        test.assert(!expanded.count("\t"), "should not contain tabs")
    end)

    test.it("expands tabs with custom size", fun ()
        let s = "a\tb"
        let expanded4 = s.expandtabs(4)
        test.assert(expanded4 == "a   b", "should have 3 spaces (column 1 + 3 = 4)")
    end)

    test.it("handles multiple tabs", fun ()
        let s = "a\tb\tc"
        let expanded = s.expandtabs(4)
        test.assert(!expanded.count("\t"), "should not contain tabs")
    end)

    test.it("handles newlines correctly", fun ()
        let s = "a\tb\n\tc"
        let expanded = s.expandtabs(4)
        test.assert(expanded.count("\n") == 1, "should preserve newline")
    end)

    test.it("handles strings without tabs", fun ()
        let s = "hello world"
        test.assert_eq(s.expandtabs(), "hello world", "should be unchanged")
    end)
end)

test.describe("String encode()", fun ()
    test.it("encodes to utf-8 bytes by default", fun ()
        let encoded = "ABC".encode()
        test.assert(encoded.count("65") > 0, "should contain 65 (A)")
        test.assert(encoded.count("66") > 0, "should contain 66 (B)")
        test.assert(encoded.count("67") > 0, "should contain 67 (C)")
    end)

    test.it("encodes to hex", fun ()
        let encoded = "ABC".encode("hex")
        test.assert_eq(encoded, "414243", "should be 414243 in hex")
    end)

    test.it("handles empty strings", fun ()
        let encoded = "".encode()
        test.assert_eq(encoded, "[]", "empty string should encode to []")
    end)

    test.it("encodes special characters", fun ()
        let encoded = "\n".encode("hex")
        test.assert_eq(encoded, "0a", "newline should be 0a in hex")
    end)
end)
