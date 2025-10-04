"""
# Documentation formatting utilities.

This module provides functions for formatting and displaying documentation,
including markdown rendering with terminal colors.

**Example:**
```quest
  use "std/doc" as doc
  use "std/term" as term

  let md = "# Hello\n\nThis is **bold** and `code`"
  puts(doc.format_markdown(md))
```
"""

use "std/term" as term
use "std/regex" as regex

let HEADER_SEPARATOR = term.cyan("════════════════════════════════════════════════════════════════════════════")
let H1_COLOR = "bold_cyan"
let H2_COLOR = "bold_cyan"
let H3_COLOR = "cyan"

%fun format_markdown(text)
"""
## Format markdown text with terminal colors and styling.

Applies ANSI color codes to markdown elements for terminal display.
Supports headers, bold, inline code, code blocks, links, lists, and 
blockquotes.

**Parameters:**
- `text` (**Str**) - Markdown text to format

**Returns:** **Str** - Formatted text with ANSI codes
"""

fun format_markdown(text)
    """
    Format markdown text with terminal colors and styling.
    """

    let lines = text.split("\n")
    let result = []
    let in_code_block = false
    let code_block_lines = []

    let i = 0
    while i.lt(lines.len())
        let line = lines.get(i)

        # Check for code block markers (handle indented ```)
        let trimmed_line = line
        let spaces_count = 0
        while spaces_count.lt(line.len()) and line.slice(spaces_count, spaces_count.plus(1)).eq(" ")
            spaces_count = spaces_count.plus(1)
        end
        if spaces_count.gt(0)
            trimmed_line = line.slice(spaces_count, line.len())
        end

        if trimmed_line.startswith("```")
            if in_code_block
                # End of code block - format and add (without ``` markers)
                let j = 0
                while j.lt(code_block_lines.len())
                    result = result.push(term.dimmed(code_block_lines.get(j)))
                    j = j.plus(1)
                end
                code_block_lines = []
                in_code_block = false
            else
                # Start of code block (don't add ``` marker)
                in_code_block = true
            end
            i = i.plus(1)
        elif in_code_block
            # If inside code block, collect lines
            code_block_lines = code_block_lines.push(line)
            i = i.plus(1)
        else
            # Format regular lines
            result = result.push(format_line(line))
            i = i.plus(1)
        end
    end

    # Join with newlines
    let output = ""
    let j = 0
    while j.lt(result.len())
        output = output .. result.get(j)
        if j.lt(result.len().minus(1))
            output = output .. "\n"
        end
        j = j.plus(1)
    end

    output
end

fun format_line(line)
    """
    Format a single line of markdown text.
    """
    let result = ""

    # Headers (with inline formatting support)
    # NOTE: Using elif due to bug #007 - return doesn't exit function in separate if blocks
    if line.startswith("### ")
        let tokens = tokenize_inline(line.slice(4, line.len()))
        result = render_tokens_with_color(tokens, H3_COLOR)
    elif line.startswith("## ")
        let tokens = tokenize_inline(line.slice(3, line.len()))
        result = render_tokens_with_color(tokens, H2_COLOR) .. "\n" .. HEADER_SEPARATOR
    elif line.startswith("# ")
        # H1 gets bold cyan with inline formatting
        let tokens = tokenize_inline(line.slice(2, line.len()))
        result = render_tokens_with_color(tokens, H1_COLOR) .. "\n" .. HEADER_SEPARATOR
    # Blockquotes - with inline formatting
    elif line.startswith("> ")
        let tokens = tokenize_inline(line.slice(2, line.len()))
        result = term.grey("  ") .. render_tokens_with_color(tokens, "grey")
    # List items - apply inline formatting to item text only
    elif line.startswith("- ") or line.startswith("* ")
        let tokens = tokenize_inline(line.slice(2, line.len()))
        result = term.green("  • ") .. render_tokens(tokens)
    # Indented list items (strip leading spaces, check for list marker)
    elif line.startswith(" ")
        let i = 0
        while i.lt(line.len()) and line.slice(i, i.plus(1)).eq(" ")
            i = i.plus(1)
        end
        if i.lt(line.len())
            let remaining = line.slice(i, line.len())
            if remaining.startswith("- ") or remaining.startswith("* ")
                let tokens = tokenize_inline(remaining.slice(2, remaining.len()))
                result = term.green("  • ") .. render_tokens(tokens)
            else
                let tokens = tokenize_inline(line)
                result = render_tokens(tokens)
            end
        else
            result = ""
        end
    # Regular line with inline formatting
    else
        let tokens = tokenize_inline(line)
        result = render_tokens(tokens)
    end

    result
