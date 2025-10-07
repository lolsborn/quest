use "std/test"
use "std/encoding/struct"

test.module("std/encoding/struct")

test.describe("calcsize", fun ()
    test.it("calculates size for simple formats", fun ()
        test.assert_eq(struct.calcsize("b"), 1)
        test.assert_eq(struct.calcsize("B"), 1)
        test.assert_eq(struct.calcsize("h"), 2)
        test.assert_eq(struct.calcsize("H"), 2)
        test.assert_eq(struct.calcsize("i"), 4)
        test.assert_eq(struct.calcsize("I"), 4)
        test.assert_eq(struct.calcsize("q"), 8)
        test.assert_eq(struct.calcsize("Q"), 8)
        test.assert_eq(struct.calcsize("f"), 4)
        test.assert_eq(struct.calcsize("d"), 8)
    end)

    test.it("calculates size for repeated formats", fun ()
        test.assert_eq(struct.calcsize("3i"), 12)
        test.assert_eq(struct.calcsize("2H"), 4)
        test.assert_eq(struct.calcsize("4b"), 4)
    end)

    test.it("calculates size for mixed formats", fun ()
        test.assert_eq(struct.calcsize("HHI"), 8)
        test.assert_eq(struct.calcsize("bHi"), 7)
    end)

    test.it("calculates size with byte order prefix", fun ()
        test.assert_eq(struct.calcsize("<HHI"), 8)
        test.assert_eq(struct.calcsize(">HHI"), 8)
        test.assert_eq(struct.calcsize("!HHI"), 8)
    end)

    test.it("calculates size for strings", fun ()
        test.assert_eq(struct.calcsize("10s"), 10)
        test.assert_eq(struct.calcsize("5s"), 5)
    end)
end)

test.describe("pack and unpack", fun ()
    test.it("packs and unpacks single integers", fun ()
        let data = struct.pack("i", 42)
        test.assert_eq(data.len(), 4)

        let values = struct.unpack("i", data)
        test.assert_eq(values.len(), 1)
        test.assert_eq(values[0], 42)    end)

    test.it("packs and unpacks multiple values", fun ()
        let data = struct.pack("<HHI", 1, 2, 3)
        test.assert_eq(data.len(), 8)

        let values = struct.unpack("<HHI", data)
        test.assert_eq(values.len(), 3)
        test.assert_eq(values[0], 1)        test.assert_eq(values[1], 2)        test.assert_eq(values[2], 3)    end)

    test.it("handles little-endian byte order", fun ()
        let data = struct.pack("<H", 258)  # 0x0102
        test.assert_eq(data.len(), 2)
        test.assert_eq(data.get(0), 2)   # Little-endian: low byte first
        test.assert_eq(data.get(1), 1)   # High byte second
    end)

    test.it("handles big-endian byte order", fun ()
        let data = struct.pack(">H", 258)  # 0x0102
        test.assert_eq(data.len(), 2)
        test.assert_eq(data.get(0), 1)   # Big-endian: high byte first
        test.assert_eq(data.get(1), 2)   # Low byte second
    end)

    test.it("handles network byte order (big-endian)", fun ()
        let data = struct.pack("!H", 258)
        test.assert_eq(data.len(), 2)
        test.assert_eq(data.get(0), 1)
        test.assert_eq(data.get(1), 2)
    end)
end)

test.describe("numeric types", fun ()
    test.it("handles signed bytes", fun ()
        let data = struct.pack("b", -128)
        let values = struct.unpack("b", data)
        test.assert_eq(values[0], -128)
        let data2 = struct.pack("b", 127)
        let values2 = struct.unpack("b", data2)
        test.assert_eq(values2[0], 127)    end)

    test.it("handles unsigned bytes", fun ()
        let data = struct.pack("B", 255)
        let values = struct.unpack("B", data)
        test.assert_eq(values[0], 255)    end)

    test.it("handles signed shorts", fun ()
        let data = struct.pack("<h", -32768)
        let values = struct.unpack("<h", data)
        test.assert_eq(values[0], -32768)
        let data2 = struct.pack("<h", 32767)
        let values2 = struct.unpack("<h", data2)
        test.assert_eq(values2[0], 32767)    end)

    test.it("handles unsigned shorts", fun ()
        let data = struct.pack("<H", 65535)
        let values = struct.unpack("<H", data)
        test.assert_eq(values[0], 65535)    end)

    test.it("handles signed ints", fun ()
        let data = struct.pack("<i", -2147483648)
        let values = struct.unpack("<i", data)
        test.assert_eq(values[0], -2147483648)
        let data2 = struct.pack("<i", 2147483647)
        let values2 = struct.unpack("<i", data2)
        test.assert_eq(values2[0], 2147483647)    end)

    test.it("handles unsigned ints", fun ()
        let data = struct.pack("<I", 4294967295)
        let values = struct.unpack("<I", data)
        test.assert_eq(values[0], 4294967295)    end)

    test.it("handles long longs", fun ()
        let data = struct.pack("<q", 9223372036854775807)
        let values = struct.unpack("<q", data)
        test.assert_eq(values[0], 9223372036854775807)    end)
end)

