use "std/test" as test
use "std/hash" as hash

test.module("Hash Functions")

test.describe("MD5", fun ()
    test.it("hashes empty string correctly", fun ()
        test.assert_eq(hash.md5(""), "d41d8cd98f00b204e9800998ecf8427e", nil)
    end)

    test.it("hashes single character correctly", fun ()
        test.assert_eq(hash.md5("a"), "0cc175b9c0f1b6a831c399e269772661", nil)
    end)

    test.it("hashes 'abc' correctly", fun ()
        test.assert_eq(hash.md5("abc"), "900150983cd24fb0d6963f7d28e17f72", nil)
    end)
end)

test.describe("SHA-1", fun ()
    test.it("hashes empty string correctly", fun ()
        test.assert_eq(hash.sha1(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709", nil)
    end)
end)

test.describe("SHA-256", fun ()
    test.it("hashes empty string correctly", fun ()
        test.assert_eq(hash.sha256(""), "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", nil)
    end)

    test.it("hashes 'test' correctly", fun ()
        test.assert_eq(hash.sha256("test"), "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08", nil)
    end)

    test.it("hashes test string correctly", fun ()
        let result = hash.sha256("Hello, Worldnot ")
        test.assert_type(result, "Str", nil)
        test.assert_eq(result.len(), 64, nil) # SHA-256 produces 32 bytes = 64 hex chars
    end)
end)

test.describe("SHA-512", fun ()
    test.it("hashes empty string correctly", fun ()
        let expected = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
        test.assert_eq(hash.sha512(""), expected, nil)
    end)

    test.it("hashes test string correctly", fun ()
        let result = hash.sha512("Hello, Worldnot ")
        test.assert_type(result, "Str", nil)
        test.assert_eq(result.len(), 128, nil) # SHA-512 produces 64 bytes = 128 hex chars
    end)
end)

test.describe("CRC32", fun ()
    test.it("generates checksum for empty string", fun ()
        test.assert_eq(hash.crc32(""), "00000000", nil)
    end)

    test.it("generates checksum for test string", fun ()
        let result = hash.crc32("Hello, Worldnot ")
        test.assert_type(result, "Str", nil)
        test.assert_eq(result.len(), 8, nil) # CRC32 produces 4 bytes = 8 hex chars
    end)

    test.it("generates different checksums for different strings", fun ()
        let crc1 = hash.crc32("test1")
        let crc2 = hash.crc32("test2")
        test.assert_neq(crc1, crc2, nil)
    end)
end)
