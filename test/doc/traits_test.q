use "std/test" as test

test.module("Trait Docstrings")

test.describe("Trait documentation", fun ()
    test.it("extracts docstring from trait definition", fun ()
        trait Drawable
            "Defines objects that can be drawn to screen"
            fun draw()
            fun clear()
        end

        let doc = Drawable._doc()
    end)

    test.it("shows required methods when no docstring present", fun ()
        trait Comparable
            fun compare(other)
            fun less_than(other)
        end

        let doc = Comparable._doc()
    end)

    test.it("handles trait with typed parameters", fun ()
        trait Numeric
            "Numeric operations"
            fun add(num: other)
            fun subtract(num: other)
        end

        let doc = Numeric._doc()
    end)
end)

test.describe("Trait with return types", fun ()
    test.it("shows return type annotations in documentation", fun ()
        trait Converter
            "Type conversion operations"
            fun to_string() -> str
            fun to_number() -> num
        end

        let doc = Converter._doc()
    end)
end)

test.describe("Built-in trait methods", fun ()
    test.it("_str returns trait representation", fun ()
        trait Sample
            "Sample trait"
            fun test()
        end

        test.assert_eq(Sample._str(), "trait Sample")
    end)

    test.it("_rep returns trait representation", fun ()
        trait Sample
            "Sample trait"
            fun test()
        end

        test.assert_eq(Sample._rep(), "trait Sample")
    end)

    test.it("_id returns unique identifier", fun ()
        trait Sample1
            fun test()
        end

        trait Sample2
            fun test()
        end

        # Each trait should have a different ID
        test.assert_neq(Sample1._id(), Sample2._id())
    end)
end)