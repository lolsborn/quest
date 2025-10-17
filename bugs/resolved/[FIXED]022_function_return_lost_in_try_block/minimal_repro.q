# Bug #022: Function Return Value Lost in Try Block
# Minimal reproduction case

fun test_with_try()
    try
        return {success: true}
    catch e
        puts("Error: " .. e.str())
    end
    return {fallback: true}
end

puts("Calling test_with_try()...")
let result = test_with_try()
puts("Result: " .. result.str())
puts("")

# Test assertions
if result.contains("success")
    puts("✓ PASS: Got correct return value from try block")
else
    puts("✗ FAIL: Return value was lost, got fallback instead")
    puts("  Expected: {success: true}")
    puts("  Actual:   " .. result.str())
end
