use std::collections::HashMap;
use crate::types::*;
use regex::Regex;

pub fn create_regex_module() -> QValue {
    let mut members = HashMap::new();

    // Pattern matching and testing
    members.insert("match".to_string(), create_fn("regex", "match", "Check if a string matches a regex pattern. Returns bool.\nUsage: regex.match(pattern, text)"));
    members.insert("find".to_string(), create_fn("regex", "find", "Find the first match of a pattern in text. Returns the matched string or nil.\nUsage: regex.find(pattern, text)"));
    members.insert("find_all".to_string(), create_fn("regex", "find_all", "Find all matches of a pattern in text. Returns an array of matched strings.\nUsage: regex.find_all(pattern, text)"));

    // Capture groups
    members.insert("captures".to_string(), create_fn("regex", "captures", "Get capture groups from the first match. Returns array of captured strings or nil.\nUsage: regex.captures(pattern, text)"));
    members.insert("captures_all".to_string(), create_fn("regex", "captures_all", "Get all capture groups from all matches. Returns array of arrays.\nUsage: regex.captures_all(pattern, text)"));

    // String manipulation
    members.insert("replace".to_string(), create_fn("regex", "replace", "Replace the first match with replacement string.\nUsage: regex.replace(pattern, text, replacement)"));
    members.insert("replace_all".to_string(), create_fn("regex", "replace_all", "Replace all matches with replacement string.\nUsage: regex.replace_all(pattern, text, replacement)"));
    members.insert("split".to_string(), create_fn("regex", "split", "Split text by regex pattern. Returns array of strings.\nUsage: regex.split(pattern, text)"));

    // Pattern validation
    members.insert("is_valid".to_string(), create_fn("regex", "is_valid", "Check if a regex pattern is valid. Returns bool.\nUsage: regex.is_valid(pattern)"));

    QValue::Module(QModule::new("regex".to_string(), members))
}

pub fn call_regex_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "regex.match" => {
            if args.len() != 2 {
                return Err(format!("regex.match expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let is_match = re.is_match(&text);
            Ok(QValue::Bool(QBool::new(is_match)))
        }
        "regex.find" => {
            if args.len() != 2 {
                return Err(format!("regex.find expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            match re.find(&text) {
                Some(m) => Ok(QValue::Str(QString::new(m.as_str().to_string()))),
                None => Ok(QValue::Nil(QNil)),
            }
        }
        "regex.find_all" => {
            if args.len() != 2 {
                return Err(format!("regex.find_all expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let matches: Vec<QValue> = re.find_iter(&text)
                .map(|m| QValue::Str(QString::new(m.as_str().to_string())))
                .collect();
            Ok(QValue::Array(QArray::new(matches)))
        }
        "regex.captures" => {
            if args.len() != 2 {
                return Err(format!("regex.captures expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            match re.captures(&text) {
                Some(caps) => {
                    let captured: Vec<QValue> = caps.iter()
                        .map(|c| match c {
                            Some(m) => QValue::Str(QString::new(m.as_str().to_string())),
                            None => QValue::Nil(QNil),
                        })
                        .collect();
                    Ok(QValue::Array(QArray::new(captured)))
                }
                None => Ok(QValue::Nil(QNil)),
            }
        }
        "regex.captures_all" => {
            if args.len() != 2 {
                return Err(format!("regex.captures_all expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let all_captures: Vec<QValue> = re.captures_iter(&text)
                .map(|caps| {
                    let captured: Vec<QValue> = caps.iter()
                        .map(|c| match c {
                            Some(m) => QValue::Str(QString::new(m.as_str().to_string())),
                            None => QValue::Nil(QNil),
                        })
                        .collect();
                    QValue::Array(QArray::new(captured))
                })
                .collect();
            Ok(QValue::Array(QArray::new(all_captures)))
        }
        "regex.replace" => {
            if args.len() != 3 {
                return Err(format!("regex.replace expects 3 arguments (pattern, text, replacement), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();
            let replacement = args[2].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let result = re.replace(&text, replacement.as_str()).to_string();
            Ok(QValue::Str(QString::new(result)))
        }
        "regex.replace_all" => {
            if args.len() != 3 {
                return Err(format!("regex.replace_all expects 3 arguments (pattern, text, replacement), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();
            let replacement = args[2].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let result = re.replace_all(&text, replacement.as_str()).to_string();
            Ok(QValue::Str(QString::new(result)))
        }
        "regex.split" => {
            if args.len() != 2 {
                return Err(format!("regex.split expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let parts: Vec<QValue> = re.split(&text)
                .map(|s| QValue::Str(QString::new(s.to_string())))
                .collect();
            Ok(QValue::Array(QArray::new(parts)))
        }
        "regex.is_valid" => {
            if args.len() != 1 {
                return Err(format!("regex.is_valid expects 1 argument, got {}", args.len()));
            }
            let pattern = args[0].as_str();

            match Regex::new(&pattern) {
                Ok(_) => Ok(QValue::Bool(QBool::new(true))),
                Err(_) => Ok(QValue::Bool(QBool::new(false))),
            }
        }

        _ => Err(format!("Unknown term function: {}", func_name))
    }
}
