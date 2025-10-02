#!/usr/bin/env quest
# Tests for user-defined functions

use "std/test" as test

test.module("Function Tests - Basic")

test.describe("Function Definition and Calling", fun ()
    test.it("calls simple function", fun ()
        fun greet()
            "Hello"
        end

        let result = greet()
        test.assert(result == "Hello", "should return Hello")
    end)

    test.it("calls function with single parameter", fun ()
        fun double(x)
            x * 2
        end

        test.assert(double(5) == 10, "double(5) should be 10")
        test.assert(double(0) == 0, "double(0) should be 0")
    end)

    test.it("calls function with multiple parameters", fun ()
        fun add(x, y)
            x + y
        end

        test.assert(add(5, 3) == 8, "5 + 3 should be 8")
        test.assert(add(10, 20) == 30, "10 + 20 should be 30")
    end)
end)

test.describe("Function Return Values", fun ()
    test.it("returns last expression", fun ()
        fun compute(x)
            let a = x * 2
            let b = a + 10
            b
        end

        test.assert(compute(5) == 20, "compute(5) should be 20")
    end)

    test.it("returns number", fun ()
        fun get_pi()
            3.14159
        end

        let pi = get_pi()
        test.assert(pi > 3.14, "should return pi approximation")
    end)

    test.it("returns string", fun ()
        fun get_greeting(name)
            "Hello, " .. name .. "not "
        end

        test.assert(get_greeting("World") == "Hello, Worldnot ", "should return greeting")
    end)

    test.it("returns boolean", fun ()
        fun is_positive(n)
            n > 0
        end

        test.assert(is_positive(5), "5 should be positive")
        test.assert(not is_positive(-3), "-3 should not be positive")
    end)

    test.it("returns array", fun ()
        fun make_array(a, b, c)
            [a, b, c]
        end

        let result = make_array(1, 2, 3)
        test.assert(result.len() == 3, "should return array of length 3")
        test.assert(result[0] == 1, "first element should be 1")
    end)

    test.it("returns dict", fun ()
        fun make_dict(name, age)
            {"name": name, "age": age}
        end

        let d = make_dict("Alice", 30)
        test.assert(d["name"] == "Alice", "name should be Alice")
        test.assert(d["age"] == 30, "age should be 30")
    end)
end)

test.describe("Function with Multiple Statements", fun ()
    test.it("executes multiple statements", fun ()
        fun process(x)
            let a = x * 2
            let b = a + 10
            let c = b / 2
            c
        end

        test.assert(process(5) == 10, "process(5) should be 10")
    end)

    test.it("uses conditionals in function", fun ()
        fun classify(x)
            if x > 10
                "big"
            elif x > 5
                "medium"
            else
                "small"
            end
        end

        test.assert(classify(15) == "big", "15 is big")
        test.assert(classify(7) == "medium", "7 is medium")
        test.assert(classify(3) == "small", "3 is small")
    end)
end)

test.describe("Function Scoping", fun ()
    test.it("accesses outer scope variables", fun ()
        let outer = 10

        fun use_outer()
            outer * 2
        end

        test.assert(use_outer() == 20, "should access outer variable")
    end)

    test.it("shadows outer scope variables", fun ()
        let x = 10

        fun shadow(x)
            x * 2
        end

        test.assert(shadow(5) == 10, "should use parameter, not outer x")
        test.assert(x == 10, "outer x should be unchanged")
    end)

    test.it("creates local variables", fun ()
        fun use_local()
            let local = 42
            local
        end

        let result = use_local()
        test.assert(result == 42, "should return local variable")
    end)
end)

test.describe("Function with Closures", fun ()
    test.it("captures variables from outer scope", fun ()
        let multiplier = 3

        fun multiply(x)
            x * multiplier
        end

        test.assert(multiply(5) == 15, "should use captured multiplier")
    end)

    test.it("captures multiple variables", fun ()
        let a = 10
        let b = 20

        fun compute()
            a + b
        end

        test.assert(compute() == 30, "should capture both variables")
    end)
end)

test.describe("Recursive Functions", fun ()
    test.it("computes factorial", fun ()
        fun factorial(n)
            if n <= 1
                1
            else
                n * factorial(n - 1)
            end
        end

        test.assert(factorial(0) == 1, "0not  should be 1")
        test.assert(factorial(1) == 1, "1not  should be 1")
        test.assert(factorial(5) == 120, "5not  should be 120")
    end)

    test.it("computes fibonacci", fun ()
        fun fib(n)
            if n <= 1
                n
            else
                fib(n - 1) + fib(n - 2)
            end
        end

        test.assert(fib(0) == 0, "fib(0) should be 0")
        test.assert(fib(1) == 1, "fib(1) should be 1")
        test.assert(fib(6) == 8, "fib(6) should be 8")
    end)
end)

test.describe("Higher-Order Functions", fun ()
    test.it("accepts function as parameter", fun ()
        fun apply_twice(f, value)
            f(f(value))
        end

        fun increment(n)
            n + 1
        end

        test.assert(apply_twice(increment, 5) == 7, "should apply twice")
    end)

    # Note: Returning closures with captured variables is not fully supported yet
    # test.it("returns function", fun ()
    #     fun make_adder(n)
    #         fun (x)
    #             x + n
    #         end
    #     end
    #     let add5 = make_adder(5)
    #     test.assert(add5(10) == 15, "should add 5")
    # end)
end)
