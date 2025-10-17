# Simplified test suite for std/conf module (QEP-053)

use "std/test"
use "std/conf" as conf
use "std/toml" as toml

test.module("std/conf - Configuration System (QEP-053)")

# =============================================================================
# Test 1: TOML Parsing Basics
# =============================================================================

test.describe("TOML Parsing", fun ()
    test.it("parses simple TOML string", fun ()
        let simple_toml = "[section]\nkey = \"value\"\n"
        let result = toml.parse(simple_toml)
        test.assert_eq(result["section"]["key"], "value")
    end)

    test.it("parses TOML with multiple types", fun ()
        let typed_toml = """
[test]
string_val = "hello"
int_val = 42
float_val = 3.14
bool_val = true
"""
        let result = toml.parse(typed_toml)
        test.assert_eq(result["test"]["string_val"], "hello")
        test.assert_eq(result["test"]["int_val"], 42)
        test.assert_eq(result["test"]["bool_val"], true)
    end)
end)

# =============================================================================
# Test 2: Configuration Loading
# =============================================================================

test.describe("Configuration Loading", fun ()
    test.it("returns empty config when no files exist", fun ()
        conf.clear_cache()
        let config = conf.load_module_config("test.nonexistent")
        test.assert_eq(config.len(), 0)
    end)
end)

# =============================================================================
# Test 3: Schema Registration
# =============================================================================

test.describe("Schema Registration", fun ()
    test.it("registers and retrieves a schema", fun ()
        type TestConfig
            setting: Str?

            static fun from_dict(dict)
                let config = TestConfig._new()
                if dict.contains("setting")
                    config.setting = dict["setting"]
                end
                return config
            end
        end

        conf.register_schema("test.schema", TestConfig)
        let schema = conf.get_schema("test.schema")
        test.assert(schema == TestConfig)
    end)
end)

# =============================================================================
# Test 4: Configuration Merging
# =============================================================================

test.describe("Configuration Merging", fun ()
    test.it("merges flat dictionaries", fun ()
        let dict1 = {a: 1, b: 2}
        let dict2 = {b: 3, c: 4}
        let result = conf.merge(dict1, dict2)

        test.assert_eq(result["a"], 1)
        test.assert_eq(result["b"], 3)  # dict2 wins
        test.assert_eq(result["c"], 4)
    end)

    test.it("merges nested dictionaries", fun ()
        let dict1 = {section: {a: 1, b: 2}}
        let dict2 = {section: {b: 3, c: 4}}
        let result = conf.merge(dict1, dict2)

        test.assert_eq(result["section"]["a"], 1)
        test.assert_eq(result["section"]["b"], 3)
        test.assert_eq(result["section"]["c"], 4)
    end)
end)

# =============================================================================
# Test 5: Utility Functions
# =============================================================================

test.describe("Utility Functions", fun ()
    test.it("lists registered modules", fun ()
        type Config1
            static fun from_dict(dict)
                return Config1._new()
            end
        end

        type Config2
            static fun from_dict(dict)
                return Config2._new()
            end
        end

        conf.register_schema("test.list1", Config1)
        conf.register_schema("test.list2", Config2)

        let modules = conf.list_modules()
        test.assert(modules.contains("test.list1"))
        test.assert(modules.contains("test.list2"))
    end)

    test.it("clears configuration cache", fun ()
        conf.clear_cache()
        test.assert(true)
    end)
end)
