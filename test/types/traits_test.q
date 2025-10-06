use "std/test" as test

test.module("Type System - Traits")

test.describe("Single trait", fun ()
    test.it("implements trait method", fun ()
        trait Drawable
            fun draw()
        end

        type Circle
            radius: num

            impl Drawable
                fun draw()
                    "Circle"
                end
            end
        end

        let c = Circle.new(radius: 5)
        test.assert_eq(c.draw(), "Circle", "draw should return Circle")
    end)
end)

test.describe("Multiple traits", fun ()
    test.it("implements multiple traits", fun ()
        trait Drawable
            fun draw()
        end

        trait Serializable
            fun serialize()
        end

        type Shape
            name: str

            impl Drawable
                fun draw()
                    "Drawing"
                end
            end

            impl Serializable
                fun serialize()
                    "Serialized"
                end
            end
        end

        let s = Shape.new(name: "Square")
        test.assert_eq(s.draw(), "Drawing", "draw should work")
        test.assert_eq(s.serialize(), "Serialized", "serialize should work")
    end)
end)
