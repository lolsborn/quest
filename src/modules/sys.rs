use std::collections::HashMap;
use std::env;
use std::path::Path;
use std::rc::Rc;
use std::cell::RefCell;
use crate::types::*;
use crate::Scope;
use crate::{QuestParser, Rule, eval_pair, extract_docstring};
use pest::Parser;

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

    // load_module - Function to dynamically load a module at runtime
    members.insert("load_module".to_string(), create_fn("sys", "load_module"));
    members.insert("exit".to_string(), create_fn("sys", "exit"));
    members.insert("fail".to_string(), create_fn("sys", "fail"));

    QValue::Module(QModule::new("sys".to_string(), members))
}

/// Handle sys.* function calls
pub fn call_sys_function(func_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "sys.load_module" => {
            if args.len() != 1 {
                return Err(format!("sys.load_module expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();

            // Resolve path (handle relative paths)
            let resolved_path = if Path::new(&path).is_absolute() {
                path.to_string()
            } else {
                // Resolve relative to current working directory
                env::current_dir()
                    .map_err(|e| format!("Cannot get current directory: {}", e))?
                    .join(&path)
                    .to_string_lossy()
                    .to_string()
            };

            // Canonicalize path for security (prevents directory traversal)
            let canonical_path = Path::new(&resolved_path)
                .canonicalize()
                .map_err(|e| format!("Cannot load module '{}': {}", path, e))?
                .to_string_lossy()
                .to_string();

            // Check if module is already cached
            let module = if let Some(cached) = scope.get_cached_module(&canonical_path) {
                // Module already loaded - return cached version
                cached
            } else {
                // Load the module file
                let file_content = std::fs::read_to_string(&canonical_path)
                    .map_err(|e| format!("Failed to read module file '{}': {}", canonical_path, e))?;

                // Extract module docstring
                let module_docstring = extract_docstring(&file_content);

                // Create a fresh scope for the module
                let mut module_scope = Scope::new();
                module_scope.module_cache = Rc::clone(&scope.module_cache);
                module_scope.current_script_path = Rc::new(RefCell::new(Some(canonical_path.clone())));

                // Parse and evaluate the module file
                let pairs = QuestParser::parse(Rule::program, &file_content)
                    .map_err(|e| format!("Parse error in module '{}': {}", path, e))?;

                // Execute all statements in the module
                for pair in pairs {
                    if matches!(pair.as_rule(), Rule::EOI) {
                        continue;
                    }
                    for statement in pair.into_inner() {
                        if matches!(statement.as_rule(), Rule::EOI) {
                            continue;
                        }
                        eval_pair(statement, &mut module_scope)?;
                    }
                }

                // Create a module object
                let members = module_scope.to_flat_map();
                let module_name = Path::new(&canonical_path)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("module")
                    .to_string();

                let new_module = QValue::Module(QModule::with_doc(
                    module_name,
                    members,
                    Some(canonical_path.clone()),
                    module_docstring
                ));

                // Cache the module
                scope.cache_module(canonical_path.clone(), new_module.clone());

                new_module
            };

            Ok(module)
        }

        "sys.exit" => {
            let exit_code = if args.is_empty() {
                0
            } else if args.len() == 1 {
                args[0].as_num()? as i32
            } else {
                return Err(format!("sys.exit expects 0 or 1 arguments, got {}", args.len()));
            };
            std::process::exit(exit_code);
        }

        "sys.fail" => {
            if args.is_empty() {
                return Err("Failure".to_string());
            } else if args.len() == 1 {
                let message = args[0].as_str();
                return Err(message);
            } else {
                return Err(format!("sys.fail expects 0 or 1 arguments, got {}", args.len()));
            }
        }

        _ => Err(format!("Unknown sys function: {}", func_name))
    }
}
