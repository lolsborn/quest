# Test with direct raise in loop body (no if statement)
puts("Test: direct raise in while loop")

try
    let i = 0
    while i < 3
        puts("Iteration " .. i.str())
        raise "error at iteration " .. i.str()
        i = i + 1
    end
catch e
    puts("Caught: " .. e.message())
end

puts("Completed")
