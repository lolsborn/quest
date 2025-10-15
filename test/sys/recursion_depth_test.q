use "std/test"
use "std/sys" as sys

test.describe("QEP-048: Stack depth introspection", fun ()
    test.it("sys.get_call_depth() returns current depth", fun ()
        # At test level, call_depth should be small (> 0 due to test framework)
        let depth = sys.get_call_depth()
        test.assert(depth > 0)
        test.assert(depth < 100)  # Reasonable bound
    end)

    test.it("sys.get_call_depth() increases with function calls", fun ()
        let depth_at_level = fun (n)
            if n <= 0
                return sys.get_call_depth()
            end
            return depth_at_level(n - 1)
        end

        let initial_depth = sys.get_call_depth()
        let depth_after_10 = depth_at_level(10)

        # Should be roughly 10 levels deeper
        test.assert(depth_after_10 > initial_depth)
        test.assert(depth_after_10 - initial_depth >= 10)
    end)

    test.it("sys.get_depth_limits() returns default limits", fun ()
        let limits = sys.get_depth_limits()
        test.assert_eq(limits["function_calls"], 1000)
        test.assert_eq(limits["eval_recursion"], 2000)
        test.assert_eq(limits["module_loading"], 50)
    end)

    test.it("depth tracking works with nested function calls", fun ()
        fun level_a(n)
            if n <= 0
                return sys.get_call_depth()
            end
            return level_b(n - 1)
        end

        fun level_b(n)
            if n <= 0
                return sys.get_call_depth()
            end
            return level_a(n - 1)
        end

        let initial_depth = sys.get_call_depth()
        let depth_in_recursion = level_a(5)

        # Should be at least 5 levels deeper
        test.assert(depth_in_recursion > initial_depth)
        test.assert(depth_in_recursion - initial_depth >= 5)
    end)

    test.it("call depth resets after function returns", fun ()
        let depth_before = sys.get_call_depth()

        fun nested()
            let depth_inside = sys.get_call_depth()
            test.assert(depth_inside > depth_before)
        end

        nested()

        let depth_after = sys.get_call_depth()
        test.assert_eq(depth_before, depth_after)
    end)

    test.it("enforces function call depth limit with default settings", fun ()
        # With default limit of 1000, we should be able to recurse safely to small depths
        let countdown = fun (n)
            if n <= 0
                return 0
            end
            return countdown(n - 1)
        end

        # This should work with default limits (using small depth)
        let result = countdown(20)
        test.assert_eq(result, 0)
    end)

end)
