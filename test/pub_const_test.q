# Test pub const functionality
use "std/test"
use "test/_pub_const_helper" as helper

test.module("pub const")

test.describe("Public constants", fun ()
    test.it("can export string constants", fun ()
        test.assert_eq(helper.PUBLIC_CONST, "exported")
    end)

    test.it("can export numeric constants", fun ()
        test.assert_eq(helper.PI, 3.14159)
        test.assert_eq(helper.MAX_SIZE, 1000)
    end)

    test.it("can export constants alongside public variables", fun ()
        test.assert_eq(helper.public_var, "also exported")
    end)

    test.it("does not export private constants", fun ()
        # PRIVATE_CONST should not be accessible
        let error_raised = false
        try
            let _ = helper.PRIVATE_CONST
        catch e
            error_raised = true
        end
        test.assert(error_raised, "Private const should not be accessible")
    end)
end)
