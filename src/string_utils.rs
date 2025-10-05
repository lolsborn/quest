// String utility functions for Quest
// Handles string parsing, formatting, and interpolation

use crate::types::*;

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
        QValue::Int(n) => {
            let num = n.value;
            let base_str = match format_type {
                "x" => format!("{:x}", num),
                "X" => format!("{:X}", num),
                "b" => format!("{:b}", num),
                "o" => format!("{:o}", num),
                "e" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$e}", num as f64, prec = prec)
                    } else {
                        format!("{:e}", num as f64)
                    }
                }
                "E" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$E}", num as f64, prec = prec)
                    } else {
                        format!("{:E}", num as f64)
                    }
                }
                _ => {
                    // Default number formatting
                    if let Some(prec) = precision {
                        format!("{:.prec$}", num as f64, prec = prec)
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
            if sign == '+' && num >= 0 {
                result = format!("+{}", result);
            } else if sign == ' ' && num >= 0 {
                result = format!(" {}", result);
            }

            result
        }
        QValue::Float(n) => {
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
                s.value.as_ref().clone()
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

/// Process escape sequences in strings: \n, \t, \r, \\, \"
pub fn process_escape_sequences(s: &str) -> String {
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
