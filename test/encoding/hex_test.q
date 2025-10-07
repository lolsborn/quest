use "std/test"
use "std/encoding/hex"

test.module("std/encoding/hex")

test.describe("encode", fun ()
    test.it("encodes bytes to lowercase hex string", fun ()
        let data = b"\x00\x01\x02\xff\xfe"
        let hex_str = hex.encode(data)
        test.assert_eq(hex_str, "000102fffe")    end)

    test.it("encodes empty bytes", fun ()
        let data = b""
        let hex_str = hex.encode(data)
        test.assert_eq(hex_str, "")    end)

    test.it("encodes single byte", fun ()
        let data = b"\xab"
        let hex_str = hex.encode(data)
        test.assert_eq(hex_str, "ab")    end)
end)

test.describe("encode_upper", fun ()
    test.it("encodes bytes to uppercase hex string", fun ()
        let data = b"\xde\xad\xbe\xef"
        let hex_str = hex.encode_upper(data)
        test.assert_eq(hex_str, "DEADBEEF")    end)

    test.it("encodes lowercase range", fun ()
        let data = b"\x0a\x0b\x0c"
        let hex_str = hex.encode_upper(data)
        test.assert_eq(hex_str, "0A0B0C")    end)
end)

test.describe("encode_with_sep", fun ()
    test.it("encodes with colon separator", fun ()
        let data = b"\x01\x02\x03"
        let hex_str = hex.encode_with_sep(data, ":")
        test.assert_eq(hex_str, "01:02:03")    end)

    test.it("encodes with space separator", fun ()
        let data = b"\xaa\xbb\xcc"
        let hex_str = hex.encode_with_sep(data, " ")
        test.assert_eq(hex_str, "aa bb cc")    end)

    test.it("encodes with dash separator", fun ()
        let data = b"\x12\x34\x56"
        let hex_str = hex.encode_with_sep(data, "-")
        test.assert_eq(hex_str, "12-34-56")    end)

    test.it("encodes with empty separator", fun ()
        let data = b"\xab\xcd"
        let hex_str = hex.encode_with_sep(data, "")
        test.assert_eq(hex_str, "abcd")    end)
end)

test.describe("decode", fun ()
    test.it("decodes lowercase hex string", fun ()
        let data = hex.decode("deadbeef")
        test.assert_eq(data.len(), 4)
        test.assert_eq(data.get(0), 222)  # 0xde
        test.assert_eq(data.get(1), 173)  # 0xad
        test.assert_eq(data.get(2), 190)  # 0xbe
        test.assert_eq(data.get(3), 239)  # 0xef
    end)

    test.it("decodes uppercase hex string", fun ()
        let data = hex.decode("DEADBEEF")
        test.assert_eq(data.len(), 4)
        test.assert_eq(data.get(0), 222)
    end)

    test.it("decodes mixed case hex string", fun ()
        let data = hex.decode("DeAdBeEf")
        test.assert_eq(data.len(), 4)
        test.assert_eq(data.get(0), 222)
    end)

    test.it("decodes hex with colons", fun ()
        let data = hex.decode("01:02:03")
        test.assert_eq(data.len(), 3)
        test.assert_eq(data.get(0), 1)
        test.assert_eq(data.get(1), 2)
        test.assert_eq(data.get(2), 3)
    end)

    test.it("decodes hex with spaces", fun ()
        let data = hex.decode("aa bb cc")
        test.assert_eq(data.len(), 3)
        test.assert_eq(data.get(0), 170)
    end)

    test.it("decodes hex with hyphens", fun ()
        let data = hex.decode("12-34-56")
        test.assert_eq(data.len(), 3)
        test.assert_eq(data.get(0), 18)
    end)

    test.it("decodes empty string", fun ()
        let data = hex.decode("")
        test.assert_eq(data.len(), 0)
    end)
end)

test.describe("is_valid", fun ()
    test.it("validates correct lowercase hex", fun ()
        test.assert_eq(hex.is_valid("deadbeef"), true)
    end)

    test.it("validates correct uppercase hex", fun ()
        test.assert_eq(hex.is_valid("DEADBEEF"), true)
    end)

    test.it("validates mixed case hex", fun ()
        test.assert_eq(hex.is_valid("DeAdBeEf"), true)
    end)

    test.it("validates hex with separators", fun ()
        test.assert_eq(hex.is_valid("de:ad:be:ef"), true)
        test.assert_eq(hex.is_valid("de-ad-be-ef"), true)
        test.assert_eq(hex.is_valid("de ad be ef"), true)
    end)

    test.it("rejects odd number of hex digits", fun ()
        test.assert_eq(hex.is_valid("abc"), false)
        test.assert_eq(hex.is_valid("12345"), false)
    end)

    test.it("rejects invalid characters", fun ()
        test.assert_eq(hex.is_valid("xyz"), false)
        test.assert_eq(hex.is_valid("12g34"), false)
    end)

    test.it("validates empty string", fun ()
        test.assert_eq(hex.is_valid(""), true)
    end)
end)

test.describe("error handling", fun ()
    test.it("raises error for odd length hex string", fun ()
        test.assert_raises(ValueErr, fun ()
            hex.decode("abc")
        end)
    end)

    test.it("raises error for invalid hex character", fun ()
        test.assert_raises(Err, fun ()
            hex.decode("gg")
        end)
    end)
end)

test.describe("round trip", fun ()
    test.it("encodes and decodes correctly", fun ()
        let original = b"\x01\x02\x03\xff\xfe\xfd"
        let encoded = hex.encode(original)
        let decoded = hex.decode(encoded)
        # Compare byte by byte since Bytes comparison may not work
        test.assert_eq(decoded.len(), original.len())
        test.assert_eq(decoded.get(0), 1)
        test.assert_eq(decoded.get(1), 2)
        test.assert_eq(decoded.get(2), 3)
        test.assert_eq(decoded.get(3), 255)
        test.assert_eq(decoded.get(4), 254)
        test.assert_eq(decoded.get(5), 253)
    end)

    test.it("round trips with uppercase", fun ()
        let original = b"\xde\xad\xbe\xef"
        let encoded = hex.encode_upper(original)
        let decoded = hex.decode(encoded)
        test.assert_eq(decoded.len(), 4)
        test.assert_eq(decoded.get(0), 222)
        test.assert_eq(decoded.get(1), 173)
        test.assert_eq(decoded.get(2), 190)
        test.assert_eq(decoded.get(3), 239)
    end)
end)
