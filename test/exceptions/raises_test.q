# Test assert_raises() with exception handling

use "std/test" {module, describe, it, assert_raises, assert_eq, assert}

describe("Exception Handling", fun()
  it("catches basic string errors", fun()
    assert_raises(RuntimeErr, fun()
      raise "something went wrong"
    end)
  end)

  it("ensures block always runs", fun()
    let cleanup = false
    try
      raise "test error"
    catch exc
      # Error caught
    ensure
      cleanup = true
    end
    assert_eq(cleanup, true)  end)

  it("exception objects have exc_type property", fun()
    try
      raise "test message"
    catch ex
      assert_eq(ex.type(), RuntimeErr)
    end
  end)

  it("exception objects have message property", fun()
    try
      raise "hello world"
    catch ex
      assert_eq(ex.message(), "hello world")
    end
  end)
end)


