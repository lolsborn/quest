use "std/test" as test

test.module("Function Docstrings")

test.describe("Single-line docstrings", fun ()
    test.it("extracts docstring from function with single-line string", fun ()
        fun greet(name)
            "Greets a person by name"
            "Hello, " .. name
        end

        let f = greet
        test.assert_eq(f._doc(), "Greets a person by name", nil)
    end)

    test.it("returns default doc when no docstring present", fun ()
        fun no_doc()
            42
        end

        let f = no_doc
        test.assert_eq(f._doc(), "User-defined function: no_doc", nil)
    end)
end)

test.describe("Type methods with docstrings", fun ()
    test.it("type with method docstrings can be created", fun ()
        type Calculator
            "A simple calculator"
            pub num: value

            fun add(n)
                "Adds a number to the value"
                self.value + n
            end
        end

        # Cannot directly test method docstrings since we can't get method references from instances
        # But we verify the type can be created and used
        let calc = Calculator.new(value: 10)
        test.assert_eq(calc.value, 10, nil)
        test.assert_eq(calc.add(5), 15, nil)
    end)
end)

test.describe("Anonymous functions", fun ()
    test.it("returns default doc for anonymous function", fun ()
        let f = fun (x) x * 2 end
        test.assert_eq(f._doc(), "Anonymous function", nil)
    end)
end)