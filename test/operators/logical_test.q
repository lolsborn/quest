#!/usr/bin/env quest

use "std/test" as test

test.module("Logical Operators")

test.describe("not operator", fun ()
    test.it("negates true to false", fun ()
        test.assert(not true == false, nil)
    end)

    test.it("negates false to true", fun ()
        test.assert(not false == true, nil)
    end)

    test.it("works with variables", fun ()
        let x = true
        test.assert(not x == false, nil)
        let y = false
        test.assert(not y == true, nil)
    end)

    test.it("supports double negation", fun ()
        test.assert(not not true == true, nil)
        test.assert(not not false == false, nil)
    end)

    test.it("supports triple negation", fun ()
        test.assert(not not not true == false, nil)
        test.assert(not not not false == true, nil)
    end)

    test.it("works with expressions in parentheses", fun ()
        test.assert(not (5 > 3) == false, nil)
        test.assert(not (3 > 5) == true, nil)
    end)

    test.it("works with comparisons", fun ()
        test.assert(not (5 == 5) == false, nil)
        test.assert(not (5 != 5) == true, nil)
    end)

    test.it("negates method results", fun ()
        let nums = [1, 2, 3]
        test.assert(not nums.empty(), nil)
        let empty = []
        let is_empty = empty.empty()
        test.assert(not not is_empty, nil)
    end)
end)

test.describe("and operator", fun ()
    test.it("returns true when both operands are true", fun ()
        test.assert(true and true, nil)
    end)

    test.it("returns false when first operand is false", fun ()
        test.assert(not (false and true), nil)
    end)

    test.it("returns false when second operand is false", fun ()
        test.assert(not (true and false), nil)
    end)

    test.it("returns false when both operands are false", fun ()
        test.assert(not (false and false), nil)
    end)

    test.it("works with variables", fun ()
        let a = true
        let b = false
        test.assert(a and a, nil)
        test.assert(not (a and b), nil)
        test.assert(not (b and a), nil)
        test.assert(not (b and b), nil)
    end)

    test.it("chains multiple conditions", fun ()
        test.assert(true and true and true, nil)
        test.assert(not (true and true and false), nil)
        test.assert(not (false and true and true), nil)
    end)

    test.it("works with comparisons", fun ()
        let x = 5
        let y = 10
        test.assert((x > 3) and (y > 8), nil)
        test.assert(not ((x > 10) and (y > 8)), nil)
    end)
end)

test.describe("or operator", fun ()
    test.it("returns true when both operands are true", fun ()
        test.assert(true or true, nil)
    end)

    test.it("returns true when first operand is true", fun ()
        test.assert(true or false, nil)
    end)

    test.it("returns true when second operand is true", fun ()
        test.assert(false or true, nil)
    end)

    test.it("returns false when both operands are false", fun ()
        test.assert(not (false or false), nil)
    end)

    test.it("works with variables", fun ()
        let a = true
        let b = false
        test.assert(a or a, nil)
        test.assert(a or b, nil)
        test.assert(b or a, nil)
        test.assert(not (b or b), nil)
    end)

    test.it("chains multiple conditions", fun ()
        test.assert(false or false or true, nil)
        test.assert(not (false or false or false), nil)
    end)

    test.it("works with comparisons", fun ()
        let x = 5
        test.assert((x < 3) or (x > 4), nil)
        test.assert(not ((x < 3) or (x > 10)), nil)
    end)
end)

test.describe("not with and/or", fun ()
    test.it("not has higher precedence than and", fun ()
        test.assert(not false and true, "should be (not false) and true")
        test.assert(not (false and true), "parentheses for clarity")
    end)

    test.it("not has higher precedence than or", fun ()
        test.assert(not false or false, "should be (not false) or false")
        test.assert(not (false or false), "parentheses override precedence")
    end)

    test.it("combines not with and", fun ()
        let a = true
        let b = false
        test.assert((not a and b) == false, "not a and b with a=true, b=false")
        test.assert(not (a and b) == true, "not (a and b) with a=true, b=false")
    end)

    test.it("combines not with or", fun ()
        let a = true
        let b = false
        test.assert((not a or b) == false, "not a or b with a=true, b=false")
        test.assert(not (a or b) == false, "not (a or b) with a=true, b=false")
    end)

    test.it("De Morgan's laws: not (a and b) == (not a) or (not b)", fun ()
        let a = true
        let b = false
        test.assert(not (a and b) == ((not a) or (not b)), nil)
    end)

    test.it("De Morgan's laws: not (a or b) == (not a) and (not b)", fun ()
        let a = true
        let b = false
        test.assert(not (a or b) == ((not a) and (not b)), nil)
    end)
end)

test.describe("complex logical expressions", fun ()
    test.it("combines and, or, not with parentheses", fun ()
        test.assert(not ((true and false) or (false and true)), nil)
        test.assert((not false or false) and not false, "should be true")
    end)

    test.it("works with nested conditions", fun ()
        let x = 5
        let y = 10
        let z = 15
        test.assert(((x < y) and (y < z)) or (x == 0), nil)
        test.assert(not ((x > y) and (y > z)) or true, nil)
    end)

    test.it("evaluates complex boolean algebra", fun ()
        let a = true
        let b = false
        let c = true
        test.assert((a or b) and c, nil)
        test.assert(not (a and b and c), nil)
        test.assert((a or b) and (b or c), nil)
    end)

    test.it("works in control flow conditions", fun ()
        let x = 10
        let result = 0

        if (x > 5) and (x < 15)
            result = 1
        end
        test.assert(result == 1, nil)
    end)

    test.it("works with method calls in conditions", fun ()
        let nums = [1, 2, 3, 4, 5]
        test.assert((not nums.empty()) and (nums.len() > 3), nil)
    end)
end)

