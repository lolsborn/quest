use "std/test" {it, describe, module, assert_eq, assert}

module("Built-in Functions - chr and ord")

describe("chr() - codepoint to character", fun ()
  it("converts ASCII codepoints", fun ()
    assert_eq(chr(65), "A")
    assert_eq(chr(90), "Z")
    assert_eq(chr(97), "a")
    assert_eq(chr(122), "z")
  end)

  it("converts digits", fun ()
    assert_eq(chr(48), "0")
    assert_eq(chr(57), "9")
  end)

  it("converts special characters", fun ()
    assert_eq(chr(32), " ")
    assert_eq(chr(33), "!")
    assert_eq(chr(64), "@")
  end)

  it("converts Unicode characters", fun ()
    assert_eq(chr(8364), "€")  # Euro sign
    assert_eq(chr(9731), "☃")  # Snowman
    assert_eq(chr(128077), "👍")  # Thumbs up
  end)

  it("handles low codepoints", fun ()
    assert_eq(chr(0).len(), 1)  # Null byte exists
    assert_eq(chr(10), "\n")
    assert_eq(chr(13), "\r")
    assert_eq(chr(9), "\t")
  end)

  it("raises error on invalid codepoint", fun ()
    try
      chr(0xFFFFFFFF)  # Invalid Unicode
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)

  it("works with floats", fun ()
    assert_eq(chr(65.7), "A")  # Truncates to 65
  end)
end)

describe("ord() - character to codepoint", fun ()
  it("converts ASCII characters", fun ()
    assert_eq(ord("A"), 65)
    assert_eq(ord("Z"), 90)
    assert_eq(ord("a"), 97)
    assert_eq(ord("z"), 122)
  end)

  it("converts digits", fun ()
    assert_eq(ord("0"), 48)
    assert_eq(ord("9"), 57)
  end)

  it("converts special characters", fun ()
    assert_eq(ord(" "), 32)
    assert_eq(ord("!"), 33)
    assert_eq(ord("@"), 64)
  end)

  it("converts Unicode characters", fun ()
    assert_eq(ord("€"), 8364)  # Euro sign
    assert_eq(ord("☃"), 9731)  # Snowman
    assert_eq(ord("👍"), 128077)  # Thumbs up
  end)

  it("takes first character of multi-char string", fun ()
    assert_eq(ord("Hello"), 72)  # H
    assert_eq(ord("ABC"), 65)  # A
  end)

  it("raises error on empty string", fun ()
    try
      ord("")
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("String.ord() method", fun ()
  it("works as method on string", fun ()
    assert_eq("A".ord(), 65)
    assert_eq("Z".ord(), 90)
  end)

  it("handles Unicode", fun ()
    assert_eq("€".ord(), 8364)
    assert_eq("👍".ord(), 128077)
  end)

  it("takes first character", fun ()
    assert_eq("Hello".ord(), 72)
  end)

  it("raises error on empty string", fun ()
    try
      "".ord()
      assert(false, "Should have raised exception")
    catch e
      assert(true)    end
  end)
end)

describe("chr and ord roundtrip", fun ()
  it("roundtrips ASCII", fun ()
    assert_eq(chr(ord("A")), "A")
    assert_eq(chr(ord("z")), "z")
    assert_eq(ord(chr(65)), 65)
    assert_eq(ord(chr(122)), 122)
  end)

  it("roundtrips Unicode", fun ()
    assert_eq(chr(ord("€")), "€")
    assert_eq(chr(ord("👍")), "👍")
    assert_eq(ord(chr(8364)), 8364)
  end)

  it("roundtrips using method syntax", fun ()
    assert_eq(chr("A".ord()), "A")
    assert_eq(chr(65).ord(), 65)
  end)
end)

describe("Real-world use cases", fun ()
  it("builds string from codepoints", fun ()
    let msg = chr(72) .. chr(101) .. chr(108) .. chr(108) .. chr(111)
    assert_eq(msg, "Hello")  end)

  it("gets codepoint range", fun ()
    let a_code = "A".ord()
    let z_code = "Z".ord()
    assert_eq(z_code - a_code, 25)  # 26 letters, 0-indexed
  end)

  it("shifts characters", fun ()
    # Simple Caesar cipher
    let shifted = chr("A".ord() + 3)
    assert_eq(shifted, "D")  end)

  it("checks character ranges", fun ()
    let ch = "M"
    let code = ch.ord()
    let is_uppercase = code >= 65 and code <= 90
    assert(is_uppercase)  end)

  it("converts case manually", fun ()
    # Uppercase to lowercase (add 32)
    let upper = "A"
    let lower = chr(upper.ord() + 32)
    assert_eq(lower, "a")  end)
end)
