use "std/test" as test
use "std/uuid" as uuid

test.module("UUID")

test.describe("Generation", fun ()
    test.it("generates random v4 UUIDs", fun ()
        let id1 = uuid.v4()
        let id2 = uuid.v4()

        test.assert_type(id1, "Uuid", "Should create Uuid type")
        test.assert_type(id2, "Uuid", "Should create Uuid type")
        test.assert_neq(id1.to_string(), id2.to_string(), "Should generate different UUIDs")
    end)

    test.it("creates nil UUID", fun ()
        let id = uuid.nil_uuid()

        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.is_nil(), true, "Should be a nil UUID")
        test.assert_eq(id.to_string(), "00000000-0000-0000-0000-000000000000", "Nil UUID should be all zeros")
    end)
end)

test.describe("Parsing", fun ()
    test.it("parses valid UUID strings", fun ()
        let uuid_str = "550e8400-e29b-41d4-a716-446655440000"
        let id = uuid.parse(uuid_str)

        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.to_string(), uuid_str, "Parsed UUID should match original string")
    end)

    test.it("raises error on invalid UUID string", fun ()
        test.assert_raises(ValueErr, fun ()
            uuid.parse("invalid-uuid-string")
        end)
    end)

    test.it("parses UUID without hyphens", fun ()
        let id = uuid.parse("550e8400e29b41d4a716446655440000")
        test.assert_eq(id.to_string(), "550e8400-e29b-41d4-a716-446655440000", "Should parse and format with hyphens")
    end)
end)

test.describe("Methods", fun ()
    test.it("converts to string", fun ()
        let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let uuid_str = id.to_string()

        test.assert_type(uuid_str, "Str", "Should return string")
        test.assert_eq(uuid_str, "550e8400-e29b-41d4-a716-446655440000", "Should be hyphenated lowercase")
    end)

    test.it("converts to hyphenated format", fun ()
        let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let hyphenated = id.to_hyphenated()

        test.assert_eq(hyphenated, "550e8400-e29b-41d4-a716-446655440000", "Should have hyphens")
    end)

    test.it("converts to simple format (no hyphens)", fun ()
        let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let simple = id.to_simple()

        test.assert_eq(simple, "550e8400e29b41d4a716446655440000", "Should have no hyphens")
    end)

    test.it("converts to URN format", fun ()
        let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let urn = id.to_urn()

        test.assert_eq(urn, "urn:uuid:550e8400-e29b-41d4-a716-446655440000", "Should have URN prefix")
    end)

    test.it("converts to bytes", fun ()
        let id = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let bytes = id.to_bytes()

        test.assert_type(bytes, "Bytes", "Should return Bytes type")
        test.assert_eq(bytes.len(), 16, "UUID should be 16 bytes")
    end)

    test.it("gets version number", fun ()
        let id = uuid.v4()
        let version = id.version()

        test.assert_eq(version, 4, "v4 UUID should have version 4")
    end)

    test.it("checks equality", fun ()
        let id1 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let id2 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let id3 = uuid.parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8")

        test.assert_eq(id1.eq(id2), true, "Same UUIDs should be equal")
        test.assert_eq(id1.eq(id3), false, "Different UUIDs should not be equal")
    end)

    test.it("checks inequality", fun ()
        let id1 = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let id2 = uuid.parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8")

        test.assert_eq(id1.neq(id2), true, "Different UUIDs should be not equal")
    end)
end)

test.describe("Bytes Conversion", fun ()
    test.it("creates UUID from bytes", fun ()
        # Create a UUID and get its bytes
        let original = uuid.parse("550e8400-e29b-41d4-a716-446655440000")
        let bytes = original.to_bytes()

        # Reconstruct UUID from bytes
        let reconstructed = uuid.from_bytes(bytes)

        test.assert_eq(reconstructed.to_string(), original.to_string(), "Should reconstruct same UUID from bytes")
    end)

    test.it("raises error on invalid byte length", fun ()
        test.assert_raises(ValueErr, fun ()
            uuid.from_bytes(b"\x01\x02\x03")
        end)
    end)
end)
