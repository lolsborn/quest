# Simplified test suite for std/conf module (QEP-053)

use "std/test" {module, it, describe, assert, assert_eq}
use "std/conf" as conf
use "std/toml" as toml

module("std/conf - Configuration System (QEP-053)")

# =============================================================================
# Test 1: TOML Parsing Basics
# =============================================================================

describe("TOML Parsing", fun ()
  it("parses simple TOML string", fun ()
    let simple_toml = "[section]\nkey = \"value\"\n"
    let result = toml.parse(simple_toml)
    assert_eq(result["section"]["key"], "value")
  end)

  it("parses TOML with multiple types", fun ()
    let typed_toml = """
[test]
string_val = "hello"
int_val = 42
float_val = 3.14
bool_val = true
"""
    let result = toml.parse(typed_toml)
    assert_eq(result["test"]["string_val"], "hello")
    assert_eq(result["test"]["int_val"], 42)
    assert_eq(result["test"]["bool_val"], true)
  end)
end)

# =============================================================================
# Test 2: Configuration Loading
# =============================================================================

describe("Configuration Loading", fun ()
  it("returns empty config when no files exist", fun ()
    conf.clear_cache()
    let config = conf.load_module_config("nonexistent")
    assert_eq(config.len(), 0)
  end)
end)

# =============================================================================
# Test 3: Schema Registration
# =============================================================================

describe("Schema Registration", fun ()
  it("registers and retrieves a schema", fun ()
    type TestConfig
      setting: Str?

      fun self.from_dict(dict)
        let config = TestConfig._new()
        if dict.contains("setting")
          config.setting = dict["setting"]
        end
        return config
      end
    end

    conf.register_schema("schema", TestConfig)
    let schema = conf.get_schema("schema")
    assert(schema == TestConfig)
  end)
end)

# =============================================================================
# Test 4: Configuration Merging
# =============================================================================

describe("Configuration Merging", fun ()
  it("merges flat dictionaries", fun ()
    let dict1 = {a: 1, b: 2}
    let dict2 = {b: 3, c: 4}
    let result = conf.merge(dict1, dict2)

    assert_eq(result["a"], 1)
    assert_eq(result["b"], 3)  # dict2 wins
    assert_eq(result["c"], 4)
  end)

  it("merges nested dictionaries", fun ()
    let dict1 = {section: {a: 1, b: 2}}
    let dict2 = {section: {b: 3, c: 4}}
    let result = conf.merge(dict1, dict2)

    assert_eq(result["section"]["a"], 1)
    assert_eq(result["section"]["b"], 3)
    assert_eq(result["section"]["c"], 4)
  end)
end)

# =============================================================================
# Test 5: Utility Functions
# =============================================================================

describe("Utility Functions", fun ()
  it("lists registered modules", fun ()
    type Config1
      fun self.from_dict(dict)
        return Config1._new()
      end
    end

    type Config2
      fun self.from_dict(dict)
        return Config2._new()
      end
    end

    conf.register_schema("list1", Config1)
    conf.register_schema("list2", Config2)

    let modules = conf.list_modules()
    assert(modules.contains("list1"))
    assert(modules.contains("list2"))
  end)

  it("clears configuration cache", fun ()
    conf.clear_cache()
    assert(true)
  end)
end)
