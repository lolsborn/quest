use "std/test"

test.module("String Quote Styles")

test.describe("Single and double quotes", fun ()
    test.it("double quotes work", fun ()
        let s = "double"
        test.assert_eq(s, "double")    end)

    test.it("single quotes work", fun ()
        let s = 'single'
        test.assert_eq(s, 'single')    end)

    test.it("single and double quotes are equivalent", fun ()
        test.assert_eq("test", 'test')    end)

    test.it("double quotes don't escape single quote", fun ()
        let s = "It's working"
        test.assert_eq(s.len(), 12)
        test.assert(s.contains("'"))
    end)

    test.it("single quotes don't escape double quote", fun ()
        let s = 'She said "hello"'
        test.assert_eq(s.len(), 16)
        test.assert(s.contains('"'))
    end)

    test.it("escaped single quote in single-quoted string", fun ()
        let s = 'It\'s Alice\'s turn'
        test.assert_eq(s, "It's Alice's turn")    end)

    test.it("escaped double quote in double-quoted string", fun ()
        let s = "She said \"hello\""
        test.assert_eq(s, 'She said "hello"')    end)
end)

test.describe("F-strings with both quotes", fun ()
    test.it("f-string with double quotes", fun ()
        let name = "Alice"
        let s = f"Hello {name}"
        test.assert_eq(s, "Hello Alice")    end)

    test.it("f-string with single quotes", fun ()
        let name = "Bob"
        let s = f'Hello {name}'
        test.assert_eq(s, "Hello Bob")    end)

    test.it("f-string single quotes with apostrophe", fun ()
        let name = "Alice"
        let s = f'It\'s {name}\'s turn'
        test.assert_eq(s, "It's Alice's turn")    end)
end)

test.describe("Bytes with both quotes", fun ()
    test.it("b-string with double quotes", fun ()
        let b = b"bytes"
        test.assert_eq(b.len(), 5)
    end)

    test.it("b-string with single quotes", fun ()
        let b = b'bytes'
        test.assert_eq(b.len(), 5)
    end)

    test.it("bytes with hex escapes and single quotes", fun ()
        let b = b'\xFF\x00\xFF'
        test.assert_eq(b.len(), 3)
        test.assert_eq(b.get(0), 255)
        test.assert_eq(b.get(1), 0)
    end)
end)

test.describe("Triple quotes", fun ()
    test.it("triple double quotes for multi-line", fun ()
        let s = """Line 1
Line 2
Line 3"""
        test.assert(s.contains("Line 1"))
        test.assert(s.contains("\n"))
    end)

    test.it("triple single quotes for multi-line", fun ()
        let s = '''Line 1
Line 2
Line 3'''
        test.assert(s.contains("Line 1"))
        test.assert(s.contains("\n"))
    end)
end)

test.describe("Escape sequences", fun ()
    test.it("processes newline escape", fun ()
        let s = 'Hello\nWorld'
        test.assert(s.contains("\n"))
        test.assert_eq(s.len(), 11)
    end)

    test.it("processes tab escape", fun ()
        let s = "Col1\tCol2"
        test.assert(s.contains("\t"))
    end)

    test.it("processes backslash escape", fun ()
        let s = 'C:\\path\\file'
        test.assert_eq(s, "C:\\path\\file")    end)
end)
