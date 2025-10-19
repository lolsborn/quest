use "std/test" as test

test.module("Type System - Methods")

test.describe("Instance methods", fun ()
    test.it("calls method with self access", fun ()
        type Point
            x: Num
            y: Num

            fun sum()
                self.x + self.y
            end
        end

        let p = Point.new(x: 3, y: 4)
        test.assert_eq(p.sum(), 7, "sum should be 7")
    end)

    test.it("calls method that returns computed value", fun ()
        type Point
            x: Num
            y: Num

            fun product()
                self.x * self.y
            end
        end

        let p = Point.new(x: 5, y: 6)
        test.assert_eq(p.product(), 30, "product should be 30")
    end)
end)

test.describe("Class methods", fun ()
    test.it("calls class method", fun ()
        type Math
            fun self.double(x)
                x * 2
            end
        end

        test.assert_eq(Math.double(5), 10, "double(5) should be 10")
    end)

    test.it("creates instance from class factory method", fun ()
        type Point
            pub x: Num
            pub y: Num

            fun self.origin()
                Point.new(x: 0, y: 0)
            end
        end

        let p = Point.origin()
        test.assert_eq(p.x, 0, "x should be 0")
        test.assert_eq(p.y, 0, "y should be 0")
    end)
end)
