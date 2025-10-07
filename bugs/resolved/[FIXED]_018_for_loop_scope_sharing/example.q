# Minimal reproduction of for-loop scope sharing bug

puts("=== Test 1: Basic let in for loop (BROKEN) ===")
puts("Expected: Print 2, 4, 6")
puts("Actual: Error on 2nd iteration")

for i in [1, 2, 3]
    let doubled = i * 2
    puts(doubled)
end

puts("\n=== Test 2: While loop with let (WORKS) ===")
puts("Expected: Print 2, 4, 6")

let items = [1, 2, 3]
let idx = 0
while idx < items.len()
    let doubled = items[idx] * 2
    puts(doubled)
    idx = idx + 1
end

puts("\n=== Test 3: For loop with assignment (WORKAROUND) ===")
puts("Expected: Print 2, 4, 6")

let doubled = nil
for i in [1, 2, 3]
    doubled = i * 2
    puts(doubled)
end
