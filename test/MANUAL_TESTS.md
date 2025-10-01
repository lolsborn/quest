# Manual Test Files

These test files are kept for manual testing and demonstration purposes. They are not part of the automated test suite run by `run.q`.

## Available Manual Tests

### [`del_test.q`](del_test.q)
Tests the `del` statement for variable deletion. Demonstrates:
- Basic variable deletion
- Delete and redeclare variables
- Freeing memory for large data structures
- Selective deletion of variables
- Deletion restrictions (modules cannot be deleted)
- Function scope deletion

**Run with:** `./target/release/quest test/del_test.q`

### [`glob_test.q`](glob_test.q)
Tests IO module's glob pattern matching functionality. Demonstrates:
- Finding files with glob patterns (`test/*.q`, `docs/**/*.md`)
- Glob match testing (`glob_match()` function)
- Pattern matching with wildcards

**Run with:** `./target/release/quest test/glob_test.q`

**Note:** This test actually works and could be integrated into the test suite as `test/io/glob.q` if desired.

### [`hash_test.q`](hash_test.q)
Tests the hash module's cryptographic functions. Demonstrates:
- MD5 hashing
- SHA-1, SHA-256, SHA-512 hashing
- HMAC-SHA256 and HMAC-SHA512
- CRC32 checksums
- Testing with different inputs

**Run with:** `./target/release/quest test/hash_test.q`

**Note:** Hash functions are documented in `IMPLEMENTATION_STATUS.md` as defined but not yet implemented. This test will fail until hash module is implemented.

### [`os_test.q`](os_test.q)
Tests OS module functionality. Demonstrates:
- Getting current working directory (`os.getcwd()`)
- Reading environment variables (`os.getenv()`)
- Directory listing (`os.listdir()`)
- Creating directories (`os.mkdir()`)
- Removing directories (`os.rmdir()`)

**Run with:** `./target/release/quest test/os_test.q`

**Warning:** Creates and removes `test_dir_12345` directory. Has filesystem side effects.

### [`term_test.q`](term_test.q)
Tests terminal/ANSI color module. Demonstrates:
- Basic colors (red, green, yellow, blue, magenta, cyan)
- Text attributes (bold, underline, dimmed)
- Colors with attributes
- Background colors
- Terminal size detection
- ANSI color stripping

**Run with:** `./target/release/quest test/term_test.q`

**Note:** Outputs colored text to terminal. Visual inspection required.

## Why These Are Manual

These tests are kept separate from the automated suite because they:
1. **Have side effects** (create files/directories: `os_test.q`)
2. **Require visual inspection** (colored output: `term_test.q`)
3. **Test unimplemented features** (hash functions: `hash_test.q`)
4. **Are demonstration code** (show feature usage rather than test assertions)
5. **May require cleanup** (file operations: `glob_test.q`, `os_test.q`)

## Adding to Test Suite

If you want to integrate any of these into the automated test suite:

1. Convert `puts()` statements to `test.assert()` assertions
2. Add proper cleanup for side effects
3. Handle unimplemented features gracefully
4. Move to appropriate `test/<category>/` subdirectory
5. Add import to `test/run.q`

Example structure for conversion:
```quest
use "std/test" as test

test.describe("Feature Name", fun ()
    test.it("does something", fun ()
        # Setup
        let result = some_function()

        # Assert
        test.assert(result == expected, "description")

        # Cleanup (if needed)
    end)
end)
```
