# Bug #020: Minimal Reproduction - Scope Leak in Iterative Evaluator
# Simplest possible test case to demonstrate the scope leak

puts("=== Minimal Scope Leak Reproduction ===\n")

# Test: Error in While Loop
puts("Test: Error in While Loop with 3 iterations")
puts("-" * 40)

try
    let i = 0
    while i < 3
        let x = i * 2
        puts("Iteration " .. i.str() .. ": x = " .. x.str())

        # Trigger error on iteration 1
        if i == 1
            undefined_variable  # This should cause a NameErr
        end

        i = i + 1
    end
catch e
    puts("Caught error: " .. e.message())
end

puts("✓ Completed (if scopes leaked, they're now in memory)")
puts()
puts("Expected behavior: Error should be caught, no scope leak")
puts("Actual behavior: Iteration 0 pushed a scope that was never popped")
