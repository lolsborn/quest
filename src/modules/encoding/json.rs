use std::collections::HashMap;
use crate::types::*;
use crate::encoding::json_utils::{qvalue_to_json, json_to_qvalue};

pub fn create_json_module() -> QValue {
    // Create a wrapper for json functions
    fn create_json_fn(name: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "json".to_string()))
    }

    let mut members = HashMap::new();

    // Parsing functions
    members.insert("parse".to_string(), create_json_fn("parse"));
    members.insert("try_parse".to_string(), create_json_fn("try_parse"));
    members.insert("is_valid".to_string(), create_json_fn("is_valid"));

    // Serialization functions
    members.insert("stringify".to_string(), create_json_fn("stringify"));
    members.insert("stringify_pretty".to_string(), create_json_fn("stringify_pretty"));

    // Type checking
    members.insert("is_array".to_string(), create_json_fn("is_array"));

    QValue::Module(QModule::new("json".to_string(), members))
}

/// Handle json.* function calls
pub fn call_json_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "json.parse" => {
            if args.len() != 1 {
                return Err(format!("parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let json_value: serde_json::Value = serde_json::from_str(&json_str)
                .map_err(|e| format!("JSON parse error: {}", e))?;
            json_to_qvalue(json_value)
        }

        "json.try_parse" => {
            if args.len() != 1 {
                return Err(format!("try_parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            match serde_json::from_str::<serde_json::Value>(&json_str) {
                Ok(json_value) => json_to_qvalue(json_value),
                Err(_) => Ok(QValue::Nil(QNil)),
            }
        }

        "json.is_valid" => {
            if args.len() != 1 {
                return Err(format!("is_valid expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let is_valid = serde_json::from_str::<serde_json::Value>(&json_str).is_ok();
            Ok(QValue::Bool(QBool::new(is_valid)))
        }

        "json.stringify" => {
            if args.is_empty() {
                return Err(format!("stringify expects at least 1 argument, got 0"));
            }
            let value = &args[0];
            let json_value = qvalue_to_json(value)?;
            let json_str = serde_json::to_string(&json_value)
                .map_err(|e| format!("JSON stringify error: {}", e))?;
            Ok(QValue::Str(QString::new(json_str)))
        }

        "json.stringify_pretty" => {
            if args.is_empty() {
                return Err(format!("stringify_pretty expects at least 1 argument, got 0"));
            }
            let value = &args[0];
            let json_value = qvalue_to_json(value)?;
            let json_str = serde_json::to_string_pretty(&json_value)
                .map_err(|e| format!("JSON stringify error: {}", e))?;
            Ok(QValue::Str(QString::new(json_str)))
        }

        _ => Err(format!("Unknown json function: {}", func_name))
    }
}
