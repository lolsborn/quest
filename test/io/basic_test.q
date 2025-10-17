#!/usr/bin/env quest
# Tests for IO module

use "std/test" { module, describe, it, assert_eq, assert }
use "std/io" as iomod

describe("File Reading and Writing", fun ()
  it("writes and reads file", fun ()
    let content = "Hello, Quest!"
    iomod.write("test_file_temp.txt", content)
    let read_content = iomod.read("test_file_temp.txt")

    assert(read_content == content, "content should match")

    # Cleanup
    iomod.remove("test_file_temp.txt")
  end)

  it("reads existing file", fun ()
    # Write a test file first
    iomod.write("test_read.txt", "test content")
    let content = iomod.read("test_read.txt")

    assert(content.len() > 0, "should read content")
    assert(content == "test content", "should match written content")

    # Cleanup
    iomod.remove("test_read.txt")
  end)

  it("writes multiline content", fun ()
    let lines = "line1\nline2\nline3"
    iomod.write("test_multiline.txt", lines)
    let read = iomod.read("test_multiline.txt")

    assert(read == lines, "multiline content should match")

    # Cleanup
    iomod.remove("test_multiline.txt")
  end)
end)

describe("File Existence", fun ()
  it("checks if file exists", fun ()
    # Create a test file
    iomod.write("test_exists.txt", "data")

    assert(iomod.exists("test_exists.txt"), "file should exist")

    # Cleanup
    iomod.remove("test_exists.txt")

    assert(not iomod.exists("test_exists.txt"), "file should not exist after removal")
  end)

  it("checks if directory exists", fun ()
    assert(iomod.exists("."), "current directory should exist")
    assert(iomod.exists("test"), "test directory should exist")
  end)

  it("returns false for non-existent path", fun ()
    assert(not iomod.exists("nonexistent_file_12345.txt"), "should not exist")
  end)
end)

describe("Glob Pattern Matching", fun ()
  it("finds files with glob pattern", fun ()
    # Create some test files
    iomod.write("test_glob_1.txt", "data1")
    iomod.write("test_glob_2.txt", "data2")
    iomod.write("test_glob_3.txt", "data3")

    let files = iomod.glob("test_glob_*.txt")

    assert(files.len() == 3, "should find 3 files")

    # Cleanup
    iomod.remove("test_glob_1.txt")
    iomod.remove("test_glob_2.txt")
    iomod.remove("test_glob_3.txt")
  end)

  it("finds quest files in test directory", fun ()
    let quest_files = iomod.glob("test/*.q")
    assert(quest_files.len() > 0, "should find quest files")
  end)

  it("finds files recursively", fun ()
    let all_q_files = iomod.glob("test/**/*.q")
    assert(all_q_files.len() > 0, "should find quest files recursively")
  end)

  it("returns empty array for no matches", fun ()
    let files = iomod.glob("nonexistent_pattern_xyz_*.abc")
    assert(files.len() == 0, "should return empty array")
  end)
end)

describe("Glob Match Function", fun ()
  it("matches simple patterns", fun ()
    assert(iomod.glob_match("test.q", "*.q"), "should match *.q")
    assert(iomod.glob_match("hello.txt", "*.txt"), "should match *.txt")
    assert(not iomod.glob_match("hello.q", "*.txt"), "should not match different extension")
  end)

  it("matches with prefix", fun ()
    assert(iomod.glob_match("test_file.q", "test_*.q"), "should match test_*.q")
    assert(not iomod.glob_match("other_file.q", "test_*.q"), "should not match wrong prefix")
  end)

  it("matches paths", fun ()
    assert(iomod.glob_match("src/main.rs", "src/*.rs"), "should match src/*.rs")
    assert(not iomod.glob_match("test/main.rs", "src/*.rs"), "should not match wrong directory")
  end)

  it("matches recursive patterns", fun ()
    assert(iomod.glob_match("foo/bar/baz.txt", "**/*.txt"), "should match **/*.txt")
    assert(iomod.glob_match("a/b/c/d.txt", "**/*.txt"), "should match nested paths")
  end)
end)

describe("File Removal", fun ()
  it("removes file", fun ()
    # Create file
    iomod.write("test_remove.txt", "delete me")
    assert(iomod.exists("test_remove.txt"), "file should exist before removal")

    # Remove it
    iomod.remove("test_remove.txt")
    assert(not iomod.exists("test_remove.txt"), "file should not exist after removal")
  end)
end)
