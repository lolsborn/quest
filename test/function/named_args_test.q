# QEP-035: Named Arguments for Functions

use "std/test" {  module, describe, it, assert_eq  }

module("QEP-035: Named Arguments for Functions")

describe("Basic named arguments", fun ()
  it("accepts all named arguments", fun ()
    fun greet(greeting, name)
      greeting .. ", " .. name
    end

    let result = greet(greeting: "Hello", name: "Alice")
    assert_eq(result, "Hello, Alice")
  end)

  it("accepts named arguments in any order", fun ()
    fun greet(greeting, name)
      greeting .. ", " .. name
    end

    let result = greet(name: "Alice", greeting: "Hello")
    assert_eq(result, "Hello, Alice")
  end)

  it("works with single argument", fun ()
    fun square(x)
      x * x
    end

    assert_eq(square(x: 5), 25)
  end)
end)

describe("Mixed positional and named", fun ()
  it("accepts positional then named", fun ()
    fun greet(greeting, name, punctuation)
      greeting .. ", " .. name .. punctuation
    end

    let result = greet("Hello", name: "Alice", punctuation: "!")
    assert_eq(result, "Hello, Alice!")
  end)

  it("first positional, last two named", fun ()
    fun add_three(a, b, c)
      a + b + c
    end

    assert_eq(add_three(1, b: 2, c: 3), 6)
  end)
end)

describe("With default parameters", fun ()
  it("can override defaults with named args", fun ()
    fun connect(host, port = 8080, timeout = 30)
      host .. ":" .. port.str() .. " (timeout: " .. timeout.str() .. ")"
    end

    let result = connect("localhost", timeout: 60)
    assert_eq(result, "localhost:8080 (timeout: 60)")
  end)

  it("can skip optional parameters", fun ()
    fun connect(host, port = 8080, timeout = 30, debug = false)
      let dbg_str = "prod"
      if debug
        dbg_str = "debug"
      end
      host .. ":" .. port.str() .. " [" .. dbg_str .. "]"
    end

    let result = connect("localhost", debug: true)
    assert_eq(result, "localhost:8080 [debug]")
  end)

  it("can specify middle defaults", fun ()
    fun f(a, b = 1, c = 2, d = 3)
      a + b + c + d
    end

    assert_eq(f(10, c: 5), 19)  # 10 + 1 + 5 + 3
  end)
end)

describe("With type annotations", fun ()
  it("type checks named arguments", fun ()
    fun add(x: Int, y: Int)
      x + y
    end

    assert_eq(add(x: 5, y: 3), 8)
  end)

  it("type checks mixed positional and named", fun ()
    fun greet(name: str, greeting: str = "Hello")
      greeting .. ", " .. name
    end

    assert_eq(greet("Alice"), "Hello, Alice")
    assert_eq(greet("Bob", greeting: "Hi"), "Hi, Bob")
  end)
end)
