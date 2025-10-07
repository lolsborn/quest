use "std/test"

test.module("Bytes Type")

test.describe("Bytes literals", fun ()
    test.it("creates bytes from literal", fun ()
        let b = b"Hello"
        test.assert_eq(b.len(), 5)
    end)

    test.it("supports hex escapes", fun ()
        let b = b"\xFF\x01\x42"
        test.assert_eq(b.len(), 3)
        test.assert_eq(b.get(0), 255)
        test.assert_eq(b.get(1), 1)
        test.assert_eq(b.get(2), 66)
    end)

    test.it("supports escape sequences", fun ()
        let b = b"Hello\n\r\t\0"
        test.assert_eq(b.len(), 9)
        test.assert_eq(b.get(5), 10)   # \n
        test.assert_eq(b.get(6), 13)   # \r
        test.assert_eq(b.get(7), 9)    # \t
        test.assert_eq(b.get(8), 0)    # \0
    end)
end)

test.describe("String.bytes()", fun ()
    test.it("converts string to bytes", fun ()
        let s = "Hello"
        let b = s.bytes()
        test.assert_eq(b.len(), 5)
        test.assert_eq(b.get(0), 72)   # 'H'
        test.assert_eq(b.get(4), 111)  # 'o'
    end)

    test.it("handles UTF-8 properly", fun ()
        let s = "café"
        let b = s.bytes()
        test.assert_eq(b.len(), 5)     # é is 2 bytes in UTF-8
    end)
end)

test.describe("Bytes.decode()", fun ()
    test.it("decodes UTF-8 bytes to string", fun ()
        let b = b"Hello"
        let s = b.decode()
        test.assert_eq(s, "Hello")    end)

    test.it("decodes to hex", fun ()
        let b = b"\xFF\x01\x42"
        let hex = b.decode("hex")
        test.assert_eq(hex, "ff0142")    end)

    test.it("errors on invalid UTF-8", fun ()
        let b = b"\xFF\xFE"
        test.assert_raises(ValueErr, fun ()
            b.decode()
        end)
    end)
end)

test.describe("Bytes.get()", fun ()
    test.it("gets byte at index", fun ()
        let b = b"ABC"
        test.assert_eq(b.get(0), 65)
        test.assert_eq(b.get(1), 66)
        test.assert_eq(b.get(2), 67)
    end)

    test.it("errors on out of bounds", fun ()
        let b = b"Hi"
        test.assert_raises(IndexErr, fun ()
            b.get(10)
        end)
    end)
end)

test.describe("Bytes.slice()", fun ()
    test.it("slices bytes", fun ()
        let b = b"Hello World"
        let sliced = b.slice(0, 5)
        test.assert_eq(sliced.decode(), "Hello")
    end)

    test.it("supports mid-range slicing", fun ()
        let b = b"Hello World"
        let sliced = b.slice(6, 11)
        test.assert_eq(sliced.decode(), "World")
    end)

    test.it("errors on invalid range", fun ()
        let b = b"Hello"
        test.assert_raises(IndexErr, fun ()
            b.slice(10, 20)
        end)
    end)
end)

test.describe("Bytes.to_array()", fun ()
    test.it("converts to array of numbers", fun ()
        let b = b"ABC"
        let arr = b.to_array()
        test.assert_eq(arr.len(), 3)
        test.assert_eq(arr.get(0), 65)
        test.assert_eq(arr.get(1), 66)
        test.assert_eq(arr.get(2), 67)
    end)
end)

test.describe("Bytes truthiness", fun ()
    test.it("empty bytes are falsy", fun ()
        let b = b""
        test.assert(not b, "Empty bytes should be falsy")
    end)

    test.it("non-empty bytes are truthy", fun ()
        let b = b"x"
        test.assert(b, "Non-empty bytes should be truthy")
    end)
end)
