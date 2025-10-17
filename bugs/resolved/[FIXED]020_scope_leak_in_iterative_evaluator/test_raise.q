# Test with explicit raise
puts("Test with explicit raise:")
try
    raise "test error"
catch e
    puts("Caught: " .. e.message())
end
puts("Done")

# Test in while loop
puts("\nTest in while loop:")
let i = 0
try
    while i < 3
        puts("Iteration " .. i.str())
        if i == 1
            raise "error at iteration 1"
        end
        i = i + 1
    end
catch e
    puts("Caught: " .. e.message())
end
puts("Completed")
