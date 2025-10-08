# Exception Variable Scoping Tests
# Tests that exception variables in catch blocks are properly scoped

use "std/test" as test

test.module("Exception Variable Scoping")

test.describe("Catch variable scoping", fun ()
    test.it("allows reusing same exception variable name in multiple catch blocks", fun ()
        let first_msg = nil
        let second_msg = nil

        try
            raise "first error"
        catch e
            first_msg = e.message()
        end

        try
            raise "second error"
        catch e
            second_msg = e.message()
        end

        test.assert_eq(first_msg, "first error", "First catch should capture first error")
        test.assert_eq(second_msg, "second error", "Second catch should capture second error")
    end)

    test.it("exception variable does not leak outside catch block", fun ()
        try
            raise "test error"
        catch exc
            test.assert_eq(exc.message(), "test error", "Exception should be accessible in catch")
        end

        # Try to access exc outside catch - should fail
        let error_caught = false
        try
            let msg = exc.message()
        catch e
            error_caught = true
        end

        test.assert(error_caught, "Exception variable should not be accessible outside catch block")
    end)

    test.it("supports nested try/catch with same variable name", fun ()
        let inner_msg = nil
        let outer_msg = nil

        try
            try
                raise "inner error"
            catch e
                inner_msg = e.message()
                raise "outer error"
            end
        catch e
            outer_msg = e.message()
        end

        test.assert_eq(inner_msg, "inner error", "Inner catch should get inner error")
        test.assert_eq(outer_msg, "outer error", "Outer catch should get outer error")
    end)

    test.it("allows different exception variable names", fun ()
        let err_msg = nil
        let ex_msg = nil
        let exception_msg = nil

        try
            raise "error1"
        catch err
            err_msg = err.message()
        end

        try
            raise "error2"
        catch ex
            ex_msg = ex.message()
        end

        try
            raise "error3"
        catch exception
            exception_msg = exception.message()
        end

        test.assert_eq(err_msg, "error1", "Should work with 'err'")
        test.assert_eq(ex_msg, "error2", "Should work with 'ex'")
        test.assert_eq(exception_msg, "error3", "Should work with 'exception'")
    end)

    test.it("exception variable is scoped even if catch throws", fun ()
        let caught_inner = false
        let caught_outer = false

        try
            try
                raise "inner"
            catch e
                caught_inner = true
                raise "outer from catch"
            end
        catch e
            caught_outer = true
            test.assert_eq(e.message(), "outer from catch", "Outer should get re-raised error")
        end

        test.assert(caught_inner, "Inner catch should execute")
        test.assert(caught_outer, "Outer catch should execute")
    end)

    test.it("exception variable accessible throughout catch block", fun ()
        let msg1 = nil
        let msg2 = nil
        let msg3 = nil

        try
            raise "test"
        catch e
            msg1 = e.message()
            let x = 1 + 1
            msg2 = e.message()
            if true
                msg3 = e.message()
            end
        end

        test.assert_eq(msg1, "test", "Exception accessible at start of catch")
        test.assert_eq(msg2, "test", "Exception accessible in middle of catch")
        test.assert_eq(msg3, "test", "Exception accessible inside nested block in catch")
    end)

    test.it("can use same name in sequential try/catch blocks multiple times", fun ()
        let messages = []

        let i = 0
        while i < 5
            try
                raise "error " .. i.str()
            catch e
                messages.push(e.message())
            end
            i = i + 1
        end

        test.assert_eq(messages.len(), 5, "Should catch 5 errors")
        test.assert_eq(messages[0], "error 0", "First error")
        test.assert_eq(messages[4], "error 4", "Fifth error")
    end)
end)
