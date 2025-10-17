use "std/test"

test.module("Match Range Patterns (QEP-058)")

test.describe("Basic range matching", fun ()
    test.it("matches inclusive ranges with 'to'", fun ()
        fun check(n)
            match n
            in 0 to 10
                "low"
            in 11 to 20
                "high"
            else
                "other"
            end
        end

        test.assert_eq(check(0), "low")
        test.assert_eq(check(5), "low")
        test.assert_eq(check(10), "low")
        test.assert_eq(check(11), "high")
        test.assert_eq(check(20), "high")
        test.assert_eq(check(21), "other")
    end)

    test.it("matches exclusive ranges with 'until'", fun ()
        fun check(n)
            match n
            in 0 until 10
                "low"
            in 10 until 20
                "high"
            end
        end

        test.assert_eq(check(0), "low")
        test.assert_eq(check(9), "low")
        test.assert_eq(check(10), "high")
        test.assert_eq(check(19), "high")
        test.assert_eq(check(20), nil)
    end)

    test.it("distinguishes between to and until", fun ()
        fun check_to(n)
            match n
            in 1 to 3
                "matched"
            else
                "not matched"
            end
        end

        fun check_until(n)
            match n
            in 1 until 3
                "matched"
            else
                "not matched"
            end
        end

        # 'to' is inclusive of end
        test.assert_eq(check_to(3), "matched")

        # 'until' is exclusive of end
        test.assert_eq(check_until(3), "not matched")
    end)
end)

test.describe("Step patterns", fun ()
    test.it("matches even numbers with step", fun ()
        fun check(n)
            match n
            in 0 to 100 step 2
                "even"
            in 1 to 100 step 2
                "odd"
            else
                "other"
            end
        end

        test.assert_eq(check(0), "even")
        test.assert_eq(check(42), "even")
        test.assert_eq(check(1), "odd")
        test.assert_eq(check(17), "odd")
        test.assert_eq(check(101), "other")
    end)

    test.it("matches multiples of 5", fun ()
        fun check(n)
            match n
            in 0 to 100 step 5
                "multiple of 5"
            else
                "not multiple of 5"
            end
        end

        test.assert_eq(check(0), "multiple of 5")
        test.assert_eq(check(25), "multiple of 5")
        test.assert_eq(check(100), "multiple of 5")
        test.assert_eq(check(23), "not multiple of 5")
    end)

    test.it("step works with until", fun ()
        fun check(n)
            match n
            in 0 until 10 step 3
                "matched"
            else
                "not matched"
            end
        end

        test.assert_eq(check(0), "matched")
        test.assert_eq(check(3), "matched")
        test.assert_eq(check(6), "matched")
        test.assert_eq(check(9), "matched")
        test.assert_eq(check(10), "not matched")
        test.assert_eq(check(1), "not matched")
    end)
end)

test.describe("Negative ranges", fun ()
    test.it("matches negative numbers", fun ()
        fun check(temp)
            match temp
            in -10 to -1
                "below freezing"
            in 0 to 10
                "cold"
            else
                "other"
            end
        end

        test.assert_eq(check(-5), "below freezing")
        test.assert_eq(check(-1), "below freezing")
        test.assert_eq(check(0), "cold")
        test.assert_eq(check(5), "cold")
        test.assert_eq(check(11), "other")
    end)

    test.it("handles ranges spanning negative to positive", fun ()
        fun check(n)
            match n
            in -5 to 5
                "near zero"
            else
                "far from zero"
            end
        end

        test.assert_eq(check(-5), "near zero")
        test.assert_eq(check(0), "near zero")
        test.assert_eq(check(5), "near zero")
        test.assert_eq(check(-6), "far from zero")
        test.assert_eq(check(6), "far from zero")
    end)
end)

