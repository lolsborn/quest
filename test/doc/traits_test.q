use "std/test" {it, describe, module, assert_eq, assert_neq, assert_type}

module("Trait Docstrings")

describe("Trait documentation", fun ()
  it("extracts docstring from trait definition", fun ()
    trait Drawable
      "Defines objects that can be drawn to screen"
      fun draw()
      fun clear()
    end

    let doc = Drawable._doc()
    assert_eq(doc, "Defines objects that can be drawn to screen")
  end)

  it("shows required methods when no docstring present", fun ()
    trait Comparable
      fun compare(other)
      fun less_than(other)
    end

    let doc = Comparable._doc()
    assert_eq(doc, "Trait definition: Comparable\nRequired methods:\n  fun compare(other)\n  fun less_than(other)")
  end)

  it("handles trait with typed parameters", fun ()
    trait Numeric
      "Numeric operations"
      fun add(num: other)
      fun subtract(num: other)
    end

    let doc = Numeric._doc()
    assert_eq(doc, "Numeric operations")
  end)
end)

describe("Trait with return types", fun ()
  it("shows return type annotations in documentation", fun ()
    trait Converter
      "Type conversion operations"
      fun to_string() -> str
      fun to_number() -> num
    end

    let doc = Converter._doc()
    assert_eq(doc, "Type conversion operations")
  end)
end)

describe("Built-in trait methods", fun ()
  it("_str returns trait representation", fun ()
    trait Sample
      "Sample trait"
      fun test()
    end

    assert_eq(Sample.str(), "trait Sample")
  end)

  it("_rep returns trait representation", fun ()
    trait Sample
      "Sample trait"
      fun test()
    end

    assert_eq(Sample._rep(), "trait Sample")
  end)

  it("_id returns unique identifier", fun ()
    trait Sample1
      fun test()
    end

    trait Sample2
      fun test()
    end

    # Each trait should have a different ID
    assert_neq(Sample1._id(), Sample2._id())
  end)
end)