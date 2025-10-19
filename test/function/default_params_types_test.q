# QEP-033: Default Parameter Values - Type Methods

use "std/test" { module, describe, it, assert_eq, assert_raises }

module("Default Parameters - Type Methods")

describe("Instance methods with defaults", fun ()
  it("supports defaults in instance methods", fun ()
    type Person
      name: Str

      fun greet(greeting = "Hello")
        greeting .. ", " .. self.name
      end
    end

    let alice = Person.new(name: "Alice")
    assert_eq(alice.greet(), "Hello, Alice")
    assert_eq(alice.greet("Hi"), "Hi, Alice")
  end)

  it("supports multiple defaults in instance methods", fun ()
    type Counter
      value: Int = 0

      fun add(x = 1, y = 1)
        self.value = self.value + x + y
        self.value
      end
    end

    let c = Counter.new()
    assert_eq(c.add(), 2, "Should add defaults 1+1")
    assert_eq(c.add(5), 8, "Should add 5+1")
    assert_eq(c.add(10, 20), 38, "Should add 10+20")
  end)

  it("defaults can reference earlier parameters but not self", fun ()
    type Calculator
      base: Int = 0

      fun compute(x, multiplier = 2, result = x * multiplier)
        self.base + result
      end
    end

    let calc = Calculator.new(base: 10)
    assert_eq(calc.compute(5), 20, "10 + (5*2)")
    assert_eq(calc.compute(5, 3), 25, "10 + (5*3)")
    assert_eq(calc.compute(5, 3, 100), 110, "10 + 100")
  end)
end)

describe("Class methods with defaults", fun ()
  it("supports defaults in class methods", fun ()
    type Config
      fun self.create(debug = false, verbose = false)
        {debug: debug, verbose: verbose}
      end
    end

    let c1 = Config.create()
    let c2 = Config.create(true)
    let c3 = Config.create(true, true)

    assert_eq(c1.get("debug"), false)
    assert_eq(c2.get("debug"), true)
    assert_eq(c3.get("verbose"), true)
  end)

  it("defaults in class factory methods", fun ()
    type Point
      pub x: Int
      pub y: Int

      fun self.origin(x = 0, y = 0)
        Point.new(x: x, y: y)
      end
    end

    let p1 = Point.origin()
    let p2 = Point.origin(5)
    let p3 = Point.origin(5, 10)

    assert_eq(p1.x, 0)
    assert_eq(p1.y, 0)
    assert_eq(p2.x, 5)
    assert_eq(p2.y, 0)
    assert_eq(p3.x, 5)
    assert_eq(p3.y, 10)
  end)
end)

describe("Type field defaults vs method defaults", fun ()
  it("distinguishes field defaults from method parameter defaults", fun ()
    type Container
      pub value: Int? = 100

      fun get_or_default(default_val = 50)
        if self.value == nil
          default_val
        else
          self.value
        end
      end
    end

    let c1 = Container.new()
    assert_eq(c1.value, 100, "Field should use field default")
    assert_eq(c1.get_or_default(), 100, "Should return field value")

    let c2 = Container.new(value: nil)
    assert_eq(c2.get_or_default(), 50, "Should use method default")
    assert_eq(c2.get_or_default(75), 75, "Should use explicit arg")
  end)
end)

describe("Closures captured in type methods", fun ()
  it("method defaults can access captured scope", fun ()
    let multiplier = 10

    type Calculator
      fun multiply(x, factor = multiplier)
        x * factor
      end
    end

    let calc = Calculator.new()
    assert_eq(calc.multiply(5), 50, "Should use captured multiplier")
    assert_eq(calc.multiply(5, 2), 10, "Should use explicit factor")
  end)
end)
