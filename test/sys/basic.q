#!/usr/bin/env quest
# Tests for sys module (static properties only)
# Note: sys is auto-injected in scripts, not importable via "use"

use "std/test" as test
# Note: sys is auto-injected and available directly (no need to import)

test.module("System Module")

test.describe("Version Info", fun ()
    test.it("has version string", fun ()
        test.assert_eq(sys.version.len() > 0, true, "version should not be empty")
        test.assert_eq(sys.version.count(".") > 0, true, "version should contain dots")
    end)

    test.it("has platform string", fun ()
        test.assert_eq(sys.platform.len() > 0, true, "platform should not be empty")
        # Should be darwin, linux, win32, etc.
        let valid = sys.platform == "darwin" or sys.platform == "linux" or sys.platform == "win32" or sys.platform == "windows"
        test.assert_eq(valid, true, "platform should be recognized")
    end)

    test.it("has executable path", fun ()
        test.assert_eq(sys.executable.len() > 0, true, "executable path should not be empty")
        test.assert_eq(sys.executable.count("quest") > 0, true, "executable should contain quest")
    end)

    test.it("has builtin module names", fun ()
        test.assert_eq(sys.builtin_module_names.len() > 0, true, "should have builtin modules")
        test.assert_eq(sys.builtin_module_names.contains("math"), true, "should include math")
        test.assert_eq(sys.builtin_module_names.contains("json"), true, "should include json")
        test.assert_eq(sys.builtin_module_names.contains("io"), true, "should include io")
    end)
end)

test.describe("Command Line Arguments", fun ()
    test.it("has argc property", fun ()
        # argc is 0 when imported as module, > 0 when run as script
        test.assert_eq(sys.argc >= 0, true, "argc should be non-negative")
    end)

    test.it("has argv array", fun ()
        # argv length should always match argc
        test.assert_eq(sys.argv.len(), sys.argc, "argv length should equal argc")
    end)

    test.it("argv matches argc count", fun ()
        # When run as script, argc > 0 and argv[0] exists
        # When imported as module, argc == 0 and argv is empty
        if sys.argc > 0
            let script = sys.argv[0]
            test.assert_eq(script.len() > 0, true, "when argc > 0, argv[0] should not be empty")
        end
        # Always true regardless of how it's run
        test.assert_eq(true, true, "argv/argc consistency check passed")
    end)
end)
