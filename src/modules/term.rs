use std::collections::HashMap;
use crate::control_flow::EvalError;
use crate::{arg_err, value_err, attr_err};
use crate::types::*;

pub fn create_term_module() -> QValue {
    let mut members = HashMap::new();

    // Text color functions
    members.insert("color".to_string(), create_fn("term", "color"));
    members.insert("on_color".to_string(), create_fn("term", "on_color"));

    // Convenience color functions
    members.insert("red".to_string(), create_fn("term", "red"));
    members.insert("green".to_string(), create_fn("term", "green"));
    members.insert("yellow".to_string(), create_fn("term", "yellow"));
    members.insert("blue".to_string(), create_fn("term", "blue"));
    members.insert("magenta".to_string(), create_fn("term", "magenta"));
    members.insert("cyan".to_string(), create_fn("term", "cyan"));
    members.insert("white".to_string(), create_fn("term", "white"));
    members.insert("grey".to_string(), create_fn("term", "grey"));

    // Text attribute functions
    members.insert("bold".to_string(), create_fn("term", "bold"));
    members.insert("dimmed".to_string(), create_fn("term", "dimmed"));
    members.insert("underline".to_string(), create_fn("term", "underline"));
    members.insert("blink".to_string(), create_fn("term", "blink"));
    members.insert("reverse".to_string(), create_fn("term", "reverse"));
    members.insert("hidden".to_string(), create_fn("term", "hidden"));

    // Cursor control
    members.insert("move_up".to_string(), create_fn("term", "move_up"));
    members.insert("move_down".to_string(), create_fn("term", "move_down"));
    members.insert("move_left".to_string(), create_fn("term", "move_left"));
    members.insert("move_right".to_string(), create_fn("term", "move_right"));
    members.insert("move_to".to_string(), create_fn("term", "move_to"));
    members.insert("save_cursor".to_string(), create_fn("term", "save_cursor"));
    members.insert("restore_cursor".to_string(), create_fn("term", "restore_cursor"));

    // Screen control
    members.insert("clear".to_string(), create_fn("term", "clear"));
    members.insert("clear_line".to_string(), create_fn("term", "clear_line"));
    members.insert("clear_to_end".to_string(), create_fn("term", "clear_to_end"));
    members.insert("clear_to_start".to_string(), create_fn("term", "clear_to_start"));

    // Terminal properties
    members.insert("width".to_string(), create_fn("term", "width"));
    members.insert("height".to_string(), create_fn("term", "height"));
    members.insert("size".to_string(), create_fn("term", "size"));

    // Style combinations
    members.insert("styled".to_string(), create_fn("term", "styled"));

    // ANSI control
    members.insert("reset".to_string(), create_fn("term", "reset"));
    members.insert("strip_colors".to_string(), create_fn("term", "strip_colors"));

    QValue::Module(Box::new(QModule::new("term".to_string(), members)))
}

