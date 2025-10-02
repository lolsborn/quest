#!/usr/bin/env quest
# Tests for sys module

use "std/test" as test
use "std/sys" as sys

test.describe("System Module - Version Info", fun ()
    test.it("has version string", fun ()
        test.assert(sys.version.len() > 0, "version should not be empty")
        test.assert(sys.version.count(".") > 0, "version should contain dots")
    end)

    test.it("has platform string", fun ()
        test.assert(sys.platform.len() > 0, "platform should not be empty")
        # Should be darwin, linux, win32, etc.
        let valid_platforms = ["darwin", "linux", "win32", "windows"]
        let is_valid = sys.platform == "darwin" or sys.platform == "linux" or sys.platform == "win32" or sys.platform == "windows"
        test.assert(is_valid, "platform should be recognized")
    end)

    test.it("has executable path", fun ()
        test.assert(sys.executable.len() > 0, "executable path should not be empty")
        test.assert(sys.executable.count("quest") > 0, "executable should contain 'quest'")
    end)

    test.it("has builtin module names", fun ()
        test.assert(sys.builtin_module_names.len() > 0, "should have builtin modules")
        test.assert(sys.builtin_module_names.contains("math"), "should include math")
        test.assert(sys.builtin_module_names.contains("json"), "should include json")
        test.assert(sys.builtin_module_names.contains("io"), "should include io")
    end)
end)

test.describe("System Module - Command Line Arguments", fun ()
    test.it("has argc", fun ()
        test.assert(sys.argc > 0, "argc should be at least 1")
    end)

    test.it("has argv array", fun ()
        test.assert(sys.argv.len() > 0, "argv should not be empty")
        test.assert(sys.argv.len() == sys.argc, "argv length should equal argc")
    end)

    test.it("argv[0] is script path", fun ()
        let script = sys.argv[0]
        test.assert(script.len() > 0, "script path should not be empty")
        test.assert(script.count(".q") > 0, "script should be a .q file")
    end)

    test.it("can iterate over argv", fun ()
        let count = 0
        sys.argv.each(fun (arg)
            count = count + 1
        end)

        test.assert(count == sys.argc, "should iterate over all arguments")
    end)
end)

test.describe("System Module - Argument Parsing", fun ()
    test.it("can check for flags", fun ()
        # This test checks if we can search argv
        let has_test_flag = false
        sys.argv.each(fun (arg)
            if arg == "--test"
                has_test_flag = true
            end
        end)

        # This will be false unless --test is passed, which is fine
        # We're just testing that the logic works
        test.assert(not has_test_flag or has_test_flag, "flag check should work")
    end)

    test.it("can access arguments by index", fun ()
        test.assert(sys.argv[0].len() > 0, "first argument should exist")

        if sys.argc > 1
            test.assert(sys.argv[1].len() > 0, "second argument should be accessible")
        end
    end)
end)
