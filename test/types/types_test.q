use "std/test" as test

pub type Person
    str: name
    num: age
end

test.module("Type System - Basic")

test.describe("Basic type declarations", fun ()
    test.it("creates type with required fields", fun ()
        type Person
            str: name
            num: age
        end

        let alice = Person.new("Alice", 30)
        test.assert_eq(alice.name, "Alice", "name should be Alice")
        test.assert_eq(alice.age, 30, "age should be 30")
    end)

    test.it("supports named arguments", fun ()
        type Person
            str: name
            num: age
        end

        let bob = Person.new(name: "Bob", age: 25)
        test.assert_eq(bob.name, "Bob", "name should be Bob")
        test.assert_eq(bob.age, 25, "age should be 25")
    end)

    test.it("allows any order for named arguments", fun ()
        type Person
            str: name
            num: age
        end

        let charlie = Person.new(age: 35, name: "Charlie")
        test.assert_eq(charlie.name, "Charlie", "name should be Charlie")
        test.assert_eq(charlie.age, 35, "age should be 35")
    end)
end)

test.describe("Optional fields", fun ()
    test.it("defaults optional fields to nil", fun ()
        type User
            str: username
            str?: email
            num?: score
        end

        let user = User.new("alice")
        test.assert_eq(user.username, "alice", "username should be alice")
        test.assert_eq(user.email, nil, "email should be nil")
        test.assert_eq(user.score, nil, "score should be nil")
    end)

    test.it("accepts optional fields when provided", fun ()
        type User
            str: username
            str?: email
            num?: score
        end

        let user = User.new("bob", "bob@test.com", 100)
        test.assert_eq(user.username, "bob", "username should be bob")
        test.assert_eq(user.email, "bob@test.com", "email should match")
        test.assert_eq(user.score, 100, "score should be 100")
    end)
end)
