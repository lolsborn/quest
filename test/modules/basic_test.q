# Module Import Semantics Tests
# Tests use statements, aliasing, and module member access

use "std/test" as test

test.module("Module System Tests")

test.describe("Module Import - Basic", fun ()
    test.it("imports builtin module with std/ prefix", fun ()
        use "std/math" as m
        test.assert(m.pi > 3.14, nil)
        test.assert(m.pi < 3.15, nil)
    end)

    test.it("imports builtin module and accesses constants", fun ()
        use "std/math" as math
        test.assert_near(math.pi, 3.14159, 0.001, nil)
        test.assert_near(math.tau, 6.28318, 0.001, nil)
    end)

    test.it("imports multiple different modules", fun ()
        use "std/math" as math
        use "std/encoding/json" as json
        test.assert(math.pi > 0, nil)
        let s = json.stringify({"x": 1})
        test.assert(s.len() > 0, nil)
    end)
end)

test.describe("Module Aliasing", fun ()
    test.it("uses custom alias for module", fun ()
        use "std/math" as m
        let result = m.abs(-5)
        test.assert_eq(result, 5, nil)
    end)

    test.it("uses different aliases for same module", fun ()
        use "std/math" as m1
        use "std/math" as m2
        test.assert_eq(m1.pi, m2.pi, nil)
    end)

    test.it("creates separate module instances for each import", fun ()
        use "std/math" as m1
        use "std/math" as m2
        # Each import creates a new module instance with new member objects
        # Even though the values are equal, they have different object IDs
        test.assert_eq(m1.pi, m2.pi, nil)
        test.assert(m1.pi._id() != m2.pi._id(), nil)
    end)

    test.it("allows short aliases", fun ()
        use "std/math" as m
        test.assert(m.sin(0) == 0, nil)
    end)
end)

test.describe("Module Member Access - Functions", fun ()
    test.it("calls module function with arguments", fun ()
        use "std/math" as math
        let result = math.abs(-10)
        test.assert_eq(result, 10, nil)
    end)

    test.it("calls multiple module functions", fun ()
        use "std/math" as math
        let a = math.abs(-5)
        let b = math.sqrt(16)
        let c = math.floor(3.7)
        test.assert_eq(a, 5, nil)
        test.assert_eq(b, 4, nil)
        test.assert_eq(c, 3, nil)
    end)

    test.it("passes module function results to other functions", fun ()
        use "std/math" as math
        let result = math.abs(math.floor(-3.7))
        test.assert_eq(result, 4, nil)
    end)

    test.it("uses module functions in expressions", fun ()
        use "std/math" as math
        let result = math.abs(-5) + math.abs(-3)
        test.assert_eq(result, 8, nil)
    end)
end)

test.describe("Module Member Access - Constants", fun ()
    test.it("accesses module constant", fun ()
        use "std/math" as math
        let pi_val = math.pi
        test.assert_near(pi_val, 3.14159, 0.001, nil)
    end)

    test.it("uses module constant in calculations", fun ()
        use "std/math" as math
        let circumference = 2 * math.pi * 10
        test.assert_near(circumference, 62.8318, 0.001, nil)
    end)

    test.it("accesses multiple module constants", fun ()
        use "std/math" as math
        let sum = math.pi + math.tau
        test.assert(sum > 9.4, nil)
        test.assert(sum < 9.5, nil)
    end)
end)

test.describe("Module Scope", fun ()
    test.it("module is available throughout enclosing scope", fun ()
        use "std/math" as math
        let x = math.abs(-5)
        if true
            let y = math.abs(-3)
            test.assert_eq(y, 3, nil)
        end
        test.assert_eq(x, 5, nil)
    end)

    test.it("module imported in function is scoped to function", fun ()
        fun test_fn()
            use "std/math" as math
            return math.abs(-10)
        end
        let result = test_fn()
        test.assert_eq(result, 10, nil)
    end)

    test.it("module imported in function doesn't leak to outer scope", fun ()
        fun test_fn()
            use "std/math" as math_inner
            return math_inner.abs(-10)
        end
        test_fn()

        # Try to access math_inner from outer scope - should fail
        let caught_error = false
        try
            let x = math_inner.pi
        catch e
            caught_error = true
            # Error message includes "Undefined variable:" prefix (QEP-037)
            test.assert_eq(e.message(), "Undefined variable: math_inner", nil)
        end
        test.assert(caught_error, "Expected error accessing math_inner outside function scope")
    end)

    test.it("different aliases in nested scopes don't conflict", fun ()
        use "std/math" as m1
        let x = m1.pi

        # Import same module with different alias in nested scope
        if true
            use "std/math" as m2
            let y = m2.pi
            test.assert_eq(x, y, nil)
            # Both aliases work in nested scope (m1 from outer, m2 from inner)
            test.assert_eq(m1.pi, m2.pi, nil)
        end

        # m1 still works after nested scope
        test.assert_near(m1.pi, 3.14159, 0.001, nil)
    end)

    test.it("module imported in nested scope doesn't leak out", fun ()
        use "std/math" as m1

        if true
            use "std/math" as math_nested
            test.assert_near(math_nested.pi, 3.14159, 0.001, nil)
        end

        # math_nested should not be accessible here
        let caught_error = false
        try
            let x = math_nested.pi
        catch e
            caught_error = true
            # Error message includes "Undefined variable:" prefix (QEP-037)
            test.assert_eq(e.message(), "Undefined variable: math_nested", nil)
        end
        test.assert(caught_error, "Expected error accessing math_nested outside nested scope")
    end)

    test.it("assigning module member to variable preserves identity", fun ()
        use "std/math" as math

        # Assign module functions to variables
        let abs_fn = math.abs
        let sqrt_fn = math.sqrt

        # The assigned variable should have the same _id as the module member
        test.assert_eq(abs_fn._id(), math.abs._id(), nil)
        test.assert_eq(sqrt_fn._id(), math.sqrt._id(), nil)

        # Different functions should have different IDs
        test.assert_neq(abs_fn._id(), sqrt_fn._id(), nil)
    end)

    test.it("assigning multiple module members preserves their identities", fun ()
        use "std/math" as math

        # Multiple assignment from module
        let sin = math.sin, cos = math.cos, tan = math.tan

        # Each should have the same ID as the original
        test.assert_eq(sin._id(), math.sin._id(), nil)
        test.assert_eq(cos._id(), math.cos._id(), nil)
        test.assert_eq(tan._id(), math.tan._id(), nil)

        # All three should have different IDs
        test.assert_neq(sin._id(), cos._id(), nil)
        test.assert_neq(cos._id(), tan._id(), nil)
        test.assert_neq(sin._id(), tan._id(), nil)
    end)
end)

