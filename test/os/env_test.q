use "std/test"
use "std/os"

test.module("os environment variables")

test.describe("os.getenv", fun ()
    test.it("returns nil for non-existent env var", fun ()
        let val = os.getenv("QUEST_TEST_NONEXISTENT_VAR_12345")
        test.assert_eq(val, nil, "non-existent var should return nil")
    end)

    test.it("returns HOME env var", fun ()
        let home = os.getenv("HOME")
        test.assert_not_nil(home, "HOME should be set")
        test.assert_type(home, "Str", "HOME should be a string")
    end)
end)

test.describe("os.setenv and os.getenv", fun ()
    test.it("sets and retrieves env var", fun ()
        os.setenv("QUEST_TEST_VAR", "test_value")
        let val = os.getenv("QUEST_TEST_VAR")
        test.assert_eq(val, "test_value", "should retrieve set value")
    end)

    test.it("overwrites existing env var", fun ()
        os.setenv("QUEST_TEST_OVERWRITE", "first")
        os.setenv("QUEST_TEST_OVERWRITE", "second")
        let val = os.getenv("QUEST_TEST_OVERWRITE")
        test.assert_eq(val, "second", "should overwrite previous value")
    end)
end)

test.describe("os.unsetenv", fun ()
    test.it("removes env var", fun ()
        os.setenv("QUEST_TEST_UNSET", "value")
        os.unsetenv("QUEST_TEST_UNSET")
        let val = os.getenv("QUEST_TEST_UNSET")
        test.assert_eq(val, nil, "unset var should return nil")
    end)

    test.it("handles removing non-existent var", fun ()
        os.unsetenv("QUEST_TEST_NEVER_EXISTED")
        # Should not raise error
        test.assert(true)    end)
end)

test.describe("os.environ", fun ()
    test.it("returns a dict", fun ()
        let env = os.environ()
        test.assert_type(env, "Dict", "environ should return a Dict")
    end)

    test.it("contains known env vars", fun ()
        let env = os.environ()
        test.assert(env.contains("HOME"), "environ should contain HOME")
    end)

    test.it("reflects setenv changes", fun ()
        os.setenv("QUEST_TEST_ENVIRON", "environ_test")
        let env = os.environ()
        test.assert(env.contains("QUEST_TEST_ENVIRON"), "environ should contain newly set var")
        test.assert_eq(env.get("QUEST_TEST_ENVIRON"), "environ_test", "environ should have correct value")

        # Cleanup
        os.unsetenv("QUEST_TEST_ENVIRON")
    end)

    test.it("shows all env vars have string values", fun ()
        let env = os.environ()
        let keys = env.keys()

        # Check at least one key has a string value
        test.assert(keys.len() > 0, "should have at least one env var")

        let first_key = keys.get(0)
        let first_val = env.get(first_key)
        test.assert_type(first_val, "Str", "env values should be strings")
    end)
end)

test.describe("os.environ edge cases", fun ()
    test.it("environ does not accept arguments", fun ()
        try
            os.environ("arg")
            test.fail("should raise error with arguments")
        catch e
            test.assert(e.message().contains("expects 0 arguments"), nil)
        end
    end)
end)

test.describe("os environment integration", fun ()
    test.it("can set, get, and unset multiple vars", fun ()
        os.setenv("VAR1", "value1")
        os.setenv("VAR2", "value2")
        os.setenv("VAR3", "value3")

        test.assert_eq(os.getenv("VAR1"), "value1", nil)
        test.assert_eq(os.getenv("VAR2"), "value2", nil)
        test.assert_eq(os.getenv("VAR3"), "value3", nil)

        os.unsetenv("VAR1")
        os.unsetenv("VAR2")
        os.unsetenv("VAR3")

        test.assert_eq(os.getenv("VAR1"), nil, nil)
        test.assert_eq(os.getenv("VAR2"), nil, nil)
        test.assert_eq(os.getenv("VAR3"), nil, nil)
    end)
end)
