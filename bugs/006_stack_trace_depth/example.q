#!/usr/bin/env quest
# Minimal reproduction of stack trace depth issue

fun inner()
    raise "error from inner"
end

fun middle()
    inner()
end

fun outer()
    middle()
end

puts("Testing stack trace depth...")
puts("")

try
    outer()
catch e
    let stack = e.stack()
    puts("Stack trace array length:")
    puts(stack.len())
    puts("")
    puts("Expected: >= 3 frames (inner, middle, outer)")
    puts("")
    puts("Actual stack trace:")
    stack.each(fun (frame)
        puts("  - " .. frame)
    end)
    puts("")

    if stack.len() < 3
        puts("❌ FAIL: Stack trace has fewer than 3 frames")
    else
        puts("✅ PASS: Stack trace has at least 3 frames")
    end
end
