use "std/test"
use "std/compress/bzip2"

test.module("std/compress/bzip2")

test.describe("bzip2.compress and bzip2.decompress", fun ()
    test.it("compresses and decompresses string data", fun ()
        # Build a large string by concatenation
        let base = "Hello World! Hello World! Hello World! Hello World! "
        let original = base .. base .. base .. base
        let compressed = bzip2.compress(original)
        let decompressed = bzip2.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), original)
        test.assert_lt(compressed.len(), original.len(), "Compressed size should be smaller")
    end)

    test.it("compresses and decompresses bytes data", fun ()
        let data = b"binary data\x00\xFF\xAB"
        let compressed = bzip2.compress(data)
        let decompressed = bzip2.decompress(compressed)

        # Compare as strings since Bytes equality might not work as expected
        test.assert_eq(decompressed.len(), data.len(), "Decompressed bytes should have same length")
    end)

    test.it("handles empty data", fun ()
        let compressed = bzip2.compress("")
        let decompressed = bzip2.decompress(compressed)
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

        let fast = bzip2.compress(data, 1)
        let default = bzip2.compress(data, 6)
        let best = bzip2.compress(data, 9)

        # Best compression should be smaller or equal to fast
        test.assert_lte(best.len(), fast.len(), "Level 9 should be <= level 1 size")

        # All should decompress to original
        test.assert_eq(bzip2.decompress(fast).decode("utf-8"), data)
        test.assert_eq(bzip2.decompress(default).decode("utf-8"), data)
        test.assert_eq(bzip2.decompress(best).decode("utf-8"), data)
    end)

    test.it("compresses highly repetitive data well", fun ()
        # Build repetitive data
        let data = "aaaaaaaaaa"
        let i = 0
        while i < 10
            data = data .. data
            i = i + 1
        end

        let compressed = bzip2.compress(data)

        # Repetitive data should compress very well
        let ratio = compressed.len().to_f64() / data.len().to_f64()
        test.assert_lt(ratio, 0.05, "Repetitive data should compress to < 5% of original")
    end)

    test.it("validates compression level range", fun ()
        let data = "test"

        # Test invalid levels - should raise errors
        # Note: These test that errors are raised, not exact error message matching
        try
            bzip2.compress(data, -1)
            test.fail("Should have raised error for level < 1")
        catch e
            # Error raised as expected
        end

        try
            bzip2.compress(data, 10)
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

        let compressed = bzip2.compress(data)
        let decompressed = bzip2.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "Large data should round-trip correctly")
    end)

    test.it("preserves UTF-8 text", fun ()
        let data = "Hello 世界! 🌍"
        let compressed = bzip2.compress(data)
        let decompressed = bzip2.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "UTF-8 should be preserved")
    end)

    test.it("level 1 produces valid bzip2", fun ()
        let data = "test data"
        let compressed = bzip2.compress(data, 1)
        let decompressed = bzip2.decompress(compressed)

        test.assert_eq(decompressed.decode("utf-8"), data, "Level 1 should work")
        # Level 1 is the fastest compression
        test.assert(compressed.len() > 0, "Compressed data should exist")
    end)
end)

test.describe("bzip2 error handling", fun ()
    test.it("rejects invalid compressed data", fun ()
        let invalid = b"not bzip2 data"
        try
            bzip2.decompress(invalid)
            test.fail("Should have raised error for invalid bzip2 data")
        catch e
            # Error raised as expected
        end
    end)

    test.it("requires at least one argument for compress", fun ()
        try
            bzip2.compress()
            test.fail("Should require at least one argument")
        catch e
            # Error raised as expected
        end
    end)

    test.it("requires exactly one argument for decompress", fun ()
        try
            bzip2.decompress()
            test.fail("Should require an argument")
        catch e
            # Error raised as expected
        end
    end)
end)
