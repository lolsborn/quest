---
slug: /
---

# Introduction

Quest is a batteries-included general-purpose scripting language designed to **optimize developer productivity while remaining performant**. Built on a pure object-oriented foundation, Quest treats everything as an object—from numbers and strings to functions and modules—while providing the practical tools and libraries needed for real-world scripting, automation, and web development.

Quest draws inspiration from Ruby, Python, Go, and Rust, combining their best ideas into a unique, concise syntax that focuses on simplicity and getting things done.

## Primary Goal

**Maximize developer productivity without sacrificing performance.** Quest is designed to let you write less code, iterate faster, and ship more quickly—all while maintaining the speed and reliability your applications need.

## Key Features

- **Pure Object-Oriented**: Everything in Quest is an object. Numbers, booleans, strings, functions—all implement the same fundamental object interface.
- **Batteries Included**: Comprehensive standard library with modules for JSON, hashing, base64, file I/O, HTTP, terminal formatting, and more.
- **Concise, Simple Syntax**: A unique syntax designed for clarity and brevity. No unnecessary ceremony, just clear intent.
- **First-Class Functions**: Functions are objects that can be passed, returned, and inspected like any other value.
- **Module System**: Organize code with a simple and powerful module system.
- **Interactive REPL**: Experiment and develop interactively with a feature-rich REPL.
- **Advanced Web Tooling**: Built-in capabilities for web development and API integration.
- **Fast Execution**: Implemented in Rust for performance that keeps up with your productivity.

## Inspirations

Quest takes the best ideas from multiple languages:

- **Ruby**: Object-oriented purity, blocks/closures, developer happiness
- **Python**: Explicit is better than implicit, batteries-included philosophy
- **Go**: Simplicity, practical focus, clear error handling
- **Rust**: Safety through careful design, performance, modern tooling ecosystem

## Philosophy

Quest is designed with the following principles:

1. **Developer productivity first** - Optimize for writing, reading, and maintaining code quickly.
2. **Performance matters** - Fast iteration doesn't mean slow execution.
3. **Everything is an object** - No special cases, no primitives. This uniformity makes the language easier to learn and reason about.
4. **Batteries included** - Comprehensive standard library means less dependency management and more getting things done.
5. **Simplicity over cleverness** - Straightforward solutions beat clever abstractions.
6. **Explicit is better than implicit** - Variable declarations use `let`, operations are clear method calls.
7. **Great developer experience** - Clear error messages, helpful documentation, and fast feedback loops.

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
