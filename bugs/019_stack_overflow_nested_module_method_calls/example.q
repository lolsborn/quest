# Minimal reproduction case for Bug #019
# Stack overflow with nested module method calls

use "std/test" as test

test.module("Simple Test")

test.describe("Test Group", fun ()
    test.it("first test", fun ()
        test.assert(true)
    end)
end)
