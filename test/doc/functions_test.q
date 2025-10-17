use "std/test" {it, describe, module, assert_eq}

module("Function Docstrings")

describe("Single-line docstrings", fun ()
  it("extracts docstring from function with single-line string", fun ()
    fun greet(name)
      "Greets a person by name"
      "Hello, " .. name
    end

    let f = greet
    assert_eq(f._doc(), "Greets a person by name")
  end)

  it("returns default doc when no docstring present", fun ()
    fun no_doc()
      42
    end

    let f = no_doc
    assert_eq(f._doc(), "User-defined function: no_doc")
  end)
end)

describe("Type methods with docstrings", fun ()
  it("type with method docstrings can be created", fun ()
    type Calculator
      "A simple calculator"
      pub value: Num

      fun add(n)
        "Adds a number to the value"
        self.value + n
      end
    end

    # Cannot directly test method docstrings since we can't get method references from instances
    # But we verify the type can be created and used
    let calc = Calculator.new(value: 10)
    assert_eq(calc.value, 10)
    assert_eq(calc.add(5), 15)
  end)
end)

describe("Anonymous functions", fun ()
  it("returns default doc for anonymous function", fun ()
    let f = fun (x) x * 2 end
    assert_eq(f._doc(), "Anonymous function")
  end)
end)