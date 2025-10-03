use "std/test" as test

test.module("String split() and slice() methods")

test.describe("split()", fun ()
    test.it("splits by single character delimiter", fun ()
        let result = "a,b,c".split(",")
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], "a", nil)
        test.assert_eq(result[1], "b", nil)
        test.assert_eq(result[2], "c", nil)
    end)

    test.it("splits by multi-character delimiter", fun ()
        let result = "one::two::three".split("::")
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], "one", nil)
        test.assert_eq(result[1], "two", nil)
        test.assert_eq(result[2], "three", nil)
    end)

    test.it("splits path by forward slash", fun ()
        let path = "/foo/bar/test.q"
        let parts = path.split("/")
        test.assert_eq(parts.len(), 4, nil)
        test.assert_eq(parts[0], "", nil)
        test.assert_eq(parts[1], "foo", nil)
        test.assert_eq(parts[2], "bar", nil)
        test.assert_eq(parts[3], "test.q", nil)
    end)

    test.it("handles empty string", fun ()
        let result = "".split(",")
        test.assert_eq(result.len(), 1, nil)
        test.assert_eq(result[0], "", nil)
    end)

    test.it("handles no delimiter found", fun ()
        let result = "hello".split(",")
        test.assert_eq(result.len(), 1, nil)
        test.assert_eq(result[0], "hello", nil)
    end)

    test.it("splits into characters with empty delimiter", fun ()
        let result = "abc".split("")
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], "a", nil)
        test.assert_eq(result[1], "b", nil)
        test.assert_eq(result[2], "c", nil)
    end)

    test.it("handles consecutive delimiters", fun ()
        let result = "a,,b".split(",")
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], "a", nil)
        test.assert_eq(result[1], "", nil)
        test.assert_eq(result[2], "b", nil)
    end)
end)

test.describe("slice()", fun ()
    test.it("extracts substring with positive indices", fun ()
        let result = "Hello, World!".slice(0, 5)
        test.assert_eq(result, "Hello", nil)
    end)

    test.it("extracts substring from middle", fun ()
        let result = "Hello, World!".slice(7, 12)
        test.assert_eq(result, "World", nil)
    end)

    test.it("handles negative start index", fun ()
        let result = "Hello, World!".slice(-6, 12)
        test.assert_eq(result, "World", nil)
    end)

    test.it("handles negative end index", fun ()
        let result = "Hello, World!".slice(0, -1)
        test.assert_eq(result, "Hello, World", nil)
    end)

    test.it("handles both negative indices", fun ()
        let result = "Hello, World!".slice(-6, -1)
        test.assert_eq(result, "World", nil)
    end)

    test.it("returns empty string when start >= end", fun ()
        let result = "Hello".slice(3, 1)
        test.assert_eq(result, "", nil)
    end)

    test.it("handles start beyond length", fun ()
        let result = "Hello".slice(10, 20)
        test.assert_eq(result, "", nil)
    end)

    test.it("clamps end beyond length", fun ()
        let result = "Hello".slice(0, 100)
        test.assert_eq(result, "Hello", nil)
    end)

    test.it("extracts single character", fun ()
        let result = "Hello".slice(1, 2)
        test.assert_eq(result, "e", nil)
    end)

    test.it("handles Unicode correctly", fun ()
        let result = "Hello 世界".slice(6, 8)
        test.assert_eq(result, "世界", nil)
    end)
end)

test.describe("Combined usage", fun ()
    test.it("extracts filename from path using split", fun ()
        let path = "/foo/bar/test.q"
        let parts = path.split("/")
        let filename = parts[parts.len() - 1]
        test.assert_eq(filename, "test.q", nil)
    end)

    test.it("extracts extension using split and slice", fun ()
        let filename = "test.q"
        let parts = filename.split(".")
        let extension = parts[parts.len() - 1]
        test.assert_eq(extension, "q", nil)
    end)

    test.it("extracts directory from path", fun ()
        let path = "/foo/bar/test.q"
        let parts = path.split("/")
        let directory = parts[parts.len() - 2]
        test.assert_eq(directory, "bar", nil)
    end)
end)
