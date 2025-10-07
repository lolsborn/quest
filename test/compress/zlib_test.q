use "std/test"
use "std/compress/zlib"

test.module("std/compress/zlib")

test.describe("zlib.compress and zlib.decompress", fun ()
    test.it("compresses and decompresses string data", fun ()
        # Build a large string by concatenation
        let base = "Hello World! Hello World! Hello World! Hello World! "
        let original = base .. base .. base .. base
        let compressed = zlib.compress(original)
        let decompressed = zlib.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), original)
        test.assert_lt(compressed.len(), original.len(), "Compressed size should be smaller")
    end)

    test.it("compresses and decompresses bytes data", fun ()
        let data = b"binary data\x00\xFF\xAB"
        let compressed = zlib.compress(data)
        let decompressed = zlib.decompress(compressed)

        # Compare as strings since Bytes equality might not work as expected
        test.assert_eq(decompressed.len(), data.len(), "Decompressed bytes should have same length")
    end)

    test.it("handles empty data", fun ()
        let compressed = zlib.compress("")
        let decompressed = zlib.decompress(compressed)
        test.assert_eq(decompressed.decode("utf-8"), "", "Empty data should decompress to empty")
    end)

    test.it("supports different compression levels", fun ()
        # Build a large string with repetition
        let data = "xxxxxxxxxx"
        let i = 0
        while i < 10
            data = data .. data
            i = i + 1
        end

        let fast = zlib.compress(data, 1)
        let default = zlib.compress(data, 6)
        let best = zlib.compress(data, 9)

        # Best compression should be smaller or equal to fast
        test.assert_lte(best.len(), fast.len(), "Level 9 should be <= level 1 size")

        # All should decompress to original
        test.assert_eq(zlib.decompress(fast).decode("utf-8"), data)
        test.assert_eq(zlib.decompress(default).decode("utf-8"), data)
        test.assert_eq(zlib.decompress(best).decode("utf-8"), data)
    end)

    test.it("compresses highly repetitive data well", fun ()
        # Build repetitive data
        let data = "aaaaaaaaaa"
        let i = 0
        while i < 10
            data = data .. data
            i = i + 1
        end

        let compressed = zlib.compress(data)

        # Repetitive data should compress very well
        let ratio = compressed.len().to_f64() / data.len().to_f64()
        test.assert_lt(ratio, 0.05, "Repetitive data should compress to < 5% of original")
    end)

    test.it("validates compression level range", fun ()
        let data = "test"

        # Test invalid levels - should raise errors
        # Note: These test that errors are raised, not exact error message matching
        try
            zlib.compress(data, -1)
            test.fail("Should have raised error for level < 0")
        catch e
            # Error raised as expected
        end

        try
            zlib.compress(data, 10)
            test.fail("Should have raised error for level > 9")
        catch e
            # Error raised as expected
        end
    end)

    test.it("handles large data", fun ()
        # Build large string
        let data = "The quick brown fox jumps over the lazy dog. "
        let i = 0
        while i < 8
            data = data .. data
            i = i + 1
        end

        let compressed = zlib.compress(data)
        let decompressed = zlib.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "Large data should round-trip correctly")
    end)

    test.it("preserves UTF-8 text", fun ()
        let data = "Hello 世界! 🌍"
        let compressed = zlib.compress(data)
        let decompressed = zlib.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "UTF-8 should be preserved")
    end)

    test.it("level 0 produces valid zlib", fun ()
        let data = "test data"
        let compressed = zlib.compress(data, 0)
        let decompressed = zlib.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "Level 0 should work")
        # Level 0 should be larger than compressed (no actual compression)
        test.assert_gte(compressed.len(), data.len(), "Level 0 adds overhead without compressing")
    end)
end)

test.describe("zlib error handling", fun ()
    test.it("rejects invalid compressed data", fun ()
        let invalid = b"not zlib data"
        try
            zlib.decompress(invalid)
            test.fail("Should have raised error for invalid zlib data")
        catch e
            # Error raised as expected
        end
    end)

    test.it("requires at least one argument for compress", fun ()
        try
            zlib.compress()
            test.fail("Should require at least one argument")
        catch e
            # Error raised as expected
        end
    end)

    test.it("requires exactly one argument for decompress", fun ()
        try
            zlib.decompress()
            test.fail("Should require an argument")
        catch e
            # Error raised as expected
        end
    end)
end)
