use crate::types::*;
use std::collections::HashMap;
use crate::{arg_err, attr_err};
use std::sync::RwLock;
use lazy_static::lazy_static;

lazy_static! {
    /// Global settings storage - loaded once at interpreter startup
    static ref SETTINGS_DATA: RwLock<Option<HashMap<String, toml::Value>>> = RwLock::new(None);
}

/// Initialize settings from .settings.toml file in current directory
/// Called once at interpreter startup
pub fn init_settings() -> Result<(), String> {
    let settings_path = ".settings.toml";

    // Check if file exists
    if !std::path::Path::new(settings_path).exists() {
        // File doesn't exist - that's okay, settings will just return nil
        return Ok(());
    }

    // Read and parse the file
    let contents = std::fs::read_to_string(settings_path)
        .map_err(|e| format!("Failed to read .settings.toml: {}", e))?;

    let mut data: HashMap<String, toml::Value> = toml::from_str(&contents)
        .map_err(|e| format!("Failed to parse .settings.toml: {}", e))?;

    // Process [os.environ] section
    if let Some(toml::Value::Table(environ_table)) = data.remove("os") {
        if let Some(toml::Value::Table(environ)) = environ_table.get("environ") {
            for (key, value) in environ {
                if let toml::Value::String(val) = value {
                    std::env::set_var(key, val);
                }
            }
        }
    }

    // Store the remaining settings
    let mut settings = SETTINGS_DATA.write().unwrap();
    *settings = Some(data);

    Ok(())
}

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

/// Navigate a dot-separated path through TOML structure
fn navigate_path<'a>(data: &'a HashMap<String, toml::Value>, path: &str) -> Option<&'a toml::Value> {
    let parts: Vec<&str> = path.split('.').collect();

    if parts.is_empty() {
        return None;
    }

    // Start with the first part
    let mut current = data.get(parts[0])?;

    // Navigate through remaining parts
    for part in &parts[1..] {
        match current {
            toml::Value::Table(table) => {
                current = table.get(*part)?;
            }
            _ => return None, // Can't navigate deeper
        }
    }

    Some(current)
}

/// Create the settings module with all functions
pub fn create_settings_module() -> QValue {
    let mut module_map = HashMap::new();

    // get(path) function
    module_map.insert(
        "get".to_string(),
        QValue::Fun(QFun::new("get".to_string(), "settings".to_string())),
    );

    // contains(path) function
    module_map.insert(
        "contains".to_string(),
        QValue::Fun(QFun::new("contains".to_string(), "settings".to_string())),
    );

    // section(name) function
    module_map.insert(
        "section".to_string(),
        QValue::Fun(QFun::new("section".to_string(), "settings".to_string())),
    );

    // all() function
    module_map.insert(
        "all".to_string(),
        QValue::Fun(QFun::new("all".to_string(), "settings".to_string())),
    );

    QValue::Module(Box::new(QModule::new("std/settings".to_string(), module_map)))
}

/// Call a settings function
pub fn call_settings_function(func_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    let settings = SETTINGS_DATA.read().unwrap();

    match func_name {
        "settings.get" => {
            // Validate arguments
            if args.len() != 1 {
                return arg_err!("settings.get() expects 1 argument, got {}", args.len());
            }

            let path = match &args[0] {
                QValue::Str(s) => &s.value,
                _ => return Err("settings.get() expects a string path".to_string()),
            };

            // If no settings loaded, return nil
            let data = match settings.as_ref() {
                Some(d) => d,
                None => return Ok(QValue::Nil(QNil)),
            };

            // Navigate the path
            match navigate_path(data, path) {
                Some(value) => Ok(toml_to_qvalue(value)),
                None => Ok(QValue::Nil(QNil)),
            }
        }

        "settings.contains" => {
            // Validate arguments
            if args.len() != 1 {
                return arg_err!("settings.contains() expects 1 argument, got {}", args.len());
            }

            let path = match &args[0] {
                QValue::Str(s) => &s.value,
                _ => return Err("settings.contains() expects a string path".to_string()),
            };

            // If no settings loaded, return false
            let data = match settings.as_ref() {
                Some(d) => d,
                None => return Ok(QValue::Bool(QBool::new(false))),
            };

            // Check if path exists
            let exists = navigate_path(data, path).is_some();
            Ok(QValue::Bool(QBool::new(exists)))
        }

        "settings.section" => {
            // Validate arguments
            if args.len() != 1 {
                return arg_err!("settings.section() expects 1 argument, got {}", args.len());
            }

            let name = match &args[0] {
                QValue::Str(s) => &s.value,
                _ => return Err("settings.section() expects a string name".to_string()),
            };

            // If no settings loaded, return nil
            let data = match settings.as_ref() {
                Some(d) => d,
                None => return Ok(QValue::Nil(QNil)),
            };

            // Get the section
            match navigate_path(data, name) {
                Some(value) => Ok(toml_to_qvalue(value)),
                None => Ok(QValue::Nil(QNil)),
            }
        }

        "settings.all" => {
            // Validate arguments
            if !args.is_empty() {
                return arg_err!("settings.all() expects no arguments, got {}", args.len());
            }

            // If no settings loaded, return empty dict
            let data = match settings.as_ref() {
                Some(d) => d,
                None => return Ok(QValue::Dict(Box::new(QDict::new(HashMap::new()))))
            };

            // Convert entire settings to Dict
            let mut map = HashMap::new();
            for (key, value) in data {
                map.insert(key.clone(), toml_to_qvalue(value));
            }

            Ok(QValue::Dict(Box::new(QDict::new(map))))
        }

        _ => attr_err!("Unknown settings function: {}", func_name),
    }
}
