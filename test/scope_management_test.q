# Scope Management Tests (QEP-059, Bug #020)
#
# Tests that scope depth is properly maintained even when errors occur
# in control flow constructs (loops, functions, try/catch).
#
# Related:
# - QEP-059: RAII Scope Management
# - Bug #020: Scope Leak in Iterative Evaluator (FIXED)
# - Bug #021: If Statement Errors Bypass Try/Catch (FIXED)

use "std/test"
use "std/sys" as sys

test.module("Scope Management (QEP-059)")

test.describe("While Loop Scope Management", fun ()
    test.it("maintains scope depth with break statement", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 10
            if i == 5
                break
            end
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with continue statement", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        let count = 0
        while i < 5
            i = i + 1
            if i == 3
                continue
            end
            count = count + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with normal completion", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 5
            let x = i * 2
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("For Loop Scope Management", fun ()
    test.it("maintains scope depth with for loop break", fun ()
        let initial = sys.get_scope_depth()

        for x in [1, 2, 3, 4, 5]
            if x == 3
                break
            end
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with for loop continue", fun ()
        let initial = sys.get_scope_depth()

        let sum = 0
        for x in [1, 2, 3, 4, 5]
            if x == 3
                continue
            end
            sum = sum + x
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with normal for loop", fun ()
        let initial = sys.get_scope_depth()

        let result = 0
        for x in [1, 2, 3, 4, 5]
            result = result + x
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("Nested Loop Scope Management", fun ()
    test.it("maintains scope depth with nested while loops", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 3
            let j = 0
            while j < 3
                let k = i * 10 + j
                j = j + 1
            end
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with nested for loops", fun ()
        let initial = sys.get_scope_depth()

        for i in [1, 2, 3]
            for j in [1, 2, 3]
                let product = i * j
            end
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with mixed nested loops", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 3
            for j in [1, 2, 3]
                let sum = i + j
            end
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("Stress Test - High Iteration Count", fun ()
    test.it("handles 1000 iterations without leak", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 1000
            let x = i * 2
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("handles deeply nested loops", fun ()
        let initial = sys.get_scope_depth()

        let i = 0
        while i < 5
            let j = 0
            while j < 5
                let k = 0
                while k < 5
                    let val = i + j + k
                    k = k + 1
                end
                j = j + 1
            end
            i = i + 1
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("Function Scope Management", fun ()
    test.it("maintains scope depth after function call", fun ()
        let initial = sys.get_scope_depth()

        fun test_func()
            let x = 42
            return x
        end

        test_func()

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth after nested function calls", fun ()
        let initial = sys.get_scope_depth()

        fun inner()
            let x = 1
            return x
        end

        fun outer()
            let y = inner()
            return y + 1
        end

        outer()

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("Try/Catch Scope Management", fun ()
    test.it("maintains scope depth in try block", fun ()
        let initial = sys.get_scope_depth()

        try
            let x = 42
            let y = x * 2
        catch e
            # Not reached
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth in catch block", fun ()
        let initial = sys.get_scope_depth()

        try
            raise Err.new("test")
        catch e
            let msg = e.message()
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)

    test.it("maintains scope depth with nested try/catch", fun ()
        let initial = sys.get_scope_depth()

        try
            try
                let x = 42
            catch e1
                let y = 1
            end
        catch e2
            let z = 2
        end

        let final_depth = sys.get_scope_depth()
        test.assert_eq(final_depth, initial)
    end)
end)

test.describe("Scope Depth Introspection", fun ()
    test.it("reports correct depth at top level", fun ()
        let depth = sys.get_scope_depth()
        # Should be at least 1 (module scope)
        test.assert(depth >= 1)
    end)

    test.it("reports increased depth in function", fun ()
        let outer_depth = sys.get_scope_depth()

        fun check_depth()
            let inner_depth = sys.get_scope_depth()
            test.assert(inner_depth > outer_depth)
        end

        check_depth()
    end)

    test.it("reports increased depth in loop", fun ()
        let outer_depth = sys.get_scope_depth()

        let i = 0
        while i < 1
            let inner_depth = sys.get_scope_depth()
            test.assert(inner_depth > outer_depth)
            i = i + 1
        end
    end)
end)
