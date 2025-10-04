# Reproduction case for return statement bug

puts("Test 1: Multiple if blocks with returns")

fun test_return(x)
    puts("  Entering function with x = " .. x.to_string())

    if x.eq(1)
        puts("  First if block matched")
        return "first"
    end

    if x.eq(1)
        puts("  Second if block matched (should NOT execute)")
        return "second"
    end

    puts("  Reached end of function (should NOT execute)")
    return "third"
end

let result = test_return(1)
puts("Result: " .. result)
puts("Expected: first")
puts("")

puts("Test 2: Header formatting example from std/doc")

fun format_line(line)
    if line.startswith("### ")
        puts("  Found H3: " .. line)
        return "H3"
    end
    if line.startswith("## ")
        puts("  Found H2: " .. line)
        return "H2"
    end
    if line.startswith("# ")
        puts("  Found H1: " .. line)
        return "H1"
    end
    puts("  Regular line: " .. line)
    return "regular"
end

let h1_result = format_line("# Header")
puts("Result: " .. h1_result)
puts("Expected: H1")
puts("")

puts("Test 3: Workaround using elif")

fun format_line_fixed(line)
    if line.startswith("### ")
        puts("  Found H3: " .. line)
        return "H3"
    elif line.startswith("## ")
        puts("  Found H2: " .. line)
        return "H2"
    elif line.startswith("# ")
        puts("  Found H1: " .. line)
        return "H1"
    else
        puts("  Regular line: " .. line)
        return "regular"
    end
end

let h1_result_fixed = format_line_fixed("# Header")
puts("Result: " .. h1_result_fixed)
puts("Expected: H1")
