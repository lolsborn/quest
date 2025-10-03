use "std/test" as test

test.module("String Tests - Interpolation")

test.describe("String Interpolation", fun ()

# F-strings
test.it("f-strings interpolate variables", fun ()
    let name = "Alice"
    let age = 30
    let result = f"Hello {name}, you are {age}"
    test.assert_eq(result, "Hello Alice, you are 30", nil)
end)

test.it("f-strings support format specifiers", fun ()
    let pi = 3.14159
    test.assert_eq(f"{pi:.2}", "3.14", nil)
    test.assert_eq(f"{pi:.4}", "3.1416", nil)
end)

test.it("f-strings support number formatting", fun ()
    let n = 255
    test.assert_eq(f"{n:x}", "ff", nil)
    test.assert_eq(f"{n:X}", "FF", nil)
    test.assert_eq(f"{n:b}", "11111111", nil)
    test.assert_eq(f"{n:o}", "377", nil)
    test.assert_eq(f"{n:#x}", "0xff", nil)
end)

test.it("f-strings support width and alignment", fun ()
    let x = 42
    test.assert_eq(f"{x:5}", "   42", nil)
    test.assert_eq(f"{x:<5}", "42   ", nil)
    test.assert_eq(f"{x:^5}", " 42  ", nil)
    test.assert_eq(f"{x:05}", "00042", nil)
end)

# .fmt() method
test.it(".fmt() with positional placeholders", fun ()
    let result = "Hello {}, you are {}".fmt("Bob", 25)
    test.assert_eq(result, "Hello Bob, you are 25", nil)
end)

test.it(".fmt() with explicit indices", fun ()
    let result = "{1} {0}".fmt("World", "Hello")
    test.assert_eq(result, "Hello World", nil)
end)

test.it(".fmt() with format specifiers", fun ()
    let result = "{:.2}".fmt(3.14159)
    test.assert_eq(result, "3.14", nil)

    let result2 = "{:x}".fmt(255)
    test.assert_eq(result2, "ff", nil)
end)

test.it(".fmt() with indexed format specifiers", fun ()
    let result = "{0:.2} costs ${1:.2}".fmt(3.14159, 2.5)
    test.assert_eq(result, "3.14 costs $2.50", nil)
end)

# Plain strings remain unchanged
test.it("plain strings don't interpolate", fun ()
    let template = "Hello {name}"
    test.assert_eq(template, "Hello {name}", nil)
end)

# Escaped braces
test.it("escaped braces in .fmt()", fun ()
    let result = "Use {{}} for braces".fmt()
    test.assert_eq(result, "Use {} for braces", nil)
end)

end) # end of describe block
