let i = 0
while i < 5
    puts("Before break check: i = " .. i.str())
    if i == 2
        puts("About to break!")
        break
        puts("After break (should not print)")
    end
    puts("After if: i = " .. i.str())
    i = i + 1
end
puts("After while loop: i = " .. i.str())
