use "std/test" as test

test.module("Type Docstrings")

test.describe("Type documentation", fun ()
    test.it("extracts docstring from type definition", fun ()
        type Person
            "Represents a person with name and age"
            name: Str
            age: Num?
        end

        let doc = Person._doc()
    end)

    test.it("shows fields when no docstring present", fun ()
        type Point
            x: Num
            y: Num
        end

        let doc = Point._doc()
    end)

    test.it("handles types with optional fields", fun ()
        type Config
            "Configuration settings"
            name: Str
            port: Num?
            host: Str?
        end

        let doc = Config._doc()
    end)
end)

test.describe("Type with methods", fun ()
    test.it("type with instance methods has documentation", fun ()
        type Counter
            "A simple counter"
            value: Num

            fun increment()
                "Increments the counter by 1"
                self.value + 1
            end
        end

        let doc = Counter._doc()
    end)

    test.it("type with static methods has documentation", fun ()
        type Factory
            "A factory for creating things"
            name: Str

            static fun create_default()
                "Creates a default factory instance"
                Factory.new(name: "Default")
            end
        end

        let doc = Factory._doc()
    end)
end)

test.describe("Built-in type methods", fun ()
    test.it("_str returns type representation", fun ()
        type Sample
            "Sample type"
            x: Num
        end

        test.assert_eq(Sample._str(), "type Sample")
    end)

    test.it("_rep returns type representation", fun ()
        type Sample
            "Sample type"
            x: Num
        end

        test.assert_eq(Sample._rep(), "type Sample")
    end)

    test.it("_id returns unique identifier", fun ()
        type Sample1
            x: Num
        end

        type Sample2
            x: Num
        end

        # Each type should have a different ID
        test.assert_neq(Sample1._id(), Sample2._id())
    end)
end)