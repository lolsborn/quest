# QEP-037: Typed Exception System Tests

use "std/test" {module, describe, it, assert_eq, assert, assert_type}

module("QEP-037: Typed Exception System")

describe("Exception type creation", fun ()
  it("creates Err exception", fun ()
    let e = Err.new("generic error")
    assert_eq(e.type(), Err)
    assert_eq(e.message(), "generic error")
  end)

  it("creates IndexErr exception", fun ()
    let e = IndexErr.new("index out of bounds")
    assert_eq(e.type(), IndexErr)
    assert_eq(e.message(), "index out of bounds")
  end)

  it("creates TypeErr exception", fun ()
    let e = TypeErr.new("type mismatch")
    assert_eq(e.type(), TypeErr)
  end)

  it("creates ValueErr exception", fun ()
    let e = ValueErr.new("invalid value")
    assert_eq(e.type(), ValueErr)
  end)

  it("creates ArgErr exception", fun ()
    let e = ArgErr.new("wrong number of arguments")
    assert_eq(e.type(), ArgErr)
  end)

  it("creates AttrErr exception", fun ()
    let e = AttrErr.new("no such attribute")
    assert_eq(e.type(), AttrErr)
  end)

  it("creates NameErr exception", fun ()
    let e = NameErr.new("name not found")
    assert_eq(e.type(), NameErr)
  end)

  it("creates RuntimeErr exception", fun ()
    let e = RuntimeErr.new("runtime error")
    assert_eq(e.type(), RuntimeErr)
  end)

  it("creates IOErr exception", fun ()
    let e = IOErr.new("file not found")
    assert_eq(e.type(), IOErr)
  end)

  it("creates ImportErr exception", fun ()
    let e = ImportErr.new("module not found")
    assert_eq(e.type(), ImportErr)
  end)

  it("creates KeyErr exception", fun ()
    let e = KeyErr.new("key not found")
    assert_eq(e.type(), KeyErr)
  end)
end)

describe("Exception raising and catching", fun ()
  it("raises and catches specific exception type", fun ()
    let caught = false
    let caught_msg = nil
    try
      raise IndexErr.new("test error")
    catch e: IndexErr
      caught = true
      caught_msg = e.message()
    end
    assert(caught, "Should catch IndexErr")
    assert_eq(caught_msg, "test error")  end)

  it("catches IndexErr with Err base type", fun ()
    let caught = false
    let caught_type = nil
    try
      raise IndexErr.new("test")
    catch e: Err
      caught = true
      caught_type = e.type()
    end
    assert(caught, "Should catch IndexErr via Err")
    assert_eq(caught_type, IndexErr)
  end)

  it("catches TypeErr with Err base type", fun ()
    let caught = false
    try
      raise TypeErr.new("test")
    catch e: Err
      caught = true
    end
    assert(caught, "Should catch TypeErr via Err")
  end)

  it("does not catch wrong exception type", fun ()
    let caught_index = false
    let caught_type = false
    try
      raise TypeErr.new("test")
    catch e: IndexErr
      caught_index = true
    catch e: TypeErr
      caught_type = true
    catch e: Err
      # Catch all to prevent uncaught exception
    end
    assert(not caught_index, "Should not catch as IndexErr")
    assert(caught_type, "Should catch as TypeErr")
  end)

  it("catches most specific type first", fun ()
    let which = nil
    try
      raise IndexErr.new("test")
    catch e: IndexErr
      which = "specific"
    catch e: Err
      which = "general"
    end
    assert_eq(which, "specific")
  end)

  it("falls through to general catch", fun ()
    let which = nil
    try
      raise ValueErr.new("test")
    catch e: IndexErr
      which = "specific"
    catch e: Err
      which = "general"
    end
    assert_eq(which, "general")
  end)
end)

describe("Exception object methods", fun ()
  it("has exc_type method", fun ()
    let e = IndexErr.new("test")
    assert_eq(e.type(), IndexErr)
  end)

  it("has message method", fun ()
    let e = IndexErr.new("my message")
    assert_eq(e.message(), "my message")
  end)

  it("has _str method", fun ()
    let e = IndexErr.new("test")
    assert_eq(e.str(), "IndexErr: test")
  end)
end)

describe("Backwards compatibility", fun ()
  it("still allows string-based raise (as RuntimeErr)", fun ()
    let caught = false
    let caught_type = nil
    try
      raise "string error"
    catch e
      caught = true
      caught_type = e.type()
    end
    assert(caught, "Should catch string-based error")
    assert_eq(caught_type, RuntimeErr, "String errors become RuntimeErr")
  end)

  it("catches string errors with Err base type", fun ()
    let caught = false
    try
      raise "test"
    catch e: Err
      caught = true
    end
    assert(caught, "Should catch string error via Err")
  end)
end)
