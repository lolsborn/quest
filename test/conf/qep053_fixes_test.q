# Tests for QEP-053 critical bug fixes

use "std/test" {module, it, describe, assert, assert_eq}
use "std/os" as os

# Clear QUEST_ENV before loading conf to prevent validation errors
os.setenv("QUEST_ENV", nil)

use "std/conf" as conf

module("std/conf - QEP-053 Critical Fixes")

# =============================================================================
# Test 1: QUEST_ENV path injection prevention (Security Fix)
# =============================================================================

describe("QUEST_ENV Validation", fun ()
  it("rejects path traversal attempts", fun ()
    os.setenv("QUEST_ENV", nil)
    os.setenv("QUEST_ENV", "../../../etc/passwd")

    let caught_error = false
    try
      conf.load_module_config("module")
    catch e: ValueErr
      caught_error = true
      assert(e.message().contains("Invalid QUEST_ENV"))
    end

    assert(caught_error)
    os.setenv("QUEST_ENV", nil)
  end)

  it("rejects paths with slashes", fun ()
    os.setenv("QUEST_ENV", nil)
    os.setenv("QUEST_ENV", "dev/hack")

    let caught_error = false
    try
      conf.load_module_config("module")
    catch e: ValueErr
      caught_error = true
    end

    assert(caught_error)
    os.setenv("QUEST_ENV", nil)
  end)

  it("accepts valid environment names", fun ()
    os.setenv("QUEST_ENV", nil)

    # These should all work without errors
    os.setenv("QUEST_ENV", "dev")
    let config1 = conf.load_module_config("module")
    assert(config1.is("dict"))

    os.setenv("QUEST_ENV", "production-2024")
    let config2 = conf.load_module_config("module")
    assert(config2.is("dict"))

    os.setenv("QUEST_ENV", "test_123")
    let config3 = conf.load_module_config("module")
    assert(config3.is("dict"))

    os.setenv("QUEST_ENV", nil)
  end)
end)

# =============================================================================
# Test 2: Native ConfigurationErr exception type
# =============================================================================

describe("ConfigurationErr Exception", fun ()
  it("raises ConfigurationErr for missing schema", fun ()
    os.setenv("QUEST_ENV", nil)

    let caught_config_err = false
    try
      conf.get_config("nonexistent.module")
    catch e: ConfigurationErr
      caught_config_err = true
      assert(e.message().contains("No schema registered"))
    end

    assert(caught_config_err)
  end)

  it("can be caught by type", fun ()
    os.setenv("QUEST_ENV", nil)

    let caught_correct_type = false
    try
      conf.get_config("another.nonexistent")
    catch e: ConfigurationErr
      caught_correct_type = true
    catch e
      # Should not catch as generic error
      caught_correct_type = false
    end

    assert(caught_correct_type)
  end)
end)

# =============================================================================
# Test 3: clear_cache functionality
# =============================================================================

describe("Cache Management", fun ()
  it("clear_cache works without errors", fun ()
    os.setenv("QUEST_ENV", nil)

    # Test that clear_cache can be called multiple times without error
    conf.clear_cache()
    conf.clear_cache()
    conf.clear_cache()

    # If we got here without errors, test passes
    assert(true)
  end)
end)
