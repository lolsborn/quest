use std::env;
use std::rc::Rc;
use std::cell::RefCell;
use std::collections::HashMap;
use crate::scope::Scope;
use crate::types::{QValue, QModule};
use crate::{QuestParser, Rule, eval_pair};
use pest::Parser;

/// Load an external Quest module from a file path
pub fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
    // Check if this is a relative import (starts with ".")
    let resolved_path = if path.starts_with('.') {
        // Relative import - resolve relative to current script
        let current_script = scope.current_script_path.borrow().clone();
        if let Some(script_path) = current_script {
            // Get the directory of the current script
            let script_dir = std::path::Path::new(&script_path)
                .parent()
                .ok_or_else(|| format!("Cannot determine parent directory of '{}'", script_path))?;

            // Remove the leading "." and join with script directory
            let relative = path.strip_prefix('.').unwrap_or(path);
            let full_path = script_dir.join(relative);

            // Add .q extension if not present
            let full_path_str = full_path.to_string_lossy().to_string();
            if full_path_str.ends_with(".q") {
                full_path_str
            } else {
                format!("{}.q", full_path_str)
            }
        } else {
            return Err("Relative imports (starting with '.') can only be used in script files, not in REPL".to_string());
        }
    } else {
        // Absolute import - use normal resolution
        let mut search_paths = vec![];

        // Try to get search paths from os module if it exists
        if let Some(QValue::Module(os_module)) = scope.get("os") {
            if let Some(QValue::Array(arr)) = os_module.members.borrow().get("search_path") {
                for elem in &arr.elements {
                    if let QValue::Str(s) = elem {
                        search_paths.push(s.value.clone());
                    }
                }
            }
        }

        // If no search paths from os module, use default from QUEST_INCLUDE
        if search_paths.is_empty() {
            let quest_include = env::var("QUEST_INCLUDE").unwrap_or_else(|_| "lib/".to_string());
            if !quest_include.is_empty() {
                let separator = if cfg!(windows) { ';' } else { ':' };
                for path in quest_include.split(separator) {
                    if !path.is_empty() {
                        search_paths.push(path.to_string());
                    }
                }
            }
        }

        resolve_module_path(path, &search_paths)?
    };

    // Check if module is already cached
    let module = if let Some(cached) = scope.get_cached_module(&resolved_path) {
        // Module already loaded - use cached version
        cached
    } else {
        // Load and evaluate the external .q file
        let file_content = std::fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read module file '{}': {}", resolved_path, e))?;

        // Extract module docstring (first string literal in file)
        let module_docstring = extract_docstring(&file_content);

        // Canonicalize the resolved path for setting as current_script_path
        let canonical_path = std::path::Path::new(&resolved_path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| resolved_path.clone());

        // Create a fresh scope for the module (not cloned from parent)
        // This prevents variable name conflicts when multiple files import the same module
        // Share the parent scope's module cache but create new current_script_path for this module
        let mut module_scope = Scope::new();
        module_scope.module_cache = Rc::clone(&scope.module_cache);

        // Set the current script path for this module (for nested relative imports)
        // Each module gets its own Rc so nested imports don't interfere with parent
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

        // Create a module object with the module's exported variables
        // Convert scope to flat HashMap for module storage
        let members = module_scope.to_flat_map();

        let new_module = QValue::Module(QModule::with_doc(
            alias.to_string(),
            members,
            Some(resolved_path.clone()),
            module_docstring
        ));

        // Cache the module for future imports
        scope.cache_module(resolved_path.clone(), new_module.clone());

        new_module
    };

    scope.declare(alias, module)?;
    Ok(())
}

/// Resolve a module path using search paths
pub fn resolve_module_path(relative_path: &str, search_paths: &[String]) -> Result<String, String> {
    // Search precedence:
    // 1. Current working directory
    // 2. Paths in search_paths (from os.search_path, user-modifiable)
    // 3. Paths from QUEST_INCLUDE env variable (already in search_paths)

    // Add .q extension if not already present
    let with_extension = if relative_path.ends_with(".q") {
        relative_path.to_string()
    } else {
        format!("{}.q", relative_path)
    };

    // Try current directory first
    let cwd_path = env::current_dir()
        .map_err(|e| format!("Failed to get current directory: {}", e))?
        .join(&with_extension);

    if cwd_path.exists() {
        return Ok(cwd_path.to_string_lossy().to_string());
    }

    // Try each search path in order
    for search_dir in search_paths {
        let candidate = std::path::Path::new(search_dir).join(&with_extension);
        if candidate.exists() {
            return Ok(candidate.to_string_lossy().to_string());
        }
    }

    // Not found anywhere
    Err(format!(
        "Module '{}' not found in current directory or search paths: [{}]",
        relative_path,
        search_paths.join(", ")
    ))
}

