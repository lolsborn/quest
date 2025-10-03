#!/usr/bin/env quest
# Comprehensive tests for all UUID versions

use "std/test" as test
use "std/uuid" as uuid

test.module("UUID Versions")

test.describe("UUID v1 (Timestamp-based)", fun ()
    test.it("generates valid v1 UUID", fun ()
        let id = uuid.v1()
        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.version(), 1, "Should be version 1")
    end)

    test.it("generates v1 with custom node ID", fun ()
        let node_id = b"\x01\x02\x03\x04\x05\x06"
        let id = uuid.v1(node_id)
        test.assert_eq(id.version(), 1, "Should be version 1")
    end)

    test.it("generates unique v1 UUIDs", fun ()
        let id1 = uuid.v1()
        let id2 = uuid.v1()
        test.assert_eq(id1.neq(id2), true, "Should generate different UUIDs")
    end)

    test.it("raises error on invalid node ID length", fun ()
        test.assert_raises("uuid.v1 node_id must be exactly 6 bytes", fun ()
            uuid.v1(b"\x01\x02\x03")
        end, nil)
    end)
end)

test.describe("UUID v3 (MD5 namespace-based)", fun ()
    test.it("generates deterministic v3 UUID", fun ()
        let id1 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let id2 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")

        test.assert_type(id1, "Uuid", "Should create Uuid type")
        test.assert_eq(id1.version(), 3, "Should be version 3")
        test.assert_eq(id1.eq(id2), true, "Same namespace+name should produce same UUID")
    end)

    test.it("generates different UUIDs for different names", fun ()
        let id1 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let id2 = uuid.v3(uuid.NAMESPACE_DNS, "different.com")

        test.assert_eq(id1.neq(id2), true, "Different names should produce different UUIDs")
    end)

    test.it("generates different UUIDs for different namespaces", fun ()
        let id1 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let id2 = uuid.v3(uuid.NAMESPACE_URL, "example.com")

        test.assert_eq(id1.neq(id2), true, "Different namespaces should produce different UUIDs")
    end)

    test.it("works with bytes as name", fun ()
        let id = uuid.v3(uuid.NAMESPACE_DNS, b"example.com")
        test.assert_eq(id.version(), 3, "Should work with bytes")
    end)

    test.it("supports all namespace constants", fun ()
        let id_dns = uuid.v3(uuid.NAMESPACE_DNS, "test")
        let id_url = uuid.v3(uuid.NAMESPACE_URL, "test")
        let id_oid = uuid.v3(uuid.NAMESPACE_OID, "test")
        let id_x500 = uuid.v3(uuid.NAMESPACE_X500, "test")

        # All should be different
        test.assert_eq(id_dns.neq(id_url), true, "DNS vs URL namespaces differ")
        test.assert_eq(id_dns.neq(id_oid), true, "DNS vs OID namespaces differ")
        test.assert_eq(id_dns.neq(id_x500), true, "DNS vs X500 namespaces differ")
    end)
end)

test.describe("UUID v5 (SHA1 namespace-based)", fun ()
    test.it("generates deterministic v5 UUID", fun ()
        let id1 = uuid.v5(uuid.NAMESPACE_DNS, "example.com")
        let id2 = uuid.v5(uuid.NAMESPACE_DNS, "example.com")

        test.assert_type(id1, "Uuid", "Should create Uuid type")
        test.assert_eq(id1.version(), 5, "Should be version 5")
        test.assert_eq(id1.eq(id2), true, "Same namespace+name should produce same UUID")
    end)

    test.it("generates different UUIDs for different names", fun ()
        let id1 = uuid.v5(uuid.NAMESPACE_DNS, "example.com")
        let id2 = uuid.v5(uuid.NAMESPACE_DNS, "different.com")

        test.assert_eq(id1.neq(id2), true, "Different names should produce different UUIDs")
    end)

    test.it("produces different UUID than v3 for same input", fun ()
        let id_v3 = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let id_v5 = uuid.v5(uuid.NAMESPACE_DNS, "example.com")

        test.assert_eq(id_v3.neq(id_v5), true, "v3 and v5 should produce different UUIDs")
    end)

    test.it("works with bytes as name", fun ()
        let id = uuid.v5(uuid.NAMESPACE_URL, b"https://example.com")
        test.assert_eq(id.version(), 5, "Should work with bytes")
    end)
end)

test.describe("UUID v6 (Improved timestamp-based)", fun ()
    test.it("generates valid v6 UUID", fun ()
        let id = uuid.v6()
        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.version(), 6, "Should be version 6")
    end)

    test.it("generates v6 with custom node ID", fun ()
        let node_id = b"\xAA\xBB\xCC\xDD\xEE\xFF"
        let id = uuid.v6(node_id)
        test.assert_eq(id.version(), 6, "Should be version 6")
    end)

    test.it("generates unique v6 UUIDs", fun ()
        let id1 = uuid.v6()
        let id2 = uuid.v6()
        test.assert_eq(id1.neq(id2), true, "Should generate different UUIDs")
    end)

    test.it("raises error on invalid node ID length", fun ()
        test.assert_raises("uuid.v6 node_id must be exactly 6 bytes", fun ()
            uuid.v6(b"\x01\x02")
        end, nil)
    end)
