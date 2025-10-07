# QEP-035: Named Arguments for Functions

use "std/test"

test.module("QEP-035: Named Arguments for Functions")

test.describe("Basic named arguments", fun ()
    test.it("accepts all named arguments", fun ()
        fun greet(greeting, name)
            greeting .. ", " .. name
        end

        let result = greet(greeting: "Hello", name: "Alice")
        test.assert_eq(result, "Hello, Alice", nil)
    end)

    test.it("accepts named arguments in any order", fun ()
        fun greet(greeting, name)
            greeting .. ", " .. name
        end

        let result = greet(name: "Alice", greeting: "Hello")
        test.assert_eq(result, "Hello, Alice", nil)
    end)

    test.it("works with single argument", fun ()
        fun square(x)
            x * x
        end

        test.assert_eq(square(x: 5), 25, nil)
    end)
end)

test.describe("Mixed positional and named", fun ()
    test.it("accepts positional then named", fun ()
        fun greet(greeting, name, punctuation)
            greeting .. ", " .. name .. punctuation
        end

        let result = greet("Hello", name: "Alice", punctuation: "!")
        test.assert_eq(result, "Hello, Alice!", nil)
    end)

    test.it("first positional, last two named", fun ()
        fun add_three(a, b, c)
            a + b + c
        end

        test.assert_eq(add_three(1, b: 2, c: 3), 6, nil)
    end)
end)

test.describe("With default parameters", fun ()
    test.it("can override defaults with named args", fun ()
        fun connect(host, port = 8080, timeout = 30)
            host .. ":" .. port._str() .. " (timeout: " .. timeout._str() .. ")"
        end

        let result = connect("localhost", timeout: 60)
        test.assert_eq(result, "localhost:8080 (timeout: 60)", nil)
    end)

    test.it("can skip optional parameters", fun ()
        fun connect(host, port = 8080, timeout = 30, debug = false)
            let dbg_str = "prod"
            if debug
                dbg_str = "debug"
            end
            host .. ":" .. port._str() .. " [" .. dbg_str .. "]"
        end

        let result = connect("localhost", debug: true)
        test.assert_eq(result, "localhost:8080 [debug]", nil)
    end)

    test.it("can specify middle defaults", fun ()
        fun f(a, b = 1, c = 2, d = 3)
            a + b + c + d
        end

        test.assert_eq(f(10, c: 5), 19, nil)  # 10 + 1 + 5 + 3
    end)
end)

test.describe("With type annotations", fun ()
    test.it("type checks named arguments", fun ()
        fun add(x: int, y: int)
            x + y
        end

        test.assert_eq(add(x: 5, y: 3), 8, nil)
    end)

    test.it("type checks mixed positional and named", fun ()
        fun greet(name: str, greeting: str = "Hello")
            greeting .. ", " .. name
        end

        test.assert_eq(greet("Alice"), "Hello, Alice", nil)
        test.assert_eq(greet("Bob", greeting: "Hi"), "Hi, Bob", nil)
    end)
end)
