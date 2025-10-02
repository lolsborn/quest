#!/bin/bash
# Comprehensive test runner that runs all Quest tests

set -e  # Exit on error

echo "Running Quest Test Suite"
echo "========================"
echo

# Run main test suite
echo "Running main test suite..."
./target/release/quest test/run.q
MAIN_EXIT=$?

echo
echo "Running sys module tests (standalone)..."
./target/release/quest test/sys/basic.q
SYS_EXIT=$?

echo
echo "========================"
if [ $MAIN_EXIT -eq 0 ] && [ $SYS_EXIT -eq 0 ]; then
    echo "✓ All test suites passed!"
    exit 0
else
    echo "✗ Some tests failed"
    exit 1
fi
