use "std/test" as test

test.module("Del Statement Tests")

test.describe("Basic deletion", fun ()
    test.it("deletes a variable", fun ()
        let x = 10
        test.assert_eq(x, 10, "x should be 10")
        del x
        # Variable should be gone - we can't test it directly without causing an error
    end)

    test.it("allows redeclaration after deletion", fun ()
        let y = 20
        test.assert_eq(y, 20, "y should be 20")
        del y
        let y = 30
        test.assert_eq(y, 30, "y should be redeclared as 30")
    end)
end)

test.describe("Freeing data structures", fun ()
    test.it("can delete arrays", fun ()
        let arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        test.assert_eq(arr.len(), 10, "array should have 10 elements")
        del arr
        # Array should be freed
    end)

    test.it("can delete dicts", fun ()
        let d = {"a": 1, "b": 2, "c": 3}
        test.assert_eq(d.len(), 3, "dict should have 3 keys")
        del d
        # Dict should be freed
    end)

    test.it("can delete strings", fun ()
        let s = "large string data"
        test.assert_eq(s.len(), 17, "string should have length")
        del s
        # String should be freed
    end)
end)

test.describe("Selective deletion", fun ()
    test.it("can delete specific variables while keeping others", fun ()
        let a = 1
        let b = 2
        let c = 3
        test.assert_eq(a, 1, "a should be 1")
        test.assert_eq(b, 2, "b should be 2")
        test.assert_eq(c, 3, "c should be 3")

        del b

        test.assert_eq(a, 1, "a should still be 1")
        test.assert_eq(c, 3, "c should still be 3")
    end)
end)

test.describe("Del in function scope", fun ()
    test.it("can delete variables in function scope", fun ()
        fun cleanup()
            let temp = 42
            del temp
            return "cleaned"
        end

        let result = cleanup()
        test.assert_eq(result, "cleaned", "function should complete successfully")
    end)

    test.it("function-scoped deletion doesn't affect outer scope", fun ()
        let outer = 100

        fun inner()
            let outer = 200
            del outer
            return "done"
        end

        inner()
        test.assert_eq(outer, 100, "outer variable should be unchanged")
    end)
end)
