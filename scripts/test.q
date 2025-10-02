#!/usr/bin/env quest

use "std/test"
use "std/sys"

# Check for --no-color flag in command line arguments
# Note: sys is auto-injected in scripts, no need to import it
let use_colors = true
sys.argv.each(fun (arg)
    if arg == "--no-color"
        use_colors = false
    end
end)

# Configure test framework
if not use_colors
    test.set_colors(false)
end

let tests = test.find_tests(["."])

# Filter out sys tests - they need to be run as scripts, not loaded as modules
# because sys is only available in script context, not module context
let filtered_tests = tests.filter(fun (t)
    let parts = t.split("/")
    let has_sys = false
    parts.each(fun (p)
        if p == "sys"
            has_sys = true
        end
    end)
    not has_sys
end)

filtered_tests.each(fun (t)
    # Loading the module automatically executes it, registering the tests
    sys.load_module(t)
end)