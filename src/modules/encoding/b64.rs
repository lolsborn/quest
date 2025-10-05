use std::collections::HashMap;
use crate::types::*;
use base64::{Engine as _, engine::general_purpose};

pub fn create_b64_module() -> QValue {
    // Create a wrapper for encode functions
    fn create_encode_fn(name: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "b64".to_string()))
    }

    let mut members = HashMap::new();

    // Base64 encoding functions
    // The function name will be prepended with parent_type (b64) to become: b64.encode
    members.insert("encode".to_string(), create_encode_fn("encode"));
    members.insert("decode".to_string(), create_encode_fn("decode"));
    members.insert("encode_url".to_string(), create_encode_fn("encode_url"));
    members.insert("decode_url".to_string(), create_encode_fn("decode_url"));

    QValue::Module(Box::new(QModule::new("b64".to_string(), members)))
}

pub fn call_b64_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "b64.encode" => {
            if args.len() != 1 {
                return Err(format!("b64.encode expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::STANDARD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "b64.decode" => {
            if args.len() != 1 {
                return Err(format!("b64.decode expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let decoded = general_purpose::STANDARD.decode(data.as_bytes())
                .map_err(|e| format!("Base64 decode error: {}", e))?;
            let decoded_str = String::from_utf8(decoded)
                .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
            Ok(QValue::Str(QString::new(decoded_str)))
        }
        "b64.encode_url" => {
            if args.len() != 1 {
                return Err(format!("b64.encode_url expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::URL_SAFE_NO_PAD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "b64.decode_url" => {
            if args.len() != 1 {
                return Err(format!("b64.decode_url expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let decoded = general_purpose::URL_SAFE_NO_PAD.decode(data.as_bytes())
                .map_err(|e| format!("Base64 decode error: {}", e))?;
            let decoded_str = String::from_utf8(decoded)
                .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
            Ok(QValue::Str(QString::new(decoded_str)))
        }
        _ => Err(format!("Undefined function: {}", func_name)),
    }
}
