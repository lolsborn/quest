# Bug #021: If Statement Errors Bypass Try/Catch
# Demonstrates that errors in if statement bodies are not caught by try/catch

puts("=== Bug #021: If Statement Errors Bypass Try/Catch ===\n")

# Test 1: Simple if in try block
puts("Test 1: Simple if statement in try block")
puts("-" * 40)

try
    puts("Before if")
    if true
        puts("Inside if")
        raise "error in if"
    end
    puts("After if (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

# Test 2: If in while loop in try block
puts("Test 2: If inside while loop in try block")
puts("-" * 40)

try
    let i = 0
    while i < 3
        puts("Iteration " .. i.str())
        if i == 1
            raise "error at iteration 1"
        end
        i = i + 1
    end
    puts("After loop (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

# Test 3: If in for loop in try block
puts("Test 3: If inside for loop in try block")
puts("-" * 40)

try
    for item in [1, 2, 3, 4, 5]
        puts("Processing item " .. item.str())
        if item == 3
            raise "error at item 3"
        end
    end
    puts("After loop (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

# Test 4: Nested if statements
puts("Test 4: Nested if statements")
puts("-" * 40)

try
    if true
        puts("Outer if")
        if true
            puts("Inner if")
            raise "error in nested if"
        end
    end
    puts("After nested if (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

# Test 5: If with elif
puts("Test 5: If with elif clause")
puts("-" * 40)

try
    let x = 5
    if x < 5
        puts("x is small")
    elif x == 5
        puts("x equals 5")
        raise "error in elif"
    end
    puts("After if/elif (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

# Test 6: If with else
puts("Test 6: If with else clause")
puts("-" * 40)

try
    let x = 10
    if x < 5
        puts("x is small")
    else
        puts("x is not small")
        raise "error in else"
    end
    puts("After if/else (shouldn't reach)")
catch e
    puts("✓ Caught: " .. e.message())
end
puts()

puts("=== Expected Behavior ===")
puts("All 6 tests should print '✓ Caught: ...'")
puts("If any test shows 'RuntimeErr: ...' at the top, the bug is present.")
