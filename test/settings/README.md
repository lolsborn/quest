# Settings Module Testing

## Manual Testing Only

The `std/settings` module loads `.settings.toml` from the **current working directory** on interpreter startup (before any Quest code runs). This means:

1. Settings are loaded **once** at startup
2. Tests cannot change or reload settings
3. The test runner starts a single interpreter instance with its own working directory

Therefore, automated testing of the settings module is not practical within the normal test framework.

## How to Test Manually

**From the repository root:**

```bash
cd test/settings
../../target/release/quest _load_settings.q
cd ../..
```

This ensures:
- The interpreter starts with `test/settings` as the current working directory
- The `.settings.toml` file in `test/settings/` is loaded on startup
- The test script can verify settings were loaded correctly

## Test Coverage

The `_load_settings.q` script tests:

1. ✅ Simple value retrieval (`settings.get()`)
2. ✅ Nested path navigation (dot-notation)
3. ✅ Existence checking (`settings.has()`)
4. ✅ Section retrieval (`settings.section()`)
5. ✅ All settings (`settings.all()`)
6. ✅ Array values
7. ✅ `[os.environ]` processing (values set in environment, section removed from settings)
8. ✅ Default values with `or` operator
9. ✅ Type conversion (TOML → Quest types)

## Why _load_settings.q?

The underscore prefix (`_`) causes the test runner to skip this file during automated test discovery. This prevents the test from running in the wrong directory.
