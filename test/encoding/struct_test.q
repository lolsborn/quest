use "std/test" {it, describe, module, assert_eq, assert_near, assert_raises}
use "std/encoding/struct"

module("std/encoding/struct")

describe("calcsize", fun ()
  it("calculates size for simple formats", fun ()
    assert_eq(struct.calcsize("b"), 1)
    assert_eq(struct.calcsize("B"), 1)
    assert_eq(struct.calcsize("h"), 2)
    assert_eq(struct.calcsize("H"), 2)
    assert_eq(struct.calcsize("i"), 4)
    assert_eq(struct.calcsize("I"), 4)
    assert_eq(struct.calcsize("q"), 8)
    assert_eq(struct.calcsize("Q"), 8)
    assert_eq(struct.calcsize("f"), 4)
    assert_eq(struct.calcsize("d"), 8)
  end)

  it("calculates size for repeated formats", fun ()
    assert_eq(struct.calcsize("3i"), 12)
    assert_eq(struct.calcsize("2H"), 4)
    assert_eq(struct.calcsize("4b"), 4)
  end)

  it("calculates size for mixed formats", fun ()
    assert_eq(struct.calcsize("HHI"), 8)
    assert_eq(struct.calcsize("bHi"), 7)
  end)

  it("calculates size with byte order prefix", fun ()
    assert_eq(struct.calcsize("<HHI"), 8)
    assert_eq(struct.calcsize(">HHI"), 8)
    assert_eq(struct.calcsize("!HHI"), 8)
  end)

  it("calculates size for strings", fun ()
    assert_eq(struct.calcsize("10s"), 10)
    assert_eq(struct.calcsize("5s"), 5)
  end)
end)

describe("pack and unpack", fun ()
  it("packs and unpacks single integers", fun ()
    let data = struct.pack("i", 42)
    assert_eq(data.len(), 4)

    let values = struct.unpack("i", data)
    assert_eq(values.len(), 1)
    assert_eq(values[0], 42)
  end)

  it("packs and unpacks multiple values", fun ()
    let data = struct.pack("<HHI", 1, 2, 3)
    assert_eq(data.len(), 8)

    let values = struct.unpack("<HHI", data)
    assert_eq(values.len(), 3)
    assert_eq(values[0], 1)
    assert_eq(values[1], 2)
    assert_eq(values[2], 3)
  end)

  it("handles little-endian byte order", fun ()
    let data = struct.pack("<H", 258)  # 0x0102
    assert_eq(data.len(), 2)
    assert_eq(data.get(0), 2)   # Little-endian: low byte first
    assert_eq(data.get(1), 1)   # High byte second
  end)

  it("handles big-endian byte order", fun ()
    let data = struct.pack(">H", 258)  # 0x0102
    assert_eq(data.len(), 2)
    assert_eq(data.get(0), 1)   # Big-endian: high byte first
    assert_eq(data.get(1), 2)   # Low byte second
  end)

  it("handles network byte order (big-endian)", fun ()
    let data = struct.pack("!H", 258)
    assert_eq(data.len(), 2)
    assert_eq(data.get(0), 1)
    assert_eq(data.get(1), 2)
  end)
end)

describe("numeric types", fun ()
  it("handles signed bytes", fun ()
    let data = struct.pack("b", -128)
    let values = struct.unpack("b", data)
    assert_eq(values[0], -128)
    let data2 = struct.pack("b", 127)
    let values2 = struct.unpack("b", data2)
    assert_eq(values2[0], 127)
  end)

  it("handles unsigned bytes", fun ()
    let data = struct.pack("B", 255)
    let values = struct.unpack("B", data)
    assert_eq(values[0], 255)
  end)

  it("handles signed shorts", fun ()
    let data = struct.pack("<h", -32768)
    let values = struct.unpack("<h", data)
    assert_eq(values[0], -32768)
    let data2 = struct.pack("<h", 32767)
    let values2 = struct.unpack("<h", data2)
    assert_eq(values2[0], 32767)
  end)

  it("handles unsigned shorts", fun ()
    let data = struct.pack("<H", 65535)
    let values = struct.unpack("<H", data)
    assert_eq(values[0], 65535)
  end)

  it("handles signed ints", fun ()
    let data = struct.pack("<i", -2147483648)
    let values = struct.unpack("<i", data)
    assert_eq(values[0], -2147483648)
    let data2 = struct.pack("<i", 2147483647)
    let values2 = struct.unpack("<i", data2)
    assert_eq(values2[0], 2147483647)
  end)

  it("handles unsigned ints", fun ()
    let data = struct.pack("<I", 4294967295)
    let values = struct.unpack("<I", data)
    assert_eq(values[0], 4294967295)
  end)

  it("handles long longs", fun ()
    let data = struct.pack("<q", 9223372036854775807)
    let values = struct.unpack("<q", data)
    assert_eq(values[0], 9223372036854775807)
  end)
end)