end

fun tokenize_inline(text)
    """
    Tokenize inline markdown elements in text.
    """
    let tokens = []
    let i = 0
    let text_buffer = ""

    while i.lt(text.len())
        let matched = false

        # Try to match ** for bold
        if i.plus(1).lt(text.len())
            if text.slice(i, i.plus(2)).eq("**")
                # Flush text buffer
                if text_buffer.len().gt(0)
                    tokens = tokens.push({"type": "text", "content": text_buffer})
                    text_buffer = ""
                end

                # Find closing **
                let j = i.plus(2)
                let close_pos = -1
                while j.plus(1).lte(text.len())
                    if text.slice(j, j.plus(2)).eq("**")
                        close_pos = j
                        j = text.len()  # Exit loop
                    else
                        j = j.plus(1)
                    end
                end

                if close_pos.gt(-1)
                    tokens = tokens.push({
                        "type": "bold",
                        "content": text.slice(i.plus(2), close_pos)
                    })
                    i = close_pos.plus(2)
                    matched = true
                end
            end
        end

        # Try to match ` for code
        if not matched and text.slice(i, i.plus(1)).eq("`")
            # Flush text buffer
            if text_buffer.len().gt(0)
                tokens = tokens.push({"type": "text", "content": text_buffer})
                text_buffer = ""
            end

            # Find closing `
            let j = i.plus(1)
            let close_pos = -1
            while j.lt(text.len())
                if text.slice(j, j.plus(1)).eq("`")
                    close_pos = j
                    j = text.len()  # Exit loop
                else
                    j = j.plus(1)
                end
            end

            if close_pos.gt(-1)
                tokens = tokens.push({
                    "type": "code",
                    "content": text.slice(i.plus(1), close_pos)
                })
                i = close_pos.plus(1)
                matched = true
            end
        end

        # Try to match [text](url)
        if not matched and text.slice(i, i.plus(1)).eq("[")
            # Flush text buffer
            if text_buffer.len().gt(0)
                tokens = tokens.push({"type": "text", "content": text_buffer})
                text_buffer = ""
            end

            let link_match = try_match_link(text, i)
            if link_match.get("found")
                tokens = tokens.push({
                    "type": "link",
                    "content": link_match.get("text"),
                    "url": link_match.get("url")
                })
                i = link_match.get("end")
                matched = true
            end
        end

        # No match - accumulate in text buffer
        if not matched
            text_buffer = text_buffer .. text.slice(i, i.plus(1))
            i = i.plus(1)
        end
    end

    # Flush remaining text buffer
    if text_buffer.len().gt(0)
        tokens = tokens.push({"type": "text", "content": text_buffer})
    end

    tokens
end

fun render_tokens(tokens)
    """
    Render tokens to formatted string.
    """
    let result = ""
    let i = 0

    while i.lt(tokens.len())
        let token = tokens.get(i)
        let token_type = token.get("type")

        if token_type.eq("bold")
            # Check if bold text contains error keywords
            let content = token.get("content")
            if content.contains("Warning") or content.contains("Error") or content.contains("Exception")
                # Has error keyword - apply bold + red highlighting
                result = result .. term.bold(highlight_errors(content))
            else
                result = result .. term.bold(content)
            end
        elif token_type.eq("code")
            result = result .. term.yellow(token.get("content"))
        elif token_type.eq("link")
            # Apply formatting to content and url separately
            result = result .. term.blue(term.underline(token.get("content")))
            result = result .. term.grey(" (" .. token.get("url") .. ")")
        else
            # Apply error keyword highlighting to plain text
            result = result .. highlight_errors(token.get("content"))
        end

        i = i.plus(1)
    end

    result
