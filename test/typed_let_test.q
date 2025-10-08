# Typed Let Statements Test
use "std/test"

test.module("Typed Let Statements")

test.describe("Basic typed declarations", fun ()
    test.it("declares Int variable", fun ()
        let x: Int = 42
        test.assert_eq(x, 42)
    end)

    test.it("declares Str variable", fun ()
        let name: Str = "Alice"
        test.assert_eq(name, "Alice")
    end)

    test.it("declares Bool variable", fun ()
        let active: Bool = true
        test.assert_eq(active, true)
    end)

    test.it("declares Float variable", fun ()
        let pi: Float = 3.14
        test.assert_near(pi, 3.14, 0.01)
    end)

    test.it("declares Array variable", fun ()
        let items: Array = [1, 2, 3]
        test.assert_eq(items.len(), 3)
        test.assert_eq(items[0], 1)
    end)

    test.it("declares Dict variable", fun ()
        let config: Dict = {debug: true, port: 8080}
        test.assert_eq(config["debug"], true)
        test.assert_eq(config["port"], 8080)
    end)
end)

test.describe("Multiple declarations", fun ()
    test.it("declares multiple typed variables in one statement", fun ()
        let a: Int = 1, b: Str = "test", c: Bool = false
        test.assert_eq(a, 1)
        test.assert_eq(b, "test")
        test.assert_eq(c, false)
    end)

    test.it("mixes typed and untyped declarations", fun ()
        let x: Int = 10, y = "hello", z: Float = 2.5
        test.assert_eq(x, 10)
        test.assert_eq(y, "hello")
        test.assert_near(z, 2.5, 0.01)
    end)
end)

test.describe("Type annotations with expressions", fun ()
    test.it("works with arithmetic expressions", fun ()
        let sum: Int = 10 + 5
        test.assert_eq(sum, 15)
    end)

    test.it("works with string concatenation", fun ()
        let greeting: Str = "Hello" .. " " .. "World"
        test.assert_eq(greeting, "Hello World")
    end)

    test.it("works with function calls", fun ()
        fun double(x)
            x * 2
        end
        let result: Int = double(21)
        test.assert_eq(result, 42)
    end)

    test.it("works with array literals", fun ()
        let nums: Array = [1, 2, 3, 4, 5]
        test.assert_eq(nums.len(), 5)
    end)
end)

test.describe("Scoping", fun ()
    test.it("respects block scope", fun ()
        let outer: Int = 10

        if true
            let inner: Int = 20
            test.assert_eq(inner, 20)
        end

        test.assert_eq(outer, 10)
    end)

    test.it("allows shadowing", fun ()
        let x: Int = 5
        test.assert_eq(x, 5)

        if true
            let x: Str = "shadowed"
            test.assert_eq(x, "shadowed")
        end

        test.assert_eq(x, 5)
    end)
end)

test.describe("Assignment after declaration", fun ()
    test.it("allows reassignment of typed variables", fun ()
        let count: Int = 0
        test.assert_eq(count, 0)

        count = 10
        test.assert_eq(count, 10)

        count += 5
        test.assert_eq(count, 15)
    end)

    test.it("allows reassignment to different value", fun ()
        let x: Int = 100
        x = 200
        x = 300
        test.assert_eq(x, 300)
    end)
end)

test.describe("Custom types", fun ()
    test.it("works with user-defined types", fun ()
        type Person
            pub name: Str
            pub age: Int
        end

        let user: Person = Person.new(name: "Bob", age: 30)
        test.assert_eq(user.name, "Bob")
        test.assert_eq(user.age, 30)
    end)
end)