describe("floating point", fun ()
  it("handles floats", fun ()
    let data = struct.pack("<f", 3.14)
    let values = struct.unpack("<f", data)
    # Float has precision loss, so we use assert_near
    assert_near(values[0], 3.14, 0.01)
  end)

  it("handles doubles", fun ()
    let data = struct.pack("<d", 3.141592653589793)
    let values = struct.unpack("<d", data)
    assert_near(values[0], 3.141592653589793, 0.000001)
  end)
end)

describe("booleans", fun ()
  it("handles boolean values", fun ()
    let data = struct.pack("??", true, false)
    assert_eq(data.len(), 2)

    let values = struct.unpack("??", data)
    assert_eq(values[0], true)
    assert_eq(values[1], false)
  end)
end)

describe("strings", fun ()
  it("handles fixed-length strings", fun ()
    let data = struct.pack("10s", "Hello")
    assert_eq(data.len(), 10)

    let values = struct.unpack("10s", data)
    assert_eq(values[0], "Hello")  # Null bytes are stripped
  end)

  it("truncates strings that are too long", fun ()
    let data = struct.pack("5s", "HelloWorld")
    assert_eq(data.len(), 5)

    let values = struct.unpack("5s", data)
    assert_eq(values[0], "Hello")
  end)
end)

describe("chars", fun ()
  it("handles single characters", fun ()
    let data = struct.pack("ccc", "A", "B", "C")
    assert_eq(data.len(), 3)

    let values = struct.unpack("ccc", data)
    assert_eq(values[0], "A")
    assert_eq(values[1], "B")
    assert_eq(values[2], "C")
  end)
end)

describe("pad bytes", fun ()
  it("handles pad bytes", fun ()
    let data = struct.pack("ixH", 42, 100)
    assert_eq(data.len(), 7)  # 4 (int) + 1 (pad) + 2 (short)

    let values = struct.unpack("ixH", data)
    assert_eq(values.len(), 2)
    assert_eq(values[0], 42)
    assert_eq(values[1], 100)
  end)
end)

describe("repeated values", fun ()
  it("handles repeated format characters", fun ()
    let data = struct.pack("3i", 1, 2, 3)
    assert_eq(data.len(), 12)

    let values = struct.unpack("3i", data)
    assert_eq(values.len(), 3)
    assert_eq(values[0], 1)
    assert_eq(values[1], 2)
    assert_eq(values[2], 3)
  end)
end)

describe("unpack_from", fun ()
  it("unpacks from offset", fun ()
    # Pack multiple values
    let data = struct.pack("<HHH", 100, 200, 300)
    assert_eq(data.len(), 6)

    # Unpack from offset 2 (skip first short)
    let values = struct.unpack_from("<HH", data, 2)
    assert_eq(values.len(), 2)
    assert_eq(values[0], 200)
    assert_eq(values[1], 300)
  end)
end)

describe("error handling", fun ()
  it("raises error for invalid format string", fun ()
    assert_raises(ValueErr, fun ()
      struct.calcsize("Z")
    end)
  end)

  it("raises error for mismatched value count", fun ()
    assert_raises(ValueErr, fun ()
      struct.pack("HHI", 1, 2)  # Expects 3 values, got 2
    end)
  end)

  it("raises error for insufficient data", fun ()
    let data = b"\x01\x02"  # Only 2 bytes
    assert_raises(ValueErr, fun ()
      struct.unpack("HHI", data)  # Expects 8 bytes
    end)
  end)

  it("raises error for value out of range", fun ()
    assert_raises(ValueErr, fun ()
      struct.pack("b", 200)  # Signed byte range is -128 to 127
    end)
  end)
end)

describe("real-world use cases", fun ()
  it("handles network packet header", fun ()
    # Typical packet: version(1), type(1), length(2), id(4)
    let data = struct.pack("!BBHI", 1, 5, 1024, 12345)
    assert_eq(data.len(), 8)

    let values = struct.unpack("!BBHI", data)
    assert_eq(values[0], 1)    # version
    assert_eq(values[1], 5)    # type
    assert_eq(values[2], 1024)   # length
    assert_eq(values[3], 12345)  # id
  end)

  it("handles binary file format", fun ()
    # File header: magic(4 bytes), version(2), flags(2), timestamp(8)
    let data = struct.pack("<4sHHQ", "ABCD", 100, 7, 1234567890)
    assert_eq(data.len(), 16)

    let values = struct.unpack("<4sHHQ", data)
    assert_eq(values[0], "ABCD")
    assert_eq(values[1], 100)
    assert_eq(values[2], 7)
    assert_eq(values[3], 1234567890)
  end)
end)
