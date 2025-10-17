# Basic Exception Handling Tests
# Tests try/catch/ensure/raise functionality

use "std/test" {module, describe, it, assert_eq, assert_raises}

module("Exception Tests - Basic")

describe("Raise and Catch", fun ()
  it("catches simple string errors", fun ()
    assert_raises(RuntimeErr, fun ()
      raise "something went wrong"
    end)
  end)

  it("allows execution to continue after catch", fun ()
    let executed = false
    try
      raise "test error"
    catch e
      executed = true
    end
    assert_eq(executed, true, "Catch block should execute")
  end)

  it("does not execute catch when no error", fun ()
    let catch_ran = false
    try
      # No error
    catch e
      catch_ran = true
    end
    assert_eq(catch_ran, false, "Catch should not run without error")
  end)
end)

describe("Exception Objects", fun ()
  it("have exc_type property", fun ()
    try
      raise "test message"
    catch e
      assert_eq(e.type(), RuntimeErr, "String raises become RuntimeErr (QEP-037)")
    end
  end)

  it("have message property", fun ()
    try
      raise "hello world"
    catch e
      assert_eq(e.message(), "hello world", "Exception message should match")
    end
  end)

  it("have _str representation", fun ()
    try
      raise "test"
    catch e
      let str_repr = e.str()
      assert_eq(str_repr, "RuntimeErr: test", "String representation should be 'RuntimeErr: test'")
    end
  end)
end)

describe("Ensure Blocks", fun ()
  it("always execute after try", fun ()
    let cleanup = false
    try
      # No error
    ensure
      cleanup = true
    end
    assert_eq(cleanup, true, "Ensure should run after try")
  end)

  it("always execute even with error", fun ()
    let cleanup = false
    try
      raise "error"
    catch err
      # Caught
    ensure
      cleanup = true
    end
    assert_eq(cleanup, true, "Ensure should run after catch")
  end)

  it("execute in correct order", fun ()
    let order_correct = false

    try
      # Try block runs first
    ensure
      # Ensure block runs second
      order_correct = true
    end
    # Code after try/ensure runs third

    assert_eq(order_correct, true, "Ensure should execute before continuing")
  end)
end)

describe("Re-raising", fun ()
  it("can re-raise caught exception", fun ()
    let outer_caught = false

    try
      try
        raise "inner error"
      catch e
        # Re-raise
        raise
      end
    catch e2
      outer_caught = true
      assert_eq(e2.message(), "inner error", "Re-raised exception should have same message")
    end

    assert_eq(outer_caught, true, "Outer catch should execute")
  end)
end)
