# Automatic Test Discovery Runner
# Discovers and runs all test files from specified paths

use "std/test" as test

# Discover test files from array of paths
# Can pass directories and/or individual files
let test_files = test.find_tests(["test"])

puts("\nDiscovered " .. test_files.len()._str() .. " test files\n")

# Load each test file - tests self-execute via test.it()
for file in test_files
    sys.load_module(file)
end

# Print final test summary
test.run()