test.describe("Mixed patterns", fun ()
    test.it("combines ranges and discrete values", fun ()
        fun check(code)
            match code
            in 200, 201, 204
                "success"
            in 400 to 499
                "client error"
            in 500 to 599
                "server error"
            else
                "other"
            end
        end

        test.assert_eq(check(200), "success")
        test.assert_eq(check(201), "success")
        test.assert_eq(check(204), "success")
        test.assert_eq(check(404), "client error")
        test.assert_eq(check(500), "server error")
        test.assert_eq(check(100), "other")
    end)

    test.it("multiple range arms", fun ()
        fun check(n)
            match n
            in 1 to 10
                "first"
            in 20 to 30
                "second"
            in 40 to 50
                "third"
            else
                "none"
            end
        end

        test.assert_eq(check(5), "first")
        test.assert_eq(check(25), "second")
        test.assert_eq(check(45), "third")
        test.assert_eq(check(15), "none")
    end)
end)

test.describe("Type safety - Float", fun ()
    test.it("works with Float ranges", fun ()
        fun check(x)
            match x
            in 0.0 to 1.0
                "unit"
            else
                "other"
            end
        end

        test.assert_eq(check(0.0), "unit")
        test.assert_eq(check(0.5), "unit")
        test.assert_eq(check(1.0), "unit")
        test.assert_eq(check(1.1), "other")
    end)

    test.it("promotes Int to Float for comparison", fun ()
        fun check(x)
            match x
            in 0.0 to 100.0
                "matches"
            else
                "other"
            end
        end

        test.assert_eq(check(42), "matches")
        test.assert_eq(check(0), "matches")
        test.assert_eq(check(100), "matches")
        test.assert_eq(check(101), "other")
    end)

    test.it("Float value matches Int range", fun ()
        fun check(x)
            match x
            in 0 to 10
                "matches"
            else
                "other"
            end
        end

        test.assert_eq(check(5.5), "matches")
        test.assert_eq(check(0.1), "matches")
        test.assert_eq(check(10.0), "matches")
    end)
end)

test.describe("Type safety - errors", fun ()
    test.it("raises error for non-numeric types", fun ()
        fun check(x)
            match x
            in 0 to 10
                "number"
            end
        end

        test.assert_raises(TypeErr, fun () check("hello") end)
        test.assert_raises(TypeErr, fun () check(true) end)
        test.assert_raises(TypeErr, fun () check([1, 2, 3]) end)
    end)

    test.it("raises error for non-numeric range bounds", fun ()
        fun check_str()
            match 5
            in "a" to "z"
                "matched"
            end
        end

        test.assert_raises(TypeErr, fun () check_str() end)
    end)

    test.it("rejects step with Float", fun ()
        fun check(x)
            match x
            in 0.0 to 1.0 step 0.1
                "matches"
            end
        end

        test.assert_raises(TypeErr, fun () check(0.5) end)
    end)
end)

test.describe("Edge cases", fun ()
    test.it("handles single-value ranges with 'to'", fun ()
        fun check(n)
            match n
            in 5 to 5
                "five"
            end
        end

        test.assert_eq(check(5), "five")
        test.assert_eq(check(4), nil)
        test.assert_eq(check(6), nil)
    end)

    test.it("handles empty ranges (start > end)", fun ()
        fun check(n)
            match n
            in 10 to 1
                "never"
            else
                "always"
            end
        end

        test.assert_eq(check(5), "always")
        test.assert_eq(check(1), "always")
        test.assert_eq(check(10), "always")
    end)

    test.it("handles empty 'until' ranges (start == end)", fun ()
        fun check(n)
            match n
            in 10 until 10
                "never"
            else
                "always"
            end
        end

        test.assert_eq(check(10), "always")
        test.assert_eq(check(9), "always")
    end)

    test.it("first match wins for overlapping ranges", fun ()
        fun check(n)
            match n
            in 0 to 100
                "first"
            in 25 to 75
                "second"
            end
        end

        test.assert_eq(check(50), "first")
        test.assert_eq(check(0), "first")
        test.assert_eq(check(100), "first")
    end)

    test.it("rejects zero step", fun ()
        fun check(n)
            match n
            in 0 to 100 step 0
                "never"
            end
        end

        test.assert_raises(ValueErr, fun () check(50) end)
    end)

    test.it("rejects negative step", fun ()
        fun check(n)
            match n
            in 0 to 100 step -2
                "never"
            end
        end

        test.assert_raises(ValueErr, fun () check(50) end)
    end)
end)

