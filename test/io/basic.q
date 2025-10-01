#!/usr/bin/env quest
# Tests for IO module

use "std/test" as test
use "std/io" as iomod

test.describe("File Reading and Writing", fun ()
    test.it("writes and reads file", fun ()
        let content = "Hello, Quest!"
        iomod.write_file("test_file_temp.txt", content)
        let read_content = iomod.read_file("test_file_temp.txt")

        test.assert(read_content == content, "content should match")

        # Cleanup
        iomod.remove("test_file_temp.txt")
    end)

    test.it("reads existing file", fun ()
        # Write a test file first
        iomod.write_file("test_read.txt", "test content")
        let content = iomod.read_file("test_read.txt")

        test.assert(content.len() > 0, "should read content")
        test.assert(content == "test content", "should match written content")

        # Cleanup
        iomod.remove("test_read.txt")
    end)

    test.it("writes multiline content", fun ()
        let lines = "line1\nline2\nline3"
        iomod.write_file("test_multiline.txt", lines)
        let read = iomod.read_file("test_multiline.txt")

        test.assert(read == lines, "multiline content should match")

        # Cleanup
        iomod.remove("test_multiline.txt")
    end)
end)

test.describe("File Existence", fun ()
    test.it("checks if file exists", fun ()
        # Create a test file
        iomod.write_file("test_exists.txt", "data")

        test.assert(iomod.exists("test_exists.txt"), "file should exist")

        # Cleanup
        iomod.remove("test_exists.txt")

        test.assert(!iomod.exists("test_exists.txt"), "file should not exist after removal")
    end)

    test.it("checks if directory exists", fun ()
        test.assert(iomod.exists("."), "current directory should exist")
        test.assert(iomod.exists("test"), "test directory should exist")
    end)

    test.it("returns false for non-existent path", fun ()
        test.assert(!iomod.exists("nonexistent_file_12345.txt"), "should not exist")
    end)
end)

test.describe("Glob Pattern Matching", fun ()
    test.it("finds files with glob pattern", fun ()
        # Create some test files
        iomod.write_file("test_glob_1.txt", "data1")
        iomod.write_file("test_glob_2.txt", "data2")
        iomod.write_file("test_glob_3.txt", "data3")

        let files = iomod.glob("test_glob_*.txt")

        test.assert(files.len() == 3, "should find 3 files")

        # Cleanup
        iomod.remove("test_glob_1.txt")
        iomod.remove("test_glob_2.txt")
        iomod.remove("test_glob_3.txt")
    end)

    test.it("finds quest files in test directory", fun ()
        let quest_files = iomod.glob("test/*.q")
        test.assert(quest_files.len() > 0, "should find quest files")
    end)

    test.it("finds files recursively", fun ()
        let all_q_files = iomod.glob("test/**/*.q")
        test.assert(all_q_files.len() > 0, "should find quest files recursively")
    end)

    test.it("returns empty array for no matches", fun ()
        let files = iomod.glob("nonexistent_pattern_xyz_*.abc")
        test.assert(files.len() == 0, "should return empty array")
    end)
end)

test.describe("Glob Match Function", fun ()
    test.it("matches simple patterns", fun ()
        test.assert(iomod.glob_match("test.q", "*.q"), "should match *.q")
        test.assert(iomod.glob_match("hello.txt", "*.txt"), "should match *.txt")
        test.assert(!iomod.glob_match("hello.q", "*.txt"), "should not match different extension")
    end)

    test.it("matches with prefix", fun ()
        test.assert(iomod.glob_match("test_file.q", "test_*.q"), "should match test_*.q")
        test.assert(!iomod.glob_match("other_file.q", "test_*.q"), "should not match wrong prefix")
    end)

    test.it("matches paths", fun ()
        test.assert(iomod.glob_match("src/main.rs", "src/*.rs"), "should match src/*.rs")
        test.assert(!iomod.glob_match("test/main.rs", "src/*.rs"), "should not match wrong directory")
    end)

    test.it("matches recursive patterns", fun ()
        test.assert(iomod.glob_match("foo/bar/baz.txt", "**/*.txt"), "should match **/*.txt")
        test.assert(iomod.glob_match("a/b/c/d.txt", "**/*.txt"), "should match nested paths")
    end)
end)

test.describe("File Removal", fun ()
    test.it("removes file", fun ()
        # Create file
        iomod.write_file("test_remove.txt", "delete me")
        test.assert(iomod.exists("test_remove.txt"), "file should exist before removal")

        # Remove it
        iomod.remove("test_remove.txt")
        test.assert(!iomod.exists("test_remove.txt"), "file should not exist after removal")
    end)
end)
