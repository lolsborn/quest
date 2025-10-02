use std::collections::HashMap;
use crate::types::*;

pub fn create_regex_module() -> QValue {
    // Create a wrapper for regex functions
    fn create_regex_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "regex".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Pattern matching and testing
    members.insert("match".to_string(), create_regex_fn("match", "Check if a string matches a regex pattern. Returns bool.\nUsage: regex.match(pattern, text)"));
    members.insert("find".to_string(), create_regex_fn("find", "Find the first match of a pattern in text. Returns the matched string or nil.\nUsage: regex.find(pattern, text)"));
    members.insert("find_all".to_string(), create_regex_fn("find_all", "Find all matches of a pattern in text. Returns an array of matched strings.\nUsage: regex.find_all(pattern, text)"));

    // Capture groups
    members.insert("captures".to_string(), create_regex_fn("captures", "Get capture groups from the first match. Returns array of captured strings or nil.\nUsage: regex.captures(pattern, text)"));
    members.insert("captures_all".to_string(), create_regex_fn("captures_all", "Get all capture groups from all matches. Returns array of arrays.\nUsage: regex.captures_all(pattern, text)"));

    // String manipulation
    members.insert("replace".to_string(), create_regex_fn("replace", "Replace the first match with replacement string.\nUsage: regex.replace(pattern, text, replacement)"));
    members.insert("replace_all".to_string(), create_regex_fn("replace_all", "Replace all matches with replacement string.\nUsage: regex.replace_all(pattern, text, replacement)"));
    members.insert("split".to_string(), create_regex_fn("split", "Split text by regex pattern. Returns array of strings.\nUsage: regex.split(pattern, text)"));

    // Pattern validation
    members.insert("is_valid".to_string(), create_regex_fn("is_valid", "Check if a regex pattern is valid. Returns bool.\nUsage: regex.is_valid(pattern)"));

    QValue::Module(QModule::new("regex".to_string(), members))
}
