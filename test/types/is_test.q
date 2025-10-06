use "std/test"

test.module("Type .is() Method")

test.describe("Built-in type literals", fun ()
    test.it("int type literal works", fun ()
        test.assert(42.is(Int), "42 should be int")
        test.assert_eq(42.is(Str), false, "42 should not be str")
    end)

    test.it("str type literal works", fun ()
        test.assert("hello".is(Str), "string should be str")
        test.assert_eq("hello".is(Int), false, "string should not be int")
    end)

    test.it("float type literal works", fun ()
        test.assert(3.14.is(Float), "3.14 should be float")
        test.assert_eq(3.14.is(Int), false, "3.14 should not be int")
    end)

    test.it("bool type literal works", fun ()
        test.assert(true.is(Bool), "true should be bool")
        test.assert(false.is(Bool), "false should be bool")
    end)

    test.it("array type literal works", fun ()
        let arr = [1, 2, 3]
        test.assert(arr.is(Array), "array should be array")
    end)

    test.it("dict type literal works", fun ()
        let d = {"key": "value"}
        test.assert(d.is(Dict), "dict should be dict")
    end)
end)

test.describe("User-defined types", fun ()
    test.it("works with user types", fun ()
        type Person
            name: Str
        end

        let p = Person.new(name: "Alice")
        test.assert(p.is(Person), "instance should be Person type")
    end)
end)