test.describe("Real-world examples", fun ()
    test.it("grade calculator", fun ()
        fun grade(score)
            match score
            in 90 to 100
                "A"
            in 80 until 90
                "B"
            in 70 until 80
                "C"
            in 60 until 70
                "D"
            else
                "F"
            end
        end

        test.assert_eq(grade(95), "A")
        test.assert_eq(grade(90), "A")
        test.assert_eq(grade(85), "B")
        test.assert_eq(grade(75), "C")
        test.assert_eq(grade(65), "D")
        test.assert_eq(grade(55), "F")
    end)

    test.it("age categorization", fun ()
        fun describe_age(age)
            match age
            in 0 to 12
                "child"
            in 13 to 19
                "teenager"
            in 20 to 64
                "adult"
            else
                "senior"
            end
        end

        test.assert_eq(describe_age(7), "child")
        test.assert_eq(describe_age(15), "teenager")
        test.assert_eq(describe_age(45), "adult")
        test.assert_eq(describe_age(70), "senior")
    end)

    test.it("time of day", fun ()
        fun time_of_day(hour)
            match hour
            in 0 until 6
                "night"
            in 6 until 12
                "morning"
            in 12 until 18
                "afternoon"
            in 18 until 24
                "evening"
            else
                "invalid"
            end
        end

        test.assert_eq(time_of_day(3), "night")
        test.assert_eq(time_of_day(8), "morning")
        test.assert_eq(time_of_day(14), "afternoon")
        test.assert_eq(time_of_day(20), "evening")
    end)
end)

test.describe("BigInt support", fun ()
    test.it("matches BigInt ranges", fun ()
        fun check(n)
            match n
            in 0n to 100n
                "small"
            in 1000n to 10000n
                "medium"
            else
                "other"
            end
        end

        test.assert_eq(check(50n), "small")
        test.assert_eq(check(5000n), "medium")
        test.assert_eq(check(100000n), "other")
    end)

    test.it("BigInt with step", fun ()
        fun check(n)
            match n
            in 0n to 100n step 10n
                "multiple of 10"
            else
                "not multiple of 10"
            end
        end

        test.assert_eq(check(0n), "multiple of 10")
        test.assert_eq(check(50n), "multiple of 10")
        test.assert_eq(check(100n), "multiple of 10")
        test.assert_eq(check(55n), "not multiple of 10")
    end)

    test.it("rejects BigInt with Int range", fun ()
        fun check(n)
            match n
            in 0 to 100
                "matched"
            end
        end

        test.assert_raises(TypeErr, fun () check(42n) end)
    end)
end)

test.describe("Decimal support", fun ()
    test.it("matches Decimal ranges", fun ()
        let d_zero = Decimal.zero()
        let d_one = Decimal.new("1.0")
        let d_half = Decimal.new("0.5")

        fun check(d)
            match d
            in Decimal.zero() to Decimal.new("1.0")
                "unit"
            else
                "other"
            end
        end

        test.assert_eq(check(d_zero), "unit")
        test.assert_eq(check(d_half), "unit")
        test.assert_eq(check(d_one), "unit")
        test.assert_eq(check(Decimal.new("1.5")), "other")
    end)

    test.it("rejects Decimal with step", fun ()
        fun check(d)
            match d
            in Decimal.zero() to Decimal.new("1.0") step Decimal.new("0.1")
                "matched"
            end
        end

        test.assert_raises(TypeErr, fun () check(Decimal.new("0.5")) end)
    end)
end)

test.describe("Performance and evaluation", fun ()
    test.it("evaluates match value only once", fun ()
        let counter = 0
        fun increment_and_return()
            counter = counter + 1
            counter
        end

        fun test_match()
            match increment_and_return()
            in 1 to 5
                "matched"
            else
                "not matched"
            end
        end

        test_match()
        test.assert_eq(counter, 1)
    end)

    test.it("stops at first matching range", fun ()
        let eval_count = 0
        fun track_eval(val)
            eval_count = eval_count + 1
            val
        end

        fun test_match(x)
            match x
            in track_eval(1) to track_eval(10)
                "first"
            in track_eval(5) to track_eval(15)
                "second"
            end
        end

        test_match(5)
        # Should only evaluate first range (2 evals for start and end)
        test.assert_eq(eval_count, 2)
    end)
end)
