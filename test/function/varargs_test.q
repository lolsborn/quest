# QEP-034 MVP: Variadic Parameters (*args) Tests

use "std/test"

test.module("QEP-034 MVP: Variadic Parameters")

test.describe("Basic *args", fun ()
    test.it("collects no arguments into empty array", fun ()
        fun sum(*numbers)
            let total = 0
            for n in numbers
                total = total + n
            end
            total
        end

        test.assert_eq(sum(), 0, nil)
    end)

    test.it("collects single argument into array", fun ()
        fun sum(*numbers)
            let total = 0
            for n in numbers
                total = total + n
            end
            total
        end

        test.assert_eq(sum(5), 5, nil)
    end)

    test.it("collects multiple arguments into array", fun ()
        fun sum(*numbers)
            let total = 0
            for n in numbers
                total = total + n
            end
            total
        end

        test.assert_eq(sum(1, 2, 3), 6, nil)
        test.assert_eq(sum(1, 2, 3, 4, 5), 15, nil)
    end)

    test.it("varargs parameter has correct length", fun ()
        fun count_args(*args)
            args.len()
        end

        test.assert_eq(count_args(), 0, nil)
        test.assert_eq(count_args(1), 1, nil)
        test.assert_eq(count_args(1, 2, 3), 3, nil)
    end)

    test.it("varargs parameter is an array", fun ()
        fun get_args(*args)
            args
        end

        let result = get_args(1, 2, 3)
        test.assert_eq(result.len(), 3, nil)
        test.assert_eq(result[0], 1, nil)
        test.assert_eq(result[1], 2, nil)
        test.assert_eq(result[2], 3, nil)
    end)
end)

test.describe("Mixed parameters and *args", fun ()
    test.it("combines required param with *args", fun ()
        fun greet(greeting, *names)
            let result = greeting
            for name in names
                result = result .. " " .. name
            end
            result
        end

        test.assert_eq(greet("Hello"), "Hello")
        test.assert_eq(greet("Hello", "Alice"), "Hello Alice")
        test.assert_eq(greet("Hello", "Alice", "Bob"), "Hello Alice Bob")
    end)

    test.it("combines multiple required params with *args", fun ()
        fun printf(format, sep, *args)
            let result = format .. sep
            for arg in args
                result = result .. arg._str() .. sep
            end
            result
        end

        test.assert_eq(printf("Values:", " "), "Values: ", nil)
        test.assert_eq(printf("Values:", " ", 1, 2, 3), "Values: 1 2 3 ", nil)
    end)

    test.it("combines required and optional params with *args", fun ()
        fun connect(host, port = 8080, *extra)
            host .. ":" .. port._str() .. " extras:" .. extra.len()._str()
        end

        test.assert_eq(connect("localhost"), "localhost:8080 extras:0", nil)
        test.assert_eq(connect("localhost", 3000), "localhost:3000 extras:0", nil)
        test.assert_eq(connect("localhost", 3000, "a", "b"), "localhost:3000 extras:2", nil)
    end)
end)

test.describe("Lambda with *args", fun ()
    test.it("works with lambda expressions", fun ()
        let sum = fun (*nums)
            let total = 0
            for n in nums
                total = total + n
            end
            total
        end

        test.assert_eq(sum(), 0, nil)
        test.assert_eq(sum(1, 2, 3), 6, nil)
    end)

    test.it("lambda with mixed params", fun ()
        let multiply_and_sum = fun (factor, *nums)
            let total = 0
            for n in nums
                total = total + (n * factor)
            end
            total
        end

        test.assert_eq(multiply_and_sum(2), 0, nil)
        test.assert_eq(multiply_and_sum(2, 1, 2, 3), 12, nil)
    end)
end)

test.describe("Error handling", fun ()
    test.it("requires required params even with *args", fun ()
        fun f(required, *rest)
            required
        end

        test.assert_raises(Err, fun () f() end, nil)
    end)

    test.it("rejects too few args for required params", fun ()
        fun f(a, b, *rest)
            a + b
        end

        test.assert_raises(Err, fun () f(1) end, nil)
    end)
end)
