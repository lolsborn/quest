# Term Module

The `term` module provides terminal control functions including colors, text attributes, cursor control, and screen management.

## Text Color Functions

### `term.color(text, color, attrs = [])`
Return colored text with optional attributes

**Parameters:**
- `text` - Text to colorize (Str)
- `color` - Color name (Str): "red", "green", "yellow", "blue", "magenta", "cyan", "white", "grey"
- `attrs` - Optional list of attributes (List): "bold", "dimmed", "underline", "blink", "reverse", "hidden"

**Returns:** Colored text string (Str)

**Example:**
```
puts(term.color("Error!", "red", ["bold"]))
puts(term.color("Success", "green"))
```

### `term.on_color(text, color)`
Return text with background color

**Parameters:**
- `text` - Text to colorize (Str)
- `color` - Background color name (Str): "red", "green", "yellow", "blue", "magenta", "cyan", "white", "grey"

**Returns:** Text with background color (Str)

**Example:**
```
puts(term.on_color("Warning", "yellow"))
```

### Convenience Color Functions

Quick color functions that take text and optional attributes:

- `term.red(text, attrs = [])`
- `term.green(text, attrs = [])`
- `term.yellow(text, attrs = [])`
- `term.blue(text, attrs = [])`
- `term.magenta(text, attrs = [])`
- `term.cyan(text, attrs = [])`
- `term.white(text, attrs = [])`
- `term.grey(text, attrs = [])`

**Example:**
```
puts(term.red("Error: File not found"))
puts(term.green("Test passed", ["bold"]))
puts(term.yellow("Warning: deprecated function"))
```

## Text Attribute Functions

### `term.bold(text)`
Return bold text

### `term.dimmed(text)`
Return dimmed text

### `term.underline(text)`
Return underlined text

### `term.blink(text)`
Return blinking text (may not work in all terminals)

### `term.reverse(text)`
Return text with reversed foreground/background

### `term.hidden(text)`
Return hidden text

**Example:**
```
puts(term.bold("Important Message"))
puts(term.underline("Underlined text"))
```

## Cursor Control

### `term.move_up(n = 1)`
Move cursor up n lines

**Parameters:**
- `n` - Number of lines (Num, default 1)

### `term.move_down(n = 1)`
Move cursor down n lines

### `term.move_left(n = 1)`
Move cursor left n columns

### `term.move_right(n = 1)`
Move cursor right n columns

### `term.move_to(row, col)`
Move cursor to specific position

**Parameters:**
- `row` - Row number (Num, 1-indexed)
- `col` - Column number (Num, 1-indexed)

**Example:**
```
term.move_to(1, 1)  # Move to top-left corner
puts("Header")
```

### `term.save_cursor()`
Save current cursor position

### `term.restore_cursor()`
Restore previously saved cursor position

## Screen Control

### `term.clear()`
Clear entire screen

### `term.clear_line()`
Clear current line

### `term.clear_to_end()`
Clear from cursor to end of screen

### `term.clear_to_start()`
Clear from cursor to start of screen

**Example:**
```
term.clear()
term.move_to(1, 1)
puts("Fresh screen!")
```

## Terminal Properties

### `term.width()`
Get terminal width in columns

**Returns:** Number of columns (Num)

### `term.height()`
Get terminal height in rows

**Returns:** Number of rows (Num)

### `term.size()`
Get terminal size as [height, width]

**Returns:** List containing [rows, columns]

**Example:**
```
let size = term.size()
puts("Terminal is ", size[1], "x", size[0])
```

## Style Combinations

### `term.styled(text, fg = nil, bg = nil, attrs = [])`
Apply multiple styles at once

**Parameters:**
- `text` - Text to style (Str)
- `fg` - Foreground color name or nil (Str or Nil)
- `bg` - Background color name or nil (Str or Nil)
- `attrs` - List of attributes (List)

**Returns:** Styled text (Str)

**Example:**
```
puts(term.styled("ERROR", "white", "red", ["bold"]))
puts(term.styled("Success", "green", nil, ["bold", "underline"]))
```

## ANSI Control

### `term.reset()`
Return ANSI reset code to clear all formatting

**Returns:** Reset string (Str)

### `term.strip_colors(text)`
Remove all ANSI color codes from text

**Parameters:**
- `text` - Text with ANSI codes (Str)

**Returns:** Plain text without codes (Str)

**Example:**
```
let colored = term.red("Error")
let plain = term.strip_colors(colored)
```

## Progress Indicators

### `term.progress_bar(current, total, width = 50, char = "=")`
Create a text-based progress bar

**Parameters:**
- `current` - Current progress value (Num)
- `total` - Total/maximum value (Num)
- `width` - Width of bar in characters (Num, default 50)
- `char` - Character to use for filled portion (Str, default "=")

**Returns:** Progress bar string (Str)

**Example:**
```
let progress = term.progress_bar(75, 100, 40)
puts(progress, " 75%")
# Output: [==============================          ] 75%
```

### `term.spinner(frame)`
Get spinner animation frame

**Parameters:**
- `frame` - Frame number (Num)

**Returns:** Spinner character (Str)

**Example:**
```
let frames = ["", "", "9", "8", "<", "4", "&", "'", "", ""]
let i = 0
loop
    print("\r", term.spinner(i), " Loading...")
    sleep(0.1)
    i = (i + 1) % 10
end
```

## Common Use Cases

### Logging Levels
```
# Different colored log levels
puts("[", term.blue("INFO"), "] Server started")
puts("[", term.yellow("WARN"), "] High memory usage")
puts("[", term.red("ERROR", ["bold"]), "] Connection failed")
puts("[", term.green("OK"), "] All tests passed")
```

### Highlighting
```
# Highlight specific parts of output
puts("Found ", term.cyan(file_count), " files in ", term.yellow(directory))
```

### Status Messages
```
# Success/failure messages
if result
    puts(term.green(""), " Operation completed successfully")
else
    puts(term.red(""), " Operation failed")
end
```

### Tables and Borders
```
# Create formatted tables
term.clear()
puts(term.bold(term.blue("=" * 60)))
puts(term.bold("Report Summary"))
puts(term.bold(term.blue("=" * 60)))
puts("Total: ", term.cyan(total))
puts("Passed: ", term.green(passed))
puts("Failed: ", term.red(failed))
```
