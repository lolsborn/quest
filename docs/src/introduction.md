# Introduction

Quest is a Ruby-inspired programming language with a focus on clarity, simplicity, and powerful abstractions. Built on a pure object-oriented foundation, Quest treats everything as an object—from numbers and strings to functions and modules.

## Key Features

- **Pure Object-Oriented**: Everything in Quest is an object. Numbers, booleans, strings, functions—all implement the same fundamental object interface.
- **Ruby-like Syntax**: Familiar and readable syntax inspired by Ruby, making it easy to learn and enjoyable to write.
- **Method-Based Operations**: All operations are method calls, providing consistency and extensibility.
- **First-Class Functions**: Functions are objects that can be passed, returned, and inspected like any other value.
- **Module System**: Organize code with a simple and powerful module system.
- **Interactive REPL**: Experiment and develop interactively with a feature-rich REPL.

## Philosophy

Quest is designed with the following principles:

1. **Everything is an object** - No special cases, no primitives. This uniformity makes the language easier to learn and reason about.
2. **Explicit is better than implicit** - Variable declarations use `let`, operations are clear method calls.
3. **Small but complete** - A carefully curated set of features that work well together rather than a sprawling standard library.
4. **Developer experience matters** - Clear error messages, helpful documentation, and great tooling.

## Example

Here's a taste of Quest:

```quest
# Variables and basic types
let name = "World"
let count = 42
let active = true

# Everything is an object with methods
puts(name.upper())        # "WORLD"
puts(count.plus(8))       # 50
puts(active.eq(true))     # true

# Arrays and functional operations
let numbers = [1, 2, 3, 4, 5]
let doubled = numbers.map(fun (x) x.times(2) end)
puts(doubled)             # [2, 4, 6, 8, 10]

# Control flow
if count > 40
    puts("Count is high")
elif count > 20
    puts("Count is medium")
else
    puts("Count is low")
end

# Loops
for i in 0 to 4
    puts("Iteration ", i)
end

# Functions
fun greet(name)
    "Hello, " .. name .. "!"
end

puts(greet("Quest"))      # "Hello, Quest!"
```

## Getting Started

Continue to the [Getting Started](./getting-started.md) section to install Quest and run your first program.