end

fun highlight_errors(text)
    """
    Highlight error keywords in text with red color.
    """
    let result = text

    # Check if text contains any keywords before processing
    if text.contains("Warning")
        result = replace_keyword(result, "Warning")
    end
    if result.contains("Error")
        result = replace_keyword(result, "Error")
    end
    if result.contains("Exception")
        result = replace_keyword(result, "Exception")
    end

    result
end

fun replace_keyword(text, keyword)
    """
    Replace occurrences of keyword in text with red-colored version.
    """
    let parts = text.split(keyword)
    let parts_len = parts.len()

    if parts_len.lt(2)
        return text
    end

    let result = ""
    let i = 0
    while i.lt(parts_len)
        result = result .. parts.get(i)
        if i.lt(parts_len.minus(1))
            result = result .. term.red(keyword)
        end
        i = i.plus(1)
    end
    result
end

fun render_tokens_with_color(tokens, base_color)
    """
    Render tokens to formatted string with a base color for text.   
    """
    let result = ""
    let i = 0

    while i.lt(tokens.len())
        let token = tokens.get(i)
        let token_type = token.get("type")

        if token_type.eq("bold")
            # Check if bold text contains error keywords
            let content = token.get("content")
            if content.contains("Warning") or content.contains("Error") or content.contains("Exception")
                # Has error keyword - apply bold + red highlighting
                result = result .. term.bold(highlight_errors(content))
            else
                result = result .. term.bold(content)
            end
        elif token_type.eq("code")
            # Code is always yellow, even in headers
            result = result .. term.yellow(token.get("content"))
        elif token_type.eq("link")
            result = result .. term.blue(term.underline(token.get("content")))
            result = result .. term.grey(" (" .. token.get("url") .. ")")
        else
            # Text token - check for error keywords first
            let content = token.get("content")
            let has_errors = content.contains("Warning") or content.contains("Error") or content.contains("Exception")

            if has_errors
                # Has error keywords - highlight them in red, skip base color for simplicity
                result = result .. highlight_errors(content)
            else
                # No errors - apply base color
                if base_color.eq("cyan")
                    result = result .. term.cyan(content)
                elif base_color.eq("bold_cyan")
                    result = result .. term.bold(term.cyan(content))
                elif base_color.eq("grey")
                    result = result .. term.grey(content)
                else
                    result = result .. content
                end
            end
        end

        i = i.plus(1)
    end

    result
end

# Try to match [text](url) pattern starting at position i
fun try_match_link(text, start_pos)
    let i = start_pos.plus(1)
    let text_part = ""

    # Find closing ]
    while i.lt(text.len())
        let ch = text.slice(i, i.plus(1))
        if ch.eq("]")
            # Found ], now check for (
            if i.plus(1).lt(text.len())
                let next_ch = text.slice(i.plus(1), i.plus(2))
                if next_ch.eq("(")
                    # Found (, now find closing )
                    let url_start = i.plus(2)
                    let j = url_start
                    let url_part = ""

                    while j.lt(text.len())
                        let url_ch = text.slice(j, j.plus(1))
                        if url_ch.eq(")")
                            # Complete match!
                            return {
                                "found": true,
                                "text": text_part,
                                "url": url_part,
                                "end": j.plus(1)
                            }
                        end
                        url_part = url_part .. url_ch
                        j = j.plus(1)
                    end
                end
            end
            # No matching (, not a link
            return {"found": false}
        end
        text_part = text_part .. ch
        i = i.plus(1)
    end

    # No matching ], not a link
    {"found": false}
end
