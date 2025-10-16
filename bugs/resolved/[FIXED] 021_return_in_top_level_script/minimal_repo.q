# Minimal reproduction case for Bug #021
# Using `return` at the top level of a script should cleanly exit,
# but instead throws "Error: __FUNCTION_RETURN__"

puts("Before return")
return
puts("After return - this should not print")
