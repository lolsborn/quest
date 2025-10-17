use crate::types::*;
use crate::control_flow::EvalError;
use std::collections::HashMap;
use crate::arg_err;

/// Convert a TOML value to a Quest QValue
fn toml_to_qvalue(value: &toml::Value) -> QValue {
    match value {
        toml::Value::String(s) => QValue::Str(QString::new(s.clone())),
        toml::Value::Integer(i) => QValue::Int(QInt::new(*i)),
        toml::Value::Float(f) => QValue::Float(QFloat::new(*f)),
        toml::Value::Boolean(b) => QValue::Bool(QBool::new(*b)),
        toml::Value::Array(arr) => {
            let elements: Vec<QValue> = arr.iter().map(toml_to_qvalue).collect();
            QValue::Array(QArray::new(elements))
        }
        toml::Value::Table(table) => {
            let mut map = HashMap::new();
            for (key, val) in table {
                map.insert(key.clone(), toml_to_qvalue(val));
            }
            QValue::Dict(Box::new(QDict::new(map)))
        }
        toml::Value::Datetime(dt) => {
            // Convert datetime to string representation
            QValue::Str(QString::new(dt.to_string()))
        }
    }
}

/// Create the toml module with native functions
pub fn create_toml_module() -> QValue {
    let mut module_map = HashMap::new();

    // parse(content: str) -> dict
    module_map.insert(
        "parse".to_string(),
        QValue::Fun(QFun::new("parse".to_string(), "toml".to_string())),
    );

    QValue::Module(Box::new(QModule::new("std/toml".to_string(), module_map)))
}

/// Call a toml function
pub fn call_toml_function(func_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
    match func_name {
        "toml.parse" => {
            // Validate arguments
            if args.len() != 1 {
                return arg_err!("toml.parse() expects 1 argument, got {}", args.len());
            }

            let content = match &args[0] {
                QValue::Str(s) => &s.value,
                _ => return Err("toml.parse() expects a string".into()),
            };

            // Parse TOML (use toml::Table to support nested structures)
            let data: toml::Table = toml::from_str(content)
                .map_err(|e| format!("Failed to parse TOML: {}", e))?;

            // Convert to QValue dict
            let mut map = HashMap::new();
            for (key, value) in data {
                map.insert(key, toml_to_qvalue(&value));
            }

            Ok(QValue::Dict(Box::new(QDict::new(map))))
        }

        _ => Err(format!("Unknown toml function: {}", func_name).into()),
    }
}