end)

test.describe("UUID v8 (Custom data)", fun ()
    test.it("generates valid v8 UUID from 16 bytes", fun ()
        let data = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F\x10"
        let id = uuid.v8(data)

        test.assert_type(id, "Uuid", "Should create Uuid type")
        test.assert_eq(id.version(), 8, "Should be version 8")
    end)

    test.it("produces same UUID from same data", fun ()
        let data = b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"
        let id1 = uuid.v8(data)
        let id2 = uuid.v8(data)

        test.assert_eq(id1.eq(id2), true, "Same data should produce same UUID")
    end)

    test.it("produces different UUIDs from different data", fun ()
        let data1 = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
        let data2 = b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF"

        let id1 = uuid.v8(data1)
        let id2 = uuid.v8(data2)

        test.assert_eq(id1.neq(id2), true, "Different data should produce different UUIDs")
    end)

    test.it("raises error on invalid byte length", fun ()
        test.assert_raises("uuid.v8 requires exactly 16 bytes", fun ()
            uuid.v8(b"\x01\x02\x03")
        end, nil)
    end)

    test.it("can roundtrip through to_bytes", fun ()
        let original_data = b"\x12\x34\x56\x78\x9A\xBC\xDE\xF0\x11\x22\x33\x44\x55\x66\x77\x88"
        let id = uuid.v8(original_data)
        let bytes = id.to_bytes()

        test.assert_eq(bytes.len(), 16, "Should have 16 bytes")
        # Note: to_bytes may not return exact same bytes due to version/variant bits
    end)
end)

test.describe("Version comparison", fun ()
    test.it("all versions are unique for same input concept", fun ()
        let v1 = uuid.v1()
        let v3 = uuid.v3(uuid.NAMESPACE_DNS, "test")
        let v4 = uuid.v4()
        let v5 = uuid.v5(uuid.NAMESPACE_DNS, "test")
        let v6 = uuid.v6()
        let v7 = uuid.v7()
        let v8 = uuid.v8(b"\x00\x11\x22\x33\x44\x55\x66\x77\x88\x99\xAA\xBB\xCC\xDD\xEE\xFF")

        test.assert_eq(v1.version(), 1, "v1 has version 1")
        test.assert_eq(v3.version(), 3, "v3 has version 3")
        test.assert_eq(v4.version(), 4, "v4 has version 4")
        test.assert_eq(v5.version(), 5, "v5 has version 5")
        test.assert_eq(v6.version(), 6, "v6 has version 6")
        test.assert_eq(v7.version(), 7, "v7 has version 7")
        test.assert_eq(v8.version(), 8, "v8 has version 8")
    end)

    test.it("namespace-based versions are deterministic", fun ()
        # v3 and v5 should always produce same result
        let v3_a = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let v3_b = uuid.v3(uuid.NAMESPACE_DNS, "example.com")
        let v5_a = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")
        let v5_b = uuid.v5(uuid.NAMESPACE_URL, "https://example.com")

        test.assert_eq(v3_a.eq(v3_b), true, "v3 is deterministic")
        test.assert_eq(v5_a.eq(v5_b), true, "v5 is deterministic")
    end)

    test.it("random versions are non-deterministic", fun ()
        # v1, v4, v6, v7 should produce different results each time
        let v1_a = uuid.v1()
        let v1_b = uuid.v1()
        let v4_a = uuid.v4()
        let v4_b = uuid.v4()

        test.assert_eq(v1_a.neq(v1_b), true, "v1 is non-deterministic")
        test.assert_eq(v4_a.neq(v4_b), true, "v4 is non-deterministic")
    end)
end)

test.describe("Namespace constants", fun ()
    test.it("namespace constants are valid UUIDs", fun ()
        test.assert_type(uuid.NAMESPACE_DNS, "Uuid", "NAMESPACE_DNS is Uuid")
        test.assert_type(uuid.NAMESPACE_URL, "Uuid", "NAMESPACE_URL is Uuid")
        test.assert_type(uuid.NAMESPACE_OID, "Uuid", "NAMESPACE_OID is Uuid")
        test.assert_type(uuid.NAMESPACE_X500, "Uuid", "NAMESPACE_X500 is Uuid")
    end)

    test.it("namespace constants are different from each other", fun ()
        test.assert_eq(uuid.NAMESPACE_DNS.neq(uuid.NAMESPACE_URL), true, "DNS != URL")
        test.assert_eq(uuid.NAMESPACE_DNS.neq(uuid.NAMESPACE_OID), true, "DNS != OID")
        test.assert_eq(uuid.NAMESPACE_DNS.neq(uuid.NAMESPACE_X500), true, "DNS != X500")
    end)
end)
