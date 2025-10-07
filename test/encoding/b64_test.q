use "std/test" as test
use "std/encoding/b64" as b64

test.module("Encoding Tests")

test.describe("Base64 Encoding - String Method", fun ()
    test.it("encodes simple string", fun ()
        let orig = "Hello World"
        let encoded = orig.encode("b64")
        test.assert_eq(encoded, "SGVsbG8gV29ybGQ=")    end)

    test.it("decodes simple string", fun ()
        let encoded = "SGVsbG8gV29ybGQ="
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, "Hello World")    end)

    test.it("round-trip encoding/decoding", fun ()
        let orig = "The quick brown fox"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)

    test.it("encodes empty string", fun ()
        let encoded = "".encode("b64")
        test.assert_eq(encoded, "")    end)

    test.it("encodes string with special characters", fun ()
        let orig = "test+data/with=special"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)

    test.it("encodes numbers as strings", fun ()
        let orig = "12345"
        let encoded = orig.encode("b64")
        test.assert_eq(encoded, "MTIzNDU=")    end)

    test.it("encodes unicode characters", fun ()
        let orig = "hello"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)
end)

test.describe("Base64 Encoding - Module Functions", fun ()
    test.it("encodes with module function", fun ()
        let encoded = b64.encode("test")
        test.assert_eq(encoded, "dGVzdA==")    end)

    test.it("decodes with module function", fun ()
        let decoded = b64.decode("dGVzdA==")
        test.assert_eq(decoded, "test")    end)

    test.it("module function round-trip", fun ()
        let orig = "Module test data"
        let encoded = b64.encode(orig)
        let decoded = b64.decode(encoded)
        test.assert_eq(decoded, orig)    end)
end)

test.describe("URL-Safe Base64 Encoding", fun ()
    test.it("encodes with URL-safe method", fun ()
        let orig = "test data"
        let encoded = orig.encode("b64url")
        let decoded = encoded.decode("b64url")
        test.assert_eq(decoded, orig)    end)

    test.it("URL-safe has no padding", fun ()
        let encoded = "test".encode("b64url")
        # URL-safe removes padding (no = at end)
        test.assert_eq(encoded, "dGVzdA")    end)

    test.it("encodes with URL-safe module function", fun ()
        let encoded = b64.encode_url("test")
        test.assert_eq(encoded, "dGVzdA")    end)

    test.it("decodes with URL-safe module function", fun ()
        let decoded = b64.decode_url("dGVzdA")
        test.assert_eq(decoded, "test")    end)

    test.it("URL-safe round-trip", fun ()
        let orig = "URL safe data"
        let encoded = b64.encode_url(orig)
        let decoded = b64.decode_url(encoded)
        test.assert_eq(decoded, orig)    end)
end)

test.describe("Hex Encoding/Decoding", fun ()
    test.it("encodes to hex", fun ()
        let orig = "test"
        let encoded = orig.encode("hex")
        test.assert_eq(encoded, "74657374")    end)

    test.it("decodes from hex", fun ()
        let encoded = "74657374"
        let decoded = encoded.decode("hex")
        test.assert_eq(decoded, "test")    end)

    test.it("hex round-trip", fun ()
        let orig = "Hello"
        let encoded = orig.encode("hex")
        let decoded = encoded.decode("hex")
        test.assert_eq(decoded, orig)    end)

    test.it("hex encodes empty string", fun ()
        let encoded = "".encode("hex")
        test.assert_eq(encoded, "")    end)
end)

test.describe("Encoding Edge Cases", fun ()
    test.it("handles long strings", fun ()
        let orig = "This is a longer string that needs to be encoded properly to test the base64 encoding implementation"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)

    test.it("encodes strings with spaces", fun ()
        let orig = "line1 line2 line3"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)

    test.it("encodes strings with tabs", fun ()
        let orig = "col1	col2	col3"
        let encoded = orig.encode("b64")
        let decoded = encoded.decode("b64")
        test.assert_eq(decoded, orig)    end)
end)

test.describe("Encoding Compatibility", fun ()
    test.it("string method matches module function", fun ()
        let data = "compatibility test"
        let method_encoded = data.encode("b64")
        let module_encoded = b64.encode(data)
        test.assert_eq(method_encoded, module_encoded)    end)

    test.it("decode matches regardless of method", fun ()
        let encoded = "dGVzdA=="
        let method_decoded = encoded.decode("b64")
        let module_decoded = b64.decode(encoded)
        test.assert_eq(method_decoded, module_decoded)    end)
end)
