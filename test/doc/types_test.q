use "std/test" {it, describe, module, assert_eq, assert_neq, assert_type}

module("Type Docstrings")

describe("Type documentation", fun ()
  it("extracts docstring from type definition", fun ()
    type Person
      "Represents a person with name and age"
      name: Str
      age: Num?
    end

    let doc = Person._doc()
    assert_eq(doc, "Represents a person with name and age")
  end)

  it("shows fields when no docstring present", fun ()
    type Point
      x: Num
      y: Num
    end

    let doc = Point._doc()
    assert_eq(doc, "Type definition: Point\nFields:\n  Num: x\n  Num: y")
  end)

  it("handles types with optional fields", fun ()
    type Config
      "Configuration settings"
      name: Str
      port: Num?
      host: Str?
    end

    let doc = Config._doc()
    assert_eq(doc, "Configuration settings")
  end)
end)

describe("Type with methods", fun ()
  it("type with instance methods has documentation", fun ()
    type Counter
      "A simple counter"
      value: Num

      fun increment()
        "Increments the counter by 1"
        self.value + 1
      end
    end

    let doc = Counter._doc()
    assert_eq(doc, "A simple counter")
  end)

  it("type with static methods has documentation", fun ()
    type Factory
      "A factory for creating things"
      name: Str

      fun self.create_default()
        "Creates a default factory instance"
        Factory.new(name: "Default")
      end
    end

    let doc = Factory._doc()
    assert_eq(doc, "A factory for creating things")
  end)
end)

describe("Built-in type methods", fun ()
  it("_str returns type representation", fun ()
    type Sample
      "Sample type"
      x: Num
    end

    assert_eq(Sample.str(), "type Sample")
  end)

  it("_rep returns type representation", fun ()
    type Sample
      "Sample type"
      x: Num
    end

    assert_eq(Sample._rep(), "type Sample")
  end)

  it("_id returns unique identifier", fun ()
    type Sample1
      x: Num
    end

    type Sample2
      x: Num
    end

    # Each type should have a different ID
    assert_neq(Sample1._id(), Sample2._id())
  end)
end)