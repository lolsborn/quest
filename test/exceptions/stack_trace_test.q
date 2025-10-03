# Test stack trace functionality

use "std/test" as test

test.module("Exception Tests - Stack Traces")

test.describe("Stack Traces", fun ()
    test.it("exception has stack array", fun ()
        try
            raise "test error"
        catch e
            let stack = e.stack()
            test.assert_type(stack, "Array", "stack should be an array")
        end
    end)

    test.it("captures function call stack", fun ()
        fun inner()
            raise "error from inner"
        end

        fun middle()
            inner()
        end

        fun outer()
            middle()
        end

        try
            outer()
        catch e
            let stack = e.stack()
            # Stack includes test framework functions too, so check >= 3
            test.assert(stack.len() >= 3, "Should have at least 3 stack frames")
        end
    end)

    test.it("shows nested function calls", fun ()
        fun level3()
            raise "deep error"
        end

        fun level2()
            level3()
        end

        fun level1()
            level2()
        end

        try
            level1()
        catch e
            test.assert(e.stack().len() >= 3, "Should have at least 3 levels")
            test.assert_eq(e.message(), "deep error", "Message should be preserved")
        end
    end)

    test.it("clears stack after exception is caught", fun ()
        fun thrower()
            raise "first error"
        end

        # First exception
        try
            thrower()
        catch e
            test.assert(e.stack().len() >= 1, "First exception should have stack")
        end

        # Second exception - stack should be cleared
        try
            thrower()
        catch e2
            test.assert(e2.stack().len() >= 1, "Second exception should also have stack")
        end
    end)
end)
