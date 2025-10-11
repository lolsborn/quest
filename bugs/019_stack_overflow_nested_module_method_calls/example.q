# Minimal reproduction case for Bug #019
# Stack overflow when calling user-defined functions

# THE SIMPLEST POSSIBLE CASE - just two functions
fun helper()
    puts("Helper function")
end

fun main_fn()
    puts("Main function")
    helper()  # <-- CRASHES HERE with stack overflow
end

puts("About to call main_fn...")
main_fn()
puts("This line never executes")
