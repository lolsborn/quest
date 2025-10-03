# Test assert_raises() with exception handling

use "std/test" as test

test.describe("Exception Handling", fun()
    test.it("catches basic string errors", fun()
        test.assert_raises("Error", fun()
            raise "something went wrong"
        end, nil)
    end)

    test.it("ensures block always runs", fun()
        let cleanup = false
        try
            raise "test error"
        catch exc
            # Error caught
        ensure
            cleanup = true
        end
        test.assert_eq(cleanup, true, nil)
    end)

    test.it("exception objects have exc_type property", fun()
        try
            raise "test message"
        catch ex
            test.assert_eq(ex.exc_type(), "Error", nil)
        end
    end)

    test.it("exception objects have message property", fun()
        try
            raise "hello world"
        catch ex
            test.assert_eq(ex.message(), "hello world", nil)
        end
    end)
end)


