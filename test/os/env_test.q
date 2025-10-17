use "std/test" { module, describe, it, assert_eq, assert_not_nil, assert_type, assert }
use "std/os"

module("os environment variables")

describe("os.getenv", fun ()
  it("returns nil for non-existent env var", fun ()
    let val = os.getenv("QUEST_TEST_NONEXISTENT_VAR_12345")
    assert_eq(val, nil, "non-existent var should return nil")
  end)

  it("returns HOME env var", fun ()
    let home = os.getenv("HOME")
    assert_not_nil(home, "HOME should be set")
    assert_type(home, "Str", "HOME should be a string")
  end)
end)

describe("os.setenv and os.getenv", fun ()
  it("sets and retrieves env var", fun ()
    os.setenv("QUEST_TEST_VAR", "test_value")
    let val = os.getenv("QUEST_TEST_VAR")
    assert_eq(val, "test_value", "should retrieve set value")
  end)

  it("overwrites existing env var", fun ()
    os.setenv("QUEST_TEST_OVERWRITE", "first")
    os.setenv("QUEST_TEST_OVERWRITE", "second")
    let val = os.getenv("QUEST_TEST_OVERWRITE")
    assert_eq(val, "second", "should overwrite previous value")
  end)
end)

describe("os.unsetenv", fun ()
  it("removes env var", fun ()
    os.setenv("QUEST_TEST_UNSET", "value")
    os.unsetenv("QUEST_TEST_UNSET")
    let val = os.getenv("QUEST_TEST_UNSET")
    assert_eq(val, nil, "unset var should return nil")
  end)

  it("handles removing non-existent var", fun ()
    os.unsetenv("QUEST_TEST_NEVER_EXISTED")
    # Should not raise error
    assert(true)  end)
end)

describe("os.environ", fun ()
  it("returns a dict", fun ()
    let env = os.environ()
    assert_type(env, "Dict", "environ should return a Dict")
  end)

  it("contains known env vars", fun ()
    let env = os.environ()
    assert(env.contains("HOME"), "environ should contain HOME")
  end)

  it("reflects setenv changes", fun ()
    os.setenv("QUEST_TEST_ENVIRON", "environ_test")
    let env = os.environ()
    assert(env.contains("QUEST_TEST_ENVIRON"), "environ should contain newly set var")
    assert_eq(env.get("QUEST_TEST_ENVIRON"), "environ_test", "environ should have correct value")

    # Cleanup
    os.unsetenv("QUEST_TEST_ENVIRON")
  end)

  it("shows all env vars have string values", fun ()
    let env = os.environ()
    let keys = env.keys()

    # Check at least one key has a string value
    assert(keys.len() > 0, "should have at least one env var")

    let first_key = keys.get(0)
    let first_val = env.get(first_key)
    assert_type(first_val, "Str", "env values should be strings")
  end)
end)

describe("os.environ edge cases", fun ()
  it("environ does not accept arguments", fun ()
    try
      os.environ("arg")
      fail("should raise error with arguments")
    catch e
      assert(e.message().contains("expects 0 arguments"))
    end
  end)
end)

describe("os environment integration", fun ()
  it("can set, get, and unset multiple vars", fun ()
    os.setenv("VAR1", "value1")
    os.setenv("VAR2", "value2")
    os.setenv("VAR3", "value3")

    assert_eq(os.getenv("VAR1"), "value1")
    assert_eq(os.getenv("VAR2"), "value2")
    assert_eq(os.getenv("VAR3"), "value3")

    os.unsetenv("VAR1")
    os.unsetenv("VAR2")
    os.unsetenv("VAR3")

    assert_eq(os.getenv("VAR1"), nil)
    assert_eq(os.getenv("VAR2"), nil)
    assert_eq(os.getenv("VAR3"), nil)
  end)
end)
