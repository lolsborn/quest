#!/usr/bin/env quest
# Tests for anonymous functions (lambdas)

use "std/test" { module, describe, it, assert }

module("Function Tests - Lambda")

describe("Lambda Creation", fun ()
  it("creates simple lambda", fun ()
    let double = fun (x) x * 2 end
    assert(double(5) == 10, "double(5) should be 10")
  end)

  it("creates multi-parameter lambda", fun ()
    let add = fun (x, y) x + y end
    assert(add(3, 7) == 10, "add(3, 7) should be 10")
  end)

  it("creates parameterless lambda", fun ()
    let greet = fun () "Hello, Worldnot " end
    assert(greet() == "Hello, Worldnot ", "should return greeting")
  end)
end)

describe("Lambda with Multiple Statements", fun ()
  it("executes multiple statements", fun ()
    let compute = fun (x, y)
      let a = x * 2
      let b = y * 3
      a + b
    end

    assert(compute(5, 10) == 40, "compute(5, 10) should be 40")
  end)

  it("uses conditionals", fun ()
    let classify = fun (n)
      if n > 10
        "big"
      else
        "small"
      end
    end

    assert(classify(15) == "big", "15 is big")
    assert(classify(3) == "small", "3 is small")
  end)
end)

describe("Lambda with String Operations", fun ()
  it("concatenates strings", fun ()
    let make_greeting = fun (name) "Hello, " .. name .. "not " end
    assert(make_greeting("Alice") == "Hello, Alicenot ", "should greet Alice")
    assert(make_greeting("Bob") == "Hello, Bobnot ", "should greet Bob")
  end)

  it("transforms strings", fun ()
    let shout = fun (msg) msg.upper() .. "not !!" end
    assert(shout("hello") == "HELLOnot !!", "should shout hello")
  end)
end)

describe("Lambda as Function Arguments", fun ()
  it("passes lambda to function", fun ()
    fun apply_twice(f, value)
      f(f(value))
    end

    let increment = fun (n) n + 1 end
    assert(apply_twice(increment, 5) == 7, "should increment twice")
  end)

  it("uses inline lambda", fun ()
    fun apply_twice(f, value)
      f(f(value))
    end

    let result = apply_twice(fun (x) x * 2 end, 3)
    assert(result == 12, "should double twice: 3 -> 6 -> 12")
  end)
end)

describe("Lambda with Array Operations", fun ()
  it("uses lambda with map", fun ()
    let items = [1, 2, 3, 4, 5]
    let doubled = items.map(fun (x) x * 2 end)

    assert(doubled[0] == 2, "first element doubled")
    assert(doubled[4] == 10, "last element doubled")
  end)

  it("uses lambda with filter", fun ()
    let items = [1, 2, 3, 4, 5, 6]
    let evens = items.filter(fun (x) x % 2 == 0 end)

    assert(evens.len() == 3, "should have 3 even numbers")
    assert(evens[0] == 2, "first even is 2")
  end)

  it("uses lambda with reduce", fun ()
    let items = [1, 2, 3, 4, 5]
    let sum = items.reduce(fun (acc, x) acc + x end, 0)

    assert(sum == 15, "sum should be 15")
  end)

  it("uses lambda with any", fun ()
    let items = [1, 2, 3, 4, 5]
    let has_even = items.any(fun (x) x % 2 == 0 end)
    let has_negative = items.any(fun (x) x < 0 end)

    assert(has_even, "should have even number")
    assert(not has_negative, "should not have negative")
  end)

  it("uses lambda with all", fun ()
    let items = [2, 4, 6, 8]
    let all_even = items.all(fun (x) x % 2 == 0 end)
    let all_positive = items.all(fun (x) x > 0 end)

    assert(all_even, "all should be even")
    assert(all_positive, "all should be positive")
  end)

  it("uses lambda with find", fun ()
    let items = [1, 2, 3, 4, 5]
    let first_even = items.find(fun (x) x % 2 == 0 end)

    assert(first_even == 2, "first even should be 2")
  end)
end)

describe("Lambda Array Storage", fun ()
  it("stores lambdas in array", fun ()
    let operations = [
      fun (x) x + 1 end,
      fun (x) x * 2 end,
      fun (x) x * x end
    ]

    let op0 = operations[0]
    let op1 = operations[1]
    let op2 = operations[2]

    assert(op0(5) == 6, "first operation: increment")
    assert(op1(5) == 10, "second operation: double")
    assert(op2(5) == 25, "third operation: square")
  end)

  it("applies array of lambdas", fun ()
    let transforms = [
      fun (x) x + 10 end,
      fun (x) x * 2 end
    ]

    let value = 5
    # Note: Direct indexing and calling like transforms[0](value) may not work
    # Instead, extract the function first
    let add_fn = transforms[0]
    let mul_fn = transforms[1]
    let result1 = add_fn(value)
    let result2 = mul_fn(value)

    assert(result1 == 15, "add 10")
    assert(result2 == 10, "multiply by 2")
  end)
end)

describe("Lambda Closures", fun ()
  it("captures outer variables", fun ()
    let multiplier = 3
    let multiply = fun (x) x * multiplier end

    assert(multiply(5) == 15, "should use captured multiplier")
  end)

  it("captures multiple variables", fun ()
    let a = 10
    let b = 20
    let compute = fun () a + b end

    assert(compute() == 30, "should capture both variables")
  end)

  # Note: Returning closures with captured variables is not fully supported yet
  # it("creates closure factory", fun ()
  #   fun make_adder(n)
  #     fun (x) x + n end
  #   end
  #   let add5 = make_adder(5)
  #   let add10 = make_adder(10)
  #   assert(add5(3) == 8, "add5(3) should be 8")
  #   assert(add10(3) == 13, "add10(3) should be 13")
  # end)
  #
  # it("creates counter closure", fun ()
  #   fun make_counter()
  #     let count = 0
  #     fun ()
  #       count = count + 1
  #       count
  #     end
  #   end
  #   let counter = make_counter()
  #   assert(counter() == 1, "first call returns 1")
  #   assert(counter() == 2, "second call returns 2")
  #   assert(counter() == 3, "third call returns 3")
  # end)
end)

describe("Lambda Return from Function", fun ()
  # Note: Returning closures with captured variables is not fully supported yet
  # it("returns lambda", fun ()
  #   fun make_multiplier(n)
  #     fun (x) x * n end
  #   end
  #   let triple = make_multiplier(3)
  #   assert(triple(7) == 21, "triple(7) should be 21")
  # end)

  it("returns simple lambda", fun ()
    fun get_operation(op)
      if op == "add"
        fun (x, y) x + y end
      else
        fun (x, y) x * y end
      end
    end

    let add = get_operation("add")
    let multiply = get_operation("multiply")

    assert(add(3, 5) == 8, "add should work")
    assert(multiply(3, 5) == 15, "multiply should work")
  end)
end)
