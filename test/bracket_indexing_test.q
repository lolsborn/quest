use "std/test"

# Helper function to test that a function raises an error
fun assert_raises_error(test_fn, desc)
    let did_raise = false
    try
        test_fn()
    catch e
        did_raise = true
    end
    test.assert(did_raise, desc)
end

test.module("QEP-036: Bracket Indexing for Strings and Bytes")

test.describe("String bracket indexing", fun ()
    test.it("returns single character", fun ()
        test.assert_eq("hello"[0], "h")        test.assert_eq("hello"[1], "e")        test.assert_eq("hello"[2], "l")        test.assert_eq("hello"[3], "l")        test.assert_eq("hello"[4], "o")    end)

    test.it("supports negative indexing", fun ()
        test.assert_eq("hello"[-1], "o")        test.assert_eq("hello"[-2], "l")        test.assert_eq("hello"[-3], "l")        test.assert_eq("hello"[-4], "e")        test.assert_eq("hello"[-5], "h")    end)

    test.it("handles boundary indices", fun ()
        # First and last valid indices
        test.assert_eq("hello"[0], "h")        test.assert_eq("hello"[4], "o")        test.assert_eq("hello"[-1], "o")        test.assert_eq("hello"[-5], "h")    end)

    test.it("handles UTF-8 code points correctly", fun ()
        let s = "hello世界"
        # Note: String literal encoding in source may vary
        # Just test that indexing returns the correct Chinese characters
        test.assert_eq(s[5], "世")        test.assert_eq(s[6], "界")    end)

    # Note: Combining character test skipped - Quest doesn't yet support \u{} escape sequences

    test.it("handles emoji as code points", fun ()
        let s = "👨"  # Single emoji
        test.assert_eq(s[0], "👨")    end)

    test.it("raises error on out of bounds", fun ()
        assert_raises_error(fun () puts("hello"[5]) end, "Should raise error for index 5")
        assert_raises_error(fun () puts("hello"[10]) end, "Should raise error for index 10")
        assert_raises_error(fun () puts("hello"[-6]) end, "Should raise error for index -6")
        assert_raises_error(fun () puts("hello"[-10]) end, "Should raise error for index -10")
    end)

    test.it("raises error on empty string", fun ()
        assert_raises_error(fun () puts(""[0]) end, "Should raise error for empty string index 0")
        assert_raises_error(fun () puts(""[-1]) end, "Should raise error for empty string index -1")
    end)

    test.it("raises error on non-int indices", fun ()
        assert_raises_error(fun () puts("hello"[1.5]) end, "Should raise error for float index")
        assert_raises_error(fun () puts("hello"["0"]) end, "Should raise error for string index")
        assert_raises_error(fun () puts("hello"[nil]) end, "Should raise error for nil index")
    end)

    test.it("supports BigInt indices if they fit", fun ()
        test.assert_eq("hello"[0n], "h")  # Converts to Int
        assert_raises_error(fun () puts("hello"[9999999999999999n]) end, "Should raise error for BigInt too large")
    end)

    test.it("works with single character strings", fun ()
        test.assert_eq("a"[0], "a")        test.assert_eq("a"[-1], "a")    end)

    test.it("works with multi-line strings", fun ()
        let s = "hello\nworld"
        test.assert_eq(s[5], "\n")        test.assert_eq(s[6], "w")    end)
end)

test.describe("Bytes bracket indexing", fun ()
    test.it("returns byte value as int", fun ()
        test.assert_eq(b"hello"[0], 104)  # 'h'
        test.assert_eq(b"hello"[1], 101)  # 'e'
        test.assert_eq(b"hello"[2], 108)  # 'l'
        test.assert_eq(b"hello"[3], 108)  # 'l'
        test.assert_eq(b"hello"[4], 111)  # 'o'
    end)

    test.it("supports negative indexing", fun ()
        test.assert_eq(b"hello"[-1], 111)  # 'o'
        test.assert_eq(b"hello"[-2], 108)  # 'l'
        test.assert_eq(b"hello"[-3], 108)  # 'l'
        test.assert_eq(b"hello"[-4], 101)  # 'e'
        test.assert_eq(b"hello"[-5], 104)  # 'h'
    end)

    test.it("handles boundary indices", fun ()
        test.assert_eq(b"hello"[0], 104)        test.assert_eq(b"hello"[4], 111)        test.assert_eq(b"hello"[-1], 111)        test.assert_eq(b"hello"[-5], 104)    end)

    test.it("handles hex escape sequences", fun ()
        let data = b"\x48\x65\x6C\x6C\x6F"  # "Hello"
        test.assert_eq(data[0], 72)   # 0x48
        test.assert_eq(data[1], 101)  # 0x65
        test.assert_eq(data[4], 111)  # 0x6F
    end)

    test.it("handles full byte range (0-255)", fun ()
        let data = b"\x00\xFF"
        test.assert_eq(data[0], 0)        test.assert_eq(data[1], 255)    end)

    test.it("raises error on out of bounds", fun ()
        assert_raises_error(fun () puts(b"hello"[5]) end, "Should raise error for index 5")
        assert_raises_error(fun () puts(b"hello"[10]) end, "Should raise error for index 10")
        assert_raises_error(fun () puts(b"hello"[-6]) end, "Should raise error for index -6")
        assert_raises_error(fun () puts(b"hello"[-10]) end, "Should raise error for index -10")
    end)

    test.it("raises error on empty bytes", fun ()
        assert_raises_error(fun () puts(b""[0]) end, "Should raise error for empty bytes index 0")
        assert_raises_error(fun () puts(b""[-1]) end, "Should raise error for empty bytes index -1")
    end)

    test.it("raises error on non-int indices", fun ()
        assert_raises_error(fun () puts(b"hello"[1.5]) end, "Should raise error for float index")
        assert_raises_error(fun () puts(b"hello"["0"]) end, "Should raise error for string index")
        assert_raises_error(fun () puts(b"hello"[nil]) end, "Should raise error for nil index")
    end)

    test.it("supports BigInt indices if they fit", fun ()
        test.assert_eq(b"hello"[0n], 104)  # Converts to Int
        assert_raises_error(fun () puts(b"hello"[9999999999999999n]) end, "Should raise error for BigInt too large")
    end)

    test.it("works with single byte", fun ()
        test.assert_eq(b"a"[0], 97)        test.assert_eq(b"a"[-1], 97)    end)
end)

test.describe("Consistency with existing methods", fun ()
    test.it("String indexing consistent with slice", fun ()
        let s = "hello"
        test.assert_eq(s[0], s.slice(0, 1))
        test.assert_eq(s[2], s.slice(2, 3))
        test.assert_eq(s[-1], s.slice(s.len() - 1, s.len()))
    end)

    test.it("Bytes indexing consistent with get", fun ()
        let b = b"hello"
        test.assert_eq(b[0], b.get(0))
        test.assert_eq(b[2], b.get(2))
        test.assert_eq(b[4], b.get(4))
    end)
end)
