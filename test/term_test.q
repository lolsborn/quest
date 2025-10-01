use term

puts("=== Basic Colors ===")
puts(term.red("This is red text"))
puts(term.green("This is green text"))
puts(term.yellow("This is yellow text"))
puts(term.blue("This is blue text"))
puts(term.magenta("This is magenta text"))
puts(term.cyan("This is cyan text"))

puts()
puts("=== Text Attributes ===")
puts(term.bold("Bold text"))
puts(term.underline("Underlined text"))
puts(term.dimmed("Dimmed text"))

puts()
puts("=== Colors with Attributes ===")
puts(term.red("Bold red", ["bold"]))
puts(term.green("Bold underlined green", ["bold", "underline"]))

puts()
puts("=== Color Function ===")
puts(term.color("Custom colored", "cyan", []))
puts(term.color("Cyan bold underline", "cyan", ["bold", "underline"]))

puts()
puts("=== Background Colors ===")
puts(term.on_color("White on red", "red"))
puts(term.on_color("White on blue", "blue"))

puts()
puts("=== Styled Function ===")
puts(term.styled("White on red, bold", "white", "red", ["bold"]))
puts(term.styled("Green text only", "green", "", []))

puts()
puts("=== Terminal Size ===")
let width = term.width()
let height = term.height()
puts("Terminal width: ", width)
puts("Terminal height: ", height)

let size = term.size()
puts("Terminal size [h, w]: ", size)

puts()
puts("=== ANSI Control ===")
let colored_text = term.red("Colored")
puts("Before strip: ", colored_text)
let plain = term.strip_colors(colored_text)
puts("After strip: ", plain)

puts()
puts("Reset code: ", term.reset())
