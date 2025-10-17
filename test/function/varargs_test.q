# QEP-034 MVP: Variadic Parameters (*args) Tests

use "std/test" { module, describe, it, assert_eq, assert_raises }

module("QEP-034 MVP: Variadic Parameters")

describe("Basic *args", fun ()
  it("collects no arguments into empty array", fun ()
    fun sum(*numbers)
      let total = 0
      for n in numbers
        total = total + n
      end
      total
    end

    assert_eq(sum(), 0)
  end)

  it("collects single argument into array", fun ()
    fun sum(*numbers)
      let total = 0
      for n in numbers
        total = total + n
      end
      total
    end

    assert_eq(sum(5), 5)
  end)

  it("collects multiple arguments into array", fun ()
    fun sum(*numbers)
      let total = 0
      for n in numbers
        total = total + n
      end
      total
    end

    assert_eq(sum(1, 2, 3), 6)
    assert_eq(sum(1, 2, 3, 4, 5), 15)
  end)

  it("varargs parameter has correct length", fun ()
    fun count_args(*args)
      args.len()
    end

    assert_eq(count_args(), 0)
    assert_eq(count_args(1), 1)
    assert_eq(count_args(1, 2, 3), 3)
  end)

  it("varargs parameter is an array", fun ()
    fun get_args(*args)
      args
    end

    let result = get_args(1, 2, 3)
    assert_eq(result.len(), 3)
    assert_eq(result[0], 1)
    assert_eq(result[1], 2)
    assert_eq(result[2], 3)
  end)
end)

describe("Mixed parameters and *args", fun ()
  it("combines required param with *args", fun ()
    fun greet(greeting, *names)
      let result = greeting
      for name in names
        result = result .. " " .. name
      end
      result
    end

    assert_eq(greet("Hello"), "Hello")
    assert_eq(greet("Hello", "Alice"), "Hello Alice")
    assert_eq(greet("Hello", "Alice", "Bob"), "Hello Alice Bob")
  end)

  it("combines multiple required params with *args", fun ()
    fun printf(format, sep, *args)
      let result = format .. sep
      for arg in args
        result = result .. arg.str() .. sep
      end
      result
    end

    assert_eq(printf("Values:", " "), "Values: ")
    assert_eq(printf("Values:", " ", 1, 2, 3), "Values: 1 2 3 ")
  end)

  it("combines required and optional params with *args", fun ()
    fun connect(host, port = 8080, *extra)
      host .. ":" .. port.str() .. " extras:" .. extra.len().str()
    end

    assert_eq(connect("localhost"), "localhost:8080 extras:0")
    assert_eq(connect("localhost", 3000), "localhost:3000 extras:0")
    assert_eq(connect("localhost", 3000, "a", "b"), "localhost:3000 extras:2")
  end)
end)

describe("Lambda with *args", fun ()
  it("works with lambda expressions", fun ()
    let sum = fun (*nums)
      let total = 0
      for n in nums
        total = total + n
      end
      total
    end

    assert_eq(sum(), 0)
    assert_eq(sum(1, 2, 3), 6)
  end)

  it("lambda with mixed params", fun ()
    let multiply_and_sum = fun (factor, *nums)
      let total = 0
      for n in nums
        total = total + (n * factor)
      end
      total
    end

    assert_eq(multiply_and_sum(2), 0)
    assert_eq(multiply_and_sum(2, 1, 2, 3), 12)
  end)
end)

describe("Error handling", fun ()
  it("requires required params even with *args", fun ()
    fun f(required, *rest)
      required
    end

    assert_raises(Err, fun () f() end)
  end)

  it("rejects too few args for required params", fun ()
    fun f(a, b, *rest)
      a + b
    end

    assert_raises(Err, fun () f(1) end)
  end)
end)
