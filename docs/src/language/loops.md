# Loops

Quest provides three loop constructs that cover all iteration needs with clean, readable syntax.

## `while` Loop

Repeats while a condition is true.

**Syntax:**
```quest
while condition
    # statements
end
```

**Examples:**
```quest
# Basic counter
let i = 0
while i < 5
    puts(i)
    i = i + 1
end

# Process until complete
while !queue.empty()
    let item = queue.pop()
    process(item)
end

# Infinite loop with break
while true
    let line = read_line()
    if line == "quit"
        break
    end
    process(line)
end
```

## `for` Loop

Iterates over collections and numeric ranges.

**Syntax:**
```quest
# Iterate over collection
for item in collection
    # statements
end

# Numeric range (inclusive)
for i in start to end
    # statements
end

# Numeric range (exclusive)
for i in start until end
    # statements
end

# With step
for i in start to end step increment
    # statements
end

# With index
for item, index in collection
    # statements
end
```

**Examples:**
```quest
# Array iteration
let names = ["Alice", "Bob", "Charlie"]
for name in names
    puts("Hello, ", name)
end

# Numeric ranges
for i in 0 to 4
    puts(i)  # 0, 1, 2, 3, 4
end

for i in 0 until 5
    puts(i)  # 0, 1, 2, 3, 4
end

# With step
for i in 0 to 10 step 2
    puts(i)  # 0, 2, 4, 6, 8, 10
end

# Countdown
for i in 10 to 0 step -1
    puts(i)
end

# With index
for item, i in ["a", "b", "c"]
    puts(i, ": ", item)  # 0: a, 1: b, 2: c
end

# Dictionary iteration
let scores = {"Alice": 95, "Bob": 87}
for key, value in scores
    puts(key, " scored ", value)
end

# Nested loops
for row in 0 to 2
    for col in 0 to 2
        puts("(", row, ", ", col, ")")
    end
end
```

## `.each` Method

Functional-style iteration on collections.

**Syntax:**
```quest
collection.each(fun (item)
    # statements
end)

dictionary.each(fun (key, value)
    # statements
end)
```

**Examples:**
```quest
# Array iteration
[1, 2, 3, 4, 5].each(fun (n)
    puts(n * 2)
end)

# Dictionary iteration
{"a": 1, "b": 2}.each(fun (key, value)
    puts(key, " = ", value)
end)

# Method chaining
numbers
    .filter(fun (n) n > 5 end)
    .map(fun (n) n * 2 end)
    .each(fun (n) puts(n) end)
```

## Loop Control

### `break`

Exits the innermost loop immediately.

```quest
for i in 0 to 100
    if i == 10
        break
    end
    puts(i)
end
```

### `continue`

Skips the rest of the current iteration.

```quest
# Skip even numbers
for i in 0 to 10
    if i % 2 == 0
        continue
    end
    puts(i)  # Only odd numbers
end
```

## Common Patterns

### Process All Items
```quest
for user in users
    send_email(user)
end
```

### Numeric Iteration
```quest
for i in 0 to 9
    print(i, " ")
end
puts()
```

### Conditional Processing
```quest
while has_more_data()
    let data = fetch_next()
    process(data)
end
```

### Infinite Loop
```quest
while true
    let input = prompt("Enter command: ")
    if input == "quit"
        break
    end
    execute(input)
end
```

### Functional Pipeline
```quest
data
    .filter(fun (x) x > 0 end)
    .map(fun (x) x * 2 end)
    .each(fun (x) puts(x) end)
```

### Matrix Iteration
```quest
for row in 0 until height
    for col in 0 until width
        process(image[row][col])
    end
end
```

### Skip Invalid Items
```quest
for file in files
    if !file.exists()
        continue
    end
    process_file(file)
end
```

