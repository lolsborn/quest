# Bug #020: Scope Leak in Iterative Evaluator
# Demonstrates scope leaks when errors occur in loop bodies

use "std/sys"

puts("=== Scope Leak Demonstration ===\n")

# NOTE: Requires sys.get_scope_depth() implementation
# This is a proposed API for testing scope leaks

# Helper function to get current scope depth
# (Placeholder - needs implementation in std/sys)
fun get_scope_depth()
    # TODO: Implement in Rust
    # Should return current depth of scope stack
    return 0  # Placeholder
end

# ============================================================================
# Test 1: Error in While Loop Body
# ============================================================================

puts("Test 1: Error in While Loop Body")
puts("-" * 40)

let initial_depth = get_scope_depth()
puts("Initial scope depth: " .. initial_depth.str())

try
    let i = 0
    while i < 5
        # Each iteration pushes a new scope
        let x = i * 2
        puts("Iteration " .. i.str() .. ": x = " .. x.str())

        # Trigger error on iteration 2
        if i == 2
            undefined_variable  # NameErr: Undefined variable
        end

        i = i + 1
    end
catch e
    puts("Caught error: " .. e.message())
end

let final_depth = get_scope_depth()
let leaked = final_depth - initial_depth

puts("Final scope depth: " .. final_depth.str())
puts("Scopes leaked: " .. leaked.str())
puts("Expected: 0, Actual: " .. leaked.str())

if leaked > 0
    puts("❌ LEAK DETECTED: " .. leaked.str() .. " scopes leaked")
else
    puts("✓ No leak detected")
end

puts()

# ============================================================================
# Test 2: Error in Nested Loops
# ============================================================================

puts("Test 2: Error in Nested Loops")
puts("-" * 40)

let initial_depth = get_scope_depth()
puts("Initial scope depth: " .. initial_depth.str())

try
    let i = 0
    while i < 3
        puts("Outer iteration " .. i.str())

        let j = 0
        while j < 3
            puts("  Inner iteration " .. j.str())

            # Trigger error in middle of nested loops
            if i == 1 and j == 1
                undefined_function()
            end

            j = j + 1
        end

        i = i + 1
    end
catch e
    puts("Caught error: " .. e.message())
end

let final_depth = get_scope_depth()
let leaked = final_depth - initial_depth

puts("Final scope depth: " .. final_depth.str())
puts("Scopes leaked: " .. leaked.str())
puts("Expected: 0, Actual: " .. leaked.str())

if leaked > 0
    puts("❌ LEAK DETECTED: " .. leaked.str() .. " scopes leaked")
    puts("   (Likely: 1 outer scope + 1 inner scope)")
else
    puts("✓ No leak detected")
end

puts()

# ============================================================================
# Test 3: Error in For Loop
# ============================================================================

puts("Test 3: Error in For Loop Body")
puts("-" * 40)

let initial_depth = get_scope_depth()
puts("Initial scope depth: " .. initial_depth.str())

try
    let items = [1, 2, 3, 4, 5]
    for item in items
        let doubled = item * 2
        puts("Processing item " .. item.str() .. " -> " .. doubled.str())

        # Trigger error on item 3
        if item == 3
            raise "Intentional error"
        end
    end
catch e
    puts("Caught error: " .. e.message())
end

let final_depth = get_scope_depth()
let leaked = final_depth - initial_depth

puts("Final scope depth: " .. final_depth.str())
puts("Scopes leaked: " .. leaked.str())
puts("Expected: 0, Actual: " .. leaked.str())

if leaked > 0
    puts("❌ LEAK DETECTED: " .. leaked.str() .. " scopes leaked")
    puts("   (Likely: 3 scopes from iterations 0, 1, 2)")
else
    puts("✓ No leak detected")
end

puts()

# ============================================================================
# Test 4: Try/Catch Should NOT Leak (Control Test)
# ============================================================================

puts("Test 4: Try/Catch Block (Should Be Safe)")
puts("-" * 40)

let initial_depth = get_scope_depth()
puts("Initial scope depth: " .. initial_depth.str())

# Try/catch blocks have explicit scope cleanup in exception handler
try
    let x = 1
    let y = 2
    undefined_in_try_block
catch e
    puts("Caught error: " .. e.message())
end

let final_depth = get_scope_depth()
let leaked = final_depth - initial_depth

puts("Final scope depth: " .. final_depth.str())
puts("Scopes leaked: " .. leaked.str())
puts("Expected: 0, Actual: " .. leaked.str())

if leaked > 0
    puts("❌ UNEXPECTED LEAK: Try/catch should be safe!")
else
    puts("✓ No leak detected (as expected)")
end

puts()

# ============================================================================
# Test 5: Stress Test (High Volume)
# ============================================================================

puts("Test 5: Stress Test (1000 Errors)")
puts("-" * 40)

let initial_depth = get_scope_depth()
let error_count = 0

let iterations = 1000
let i = 0
while i < iterations
    try
        while true
            let temp = i
            undefined_variable
        end
    catch e
        error_count = error_count + 1
    end
    i = i + 1
end

let final_depth = get_scope_depth()
let leaked = final_depth - initial_depth

puts("Errors triggered: " .. error_count.str())
puts("Initial scope depth: " .. initial_depth.str())
puts("Final scope depth: " .. final_depth.str())
puts("Scopes leaked: " .. leaked.str())
puts("Expected: 0, Actual: " .. leaked.str())

if leaked > 0
    let bytes_leaked = leaked * 100  # Approximate 100 bytes per scope
    puts("❌ MAJOR LEAK: " .. leaked.str() .. " scopes (~" .. bytes_leaked.str() .. " bytes)")
else
    puts("✓ No leaks after " .. iterations.str() .. " error cycles")
end

puts()
puts("=== Test Complete ===")
puts()
puts("Summary:")
puts("  - Test 1 (while loop): Expected 0 leaks")
puts("  - Test 2 (nested loops): Expected 0 leaks")
puts("  - Test 3 (for loop): Expected 0 leaks")
puts("  - Test 4 (try/catch): Expected 0 leaks (control)")
puts("  - Test 5 (stress test): Expected 0 leaks after 1000 errors")
puts()
puts("If any leaks detected, Bug #020 is confirmed.")
