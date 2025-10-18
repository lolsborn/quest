fun helper()
    puts("Helper")
end

fun caller()
    puts("In caller, about to call helper")
    helper()
    puts("Called helper from caller")
end

puts("Calling from top level works:")
helper()

puts("")
puts("Now calling from within a function:")
caller()
