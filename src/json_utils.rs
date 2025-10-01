// JSON utility functions for Quest
// Handles conversion between Quest values (QValue) and JSON (serde_json::Value)

use crate::types::*;
use std::collections::HashMap;

/// Convert a serde_json::Value to a Quest QValue
/// Supports all JSON types: null, bool, number, string, array, object
pub fn json_to_qvalue(json: serde_json::Value) -> Result<QValue, String> {
    match json {
        serde_json::Value::Null => Ok(QValue::Nil(QNil)),
        serde_json::Value::Bool(b) => Ok(QValue::Bool(QBool::new(b))),
        serde_json::Value::Number(n) => {
            if let Some(f) = n.as_f64() {
                Ok(QValue::Num(QNum::new(f)))
            } else {
                Err("Invalid JSON number".to_string())
            }
        }
        serde_json::Value::String(s) => Ok(QValue::Str(QString::new(s))),
        serde_json::Value::Array(arr) => {
            let mut elements = Vec::new();
            for item in arr {
                elements.push(json_to_qvalue(item)?);
            }
            Ok(QValue::Array(QArray::new(elements)))
        }
        serde_json::Value::Object(obj) => {
            let mut map = HashMap::new();
            for (key, val) in obj {
                map.insert(key, json_to_qvalue(val)?);
            }
            Ok(QValue::Dict(QDict::new(map)))
        }
    }
}

/// Convert a Quest QValue to a serde_json::Value
/// Functions and modules cannot be converted to JSON and will return an error
pub fn qvalue_to_json(value: &QValue) -> Result<serde_json::Value, String> {
    match value {
        QValue::Nil(_) => Ok(serde_json::Value::Null),
        QValue::Bool(b) => Ok(serde_json::Value::Bool(b.value)),
        QValue::Num(n) => {
            Ok(serde_json::Value::Number(
                serde_json::Number::from_f64(n.value)
                    .ok_or("Invalid number for JSON")?
            ))
        }
        QValue::Str(s) => Ok(serde_json::Value::String(s.value.clone())),
        QValue::Array(arr) => {
            let mut json_arr = Vec::new();
            for elem in &arr.elements {
                json_arr.push(qvalue_to_json(elem)?);
            }
            Ok(serde_json::Value::Array(json_arr))
        }
        QValue::Dict(dict) => {
            let mut json_obj = serde_json::Map::new();
            for (key, val) in &dict.map {
                json_obj.insert(key.clone(), qvalue_to_json(val)?);
            }
            Ok(serde_json::Value::Object(json_obj))
        }
        QValue::Fun(_) | QValue::UserFun(_) | QValue::Module(_) => {
            Err("Cannot convert function or module to JSON".to_string())
        }
    }
}
