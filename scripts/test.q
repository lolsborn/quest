#!/usr/bin/env quest

use "std/test"
use "std/sys"

# Check for --no-color flag in command line arguments
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

# Filter out certain test files/directories:
# - docs-old, docs, examples, scripts: contain files that aren't proper tests
let filtered_tests = tests.filter(fun (t)
    # Check if path contains excluded directories
    let exclude_dirs = ["sys", "docs", "examples", "scripts"]
    let should_exclude = false

    for dir in exclude_dirs
        if t.slice(0, dir.len()) == dir or t.index_of("/" .. dir .. "/") >= 0
            should_exclude = true
        end
    end

    not should_exclude
end)

filtered_tests.each(fun (t)
    # Loading the module automatically executes it, registering the tests
    sys.load_module(t)
end)

# Print overall summary
let status = test.stats()
sys.exit(status)