# QEP-057: Magic Variables Test

use "std/test" {module, describe, it, assert_eq, assert}

module("Magic Variables (QEP-057)")

describe("__file__ magic variable", fun ()
    it("returns the current file path", fun ()
        let file = __file__
        assert(file.ends_with("magic_variables_test.q"), "Should contain filename")
        assert(file.contains("/test/"), "Should be in test directory")
    end)

    it("works inside functions", fun ()
        fun get_file()
            return __file__
        end
        
        let file = get_file()
        assert(file.ends_with("magic_variables_test.q"), "Should work in functions")
    end)
end)

describe("__line__ magic variable", fun ()
    it("returns the current line number", fun ()
        let line1 = __line__
        let line2 = __line__
        assert_eq(line2, line1 + 1, "Line numbers should increment")
    end)

    it("works inside functions", fun ()
        fun get_line()
            return __line__
        end
        
        let line = get_line()
        assert(line > 0, "Line number should be positive")
    end)
end)

describe("__function__ magic variable", fun ()
    it("returns function name in test context", fun ()
        # Inside a test lambda, __function__ will return the lambda's name
        # which may be <anonymous> for unnamed lambdas
        let func_name = __function__
        assert(func_name.len() > 0, "Function name should not be empty")
    end)

    it("returns function name inside functions", fun ()
        fun test_function()
            return __function__
        end
        
        assert_eq(test_function(), "test_function", "Should return function name")
    end)

    it("tracks nested function names", fun ()
        fun outer()
            return __function__
        end
        
        fun middle()
            fun inner()
                return __function__
            end
            return inner()
        end
        
        assert_eq(outer(), "outer", "Should work in outer function")
        assert_eq(middle(), "inner", "Should track innermost function")
    end)
end)

describe("Magic variables in error messages", fun ()
    it("can be used to create contextual error messages", fun ()
        fun create_error()
            let msg = "Error at " .. __file__ .. ":" .. __line__.str() .. " in " .. __function__
            raise ValueErr.new(msg)
        end
        
        try
            create_error()
            assert(false, "Should have raised an error")
        catch e
            let msg = e.message()
            assert(msg.contains("Error at"), "Message should contain 'Error at'")
            assert(msg.contains("magic_variables_test.q"), "Message should contain filename")
            assert(msg.contains("create_error"), "Message should contain function name")
        end
    end)
end)
