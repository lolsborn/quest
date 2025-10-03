use "std/test" as test
use ".types_test" as b

test.module("Type System - Import")

test.describe("Create instance from imported types", fun ()
    test.it("imports types from other files", fun ()
        let alice = b.Person.new("Alice", 30)
        test.assert_eq(alice.name, "Alice", "name should be Alice")
        test.assert_eq(alice.age, 30, "age should be 30")
    end)
end)
