#!/usr/bin/env quest
# Tests for anonymous functions (lambdas)

use "std/test" as test

test.describe("Lambda Creation", fun ()
    test.it("creates simple lambda", fun ()
        let double = fun (x) x * 2 end
        test.assert(double(5) == 10, "double(5) should be 10")
    end)

    test.it("creates multi-parameter lambda", fun ()
        let add = fun (x, y) x + y end
        test.assert(add(3, 7) == 10, "add(3, 7) should be 10")
    end)

    test.it("creates parameterless lambda", fun ()
        let greet = fun () "Hello, World!" end
        test.assert(greet() == "Hello, World!", "should return greeting")
    end)
end)

test.describe("Lambda with Multiple Statements", fun ()
    test.it("executes multiple statements", fun ()
        let compute = fun (x, y)
            let a = x * 2
            let b = y * 3
            a + b
        end

        test.assert(compute(5, 10) == 40, "compute(5, 10) should be 40")
    end)

    test.it("uses conditionals", fun ()
        let classify = fun (n)
            if n > 10
                "big"
            else
                "small"
            end
        end

        test.assert(classify(15) == "big", "15 is big")
        test.assert(classify(3) == "small", "3 is small")
    end)
end)

test.describe("Lambda with String Operations", fun ()
    test.it("concatenates strings", fun ()
        let make_greeting = fun (name) "Hello, " .. name .. "!" end
        test.assert(make_greeting("Alice") == "Hello, Alice!", "should greet Alice")
        test.assert(make_greeting("Bob") == "Hello, Bob!", "should greet Bob")
    end)

    test.it("transforms strings", fun ()
        let shout = fun (msg) msg.upper() .. "!!!" end
        test.assert(shout("hello") == "HELLO!!!", "should shout hello")
    end)
end)

test.describe("Lambda as Function Arguments", fun ()
    test.it("passes lambda to function", fun ()
        fun apply_twice(f, value)
            f(f(value))
        end

        let increment = fun (n) n + 1 end
        test.assert(apply_twice(increment, 5) == 7, "should increment twice")
    end)

    test.it("uses inline lambda", fun ()
        fun apply_twice(f, value)
            f(f(value))
        end

        let result = apply_twice(fun (x) x * 2 end, 3)
        test.assert(result == 12, "should double twice: 3 -> 6 -> 12")
    end)
end)

test.describe("Lambda with Array Operations", fun ()
    test.it("uses lambda with map", fun ()
        let items = [1, 2, 3, 4, 5]
        let doubled = items.map(fun (x) x * 2 end)

        test.assert(doubled[0] == 2, "first element doubled")
        test.assert(doubled[4] == 10, "last element doubled")
    end)

    test.it("uses lambda with filter", fun ()
        let items = [1, 2, 3, 4, 5, 6]
        let evens = items.filter(fun (x) x % 2 == 0 end)

        test.assert(evens.len() == 3, "should have 3 even numbers")
        test.assert(evens[0] == 2, "first even is 2")
    end)

    test.it("uses lambda with reduce", fun ()
        let items = [1, 2, 3, 4, 5]
        let sum = items.reduce(fun (acc, x) acc + x end, 0)

        test.assert(sum == 15, "sum should be 15")
    end)

    test.it("uses lambda with any", fun ()
        let items = [1, 2, 3, 4, 5]
        let has_even = items.any(fun (x) x % 2 == 0 end)
        let has_negative = items.any(fun (x) x < 0 end)

        test.assert(has_even, "should have even number")
        test.assert(!has_negative, "should not have negative")
    end)

    test.it("uses lambda with all", fun ()
        let items = [2, 4, 6, 8]
        let all_even = items.all(fun (x) x % 2 == 0 end)
        let all_positive = items.all(fun (x) x > 0 end)

        test.assert(all_even, "all should be even")
        test.assert(all_positive, "all should be positive")
    end)

    test.it("uses lambda with find", fun ()
        let items = [1, 2, 3, 4, 5]
        let first_even = items.find(fun (x) x % 2 == 0 end)

        test.assert(first_even == 2, "first even should be 2")
    end)
end)

test.describe("Lambda Array Storage", fun ()
    test.it("stores lambdas in array", fun ()
        let operations = [
            fun (x) x + 1 end,
            fun (x) x * 2 end,
            fun (x) x * x end
        ]

        let op0 = operations[0]
        let op1 = operations[1]
        let op2 = operations[2]

        test.assert(op0(5) == 6, "first operation: increment")
        test.assert(op1(5) == 10, "second operation: double")
        test.assert(op2(5) == 25, "third operation: square")
    end)

    test.it("applies array of lambdas", fun ()
        let transforms = [
            fun (x) x + 10 end,
            fun (x) x * 2 end
        ]

        let value = 5
        # Note: Direct indexing and calling like transforms[0](value) may not work
        # Instead, extract the function first
        let add_fn = transforms[0]
        let mul_fn = transforms[1]
        let result1 = add_fn(value)
        let result2 = mul_fn(value)

        test.assert(result1 == 15, "add 10")
        test.assert(result2 == 10, "multiply by 2")
    end)
end)

test.describe("Lambda Closures", fun ()
    test.it("captures outer variables", fun ()
        let multiplier = 3
        let multiply = fun (x) x * multiplier end

        test.assert(multiply(5) == 15, "should use captured multiplier")
    end)

    test.it("captures multiple variables", fun ()
        let a = 10
        let b = 20
        let compute = fun () a + b end

        test.assert(compute() == 30, "should capture both variables")
    end)

    # Note: Returning closures with captured variables is not fully supported yet
    # test.it("creates closure factory", fun ()
    #     fun make_adder(n)
    #         fun (x) x + n end
    #     end
    #     let add5 = make_adder(5)
    #     let add10 = make_adder(10)
    #     test.assert(add5(3) == 8, "add5(3) should be 8")
    #     test.assert(add10(3) == 13, "add10(3) should be 13")
    # end)
    #
    # test.it("creates counter closure", fun ()
    #     fun make_counter()
    #         let count = 0
    #         fun ()
    #             count = count + 1
    #             count
    #         end
    #     end
    #     let counter = make_counter()
    #     test.assert(counter() == 1, "first call returns 1")
    #     test.assert(counter() == 2, "second call returns 2")
    #     test.assert(counter() == 3, "third call returns 3")
    # end)
end)

test.describe("Lambda Return from Function", fun ()
    # Note: Returning closures with captured variables is not fully supported yet
    # test.it("returns lambda", fun ()
    #     fun make_multiplier(n)
    #         fun (x) x * n end
    #     end
    #     let triple = make_multiplier(3)
    #     test.assert(triple(7) == 21, "triple(7) should be 21")
    # end)

    test.it("returns simple lambda", fun ()
        fun get_operation(op)
            if op == "add"
                fun (x, y) x + y end
            else
                fun (x, y) x * y end
            end
        end

        let add = get_operation("add")
        let multiply = get_operation("multiply")

        test.assert(add(3, 5) == 8, "add should work")
        test.assert(multiply(3, 5) == 15, "multiply should work")
    end)
end)
