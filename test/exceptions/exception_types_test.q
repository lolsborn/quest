# QEP-037: Typed Exception System Tests

use "std/test"

test.module("QEP-037: Typed Exception System")

test.describe("Exception type creation", fun ()
    test.it("creates Err exception", fun ()
        let e = Err.new("generic error")
        test.assert_eq(e.type(), Err)
        test.assert_eq(e.message(), "generic error")
    end)

    test.it("creates IndexErr exception", fun ()
        let e = IndexErr.new("index out of bounds")
        test.assert_eq(e.type(), IndexErr)
        test.assert_eq(e.message(), "index out of bounds")
    end)

    test.it("creates TypeErr exception", fun ()
        let e = TypeErr.new("type mismatch")
        test.assert_eq(e.type(), TypeErr)
    end)

    test.it("creates ValueErr exception", fun ()
        let e = ValueErr.new("invalid value")
        test.assert_eq(e.type(), ValueErr)
    end)

    test.it("creates ArgErr exception", fun ()
        let e = ArgErr.new("wrong number of arguments")
        test.assert_eq(e.type(), ArgErr)
    end)

    test.it("creates AttrErr exception", fun ()
        let e = AttrErr.new("no such attribute")
        test.assert_eq(e.type(), AttrErr)
    end)

    test.it("creates NameErr exception", fun ()
        let e = NameErr.new("name not found")
        test.assert_eq(e.type(), NameErr)
    end)

    test.it("creates RuntimeErr exception", fun ()
        let e = RuntimeErr.new("runtime error")
        test.assert_eq(e.type(), RuntimeErr)
    end)

    test.it("creates IOErr exception", fun ()
        let e = IOErr.new("file not found")
        test.assert_eq(e.type(), IOErr)
    end)

    test.it("creates ImportErr exception", fun ()
        let e = ImportErr.new("module not found")
        test.assert_eq(e.type(), ImportErr)
    end)

    test.it("creates KeyErr exception", fun ()
        let e = KeyErr.new("key not found")
        test.assert_eq(e.type(), KeyErr)
    end)
end)

test.describe("Exception raising and catching", fun ()
    test.it("raises and catches specific exception type", fun ()
        let caught = false
        let caught_msg = nil
        try
            raise IndexErr.new("test error")
        catch e: IndexErr
            caught = true
            caught_msg = e.message()
        end
        test.assert(caught, "Should catch IndexErr")
        test.assert_eq(caught_msg, "test error")    end)

    test.it("catches IndexErr with Err base type", fun ()
        let caught = false
        let caught_type = nil
        try
            raise IndexErr.new("test")
        catch e: Err
            caught = true
            caught_type = e.type()
        end
        test.assert(caught, "Should catch IndexErr via Err")
        test.assert_eq(caught_type, IndexErr)
    end)

    test.it("catches TypeErr with Err base type", fun ()
        let caught = false
        try
            raise TypeErr.new("test")
        catch e: Err
            caught = true
        end
        test.assert(caught, "Should catch TypeErr via Err")
    end)

    test.it("does not catch wrong exception type", fun ()
        let caught_index = false
        let caught_type = false
        try
            raise TypeErr.new("test")
        catch e: IndexErr
            caught_index = true
        catch e: TypeErr
            caught_type = true
        catch e: Err
            # Catch all to prevent uncaught exception
        end
        test.assert(not caught_index, "Should not catch as IndexErr")
        test.assert(caught_type, "Should catch as TypeErr")
    end)

    test.it("catches most specific type first", fun ()
        let which = nil
        try
            raise IndexErr.new("test")
        catch e: IndexErr
            which = "specific"
        catch e: Err
            which = "general"
        end
        test.assert_eq(which, "specific")
    end)

    test.it("falls through to general catch", fun ()
        let which = nil
        try
            raise ValueErr.new("test")
        catch e: IndexErr
            which = "specific"
        catch e: Err
            which = "general"
        end
        test.assert_eq(which, "general")
    end)
end)

test.describe("Exception object methods", fun ()
    test.it("has exc_type method", fun ()
        let e = IndexErr.new("test")
        test.assert_eq(e.type(), IndexErr)
    end)

    test.it("has message method", fun ()
        let e = IndexErr.new("my message")
        test.assert_eq(e.message(), "my message")
    end)

    test.it("has _str method", fun ()
        let e = IndexErr.new("test")
        test.assert_eq(e._str(), "IndexErr: test")
    end)
end)

test.describe("Backwards compatibility", fun ()
    test.it("still allows string-based raise (as RuntimeErr)", fun ()
        let caught = false
        let caught_type = nil
        try
            raise "string error"
        catch e
            caught = true
            caught_type = e.type()
        end
        test.assert(caught, "Should catch string-based error")
        test.assert_eq(caught_type, RuntimeErr, "String errors become RuntimeErr")
    end)

    test.it("catches string errors with Err base type", fun ()
        let caught = false
        try
            raise "test"
        catch e: Err
            caught = true
        end
        test.assert(caught, "Should catch string error via Err")
    end)
end)
