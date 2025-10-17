# Test for Bug #021 fix: get_config() error handling
# Ensures ConfigurationErr is raised with helpful message when from_dict is missing

use "std/test"
use "std/conf" as conf
use "std/os" as os

test.module("Bug #021 - conf.get_config() error handling")

# Clear state before tests
os.setenv("QUEST_ENV", nil)
conf.clear_cache()

# Note: Types must be defined at module level, not inside test functions
# This is a Quest limitation - function-scoped types can't be reliably called via type variables

type NoFromDictType
    value: Str?
    # Missing from_dict method intentionally
end

type BadFromDictType
    static fun from_dict(dict)
        raise ValueErr.new("Intentional error in from_dict")
    end
end

test.describe("from_dict method validation", fun ()
    test.it("raises ConfigurationErr when from_dict is missing", fun ()
        conf.register_schema("test.bug021.no_from_dict", NoFromDictType)

        let caught_correct_error = false
        let error_message = ""

        try
            conf.get_config("test.bug021.no_from_dict")
        catch e: ConfigurationErr
            caught_correct_error = true
            error_message = e.message()
        catch e
            # Wrong error type caught
            error_message = "Wrong type: " .. e.type() .. " - " .. e.message()
        end

        test.assert(caught_correct_error, "Should catch ConfigurationErr, got: " .. error_message)
        test.assert(error_message.contains("from_dict"), "Error should mention from_dict, got: " .. error_message)
        test.assert(error_message.contains("test.bug021.no_from_dict"), "Error should mention module name")

        conf.clear_cache()
    end)

    test.it("raises ConfigurationErr when from_dict throws an error", fun ()
        conf.register_schema("test.bug021.bad_from_dict", BadFromDictType)

        let caught_error = false
        let error_message = ""

        try
            conf.get_config("test.bug021.bad_from_dict")
        catch e: ConfigurationErr
            caught_error = true
            error_message = e.message()
        catch e
            error_message = "Wrong type: " .. e.type()
        end

        test.assert(caught_error, "Should catch ConfigurationErr")
        test.assert(error_message.contains("Intentional error"), "Should preserve original error message")

        conf.clear_cache()
    end)
end)
