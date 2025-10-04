// JSON utility functions for Quest
// Handles conversion between Quest values (QValue) and JSON (serde_json::Value)

use crate::types::*;
use std::collections::HashMap;
use rust_decimal::prelude::*;

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
        QValue::Int(i) => {
            Ok(serde_json::Value::Number(serde_json::Number::from(i.value)))
        }
        QValue::Float(f) => {
            Ok(serde_json::Value::Number(
                serde_json::Number::from_f64(f.value)
                    .ok_or("Invalid float for JSON")?
            ))
        }
        QValue::Decimal(d) => {
            // Convert Decimal to f64 for JSON (may lose precision)
            Ok(serde_json::Value::Number(
                serde_json::Number::from_f64(d.value.to_f64().unwrap_or(0.0))
                    .ok_or("Invalid decimal for JSON")?
            ))
        }
        QValue::Str(s) => Ok(serde_json::Value::String(s.value.clone())),
        QValue::Bytes(b) => {
            // Convert bytes to base64 string for JSON representation
            use base64::{Engine as _, engine::general_purpose};
            let b64 = general_purpose::STANDARD.encode(&b.data);
            Ok(serde_json::Value::String(b64))
        }
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
        QValue::Type(_) | QValue::Trait(_) => {
            Err("Cannot convert type or trait to JSON".to_string())
        }
        QValue::Exception(e) => {
            // Convert exception to JSON object
            let mut json_obj = serde_json::Map::new();
            json_obj.insert("type".to_string(), serde_json::Value::String(e.exception_type.clone()));
            json_obj.insert("message".to_string(), serde_json::Value::String(e.message.clone()));
            if let Some(line) = e.line {
                json_obj.insert("line".to_string(), serde_json::Value::Number(serde_json::Number::from(line)));
            }
            if let Some(ref file) = e.file {
                json_obj.insert("file".to_string(), serde_json::Value::String(file.clone()));
            }
            Ok(serde_json::Value::Object(json_obj))
        }
        QValue::Uuid(u) => {
            // Convert UUID to string
            Ok(serde_json::Value::String(u.value.to_string()))
        }
        QValue::Struct(s) => {
            // Convert struct to JSON object with its fields
            let mut json_obj = serde_json::Map::new();
            for (key, val) in &s.fields {
                json_obj.insert(key.clone(), qvalue_to_json(val)?);
            }
            Ok(serde_json::Value::Object(json_obj))
        }
        QValue::Timestamp(ts) => {
            // Convert timestamp to ISO 8601 string
            Ok(serde_json::Value::String(ts._str()))
        }
        QValue::Zoned(z) => {
            // Convert zoned datetime to ISO 8601 string
            Ok(serde_json::Value::String(z._str()))
        }
        QValue::Date(d) => {
            // Convert date to ISO 8601 string
            Ok(serde_json::Value::String(d._str()))
        }
        QValue::Time(t) => {
            // Convert time to ISO 8601 string
            Ok(serde_json::Value::String(t._str()))
        }
        QValue::Span(s) => {
            // Convert span to ISO 8601 duration string
            Ok(serde_json::Value::String(s._str()))
        }
        QValue::SerialPort(_) => {
            Err("Cannot convert serial port to JSON".to_string())
        }
        QValue::SqliteConnection(_) | QValue::SqliteCursor(_) | QValue::PostgresConnection(_) | QValue::PostgresCursor(_) | QValue::MysqlConnection(_) | QValue::MysqlCursor(_) | QValue::HtmlTemplate(_) => {
            Err("Cannot convert database/template objects to JSON".to_string())
        }
        QValue::HttpClient(_) | QValue::HttpRequest(_) | QValue::HttpResponse(_) => {
            Err("Cannot convert HTTP objects to JSON".to_string())
        }
    }
}