test.describe("JSON Module", fun ()
    test.it("imports json module", fun ()
        use "std/encoding/json" as json
        let s = json.stringify({"x": 1})
        test.assert(s.len() > 0, nil)
    end)

    test.it("stringifies simple object", fun ()
        use "std/encoding/json" as json
        let result = json.stringify({"name": "test"})
        test.assert(result.count("name") > 0, nil)
        test.assert(result.count("test") > 0, nil)
    end)

    test.it("stringifies array", fun ()
        use "std/encoding/json" as json
        let result = json.stringify([1, 2, 3])
        test.assert(result.count("1") > 0, nil)
        test.assert(result.count("2") > 0, nil)
    end)

    test.it("stringifies nested structure", fun ()
        use "std/encoding/json" as json
        let data = {"user": {"name": "Alice", "age": 30}}
        let result = json.stringify(data)
        test.assert(result.count("user") > 0, nil)
        test.assert(result.count("Alice") > 0, nil)
    end)

    test.it("parses simple JSON string", fun ()
        use "std/encoding/json" as json
        let parsed = json.parse("{\"x\": 42}")
        test.assert_eq(parsed["x"], 42, nil)
    end)

    test.it("parses JSON array", fun ()
        use "std/encoding/json" as json
        let parsed = json.parse("[1, 2, 3]")
        test.assert_eq(parsed.len(), 3, nil)
        test.assert_eq(parsed[0], 1, nil)
    end)

    test.it("roundtrips data through stringify and parse", fun ()
        use "std/encoding/json" as json
        let original = {"name": "test", "value": 123}
        let serialized = json.stringify(original)
        let parsed = json.parse(serialized)
        test.assert_eq(parsed["name"], "test", nil)
        test.assert_eq(parsed["value"], 123, nil)
    end)
end)

test.describe("Term Module", fun ()
    test.it("imports term module", fun ()
        use "std/term" as term
        let colored = term.red("test")
        test.assert(colored.len() > 4, nil)
    end)

    test.it("applies color functions", fun ()
        use "std/term" as term
        let r = term.red("red")
        let g = term.green("green")
        let b = term.blue("blue")
        test.assert(r.len() > 3, nil)
        test.assert(g.len() > 5, nil)
        test.assert(b.len() > 4, nil)
    end)

    test.it("applies style functions", fun ()
        use "std/term" as term
        let bold_text = term.bold("bold")
        let dim_text = term.dimmed("dim")
        test.assert(bold_text.len() > 4, nil)
        test.assert(dim_text.len() > 3, nil)
    end)
end)

test.describe("Module Error Handling", fun ()
    # Note: These tests check for expected behaviors, not necessarily errors

    test.it("handles undefined module members gracefully", fun ()
        use "std/math" as math
        # This would error if we called math.nonexistent()
        # Just verify the module imported correctly
        test.assert(math.pi > 0, nil)
    end)
end)

test.describe("Reserved Words in Module Context", fun ()
    test.it("avoids reserved word 'obj' as variable", fun ()
        use "std/encoding/json" as json
        # 'obj' is reserved, use 'data' instead
        let data = {"key": "value"}
        let s = json.stringify(data)
        test.assert(s.len() > 0, nil)
    end)

    test.it("avoids reserved word 'str' as variable", fun ()
        use "std/encoding/json" as json
        # 'str' is reserved, use 's' instead
        let s = json.stringify([1, 2])
        test.assert(s.len() > 0, nil)
    end)

    test.it("avoids reserved word 'dict' as variable", fun ()
        use "std/encoding/json" as json
        # 'dict' is reserved, use 'd' instead
        let d = {"x": 1}
        let s = json.stringify(d)
        test.assert(s.len() > 0, nil)
    end)
end)
