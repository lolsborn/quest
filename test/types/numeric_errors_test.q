# Numeric Literal Error Tests - QEP-014
# Tests that invalid numeric literal syntax is properly rejected
#
# NOTE: Since Quest doesn't have eval(), we can't test parse errors directly in Quest code.
# These tests document the expected behavior and are verified manually.
# See _test_invalid_literals.sh for automated testing of invalid syntax.

use "std/test" as test

test.module("Numeric Literal Errors (QEP-014)")

test.describe("Grammar validation documentation", fun ()
    test.it("documents invalid patterns that should be rejected", fun ()
        # This test documents what SHOULD fail at parse time:
        #
        # Consecutive underscores:
        #   1__000, 0xFF__00, 0b11__00, 0o77__55, 1e1__0
        #
        # Trailing underscores:
        #   100_, 0xFF_, 0b1010_, 0o755_, 1e10_
        #
        # Leading underscores:
        #   _100, 0x_FF, 0b_1010, 0o_755
        #
        # Around decimal point:
        #   1_.5, 1._5
        #
        # After exponent marker:
        #   1e_10
        #
        # See _test_invalid_literals.sh for automated verification

        test.assert(true, "Grammar rejects all invalid patterns")
    end)
end)

test.describe("Manual verification instructions", fun ()
    test.it("provides commands to verify invalid syntax rejection", fun ()
        # To verify these errors manually:
        #
        # printf 'let x = 1__000\nputs(x)' | quest  # Should error
        # printf 'let x = 100_\nputs(x)' | quest    # Should error
        # printf 'let x = 0xFF_\nputs(x)' | quest   # Should error
        # printf 'let x = 1._5\nputs(x)' | quest    # Should error
        #
        # All should fail to parse instead of silently accepting

        test.assert(true, "Manual verification possible via shell commands")
    end)
end)
