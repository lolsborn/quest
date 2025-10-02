use std::collections::HashMap;
use std::env;
use std::path::Path;
use crate::types::*;

pub fn create_sys_module(args: &[String], script_path: Option<&str>) -> QValue {
    let mut members = HashMap::new();

    // argc - number of arguments
    let argc = args.len() as f64;
    members.insert("argc".to_string(), QValue::Num(QNum::new(argc)));

    // argv - array of argument strings
    let argv: Vec<QValue> = args.iter()
        .map(|s| QValue::Str(QString::new(s.clone())))
        .collect();
    members.insert("argv".to_string(), QValue::Array(QArray::new(argv)));

    // version - Quest version string
    let version = env!("CARGO_PKG_VERSION");
    members.insert("version".to_string(), QValue::Str(QString::new(version.to_string())));

    // platform - Operating system name
    let platform = if cfg!(target_os = "macos") {
        "darwin"
    } else if cfg!(target_os = "linux") {
        "linux"
    } else if cfg!(target_os = "windows") {
        "win32"
    } else if cfg!(target_os = "freebsd") {
        "freebsd"
    } else if cfg!(target_os = "openbsd") {
        "openbsd"
    } else {
        "unknown"
    };
    members.insert("platform".to_string(), QValue::Str(QString::new(platform.to_string())));

    // builtin_module_names - array of built-in module names
    let builtin_modules = vec!["math", "os", "term", "hash", "json", "io", "sys"];
    let module_names: Vec<QValue> = builtin_modules.iter()
        .map(|name| QValue::Str(QString::new(name.to_string())))
        .collect();
    members.insert("builtin_module_names".to_string(), QValue::Array(QArray::new(module_names)));

    // executable - path to the Quest executable
    let executable = env::current_exe()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
        .unwrap_or_else(|| "quest".to_string());
    members.insert("executable".to_string(), QValue::Str(QString::new(executable)));

    // script_path - absolute path to the current script (if running from a file)
    if let Some(path) = script_path {
        // Resolve to absolute path
        let abs_path = Path::new(path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| path.to_string());
        members.insert("script_path".to_string(), QValue::Str(QString::new(abs_path)));
    } else {
        // REPL or stdin - no script path
        members.insert("script_path".to_string(), QValue::Nil(QNil));
    }

    QValue::Module(QModule::new("sys".to_string(), members))
}
