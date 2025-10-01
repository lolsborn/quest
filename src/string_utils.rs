// String utility functions for Quest
// Handles string parsing, formatting, and interpolation

use crate::types::*;
use crate::Scope;

/// Remove quotes from string literal and process escape sequences
pub fn parse_string(s: &str) -> String {
    // Remove quotes from string literal
    if s.starts_with("\"\"\"") && s.ends_with("\"\"\"") {
        // Multi-line string
        s[3..s.len()-3].to_string()
    } else if s.starts_with("\"") && s.ends_with("\"") {
        // Single-line string, process escape sequences
        let inner = &s[1..s.len()-1];
        process_escape_sequences(inner)
    } else {
        s.to_string()
    }
}

/// Format a value according to a Rust-style format specification
/// Supports: [fill][align][sign][#][0][width][.precision][type]
pub fn format_value(value: &QValue, spec: &str) -> Result<String, String> {
    // Parse format spec: [fill][align][sign][#][0][width][.precision][type]
    let mut fill = ' ';
    let mut align = '>'; // default right-align for numbers
    let mut sign = '-';
    let mut alternate = false;
    let mut width: Option<usize> = None;
    let mut precision: Option<usize> = None;
    let mut format_type = "";

    let chars: Vec<char> = spec.chars().collect();
    let mut i = 0;

    // Check for fill+align (must be first if present)
    if chars.len() >= 2 && (chars[1] == '<' || chars[1] == '>' || chars[1] == '^') {
        fill = chars[0];
        align = chars[1];
        i = 2;
    } else if !chars.is_empty() && (chars[0] == '<' || chars[0] == '>' || chars[0] == '^') {
        align = chars[0];
        i = 1;
    }

    // Check for sign
    if i < chars.len() && (chars[i] == '+' || chars[i] == '-' || chars[i] == ' ') {
        sign = chars[i];
        i += 1;
    }

    // Check for alternate form (#)
    if i < chars.len() && chars[i] == '#' {
        alternate = true;
        i += 1;
    }

    // Check for zero padding
    if i < chars.len() && chars[i] == '0' {
        fill = '0';
        i += 1;
    }

    // Parse width
    let mut width_str = String::new();
    while i < chars.len() && chars[i].is_ascii_digit() {
        width_str.push(chars[i]);
        i += 1;
    }
    if !width_str.is_empty() {
        width = Some(width_str.parse().unwrap());
    }

    // Parse precision
    if i < chars.len() && chars[i] == '.' {
        i += 1;
        let mut prec_str = String::new();
        while i < chars.len() && chars[i].is_ascii_digit() {
            prec_str.push(chars[i]);
            i += 1;
        }
        if !prec_str.is_empty() {
            precision = Some(prec_str.parse().unwrap());
        }
    }

    // Parse format type (rest of string)
    if i < chars.len() {
        format_type = &spec[i..];
    }

    // Format the value based on type
    let formatted = match value {
        QValue::Num(n) => {
            let num = n.value;
            let base_str = match format_type {
                "x" => format!("{:x}", num as i64),
                "X" => format!("{:X}", num as i64),
                "b" => format!("{:b}", num as i64),
                "o" => format!("{:o}", num as i64),
                "e" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$e}", num, prec = prec)
                    } else {
                        format!("{:e}", num)
                    }
                }
                "E" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$E}", num, prec = prec)
                    } else {
                        format!("{:E}", num)
                    }
                }
                _ => {
                    // Default number formatting
                    if let Some(prec) = precision {
                        format!("{:.prec$}", num, prec = prec)
                    } else if num.fract() == 0.0 && num.abs() < 1e10 {
                        format!("{}", num as i64)
                    } else {
                        format!("{}", num)
                    }
                }
            };

            // Add alternate form prefix if requested
            let mut result = if alternate {
                match format_type {
                    "x" | "X" => format!("0x{}", base_str),
                    "b" => format!("0b{}", base_str),
                    "o" => format!("0o{}", base_str),
                    _ => base_str,
                }
            } else {
                base_str
            };

            // Add sign if requested
            if sign == '+' && num >= 0.0 {
                result = format!("+{}", result);
            } else if sign == ' ' && num >= 0.0 {
                result = format!(" {}", result);
            }

            result
        }
        QValue::Str(s) => {
            if let Some(prec) = precision {
                s.value[..prec.min(s.value.len())].to_string()
            } else {
                s.value.clone()
            }
        }
        QValue::Bool(b) => b.value.to_string(),
        QValue::Nil(_) => "nil".to_string(),
        _ => value.as_str(),
    };

    // Apply width and alignment
    if let Some(w) = width {
        if formatted.len() < w {
            let padding = w - formatted.len();
            let result = match align {
                '<' => format!("{}{}", formatted, fill.to_string().repeat(padding)),
                '>' => format!("{}{}", fill.to_string().repeat(padding), formatted),
                '^' => {
                    let left_pad = padding / 2;
                    let right_pad = padding - left_pad;
                    format!("{}{}{}",
                        fill.to_string().repeat(left_pad),
                        formatted,
                        fill.to_string().repeat(right_pad))
                }
                _ => formatted,
            };
            Ok(result)
        } else {
            Ok(formatted)
        }
    } else {
        Ok(formatted)
    }
}

