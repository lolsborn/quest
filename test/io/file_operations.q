use "std/test" as test
use "std/io" as io

test.module("IO - File Operations")

test.describe("File reading and writing", fun ()
    test.it("writes and reads a file", fun ()
        let content = "Hello, World!"
        io.write("test_output.txt", content)
        let result = io.read("test_output.txt")
        io.remove("test_output.txt")
        test.assert_eq(result, content, "should read back written content")
    end)

    test.it("checks if file exists", fun ()
        io.write("exists_test.txt", "test")
        test.assert_eq(io.exists("exists_test.txt"), true, "file should exist")
        io.remove("exists_test.txt")
        test.assert_eq(io.exists("nonexistent.txt"), false, "file should not exist")
    end)

    test.it("appends to existing file", fun ()
        io.write("append_test.txt", "Line 1\n")
        io.append("append_test.txt", "Line 2\n")
        let result = io.read("append_test.txt")
        io.remove("append_test.txt")
        test.assert_eq(result, "Line 1\nLine 2\n", "should contain both lines")
    end)

    test.it("gets file size", fun ()
        let content = "12345"
        io.write("size_test.txt", content)
        let size = io.size("size_test.txt")
        io.remove("size_test.txt")
        test.assert_eq(size, 5, "file size should be 5 bytes")
    end)
end)

test.describe("Glob pattern matching", fun ()
    test.it("finds files matching pattern", fun ()
        io.write("test1.txt", "a")
        io.write("test2.txt", "b")
        io.write("other.md", "c")

        let txt_files = io.glob("*.txt")
        let has_test1 = txt_files.contains("test1.txt")
        let has_test2 = txt_files.contains("test2.txt")

        io.remove("test1.txt")
        io.remove("test2.txt")
        io.remove("other.md")

        test.assert_eq(has_test1, true, "should find test1.txt")
        test.assert_eq(has_test2, true, "should find test2.txt")
    end)
end)
