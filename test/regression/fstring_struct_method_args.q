use "std/test" { module, describe, it, assert_eq }

module("F-String Inline Arguments to Struct Methods")

type TestStruct
  name: Str
  last_msg = nil

  fun store_msg(msg)
    self.last_msg = msg
  end

  fun get_last()
    return self.last_msg
  end
end

describe("Inline f-strings as struct method arguments", fun ()
  it("should work with simple f-string", fun ()
    let obj = TestStruct.new(name: "test")
    let x = "hello"

    # This should work but currently fails
    obj.store_msg(f"Value: {x}")

    assert_eq(obj.get_last(), "Value: hello")
  end)

  it("should work with multi-variable f-string", fun ()
    let obj = TestStruct.new(name: "test")
    let x = "Alice"
    let y = "Bob"

    obj.store_msg(f"{x} and {y}")

    assert_eq(obj.get_last(), "Alice and Bob")
  end)

  it("should work when assigned to variable first (baseline)", fun ()
    let obj = TestStruct.new(name: "test")
    let x = "hello"
    let msg = f"Value: {x}"

    obj.store_msg(msg)

    assert_eq(obj.get_last(), "Value: hello")
  end)

  it("should work with string concatenation (baseline)", fun ()
    let obj = TestStruct.new(name: "test")
    let x = "hello"

    obj.store_msg("Value: " .. x)

    assert_eq(obj.get_last(), "Value: hello")
  end)

  it("should work with nested method calls", fun ()
    let obj1 = TestStruct.new(name: "obj1")
    let obj2 = TestStruct.new(name: "obj2")
    let x = "data"

    obj1.store_msg(f"First: {x}")
    obj2.store_msg(obj1.get_last())

    assert_eq(obj2.get_last(), "First: data")
  end)

  it("should work with multiple arguments including f-string", fun ()
    type MultiArgStruct
      fun concat_three(a, b, c)
        return a .. " | " .. b .. " | " .. c
      end
    end

    let obj = MultiArgStruct.new()
    let x = "middle"

    let result = obj.concat_three("first", f"the {x}", "last")

    assert_eq(result, "first | the middle | last")
  end)
end)

describe("Regular functions with inline f-strings (should already work)", fun ()
  fun regular_func(msg)
    return "Got: " .. msg
  end

  it("should work with regular function", fun ()
    let x = "test"
    let result = regular_func(f"Value: {x}")
    assert_eq(result, "Got: Value: test")
  end)
end)
