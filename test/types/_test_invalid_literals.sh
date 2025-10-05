#!/bin/bash
# Automated test script for invalid numeric literal syntax
# Tests that Quest properly rejects malformed numeric literals per QEP-014

set -e

QUEST="${QUEST:-quest}"
FAILED=0
PASSED=0

# Test helper function
test_invalid() {
    local desc="$1"
    local code="$2"

    if echo "$code" | $QUEST >/dev/null 2>&1; then
        echo "  ✗ FAIL: $desc - should have been rejected"
        ((FAILED++))
        return 1
    else
        echo "  ✓ PASS: $desc - properly rejected"
        ((PASSED++))
        return 0
    fi
}

echo "Testing Invalid Numeric Literals (QEP-014 Grammar Fixes)"
echo ""

echo "Consecutive Underscores:"
test_invalid "1__000" "let x = 1__000"
test_invalid "0xFF__00" "let x = 0xFF__00"
test_invalid "0b11__00" "let x = 0b11__00"
test_invalid "0o77__55" "let x = 0o77__55"
test_invalid "1e1__0" "let x = 1e1__0"
test_invalid "3.14__159" "let x = 3.14__159"

echo ""
echo "Trailing Underscores:"
test_invalid "100_" "let x = 100_"
test_invalid "0xFF_" "let x = 0xFF_"
test_invalid "0b1010_" "let x = 0b1010_"
test_invalid "0o755_" "let x = 0o755_"
test_invalid "1e10_" "let x = 1e10_"
test_invalid "3.14_" "let x = 3.14_"

echo ""
echo "Leading Underscores:"
test_invalid "_100" "let x = _100"
test_invalid "0x_FF" "let x = 0x_FF"
test_invalid "0b_1010" "let x = 0b_1010"
test_invalid "0o_755" "let x = 0o_755"

echo ""
echo "Around Decimal Point:"
test_invalid "1_.5" "let x = 1_.5"
# Note: 1._5 parses as method access (1).(_5), not a numeric literal
# This is correct behavior - can't prevent all unusual syntax

echo ""
echo "After Exponent Marker:"
test_invalid "1e_10" "let x = 1e_10"

echo ""
echo "Multiple Trailing Underscores:"
test_invalid "100___" "let x = 100___"
test_invalid "0xFF___" "let x = 0xFF___"

echo ""
echo "Results:"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo "✓ All invalid patterns properly rejected!"
    exit 0
else
    echo ""
    echo "✗ Some invalid patterns were incorrectly accepted"
    exit 1
fi