/// Interpolate variables in a string like "Hello {name}" or "Value: {x:.2}"
/// Used for f-strings: f"Hello {name}"
pub fn interpolate_string(s: &str, scope: &Scope) -> Result<String, String> {
    let mut result = String::new();
    let mut chars = s.chars().peekable();

    while let Some(c) = chars.next() {
        if c == '{' {
            // Start of interpolation - collect variable name and optional format spec
            let mut var_name = String::new();
            let mut format_spec = None;

            // Read variable name (alphanumeric + underscore)
            while let Some(&ch) = chars.peek() {
                if ch.is_alphanumeric() || ch == '_' {
                    var_name.push(ch);
                    chars.next();
                } else {
                    break;
                }
            }

            // Check for format spec after ':'
            if let Some(&':') = chars.peek() {
                chars.next(); // consume ':'
                let mut spec = String::new();
                while let Some(&ch) = chars.peek() {
                    if ch != '}' {
                        spec.push(ch);
                        chars.next();
                    } else {
                        break;
                    }
                }
                format_spec = Some(spec);
            }

            // Expect closing '}'
            if let Some('}') = chars.next() {
                // Skip interpolation for fmt() placeholders:
                // - {} (empty placeholder)
                // - {0}, {1} (numeric placeholders)
                // - {:.2} (format-only, no variable name)
                if var_name.is_empty() || var_name.chars().all(|c| c.is_ascii_digit()) {
                    // Not a variable interpolation - leave as-is for .fmt()
                    result.push('{');
                    result.push_str(&var_name);
                    if let Some(spec) = format_spec {
                        result.push(':');
                        result.push_str(&spec);
                    }
                    result.push('}');
                } else {
                    // Variable interpolation - look up and substitute
                    let value = scope.get(&var_name)
                        .ok_or_else(|| format!("Undefined variable in interpolation: {}", var_name))?;

                    // Format value
                    let formatted = if let Some(spec) = format_spec {
                        format_value(&value, &spec)?
                    } else {
                        value.as_str()
                    };
                    result.push_str(&formatted);
                }
            } else {
                return Err(format!("Unclosed interpolation: missing '}}' after '{{{}'", var_name));
            }
        } else if c == '\\' {
            // Handle escape sequence (backslash already consumed)
            if let Some(next) = chars.next() {
                match next {
                    '{' => result.push('{'), // Escaped brace
                    '}' => result.push('}'), // Escaped brace
                    _ => {
                        result.push(c);
                        result.push(next);
                    }
                }
            } else {
                result.push(c);
            }
        } else {
            result.push(c);
        }
    }

    Ok(result)
}

/// String .fmt() method: "Hello {}, you are {}".fmt("Alice", 30)
/// Supports positional: {}, {0}, {1}
/// And format specs: {:.2}, {0:.2}, etc.
pub fn string_fmt(template: &str, args: Vec<QValue>) -> Result<QValue, String> {
    let mut result = String::new();
    let mut chars = template.chars().peekable();
    let mut arg_index = 0;

    while let Some(c) = chars.next() {
        if c == '{' {
            // Check for {{  (escaped brace)
            if let Some(&'{') = chars.peek() {
                chars.next();
                result.push('{');
                continue;
            }

            // Parse placeholder: {}, {0}, {1}, {name}, {:.2}, {0:.2}, etc.
            let mut placeholder = String::new();
            while let Some(&ch) = chars.peek() {
                if ch != '}' {
                    placeholder.push(ch);
                    chars.next();
                } else {
                    break;
                }
            }

            // Expect closing '}'
            if chars.next() != Some('}') {
                return Err(format!("Unclosed placeholder in format string"));
            }

            // Parse placeholder: [index/name][:format_spec]
            let (arg_ref, format_spec) = if let Some(colon_pos) = placeholder.find(':') {
                (placeholder[..colon_pos].trim(), Some(&placeholder[colon_pos+1..]))
            } else {
                (placeholder.as_str(), None)
            };

            // Determine which argument to use
            let value = if arg_ref.is_empty() {
                // {} - use next positional argument
                if arg_index >= args.len() {
                    return Err(format!("Not enough arguments for format string (needed at least {})", arg_index + 1));
                }
                let v = &args[arg_index];
                arg_index += 1;
                v
            } else if let Ok(index) = arg_ref.parse::<usize>() {
                // {0}, {1} - use specific index
                if index >= args.len() {
                    return Err(format!("Argument index {} out of range (have {} args)", index, args.len()));
                }
                &args[index]
            } else {
                // {name} - named argument (not yet supported, would need keyword args in Quest)
                return Err(format!("Named arguments not yet supported in fmt(): {}", arg_ref));
            };

            // Format the value
            let formatted = if let Some(spec) = format_spec {
                format_value(value, spec)?
            } else {
                value.as_str()
            };
            result.push_str(&formatted);
        } else if c == '}' {
            // Check for }} (escaped brace)
            if let Some(&'}') = chars.peek() {
                chars.next();
                result.push('}');
            } else {
                return Err("Unmatched '}' in format string".to_string());
            }
        } else {
            result.push(c);
        }
    }

    Ok(QValue::Str(QString::new(result)))
}

/// Process escape sequences in strings: \n, \t, \r, \\, \"
fn process_escape_sequences(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                match next {
                    'n' => result.push('\n'),
                    't' => result.push('\t'),
                    'r' => result.push('\r'),
                    '\\' => result.push('\\'),
                    '"' => result.push('"'),
                    _ => {
                        result.push('\\');
                        result.push(next);
                    }
                }
            }
        } else {
            result.push(c);
        }
    }
    result
}
