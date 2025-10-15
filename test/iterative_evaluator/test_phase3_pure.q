# Test Phase 3 features without postfix operations
# Only uses: literals, comparisons, if statements, variables

let x = 5
let y = 10

# Test comparison operators
if x < y
    42
end

if x > y
    1
else
    2
end

if x == 5
    100
end

if x != 10
    200
end

# Test elif
if x == 1
    10
elif x == 5
    50
else
    0
end

# Nested if
if x < 10
    if y > 5
        999
    end
end