test.describe("logical operators with truthy/falsy values", fun ()
    test.it("treats zero as false in boolean context", fun ()
        test.assert(not 0, "0 should be falsy")
    end)

    test.it("treats non-zero numbers as true", fun ()
        test.assert(1 and 5, "non-zero numbers should be truthy")
        test.assert(-1 and 99, "negative numbers should be truthy")
    end)

    test.it("treats empty string as false", fun ()
        test.assert(not "", "empty string should be falsy")
    end)

    test.it("treats non-empty string as true", fun ()
        test.assert("hello" and "world", "non-empty strings should be truthy")
    end)

    test.it("treats nil as false", fun ()
        test.assert(not nil, "nil should be falsy")
    end)

    test.it("combines different truthy/falsy types", fun ()
        test.assert(not (0 and 1), "0 and 1 should be falsy")
        test.assert(1 or 0, "1 or 0 should be truthy")
        test.assert(not ("" and "hello"), "empty string and non-empty should be falsy")
    end)
end)

test.describe("operator precedence", fun ()
    test.it("not > and > or", fun ()
        # not false and true or false
        # = (not false) and true or false
        # = true and true or false
        # = true or false
        # = true
        test.assert(not false and true or false, nil)
    end)

    test.it("uses parentheses to override precedence", fun ()
        test.assert(not (false and true) or false, nil)
        test.assert(not false and (true or false), nil)
    end)

    test.it("comparison operators before logical", fun ()
        let x = 5
        test.assert(x > 3 and x < 10, "should be (x > 3) and (x < 10)")
        test.assert(not x > 10 or x < 0, "should be (not (x > 10)) or (x < 0)")
    end)
end)

test.describe("or operator returns values (not booleans)", fun ()
    test.it("returns first truthy value", fun ()
        let result = "hello" or "world"
        test.assert_eq(result, "hello", "Should return first truthy value")
    end)

    test.it("returns second value if first is nil", fun ()
        let result = nil or "default"
        test.assert_eq(result, "default", "Should return second value when first is nil")
    end)

    test.it("returns second value if first is false", fun ()
        let result = false or "backup"
        test.assert_eq(result, "backup", "Should return second value when first is false")
    end)

    test.it("returns first value if truthy", fun ()
        let result = "value" or nil
        test.assert_eq(result, "value", "Should return first truthy value")
    end)

    test.it("returns true when first value is true", fun ()
        let result = true or "ignored"
        test.assert_eq(result, true, "Should return true")
    end)

    test.it("chains multiple values", fun ()
        let result = nil or false or "found"
        test.assert_eq(result, "found", "Should return first truthy in chain")
    end)

    test.it("short-circuits evaluation", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            "incremented"
        end

        let result = "first" or increment()
        test.assert_eq(result, "first", "Should return first")
        test.assert_eq(counter, 0, "Should not evaluate second operand")
    end)

    test.it("evaluates second operand when first is falsy", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            "incremented"
        end

        let result = nil or increment()
        test.assert_eq(result, "incremented", "Should return second")
        test.assert_eq(counter, 1, "Should evaluate second operand")
    end)
end)

test.describe("and operator returns values (not booleans)", fun ()
    test.it("returns second value when both are truthy", fun ()
        let result = "first" and "second"
        test.assert_eq(result, "second", "Should return second value")
    end)

    test.it("returns first value if it's nil", fun ()
        let result = nil and "never"
        test.assert_eq(result, nil, "Should return nil")
    end)

    test.it("returns first value if it's false", fun ()
        let result = false and "never"
        test.assert_eq(result, false, "Should return false")
    end)

    test.it("returns first falsy in chain", fun ()
        let result = "first" and nil and "third"
        test.assert_eq(result, nil, "Should return first falsy value")
    end)

    test.it("returns last value if all truthy", fun ()
        let result = "first" and "second" and "third"
        test.assert_eq(result, "third", "Should return last value")
    end)

    test.it("short-circuits on false", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            "incremented"
        end

        let result = false and increment()
        test.assert_eq(result, false, "Should return false")
        test.assert_eq(counter, 0, "Should not evaluate second operand")
    end)

    test.it("short-circuits on nil", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            "incremented"
        end

        let result = nil and increment()
        test.assert_eq(result, nil, "Should return nil")
        test.assert_eq(counter, 0, "Should not evaluate second operand")
    end)

    test.it("evaluates second operand when first is truthy", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            "incremented"
        end

        let result = "first" and increment()
        test.assert_eq(result, "incremented", "Should return second")
        test.assert_eq(counter, 1, "Should evaluate second operand")
    end)
end)

test.describe("practical use cases", fun ()
    test.it("default value pattern with or", fun ()
        let name = nil
        let display = name or "Anonymous"
        test.assert_eq(display, "Anonymous", "Should use default")

        name = "Alice"
        display = name or "Anonymous"
        test.assert_eq(display, "Alice", "Should use actual value")
    end)

    test.it("chaining fallbacks with or", fun ()
        let user_config = nil
        let system_config = nil
        let default_config = "default"

        let config = user_config or system_config or default_config
        test.assert_eq(config, "default", "Should use first non-nil")
    end)

    test.it("guard pattern with and", fun ()
        let user = {name: "Alice", active: true}

        let result = user["active"] and user["name"]
        test.assert_eq(result, "Alice", "Should return name if active")

        user["active"] = false
        result = user["active"] and user["name"]
        test.assert_eq(result, false, "Should return false if not active")
    end)
end)
