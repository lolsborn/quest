# Quest Test Suite

Comprehensive test suite for the Quest programming language.

## Running Tests

### Automated Test Suite

Run all automated tests:
```bash
./target/release/quest test/run.q
```

Run with no colors (useful for CI):
```bash
./target/release/quest test/run.q --no-color
```

### Manual Tests

See [MANUAL_TESTS.md](MANUAL_TESTS.md) for information about manual test files.

## Test Organization

### Automated Tests (336 tests)

All automated tests are organized by category in subdirectories:

| Directory | Tests | Coverage |
|-----------|-------|----------|
| **math/** | 57 | Arithmetic operations, trigonometric functions, special angle values, identities |
| **string/** | 75 | String methods, interpolation, formatting, type checks, encoding |
| **arrays/** | 34 | Array operations, higher-order functions (map, filter, reduce), iteration |
| **dict/** | 34 | Dictionary operations, key/value access, iteration, nested structures |
| **bool/** | 44 | Boolean logic, comparison operators, conditionals, logical operations |
| **modules/** | 33 | Module imports, aliasing, JSON parsing, terminal colors |
| **operators/** | 19 | Compound assignment operators (+=, -=, *=, /=, %=) |
| **functions/** | 40 | User-defined functions, lambdas, closures, recursion, higher-order |

### Manual Tests (5 files)

Manual test files for features that require visual inspection or have side effects:

- `del_test.q` - Variable deletion
- `glob_test.q` - File pattern matching
- `hash_test.q` - Cryptographic hashes (not yet implemented)
- `os_test.q` - Operating system operations
- `term_test.q` - Terminal colors and styling

See [MANUAL_TESTS.md](MANUAL_TESTS.md) for details.

### Test Files Not Yet Integrated

- `io/basic.q` - IO operations (needs cleanup support)
- `sys/basic.q` - System module (scope limitations)

## Test Framework

Tests use the Quest test framework located at `std/test.q`:

```quest
use "std/test" as test

test.describe("Feature Name", fun ()
    test.it("does something", fun ()
        test.assert(condition, "description")
    end)
end)
```

### Available Assertions

- `test.assert(condition, message)` - Basic assertion
- `test.assert_eq(actual, expected)` - Equality assertion (future)

## Adding New Tests

1. Create a new test file in the appropriate subdirectory
2. Use the test framework structure shown above
3. Import the test file in `run.q`:
   ```quest
   test.module("Running Your Tests...")
   use "test/your_category/your_test" as your_test
   ```

## Test Statistics

- **Total Tests**: 336
- **Pass Rate**: 100%
- **Coverage**: Core language features, standard library modules
- **Execution Time**: ~1-2 seconds

## Notes

- Tests are designed to be independent and can run in any order
- No external dependencies required
- All tests clean up after themselves (automated tests only)
- Manual tests may have side effects - review before running
