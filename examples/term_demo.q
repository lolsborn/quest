"""
Terminal Styling Demo

This demo showcases all the color and formatting options available in the std/term module.
"""

use "std/term" as term

# =============================================================================
# Helper function to print section headers
# =============================================================================

fun print_header(title)
    puts("")
    puts(term.bold(term.cyan("═══════════════════════════════════════════════════════")))
    puts(term.bold(term.cyan(title)))
    puts(term.bold(term.cyan("═══════════════════════════════════════════════════════")))
    puts("")
end

fun print_subheader(title)
    puts("")
    puts(term.bold(term.white(title)))
    puts(term.dimmed("─────────────────────────────────────────────"))
end

# =============================================================================
# Basic Colors
# =============================================================================

print_header("1. Basic Text Colors")

puts(term.red("■ Red text - for errors and warnings"))
puts(term.green("■ Green text - for success messages"))
puts(term.yellow("■ Yellow text - for warnings and highlights"))
puts(term.blue("■ Blue text - for information"))
puts(term.magenta("■ Magenta text - for special emphasis"))
puts(term.cyan("■ Cyan text - for headers and links"))
puts(term.white("■ White text - for bright emphasis"))
puts(term.grey("■ Grey text - for comments and subdued content"))

# =============================================================================
# Text Formatting
# =============================================================================

print_header("2. Text Formatting Options")

puts(term.bold("■ Bold text - makes text stand out"))
puts(term.dimmed("■ Dimmed text - subtle, de-emphasized"))
puts(term.underline("■ Underlined text - for links or emphasis"))
puts(term.blink("■ Blinking text - attention grabbing (may not work in all terminals)"))
puts(term.reverse("■ Reversed text - inverted colors"))
puts("■ Hidden text: [" .. term.hidden("secret") .. "] - invisible")

# =============================================================================
# Colors + Formatting Combinations
# =============================================================================

print_header("3. Colors Combined with Formatting")

print_subheader("Bold Colors")
puts(term.bold(term.red("■ Bold Red - strong error messages")))
puts(term.bold(term.green("■ Bold Green - strong success messages")))
puts(term.bold(term.yellow("■ Bold Yellow - strong warnings")))
puts(term.bold(term.blue("■ Bold Blue - strong information")))
puts(term.bold(term.magenta("■ Bold Magenta - strong emphasis")))
puts(term.bold(term.cyan("■ Bold Cyan - strong headers")))

print_subheader("Underlined Colors")
puts(term.underline(term.red("■ Underlined Red - error links")))
puts(term.underline(term.green("■ Underlined Green - success links")))
puts(term.underline(term.yellow("■ Underlined Yellow - warning links")))
puts(term.underline(term.blue("■ Underlined Blue - information links")))
puts(term.underline(term.cyan("■ Underlined Cyan - standard links")))

print_subheader("Dimmed Colors")
puts(term.dimmed(term.red("■ Dimmed Red - subtle errors")))
puts(term.dimmed(term.green("■ Dimmed Green - subtle success")))
puts(term.dimmed(term.yellow("■ Dimmed Yellow - subtle warnings")))
puts(term.dimmed(term.blue("■ Dimmed Blue - subtle info")))
puts(term.dimmed(term.grey("■ Dimmed Grey - very subtle text")))

print_subheader("Reversed Colors")
puts(term.reverse(term.red("■ Reversed Red - highlighted error")))
puts(term.reverse(term.green("■ Reversed Green - highlighted success")))
puts(term.reverse(term.yellow("■ Reversed Yellow - highlighted warning")))
puts(term.reverse(term.blue("■ Reversed Blue - highlighted info")))

# =============================================================================
# Background Colors
# =============================================================================

print_header("4. Background Colors")

puts(term.on_color("  Red background  ", "red") .. " - error background")
puts(term.on_color("  Green background  ", "green") .. " - success background")
puts(term.on_color("  Yellow background  ", "yellow") .. " - warning background")
puts(term.on_color("  Blue background  ", "blue") .. " - info background")
puts(term.on_color("  Magenta background  ", "magenta") .. " - special background")
puts(term.on_color("  Cyan background  ", "cyan") .. " - header background")
puts(term.on_color("  White background  ", "white") .. " - bright background")
puts(term.on_color("  Grey background  ", "grey") .. " - subtle background")

# =============================================================================
# Multiple Style Combinations with styled()
# =============================================================================

print_header("5. Multiple Styles with styled()")

print_subheader("styled(text, fg_color, bg_color, attributes)")
puts(term.styled("■ Bold Red", "red", nil, ["bold"]) .. " - strong errors")
puts(term.styled("■ Bold Green", "green", nil, ["bold"]) .. " - strong success")
puts(term.styled("■ Bold Underline Blue", "blue", nil, ["bold", "underline"]) .. " - important link")
puts(term.styled("■ Bold Cyan", "cyan", nil, ["bold"]) .. " - section header")
puts(term.styled("■ Dimmed Yellow", "yellow", nil, ["dim"]) .. " - subtle warning")
puts(term.styled("■ Underline Magenta", "magenta", nil, ["underline"]) .. " - special link")
puts(term.styled("  Red on Yellow  ", "red", "yellow", ["bold"]) .. " - alert banner")
puts(term.styled("  White on Blue  ", "white", "blue", ["bold"]) .. " - info banner")

