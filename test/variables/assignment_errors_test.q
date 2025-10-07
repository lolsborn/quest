use "std/test" as test

test.module("Assignment Error Handling")

test.describe("Assignment without let", fun ()
    test.it("errors when assigning to undeclared variable", fun ()
        test.assert_raises(NameErr, fun ()
            undeclared = 42
        end, nil)
    end)

    test.it("provides helpful error message", fun ()
        try
            missing_var = "value"
        catch e
            let msg = e.message()
            test.assert_type(msg, "Str")            # Message should contain the variable name
            test.assert_gt(msg.len(), 20, nil)
        end
    end)

    test.it("works after proper declaration", fun ()
        let declared = 10
        declared = 20
        test.assert_eq(declared, 20)    end)
end)

test.describe("Compound assignment without let", fun ()
    test.it("errors with += on undeclared variable", fun ()
        test.assert_raises(NameErr, fun ()
            undefined += 5
        end, nil)
    end)

    test.it("errors with -= on undeclared variable", fun ()
        test.assert_raises(NameErr, fun ()
            undefined -= 3
        end, nil)
    end)

    test.it("errors with *= on undeclared variable", fun ()
        test.assert_raises(NameErr, fun ()
            undefined *= 2
        end, nil)
    end)

    test.it("works with compound ops after declaration", fun ()
        let counter = 10
        counter += 5
        test.assert_eq(counter, 15)        counter *= 2
        test.assert_eq(counter, 30)    end)
end)

test.describe("Multiple let then assign", fun ()
    test.it("works with comma-separated let", fun ()
        let a = 1, b = 2, c = 3
        a = 10
        b = 20
        c = 30
        test.assert_eq(a, 10)        test.assert_eq(b, 20)        test.assert_eq(c, 30)    end)

    test.it("can reference earlier vars in multiple let", fun ()
        let x = 5, y = x * 2
        x = 100
        y = x + 50
        test.assert_eq(x, 100)        test.assert_eq(y, 150)    end)
end)

test.describe("Scoping rules", fun ()
    test.it("errors in function scope without let", fun ()
        test.assert_raises(NameErr, fun ()
            fun bad_func()
                local_var = 42
            end
            bad_func()
        end, nil)
    end)

    test.it("allows reassignment in function scope", fun ()
        let outer = 10
        fun modify()
            outer = 20
        end
        modify()
        test.assert_eq(outer, 20)    end)

    test.it("requires let even in nested scope", fun ()
        test.assert_raises(NameErr, fun ()
            if true
                nested = 5
            end
        end, nil)
    end)
end)
