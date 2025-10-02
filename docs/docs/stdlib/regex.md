# Regex Module

The `regex` module provides powerful regular expression pattern matching and text manipulation capabilities. It wraps Rust's regex library, offering high performance and safety.

## Pattern Matching

### `regex.match(pattern, text)`
Check if text matches a regex pattern

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to match against (Str)

**Returns:** Bool (true if text matches pattern)

**Example:**
```quest
use "std/regex"

regex.match("\\d+", "abc123")       # true
regex.match("^\\d+$", "123")        # true
regex.match("^\\d+$", "abc123")     # false
```

## Finding Matches

### `regex.find(pattern, text)`
Find the first match of a pattern in text

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to search (Str)

**Returns:** Str (matched text) or Nil (if no match)

**Example:**
```quest
use "std/regex"

regex.find("\\d+", "abc123def456")  # "123"
regex.find("\\d+", "abcdef")        # nil
```

### `regex.find_all(pattern, text)`
Find all matches of a pattern in text

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to search (Str)

**Returns:** Array of matched strings

**Example:**
```quest
use "std/regex"

let matches = regex.find_all("\\d+", "abc123def456ghi789")
# ["123", "456", "789"]

let words = regex.find_all("\\w+", "hello brave new world")
# ["hello", "brave", "new", "world"]
```

## Capture Groups

### `regex.captures(pattern, text)`
Extract capture groups from the first match

**Parameters:**
- `pattern` - Regular expression pattern with groups (Str)
- `text` - Text to search (Str)

**Returns:** Array of captured strings or Nil (if no match)
- Index 0 contains the full match
- Index 1+ contain captured groups

**Example:**
```quest
use "std/regex"

let caps = regex.captures("(\\w+)@(\\w+\\.\\w+)", "user@example.com")
# ["user@example.com", "user", "example.com"]

let date = regex.captures("(\\d{4})-(\\d{2})-(\\d{2})", "2024-10-02")
# ["2024-10-02", "2024", "10", "02"]
```

### `regex.captures_all(pattern, text)`
Extract all capture groups from all matches

**Parameters:**
- `pattern` - Regular expression pattern with groups (Str)
- `text` - Text to search (Str)

**Returns:** Array of arrays (each inner array contains captured groups)

**Example:**
```quest
use "std/regex"

let all = regex.captures_all("(\\d+)-(\\d+)", "10-20 and 30-40")
# [["10-20", "10", "20"], ["30-40", "30", "40"]]

let first_match = all.get(0)
puts(first_match.get(1))  # "10"
puts(first_match.get(2))  # "20"
```

## Text Replacement

### `regex.replace(pattern, text, replacement)`
Replace the first match with replacement string

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to modify (Str)
- `replacement` - Replacement string (Str)

**Returns:** Str (modified text)

**Example:**
```quest
use "std/regex"

regex.replace("\\d+", "abc123def456", "NUM")
# "abcNUMdef456"

# Use capture groups in replacement
regex.replace("(\\w+)@(\\w+)", "user@example", "$2@$1")
# "example@user"
```

### `regex.replace_all(pattern, text, replacement)`
Replace all matches with replacement string

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to modify (Str)
- `replacement` - Replacement string (Str)

**Returns:** Str (modified text)

**Example:**
```quest
use "std/regex"

regex.replace_all("\\d+", "abc123def456", "NUM")
# "abcNUMdefNUM"

regex.replace_all("o", "hello world", "0")
# "hell0 w0rld"
```

## Splitting Text

### `regex.split(pattern, text)`
Split text by regex pattern

**Parameters:**
- `pattern` - Regular expression pattern (Str)
- `text` - Text to split (Str)

**Returns:** Array of strings

**Example:**
```quest
use "std/regex"

regex.split(",\\s*", "a, b, c, d")
# ["a", "b", "c", "d"]

regex.split("\\s+", "hello   world    foo")
# ["hello", "world", "foo"]

regex.split("\\d+", "a123b456c")
# ["a", "b", "c"]
```

