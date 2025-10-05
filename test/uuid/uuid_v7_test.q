use "std/test" as test
use "std/uuid" as uuid

test.module("UUID v7")

test.describe("Generation", fun ()
    test.it("generates UUID v7", fun ()
        let id = uuid.v7()

        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.version(), 7, "Should be version 7")
    end)

    test.it("generates unique v7 UUIDs", fun ()
        let id1 = uuid.v7()
        let id2 = uuid.v7()

        test.assert_neq(id1.to_string(), id2.to_string(), "Should generate different UUIDs")
    end)
end)

test.describe("Sequential Ordering", fun ()
    test.it("generates UUIDs in ascending order", fun ()
        # Generate multiple UUIDs in sequence
        let ids = [
            uuid.v7(),
            uuid.v7(),
            uuid.v7(),
            uuid.v7(),
            uuid.v7()
        ]

        # Convert to strings for comparison
        let str1 = ids[0].to_string()
        let str2 = ids[1].to_string()
        let str3 = ids[2].to_string()
        let str4 = ids[3].to_string()
        let str5 = ids[4].to_string()

        # v7 UUIDs should be lexicographically sortable
        # Each UUID should be greater than or equal to the previous
        # (equal is possible if generated in same millisecond)
        test.assert(str1 <= str2, "ID 1 should be <= ID 2")
        test.assert(str2 <= str3, "ID 2 should be <= ID 3")
        test.assert(str3 <= str4, "ID 3 should be <= ID 4")
        test.assert(str4 <= str5, "ID 4 should be <= ID 5")
    end)

    test.it("timestamp ordering is preserved", fun ()
        # Generate first UUID
        let id1 = uuid.v7()
        let str1 = id1.to_string()

        # Small delay (native Quest operations)
        let sum = 0
        let i = 0
        while i < 1000
            sum = sum + i
            i = i + 1
        end

        # Generate second UUID after delay
        let id2 = uuid.v7()
        let str2 = id2.to_string()

        # Second UUID should be strictly greater (different timestamp)
        test.assert(str1 < str2, "Later UUID should be greater")
    end)
end)

test.describe("Format and Structure", fun ()
    test.it("has correct UUID structure", fun ()
        let id = uuid.v7()
        let hyphenated = id.to_hyphenated()

        # Should be 36 characters (32 hex + 4 hyphens)
        test.assert_eq(hyphenated.len(), 36, "Hyphenated length should be 36")

        # Should match the pattern: 8-4-4-4-12
        test.assert(hyphenated.contains("-"), "Should contain hyphens")
    end)

    test.it("converts to all formats", fun ()
        let id = uuid.v7()

        let hyphenated = id.to_hyphenated()
        let simple = id.to_simple()
        let urn = id.to_urn()
        let bytes = id.to_bytes()

        test.assert_eq(hyphenated.len(), 36, "Hyphenated should be 36 chars")
        test.assert_eq(simple.len(), 32, "Simple should be 32 chars")
        test.assert(urn.contains("urn:uuid:"), "URN should have prefix")
        test.assert_eq(bytes.len(), 16, "Bytes should be 16 bytes")
    end)
end)

test.describe("Comparison with v4", fun ()
    test.it("v7 maintains timestamp ordering while v4 does not", fun ()
        # Generate alternating v4 and v7 UUIDs
        let v7_1 = uuid.v7()
        let v4_1 = uuid.v4()
        let v7_2 = uuid.v7()
        let v4_2 = uuid.v4()
        let v7_3 = uuid.v7()

        # v7 UUIDs should be ordered
        test.assert(v7_1.to_string() <= v7_2.to_string(), "v7 UUIDs are ordered")
        test.assert(v7_2.to_string() <= v7_3.to_string(), "v7 UUIDs are ordered")

        # v4 has version 4, v7 has version 7
        test.assert_eq(v4_1.version(), 4, "v4 should have version 4")
        test.assert_eq(v7_1.version(), 7, "v7 should have version 7")
    end)
end)

test.describe("Parsing and Roundtrip", fun ()
    test.it("parses v7 UUIDs from strings", fun ()
        let original = uuid.v7()
        let uuid_str = original.to_string()

        let parsed = uuid.parse(uuid_str)

        test.assert_eq(parsed.to_string(), uuid_str, "Parsed UUID should match")
        test.assert_eq(parsed.version(), 7, "Version should be preserved")
    end)

    test.it("roundtrips through bytes", fun ()
        let original = uuid.v7()
        let bytes = original.to_bytes()
        let reconstructed = uuid.from_bytes(bytes)

        test.assert_eq(reconstructed.to_string(), original.to_string(), "Should reconstruct")
        test.assert_eq(reconstructed.version(), 7, "Version should be preserved")
    end)
end)
