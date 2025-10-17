# Exception Variable Scoping Tests
# Tests that exception variables in catch blocks are properly scoped

use "std/test" {module, describe, it, assert_eq, assert, assert_type}

module("Exception Variable Scoping")

describe("Catch variable scoping", fun ()
  it("allows reusing same exception variable name in multiple catch blocks", fun ()
    let first_msg = nil
    let second_msg = nil

    try
      raise "first error"
    catch e
      first_msg = e.message()
    end

    try
      raise "second error"
    catch e
      second_msg = e.message()
    end

    assert_eq(first_msg, "first error", "First catch should capture first error")
    assert_eq(second_msg, "second error", "Second catch should capture second error")
  end)

  it("exception variable does not leak outside catch block", fun ()
    try
      raise "test error"
    catch exc
      assert_eq(exc.message(), "test error", "Exception should be accessible in catch")
    end

    # Try to access exc outside catch - should fail
    let error_caught = false
    try
      let msg = exc.message()
    catch e
      error_caught = true
    end

    assert(error_caught, "Exception variable should not be accessible outside catch block")
  end)

  it("supports nested try/catch with same variable name", fun ()
    let inner_msg = nil
    let outer_msg = nil

    try
      try
        raise "inner error"
      catch e
        inner_msg = e.message()
        raise "outer error"
      end
    catch e
      outer_msg = e.message()
    end

    assert_eq(inner_msg, "inner error", "Inner catch should get inner error")
    assert_eq(outer_msg, "outer error", "Outer catch should get outer error")
  end)

  it("allows different exception variable names", fun ()
    let err_msg = nil
    let ex_msg = nil
    let exception_msg = nil

    try
      raise "error1"
    catch err
      err_msg = err.message()
    end

    try
      raise "error2"
    catch ex
      ex_msg = ex.message()
    end

    try
      raise "error3"
    catch exception
      exception_msg = exception.message()
    end

    assert_eq(err_msg, "error1", "Should work with 'err'")
    assert_eq(ex_msg, "error2", "Should work with 'ex'")
    assert_eq(exception_msg, "error3", "Should work with 'exception'")
  end)

  it("exception variable is scoped even if catch throws", fun ()
    let caught_inner = false
    let caught_outer = false

    try
      try
        raise "inner"
      catch e
        caught_inner = true
        raise "outer from catch"
      end
    catch e
      caught_outer = true
      assert_eq(e.message(), "outer from catch", "Outer should get re-raised error")
    end

    assert(caught_inner, "Inner catch should execute")
    assert(caught_outer, "Outer catch should execute")
  end)

  it("exception variable accessible throughout catch block", fun ()
    let msg1 = nil
    let msg2 = nil
    let msg3 = nil

    try
      raise "test"
    catch e
      msg1 = e.message()
      let x = 1 + 1
      msg2 = e.message()
      if true
        msg3 = e.message()
      end
    end

    assert_eq(msg1, "test", "Exception accessible at start of catch")
    assert_eq(msg2, "test", "Exception accessible in middle of catch")
    assert_eq(msg3, "test", "Exception accessible inside nested block in catch")
  end)

  it("can use same name in sequential try/catch blocks multiple times", fun ()
    let messages = []

    let i = 0
    while i < 5
      try
        raise "error " .. i.str()
      catch e
        messages.push(e.message())
      end
      i = i + 1
    end

    assert_eq(messages.len(), 5, "Should catch 5 errors")
    assert_eq(messages[0], "error 0", "First error")
    assert_eq(messages[4], "error 4", "Fifth error")
  end)
end)