## Pattern Validation

### `regex.is_valid(pattern)`
Check if a regex pattern is valid

**Parameters:**
- `pattern` - Regular expression pattern to validate (Str)

**Returns:** Bool (true if pattern is valid)

**Example:**
```quest
use "std/regex"

regex.is_valid("\\d+")               # true
regex.is_valid("[a-z]+")             # true
regex.is_valid("[")                  # false (unclosed bracket)
regex.is_valid("(")                  # false (unclosed paren)
```

## Common Patterns

### Email Validation
```quest
use "std/regex"

let email_pattern = "^[\\w.-]+@[\\w.-]+\\.\\w+$"

if regex.match(email_pattern, user_email)
    puts("Valid email")
else
    puts("Invalid email")
end
```

### Phone Number Extraction
```quest
use "std/regex"

let text = "Call me at 555-123-4567 or 555-987-6543"
let phone_pattern = "\\d{3}-\\d{3}-\\d{4}"
let phones = regex.find_all(phone_pattern, text)
# ["555-123-4567", "555-987-6543"]
```

### URL Parsing
```quest
use "std/regex"

let url_pattern = "(https?)://([^/]+)(.*)"
let caps = regex.captures(url_pattern, "https://example.com/path/to/page")

let protocol = caps.get(1)  # "https"
let domain = caps.get(2)    # "example.com"
let path = caps.get(3)      # "/path/to/page"
```

### Data Cleaning
```quest
use "std/regex"

# Remove extra whitespace
let cleaned = regex.replace_all("\\s+", text, " ")

# Remove HTML tags
let no_html = regex.replace_all("<[^>]+>", html, "")

# Extract numbers from text
let numbers = regex.find_all("\\d+", "Order #123 costs $45.67")
# ["123", "45", "67"]
```

### Log Parsing
```quest
use "std/regex"

let log_pattern = "\\[(\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2})\\] (\\w+): (.*)"
let log_line = "[2024-10-02 14:30:15] ERROR: Connection timeout"

let parts = regex.captures(log_pattern, log_line)
let timestamp = parts.get(1)  # "2024-10-02 14:30:15"
let level = parts.get(2)      # "ERROR"
let message = parts.get(3)    # "Connection timeout"
```

### Text Normalization
```quest
use "std/regex"

# Convert CamelCase to snake_case
let text = "getUserById"
let snake = regex.replace_all("([a-z])([A-Z])", text, "$1_$2").lower()
# "get_user_by_id"

# Slugify text
let title = "Hello World! This is Great."
let slug = regex.replace_all("[^\\w]+", title.lower(), "-")
# "hello-world-this-is-great-"
```

## Regular Expression Syntax

Quest uses Rust's regex syntax, which supports:
- **Character classes**: `\d` (digit), `\w` (word), `\s` (whitespace)
- **Quantifiers**: `*` (0+), `+` (1+), `?` (0-1), `{n,m}` (n to m)
- **Anchors**: `^` (start), `$` (end), `\b` (word boundary)
- **Groups**: `()` (capture), `(?:)` (non-capture)
- **Alternation**: `|` (or)
- **Character sets**: `[abc]`, `[^abc]`, `[a-z]`

**Note**: Backslashes must be escaped in strings: `"\\d+"` not `"\d+"`

## Performance Tips

1. **Pre-validate patterns**: Use `regex.is_valid()` before processing user input
2. **Reuse patterns**: If possible, compile patterns once
3. **Be specific**: More specific patterns match faster
4. **Avoid backtracking**: Catastrophic backtracking can slow down patterns like `(a+)+`

## Error Handling

Invalid regex patterns will raise an error when used:

```quest
use "std/regex"

# Always validate user-provided patterns
if regex.is_valid(user_pattern)
    let matches = regex.find_all(user_pattern, text)
else
    puts("Invalid regex pattern")
end
```
