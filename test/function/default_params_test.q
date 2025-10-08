# QEP-033: Default Parameter Values - Basic Tests

use "std/test"

test.module("Default Parameters - Basic")

test.describe("Basic default parameter values", fun ()
    test.it("uses default when parameter omitted", fun ()
        fun greet(name, greeting = "Hello")
            greeting .. ", " .. name
        end

        test.assert_eq(greet("Alice"), "Hello, Alice")
        test.assert_eq(greet("Bob", "Hi"), "Hi, Bob")
    end)

    test.it("supports multiple defaults", fun ()
        fun make_url(protocol = "https", domain = "example.com", path = "/")
            protocol .. "://" .. domain .. path
        end

        test.assert_eq(make_url(), "https://example.com/")
        test.assert_eq(make_url("http"), "http://example.com/")
        test.assert_eq(make_url("http", "test.com"), "http://test.com/")
        test.assert_eq(make_url("ftp", "files.com", "/download"), "ftp://files.com/download")
    end)

    test.it("works with typed parameters", fun ()
        fun add(x: Int, y: Int = 10)
            x + y
        end

        test.assert_eq(add(5), 15)
        test.assert_eq(add(5, 20), 25)
    end)

    test.it("works with all parameters having defaults", fun ()
        fun config(debug = false, verbose = false)
            [debug, verbose]
        end

        test.assert_eq(config(), [false, false])
        test.assert_eq(config(true), [true, false])
        test.assert_eq(config(true, true), [true, true])
    end)
end)

test.describe("Default expressions", fun ()
    test.it("evaluates simple expressions", fun ()
        fun add_ten(x = 5 + 5)
            x
        end

        test.assert_eq(add_ten(), 10)
        test.assert_eq(add_ten(20), 20)
    end)

    test.it("supports computed defaults from earlier params", fun ()
        fun double_or_custom(x, y = x + x)
            y
        end

        test.assert_eq(double_or_custom(5), 10, "Should double x")
        test.assert_eq(double_or_custom(5, 20), 20, "Should use explicit value")
    end)

    test.it("supports array and dict defaults", fun ()
        fun with_array(arr = [1, 2, 3])
            arr
        end

        fun with_dict(d = {x: 10, y: 20})
            d
        end

        test.assert_eq(with_array(), [1, 2, 3])
        test.assert_eq(with_dict().get("x"), 10)
    end)
end)

test.describe("Parameter scope rules", fun ()
    test.it("defaults can reference earlier parameters", fun ()
        fun add_with_default(x, y = x)
            x + y
        end

        test.assert_eq(add_with_default(5), 10, "y defaults to x")
        test.assert_eq(add_with_default(5, 3), 8, "y explicitly set")
    end)

    test.it("defaults can reference outer scope variables", fun ()
        let default_port = 8080

        fun connect(host, port = default_port)
            host .. ":" .. port.str()
        end

        test.assert_eq(connect("localhost"), "localhost:8080")
        test.assert_eq(connect("localhost", 3000), "localhost:3000")
    end)

    test.it("defaults evaluate in parameter scope", fun ()
        fun make_email(username, domain = "example.com", email = username .. "@" .. domain)
            email
        end

        test.assert_eq(make_email("alice"), "alice@example.com")
        test.assert_eq(make_email("bob", "test.com"), "bob@test.com")
        test.assert_eq(make_email("charlie", "foo.com", "custom@bar.com"), "custom@bar.com")
    end)
end)

test.describe("Anonymous functions with defaults", fun ()
    test.it("lambda functions support defaults", fun ()
        let greet = fun (name, greeting = "Hello")
            greeting .. ", " .. name
        end

        test.assert_eq(greet("Alice"), "Hello, Alice")
        test.assert_eq(greet("Bob", "Hi"), "Hi, Bob")
    end)

    test.it("lambdas with defaults can be passed as arguments", fun ()
        fun apply(f, x)
            f(x)
        end

        let double = fun (x, factor = 2) x * factor end

        test.assert_eq(apply(double, 5), 10)
    end)
end)

test.describe("Edge cases", fun ()
    test.it("nil as default value", fun ()
        fun optional(value = nil)
            if value == nil
                "no value"
            else
                value
            end
        end

        test.assert_eq(optional(), "no value")
        test.assert_eq(optional("test"), "test")
    end)

    test.it("boolean defaults", fun ()
        fun toggle(flag = false)
            flag
        end

        test.assert_eq(toggle(), false)
        test.assert_eq(toggle(true), true)
    end)

    test.it("string defaults with special characters", fun ()
        fun quote(text, mark = "\"")
            mark .. text .. mark
        end

        test.assert_eq(quote("hello"), "\"hello\"")
        test.assert_eq(quote("hello", "'"), "'hello'")
    end)

    test.it("numeric defaults", fun ()
        fun scale(value, factor = 1.5)
            value * factor
        end

        test.assert_eq(scale(10), 15)
        test.assert_eq(scale(10, 2), 20)
    end)
end)

test.describe("Recursive functions with defaults", fun ()
    test.it("countdown with default start", fun ()
        fun countdown(n = 5)
            if n > 0
                countdown(n - 1)
            else
                n
            end
        end

        test.assert_eq(countdown(), 0, "Should countdown from default 5")
        test.assert_eq(countdown(3), 0, "Should countdown from explicit 3")
    end)

    test.it("factorial with default base case", fun ()
        fun factorial(n, acc = 1)
            if n <= 1
                acc
            else
                factorial(n - 1, acc * n)
            end
        end

        test.assert_eq(factorial(5), 120)
        test.assert_eq(factorial(5, 2), 240, "With explicit accumulator")
    end)
end)
