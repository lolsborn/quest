# QEP-033: Default Parameter Values - Error Cases

use "std/test"

test.module("Default Parameters - Error Cases")

test.describe("Argument count validation", fun ()
    test.it("rejects too few arguments", fun ()
        fun needs_two(a, b, c = 3)
            a + b + c
        end

        test.assert_raises(ArgErr, fun () needs_two(1) end, "Should require at least 2 args")
    end)

    test.it("rejects too many arguments", fun ()
        fun takes_three(a, b = 2, c = 3)
            a + b + c
        end

        test.assert_raises(ArgErr, fun () takes_three(1, 2, 3, 4) end, "Should reject 4 args when max is 3")
    end)

    test.it("allows exactly the right number of args", fun ()
        fun takes_two(a, b = 2)
            a + b
        end

        test.assert_eq(takes_two(5), 7, "Should work with 1 arg")
        test.assert_eq(takes_two(5, 10), 15, "Should work with 2 args")
    end)
end)

test.describe("Runtime errors in defaults", fun ()
    test.it("propagates errors from default evaluation", fun ()
        fun divide_default(x, y = 10 / 0)
            x + y
        end

        test.assert_raises(RuntimeErr, fun () divide_default(5) end, "Should propagate division by zero")
    end)

    test.it("propagates errors from method calls in defaults", fun ()
        fun get_first(arr = [].get(0))
            arr
        end

        test.assert_raises(RuntimeErr, fun () get_first() end, "Should propagate index error")
    end)
end)

test.describe("Type errors (when types are specified)", fun ()
    test.it("works when default matches type", fun ()
        fun typed(x: Int = 10)
            x + 5
        end

        test.assert_eq(typed(), 15)
        test.assert_eq(typed(20), 25)
    end)

    test.it("works with complex type expressions", fun ()
        fun with_array(arr: array = [1, 2, 3])
            arr.len()
        end

        test.assert_eq(with_array(), 3)
    end)
end)
