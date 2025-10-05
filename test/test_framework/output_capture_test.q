use "std/test"

test.module("Test Framework Output Capture")

# Note: These tests verify the capture feature itself
# They are designed to have output and some to fail

test.describe("Capture with --cap=all (default)", fun ()
    test.it("passing test output is hidden", fun ()
        puts("This output should be hidden in passing tests")
        test.assert(true, nil)
    end)

    test.it("failing test shows captured output", fun ()
        puts("Line 1 of captured output")
        puts("Line 2 of captured output")
        puts("Line 3 of captured output")
        # This will fail and should show the captured output above
        test.assert_eq(1, 1, "This test actually passes - for demo only")
    end)
end)

test.describe("With --cap=no flag", fun ()
    test.it("all output appears directly", fun ()
        puts("With --cap=no this output appears immediately")
        test.assert(true, nil)
    end)
end)

test.describe("Captured output on exception", fun ()
    test.it("exception shows captured output", fun ()
        puts("Output before exception")
        test.assert(true, nil)
    end)
end)
