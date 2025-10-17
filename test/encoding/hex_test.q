use "std/test" {it, describe, module, assert_eq, assert_raises}
use "std/encoding/hex"

module("std/encoding/hex")

describe("encode", fun ()
  it("encodes bytes to lowercase hex string", fun ()
    let data = b"\x00\x01\x02\xff\xfe"
    let hex_str = hex.encode(data)
    assert_eq(hex_str, "000102fffe")
  end)

  it("encodes empty bytes", fun ()
    let data = b""
    let hex_str = hex.encode(data)
    assert_eq(hex_str, "")
  end)

  it("encodes single byte", fun ()
    let data = b"\xab"
    let hex_str = hex.encode(data)
    assert_eq(hex_str, "ab")
  end)
end)

describe("encode_upper", fun ()
  it("encodes bytes to uppercase hex string", fun ()
    let data = b"\xde\xad\xbe\xef"
    let hex_str = hex.encode_upper(data)
    assert_eq(hex_str, "DEADBEEF")
  end)

  it("encodes lowercase range", fun ()
    let data = b"\x0a\x0b\x0c"
    let hex_str = hex.encode_upper(data)
    assert_eq(hex_str, "0A0B0C")
  end)
end)

describe("encode_with_sep", fun ()
  it("encodes with colon separator", fun ()
    let data = b"\x01\x02\x03"
    let hex_str = hex.encode_with_sep(data, ":")
    assert_eq(hex_str, "01:02:03")
  end)

  it("encodes with space separator", fun ()
    let data = b"\xaa\xbb\xcc"
    let hex_str = hex.encode_with_sep(data, " ")
    assert_eq(hex_str, "aa bb cc")
  end)

  it("encodes with dash separator", fun ()
    let data = b"\x12\x34\x56"
    let hex_str = hex.encode_with_sep(data, "-")
    assert_eq(hex_str, "12-34-56")
  end)

  it("encodes with empty separator", fun ()
    let data = b"\xab\xcd"
    let hex_str = hex.encode_with_sep(data, "")
    assert_eq(hex_str, "abcd")
  end)
end)

describe("decode", fun ()
  it("decodes lowercase hex string", fun ()
    let data = hex.decode("deadbeef")
    assert_eq(data.len(), 4)
    assert_eq(data.get(0), 222)  # 0xde
    assert_eq(data.get(1), 173)  # 0xad
    assert_eq(data.get(2), 190)  # 0xbe
    assert_eq(data.get(3), 239)  # 0xef
  end)

  it("decodes uppercase hex string", fun ()
    let data = hex.decode("DEADBEEF")
    assert_eq(data.len(), 4)
    assert_eq(data.get(0), 222)
  end)

  it("decodes mixed case hex string", fun ()
    let data = hex.decode("DeAdBeEf")
    assert_eq(data.len(), 4)
    assert_eq(data.get(0), 222)
  end)

  it("decodes hex with colons", fun ()
    let data = hex.decode("01:02:03")
    assert_eq(data.len(), 3)
    assert_eq(data.get(0), 1)
    assert_eq(data.get(1), 2)
    assert_eq(data.get(2), 3)
  end)

  it("decodes hex with spaces", fun ()
    let data = hex.decode("aa bb cc")
    assert_eq(data.len(), 3)
    assert_eq(data.get(0), 170)
  end)

  it("decodes hex with hyphens", fun ()
    let data = hex.decode("12-34-56")
    assert_eq(data.len(), 3)
    assert_eq(data.get(0), 18)
  end)

  it("decodes empty string", fun ()
    let data = hex.decode("")
    assert_eq(data.len(), 0)
  end)
end)

describe("is_valid", fun ()
  it("validates correct lowercase hex", fun ()
    assert_eq(hex.is_valid("deadbeef"), true)
  end)

  it("validates correct uppercase hex", fun ()
    assert_eq(hex.is_valid("DEADBEEF"), true)
  end)

  it("validates mixed case hex", fun ()
    assert_eq(hex.is_valid("DeAdBeEf"), true)
  end)

  it("validates hex with separators", fun ()
    assert_eq(hex.is_valid("de:ad:be:ef"), true)
    assert_eq(hex.is_valid("de-ad-be-ef"), true)
    assert_eq(hex.is_valid("de ad be ef"), true)
  end)

  it("rejects odd number of hex digits", fun ()
    assert_eq(hex.is_valid("abc"), false)
    assert_eq(hex.is_valid("12345"), false)
  end)

  it("rejects invalid characters", fun ()
    assert_eq(hex.is_valid("xyz"), false)
    assert_eq(hex.is_valid("12g34"), false)
  end)

  it("validates empty string", fun ()
    assert_eq(hex.is_valid(""), true)
  end)
end)

describe("error handling", fun ()
  it("raises error for odd length hex string", fun ()
    assert_raises(ValueErr, fun ()
      hex.decode("abc")
    end)
  end)

  it("raises error for invalid hex character", fun ()
    assert_raises(Err, fun ()
      hex.decode("gg")
    end)
  end)
end)

describe("round trip", fun ()
  it("encodes and decodes correctly", fun ()
    let original = b"\x01\x02\x03\xff\xfe\xfd"
    let encoded = hex.encode(original)
    let decoded = hex.decode(encoded)
    # Compare byte by byte since Bytes comparison may not work
    assert_eq(decoded.len(), original.len())
    assert_eq(decoded.get(0), 1)
    assert_eq(decoded.get(1), 2)
    assert_eq(decoded.get(2), 3)
    assert_eq(decoded.get(3), 255)
    assert_eq(decoded.get(4), 254)
    assert_eq(decoded.get(5), 253)
  end)

  it("round trips with uppercase", fun ()
    let original = b"\xde\xad\xbe\xef"
    let encoded = hex.encode_upper(original)
    let decoded = hex.decode(encoded)
    assert_eq(decoded.len(), 4)
    assert_eq(decoded.get(0), 222)
    assert_eq(decoded.get(1), 173)
    assert_eq(decoded.get(2), 190)
    assert_eq(decoded.get(3), 239)
  end)
end)
