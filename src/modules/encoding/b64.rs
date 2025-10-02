use std::collections::HashMap;
use crate::types::*;

pub fn create_b64_module() -> QValue {
    // Create a wrapper for encode functions
    fn create_encode_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "b64".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Base64 encoding functions
    // The function name will be prepended with parent_type (b64) to become: b64.encode
    members.insert("encode".to_string(), create_encode_fn("encode", "Encode data to base64"));
    members.insert("decode".to_string(), create_encode_fn("decode", "Decode base64 data"));
    members.insert("encode_url".to_string(), create_encode_fn("encode_url", "Encode data to URL-safe base64"));
    members.insert("decode_url".to_string(), create_encode_fn("decode_url", "Decode URL-safe base64 data"));

    QValue::Module(QModule::new("b64".to_string(), members))
}