# =============================================================================
# Practical Examples
# =============================================================================

print_header("6. Practical Usage Examples")

print_subheader("Status Messages")
puts(term.bold(term.green("✓")) .. " Test passed successfully")
puts(term.bold(term.red("✗")) .. " Test failed with errors")
puts(term.bold(term.yellow("⚠")) .. " Warning: deprecated function")
puts(term.bold(term.blue("ℹ")) .. " Info: processing 1000 items")

print_subheader("Log Levels")
puts("[" .. term.dimmed("DEBUG") .. "] Starting application...")
puts("[" .. term.bold(term.blue("INFO")) .. " ] Server listening on port 8080")
puts("[" .. term.bold(term.yellow("WARN")) .. " ] High memory usage detected")
puts("[" .. term.bold(term.red("ERROR")) .. "] Failed to connect to database")
puts("[" .. term.bold(term.reverse(term.red("FATAL"))) .. "] Critical system failure")

print_subheader("Diff-style Output")
puts(term.green("+ Added line"))
puts(term.red("- Removed line"))
puts(term.cyan("@ Line changed"))
puts(term.dimmed("  Unchanged line"))

print_subheader("Progress Indicators")
puts(term.green("████████████") .. term.dimmed("████████") .. " 60% complete")
puts(term.bold(term.cyan("⣾")) .. " Loading...")
puts(term.yellow("▓▓▓▓▓▓▓▓▓▓░░░░░░░░░░") .. " 50%")

print_subheader("Syntax Highlighting Preview")
puts(term.magenta("fun") .. " " .. term.yellow("calculate") .. term.white("(") .. term.cyan("x") .. term.white(", ") .. term.cyan("y") .. term.white(")"))
puts("    " .. term.magenta("if") .. " x" .. term.white(".") .. term.green("gt") .. term.white("(") .. term.blue("0") .. term.white(")"))
puts("        " .. term.magenta("return") .. " x" .. term.white(".") .. term.green("plus") .. term.white("(") .. "y" .. term.white(")"))
puts("    " .. term.magenta("end"))
puts("    " .. term.magenta("return") .. " " .. term.blue("0"))
puts(term.magenta("end"))

print_subheader("UI Elements")
puts(term.reverse(term.bold("  File  ")) .. " " .. term.reverse(term.bold("  Edit  ")) .. " " .. term.reverse(term.bold("  View  ")) .. " " .. term.reverse(term.bold("  Help  ")))
puts("")
puts(term.bold(term.cyan("┌─────────────────────────────────────┐")))
puts(term.bold(term.cyan("│")) .. " " .. term.bold("Select an option:") .. "               " .. term.bold(term.cyan("│")))
puts(term.bold(term.cyan("├─────────────────────────────────────┤")))
puts(term.bold(term.cyan("│")) .. " " .. term.green("1.") .. " Start server                   " .. term.bold(term.cyan("│")))
puts(term.bold(term.cyan("│")) .. " " .. term.green("2.") .. " Stop server                    " .. term.bold(term.cyan("│")))
puts(term.bold(term.cyan("│")) .. " " .. term.green("3.") .. " View logs                      " .. term.bold(term.cyan("│")))
puts(term.bold(term.cyan("│")) .. " " .. term.red("0.") .. " Exit                           " .. term.bold(term.cyan("│")))
puts(term.bold(term.cyan("└─────────────────────────────────────┘")))

print_subheader("Color Palette Reference")
puts("Colors:   " .. term.red("red") .. " " .. term.green("green") .. " " .. term.yellow("yellow") .. " " .. term.blue("blue") .. " " .. term.magenta("magenta") .. " " .. term.cyan("cyan") .. " " .. term.white("white") .. " " .. term.grey("grey"))
puts("Styles:   " .. term.bold("bold") .. " " .. term.dimmed("dimmed") .. " " .. term.underline("underline") .. " " .. term.reverse("reverse"))

# =============================================================================
# Complex Combinations
# =============================================================================

print_header("7. Complex Style Combinations")

puts(term.bold(term.underline(term.red("■ Bold + Underline + Red"))) .. " - maximum emphasis error")
puts(term.bold(term.underline(term.green("■ Bold + Underline + Green"))) .. " - maximum emphasis success")
puts(term.dimmed(term.underline(term.blue("■ Dimmed + Underline + Blue"))) .. " - subtle link")
puts(term.bold(term.reverse(term.yellow("■ Bold + Reverse + Yellow"))) .. " - highlighted warning banner")
puts(term.bold(term.reverse(term.magenta("■ Bold + Reverse + Magenta"))) .. " - special banner")

puts(term.underline(term.cyan("■ Cyan")) .. " + " .. term.bold(term.yellow("Bold Yellow")) .. " + " .. term.dimmed(term.grey("Dimmed Grey")))
puts(term.bold(term.red("ERROR: ")) .. term.yellow("Connection timeout after ") .. term.bold(term.white("30s")))
puts(term.bold(term.green("SUCCESS: ")) .. term.white("Processed ") .. term.bold(term.cyan("1,234")) .. term.white(" items in ") .. term.bold(term.magenta("2.5s")))

# =============================================================================
# End
# =============================================================================

print_header("Demo Complete!")
puts(term.dimmed("Explore more by combining colors and styles in your own way!"))
puts("")
