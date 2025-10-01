use std::collections::HashMap;
use crate::types::*;

pub fn create_term_module() -> QValue {
    // Create a wrapper for term functions
    fn create_term_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "term".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Text color functions
    members.insert("color".to_string(), create_term_fn("color", "Return colored text with optional attributes"));
    members.insert("on_color".to_string(), create_term_fn("on_color", "Return text with background color"));

    // Convenience color functions
    members.insert("red".to_string(), create_term_fn("red", "Return red colored text"));
    members.insert("green".to_string(), create_term_fn("green", "Return green colored text"));
    members.insert("yellow".to_string(), create_term_fn("yellow", "Return yellow colored text"));
    members.insert("blue".to_string(), create_term_fn("blue", "Return blue colored text"));
    members.insert("magenta".to_string(), create_term_fn("magenta", "Return magenta colored text"));
    members.insert("cyan".to_string(), create_term_fn("cyan", "Return cyan colored text"));
    members.insert("white".to_string(), create_term_fn("white", "Return white colored text"));
    members.insert("grey".to_string(), create_term_fn("grey", "Return grey colored text"));

    // Text attribute functions
    members.insert("bold".to_string(), create_term_fn("bold", "Return bold text"));
    members.insert("dimmed".to_string(), create_term_fn("dimmed", "Return dimmed text"));
    members.insert("underline".to_string(), create_term_fn("underline", "Return underlined text"));
    members.insert("blink".to_string(), create_term_fn("blink", "Return blinking text"));
    members.insert("reverse".to_string(), create_term_fn("reverse", "Return text with reversed foreground/background"));
    members.insert("hidden".to_string(), create_term_fn("hidden", "Return hidden text"));

    // Cursor control
    members.insert("move_up".to_string(), create_term_fn("move_up", "Move cursor up n lines"));
    members.insert("move_down".to_string(), create_term_fn("move_down", "Move cursor down n lines"));
    members.insert("move_left".to_string(), create_term_fn("move_left", "Move cursor left n columns"));
    members.insert("move_right".to_string(), create_term_fn("move_right", "Move cursor right n columns"));
    members.insert("move_to".to_string(), create_term_fn("move_to", "Move cursor to specific position"));
    members.insert("save_cursor".to_string(), create_term_fn("save_cursor", "Save current cursor position"));
    members.insert("restore_cursor".to_string(), create_term_fn("restore_cursor", "Restore previously saved cursor position"));

    // Screen control
    members.insert("clear".to_string(), create_term_fn("clear", "Clear entire screen"));
    members.insert("clear_line".to_string(), create_term_fn("clear_line", "Clear current line"));
    members.insert("clear_to_end".to_string(), create_term_fn("clear_to_end", "Clear from cursor to end of screen"));
    members.insert("clear_to_start".to_string(), create_term_fn("clear_to_start", "Clear from cursor to start of screen"));

    // Terminal properties
    members.insert("width".to_string(), create_term_fn("width", "Get terminal width in columns"));
    members.insert("height".to_string(), create_term_fn("height", "Get terminal height in rows"));
    members.insert("size".to_string(), create_term_fn("size", "Get terminal size as [height, width]"));

    // Style combinations
    members.insert("styled".to_string(), create_term_fn("styled", "Apply multiple styles at once"));

    // ANSI control
    members.insert("reset".to_string(), create_term_fn("reset", "Return ANSI reset code"));
    members.insert("strip_colors".to_string(), create_term_fn("strip_colors", "Remove all ANSI color codes from text"));

    QValue::Module(QModule::new("term".to_string(), members))
}
