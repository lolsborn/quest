let i = 0
while i < 10
    puts("i = " .. i.str())
    if i == 3
        break
    end
    i = i + 1
end
puts("After loop, i = " .. i.str())
