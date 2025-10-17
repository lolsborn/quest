# QEP-035: Named Arguments - Error Handling

use "std/test" { module, describe, it, assert_raises, assert_eq }

module("QEP-035: Named Arguments - Errors")

describe("Positional after named error", fun ()
  it("rejects positional argument after named", fun ()
    fun greet(name, greeting)
      greeting .. ", " .. name
    end

    assert_raises(ArgErr, fun ()
      greet(name: "Alice", "Hello")
    end, "Should reject positional after named")
  end)
end)

describe("Duplicate parameter error", fun ()
  it("rejects duplicate keyword argument", fun ()
    fun greet(name, greeting)
      greeting .. ", " .. name
    end

    assert_raises(ArgErr, fun ()
      greet(name: "Alice", name: "Bob")
    end, "Should reject duplicate keyword arg")
  end)

  it("rejects positional and keyword for same param", fun ()
    fun greet(name, greeting)
      greeting .. ", " .. name
    end

    assert_raises(ArgErr, fun ()
      greet("Alice", name: "Bob")
    end, "Should reject param specified both ways")
  end)
end)

describe("Unknown keyword arguments", fun ()
  it("rejects unknown keyword arg", fun ()
    fun add(x, y)
      x + y
    end

    assert_raises(ArgErr, fun ()
      add(a: 5, b: 3)
    end, "Should reject unknown keyword args")
  end)

  it("accepts unknown kwargs when function has **kwargs", fun ()
    fun test_func(a, **options)
      a
    end

    let result = test_func(a: 10, unknown: 42, another: "test")
    assert_eq(result, 10)
  end)
end)

describe("Missing required parameters", fun ()
  it("rejects missing required param", fun ()
    fun greet(name, greeting)
      greeting .. ", " .. name
    end

    assert_raises(ArgErr, fun ()
      greet(greeting: "Hello")
    end, "Should require all params")
  end)

  it("rejects missing first param", fun ()
    fun add_three(a, b, c)
      a + b + c
    end

    assert_raises(ArgErr, fun ()
      add_three(b: 2, c: 3)
    end, "Should require first param")
  end)
end)

describe("Type errors with named args", fun ()
  it("type checks named arguments", fun ()
    fun add(x: Int, y: Int)
      x + y
    end

    assert_raises(TypeErr, fun ()
      add(x: "hello", y: 3)
    end, "Should type check named args")
  end)

  it("type checks mixed positional and named", fun ()
    fun greet(name: str, greeting: str = "Hello")
      greeting .. ", " .. name
    end

    assert_raises(TypeErr, fun ()
      greet(42, greeting: "Hi")
    end, "Should type check positional args")
  end)
end)
