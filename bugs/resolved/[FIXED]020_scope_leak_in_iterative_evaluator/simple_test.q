# Simple test - does try/catch work at all?
puts("Test 1: Simple try/catch")
try
    undefined_var
catch e
    puts("Caught: " .. e.message())
end
puts("Done")
