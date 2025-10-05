use "std/test" as test


type Point
    num: x
    num: y
end

type Circle
    pub num: radius
end

trait Drawable
    fun draw()
end

trait Serializable
    fun serialize()
end



test.module("Type System - Introspection")

test.describe("Type checking with .is()", fun ()
    test.it("returns true for matching type", fun ()
        let p = Point.new(x: 1, y: 2)
        test.assert_eq(p.is(Point), true, "should match type")
    end)

    test.it("returns false for non-matching type", fun ()
        let p = Point.new(x: 1, y: 2)
        test.assert_eq(p.is(Circle), false, "should not match different type")
    end)
end)

test.describe("Trait checking with .does()", fun ()
    test.it("returns true when trait is implemented", fun ()
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