test.describe("floating point", fun ()
    test.it("handles floats", fun ()
        let data = struct.pack("<f", 3.14)
        let values = struct.unpack("<f", data)
        # Float has precision loss, so we use assert_near
        test.assert_near(values[0], 3.14, 0.01)    end)

    test.it("handles doubles", fun ()
        let data = struct.pack("<d", 3.141592653589793)
        let values = struct.unpack("<d", data)
        test.assert_near(values[0], 3.141592653589793, 0.000001)    end)
end)

test.describe("booleans", fun ()
    test.it("handles boolean values", fun ()
        let data = struct.pack("??", true, false)
        test.assert_eq(data.len(), 2)

        let values = struct.unpack("??", data)
        test.assert_eq(values[0], true)        test.assert_eq(values[1], false)    end)
end)

test.describe("strings", fun ()
    test.it("handles fixed-length strings", fun ()
        let data = struct.pack("10s", "Hello")
        test.assert_eq(data.len(), 10)

        let values = struct.unpack("10s", data)
        test.assert_eq(values[0], "Hello")  # Null bytes are stripped
    end)

    test.it("truncates strings that are too long", fun ()
        let data = struct.pack("5s", "HelloWorld")
        test.assert_eq(data.len(), 5)

        let values = struct.unpack("5s", data)
        test.assert_eq(values[0], "Hello")    end)
end)

test.describe("chars", fun ()
    test.it("handles single characters", fun ()
        let data = struct.pack("ccc", "A", "B", "C")
        test.assert_eq(data.len(), 3)

        let values = struct.unpack("ccc", data)
        test.assert_eq(values[0], "A")        test.assert_eq(values[1], "B")        test.assert_eq(values[2], "C")    end)
end)

test.describe("pad bytes", fun ()
    test.it("handles pad bytes", fun ()
        let data = struct.pack("ixH", 42, 100)
        test.assert_eq(data.len(), 7)  # 4 (int) + 1 (pad) + 2 (short)

        let values = struct.unpack("ixH", data)
        test.assert_eq(values.len(), 2)
        test.assert_eq(values[0], 42)        test.assert_eq(values[1], 100)    end)
end)

test.describe("repeated values", fun ()
    test.it("handles repeated format characters", fun ()
        let data = struct.pack("3i", 1, 2, 3)
        test.assert_eq(data.len(), 12)

        let values = struct.unpack("3i", data)
        test.assert_eq(values.len(), 3)
        test.assert_eq(values[0], 1)        test.assert_eq(values[1], 2)        test.assert_eq(values[2], 3)    end)
end)

test.describe("unpack_from", fun ()
    test.it("unpacks from offset", fun ()
        # Pack multiple values
        let data = struct.pack("<HHH", 100, 200, 300)
        test.assert_eq(data.len(), 6)

        # Unpack from offset 2 (skip first short)
        let values = struct.unpack_from("<HH", data, 2)
        test.assert_eq(values.len(), 2)
        test.assert_eq(values[0], 200)        test.assert_eq(values[1], 300)    end)
end)

test.describe("error handling", fun ()
    test.it("raises error for invalid format string", fun ()
        test.assert_raises(ValueErr, fun ()
            struct.calcsize("Z")
        end)
    end)

    test.it("raises error for mismatched value count", fun ()
        test.assert_raises(ValueErr, fun ()
            struct.pack("HHI", 1, 2)  # Expects 3 values, got 2
        end)
    end)

    test.it("raises error for insufficient data", fun ()
        let data = b"\x01\x02"  # Only 2 bytes
        test.assert_raises(ValueErr, fun ()
            struct.unpack("HHI", data)  # Expects 8 bytes
        end)
    end)

    test.it("raises error for value out of range", fun ()
        test.assert_raises(ValueErr, fun ()
            struct.pack("b", 200)  # Signed byte range is -128 to 127
        end)
    end)
end)

test.describe("real-world use cases", fun ()
    test.it("handles network packet header", fun ()
        # Typical packet: version(1), type(1), length(2), id(4)
        let data = struct.pack("!BBHI", 1, 5, 1024, 12345)
        test.assert_eq(data.len(), 8)

        let values = struct.unpack("!BBHI", data)
        test.assert_eq(values[0], 1)      # version
        test.assert_eq(values[1], 5)      # type
        test.assert_eq(values[2], 1024)   # length
        test.assert_eq(values[3], 12345)  # id
    end)

    test.it("handles binary file format", fun ()
        # File header: magic(4 bytes), version(2), flags(2), timestamp(8)
        let data = struct.pack("<4sHHQ", "ABCD", 100, 7, 1234567890)
        test.assert_eq(data.len(), 16)

        let values = struct.unpack("<4sHHQ", data)
        test.assert_eq(values[0], "ABCD")        test.assert_eq(values[1], 100)        test.assert_eq(values[2], 7)        test.assert_eq(values[3], 1234567890)    end)
end)
