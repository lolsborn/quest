use std::collections::HashMap;
use std::env;
use crate::types::*;

pub fn create_os_module() -> QValue {
    // Create a wrapper for os functions
    fn create_os_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "os".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Directory operations
    members.insert("listdir".to_string(), create_os_fn("listdir", "Lists the contents of a directory"));
    members.insert("mkdir".to_string(), create_os_fn("mkdir", "Creates a new directory"));
    members.insert("rmdir".to_string(), create_os_fn("rmdir", "Removes an empty directory"));

    // File operations
    members.insert("remove".to_string(), create_os_fn("remove", "Deletes a file"));
    members.insert("rename".to_string(), create_os_fn("rename", "Renames a file or directory"));

    // Environment and working directory
    members.insert("getenv".to_string(), create_os_fn("getenv", "Get environment variable"));
    members.insert("getcwd".to_string(), create_os_fn("getcwd", "Returns the current working directory"));
    members.insert("chdir".to_string(), create_os_fn("chdir", "Changes the current working directory"));

    // Module search path - populated from QUEST_INCLUDE environment variable
    let quest_include = env::var("QUEST_INCLUDE").unwrap_or_default();
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

    QValue::Module(QModule::new("os".to_string(), members))
}
