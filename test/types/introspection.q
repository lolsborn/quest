use "std/test" as test

test.module("Type System - Introspection")

test.describe("Type checking with .is()", fun ()
    test.it("returns true for matching type", fun ()
        type Point
            num: x
            num: y
        end

        let p = Point.new(x: 1, y: 2)
        test.assert_eq(p.is(Point), true, "should match type")
    end)

    test.it("returns false for non-matching type", fun ()
        type Point
            num: x
            num: y
        end

        type Circle
            num: radius
        end

        let p = Point.new(x: 1, y: 2)
        test.assert_eq(p.is(Circle), false, "should not match different type")
    end)
end)

test.describe("Trait checking with .does()", fun ()
    test.it("returns true when trait is implemented", fun ()
        trait Drawable
            fun draw()
        end

        type Circle
            num: radius

            impl Drawable
                fun draw()
                    "Drawing"
                end
            end
        end

        let c = Circle.new(radius: 5)
        test.assert_eq(c.does(Drawable), true, "should implement trait")
    end)

    test.it("returns false when trait is not implemented", fun ()
        trait Drawable
            fun draw()
        end

        trait Serializable
            fun serialize()
        end

        type Circle
            num: radius

            impl Drawable
                fun draw()
                    "Drawing"
                end
            end
        end

        let c = Circle.new(radius: 5)
        test.assert_eq(c.does(Serializable), false, "should not implement unimplemented trait")
    end)
end)

test.describe("Immutable updates with .update()", fun ()
    test.it("creates new instance with updated field", fun ()
        type Point
            num: x
            num: y
        end

        let p1 = Point.new(x: 1, y: 2)
        let p2 = p1.update(x: 5)

        test.assert_eq(p1.x, 1, "original unchanged")
        test.assert_eq(p2.x, 5, "new has updated value")
        test.assert_eq(p2.y, 2, "other fields copied")
    end)

    test.it("updates multiple fields", fun ()
        type Point
            num: x
            num: y
        end

        let p1 = Point.new(x: 1, y: 2)
        let p2 = p1.update(x: 10, y: 20)

        test.assert_eq(p2.x, 10, "x updated correctly")
        test.assert_eq(p2.y, 20, "y updated correctly")
    end)
end)
