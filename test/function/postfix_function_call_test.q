#!/usr/bin/env quest
# Tests for postfix function calls: f(x)(), array[i](), dict[key]()

use "std/test" { module, describe, it, assert }

module("Function Tests - Postfix Calls")

describe("Direct Function Call Expressions", fun ()
  it("calls result of function expression", fun ()
    let f = fun () fun (x) x * 2 end end
    let result = f()(5)
    assert(result == 10, "f()(5) should return 10")
  end)

  it("chains multiple function calls", fun ()
    let get_fn = fun () fun (x) x + 1 end end
    let result = get_fn()(10)
    assert(result == 11, "get_fn()(10) should return 11")
  end)

  it("calls function with parameters", fun ()
    let make_adder = fun (n) fun (x) x + n end end
    let result = make_adder(5)(10)
    assert(result == 15, "make_adder(5)(10) should return 15")
  end)
end)

describe("Array Indexed Function Calls", fun ()
  it("calls function stored in array by index", fun ()
    let handlers = [
      fun (x) x * 2 end,
      fun (x) x + 10 end
    ]

    let result1 = handlers[0](5)
    let result2 = handlers[1](5)

    assert(result1 == 10, "handlers[0](5) should be 10")
    assert(result2 == 15, "handlers[1](5) should be 15")
  end)

  it("calls function with multiple arguments", fun ()
    let operations = [
      fun (a, b) a + b end,
      fun (a, b) a * b end
    ]

    let sum = operations[0](3, 7)
    let product = operations[1](3, 7)

    assert(sum == 10, "operations[0](3, 7) should be 10")
    assert(product == 21, "operations[1](3, 7) should be 21")
  end)

  it("calls function with named arguments", fun ()
    let handlers = [
      fun (x: Int, y: Int) x - y end
    ]

    let result = handlers[0](x: 10, y: 3)
    assert(result == 7, "handlers[0](x: 10, y: 3) should be 7")
  end)

  it("calls function stored in nested array", fun ()
    let matrix = [
      [fun (x) x + 1 end, fun (x) x + 2 end],
      [fun (x) x * 10 end, fun (x) x * 20 end]
    ]

    let f1 = matrix[0][0](5)
    let f2 = matrix[0][1](5)
    let f3 = matrix[1][0](5)
    let f4 = matrix[1][1](5)

    assert(f1 == 6, "matrix[0][0](5) should be 6")
    assert(f2 == 7, "matrix[0][1](5) should be 7")
    assert(f3 == 50, "matrix[1][0](5) should be 50")
    assert(f4 == 100, "matrix[1][1](5) should be 100")
  end)

  it("calls functions from array of varying types", fun ()
    let tests = [
      fun () 42 end,
      fun (x) x + 100 end,
      fun (a, b) a * b end
    ]

    let r1 = tests[0]()
    let r2 = tests[1](7)
    let r3 = tests[2](3, 4)

    assert(r1 == 42, "tests[0]() should be 42")
    assert(r2 == 107, "tests[1](7) should be 107")
    assert(r3 == 12, "tests[2](3, 4) should be 12")
  end)
end)

describe("Dict Indexed Function Calls", fun ()
  it("calls function stored in dict", fun ()
    let methods = {
      double: fun (x) x * 2 end,
      square: fun (x) x * x end
    }

    let result1 = methods["double"](5)
    let result2 = methods["square"](5)

    assert(result1 == 10, "methods[\"double\"](5) should be 10")
    assert(result2 == 25, "methods[\"square\"](5) should be 25")
  end)

  it("calls method via symbol key", fun ()
    let ops = {}
    ops["add"] = fun (a, b) a + b end
    ops["multiply"] = fun (a, b) a * b end

    let r1 = ops["add"](4, 5)
    let r2 = ops["multiply"](4, 5)

    assert(r1 == 9, "ops[\"add\"](4, 5) should be 9")
    assert(r2 == 20, "ops[\"multiply\"](4, 5) should be 20")
  end)

  it("calls nested dict functions", fun ()
    let services = {
      math: {
        add: fun (a, b) a + b end,
        sub: fun (a, b) a - b end
      },
      string: {
        concat: fun (a, b) a .. b end
      }
    }

    let r1 = services["math"]["add"](10, 3)
    let r2 = services["math"]["sub"](10, 3)
    let r3 = services["string"]["concat"]("hello", " world")

    assert(r1 == 13, "services[\"math\"][\"add\"](10, 3) should be 13")
    assert(r2 == 7, "services[\"math\"][\"sub\"](10, 3) should be 7")
    assert(r3 == "hello world", "services[\"string\"][\"concat\"] should concat")
  end)

  it("calls function with multiple named arguments", fun ()
    let handlers = {}
    handlers["process"] = fun (x: Int, y: Int, z: Int) x + y * z end

    let result = handlers["process"](x: 2, y: 3, z: 4)
    assert(result == 14, "handlers[\"process\"](x: 2, y: 3, z: 4) should be 14")
  end)
end)

