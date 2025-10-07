# Regression Test: Bug 005 - Literal Keyword Prefix Identifiers
# 
# Bug Description:
#   Identifiers that start with the literal keywords `nil`, `true`, or `false`
#   (without an underscore separator) failed to parse, while identifiers starting
#   with other keywords worked fine.
# 
#   Examples that failed:
#     - let nilable = 1
#     - let truely = 2
#     - let falsey = 3
# 
# Solution:
#   Fixed the grammar in quest.pest to allow literal keywords to be prefixes of
#   longer identifiers, treating them the same way as control flow keywords.
# 
# Status: Fixed - 2025-10-03


use "std/test" as test

test.module("Regression: Bug 005 - Literal Keyword Prefix Identifiers")

test.describe("Identifiers starting with literal keywords", fun ()
    test.it("allows identifiers starting with 'nil'", fun ()
        let nilable = 1
        test.assert_eq(nilable, 1)    end)

    test.it("allows identifiers starting with 'true'", fun ()
        let truely = 2
        test.assert_eq(truely, 2)    end)

    test.it("allows identifiers starting with 'false'", fun ()
        let falsey = 3
        test.assert_eq(falsey, 3)    end)

    test.it("still allows underscore-separated identifiers", fun ()
        let nil_value = 4
        let true_flag = 5
        let false_flag = 6
        test.assert_eq(nil_value, 4)        test.assert_eq(true_flag, 5)        test.assert_eq(false_flag, 6)    end)

    test.it("preserves actual literal keyword behavior", fun ()
        let x = nil
        let y = true
        let z = false
        test.assert_nil(x)        test.assert_eq(y, true)        test.assert_eq(z, false)    end)
end)
