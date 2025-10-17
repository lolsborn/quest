# Simplest possible test - try/catch around while with raise
puts("Starting test")

try
    puts("In try block")
    let i = 0
    while i < 2
        puts("Loop iteration " .. i.str())
        if i == 0
            puts("About to raise")
            raise "test"
        end
        i = i + 1
    end
    puts("After loop (shouldn't reach)")
catch e
    puts("In catch block!")
    puts("Caught: " .. e.message())
end

puts("After try/catch")
