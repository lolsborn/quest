# Basic Exception Handling Tests
# Tests try/catch/ensure/raise functionality

use "std/test" as test

test.module("Exception Tests - Basic")

test.describe("Raise and Catch", fun ()
    test.it("catches simple string errors", fun ()
        test.assert_raises(RuntimeErr, fun ()
            raise "something went wrong"
        end)
    end)

    test.it("allows execution to continue after catch", fun ()
        let executed = false
        try
            raise "test error"
        catch e
            executed = true
        end
        test.assert_eq(executed, true, "Catch block should execute")
    end)

    test.it("does not execute catch when no error", fun ()
        let catch_ran = false
        try
            # No error
        catch e
            catch_ran = true
        end
        test.assert_eq(catch_ran, false, "Catch should not run without error")
    end)
end)

test.describe("Exception Objects", fun ()
    test.it("have exc_type property", fun ()
        try
            raise "test message"
        catch e
            test.assert_eq(e.type(), RuntimeErr, "String raises become RuntimeErr (QEP-037)")
        end
    end)

    test.it("have message property", fun ()
        try
            raise "hello world"
        catch e
            test.assert_eq(e.message(), "hello world", "Exception message should match")
        end
    end)

    test.it("have _str representation", fun ()
        try
            raise "test"
        catch e
            let str_repr = e.str()
            test.assert_eq(str_repr, "RuntimeErr: test", "String representation should be 'RuntimeErr: test'")
        end
    end)
end)

test.describe("Ensure Blocks", fun ()
    test.it("always execute after try", fun ()
        let cleanup = false
        try
            # No error
        ensure
            cleanup = true
        end
        test.assert_eq(cleanup, true, "Ensure should run after try")
    end)

    test.it("always execute even with error", fun ()
        let cleanup = false
        try
            raise "error"
        catch err
            # Caught
        ensure
            cleanup = true
        end
        test.assert_eq(cleanup, true, "Ensure should run after catch")
    end)

    test.it("execute in correct order", fun ()
        let order_correct = false

        try
            # Try block runs first
        ensure
            # Ensure block runs second
            order_correct = true
        end
        # Code after try/ensure runs third

        test.assert_eq(order_correct, true, "Ensure should execute before continuing")
    end)
end)

test.describe("Re-raising", fun ()
    test.it("can re-raise caught exception", fun ()
        let outer_caught = false

        try
            try
                raise "inner error"
            catch e
                # Re-raise
                raise
            end
        catch e2
            outer_caught = true
            test.assert_eq(e2.message(), "inner error", "Re-raised exception should have same message")
        end

        test.assert_eq(outer_caught, true, "Outer catch should execute")
    end)
end)
