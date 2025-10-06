# Const Keyword Tests - QEP-017
# Tests the const keyword for immutable constants

use "std/test" as test

test.module("Const Keyword (QEP-017)")

test.describe("Basic const declaration", fun ()
    test.it("declares constant", fun ()
        const X = 42
        test.assert_eq(X, 42, "Const should have declared value")
    end)

    test.it("allows multiple constants", fun ()
        const A = 1
        const B = 2
        const C = 3
        test.assert_eq(A + B + C, 6, "Multiple constants should work")
    end)

    test.it("works with different types", fun ()
        const INT_VAL = 42
        const FLOAT_VAL = 3.14
        const STR_VAL = "hello"
        const BOOL_VAL = true

        test.assert_eq(INT_VAL.cls(), "Int", "Int constant")
        test.assert_eq(FLOAT_VAL.cls(), "Float", "Float constant")
        test.assert_eq(STR_VAL.cls(), "Str", "Str constant")
        test.assert_eq(BOOL_VAL.cls(), "Bool", "Bool constant")
    end)

    test.it("works with arrays", fun ()
        const ARR = [1, 2, 3]
        test.assert_eq(ARR.len(), 3, "Array constant")
    end)

    test.it("works with dicts", fun ()
        const DICT = {"key": "value"}
        test.assert_eq(DICT.get("key"), "value", "Dict constant")
    end)
end)

test.describe("Const immutability", fun ()
    test.it("prevents reassignment", fun ()
        const X = 10

        let caught = false
        try
            X = 20
        catch e
            if e.message().contains("Cannot reassign constant")
                caught = true
            end
        end

        test.assert(caught, "Should prevent reassignment")
    end)

    test.it("prevents compound assignment with +=", fun ()
        const X = 10

        let caught = false
        try
            X += 5
        catch e
            if e.message().contains("Cannot modify constant")
                caught = true
            end
        end

        test.assert(caught, "Should prevent += on const")
    end)

    test.it("prevents compound assignment with -=", fun ()
        const X = 10

        let caught = false
        try
            X -= 5
        catch e
            caught = true
        end

        test.assert(caught, "Should prevent -= on const")
    end)

    test.it("prevents compound assignment with *=", fun ()
        const X = 10

        let caught = false
        try
            X *= 2
        catch e
            caught = true
        end

        test.assert(caught, "Should prevent *= on const")
    end)

    test.it("prevents compound assignment with /=", fun ()
        const X = 10

        let caught = false
        try
            X /= 2
        catch e
            caught = true
        end

        test.assert(caught, "Should prevent /= on const")
    end)
end)

test.describe("Const initialization", fun ()
    test.it("can initialize with expressions", fun ()
        const A = 5 + 5
        const B = 10 * 2
        const C = "Hello" .. " World"

        test.assert_eq(A, 10, "Expression evaluation")
        test.assert_eq(B, 20, "Multiplication expression")
        test.assert_eq(C, "Hello World", "String concatenation")
    end)

    test.it("can reference other constants", fun ()
        const X = 10
        const Y = X * 2
        const Z = Y + X

        test.assert_eq(Z, 30, "Can use constants in initialization")
    end)

    test.it("can reference variables", fun ()
        let x = 5
        const DOUBLED = x * 2

        test.assert_eq(DOUBLED, 10, "Can reference variables")
    end)
end)

test.describe("Const scoping", fun ()
    test.it("respects function scope", fun ()
        const OUTER = 100

        fun test_func()
            const INNER = 200
            OUTER + INNER
        end

        test.assert_eq(test_func(), 300, "Function can access outer const")
    end)

    test.it("allows shadowing in nested scopes", fun ()
        const X = 10

        let inner_x = nil
        if true
            const X = 20
            inner_x = X
        end

        test.assert_eq(inner_x, 20, "Inner X should be 20")
        test.assert_eq(X, 10, "Outer X should still be 10")
    end)

    test.it("shadowed constant is independent", fun ()
        const X = 10

        let caught = false
        if true
            const X = 20
            try
                X = 30
            catch e
                caught = true
            end
        end

        test.assert(caught, "Shadowed const should also be immutable")
        test.assert_eq(X, 10, "Outer X unchanged")
    end)

    test.it("constants can shadow variables", fun ()
        let x = 5

        if true
            const x = 10
            test.assert_eq(x, 10, "Const shadows variable")

            let caught = false
            try
                x = 20
            catch e
                caught = true
            end
            test.assert(caught, "Shadowing const is immutable")
        end

        # Outer x is still a variable
        x = 15
        test.assert_eq(x, 15, "Outer variable can still be reassigned")
    end)
end)

test.describe("Const with reference types (shallow immutability)", fun ()
    test.it("prevents rebinding of arrays", fun ()
        const ARR = [1, 2, 3]

        let caught = false
        try
            ARR = [4, 5, 6]
        catch e
            caught = true
        end

        test.assert(caught, "Cannot rebind array constant")
    end)

    test.it("allows mutating array contents", fun ()
        const ARR = [1, 2, 3]
        ARR.push(4)

        test.assert_eq(ARR.len(), 4, "Array should have 4 elements")
        test.assert_eq(ARR.get(3), 4, "New element should be 4")
    end)

    test.it("prevents rebinding of dicts", fun ()
        const CONFIG = {"debug": true}

        let caught = false
        try
            CONFIG = {"debug": false}
        catch e
            caught = true
        end

        test.assert(caught, "Cannot rebind dict constant")
    end)

    test.it("allows calling methods on dict constants", fun ()
        const CONFIG = {"debug": true, "mode": "prod"}
        # Can call methods on const dicts (shallow immutability)
        let val = CONFIG.get("debug")
        test.assert_eq(val, true, "Can read from const dict")
        test.assert_eq(CONFIG.len(), 2, "Can call len() on const dict")
    end)
end)

test.describe("Const vs let", fun ()
    test.it("let allows reassignment, const doesn't", fun ()
        let x = 5
        const Y = 10

        # let can be reassigned
        x = 10
        test.assert_eq(x, 10, "let variable can be reassigned")

        # const cannot
        let caught = false
        try
            Y = 20
        catch e
            caught = true
        end
        test.assert(caught, "const cannot be reassigned")
    end)

    test.it("can have let and const with same name in different scopes", fun ()
        let x = 5

        if true
            const x = 10
            test.assert_eq(x, 10, "const shadows let")
        end

        x = 15
        test.assert_eq(x, 15, "let still mutable outside")
    end)
end)

test.describe("Real-world usage", fun ()
    test.it("mathematical constants", fun ()
        const PI = 3.14159
        const E = 2.71828
        const TAU = 2.0 * PI

        let circle_area = fun (r)
            PI * r.to_f64() * r.to_f64()
        end

        test.assert(circle_area(10) > 314.0, "Circle area calculation")
    end)

    test.it("configuration constants", fun ()
        const MAX_RETRIES = 3
        const TIMEOUT_MS = 5000
        const BASE_URL = "https://api.example.com"

        fun make_request()
            let retries = 0
            while retries < MAX_RETRIES
                retries += 1
            end
            retries
        end

        test.assert_eq(make_request(), 3, "Config constants in logic")
    end)

    test.it("enum-like constants", fun ()
        const STATUS_PENDING = 0
        const STATUS_ACTIVE = 1
        const STATUS_COMPLETE = 2

        let current_status = STATUS_ACTIVE
        test.assert_eq(current_status, 1, "Enum-like constant usage")
    end)
end)
