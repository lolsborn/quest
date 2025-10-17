# Minimal reproduction for Bug #021
# Tests if errors inside if statements are caught by try/catch

puts("Testing if statement error handling...")

try
    if true
        raise "This error should be caught"
    end
    puts("ERROR: Code after raise executed!")
catch e
    puts("SUCCESS: Caught error: " .. e.message())
end

puts("\nIf you see 'SUCCESS' above, the bug is fixed.")
puts("If you see 'RuntimeErr' at the top, the bug is present.")
