use std::collections::HashMap;
use crate::types::*;

pub fn create_encode_module() -> QValue {
    // Create a wrapper for encode functions
    fn create_encode_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "encode".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Base64 encoding functions
    members.insert("b64_encode".to_string(), create_encode_fn("b64_encode", "Encode data to base64"));
    members.insert("b64_decode".to_string(), create_encode_fn("b64_decode", "Decode base64 data"));
    members.insert("b64_encode_url".to_string(), create_encode_fn("b64_encode_url", "Encode data to URL-safe base64"));
    members.insert("b64_decode_url".to_string(), create_encode_fn("b64_decode_url", "Decode URL-safe base64 data"));

    QValue::Module(QModule::new("encode".to_string(), members))
}
