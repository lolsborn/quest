"""
Terminal styling and control.

This module provides functions for colorizing text, controlling the cursor,
and managing terminal display.

Example:
  use "std/term" as term

  puts(term.red("Error: File not found"))
  puts(term.bold(term.green("Success!")))
"""

# =============================================================================
# Text Colors
# =============================================================================

%fun color(text, color_name)
"""
## Apply a named color to text.

**Parameters:**
- `text` (**Str**) - Text to colorize
- `color_name` (**Str**) - Color name (red, green, yellow, blue, magenta, cyan, white, grey)

**Returns:** **Str** - Text wrapped with ANSI color codes

**Example:**
```quest
puts(term.color("Hello", "red"))
```
"""

%fun on_color(text, color_name)
"""
## Apply a background color to text.

**Parameters:**
- `text` (**Str**) - Text to style
- `color_name` (**Str**) - Background color name

**Returns:** **Str** - Text with background color

**Example:**
```quest
puts(term.on_color("Alert", "red"))
```
"""

%fun red(text)
"""
## Make text red.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Red-colored text

**Example:**
```quest
puts(term.red("Error: Something went wrong"))
```
"""

%fun green(text)
"""
## Make text green.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Green-colored text

**Example:**
```quest
puts(term.green("✓ Tests passed"))
```
"""

%fun yellow(text)
"""
## Make text yellow.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Yellow-colored text

**Example:**
```quest
puts(term.yellow("Warning: Deprecated function"))
```
"""

%fun blue(text)
"""
## Make text blue.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Blue-colored text
"""

%fun magenta(text)
"""
## Make text magenta.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Magenta-colored text
"""

%fun cyan(text)
"""
## Make text cyan.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Cyan-colored text
"""

%fun white(text)
"""
## Make text white.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - White-colored text
"""

%fun grey(text)
"""
## Make text grey.

**Parameters:**
- `text` (**Str**) - Text to colorize

**Returns:** **Str** - Grey-colored text

**Example:**
```quest
puts(term.grey("# Comment"))
```
"""

# =============================================================================
# Text Attributes
# =============================================================================

%fun bold(text)
"""
## Make text bold.

**Parameters:**
- `text` (**Str**) - Text to style

**Returns:** **Str** - Bold text

**Example:**
```quest
puts(term.bold("Important Message"))
```
"""

%fun dimmed(text)
"""
## Make text dimmed/faint.

**Parameters:**
- `text` (**Str**) - Text to style

**Returns:** **Str** - Dimmed text
"""

%fun underline(text)
"""
## Underline text.

**Parameters:**
- `text` (**Str**) - Text to style

**Returns:** **Str** - Underlined text

**Example:**
```quest
puts(term.underline("Link"))
```
"""

%fun blink(text)
"""
## Make text blink (not supported in all terminals).

**Parameters:**
- `text` (**Str**) - Text to style

**Returns:** **Str** - Blinking text
"""

%fun reverse(text)
"""
## Reverse foreground and background colors.

**Parameters:**
- `text` (**Str**) - Text to style

**Returns:** **Str** - Reversed text
"""

%fun hidden(text)
"""
## Make text hidden (invisible).

**Parameters:**
- `text` (**Str**) - Text to hide

**Returns:** **Str** - Hidden text
"""

# =============================================================================
# Cursor Control
# =============================================================================

%fun move_up(n)
"""
## Move cursor up n lines.

**Parameters:**
- `n` (**Num**) - Number of lines to move up

**Returns:** **Str** - ANSI escape sequence (print to apply)

**Example:**
```quest
print(term.move_up(3))
```
"""

%fun move_down(n)
"""
## Move cursor down n lines.

**Parameters:**
- `n` (**Num**) - Number of lines to move down

**Returns:** **Str** - ANSI escape sequence
"""

%fun move_left(n)
"""
## Move cursor left n columns.

**Parameters:**
- `n` (**Num**) - Number of columns to move left

**Returns:** **Str** - ANSI escape sequence
"""

%fun move_right(n)
"""
## Move cursor right n columns.

**Parameters:**
- `n` (**Num**) - Number of columns to move right

**Returns:** **Str** - ANSI escape sequence
"""

%fun move_to(row, col)
"""
## Move cursor to specific position.

**Parameters:**
- `row` (**Num**) - Row number (0-based)
- `col` (**Num**) - Column number (0-based)

**Returns:** **Str** - ANSI escape sequence

**Example:**
```quest
print(term.move_to(0, 0))  # Move to top-left corner
```
"""

%fun save_cursor()
"""
## Save current cursor position.

**Returns:** **Str** - ANSI escape sequence

**Example:**
```quest
print(term.save_cursor())
# ... do some printing ...
print(term.restore_cursor())
```
"""

%fun restore_cursor()
"""
## Restore saved cursor position.

**Returns:** **Str** - ANSI escape sequence
"""

# =============================================================================
# Screen Control
# =============================================================================

%fun clear()
"""
## Clear entire screen.

**Returns:** **Str** - ANSI escape sequence

**Example:**
```quest
print(term.clear())
```
"""

%fun clear_line()
"""
## Clear current line.

**Returns:** **Str** - ANSI escape sequence
"""

%fun clear_to_end()
"""
## Clear from cursor to end of screen.

**Returns:** **Str** - ANSI escape sequence
"""

%fun clear_to_start()
"""
## Clear from cursor to start of screen.

**Returns:** **Str** - ANSI escape sequence
"""

# =============================================================================
# Terminal Properties
# =============================================================================

%fun width()
"""
## Get terminal width in columns.

**Returns:** **Num** - Terminal width

**Example:**
```quest
let w = term.width()
puts("Terminal is " .. w.str() .. " columns wide")
```
"""

%fun height()
"""
## Get terminal height in rows.

**Returns:** **Num** - Terminal height
"""

%fun size()
"""
## Get terminal size as (width, height) tuple.

**Returns:** **Array[Num]** - [width, height]

**Example:**
```quest
let [w, h] = term.size()
puts("Terminal: " .. w.str() .. "x" .. h.str())
```
"""

# =============================================================================
# Style Combinations
# =============================================================================

%fun styled(text, styles)
"""
## Apply multiple styles to text.

**Parameters:**
- `text` (**Str**) - Text to style
- `styles` (**Array[Str]**) - List of style names

**Returns:** **Str** - Styled text

**Example:**
```quest
puts(term.styled("Error", ["bold", "red"]))
puts(term.styled("Success", ["bold", "green", "underline"]))
```
"""

# =============================================================================
# ANSI Control
# =============================================================================

%fun reset()
"""
## Reset all terminal styles and colors.

**Returns:** **Str** - ANSI reset sequence

**Example:**
```quest
print(term.red("Red text"))
print(term.reset())  # Back to normal
```
"""

%fun strip_colors(text)
"""
## Remove all ANSI color codes from text.

**Parameters:**
- `text` (**Str**) - Text containing ANSI codes

**Returns:** **Str** - Plain text without color codes

**Example:**
```quest
let colored = term.red("Error")
let plain = term.strip_colors(colored)
# plain = "Error"
```
"""
