// ============================================================================
// Simplified module loading with proper public/private encapsulation
// ============================================================================

use std::env;
use std::rc::Rc;
use std::cell::RefCell;
use std::collections::{HashMap, HashSet};
use crate::scope::Scope;
use crate::types::{QValue, QModule};
use crate::{QuestParser, Rule, eval_pair};
use pest::Parser;

/// Load an external Quest module from a file path
///
/// This implements:
/// - Module caching (same module loaded once, shared state)
/// - Public/private separation (only `pub` items are accessible externally)
/// - Proper closure capture (module functions can access private members)
pub fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
    // Resolve path (handles relative imports and search paths)
    let resolved_path = resolve_module_path_full(path, scope)?;

    // Check module cache
    let module = if let Some(cached) = scope.get_cached_module(&resolved_path) {
        cached
    } else {
        // Load fresh module
        let file_content = std::fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read module file '{}': {}", resolved_path, e))?;

        let module_docstring = extract_docstring(&file_content);

        // Canonicalize path for relative imports
        let canonical_path = std::path::Path::new(&resolved_path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| resolved_path.clone());

        // Create module scope (fresh, not inherited from parent)
        let mut module_scope = Scope::new();
        module_scope.module_cache = Rc::clone(&scope.module_cache);
        module_scope.current_script_path = Rc::new(RefCell::new(Some(canonical_path.clone())));

        // Parse and evaluate module
        let pairs = QuestParser::parse(Rule::program, &file_content)
            .map_err(|e| format!("Parse error in module '{}': {}", path, e))?;

        for pair in pairs {
            if matches!(pair.as_rule(), Rule::EOI) {
                continue;
            }
            for statement in pair.into_inner() {
                if matches!(statement.as_rule(), Rule::EOI) {
                    continue;
                }
                // Note: eval_pair should call scope.mark_public() when it sees `pub` keyword
                eval_pair(statement, &mut module_scope)?;
            }
        }

        // Get the complete module scope (contains both public and private)
        let all_members = module_scope.to_flat_map();
        let public_items = module_scope.public_items.clone();

        // IMPORTANT: All functions in all_members have their captured_scope set to
        // the module's scope, so they can access private variables

        // Create module with public/private separation
        let new_module = QValue::Module(QModule::with_public_items(
            alias.to_string(),
            all_members,
            public_items,
            Some(resolved_path.clone()),
            module_docstring
        ));

        // Cache for future imports
        scope.cache_module(resolved_path.clone(), new_module.clone());

        new_module
    };

    scope.declare(alias, module)?;
    Ok(())
}

/// Resolve module path with relative import support
fn resolve_module_path_full(path: &str, scope: &Scope) -> Result<String, String> {
    // Check if this is a relative import (starts with ".")
    if path.starts_with('.') {
        // Relative import - resolve relative to current script
        let current_script = scope.current_script_path.borrow().clone();
        if let Some(script_path) = current_script {
            let script_dir = std::path::Path::new(&script_path)
                .parent()
                .ok_or_else(|| format!("Cannot determine parent directory of '{}'", script_path))?;

            let relative = path.strip_prefix('.').unwrap_or(path);
            let full_path = script_dir.join(relative);

            let full_path_str = full_path.to_string_lossy().to_string();
            return Ok(if full_path_str.ends_with(".q") {
                full_path_str
            } else {
                format!("{}.q", full_path_str)
            });
        } else {
            return Err("Relative imports (starting with '.') can only be used in script files, not in REPL".to_string());
        }
    }

    // Absolute import - use search paths
    let mut search_paths = vec![];

    // Try to get search paths from os module if it exists
    if let Some(QValue::Module(os_module)) = scope.get("os") {
        if let Some(QValue::Array(arr)) = os_module.get_member("search_path") {
            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
            for path_component in quest_include.split(separator) {
                if !path_component.is_empty() {
                    search_paths.push(path_component.to_string());
                }
            }
        }
    }

    resolve_module_path(path, &search_paths)
}

/// Resolve a module path using search paths
pub fn resolve_module_path(relative_path: &str, search_paths: &[String]) -> Result<String, String> {
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

    // Try each search path
    for search_dir in search_paths {
        let candidate = std::path::Path::new(search_dir).join(&with_extension);
        if candidate.exists() {
            return Ok(candidate.to_string_lossy().to_string());
        }
    }

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
        if let Some(end_pos) = trimmed[3..].find("\"\"\"") {
            return Some(trimmed[3..3 + end_pos].to_string());
        }
        return None;
    }

    // Check for single-quoted string literal
    if trimmed.starts_with('"') {
        let mut chars = trimmed.chars();
        chars.next(); // Skip opening quote

        let mut result = String::new();
        let mut escaped = false;

        for ch in chars {
            if escaped {
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
/// Checks for overlay files in lib/ directory and merges them with Rust implementation.
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

    let overlay_docstring = extract_docstring(&overlay_source);

    // Create fresh scope for overlay
    let mut overlay_scope = Scope::new();
    overlay_scope.module_cache = Rc::clone(&scope.module_cache);

    // Set current script path for relative imports
    let canonical_path = std::path::Path::new(&path)
        .canonicalize()
        .ok()
        .and_then(|p| p.to_str().map(|s| s.to_string()))
        .unwrap_or_else(|| path.clone());
    overlay_scope.current_script_path = Rc::new(RefCell::new(Some(canonical_path)));

    // Set __builtin__ to the Rust module (for overlay code to access)
    overlay_scope.declare("__builtin__", rust_module.clone())?;

    // Parse and evaluate overlay
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

    // Merge namespaces: Rust module + Quest overlay additions/replacements
    let mut merged_members = HashMap::new();

    // Start with Rust module members
    if let QValue::Module(m) = &rust_module {
        for (name, value) in m.get_members_ref().borrow().iter() {
            merged_members.insert(name.clone(), value.clone());
        }
    }

    // Overlay Quest additions/replacements (skip __builtin__)
    let overlay_all = overlay_scope.to_flat_map();
    for (key, value) in overlay_all {
        if key != "__builtin__" {
            merged_members.insert(key, value);
        }
    }

    // Merge public items
    let mut merged_public_items = if let QValue::Module(m) = &rust_module {
        // Get Rust module's public items
        m.public_member_names().into_iter().collect::<HashSet<_>>()
    } else {
        HashSet::new()
    };

    // Add overlay's public items (excluding __builtin__)
    for item in &overlay_scope.public_items {
        if item != "__builtin__" {
            merged_public_items.insert(item.clone());
        }
    }

    // Use overlay docstring if present, otherwise use Rust docstring
    let final_doc = if let Some(doc) = overlay_docstring {
        Some(doc)
    } else if let QValue::Module(m) = &rust_module {
        m.doc.clone()
    } else {
        None
    };

    Ok(QValue::Module(QModule::with_public_items(
        module_path.to_string(),
        merged_members,
        merged_public_items,
        Some(path),
        final_doc,
    )))
}
