use std::collections::HashMap;
use crate::types::*;

pub fn create_io_module() -> QValue {
    fn create_io_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "io".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // File I/O functions
    members.insert("read".to_string(), create_io_fn("read", "Read entire file contents as string"));
    members.insert("write".to_string(), create_io_fn("write", "Write string to file (overwrites)"));
    members.insert("append".to_string(), create_io_fn("append", "Append string to file"));

    // Path operations
    members.insert("exists".to_string(), create_io_fn("exists", "Check if path exists"));
    members.insert("is_file".to_string(), create_io_fn("is_file", "Check if path is a file"));
    members.insert("is_dir".to_string(), create_io_fn("is_dir", "Check if path is a directory"));

    // File metadata
    members.insert("size".to_string(), create_io_fn("size", "Get file size in bytes"));

    // File operations
    members.insert("copy".to_string(), create_io_fn("copy", "Copy file from source to destination"));
    members.insert("move".to_string(), create_io_fn("move", "Move/rename file from source to destination"));

    // Glob/pattern matching functions
    members.insert("glob".to_string(), create_io_fn("glob", "Find all files matching a glob pattern"));
    members.insert("glob_match".to_string(), create_io_fn("glob_match", "Check if path matches glob pattern"));

    QValue::Module(QModule::new("io".to_string(), members))
}
