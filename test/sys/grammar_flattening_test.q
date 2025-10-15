use "std/test"

test.describe("QEP-048: Grammar flattening regression tests", fun ()
    test.it("handles multiple logical NOT operators", fun ()
        # Single negation
        test.assert_eq(not true, false)
        test.assert_eq(not false, true)

        # Double negation (should cancel out)
        test.assert_eq(not not true, true)
        test.assert_eq(not not false, false)

        # Triple negation
        test.assert_eq(not not not true, false)
        test.assert_eq(not not not false, true)

        # Quadruple negation
        test.assert_eq(not not not not true, true)
        test.assert_eq(not not not not false, false)
    end)

    test.it("handles multiple unary minus operators", fun ()
        # Single negation
        test.assert_eq(-5, -5)
        test.assert_eq(-(-5), 5)

        # Double negation
        test.assert_eq(--5, 5)
        test.assert_eq(--(-5), -5)

        # Triple negation
        test.assert_eq(---5, -5)
        test.assert_eq(---(-5), 5)

        # Quadruple negation
        test.assert_eq(----5, 5)
    end)

    test.it("handles multiple unary plus operators", fun ()
        # Unary plus is identity operation
        test.assert_eq(+5, 5)
        test.assert_eq(++5, 5)
        test.assert_eq(+++5, 5)
        test.assert_eq(++++5, 5)
    end)

    test.it("handles mixed unary operators", fun ()
        # Plus and minus
        test.assert_eq(+-5, -5)
        test.assert_eq(-+5, -5)
        test.assert_eq(+-+-5, 5)
        test.assert_eq(-+-+5, 5)
    end)

    test.it("handles bitwise NOT with multiple operators", fun ()
        # Single bitwise NOT
        test.assert_eq(~0, -1)
        test.assert_eq(~-1, 0)

        # Double bitwise NOT (should restore original)
        test.assert_eq(~~0, 0)
        test.assert_eq(~~5, 5)
        test.assert_eq(~~42, 42)

        # Triple bitwise NOT
        test.assert_eq(~~~0, -1)
        test.assert_eq(~~~5, ~5)
    end)

    test.it("handles mixed unary and logical NOT operators", fun ()
        # Unary minus with logical NOT
        let x = 5
        test.assert_eq(not -x < 0, false)  # -x < 0 is true, not true is false

        # Logical NOT with comparison
        test.assert_eq(not not 1 < 2, true)  # 1 < 2 is true, not not true is true
    end)

    test.it("preserves operator precedence with flattened grammar", fun ()
        # Unary minus has higher precedence than addition
        test.assert_eq(-5 + 3, -2)
        test.assert_eq(3 + -5, -2)

        # Multiple unary operators maintain precedence
        test.assert_eq(--5 + 3, 8)
        test.assert_eq(---5 + 10, 5)

        # Logical NOT has lower precedence than comparison
        test.assert_eq(not 5 < 3, true)  # (5 < 3) is false, not false is true
        test.assert_eq(not 10 > 20, true)  # (10 > 20) is false, not false is true
    end)

    test.it("handles deeply nested expressions without stack overflow", fun ()
        # Build a deeply nested expression with unary operators
        # The flattened grammar should handle this efficiently
        let result = ------5  # 6 unary minuses
        test.assert_eq(result, 5)

        let result2 = --------10  # 8 unary minuses
        test.assert_eq(result2, 10)
    end)

    test.it("handles complex boolean expressions with multiple NOTs", fun ()
        let a = true
        let b = false

        # Complex expression with multiple logical NOTs
        test.assert_eq(not not a or not b, true)
        test.assert_eq(not (not a and not b), true)
        test.assert_eq(not not not a or not not b, false)
    end)

    test.it("handles lambda expressions in flattened expression_statement", fun ()
        # Lambda expressions should still work in expression statements
        let add = fun (x, y) x + y end
        test.assert_eq(add(3, 4), 7)

        # Lambda with unary operators
        let negate = fun (x) -x end
        test.assert_eq(negate(5), -5)
        test.assert_eq(negate(-5), 5)

        # Lambda with logical NOT
        let invert = fun (x) not x end
        test.assert_eq(invert(true), false)
        test.assert_eq(invert(false), true)
    end)

    test.it("handles elvis operator with flattened grammar", fun ()
        # Elvis operator should still work correctly
        test.assert_eq(nil ?: "default", "default")
        test.assert_eq(0 ?: "default", 0)
        test.assert_eq("value" ?: "default", "value")

        # Elvis with unary operators
        test.assert_eq(nil ?: -5, -5)
    end)

    test.it("handles expression_statement without intermediate lambda_expr wrapper", fun ()
        # Simple expression statements should work
        let x = 5
        let y = x + 3
        test.assert_eq(y, 8)

        # Expression statement with multiple operators
        let z = --5 + ~~3
        test.assert_eq(z, 8)

        # Expression statement with logical operators
        let result = not false and not false
        test.assert_eq(result, true)
    end)

end)
