use std::collections::HashMap;
use crate::types::*;

#[allow(dead_code)]
pub fn create_json_module() -> QValue {
    // Create a wrapper for json functions
    fn create_json_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "json".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Parsing functions
    members.insert("parse".to_string(), create_json_fn("parse", "Parse JSON string into Quest value"));
    members.insert("try_parse".to_string(), create_json_fn("try_parse", "Try to parse JSON, return nil on error"));
    members.insert("is_valid".to_string(), create_json_fn("is_valid", "Check if string is valid JSON"));

    // Serialization functions
    members.insert("stringify".to_string(), create_json_fn("stringify", "Convert Quest value to JSON string"));
    members.insert("stringify_pretty".to_string(), create_json_fn("stringify_pretty", "Convert to pretty-printed JSON"));

    // Type checking
    members.insert("is_array".to_string(), create_json_fn("is_array", "Check if value is an array"));

    QValue::Module(QModule::new("json".to_string(), members))
}
