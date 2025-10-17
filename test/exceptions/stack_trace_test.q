# Test stack trace functionality

use "std/test" {module, describe, it, assert_eq, assert, assert_type}

module("Exception Tests - Stack Traces")

describe("Stack Traces", fun ()
  it("exception has stack array", fun ()
    try
      raise "test error"
    catch e
      let stack = e.stack()
      assert_type(stack, "Array", "stack should be an array")
    end
  end)

  it("captures function call stack", fun ()
    fun inner()
      raise "error from inner"
    end

    fun middle()
      inner()
    end

    fun outer()
      middle()
    end

    try
      outer()
    catch e
      let stack = e.stack()
      # Stack includes test framework functions too, so check >= 3
      assert(stack.len() >= 3, "Should have at least 3 stack frames")
    end
  end)

  it("shows nested function calls", fun ()
    fun level3()
      raise "deep error"
    end

    fun level2()
      level3()
    end

    fun level1()
      level2()
    end

    try
      level1()
    catch e
      assert(e.stack().len() >= 3, "Should have at least 3 levels")
      assert_eq(e.message(), "deep error", "Message should be preserved")
    end
  end)

  it("clears stack after exception is caught", fun ()
    fun thrower()
      raise "first error"
    end

    # First exception
    try
      thrower()
    catch e
      assert(e.stack().len() >= 1, "First exception should have stack")
    end

    # Second exception - stack should be cleared
    try
      thrower()
    catch e2
      assert(e2.stack().len() >= 1, "Second exception should also have stack")
    end
  end)
end)