describe("Mixed Array and Dict Access", fun ()
  it("calls function from array within dict", fun ()
    let container = {
      operations: [
        fun (x) x * 2 end,
        fun (x) x * 3 end
      ]
    }

    let r1 = container["operations"][0](7)
    let r2 = container["operations"][1](7)

    assert(r1 == 14, "container[\"operations\"][0](7) should be 14")
    assert(r2 == 21, "container[\"operations\"][1](7) should be 21")
  end)

  it("calls function from dict within array", fun ()
    let items = [
      { fn: fun (x) x + 100 end },
      { fn: fun (x) x * 100 end }
    ]

    let r1 = items[0]["fn"](5)
    let r2 = items[1]["fn"](5)

    assert(r1 == 105, "items[0][\"fn\"](5) should be 105")
    assert(r2 == 500, "items[1][\"fn\"](5) should be 500")
  end)

  it("deeply nested structure access and calls", fun ()
    let data = {
      layers: [
        { handlers: { process: fun (x) x + 1 end } },
        { handlers: { process: fun (x) x * 10 end } }
      ]
    }

    let r1 = data["layers"][0]["handlers"]["process"](5)
    let r2 = data["layers"][1]["handlers"]["process"](5)

    assert(r1 == 6, "nested access and call should be 6")
    assert(r2 == 50, "nested access and call should be 50")
  end)
end)

describe("Function Call Results Used in Expressions", fun ()
  it("uses result of indexed function call in arithmetic", fun ()
    let calcs = [
      fun () 10 end,
      fun () 5 end
    ]

    let sum = calcs[0]() + calcs[1]()
    assert(sum == 15, "calcs[0]() + calcs[1]() should be 15")
  end)

  it("chains indexed function calls", fun ()
    let transforms = [
      fun (x) x + 1 end,
      fun (x) x * 2 end
    ]

    let result = transforms[1](transforms[0](5))
    assert(result == 12, "transforms[1](transforms[0](5)) should be 12")
  end)

  it("uses indexed function calls in conditionals", fun ()
    let checkers = {
      is_positive: fun (x) x > 0 end,
      is_even: fun (x) x % 2 == 0 end
    }

    let pos = false
    let even = false

    if checkers["is_positive"](5)
      pos = true
    end

    if checkers["is_even"](4)
      even = true
    end

    assert(pos, "is_positive(5) should be true")
    assert(even, "is_even(4) should be true")
  end)
end)

describe("Function Calls with Variable Arguments", fun ()
  it("calls function with varargs from array", fun ()
    let handlers = [
      fun (*args) args.len() end,
      fun (*args) args.reduce(fun (a, b) a + b end, 0) end
    ]

    let len_result = handlers[0](1, 2, 3, 4)
    let sum_result = handlers[1](1, 2, 3, 4)

    assert(len_result == 4, "handlers[0](1, 2, 3, 4) length should be 4")
    assert(sum_result == 10, "handlers[1](1, 2, 3, 4) sum should be 10")
  end)

  it("calls function with kwargs from dict", fun ()
    let factories = {
      builder: fun (name: Str) name end
    }

    let result = factories["builder"](name: "test")
    assert(result == "test", "factories[\"builder\"](name: \"test\") should work")
  end)
end)

describe("Edge Cases and Complex Scenarios", fun ()
  it("returns function from function call and calls it immediately", fun ()
    let factory = fun () fun (x) x * 2 end end
    let result = factory()(10)
    assert(result == 20, "factory()(10) should be 20")
  end)

  it("stores and calls function expressions", fun ()
    let f = (fun (x) fun (y) x + y end end)(5)
    let result = f(3)
    assert(result == 8, "partial application should work")
  end)

  it("handles empty parameter lists", fun ()
    let factories = [
      fun () "result1" end,
      fun () "result2" end
    ]

    let r1 = factories[0]()
    let r2 = factories[1]()

    assert(r1 == "result1", "factories[0]() should return result1")
    assert(r2 == "result2", "factories[1]() should return result2")
  end)

  it("mixes positional and keyword arguments in indexed calls", fun ()
    let handlers = {
      compute: fun (a, b, c: Int) a + b + c end
    }

    let result = handlers["compute"](10, 20, c: 30)
    assert(result == 60, "mixed args should work")
  end)

  it("calls stored method with complex return type", fun ()
    let ops = [
      fun (x) {value: x * 2} end,
      fun (x) [x, x * 2] end
    ]

    let dict_result = ops[0](5)
    let array_result = ops[1](5)

    assert(dict_result["value"] == 10, "dict result should be correct")
    assert(array_result[0] == 5, "array result element 0 should be 5")
    assert(array_result[1] == 10, "array result element 1 should be 10")
  end)
end)
