use std::collections::HashMap;
use crate::control_flow::EvalError;
use crate::{arg_err, name_err};
use std::env;
use crate::types::*;

pub fn create_os_module() -> QValue {
    let mut members = HashMap::new();

    // Directory operations
    members.insert("listdir".to_string(), create_fn("os", "listdir"));
    members.insert("mkdir".to_string(), create_fn("os", "mkdir"));
    members.insert("rmdir".to_string(), create_fn("os", "rmdir"));

    // File operations
    members.insert("remove".to_string(), create_fn("os", "remove"));
    members.insert("rename".to_string(), create_fn("os", "rename"));

    // Environment and working directory
    members.insert("getenv".to_string(), create_fn("os", "getenv"));
    members.insert("setenv".to_string(), create_fn("os", "setenv"));
    members.insert("unsetenv".to_string(), create_fn("os", "unsetenv"));
    members.insert("environ".to_string(), create_fn("os", "environ"));
    members.insert("getcwd".to_string(), create_fn("os", "getcwd"));
    members.insert("chdir".to_string(), create_fn("os", "chdir"));

    // Module search path - populated from QUEST_INCLUDE environment variable
    // Defaults to "lib/" if QUEST_INCLUDE is not set
    let quest_include = env::var("QUEST_INCLUDE").unwrap_or_else(|_| "lib/".to_string());
    let mut search_paths = Vec::new();

    if !quest_include.is_empty() {
        // Split on ':' for Unix or ';' for Windows
        let separator = if cfg!(windows) { ';' } else { ':' };
        for path in quest_include.split(separator) {
            if !path.is_empty() {
                search_paths.push(QValue::Str(QString::new(path.to_string())));
            }
        }
    }

    members.insert("search_path".to_string(), QValue::Array(QArray::new(search_paths)));

    QValue::Module(Box::new(QModule::new("os".to_string(), members)))
}

/// Handle os.* function calls
pub fn call_os_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "os.getcwd" => {
            if !args.is_empty() {
                return arg_err!("getcwd expects 0 arguments, got {}", args.len());
            }
            let cwd = env::current_dir()
                .map_err(|e| format!("Failed to get current directory: {}", e))?;
            Ok(QValue::Str(QString::new(cwd.to_string_lossy().to_string())))
        }
        "os.chdir" => {
            if args.len() != 1 {
                return arg_err!("chdir expects 1 argument, got {}", args.len());
            }
            let path = args[0].as_str();
            env::set_current_dir(&path)
                .map_err(|e| format!("Failed to change directory to '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.listdir" => {
            if args.len() != 1 {
                return arg_err!("listdir expects 1 argument, got {}", args.len());
            }
            let path = args[0].as_str();
            let entries = std::fs::read_dir(&path)
                .map_err(|e| format!("Failed to read directory '{}': {}", path, e))?;

            let mut items = Vec::new();
            for entry in entries {
                let entry = entry.map_err(|e| format!("Failed to read directory entry: {}", e))?;
                let file_name = entry.file_name().to_string_lossy().to_string();
                items.push(QValue::Str(QString::new(file_name)));
            }
            Ok(QValue::Array(QArray::new(items)))
        }
        "os.mkdir" => {
            if args.len() != 1 {
                return arg_err!("mkdir expects 1 argument, got {}", args.len());
            }
            let path = args[0].as_str();
            std::fs::create_dir(&path)
                .map_err(|e| format!("Failed to create directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.rmdir" => {
            if args.len() != 1 {
                return arg_err!("rmdir expects 1 argument, got {}", args.len());
            }
            let path = args[0].as_str();
            std::fs::remove_dir(&path)
                .map_err(|e| format!("Failed to remove directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.rename" => {
            if args.len() != 2 {
                return arg_err!("rename expects 2 arguments, got {}", args.len());
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            std::fs::rename(&src, &dst)
                .map_err(|e| format!("Failed to rename '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.getenv" => {
            if args.len() != 1 {
                return arg_err!("getenv expects 1 argument, got {}", args.len());
            }
            let key = args[0].as_str();
            match env::var(&key) {
                Ok(value) => Ok(QValue::Str(QString::new(value))),
                Err(_) => Ok(QValue::Nil(QNil)),
            }
        }
        "os.setenv" => {
            if args.len() != 2 {
                return arg_err!("setenv expects 2 arguments (key, value), got {}", args.len());
            }
            let key = args[0].as_str();

            // If value is nil, unset the environment variable
            match &args[1] {
                QValue::Nil(_) => {
                    env::remove_var(&key);
                }
                _ => {
                    let value = args[1].as_str();
                    env::set_var(&key, &value);
                }
            }
            Ok(QValue::Nil(QNil))
        }
        "os.unsetenv" => {
            if args.len() != 1 {
                return arg_err!("unsetenv expects 1 argument, got {}", args.len());
            }
            let key = args[0].as_str();
            env::remove_var(&key);
            Ok(QValue::Nil(QNil))
        }
        "os.environ" => {
            if !args.is_empty() {
                return arg_err!("environ expects 0 arguments, got {}", args.len());
            }
            let mut env_dict = HashMap::new();
            for (key, value) in env::vars() {
                env_dict.insert(key, QValue::Str(QString::new(value)));
            }
            Ok(QValue::Dict(Box::new(QDict::new(env_dict))))
        }
        _ => name_err!("Unknown os function: {}", func_name)
    }
}
