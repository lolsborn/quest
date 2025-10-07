use "std/test"

test.module("Elvis Operator (QEP-019)")

test.describe("Basic nil handling", fun ()
    test.it("returns left if not nil", fun ()
        let x = 5 ?: 10
        test.assert_eq(x, 5)    end)

    test.it("returns right if left is nil", fun ()
        let x = nil ?: 10
        test.assert_eq(x, 10)    end)

    test.it("works with variables", fun ()
        let a = 42
        let b = a ?: 99
        test.assert_eq(b, 42)    end)

    test.it("uses default when variable is nil", fun ()
        let a = nil
        let b = a ?: 99
        test.assert_eq(b, 99)    end)
end)

test.describe("Type preservation", fun ()
    test.it("works with strings", fun ()
        test.assert_eq("hello" ?: "world", "hello")        test.assert_eq(nil ?: "world", "world")    end)

    test.it("works with numbers", fun ()
        test.assert_eq(42 ?: 0, 42)        test.assert_eq(nil ?: 0, 0)    end)

    test.it("works with booleans", fun ()
        test.assert_eq(true ?: false, true)        test.assert_eq(false ?: true, false, "false is not nil")
        test.assert_eq(nil ?: false, false)    end)

    test.it("works with arrays", fun ()
        let arr = [1, 2] ?: []
        test.assert_eq(arr.len(), 2, nil)

        let arr2 = nil ?: []
        test.assert_eq(arr2.len(), 0, nil)
    end)

    test.it("works with dicts", fun ()
        let d = {"x": 10} ?: {}
        test.assert_eq(d.get("x"), 10, nil)

        let d2 = nil ?: {}
        test.assert_eq(d2.keys().len(), 0, nil)
    end)
end)

test.describe("Zero and false are not nil", fun ()
    test.it("zero is not treated as nil", fun ()
        let x = 0 ?: 10
        test.assert_eq(x, 0, "Zero should be returned, not default")
    end)

    test.it("false is not treated as nil", fun ()
        let x = false ?: true
        test.assert_eq(x, false, "False should be returned, not default")
    end)

    test.it("empty string is not treated as nil", fun ()
        let x = "" ?: "default"
        test.assert_eq(x, "", "Empty string should be returned")
    end)

    test.it("empty array is not treated as nil", fun ()
        let x = [] ?: [1, 2]
        test.assert_eq(x.len(), 0, "Empty array should be returned")
    end)
end)

test.describe("Chaining elvis operators", fun ()
    test.it("chains multiple defaults", fun ()
        let a = nil
        let b = nil
        let c = "final"

        let result = a ?: b ?: c
        test.assert_eq(result, "final")    end)

    test.it("stops at first non-nil", fun ()
        let a = nil
        let b = "middle"
        let c = "final"

        let result = a ?: b ?: c
        test.assert_eq(result, "middle")    end)

    test.it("all non-nil returns first", fun ()
        let a = "first"
        let b = "middle"
        let c = "final"

        let result = a ?: b ?: c
        test.assert_eq(result, "first")    end)

    test.it("chains with different types", fun ()
        let a = nil
        let b = nil
        let c = 42

        let result = a ?: b ?: c
        test.assert_eq(result, 42)    end)
end)

test.describe("With expressions", fun ()
    test.it("works with arithmetic", fun ()
        let x = nil
        let result = x ?: 5 + 3
        test.assert_eq(result, 8)    end)

    test.it("works with comparisons", fun ()
        let x = nil
        let result = x ?: 10 > 5
        test.assert_eq(result, true)    end)

    test.it("works with method calls", fun ()
        let s = nil
        let result = s ?: "hello".upper()
        test.assert_eq(result, "HELLO")    end)

    test.it("works with array access", fun ()
        let arr = [1, 2, 3]
        let x = nil
        let result = x ?: arr[1]
        test.assert_eq(result, 2)    end)
end)

test.describe("Function call defaults", fun ()
    test.it("provides default for function returning nil", fun ()
        fun returns_nil()
            nil
        end

        let result = returns_nil() ?: 42
        test.assert_eq(result, 42)    end)

    test.it("uses return value when non-nil", fun ()
        fun returns_value()
            100
        end

        let result = returns_value() ?: 42
        test.assert_eq(result, 100)    end)

    test.it("function evaluated once", fun ()
        let call_count = 0

        fun track_calls()
            call_count = call_count + 1
            if call_count == 1
                nil
            else
                42
            end
        end

        let result = track_calls() ?: 99
        test.assert_eq(call_count, 1, "Function called exactly once")
        test.assert_eq(result, 99, "Got default")
    end)
end)

test.describe("Precedence", fun ()
    test.it("has lower precedence than arithmetic", fun ()
        let result = nil ?: 5 + 3
        test.assert_eq(result, 8, "Should be nil ?: (5 + 3)")
    end)

    test.it("has lower precedence than comparison", fun ()
        let result = nil ?: 10 > 5
        test.assert_eq(result, true, "Should be nil ?: (10 > 5)")
    end)

    test.it("has lower precedence than logical and", fun ()
        let result = nil ?: true and false
        test.assert_eq(result, false, "Should be nil ?: (true and false)")
    end)

    test.it("has lower precedence than logical or", fun ()
        let result = nil ?: false or true
        test.assert_eq(result, true, "Should be nil ?: (false or true)")
    end)
end)

test.describe("Edge cases", fun ()
    test.it("nested in expressions", fun ()
        let x = nil
        let result = (x ?: 5) + 3
        test.assert_eq(result, 8)    end)

    test.it("both sides can be complex", fun ()
        let result = (1 + 2) ?: (3 + 4)
        test.assert_eq(result, 3, "Left is not nil")

        let result2 = nil ?: (3 + 4)
        test.assert_eq(result2, 7, "Right evaluated")
    end)

    test.it("works in assignments", fun ()
        let x = nil ?: 10
        test.assert_eq(x, 10)    end)

    test.it("works in function arguments", fun ()
        fun take_arg(val)
            val
        end

        let result = take_arg(nil ?: 42)
        test.assert_eq(result, 42)    end)

    test.it("works in return statements", fun ()
        fun get_value(x)
            x ?: 100
        end

        test.assert_eq(get_value(50), 50, nil)
        test.assert_eq(get_value(nil), 100, nil)
    end)
end)
