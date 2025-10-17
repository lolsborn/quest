# QEP-033: Default Parameter Values - Error Cases

use "std/test" { module, describe, it, assert_raises, assert_eq }

module("Default Parameters - Error Cases")

describe("Argument count validation", fun ()
  it("rejects too few arguments", fun ()
    fun needs_two(a, b, c = 3)
      a + b + c
    end

    assert_raises(ArgErr, fun () needs_two(1) end, "Should require at least 2 args")
  end)

  it("rejects too many arguments", fun ()
    fun takes_three(a, b = 2, c = 3)
      a + b + c
    end

    assert_raises(ArgErr, fun () takes_three(1, 2, 3, 4) end, "Should reject 4 args when max is 3")
  end)

  it("allows exactly the right number of args", fun ()
    fun takes_two(a, b = 2)
      a + b
    end

    assert_eq(takes_two(5), 7, "Should work with 1 arg")
    assert_eq(takes_two(5, 10), 15, "Should work with 2 args")
  end)
end)

describe("Runtime errors in defaults", fun ()
  it("propagates errors from default evaluation", fun ()
    fun divide_default(x, y = 10 / 0)
      x + y
    end

    assert_raises(RuntimeErr, fun () divide_default(5) end, "Should propagate division by zero")
  end)

  it("propagates errors from method calls in defaults", fun ()
    fun get_first(arr = [].get(0))
      arr
    end

    assert_raises(RuntimeErr, fun () get_first() end, "Should propagate index error")
  end)
end)

describe("Type errors (when types are specified)", fun ()
  it("works when default matches type", fun ()
    fun typed(x: Int = 10)
      x + 5
    end

    assert_eq(typed(), 15)
    assert_eq(typed(20), 25)
  end)

  it("works with complex type expressions", fun ()
    fun with_array(arr: array = [1, 2, 3])
      arr.len()
    end

    assert_eq(with_array(), 3)
  end)
end)
