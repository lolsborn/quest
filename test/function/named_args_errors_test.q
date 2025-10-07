# QEP-035: Named Arguments - Error Handling

use "std/test"

test.module("QEP-035: Named Arguments - Errors")

test.describe("Positional after named error", fun ()
    test.it("rejects positional argument after named", fun ()
        fun greet(name, greeting)
            greeting .. ", " .. name
        end

        test.assert_raises(ArgErr, fun ()
            greet(name: "Alice", "Hello")
        end, "Should reject positional after named")
    end)
end)

test.describe("Duplicate parameter error", fun ()
    test.it("rejects duplicate keyword argument", fun ()
        fun greet(name, greeting)
            greeting .. ", " .. name
        end

        test.assert_raises(ArgErr, fun ()
            greet(name: "Alice", name: "Bob")
        end, "Should reject duplicate keyword arg")
    end)

    test.it("rejects positional and keyword for same param", fun ()
        fun greet(name, greeting)
            greeting .. ", " .. name
        end

        test.assert_raises(ArgErr, fun ()
            greet("Alice", name: "Bob")
        end, "Should reject param specified both ways")
    end)
end)

test.describe("Unknown keyword arguments", fun ()
    test.it("rejects unknown keyword arg", fun ()
        fun add(x, y)
            x + y
        end

        test.assert_raises(ArgErr, fun ()
            add(a: 5, b: 3)
        end, "Should reject unknown keyword args")
    end)

    test.it("accepts unknown kwargs when function has **kwargs", fun ()
        fun test_func(a, **options)
            a
        end

        let result = test_func(a: 10, unknown: 42, another: "test")
        test.assert_eq(result, 10)
    end)
end)

test.describe("Missing required parameters", fun ()
    test.it("rejects missing required param", fun ()
        fun greet(name, greeting)
            greeting .. ", " .. name
        end

        test.assert_raises(ArgErr, fun ()
            greet(greeting: "Hello")
        end, "Should require all params")
    end)

    test.it("rejects missing first param", fun ()
        fun add_three(a, b, c)
            a + b + c
        end

        test.assert_raises(ArgErr, fun ()
            add_three(b: 2, c: 3)
        end, "Should require first param")
    end)
end)

test.describe("Type errors with named args", fun ()
    test.it("type checks named arguments", fun ()
        fun add(x: int, y: int)
            x + y
        end

        test.assert_raises(TypeErr, fun ()
            add(x: "hello", y: 3)
        end, "Should type check named args")
    end)

    test.it("type checks mixed positional and named", fun ()
        fun greet(name: str, greeting: str = "Hello")
            greeting .. ", " .. name
        end

        test.assert_raises(TypeErr, fun ()
            greet(42, greeting: "Hi")
        end, "Should type check positional args")
    end)
end)
