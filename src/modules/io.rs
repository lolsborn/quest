use std::collections::HashMap;
use crate::types::*;

pub fn create_io_module() -> QValue {
    let mut members = HashMap::new();

    // File I/O functions
    members.insert("read".to_string(), create_fn("io", "read"));
    members.insert("write".to_string(), create_fn("io", "write"));
    members.insert("append".to_string(), create_fn("io", "append"));

    // Path operations
    members.insert("exists".to_string(), create_fn("io", "exists"));
    members.insert("is_file".to_string(), create_fn("io", "is_file"));
    members.insert("is_dir".to_string(), create_fn("io", "is_dir"));

    // File metadata
    members.insert("size".to_string(), create_fn("io", "size"));

    // File operations
    members.insert("copy".to_string(), create_fn("io", "copy"));
    members.insert("move".to_string(), create_fn("io", "move"));
    members.insert("remove".to_string(), create_fn("io", "remove"));

    // Glob/pattern matching functions
    members.insert("glob".to_string(), create_fn("io", "glob"));
    members.insert("glob_match".to_string(), create_fn("io", "glob_match"));

    QValue::Module(QModule::new("io".to_string(), members))
}

/// Handle io.* function calls
pub fn call_io_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "io.remove" => {
            if args.len() != 1 {
                return Err(format!("remove expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let path_obj = std::path::Path::new(&path);
            if path_obj.is_file() {
                std::fs::remove_file(&path)
                    .map_err(|e| format!("Failed to remove file '{}': {}", path, e))?;
            } else if path_obj.is_dir() {
                std::fs::remove_dir_all(&path)
                    .map_err(|e| format!("Failed to remove directory '{}': {}", path, e))?;
            } else {
                return Err(format!("Path '{}' does not exist", path));
            }
            Ok(QValue::Nil(QNil))
        }
        "io.glob" => {
            if args.len() != 1 {
                return Err(format!("glob expects 1 argument, got {}", args.len()));
            }
            let pattern = args[0].as_str();

            let mut paths = Vec::new();
            match glob::glob(&pattern) {
                Ok(entries) => {
                    for entry in entries {
                        match entry {
                            Ok(path) => {
                                paths.push(QValue::Str(QString::new(
                                    path.to_string_lossy().to_string()
                                )));
                            }
                            Err(e) => return Err(format!("Glob error: {}", e)),
                        }
                    }
                }
                Err(e) => return Err(format!("Invalid glob pattern: {}", e)),
            }

            Ok(QValue::Array(QArray::new(paths)))
        }

        "io.glob_match" => {
            if args.len() != 2 {
                return Err(format!("glob_match expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let pattern = args[1].as_str();

            match glob::Pattern::new(&pattern) {
                Ok(glob_pattern) => {
                    let matches = glob_pattern.matches(&path);
                    Ok(QValue::Bool(QBool::new(matches)))
                }
                Err(e) => Err(format!("Invalid glob pattern: {}", e)),
            }
        }
        "io.read" => {
            if args.len() != 1 {
                return Err(format!("read expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = std::fs::read_to_string(&path)
                .map_err(|e| format!("Failed to read file '{}': {}", path, e))?;
            Ok(QValue::Str(QString::new(content)))
        }
        "io.write" => {
            if args.len() != 2 {
                return Err(format!("write expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = args[1].as_str();
            std::fs::write(&path, content)
                .map_err(|e| format!("Failed to write file '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.append" => {
            if args.len() != 2 {
                return Err(format!("append expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = args[1].as_str();
            let mut file = std::fs::OpenOptions::new()
                .create(true)
                .append(true)
                .open(&path)
                .map_err(|e| format!("Failed to open file '{}' for appending: {}", path, e))?;
            use std::io::Write;
            file.write_all(content.as_bytes())
                .map_err(|e| format!("Failed to write to file '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.exists" => {
            if args.len() != 1 {
                return Err(format!("exists expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let exists = std::path::Path::new(&path).exists();
            Ok(QValue::Bool(QBool::new(exists)))
        }
        "io.is_file" => {
            if args.len() != 1 {
                return Err(format!("is_file expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let is_file = std::path::Path::new(&path).is_file();
            Ok(QValue::Bool(QBool::new(is_file)))
        }
        "io.is_dir" => {
            if args.len() != 1 {
                return Err(format!("is_dir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let is_dir = std::path::Path::new(&path).is_dir();
            Ok(QValue::Bool(QBool::new(is_dir)))
        }
        "io.size" => {
            if args.len() != 1 {
                return Err(format!("io.size expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let metadata = std::fs::metadata(&path)
                .map_err(|e| format!("Failed to get metadata for '{}': {}", path, e))?;
            Ok(QValue::Num(QNum::new(metadata.len() as f64)))
        }
        "io.copy" => {
            if args.len() != 2 {
                return Err(format!("io.copy expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            std::fs::copy(&src, &dst)
                .map_err(|e| format!("Failed to copy '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.move" => {
            if args.len() != 2 {
                return Err(format!("io.move expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            std::fs::rename(&src, &dst)
                .map_err(|e| format!("Failed to move '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }

        _ => Err(format!("Unknown io function: {}", func_name))
    }
}
