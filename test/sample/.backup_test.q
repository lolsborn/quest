# Backup test file - should be ignored by test discovery
# Files starting with . are dotfiles and should not be discovered

use "std/test" as test

test.describe("Backup tests", fun ()
    test.it("should not run", fun ()
        test.assert_eq(1, 2, "This test should not run")
    end)
end)