/// Extract docstring from the beginning of a file or function body
pub fn extract_docstring(body: &str) -> Option<String> {
    let trimmed = body.trim();

    // Check for triple-quoted string (multi-line)
    if trimmed.starts_with("\"\"\"") {
        // Find the closing triple quotes
        if let Some(end_pos) = trimmed[3..].find("\"\"\"") {
            return Some(trimmed[3..3 + end_pos].to_string());
        }
        return None;
    }

    // Check if body starts with a single-quoted string literal
    if trimmed.starts_with('"') {
        // Find the end of the string, handling escape sequences
        let mut chars = trimmed.chars();
        chars.next(); // Skip opening quote

        let mut result = String::new();
        let mut escaped = false;

        for ch in chars {
            if escaped {
                // Handle escape sequences
                match ch {
                    'n' => result.push('\n'),
                    't' => result.push('\t'),
                    'r' => result.push('\r'),
                    '\\' => result.push('\\'),
                    '"' => result.push('"'),
                    _ => {
                        result.push('\\');
                        result.push(ch);
                    }
                }
                escaped = false;
            } else if ch == '\\' {
                escaped = true;
            } else if ch == '"' {
                // Found closing quote
                return Some(result);
            } else {
                result.push(ch);
            }
        }
    }

    None
}

/// Apply Quest overlay to a built-in module (QEP-002)
///
/// Checks for overlay files in lib/ directory and merges them with Rust implementation:
/// 1. Tries lib/{module_path}.q (file module)
/// 2. Tries lib/{module_path}/index.q (directory module)
/// 3. If found, executes overlay with __builtin__ set to rust_module
/// 4. Merges namespaces (Quest code overrides Rust)
pub fn apply_module_overlay(
    rust_module: QValue,
    module_path: &str,
    scope: &mut Scope,
) -> Result<QValue, String> {
    // Check for overlay files
    let file_path = format!("lib/{}.q", module_path);
    let dir_path = format!("lib/{}/index.q", module_path);

    let overlay_path = if std::path::Path::new(&file_path).exists() {
        Some(file_path)
    } else if std::path::Path::new(&dir_path).exists() {
        Some(dir_path)
    } else {
        None
    };

    // If no overlay exists, return Rust module as-is
    let Some(path) = overlay_path else {
        return Ok(rust_module);
    };

    // Load overlay file
    let overlay_source = std::fs::read_to_string(&path)
        .map_err(|e| format!("Failed to read overlay file '{}': {}", path, e))?;

    // Extract module docstring from overlay (first string literal)
    let overlay_docstring = extract_docstring(&overlay_source);

    // Create a fresh scope for the overlay
    let mut overlay_scope = Scope::new();
    overlay_scope.module_cache = Rc::clone(&scope.module_cache);

    // Set current script path for relative imports in overlay
    let canonical_path = std::path::Path::new(&path)
        .canonicalize()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
        .unwrap_or_else(|| path.clone());
    overlay_scope.current_script_path = Rc::new(RefCell::new(Some(canonical_path)));

    // **Critical:** Set __builtin__ to the Rust module
    overlay_scope.declare("__builtin__", rust_module.clone())?;

    // Parse and evaluate the overlay file
    let pairs = QuestParser::parse(Rule::program, &overlay_source)
        .map_err(|e| format!("Parse error in overlay '{}': {}", path, e))?;

    for pair in pairs {
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }
            eval_pair(statement, &mut overlay_scope)?;
        }
    }

    // Merge namespaces: Start with Rust module, then overlay Quest additions/replacements
    let mut merged_members = HashMap::new();

    // Add all members from Rust module
    if let QValue::Module(m) = &rust_module {
        for (name, value) in m.members.borrow().iter() {
            merged_members.insert(name.clone(), value.clone());
        }
    }

    // Overlay Quest additions/replacements (skip __builtin__)
    let flat_map = overlay_scope.to_flat_map();
    for (key, value) in flat_map {
        if key != "__builtin__" {
            merged_members.insert(key, value);
        }
    }

    // Create merged module with overlay docstring (if present) or Rust docstring
    let final_doc = if let Some(doc) = overlay_docstring {
        Some(doc)
    } else if let QValue::Module(m) = &rust_module {
        m.doc.clone()
    } else {
        None
    };

    Ok(QValue::Module(QModule::with_doc(
        module_path.to_string(),
        merged_members,
        Some(path),
        final_doc,
    )))
}
