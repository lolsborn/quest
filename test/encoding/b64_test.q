use "std/test" {it, describe, module, assert_eq}
use "std/encoding/b64" as b64

module("Encoding Tests")

describe("Base64 Encoding - String Method", fun ()
  it("encodes simple string", fun ()
    let orig = "Hello World"
    let encoded = orig.encode("b64")
    assert_eq(encoded, "SGVsbG8gV29ybGQ=")
  end)

  it("decodes simple string", fun ()
    let encoded = "SGVsbG8gV29ybGQ="
    let decoded = encoded.decode("b64")
    assert_eq(decoded, "Hello World")
  end)

  it("round-trip encoding/decoding", fun ()
    let orig = "The quick brown fox"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)

  it("encodes empty string", fun ()
    let encoded = "".encode("b64")
    assert_eq(encoded, "")
  end)

  it("encodes string with special characters", fun ()
    let orig = "test+data/with=special"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)

  it("encodes numbers as strings", fun ()
    let orig = "12345"
    let encoded = orig.encode("b64")
    assert_eq(encoded, "MTIzNDU=")
  end)

  it("encodes unicode characters", fun ()
    let orig = "hello"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)
end)

describe("Base64 Encoding - Module Functions", fun ()
  it("encodes with module function", fun ()
    let encoded = b64.encode("test")
    assert_eq(encoded, "dGVzdA==")
  end)

  it("decodes with module function", fun ()
    let decoded = b64.decode("dGVzdA==")
    assert_eq(decoded, "test")
  end)

  it("module function round-trip", fun ()
    let orig = "Module test data"
    let encoded = b64.encode(orig)
    let decoded = b64.decode(encoded)
    assert_eq(decoded, orig)
  end)
end)

describe("URL-Safe Base64 Encoding", fun ()
  it("encodes with URL-safe method", fun ()
    let orig = "test data"
    let encoded = orig.encode("b64url")
    let decoded = encoded.decode("b64url")
    assert_eq(decoded, orig)
  end)

  it("URL-safe has no padding", fun ()
    let encoded = "test".encode("b64url")
    # URL-safe removes padding (no = at end)
    assert_eq(encoded, "dGVzdA")
  end)

  it("encodes with URL-safe module function", fun ()
    let encoded = b64.encode_url("test")
    assert_eq(encoded, "dGVzdA")
  end)

  it("decodes with URL-safe module function", fun ()
    let decoded = b64.decode_url("dGVzdA")
    assert_eq(decoded, "test")
  end)

  it("URL-safe round-trip", fun ()
    let orig = "URL safe data"
    let encoded = b64.encode_url(orig)
    let decoded = b64.decode_url(encoded)
    assert_eq(decoded, orig)
  end)
end)

describe("Hex Encoding/Decoding", fun ()
  it("encodes to hex", fun ()
    let orig = "test"
    let encoded = orig.encode("hex")
    assert_eq(encoded, "74657374")
  end)

  it("decodes from hex", fun ()
    let encoded = "74657374"
    let decoded = encoded.decode("hex")
    assert_eq(decoded, "test")
  end)

  it("hex round-trip", fun ()
    let orig = "Hello"
    let encoded = orig.encode("hex")
    let decoded = encoded.decode("hex")
    assert_eq(decoded, orig)
  end)

  it("hex encodes empty string", fun ()
    let encoded = "".encode("hex")
    assert_eq(encoded, "")
  end)
end)

describe("Encoding Edge Cases", fun ()
  it("handles long strings", fun ()
    let orig = "This is a longer string that needs to be encoded properly to test the base64 encoding implementation"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)

  it("encodes strings with spaces", fun ()
    let orig = "line1 line2 line3"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)

  it("encodes strings with tabs", fun ()
    let orig = "col1	col2	col3"
    let encoded = orig.encode("b64")
    let decoded = encoded.decode("b64")
    assert_eq(decoded, orig)
  end)
end)

describe("Encoding Compatibility", fun ()
  it("string method matches module function", fun ()
    let data = "compatibility test"
    let method_encoded = data.encode("b64")
    let module_encoded = b64.encode(data)
    assert_eq(method_encoded, module_encoded)
   end)

  it("decode matches regardless of method", fun ()
    let encoded = "dGVzdA=="
    let method_decoded = encoded.decode("b64")
    let module_decoded = b64.decode(encoded)
    assert_eq(method_decoded, module_decoded) 
  end)
end)