/// Handle term.* function calls
pub fn call_term_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "term.red" | "term.green" | "term.yellow" |
        "term.blue" | "term.magenta" | "term.cyan" |
        "term.white" | "term.grey" => {
            if args.is_empty() {
                return arg_err!("{} expects at least 1 argument, got 0", func_name);
            }
            let text = args[0].as_str();
            let color_code = match func_name.trim_start_matches("term.") {
                "red" => "31",
                "green" => "32",
                "yellow" => "33",
                "blue" => "34",
                "magenta" => "35",
                "cyan" => "36",
                "white" => "37",
                "grey" => "90",
                _ => unreachable!(),
            };

            // Check if there are attributes (second arg should be array)
            let mut result = format!("\x1b[{}m{}\x1b[0m", color_code, text);
            if args.len() > 1 {
                if let QValue::Array(attrs) = &args[1] {
                    let mut codes = vec![color_code.to_string()];
                    let elements = attrs.elements.borrow();
                    for attr in elements.iter() {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                    result = format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text);
                }
            }
            Ok(QValue::Str(QString::new(result)))
        }

        "term.color" => {
            if args.len() < 2 {
                return arg_err!("color expects at least 2 arguments, got {}", args.len());
            }
            let text = args[0].as_str();
            let color = args[1].as_str();

            let color_code = match color.as_str() {
                "red" => "31",
                "green" => "32",
                "yellow" => "33",
                "blue" => "34",
                "magenta" => "35",
                "cyan" => "36",
                "white" => "37",
                "grey" => "90",
                _ => return value_err!("Unknown color: {}", color),
            };

            let mut codes = vec![color_code.to_string()];
            if args.len() > 2 {
                if let QValue::Array(attrs) = &args[2] {
                    let elements = attrs.elements.borrow();
                    for attr in elements.iter() {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                }
            }

            let result = format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text);
            Ok(QValue::Str(QString::new(result)))
        }

        "term.on_color" => {
            if args.len() != 2 {
                return arg_err!("on_color expects 2 arguments, got {}", args.len());
            }
            let text = args[0].as_str();
            let color = args[1].as_str();

            let color_code = match color.as_str() {
                "red" => "41",
                "green" => "42",
                "yellow" => "43",
                "blue" => "44",
                "magenta" => "45",
                "cyan" => "46",
                "white" => "47",
                "grey" => "100",
                _ => return value_err!("Unknown color: {}", color),
            };

            let result = format!("\x1b[{}m{}\x1b[0m", color_code, text);
            Ok(QValue::Str(QString::new(result)))
        }

        "term.bold" | "term.dim" | "term.dimmed" |
        "term.underline" | "term.blink" |
        "term.reverse" | "term.hidden" => {
            if args.len() != 1 {
                return arg_err!("{} expects 1 argument, got {}", func_name, args.len());
            }
            let text = args[0].as_str();
            let attr_code = match func_name.trim_start_matches("term.") {
                "bold" => "1",
                "dim" | "dimmed" => "2",
                "underline" => "4",
                "blink" => "5",
                "reverse" => "7",
                "hidden" => "8",
                _ => unreachable!(),
            };
            let result = format!("\x1b[{}m{}\x1b[0m", attr_code, text);
            Ok(QValue::Str(QString::new(result)))
        }

        "term.styled" => {
            if args.is_empty() {
                return arg_err!("styled expects at least 1 argument, got 0");
            }
            let text = args[0].as_str();
            let mut codes = Vec::new();

            // fg color (arg 1)
            if args.len() > 1 {
                if let QValue::Str(fg) = &args[1] {
                    let fg_str = &fg.value;
                    if !fg_str.is_empty() && fg_str.as_str() != "nil" {
                        let color_code = match fg_str.as_str() {
                            "red" => "31",
                            "green" => "32",
                            "yellow" => "33",
                            "blue" => "34",
                            "magenta" => "35",
                            "cyan" => "36",
                            "white" => "37",
                            "grey" => "90",
                            _ => return value_err!("Unknown foreground color: {}", fg_str),
                        };
                        codes.push(color_code.to_string());
                    }
                }
            }

            // bg color (arg 2)
            if args.len() > 2 {
                if let QValue::Str(bg) = &args[2] {
                    let bg_str = &bg.value;
                    if !bg_str.is_empty() && bg_str.as_str() != "nil" {
                        let color_code = match bg_str.as_str() {
                            "red" => "41",
                            "green" => "42",
                            "yellow" => "43",
                            "blue" => "44",
                            "magenta" => "45",
                            "cyan" => "46",
                            "white" => "47",
                            "grey" => "100",
                            _ => return value_err!("Unknown background color: {}", bg_str),
                        };
                        codes.push(color_code.to_string());
                    }
                }
            }

            // attrs (arg 3)
            if args.len() > 3 {
                if let QValue::Array(attrs) = &args[3] {
                    let elements = attrs.elements.borrow();
                    for attr in elements.iter() {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                }
            }

            let result = if codes.is_empty() {
                text
            } else {
                format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text)
            };
            Ok(QValue::Str(QString::new(result)))
        }

        "term.move_up" | "term.move_down" | "term.move_left" | "term.move_right" => {
            let n = if args.is_empty() {
                1
            } else {
                args[0].as_num()? as i32
            };
            let code = match func_name.trim_start_matches("term.") {
                "move_up" => format!("\x1b[{}A", n),
                "move_down" => format!("\x1b[{}B", n),
                "move_right" => format!("\x1b[{}C", n),
                "move_left" => format!("\x1b[{}D", n),
                _ => unreachable!(),
            };
            print!("{}", code);
            Ok(QValue::Nil(QNil))
        }

        "term.move_to" => {
            if args.len() != 2 {
                return arg_err!("move_to expects 2 arguments, got {}", args.len());
            }
            let row = args[0].as_num()? as i32;
            let col = args[1].as_num()? as i32;
            print!("\x1b[{};{}H", row, col);
            Ok(QValue::Nil(QNil))
        }

        "term.save_cursor" => {
            if !args.is_empty() {
                return arg_err!("save_cursor expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[s");
            Ok(QValue::Nil(QNil))
        }

        "term.restore_cursor" => {
            if !args.is_empty() {
                return arg_err!("restore_cursor expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[u");
            Ok(QValue::Nil(QNil))
        }

        "term.clear" => {
            if !args.is_empty() {
                return arg_err!("clear expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[2J\x1b[H");
            Ok(QValue::Nil(QNil))
        }

        "term.clear_line" => {
            if !args.is_empty() {
                return arg_err!("clear_line expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[2K");
            Ok(QValue::Nil(QNil))
        }

        "term.clear_to_end" => {
            if !args.is_empty() {
                return arg_err!("clear_to_end expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[J");
            Ok(QValue::Nil(QNil))
        }

        "term.clear_to_start" => {
            if !args.is_empty() {
                return arg_err!("clear_to_start expects 0 arguments, got {}", args.len());
            }
            print!("\x1b[1J");
            Ok(QValue::Nil(QNil))
        }

        "term.width" | "term.height" | "term.size" => {
            if !args.is_empty() {
                return arg_err!("{} expects 0 arguments, got {}", func_name, args.len());
            }
            // Try to get terminal size or fallback
            let base_name = func_name.trim_start_matches("term.");
            if let Some((w, h)) = term_size::dimensions() {
                match base_name {
                    "width" => Ok(QValue::Int(QInt::new(w as i64))),
                    "height" => Ok(QValue::Int(QInt::new(h as i64))),
                    "size" => {
                        let arr = vec![
                            QValue::Int(QInt::new(h as i64)),
                            QValue::Int(QInt::new(w as i64)),
                        ];
                        Ok(QValue::Array(QArray::new(arr)))
                    }
                    _ => unreachable!(),
                }
            } else {
                // Fallback to default size
                match base_name {
                    "width" => Ok(QValue::Int(QInt::new(80))),
                    "height" => Ok(QValue::Int(QInt::new(24))),
                    "size" => {
                        let arr = vec![
                            QValue::Int(QInt::new(24)),
                            QValue::Int(QInt::new(80)),
                        ];
                        Ok(QValue::Array(QArray::new(arr)))
                    }
                    _ => unreachable!(),
                }
            }
        }

        "term.reset" => {
            if !args.is_empty() {
                return arg_err!("reset expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Str(QString::new("\x1b[0m".to_string())))
        }

        "term.strip_colors" => {
            if args.len() != 1 {
                return arg_err!("strip_colors expects 1 argument, got {}", args.len());
            }
            let text = args[0].as_str();
            // Simple regex-like replacement to strip ANSI codes
            let mut result = String::new();
            let mut chars = text.chars().peekable();
            while let Some(ch) = chars.next() {
                if ch == '\x1b' {
                    // Skip escape sequence
                    if chars.peek() == Some(&'[') {
                        chars.next(); // consume '['
                        // Skip until we find a letter (the command)
                        while let Some(&c) = chars.peek() {
                            chars.next();
                            if c.is_ascii_alphabetic() {
                                break;
                            }
                        }
                    }
                } else {
                    result.push(ch);
                }
            }
            Ok(QValue::Str(QString::new(result)))
        }

        _ => attr_err!("Unknown term function: {}", func_name)
    }
}
