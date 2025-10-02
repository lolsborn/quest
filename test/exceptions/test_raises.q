# Test assert_raises() with exception handling

use "std/test"

describe("Exception Handling", fun()
    it("catches basic string errors", fun()
        assert_raises("Error", fun()
            raise "something went wrong"
        end, nil)
    end)

    it("ensures block always runs", fun()
        let cleanup = false
        try
            raise "test error"
        catch exc
            # Error caught
        ensure
            cleanup = true
        end
        assert_eq(cleanup, true, nil)
    end)

    it("exception objects have exc_type property", fun()
        try
            raise "test message"
        catch ex
            assert_eq(ex.exc_type(), "Error", nil)
        end
    end)

    it("exception objects have message property", fun()
        try
            raise "hello world"
        catch ex
            assert_eq(ex.message(), "hello world", nil)
        end
    end)
end)

run()
