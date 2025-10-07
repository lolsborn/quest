# Closure Tests
# Tests closure-by-reference semantics (QEP-XXX)

use "std/test" as test

test.module("Closures")

test.describe("Basic closure modification", fun ()
    test.it("modifies outer variable", fun ()
        let x = 1
        fun increment()
            x = x + 1
            x
        end
        let result = increment()
        test.assert_eq(result, 2)        test.assert_eq(x, 2)    end)

    test.it("preserves modifications across calls", fun ()
        let counter = 0
        fun inc()
            counter = counter + 1
        end
        inc()
        inc()
        inc()
        test.assert_eq(counter, 3)    end)
end)

test.describe("Multiple functions sharing state", fun ()
    test.it("shares state between functions", fun ()
        let shared = 0
        fun inc()
            shared = shared + 1
        end
        fun dec()
            shared = shared - 1
        end
        fun get()
            shared
        end

        inc()
        inc()
        dec()
        test.assert_eq(get(), 1)
        test.assert_eq(shared, 1)    end)
end)

test.describe("Lambda closures", fun ()
    test.it("lambda captures outer variable", fun ()
        let value = 10
        let multiplier = fun (n) value * n end
        test.assert_eq(multiplier(5), 50)
    end)

    test.it("lambda sees modified outer variable", fun ()
        let x = 5
        let doubler = fun () x * 2 end
        test.assert_eq(doubler(), 10)
        x = 25
        test.assert_eq(doubler(), 50)
    end)
end)

test.describe("Closure state persistence", fun ()
    test.it("maintains state across multiple calls", fun ()
        let state = 0
        fun add_to_state(n)
            state = state + n
            state
        end

        let r1 = add_to_state(10)
        let r2 = add_to_state(20)
        let r3 = add_to_state(5)

        test.assert_eq(r1, 10)        test.assert_eq(r2, 30)        test.assert_eq(r3, 35)        test.assert_eq(state, 35)    end)
end)

test.describe("Nested closures", fun ()
    test.it("inner function sees outer scope", fun ()
        let outer_var = 100

        fun outer_func()
            fun inner_func()
                outer_var + 50
            end
            inner_func()
        end

        test.assert_eq(outer_func(), 150)
    end)

    test.it("nested function modifies outer variable",
    fun ()
        let value = 10

        fun make_incrementer()
            fun do_inc()
                value = value + 1
                value
            end
            do_inc
        end

        let inc = make_incrementer()
        test.assert_eq(inc(), 11)
        test.assert_eq(inc(), 12)
        test.assert_eq(value, 12)
    end)
end)
