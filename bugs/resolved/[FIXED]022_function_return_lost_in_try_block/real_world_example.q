# Bug #022: Real-world example from std/conf module
# This simulates the actual failure in conf.load_toml_file()

use "std/io" as io

fun load_toml_file(path)
    if not io.exists(path)
        puts("Path doesn't exist, returning {}")
        return {}  # ✅ This works correctly
    end

    try
        puts("Path exists, reading file...")
        let content = io.read(path)
        puts("File read, returning content dict")
        return {content: "parsed"}  # ❌ This returns nil
    catch e
        puts("Error in try block: " .. e.str())
        raise e
    end
end

puts("Test 1: Nonexistent file (early return from if)")
let result1 = load_toml_file("nonexistent.toml")
puts("Result1: " .. result1.str())
puts("Result1 is nil: " .. (result1 == nil).str())
puts("")

puts("Test 2: Existing file (early return from try)")
let result2 = load_toml_file("bugs/022_function_return_lost_in_try_block/example.q")
puts("Result2: " .. result2.str())
puts("Result2 is nil: " .. (result2 == nil).str())
puts("")

# Test assertions
puts("=== RESULTS ===")
if result1 != nil and not (result1 == nil)
    puts("✓ Test 1 PASS: Early return from if block works")
else
    puts("✗ Test 1 FAIL: Early return from if block broken")
end

if result2 != nil and not (result2 == nil)
    puts("✓ Test 2 PASS: Early return from try block works")
else
    puts("✗ Test 2 FAIL: Early return from try block broken (BUG #022)")
end
