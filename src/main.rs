use pest::Parser;
use pest_derive::Parser;
use rustyline::error::ReadlineError;
use rustyline::DefaultEditor;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{self, IsTerminal, Read};
use std::rc::Rc;
use std::cell::RefCell;
use std::time::Instant;
use std::sync::OnceLock;
use std::path::PathBuf;
use std::process::Command;
use serde::Deserialize;

// Hash function imports
use md5::Md5;
use sha1::Sha1;
use sha2::{Sha256, Sha512};
use crc32fast::Hasher as Crc32Hasher;

// Regex (use :: prefix to avoid conflict with modules::regex)
use ::regex::Regex;

// Base64 encoding
use base64::{Engine as _, engine::general_purpose};

// Glob import
use glob::glob as glob_pattern;

mod types;
use types::*;

mod modules;
use modules::*;

mod json_utils;
use json_utils::*;

#[derive(Parser)]
#[grammar = "quest.pest"]
pub struct QuestParser;

// Program start time for ticks_ms() function
static START_TIME: OnceLock<Instant> = OnceLock::new();

fn get_start_time() -> &'static Instant {
    START_TIME.get_or_init(|| Instant::now())
}

// Script args and path (set once at script invocation, accessed when sys module is imported)
static SCRIPT_ARGS: OnceLock<Vec<String>> = OnceLock::new();
static SCRIPT_PATH: OnceLock<Option<String>> = OnceLock::new();

fn get_script_args() -> &'static [String] {
    SCRIPT_ARGS.get().map(|v| v.as_slice()).unwrap_or(&[])
}

fn get_script_path() -> Option<&'static str> {
    SCRIPT_PATH.get().and_then(|opt| opt.as_deref())
}

// Stack frame for tracking function calls in exceptions
#[derive(Clone, Debug)]
struct StackFrame {
    function_name: String,
    line: Option<usize>,
    file: Option<String>,
}

impl StackFrame {
    fn new(function_name: String) -> Self {
        StackFrame {
            function_name,
            line: None,
            file: None,
        }
    }

    #[allow(dead_code)]
    fn with_location(function_name: String, line: Option<usize>, file: Option<String>) -> Self {
        StackFrame {
            function_name,
            line,
            file,
        }
    }

    fn to_string(&self) -> String {
        let mut s = format!("  at {}", self.function_name);
        if let Some(ref file) = self.file {
            s.push_str(&format!(" ({})", file));
            if let Some(line) = self.line {
                s.push_str(&format!(":{}", line));
            }
        }
        s
    }
}

// Scope chain for proper lexical scoping
// Uses Rc<RefCell<>> for scope levels so they can be shared (for closures, modules)
#[derive(Clone)]
struct Scope {
    // Stack of scopes - last is innermost (current scope)
    // Each scope is shared via Rc<RefCell<>> for proper closure semantics
    scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
    // Module cache: maps resolved file paths to loaded modules
    // Shared across all scopes using Rc<RefCell<>> so modules can share state
    module_cache: Rc<RefCell<HashMap<String, QValue>>>,
    // Current exception for re-raising
    current_exception: Option<QException>,
    // Call stack for exception stack traces
    call_stack: Vec<StackFrame>,
    // Current script path (for relative imports) - stored as Rc so it can be shared
    current_script_path: Rc<RefCell<Option<String>>>,
}

impl Scope {
    fn new() -> Self {
        Scope {
            scopes: vec![Rc::new(RefCell::new(HashMap::new()))],
            module_cache: Rc::new(RefCell::new(HashMap::new())),
            current_exception: None,
            call_stack: Vec::new(),
            current_script_path: Rc::new(RefCell::new(None)),
        }
    }

    // Create a scope with a specific shared map as the base scope
    // Used for module function calls so they share the module's state
    fn with_shared_base(shared_map: Rc<RefCell<HashMap<String, QValue>>>, module_cache: Rc<RefCell<HashMap<String, QValue>>>) -> Self {
        Scope {
            scopes: vec![shared_map],
            module_cache,
            current_exception: None,
            call_stack: Vec::new(),
            current_script_path: Rc::new(RefCell::new(None)),
        }
    }

    // Push a stack frame (called when entering a function)
    fn push_stack_frame(&mut self, frame: StackFrame) {
        self.call_stack.push(frame);
    }

    // Pop a stack frame (called when exiting a function)
    fn pop_stack_frame(&mut self) {
        self.call_stack.pop();
    }

    // Get a copy of the current call stack for exception handling
    fn get_stack_trace(&self) -> Vec<String> {
        self.call_stack.iter().map(|f| f.to_string()).collect()
    }

    fn push(&mut self) {
        self.scopes.push(Rc::new(RefCell::new(HashMap::new())));
    }

    fn pop(&mut self) {
        if self.scopes.len() > 1 {
            self.scopes.pop();
        }
    }

    // Look up variable starting from innermost scope
    fn get(&self, name: &str) -> Option<QValue> {
        for scope in self.scopes.iter().rev() {
            if let Some(value) = scope.borrow().get(name) {
                return Some(value.clone());
            }
        }
        None
    }

    // Set variable in the scope where it's defined, or current scope if new
    fn set(&mut self, name: &str, value: QValue) {
        // Search from innermost to outermost
        for scope in self.scopes.iter().rev() {
            if scope.borrow().contains_key(name) {
                scope.borrow_mut().insert(name.to_string(), value);
                return;
            }
        }
        // Not found in any scope - add to current (innermost) scope
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
    }

    // Declare a new variable in the current scope
    fn declare(&mut self, name: &str, value: QValue) -> Result<(), String> {
        if self.contains_in_current(name) {
            return Err(format!("Variable '{}' already declared in this scope", name));
        }
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        Ok(())
    }

    // Update an existing variable, error if undeclared
    fn update(&mut self, name: &str, value: QValue) -> Result<(), String> {
        // Search from innermost to outermost
        for scope in self.scopes.iter().rev() {
            if scope.borrow().contains_key(name) {
                scope.borrow_mut().insert(name.to_string(), value);
                return Ok(());
            }
        }
        Err(format!("Cannot assign to undeclared variable '{}'. Use 'let {} = ...' to declare it first.", name, name))
    }

    // Delete from current scope only
    fn delete(&mut self, name: &str) -> Result<(), String> {
        let current_scope = self.scopes.last().unwrap();
        if !current_scope.borrow().contains_key(name) {
            // Check if it exists in outer scope
            for scope in self.scopes.iter().rev().skip(1) {
                if scope.borrow().contains_key(name) {
                    return Err(format!("Cannot delete variable '{}' from outer scope", name));
                }
            }
            return Err(format!("Cannot delete undefined variable '{}'", name));
        }
        current_scope.borrow_mut().remove(name);
        Ok(())
    }

    // Check if variable exists in current scope only
    fn contains_in_current(&self, name: &str) -> bool {
        self.scopes.last().unwrap().borrow().contains_key(name)
    }

    // Convert to flat HashMap (for compatibility/merging scopes)
    fn to_flat_map(&self) -> HashMap<String, QValue> {
        let mut result = HashMap::new();
        for scope in &self.scopes {
            result.extend(scope.borrow().clone());
        }
        result
    }

    // Convert to flat HashMap excluding UserFun values (but including Modules)
    // Used for closure capture - closures need access to imported modules
    fn to_flat_map_no_functions(&self) -> HashMap<String, QValue> {
        let mut result = HashMap::new();
        for scope in &self.scopes {
            for (key, value) in scope.borrow().iter() {
                // Skip functions but include modules
                if !matches!(value, QValue::UserFun(_)) {
                    result.insert(key.clone(), value.clone());
                }
            }
        }
        result
    }

    // Get cached module by path
    fn get_cached_module(&self, path: &str) -> Option<QValue> {
        self.module_cache.borrow().get(path).cloned()
    }

    // Cache a module by its resolved path
    fn cache_module(&mut self, path: String, module: QValue) {
        self.module_cache.borrow_mut().insert(path, module);
    }
}

// Helper function to load an external module
fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
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

fn resolve_module_path(relative_path: &str, search_paths: &[String]) -> Result<String, String> {
    // Search precedence:
    // 1. Current working directory
    // 2. Paths in search_paths (from os.search_path, user-modifiable)
    // 3. Paths from QUEST_INCLUDE env variable (already in search_paths)

    // Try current directory first
    let cwd_path = env::current_dir()
        .map_err(|e| format!("Failed to get current directory: {}", e))?
        .join(relative_path);

    if cwd_path.exists() {
        return Ok(cwd_path.to_string_lossy().to_string());
    }

    // Try each search path in order
    for search_dir in search_paths {
        let candidate = std::path::Path::new(search_dir).join(relative_path);
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

fn eval_expression(input: &str, scope: &mut Scope) -> Result<QValue, String> {
    // Try to parse as a statement first (allows if/else, etc.)
    let pairs = QuestParser::parse(Rule::statement, input)
        .or_else(|_| QuestParser::parse(Rule::expression, input))
        .map_err(|e| format!("Parse error: {}", e))?;

    // Start evaluation from the top-level
    for pair in pairs {
        return eval_pair(pair, scope);
    }

    Err("No statement or expression found".to_string())
}

fn apply_compound_op(lhs: &QValue, op: &str, rhs: &QValue) -> Result<QValue, String> {
    match op {
        "=" => Ok(rhs.clone()),
        "+=" => {
            // Addition/concatenation
            match (lhs, rhs) {
                (QValue::Num(n1), QValue::Num(n2)) => Ok(QValue::Num(QNum::new(n1.value + n2.value))),
                (QValue::Str(s1), QValue::Str(s2)) => Ok(QValue::Str(QString::new(s1.value.clone() + &s2.value))),
                (QValue::Array(a1), QValue::Array(a2)) => {
                    let mut elements = a1.elements.clone();
                    elements.extend(a2.elements.clone());
                    Ok(QValue::Array(QArray::new(elements)))
                }
                _ => Err(format!("Cannot use += with types {} and {}", lhs.as_obj().cls(), rhs.as_obj().cls())),
            }
        }
        "-=" => {
            // Subtraction
            match (lhs, rhs) {
                (QValue::Num(n1), QValue::Num(n2)) => Ok(QValue::Num(QNum::new(n1.value - n2.value))),
                _ => Err(format!("Cannot use -= with types {} and {}", lhs.as_obj().cls(), rhs.as_obj().cls())),
            }
        }
        "*=" => {
            // Multiplication
            match (lhs, rhs) {
                (QValue::Num(n1), QValue::Num(n2)) => Ok(QValue::Num(QNum::new(n1.value * n2.value))),
                _ => Err(format!("Cannot use *= with types {} and {}", lhs.as_obj().cls(), rhs.as_obj().cls())),
            }
        }
        "/=" => {
            // Division
            match (lhs, rhs) {
                (QValue::Num(n1), QValue::Num(n2)) => {
                    if n2.value == 0.0 {
                        Err("Division by zero".to_string())
                    } else {
                        Ok(QValue::Num(QNum::new(n1.value / n2.value)))
                    }
                }
                _ => Err(format!("Cannot use /= with types {} and {}", lhs.as_obj().cls(), rhs.as_obj().cls())),
            }
        }
        "%=" => {
            // Modulo
            match (lhs, rhs) {
                (QValue::Num(n1), QValue::Num(n2)) => {
                    if n2.value == 0.0 {
                        Err("Modulo by zero".to_string())
                    } else {
                        Ok(QValue::Num(QNum::new(n1.value % n2.value)))
                    }
                }
                _ => Err(format!("Cannot use %= with types {} and {}", lhs.as_obj().cls(), rhs.as_obj().cls())),
            }
        }
        _ => Err(format!("Unknown compound operator: {}", op)),
    }
}

/// Extract the first string literal from a body for use as a docstring
fn extract_docstring(body: &str) -> Option<String> {
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

fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    match pair.as_rule() {
        Rule::statement => {
            // A statement can be various things, just evaluate the inner
            let inner = pair.into_inner().next().unwrap();
            eval_pair(inner, scope)
        }
        Rule::use_statement => {
            // Supported forms:
            // - use "path" (derive alias from filename)
            // - use "path" as identifier (explicit alias)
            //
            // Built-in modules are under std/* namespace:
            // - use "std/math" -> checks built-in math module first, then filesystem
            let inner: Vec<_> = pair.into_inner().collect();

            let (path_str, alias_opt) = match inner.len() {
                1 => {
                    // use "path" - derive alias from filename
                    let path = parse_string(inner[0].as_str());
                    (path, None)
                }
                2 => {
                    // use "path" as alias
                    let path = parse_string(inner[0].as_str());
                    let alias = inner[1].as_str().to_string();
                    (path, Some(alias))
                }
                _ => return Err("Invalid use statement".to_string()),
            };

            // Check if this is a built-in module (std/* namespace)
            if let Some(builtin_name) = path_str.strip_prefix("std/") {
                // Try to resolve as built-in module first
                let module_opt = match builtin_name {
                    "math" => Some(create_math_module()),
                    "os" => Some(create_os_module()),
                    "term" => Some(create_term_module()),
                    "hash" => Some(create_hash_module()),
                    "io" => Some(create_io_module()),
                    "crypto" => Some(create_crypto_module()),
                    "time" => Some(create_time_module()),
                    "regex" => Some(create_regex_module()),
                    "sys" => Some(create_sys_module(get_script_args(), get_script_path())),
                    // Encoding modules (only new nested paths)
                    "encoding/b64" => Some(create_b64_module()),
                    "encoding/json" => Some(create_encoding_json_module()),
                    "test.q" | "test" => None, // std/test.q is a file, not built-in
                    _ => None, // Not a built-in, try filesystem
                };

                if let Some(module) = module_opt {
                    // Use provided alias or derive from builtin name (last segment for nested paths)
                    let alias = alias_opt.unwrap_or_else(|| {
                        builtin_name.split('/').last().unwrap_or(builtin_name).to_string()
                    });

                    scope.declare(&alias, module)?;
                    return Ok(QValue::Nil(QNil));
                }
                // If not a built-in, fall through to filesystem resolution
            }

            // Not a built-in (or std/test.q), resolve from filesystem
            let mut path = path_str.clone();

            // Add .q extension if not present
            if !path.ends_with(".q") {
                path = format!("{}.q", path);
            }

            // Determine alias: use provided alias or derive from filename
            let alias = alias_opt.unwrap_or_else(|| {
                std::path::Path::new(&path)
                    .file_stem()
                    .and_then(|s| s.to_str())
                    .unwrap_or("module")
                    .to_string()
            });

            load_external_module(scope, &path, &alias)?;
            Ok(QValue::Nil(QNil))
        }
        Rule::let_statement => {
            // let identifier = expression [, identifier = expression]*
            let inner = pair.into_inner();
            for binding in inner {
                // Each binding is: identifier = expression
                let mut binding_inner = binding.into_inner();
                let identifier = binding_inner.next().unwrap().as_str();
                let value = eval_pair(binding_inner.next().unwrap(), scope)?;
                scope.declare(identifier, value)?;
            }
            Ok(QValue::Nil(QNil)) // let statements return nil
        }
        Rule::let_binding => {
            // This shouldn't be evaluated directly, only as part of let_statement
            Err("let_binding should only appear within let_statement".to_string())
        }
        Rule::del_statement => {
            // del identifier
            let mut inner = pair.into_inner();
            let identifier = inner.next().unwrap().as_str();

            // Check restrictions - cannot delete modules
            if let Some(value) = scope.get(identifier) {
                if matches!(value, QValue::Module(_)) {
                    return Err(format!("Cannot delete module '{}'", identifier));
                }
            }

            // Delete from current scope only (Scope::delete handles the check)
            scope.delete(identifier)?;
            Ok(QValue::Nil(QNil)) // del statements return nil
        }
        Rule::function_declaration => {
            // fun name(params) statements end
            let pair_str = pair.as_str();
            let mut inner = pair.into_inner();
            let name = inner.next().unwrap().as_str().to_string();

            // Collect parameters
            let mut params = Vec::new();
            let mut body_start_idx = 0;

            for (idx, p) in inner.enumerate() {
                match p.as_rule() {
                    Rule::parameter_list => {
                        for param in p.into_inner() {
                            // param can be "identifier" or "type_expr ~ : ~ identifier"
                            let param_inner: Vec<_> = param.into_inner().collect();
                            let param_name = if param_inner.len() == 1 {
                                // Untyped: just identifier
                                param_inner[0].as_str().to_string()
                            } else {
                                // Typed: type_expr : identifier - take the identifier (last one)
                                param_inner.last().unwrap().as_str().to_string()
                            };
                            params.push(param_name);
                        }
                    }
                    Rule::type_expr => {
                        // Return type annotation - skip for now
                        continue;
                    }
                    Rule::statement => {
                        // First statement marks start of body
                        if body_start_idx == 0 {
                            body_start_idx = idx;
                        }
                    }
                    _ => {}
                }
            }

            // Extract body from the original string
            // Find "fun name(params)" and take everything until "end"
            let body = if let Some(paren_pos) = pair_str.find('(') {
                if let Some(close_paren) = pair_str[paren_pos..].find(')') {
                    let after_params = paren_pos + close_paren + 1;
                    let mut body_str = &pair_str[after_params..];

                    // Skip optional return type annotation
                    body_str = body_str.trim_start();
                    if body_str.starts_with("->") {
                        if let Some(space_after_arrow) = body_str.find(char::is_whitespace) {
                            body_str = &body_str[space_after_arrow..].trim_start();
                        }
                    }

                    // Remove trailing "end"
                    if body_str.ends_with("end") {
                        body_str = &body_str[..body_str.len()-3].trim_end();
                    }
                    body_str.to_string()
                } else {
                    // No parameters
                    let after_name_idx = pair_str.find(&name).unwrap() + name.len();
                    let mut body_str = &pair_str[after_name_idx..];
                    body_str = body_str.trim_start();
                    if body_str.ends_with("end") {
                        body_str = &body_str[..body_str.len()-3].trim_end();
                    }
                    body_str.to_string()
                }
            } else {
                // No parentheses - parameterless function
                let after_name_idx = pair_str.find(&name).unwrap() + name.len();
                let mut body_str = &pair_str[after_name_idx..];
                body_str = body_str.trim_start();
                if body_str.ends_with("end") {
                    body_str = &body_str[..body_str.len()-3].trim_end();
                }
                body_str.to_string()
            };

            // Extract docstring from body
            let docstring = extract_docstring(&body);

            // Capture non-function variables for closure (functions come from module scope)
            let closure_env = scope.to_flat_map_no_functions();

            let func = QValue::UserFun(QUserFun::with_closure(
                Some(name.clone()),
                params,
                body,
                docstring,
                closure_env
            ));

            scope.declare(&name, func)?;
            Ok(QValue::Nil(QNil))
        }
        Rule::type_declaration => {
            // type TypeName string? field1 field2 ... end
            let mut inner = pair.into_inner();
            let type_name = inner.next().unwrap().as_str().to_string();

            // Check if next element is an optional docstring
            let mut type_docstring = None;
            let members_iter = inner.peekable();
            let members: Vec<_> = members_iter.collect();

            let start_idx = if !members.is_empty() && matches!(members[0].as_rule(), Rule::string) {
                // First element is the docstring
                let docstring_pair = &members[0];
                let docstring_text = parse_string(docstring_pair.as_str());
                type_docstring = Some(docstring_text);
                1  // Start parsing members from index 1
            } else {
                0  // Start parsing members from index 0
            };

            let mut fields = Vec::new();
            let mut methods = HashMap::new();
            let mut static_methods = HashMap::new();
            let mut implemented_traits = Vec::new();

            // Parse type members (fields, methods, impl blocks)
            for member in &members[start_idx..] {
                match member.as_rule() {
                    Rule::type_member => {
                        // Get the entire type_member span to check for "?" before consuming it
                        let member_str = member.as_str();

                        let mut member_inner = member.clone().into_inner();
                        let first = member_inner.next().unwrap();

                        match first.as_rule() {
                            Rule::type_expr => {
                                // Typed field: type?: name or type: name
                                // Grammar: type_expr ~ "?"? ~ ":" ~ identifier
                                let type_annotation = first.as_str().to_string();

                                // Check if the source contains "?" after the type but before the ":"
                                let optional = member_str.contains("?:");

                                // Collect remaining tokens for field name
                                let remaining: Vec<_> = member_inner.collect();
                                let field_name = remaining.last().unwrap().as_str().to_string();

                                fields.push(FieldDef::new(field_name, Some(type_annotation), optional));
                            }
                            Rule::identifier => {
                                // Untyped field: just name
                                let field_name = first.as_str().to_string();
                                fields.push(FieldDef::new(field_name, None, false));
                            }
                            Rule::function_declaration | Rule::static_function_declaration => {
                                // Method definition - extract and store
                                let is_static = first.as_rule() == Rule::static_function_declaration;
                                let func_str = first.as_str();
                                let mut func_inner = first.into_inner();
                                let method_name = func_inner.next().unwrap().as_str().to_string();

                                // Collect parameters
                                let mut params = Vec::new();
                                for p in func_inner.clone() {
                                    if p.as_rule() == Rule::parameter_list {
                                        for param in p.into_inner() {
                                            let param_inner: Vec<_> = param.into_inner().collect();
                                            let param_name = if param_inner.len() == 1 {
                                                param_inner[0].as_str().to_string()
                                            } else {
                                                param_inner.last().unwrap().as_str().to_string()
                                            };
                                            params.push(param_name);
                                        }
                                        break;
                                    }
                                }

                                // Extract method body (skip "static" keyword if present)
                                let func_str_for_body = if is_static {
                                    &func_str["static".len()..].trim_start()
                                } else {
                                    func_str
                                };

                                let body = if let Some(paren_pos) = func_str_for_body.find('(') {
                                    if let Some(close_paren) = func_str_for_body[paren_pos..].find(')') {
                                        let after_params = paren_pos + close_paren + 1;
                                        let mut body_str = &func_str_for_body[after_params..];
                                        body_str = body_str.trim_start();
                                        if body_str.starts_with("->") {
                                            if let Some(newline) = body_str.find('\n') {
                                                body_str = &body_str[newline+1..];
                                            }
                                        }
                                        body_str = body_str.trim_start();
                                        if body_str.ends_with("end") {
                                            body_str = &body_str[..body_str.len()-3].trim_end();
                                        }
                                        body_str.to_string()
                                    } else {
                                        String::new()
                                    }
                                } else {
                                    String::new()
                                };

                                // Extract docstring from method body
                                let docstring = extract_docstring(&body);

                                let func = QUserFun::with_doc(Some(method_name.clone()), params.clone(), body, docstring);

                                if is_static {
                                    static_methods.insert(method_name, func);
                                } else {
                                    // Instance methods have access to 'self' which is bound when called
                                    methods.insert(method_name, func);
                                }
                            }
                            Rule::impl_block => {
                                // impl TraitName methods end
                                let mut impl_inner = first.into_inner();
                                let trait_name = impl_inner.next().unwrap().as_str().to_string();
                                implemented_traits.push(trait_name.clone());

                                // Parse methods in impl block
                                for func in impl_inner {
                                    if func.as_rule() == Rule::function_declaration {
                                        let func_str = func.as_str();
                                        let mut func_inner = func.into_inner();
                                        let method_name = func_inner.next().unwrap().as_str().to_string();

                                        let mut params = Vec::new();
                                        for p in func_inner.clone() {
                                            if p.as_rule() == Rule::parameter_list {
                                                for param in p.into_inner() {
                                                    let param_inner: Vec<_> = param.into_inner().collect();
                                                    let param_name = if param_inner.len() == 1 {
                                                        param_inner[0].as_str().to_string()
                                                    } else {
                                                        param_inner.last().unwrap().as_str().to_string()
                                                    };
                                                    params.push(param_name);
                                                }
                                                break;
                                            }
                                        }

                                        let body = if let Some(paren_pos) = func_str.find('(') {
                                            if let Some(close_paren) = func_str[paren_pos..].find(')') {
                                                let after_params = paren_pos + close_paren + 1;
                                                let mut body_str = &func_str[after_params..];
                                                body_str = body_str.trim_start();
                                                if body_str.starts_with("->") {
                                                    if let Some(newline) = body_str.find('\n') {
                                                        body_str = &body_str[newline+1..];
                                                    }
                                                }
                                                body_str = body_str.trim_start();
                                                if body_str.ends_with("end") {
                                                    body_str = &body_str[..body_str.len()-3].trim_end();
                                                }
                                                body_str.to_string()
                                            } else {
                                                String::new()
                                            }
                                        } else {
                                            String::new()
                                        };

                                        // Extract docstring from impl method body
                                        let docstring = extract_docstring(&body);

                                        methods.insert(method_name.clone(), QUserFun::with_doc(
                                            Some(method_name),
                                            params,
                                            body,
                                            docstring
                                        ));
                                    }
                                }
                            }
                            _ => {}
                        }
                    }
                    _ => {}
                }
            }

            // Create the type with docstring
            let mut qtype = QType::with_doc(type_name.clone(), fields, type_docstring);
            for (name, func) in methods {
                qtype.add_method(name, func);
            }
            for (name, func) in static_methods {
                qtype.add_static_method(name, func);
            }
            for trait_name in &implemented_traits {
                qtype.add_trait(trait_name.clone());
            }

            // Validate trait implementations
            for trait_name in &implemented_traits {
                // Look up the trait definition
                if let Some(QValue::Trait(qtrait)) = scope.get(trait_name) {
                    // Check that all required methods are implemented
                    for trait_method in &qtrait.required_methods {
                        if let Some(impl_method) = qtype.get_method(&trait_method.name) {
                            // Method exists, validate parameter count
                            // Note: trait methods might not have 'self' in parameter list,
                            // but impl methods are instance methods and don't explicitly list 'self'
                            // So we just check that the impl method has the right number of params
                            let expected_params = trait_method.parameters.len();
                            let actual_params = impl_method.params.len();

                            if actual_params != expected_params {
                                return Err(format!(
                                    "Type {} implements trait {} but method '{}' has {} parameters, expected {}",
                                    type_name, trait_name, trait_method.name, actual_params, expected_params
                                ));
                            }
                        } else {
                            return Err(format!(
                                "Type {} implements trait {} but missing required method '{}'",
                                type_name, trait_name, trait_method.name
                            ));
                        }
                    }
                } else {
                    return Err(format!("Trait {} not found", trait_name));
                }
            }

            // Store the type in scope
            scope.declare(&type_name, QValue::Type(qtype))?;
            Ok(QValue::Nil(QNil))
        }
        Rule::trait_declaration => {
            // trait TraitName string? fun method1() fun method2() end
            let mut inner = pair.into_inner();
            let trait_name = inner.next().unwrap().as_str().to_string();

            // Check if next element is an optional docstring
            let mut trait_docstring = None;
            let methods_iter = inner.peekable();
            let methods: Vec<_> = methods_iter.collect();

            let start_idx = if !methods.is_empty() && matches!(methods[0].as_rule(), Rule::string) {
                // First element is the docstring
                let docstring_pair = &methods[0];
                let docstring_text = parse_string(docstring_pair.as_str());
                trait_docstring = Some(docstring_text);
                1  // Start parsing methods from index 1
            } else {
                0  // Start parsing methods from index 0
            };

            let mut required_methods = Vec::new();

            for method in &methods[start_idx..] {
                if method.as_rule() == Rule::trait_method {
                    let mut method_inner = method.clone().into_inner();
                    let method_name = method_inner.next().unwrap().as_str().to_string();

                    let mut parameters = Vec::new();
                    let mut return_type = None;

                    for part in method_inner {
                        match part.as_rule() {
                            Rule::parameter_list => {
                                for param in part.into_inner() {
                                    let param_inner: Vec<_> = param.into_inner().collect();
                                    let param_name = if param_inner.len() == 1 {
                                        param_inner[0].as_str().to_string()
                                    } else {
                                        param_inner.last().unwrap().as_str().to_string()
                                    };
                                    parameters.push(param_name);
                                }
                            }
                            Rule::type_expr => {
                                return_type = Some(part.as_str().to_string());
                            }
                            _ => {}
                        }
                    }

                    required_methods.push(TraitMethod::new(method_name, parameters, return_type));
                }
            }

            let qtrait = QTrait::with_doc(trait_name.clone(), required_methods, trait_docstring);
            scope.declare(&trait_name, QValue::Trait(qtrait))?;
            Ok(QValue::Nil(QNil))
        }
        Rule::assignment => {
            // Three forms:
            // 1. identifier = expression (simple variable assignment)
            // 2. identifier[index] = expression (index assignment)
            // 3. identifier.field = expression (member assignment - not implemented yet)
            let mut inner = pair.into_inner();
            let identifier = inner.next().unwrap().as_str().to_string();

            // Check if next element is index_access, member access, or "="
            let next = inner.next().unwrap();

            match next.as_rule() {
                Rule::index_access => {
                    // identifier[index] compound_op expression
                    let index_expr = next.into_inner().next().unwrap();
                    let index_value = eval_pair(index_expr, scope)?;

                    let compound_op = inner.next().unwrap();
                    let op_str = compound_op.as_str();
                    let rhs = eval_pair(inner.next().unwrap(), scope)?;

                    // Get the target (array or dict)
                    let target = scope.get(&identifier)
                        .ok_or_else(|| format!("Undefined variable: {}", identifier))?;

                    let value = if op_str == "=" {
                        rhs
                    } else {
                        // Get current value and apply compound operator
                        let current = match &target {
                            QValue::Array(arr) => {
                                let index = index_value.as_num()? as usize;
                                if index >= arr.elements.len() {
                                    return Err(format!("Index {} out of bounds for array of length {}", index, arr.elements.len()));
                                }
                                arr.elements[index].clone()
                            }
                            QValue::Dict(dict) => {
                                let key = index_value.as_str();
                                dict.map.get(&key)
                                    .ok_or_else(|| format!("Key '{}' not found in dict", key))?
                                    .clone()
                            }
                            _ => return Err(format!("Cannot index into type {}", target.as_obj().cls())),
                        };
                        apply_compound_op(&current, op_str, &rhs)?
                    };

                    match target {
                        QValue::Array(mut arr) => {
                            let index = index_value.as_num()? as usize;
                            arr.elements[index] = value;
                            scope.set(&identifier, QValue::Array(arr));
                        }
                        QValue::Dict(mut dict) => {
                            let key = index_value.as_str();
                            dict.map.insert(key, value);
                            scope.set(&identifier, QValue::Dict(dict));
                        }
                        _ => unreachable!(),
                    }
                    Ok(QValue::Nil(QNil))
                }
                Rule::identifier => {
                    // identifier.field compound_op expression
                    // Not implemented yet
                    Err("Member assignment not yet implemented".to_string())
                }
                Rule::compound_op => {
                    // identifier compound_op expression
                    let op_str = next.as_str();
                    let rhs = eval_pair(inner.next().unwrap(), scope)?;

                    let value = if op_str == "=" {
                        rhs
                    } else {
                        // Get current value and apply compound operator
                        let current = scope.get(&identifier)
                            .ok_or_else(|| format!("Undefined variable: {}", identifier))?;
                        apply_compound_op(&current, op_str, &rhs)?
                    };

                    scope.update(&identifier, value)?;
                    Ok(QValue::Nil(QNil))
                }
                _ => {
                    Err(format!("Unsupported assignment target: {:?}", next.as_rule()))
                }
            }
        }
        Rule::variable_declaration => {
            // This can match "let x = 5" if grammar interprets "let" as a type name
            // Check if it's actually a let statement by looking at the type_expr
            let mut inner = pair.into_inner();
            let type_or_let = inner.next().unwrap();

            // If type_expr is just "let", treat as let_statement
            if type_or_let.as_str() == "let" {
                let identifier = inner.next().unwrap().as_str();
                let value = if let Some(expr) = inner.next() {
                    eval_pair(expr, scope)?
                } else {
                    QValue::Nil(QNil)
                };
                scope.declare(identifier, value)?;
                Ok(QValue::Nil(QNil))
            } else {
                Err("Typed variable declarations not yet implemented".to_string())
            }
        }
        Rule::expression_statement => {
            // Expression statement just wraps an expression
            let inner = pair.into_inner().next().unwrap();
            eval_pair(inner, scope)
        }
        Rule::if_statement => {
            // if expression ~ statement* ~ elif_clause* ~ else_clause? ~ end
            let mut iter = pair.into_inner();
            let condition = eval_pair(iter.next().unwrap(), scope)?;

            if condition.as_bool() {
                // Execute the if block statements in a new scope
                scope.push();
                let mut result = QValue::Nil(QNil);
                for stmt_pair in iter.by_ref() {
                    if matches!(stmt_pair.as_rule(), Rule::elif_clause | Rule::else_clause) {
                        break;
                    }
                    result = eval_pair(stmt_pair, scope)?;
                }
                scope.pop();
                return Ok(result);
            }

            // Check elif/else clauses
            for pair in iter {
                match pair.as_rule() {
                    Rule::elif_clause => {
                        let mut elif_inner = pair.into_inner();
                        let elif_condition = eval_pair(elif_inner.next().unwrap(), scope)?;
                        if elif_condition.as_bool() {
                            scope.push();
                            let mut result = QValue::Nil(QNil);
                            for stmt in elif_inner {
                                result = eval_pair(stmt, scope)?;
                            }
                            scope.pop();
                            return Ok(result);
                        }
                    }
                    Rule::else_clause => {
                        scope.push();
                        let mut result = QValue::Nil(QNil);
                        for stmt in pair.into_inner() {
                            result = eval_pair(stmt, scope)?;
                        }
                        scope.pop();
                        return Ok(result);
                    }
                    _ => {}
                }
            }
            Ok(QValue::Nil(QNil))
        }
        Rule::for_statement => {
            // for identifier ~ ("," ~ identifier)? ~ "in" ~ for_range ~ statement* ~ "end"
            let mut iter = pair.into_inner();
            let first_var = iter.next().unwrap().as_str().to_string();

            // Check for second variable (for dict iteration)
            let next = iter.next().unwrap();
            let (second_var, for_range) = if next.as_rule() == Rule::identifier {
                (Some(next.as_str().to_string()), iter.next().unwrap())
            } else {
                (None, next)
            };

            // Evaluate the range/collection
            // Save the range text before consuming for_range
            let range_text = for_range.as_str().to_string();

            // for_range contains the expression(s) directly
            let range_parts: Vec<_> = for_range.into_inner().collect();

            if range_parts.len() == 1 {
                // Single expression - collection iteration
                let collection = eval_pair(range_parts[0].clone(), scope)?;

                scope.push();
                let mut result = QValue::Nil(QNil);

                match collection {
                    QValue::Array(arr) => {
                        'outer: for (index, item) in arr.elements.iter().enumerate() {
                            if let Some(ref idx_var) = second_var {
                                // for item, index in array
                                scope.set(&first_var, item.clone());
                                scope.set(idx_var, QValue::Num(QNum::new(index as f64)));
                            } else {
                                // for item in array
                                scope.set(&first_var, item.clone());
                            }

                            // Execute loop body
                            for stmt in iter.clone() {
                                match eval_pair(stmt.clone(), scope) {
                                    Ok(val) => result = val,
                                    Err(e) if e == "__LOOP_BREAK__" => break 'outer,
                                    Err(e) if e == "__LOOP_CONTINUE__" => break,
                                    Err(e) => {
                                        scope.pop();
                                        return Err(e);
                                    }
                                }
                            }
                        }
                    }
                    QValue::Dict(dict) => {
                        'outer: for (key, value) in dict.map.iter() {
                            if let Some(ref val_var) = second_var {
                                // for key, value in dict
                                scope.set(&first_var, QValue::Str(QString::new(key.clone())));
                                scope.set(val_var, value.clone());
                            } else {
                                // for key in dict
                                scope.set(&first_var, QValue::Str(QString::new(key.clone())));
                            }

                            // Execute loop body
                            for stmt in iter.clone() {
                                match eval_pair(stmt.clone(), scope) {
                                    Ok(val) => result = val,
                                    Err(e) if e == "__LOOP_BREAK__" => break 'outer,
                                    Err(e) if e == "__LOOP_CONTINUE__" => break,
                                    Err(e) => {
                                        scope.pop();
                                        return Err(e);
                                    }
                                }
                            }
                        }
                    }
                    _ => {
                        scope.pop();
                        return Err(format!("Cannot iterate over type {}", collection.as_obj().cls()));
                    }
                }

                scope.pop();
                Ok(result)
            } else {
                // Range iteration: start to/until end [step increment]
                let start_val = eval_pair(range_parts[0].clone(), scope)?;
                let end_val = eval_pair(range_parts[1].clone(), scope)?;

                let start = start_val.as_num()? as i64;
                let end = end_val.as_num()? as i64;

                // Check if this is "to" (inclusive) or "until" (exclusive) by examining the source text
                let inclusive = range_text.contains(" to ") || range_text.contains(" to\n") || range_text.contains(" to\t");

                // Parse step if present
                let step = if range_parts.len() >= 3 {
                    eval_pair(range_parts[2].clone(), scope)?.as_num()? as i64
                } else {
                    if start <= end { 1 } else { -1 }
                };

                scope.push();
                let mut result = QValue::Nil(QNil);

                let mut i = start;

                'outer: loop {
                    if step > 0 {
                        if inclusive && i > end { break; }
                        if !inclusive && i >= end { break; }
                    } else {
                        if inclusive && i < end { break; }
                        if !inclusive && i <= end { break; }
                    }

                    scope.set(&first_var, QValue::Num(QNum::new(i as f64)));

                    // Execute loop body
                    for stmt in iter.clone() {
                        match eval_pair(stmt.clone(), scope) {
                            Ok(val) => result = val,
                            Err(e) if e == "__LOOP_BREAK__" => break 'outer,
                            Err(e) if e == "__LOOP_CONTINUE__" => break,
                            Err(e) => {
                                scope.pop();
                                return Err(e);
                            }
                        }
                    }

                    i += step;
                }

                scope.pop();
                Ok(result)
            }
        }
        Rule::while_statement => {
            // while expression ~ statement* ~ "end"
            let mut iter = pair.into_inner();
            let condition_expr = iter.next().unwrap();

            // Collect the loop body statements
            let body_statements: Vec<_> = iter.collect();

            let mut result = QValue::Nil(QNil);

            'outer: loop {
                // Evaluate the condition
                let condition = eval_pair(condition_expr.clone(), scope)?;

                if !condition.as_bool() {
                    break;
                }

                // Create a new scope for each iteration
                scope.push();

                // Execute loop body
                for stmt in body_statements.iter() {
                    match eval_pair(stmt.clone(), scope) {
                        Ok(val) => result = val,
                        Err(e) if e == "__LOOP_BREAK__" => {
                            scope.pop();
                            break 'outer;
                        }
                        Err(e) if e == "__LOOP_CONTINUE__" => {
                            break;
                        }
                        Err(e) => {
                            scope.pop();
                            return Err(e);
                        }
                    }
                }

                // Pop the iteration scope
                scope.pop();
            }

            Ok(result)
        }
        Rule::expression => {
            let inner = pair.into_inner().next().unwrap();
            eval_pair(inner, scope)
        }
        Rule::lambda_expr => {
            let pair_str = pair.as_str().to_string();
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if this is a lambda (fun without name) or just a logical_or
            if first.as_rule() == Rule::parameter_list || first.as_rule() == Rule::statement {
                // This is an anonymous function: fun (params) body end
                let mut params = Vec::new();

                // Collect parameters if first was parameter_list
                if first.as_rule() == Rule::parameter_list {
                    for param in first.into_inner() {
                        let param_inner: Vec<_> = param.into_inner().collect();
                        let param_name = if param_inner.len() == 1 {
                            // Untyped: just identifier
                            param_inner[0].as_str().to_string()
                        } else {
                            // Typed: type_expr : identifier - take the identifier
                            param_inner.last().unwrap().as_str().to_string()
                        };
                        params.push(param_name);
                    }
                }

                // Extract body from the original string
                // Body is everything after "fun (...)" and before the final "end"
                let body = if let Some(fun_pos) = pair_str.find("fun") {
                    let after_fun = &pair_str[fun_pos + 3..].trim_start();
                    if let Some(paren_end) = after_fun.find(')') {
                        let after_params = &after_fun[paren_end + 1..];
                        // Remove trailing "end"
                        let trimmed = after_params.trim();
                        if trimmed.ends_with("end") {
                            trimmed[..trimmed.len() - 3].trim().to_string()
                        } else {
                            trimmed.to_string()
                        }
                    } else {
                        // No parameters case
                        let trimmed = after_fun.trim();
                        if trimmed.ends_with("end") {
                            trimmed[..trimmed.len() - 3].trim().to_string()
                        } else {
                            trimmed.to_string()
                        }
                    }
                } else {
                    String::new()
                };

                // Capture non-function variables for closure
                let closure_env = scope.to_flat_map_no_functions();
                let func = QValue::UserFun(QUserFun::with_closure(None, params, body, None, closure_env));
                Ok(func)
            } else {
                // Not a lambda, just evaluate the logical_or
                eval_pair(first, scope)
            }
        }
        Rule::logical_or => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            for next in inner {
                let right = eval_pair(next, scope)?;
                let result_bool = result.as_bool() || right.as_bool();
                result = QValue::Bool(QBool::new(result_bool));
            }
            Ok(result)
        }
        Rule::logical_and => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            for next in inner {
                let right = eval_pair(next, scope)?;
                let result_bool = result.as_bool() && right.as_bool();
                result = QValue::Bool(QBool::new(result_bool));
            }
            Ok(result)
        }
        Rule::logical_not => {
            let pair_str = pair.as_str().trim_start();
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if the source starts with "not" keyword
            if pair_str.starts_with("not") {
                // This is a negation - first child is the recursive logical_not to negate
                let value = eval_pair(first, scope)?;
                Ok(QValue::Bool(QBool::new(!value.as_bool())))
            } else {
                // No "not", first child is just bitwise_or
                eval_pair(first, scope)
            }
        }
        Rule::bitwise_or => {
            let mut inner = pair.into_inner();
            let result = eval_pair(inner.next().unwrap(), scope)?;

            // Collect remaining operations
            let remaining: Vec<_> = inner.collect();
            if remaining.is_empty() {
                // No bitwise operations, just return the value as-is
                Ok(result)
            } else {
                // Do bitwise operations with i64
                let mut int_result = result.as_num()? as i64;
                for next in remaining {
                    let right = eval_pair(next, scope)?.as_num()? as i64;
                    int_result |= right;
                }
                Ok(QValue::Num(QNum::new(int_result as f64)))
            }
        }
        Rule::bitwise_and => {
            let mut inner = pair.into_inner();
            let result = eval_pair(inner.next().unwrap(), scope)?;

            // Collect remaining operations
            let remaining: Vec<_> = inner.collect();
            if remaining.is_empty() {
                // No bitwise operations, just return the value as-is
                Ok(result)
            } else {
                // Do bitwise operations with i64
                let mut int_result = result.as_num()? as i64;
                for next in remaining {
                    let right = eval_pair(next, scope)?.as_num()? as i64;
                    int_result &= right;
                }
                Ok(QValue::Num(QNum::new(int_result as f64)))
            }
        }
        Rule::comparison => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

            while let Some(pair) = inner.next() {
                if pair.as_rule() == Rule::comparison_op {
                    let op = pair.as_str();
                    let right = eval_pair(inner.next().unwrap(), scope)?;

                    // Type-aware comparison
                    let cmp_result = match op {
                        "==" => types::values_equal(&result, &right),
                        "!=" => !types::values_equal(&result, &right),
                        "<" | ">" | "<=" | ">=" => {
                            // For ordering comparisons, use compare_values
                            match types::compare_values(&result, &right) {
                                Some(ordering) => {
                                    use std::cmp::Ordering;
                                    match op {
                                        "<" => ordering == Ordering::Less,
                                        ">" => ordering == Ordering::Greater,
                                        "<=" => ordering != Ordering::Greater,
                                        ">=" => ordering != Ordering::Less,
                                        _ => unreachable!()
                                    }
                                }
                                None => return Err(format!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls()))
                            }
                        }
                        _ => return Err(format!("Unknown comparison operator: {}", op)),
                    };
                    result = QValue::Bool(QBool::new(cmp_result));
                } else {
                    result = eval_pair(pair, scope)?;
                }
            }
            Ok(result)
        }
        Rule::concat => {
            let mut inner = pair.into_inner();
            let result = eval_pair(inner.next().unwrap(), scope)?;

            // Collect remaining parts for concatenation
            let remaining: Vec<_> = inner.collect();
            if remaining.is_empty() {
                Ok(result)
            } else {
                // Concatenate strings
                let mut concat_result = result.as_str();
                for next in remaining {
                    let right = eval_pair(next, scope)?;
                    concat_result.push_str(&right.as_str());
                }
                Ok(QValue::Str(QString::new(concat_result)))
            }
        }
        Rule::addition => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

            while let Some(pair) = inner.next() {
                if pair.as_rule() == Rule::add_op {
                    let op = pair.as_str();
                    let right = eval_pair(inner.next().unwrap(), scope)?;
                    let left_num = result.as_num()?;
                    let right_num = right.as_num()?;
                    let value = match op {
                        "+" => left_num + right_num,
                        "-" => left_num - right_num,
                        _ => return Err(format!("Unknown operator: {}", op)),
                    };
                    result = QValue::Num(QNum::new(value));
                } else {
                    result = eval_pair(pair, scope)?;
                }
            }
            Ok(result)
        }
        Rule::multiplication => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

            while let Some(pair) = inner.next() {
                if pair.as_rule() == Rule::mul_op {
                    let op = pair.as_str();
                    let right = eval_pair(inner.next().unwrap(), scope)?;
                    let left_num = result.as_num()?;
                    let right_num = right.as_num()?;
                    let value = match op {
                        "*" => left_num * right_num,
                        "/" => {
                            if right_num == 0.0 {
                                return Err("Division by zero".to_string());
                            }
                            left_num / right_num
                        }
                        "%" => left_num % right_num,
                        _ => return Err(format!("Unknown operator: {}", op)),
                    };
                    result = QValue::Num(QNum::new(value));
                } else {
                    result = eval_pair(pair, scope)?;
                }
            }
            Ok(result)
        }
        Rule::unary => {
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            if first.as_rule() == Rule::unary_op {
                let op = first.as_str();
                let value = eval_pair(inner.next().unwrap(), scope)?;
                match op {
                    "-" => Ok(QValue::Num(QNum::new(-value.as_num()?))),
                    "+" => Ok(QValue::Num(QNum::new(value.as_num()?))),
                    _ => Err(format!("Unknown unary operator: {}", op)),
                }
            } else {
                eval_pair(first, scope)
            }
        }
        Rule::postfix => {
            let pair_str = pair.as_str().to_string(); // Save before consuming
            let pair_start = pair.as_span().start(); // Get absolute start position
            let mut inner = pair.into_inner();
            let first_pair = inner.next().unwrap();

            // Track if this starts with an identifier (for module state updates)
            let _original_identifier = match first_pair.as_rule() {
                Rule::identifier => Some(first_pair.as_str().to_string()),
                Rule::primary => {
                    // Check if the primary contains just an identifier
                    let mut primary_inner = first_pair.clone().into_inner();
                    if let Some(inner_pair) = primary_inner.next() {
                        if matches!(inner_pair.as_rule(), Rule::identifier) {
                            Some(inner_pair.as_str().to_string())
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                }
                _ => None
            };

            let mut result = eval_pair(first_pair, scope)?;

            // Collect remaining pairs into a vector to allow peeking
            let pairs: Vec<_> = inner.collect();
            let mut i = 0;

            // Handle method calls, member access, and index access
            while i < pairs.len() {
                let current = &pairs[i];
                match current.as_rule() {
                    Rule::identifier => {
                        let method_name = current.as_str();

                        // To determine if this is a method call or member access, we need to check
                        // if there's a following argument_list pair, OR if the original expression
                        // had parentheses (for zero-argument calls like `.upper()`)
                        //
                        // Check the span: if the identifier is followed by () in the original string,
                        // it's a method call with zero arguments.
                        // Convert absolute span to relative position within pair_str
                        let span_end_absolute = current.as_span().end();
                        let span_end_relative = span_end_absolute - pair_start;

                        let has_parens = if let Some(remaining) = pair_str.get(span_end_relative..) {
                            remaining.trim_start().starts_with("()")
                        } else {
                            false
                        };

                        let has_args = i + 1 < pairs.len() && pairs[i + 1].as_rule() == Rule::argument_list;

                        if has_parens || has_args {
                            // METHOD CALL: either has () or has arguments
                            let (args, named_args) = if has_args {
                                let args_pair = &pairs[i + 1];
                                let args_inner: Vec<_> = args_pair.clone().into_inner().collect();

                                if args_inner.is_empty() {
                                    (Vec::new(), None)
                                } else if args_inner[0].as_rule() == Rule::named_arg {
                                    // Named arguments
                                    let mut named_args_map = HashMap::new();
                                    for arg in args_inner {
                                        let mut arg_inner = arg.into_inner();
                                        let name = arg_inner.next().unwrap().as_str().to_string();
                                        let value = eval_pair(arg_inner.next().unwrap(), scope)?;
                                        named_args_map.insert(name, value);
                                    }
                                    (Vec::new(), Some(named_args_map))
                                } else {
                                    // Positional arguments
                                    let mut args = Vec::new();
                                    for arg in args_inner {
                                        args.push(eval_pair(arg, scope)?);
                                    }
                                    (args, None)
                                }
                            } else {
                                (Vec::new(), None)
                            };

                            // Execute the method and return result
                            // Special handling for modules to persist state changes
                            if let QValue::Module(module) = &result {
                                // Check for built-in module methods first
                                if method_name == "_doc" {
                                    result = QValue::Str(QString::new(module._doc()));
                                } else if method_name == "_str" {
                                    result = QValue::Str(QString::new(module._str()));
                                } else if method_name == "_rep" {
                                    result = QValue::Str(QString::new(module._rep()));
                                } else if method_name == "_id" {
                                    result = QValue::Num(QNum::new(module._id() as f64));
                                } else {
                                    // Calling a method on a module (e.g., test.it())
                                    let func = module.get_member(method_name)
                                        .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?;

                                    match func {
                                    QValue::Fun(f) => {
                                        // Call builtin function with namespaced name to avoid conflicts
                                        let namespaced_name = if f.parent_type.is_empty() {
                                            f.name.clone()
                                        } else {
                                            format!("{}.{}", f.parent_type, f.name)
                                        };
                                        result = call_builtin_function(&namespaced_name, args, scope)?;
                                    }
                                    QValue::UserFun(user_fn) => {
                                        // Call user-defined function from module
                                        // Create a scope with:
                                        // 1. Base level: module's shared members (for module state)
                                        // 2. Add caller's scope on top (for closures to access outer variables)
                                        let mut module_scope = Scope::with_shared_base(
                                            Rc::clone(&module.members),
                                            Rc::clone(&scope.module_cache)
                                        );

                                        // Push a new scope level with caller's variables
                                        // This allows closures passed as arguments to access their captured vars
                                        module_scope.push();
                                        for (k, v) in scope.to_flat_map() {
                                            // Don't override module members
                                            if !module_scope.scopes[0].borrow().contains_key(&k) {
                                                module_scope.scopes[1].borrow_mut().insert(k, v);
                                            }
                                        }

                                        let ret = call_user_function(&user_fn, args, &mut module_scope)?;

                                        // No need to sync back module members - they're shared via Rc<RefCell<>>
                                        // Changes to module variables go directly to module.members

                                        result = ret;
                                    }
                                    _ => return Err(format!("Module member '{}' is not a function", method_name)),
                                    }
                                }
                            } else {
                                // Special handling for array higher-order functions
                                if let QValue::Array(arr) = &result {
                                    match method_name {
                                        "map" | "filter" | "each" | "reduce" | "any" | "all" | "find" | "find_index" => {
                                            result = call_array_higher_order_method(arr, method_name, args, scope)?;
                                        }
                                        _ => {
                                            result = arr.call_method(method_name, args)?;
                                        }
                                    }
                                } else if let QValue::Dict(dict) = &result {
                                    // Special handling for dict higher-order functions
                                    match method_name {
                                        "each" => {
                                            result = call_dict_higher_order_method(dict, method_name, args, scope)?;
                                        }
                                        _ => {
                                            result = dict.call_method(method_name, args)?;
                                        }
                                    }
                                } else if let QValue::Type(qtype) = &result {
                                    // Handle Type methods (constructor, static methods, built-in methods)
                                    if method_name == "new" {
                                        // Constructor call
                                        result = construct_struct(qtype, args, named_args, scope)?;
                                    } else if method_name == "_doc" {
                                        // Built-in _doc() method
                                        result = QValue::Str(QString::new(qtype._doc()));
                                    } else if method_name == "_str" {
                                        // Built-in _str() method
                                        result = QValue::Str(QString::new(qtype._str()));
                                    } else if method_name == "_rep" {
                                        // Built-in _rep() method
                                        result = QValue::Str(QString::new(qtype._rep()));
                                    } else if method_name == "_id" {
                                        // Built-in _id() method
                                        result = QValue::Num(QNum::new(qtype._id() as f64));
                                    } else if let Some(static_method) = qtype.get_static_method(method_name) {
                                        // Static method call
                                        result = call_user_function(static_method, args, scope)?;
                                    } else {
                                        return Err(format!("Type {} has no static method '{}'", qtype.name, method_name));
                                    }
                                } else if let QValue::Trait(qtrait) = &result {
                                    // Handle Trait built-in methods
                                    if method_name == "_doc" {
                                        result = QValue::Str(QString::new(qtrait._doc()));
                                    } else if method_name == "_str" {
                                        result = QValue::Str(QString::new(qtrait._str()));
                                    } else if method_name == "_rep" {
                                        result = QValue::Str(QString::new(qtrait._rep()));
                                    } else if method_name == "_id" {
                                        result = QValue::Num(QNum::new(qtrait._id() as f64));
                                    } else {
                                        return Err(format!("Trait {} has no method '{}'", qtrait.name, method_name));
                                    }
                                } else if let QValue::Struct(qstruct) = &result {
                                    // Handle built-in struct methods first
                                    if method_name == "is" {
                                        // .is(TypeName) checks if struct is instance of type
                                        // Usage: obj.is(Point) returns true/false
                                        if args.len() != 1 {
                                            return Err(format!(".is() expects 1 argument (type name), got {}", args.len()));
                                        }
                                        if let QValue::Type(check_type) = &args[0] {
                                            result = QValue::Bool(QBool::new(qstruct.type_name == check_type.name));
                                        } else {
                                            return Err(".is() argument must be a type".to_string());
                                        }
                                    } else if method_name == "does" {
                                        // .does(TraitName) checks if struct's type implements trait
                                        // Usage: obj.does(Drawable) returns true/false
                                        if args.len() != 1 {
                                            return Err(format!(".does() expects 1 argument (trait), got {}", args.len()));
                                        }
                                        if let QValue::Trait(check_trait) = &args[0] {
                                            // Look up the type to check implemented traits
                                            if let Some(QValue::Type(qtype)) = scope.get(&qstruct.type_name) {
                                                result = QValue::Bool(QBool::new(
                                                    qtype.implemented_traits.contains(&check_trait.name)
                                                ));
                                            } else {
                                                return Err(format!("Type {} not found", qstruct.type_name));
                                            }
                                        } else {
                                            return Err(".does() argument must be a trait".to_string());
                                        }
                                    } else if method_name == "update" {
                                        // .update() creates a new struct with updated fields
                                        // Usage: obj.update(field1: value1, field2: value2)
                                        if let Some(named_args_map) = named_args {
                                            let mut new_fields = qstruct.fields.clone();

                                            // Look up type to validate fields and types
                                            if let Some(QValue::Type(qtype)) = scope.get(&qstruct.type_name) {
                                                for (field_name, new_value) in named_args_map {
                                                    // Check if field exists in type
                                                    if let Some(field_def) = qtype.fields.iter().find(|f| f.name == field_name) {
                                                        // Validate type if annotation present
                                                        if let Some(ref type_annotation) = field_def.type_annotation {
                                                            validate_field_type(&new_value, type_annotation)?;
                                                        }
                                                        new_fields.insert(field_name, new_value);
                                                    } else {
                                                        return Err(format!("Type {} has no field '{}'", qstruct.type_name, field_name));
                                                    }
                                                }
                                                result = QValue::Struct(QStruct::new(qstruct.type_name.clone(), qtype.id, new_fields));
                                            } else {
                                                return Err(format!("Type {} not found", qstruct.type_name));
                                            }
                                        } else {
                                            return Err(".update() requires named arguments".to_string());
                                        }
                                    } else {
                                        // Handle user-defined instance methods
                                        // First, look up the type to find the method
                                        if let Some(QValue::Type(qtype)) = scope.get(&qstruct.type_name) {
                                            if let Some(method) = qtype.get_method(method_name) {
                                                // Bind 'self' to the struct and call method
                                                scope.push();
                                                scope.declare("self", result.clone())?;
                                                result = call_user_function(method, args, scope)?;
                                                scope.pop();
                                            } else {
                                                return Err(format!("Struct {} has no method '{}'", qstruct.type_name, method_name));
                                            }
                                        } else {
                                            return Err(format!("Type {} not found", qstruct.type_name));
                                        }
                                    }
                                } else {
                                    result = match &result {
                                        QValue::Num(n) => n.call_method(method_name, args)?,
                                        QValue::Bool(b) => b.call_method(method_name, args)?,
                                        QValue::Str(s) => s.call_method(method_name, args)?,
                                        QValue::Fun(f) => f.call_method(method_name, args)?,
                                        QValue::UserFun(uf) => uf.call_method(method_name, args)?,
                                        QValue::Dict(d) => d.call_method(method_name, args)?,
                                        QValue::Exception(e) => e.call_method(method_name, args)?,
                                        QValue::Timestamp(ts) => ts.call_method(method_name, args)?,
                                        QValue::Zoned(z) => z.call_method(method_name, args)?,
                                        QValue::Date(d) => d.call_method(method_name, args)?,
                                        QValue::Time(t) => t.call_method(method_name, args)?,
                                        QValue::Span(s) => s.call_method(method_name, args)?,
                                        _ => return Err(format!("Type {} does not support method calls", result.as_obj().cls())),
                                    };
                                }
                            }
                            i += if has_args { 2 } else { 1 }; // Skip identifier and optionally argument_list
                        } else {
                            // MEMBER ACCESS: no parentheses and no arguments
                            // Special handling for modules
                            if let QValue::Module(module) = &result {
                                // Access module member - functions already have module_scope set
                                result = module.get_member(method_name)
                                    .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?;
                                i += 1;
                            } else if let QValue::Struct(qstruct) = &result {
                                // Access struct field
                                result = qstruct.get_field(method_name)
                                    .ok_or_else(|| format!("Struct {} has no field '{}'", qstruct.type_name, method_name))?
                                    .clone();
                                i += 1;
                            } else {
                                // Return a QFun object representing the method
                                let parent_type = result.as_obj().cls();
                                let doc = get_method_doc(&parent_type, method_name);
                                result = QValue::Fun(QFun::new(
                                    method_name.to_string(),
                                    parent_type,
                                    doc
                                ));
                                i += 1; // Skip just identifier
                            }
                        }
                    }
                    Rule::index_access => {
                        // Array or dict index access: arr[0] or dict["key"]
                        // For now, just support single index for arrays
                        let mut index_inner = current.clone().into_inner();
                        let index_expr = index_inner.next().unwrap();
                        let index_value = eval_pair(index_expr, scope)?;

                        // Check if there are multiple indices (for 2D arrays)
                        if index_inner.next().is_some() {
                            return Err("Multi-dimensional array access not yet implemented".to_string());
                        }

                        match &result {
                            QValue::Array(arr) => {
                                let index = index_value.as_num()? as i64;
                                let len = arr.len() as i64;

                                // Support negative indexing
                                let actual_index = if index < 0 {
                                    (len + index) as usize
                                } else {
                                    index as usize
                                };

                                result = arr.get(actual_index)
                                    .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, arr.len()))?
                                    .clone();
                                i += 1;
                            }
                            QValue::Dict(dict) => {
                                let key = index_value.as_str();
                                result = dict.get(&key)
                                    .cloned()
                                    .unwrap_or(QValue::Nil(QNil));
                                i += 1;
                            }
                            _ => {
                                return Err(format!("Cannot index into type {}", result.as_obj().cls()));
                            }
                        }
                    }
                    _ => {
                        return Err(format!("Unsupported postfix operation: {:?}", current.as_rule()));
                    }
                }
            }

            Ok(result)
        }
        Rule::primary => {
            let pair_str = pair.as_str();

            // Check if this is "self" keyword
            if pair_str == "self" {
                return scope.get("self")
                    .ok_or_else(|| "'self' is only valid inside methods".to_string());
            }

            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if this is a function call: identifier followed by argument_list or ()
            if first.as_rule() == Rule::identifier {
                let func_name = first.as_str();

                // Check if this is a constructor call: TypeName.new(...)
                // Only handle simple TypeName.new(), not module.Type.new() which is handled by postfix
                // Check that .new( immediately follows the identifier (not in a string literal later)
                let is_constructor_call = !func_name.contains('.') &&
                    pair_str.trim_start().starts_with(func_name) &&
                    pair_str[func_name.len()..].trim_start().starts_with(".new(");

                if is_constructor_call {
                    // This is TypeName.new(...) constructor
                    if let Some(QValue::Type(qtype)) = scope.get(func_name) {
                        // Parse arguments - check if named or positional
                        if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                let args_inner: Vec<_> = args_pair.into_inner().collect();

                                if args_inner.is_empty() {
                                    // No arguments
                                    return construct_struct(&qtype, Vec::new(), None, scope);
                                }

                                // Check if first argument is a named_arg
                                if args_inner[0].as_rule() == Rule::named_arg {
                                    // Named arguments
                                    let mut named_args = HashMap::new();
                                    for arg in args_inner {
                                        let mut arg_inner = arg.into_inner();
                                        let name = arg_inner.next().unwrap().as_str().to_string();
                                        let value = eval_pair(arg_inner.next().unwrap(), scope)?;
                                        named_args.insert(name, value);
                                    }
                                    return construct_struct(&qtype, Vec::new(), Some(named_args), scope);
                                } else {
                                    // Positional arguments
                                    let mut args = Vec::new();
                                    for arg in args_inner {
                                        args.push(eval_pair(arg, scope)?);
                                    }
                                    return construct_struct(&qtype, args, None, scope);
                                }
                            }
                        }
                        // No arguments
                        return construct_struct(&qtype, Vec::new(), None, scope);
                    } else {
                        return Err(format!("Type {} not defined", func_name));
                    }
                }

                // Check if there's an argument_list following, or if the source has ()
                let has_args = if let Some(args_pair) = inner.clone().next() {
                    args_pair.as_rule() == Rule::argument_list
                } else {
                    false
                };

                // Check if source has () after identifier (for zero-argument calls)
                let has_parens = pair_str.trim_start().starts_with(func_name) &&
                    pair_str[func_name.len()..].trim_start().starts_with("(");

                if has_args || has_parens {
                    // This is a function call
                    let mut args = Vec::new();
                    if has_args {
                        let args_pair = inner.next().unwrap();
                        for arg in args_pair.into_inner() {
                            args.push(eval_pair(arg, scope)?);
                        }
                    }

                    // Check if it's a user-defined function
                    if let Some(func_value) = scope.get(func_name) {
                        if let QValue::UserFun(user_fun) = func_value {
                            return call_user_function(&user_fun, args, scope);
                        }
                    }

                    return call_builtin_function(func_name, args, scope);
                }

                // Just a bare identifier (variable reference)
                return scope.get(func_name)
                    .ok_or_else(|| format!("Undefined variable: {}", func_name));
            }

            // Otherwise, evaluate the inner expression
            eval_pair(first, scope)
        }
        Rule::number => {
            let value = pair.as_str()
                .parse::<f64>()
                .map_err(|e| format!("Invalid number: {}", e))?;
            Ok(QValue::Num(QNum::new(value)))
        }
        Rule::array_literal => {
            // [expression, expression, ...]
            let inner = pair.into_inner();

            // Check if we have array_elements
            let elements_pair = inner.clone().next();
            if elements_pair.is_none() {
                // Empty array []
                return Ok(QValue::Array(QArray::new(Vec::new())));
            }

            let elements_pair = elements_pair.unwrap();
            if elements_pair.as_rule() != Rule::array_elements {
                // Empty array
                return Ok(QValue::Array(QArray::new(Vec::new())));
            }

            // Parse array elements
            let mut elements = Vec::new();
            for element in elements_pair.into_inner() {
                if element.as_rule() == Rule::array_row {
                    // 2D array syntax - not yet supported
                    return Err("2D arrays not yet implemented".to_string());
                } else {
                    // Regular expression
                    elements.push(eval_pair(element, scope)?);
                }
            }

            Ok(QValue::Array(QArray::new(elements)))
        }
        Rule::dict_literal => {
            // {key: value, key: value, ...}
            let inner = pair.into_inner();
            let mut map = std::collections::HashMap::new();

            for dict_pair in inner {
                if dict_pair.as_rule() == Rule::dict_pair {
                    let mut parts = dict_pair.into_inner();
                    let key_part = parts.next().unwrap();
                    let value_part = parts.next().unwrap();

                    // Key can be identifier or string
                    let key = match key_part.as_rule() {
                        Rule::identifier => key_part.as_str().to_string(),
                        Rule::string => {
                            // Evaluate string (handles both plain and interpolated)
                            match eval_pair(key_part, scope)? {
                                QValue::Str(s) => s.value,
                                _ => return Err("Dict key must be a string".to_string())
                            }
                        }
                        _ => return Err(format!("Invalid dict key type: {:?}", key_part.as_rule()))
                    };

                    let value = eval_pair(value_part, scope)?;
                    map.insert(key, value);
                }
            }

            Ok(QValue::Dict(QDict::new(map)))
        }
        Rule::literal => {
            let inner = pair.into_inner().next().unwrap();
            eval_pair(inner, scope)
        }
        Rule::boolean => {
            match pair.as_str() {
                "true" => Ok(QValue::Bool(QBool::new(true))),
                "false" => Ok(QValue::Bool(QBool::new(false))),
                _ => Err("Invalid boolean".to_string()),
            }
        }
        Rule::nil => {
            Ok(QValue::Nil(QNil))
        }
        Rule::string => {
            // String can be either fstring or plain_string
            let mut inner = pair.into_inner();
            if let Some(string_pair) = inner.next() {
                match string_pair.as_rule() {
                    Rule::plain_string => {
                        // Plain string (no interpolation) - single or multi-line
                        let s = string_pair.as_str();
                        let unquoted = if s.starts_with("\"\"\"") {
                            // Multi-line string
                            s[3..s.len()-3].to_string()
                        } else {
                            // Single-line string - remove quotes and process escapes
                            process_escape_sequences(&s[1..s.len()-1])
                        };
                        Ok(QValue::Str(QString::new(unquoted)))
                    }
                    Rule::fstring => {
                        // F-string with interpolation
                        let mut result = String::new();
                        for part in string_pair.into_inner() {
                            match part.as_rule() {
                                Rule::interpolation => {
                                    // Extract variable name and optional format spec
                                    let mut interp_inner = part.into_inner();
                                    let var_name = interp_inner.next().unwrap().as_str();
                                    let format_spec = interp_inner.next().map(|p| p.as_str());

                                    // Look up variable in scope
                                    let value = scope.get(var_name)
                                        .ok_or_else(|| format!("Undefined variable: {}", var_name))?;

                                    // Format the value
                                    let formatted = if let Some(spec) = format_spec {
                                        format_value(&value, spec)?
                                    } else {
                                        value.as_str()
                                    };
                                    result.push_str(&formatted);
                                }
                                Rule::fstring_char => {
                                    let ch = part.as_str();
                                    result.push_str(&process_escape_sequences(ch));
                                }
                                _ => {}
                            }
                        }
                        Ok(QValue::Str(QString::new(result)))
                    }
                    _ => Err(format!("Unexpected string type: {:?}", string_pair.as_rule()))
                }
            } else {
                Err("Empty string rule".to_string())
            }
        }
        Rule::return_statement => {
            // Return statement: return expression?
            let mut inner = pair.into_inner();
            if let Some(expr) = inner.next() {
                eval_pair(expr, scope)
            } else {
                Ok(QValue::Nil(QNil))
            }
        }
        Rule::break_statement => {
            // Break out of the current loop - signal with special error
            Err("__LOOP_BREAK__".to_string())
        }
        Rule::continue_statement => {
            // Continue to next iteration - signal with special error
            Err("__LOOP_CONTINUE__".to_string())
        }
        Rule::raise_statement => {
            // raise expression or bare raise for re-raising
            let mut inner = pair.into_inner();

            if let Some(expr_pair) = inner.next() {
                // raise with expression
                let value = eval_pair(expr_pair, scope)?;

                match value {
                    QValue::Str(s) => {
                        // Simple string: raise "error message"
                        return Err(format!("Error: {}", s.value));
                    }
                    QValue::Exception(e) => {
                        // Exception object: raise ValueError("msg")
                        return Err(format!("{}: {}", e.exception_type, e.message));
                    }
                    QValue::Struct(s) => {
                        // Custom exception type (user-defined struct)
                        let msg = s.fields.get("message")
                            .map(|v| v.as_str())
                            .unwrap_or_else(|| "No message".to_string());
                        return Err(format!("{}: {}", s.type_name, msg));
                    }
                    _ => {
                        return Err(format!("Can only raise string, exception, or struct types, got {}", value.as_obj().cls()));
                    }
                }
            } else {
                // Bare raise - re-raise current exception
                if let Some(exc) = &scope.current_exception {
                    return Err(format!("{}: {}", exc.exception_type, exc.message));
                } else {
                    return Err("No active exception to re-raise".to_string());
                }
            }
        }
        Rule::try_statement => {
            // try statement* catch_clause+ ensure_clause? end
            // or: try statement* ensure_clause end
            let inner = pair.into_inner();

            let mut try_body = Vec::new();
            let mut catch_clauses = Vec::new();
            let mut ensure_block = None;

            // Parse all the parts
            for part in inner {
                match part.as_rule() {
                    Rule::catch_clause => {
                        let mut catch_inner = part.into_inner();
                        let var_name = catch_inner.next().unwrap().as_str().to_string();

                        // Check if there's a type filter
                        let mut exception_type = None;
                        let mut body = Vec::new();

                        for item in catch_inner {
                            if item.as_rule() == Rule::type_expr {
                                exception_type = Some(item.as_str().to_string());
                            } else {
                                body.push(item);
                            }
                        }

                        catch_clauses.push((var_name, exception_type, body));
                    }
                    Rule::ensure_clause => {
                        let statements: Vec<_> = part.into_inner().collect();
                        ensure_block = Some(statements);
                    }
                    Rule::statement => {
                        try_body.push(part);
                    }
                    _ => {}
                }
            }

            // Execute try block
            let try_result: Result<QValue, String> = (|| {
                let mut last_value = QValue::Nil(QNil);
                for stmt in try_body {
                    last_value = eval_pair(stmt, scope)?;
                }
                Ok(last_value)
            })();

            let final_result = match try_result {
                Err(error_msg) => {
                    // Parse the error message to extract exception type
                    let (exc_type, exc_msg) = if let Some(colon_pos) = error_msg.find(": ") {
                        (error_msg[..colon_pos].to_string(), error_msg[colon_pos + 2..].to_string())
                    } else {
                        ("Error".to_string(), error_msg.clone())
                    };

                    // Create exception and populate stack trace from current call stack
                    let mut exception = QException::new(exc_type.clone(), exc_msg, None, None);
                    exception.stack = scope.get_stack_trace();
                    scope.current_exception = Some(exception.clone());

                    // Clear the call stack now that we've captured it in the exception
                    scope.call_stack.clear();

                    // Try each catch clause
                    let mut caught = false;
                    let mut catch_result = Ok(QValue::Nil(QNil));

                    for (var_name, exception_type_filter, body) in catch_clauses {
                        // Check if this catch clause matches the exception type
                        let matches = if let Some(ref expected_type) = exception_type_filter {
                            exc_type == *expected_type
                        } else {
                            true // catch-all
                        };

                        if matches {
                            // Bind exception to variable
                            scope.declare(&var_name, QValue::Exception(exception.clone()))?;

                            // Execute catch block
                            caught = true;
                            for stmt in body {
                                catch_result = eval_pair(stmt, scope);
                                if catch_result.is_err() {
                                    break;
                                }
                            }
                            break;
                        }
                    }

                    if !caught {
                        // No catch matched - re-throw
                        catch_result = Err(error_msg);
                    }

                    catch_result
                }
                Ok(val) => Ok(val),
            };

            // Always execute ensure block
            if let Some(ensure_stmts) = ensure_block {
                for stmt in ensure_stmts {
                    eval_pair(stmt, scope)?;
                }
            }

            // Clear current exception
            scope.current_exception = None;

            final_result
        }
        _ => Err(format!("Unsupported rule: {:?}", pair.as_rule())),
    }
}

// Format a value according to a Rust-style format specification
fn format_value(value: &QValue, spec: &str) -> Result<String, String> {
    // Parse format spec: [fill][align][sign][#][0][width][.precision][type]
    let mut fill = ' ';
    let mut align = '>'; // default right-align for numbers
    let mut sign = '-';
    let mut alternate = false;
    let mut _zero_pad = false;
    let mut width: Option<usize> = None;
    let mut precision: Option<usize> = None;
    let mut format_type = "";

    let chars: Vec<char> = spec.chars().collect();
    let mut i = 0;

    // Check for fill+align (must be first if present)
    if chars.len() >= 2 && (chars[1] == '<' || chars[1] == '>' || chars[1] == '^') {
        fill = chars[0];
        align = chars[1];
        i = 2;
    } else if chars.len() >= 1 && (chars[0] == '<' || chars[0] == '>' || chars[0] == '^') {
        align = chars[0];
        i = 1;
    }

    // Check for sign
    if i < chars.len() && (chars[i] == '+' || chars[i] == '-' || chars[i] == ' ') {
        sign = chars[i];
        i += 1;
    }

    // Check for alternate form (#)
    if i < chars.len() && chars[i] == '#' {
        alternate = true;
        i += 1;
    }

    // Check for zero padding
    if i < chars.len() && chars[i] == '0' {
        _zero_pad = true;
        fill = '0';
        i += 1;
    }

    // Parse width
    let mut width_str = String::new();
    while i < chars.len() && chars[i].is_ascii_digit() {
        width_str.push(chars[i]);
        i += 1;
    }
    if !width_str.is_empty() {
        width = Some(width_str.parse().unwrap());
    }

    // Parse precision
    if i < chars.len() && chars[i] == '.' {
        i += 1;
        let mut prec_str = String::new();
        while i < chars.len() && chars[i].is_ascii_digit() {
            prec_str.push(chars[i]);
            i += 1;
        }
        if !prec_str.is_empty() {
            precision = Some(prec_str.parse().unwrap());
        }
    }

    // Parse format type (rest of string)
    if i < chars.len() {
        format_type = &spec[i..];
    }

    // Format the value based on type
    let formatted = match value {
        QValue::Num(n) => {
            let num = n.value;
            let base_str = match format_type {
                "x" => format!("{:x}", num as i64),
                "X" => format!("{:X}", num as i64),
                "b" => format!("{:b}", num as i64),
                "o" => format!("{:o}", num as i64),
                "e" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$e}", num, prec = prec)
                    } else {
                        format!("{:e}", num)
                    }
                }
                "E" => {
                    if let Some(prec) = precision {
                        format!("{:.prec$E}", num, prec = prec)
                    } else {
                        format!("{:E}", num)
                    }
                }
                _ => {
                    // Default number formatting
                    if let Some(prec) = precision {
                        format!("{:.prec$}", num, prec = prec)
                    } else {
                        format!("{}", num)
                    }
                }
            };

            // Add alternate form prefix if requested
            let mut result = if alternate {
                match format_type {
                    "x" | "X" => format!("0x{}", base_str),
                    "b" => format!("0b{}", base_str),
                    "o" => format!("0o{}", base_str),
                    _ => base_str,
                }
            } else {
                base_str
            };

            // Add sign if requested
            if sign == '+' && num >= 0.0 {
                result = format!("+{}", result);
            } else if sign == ' ' && num >= 0.0 {
                result = format!(" {}", result);
            }

            result
        }
        QValue::Str(s) => {
            if let Some(prec) = precision {
                s.value[..prec.min(s.value.len())].to_string()
            } else {
                s.value.clone()
            }
        }
        QValue::Bool(b) => b.value.to_string(),
        QValue::Nil(_) => "nil".to_string(),
        _ => value.as_str(),
    };

    // Apply width and alignment
    if let Some(w) = width {
        if formatted.len() < w {
            let padding = w - formatted.len();
            let result = match align {
                '<' => format!("{}{}", formatted, fill.to_string().repeat(padding)),
                '>' => format!("{}{}", fill.to_string().repeat(padding), formatted),
                '^' => {
                    let left_pad = padding / 2;
                    let right_pad = padding - left_pad;
                    format!("{}{}{}",
                        fill.to_string().repeat(left_pad),
                        formatted,
                        fill.to_string().repeat(right_pad))
                }
                _ => formatted,
            };
            Ok(result)
        } else {
            Ok(formatted)
        }
    } else {
        Ok(formatted)
    }
}

// Parse a string literal, removing quotes and handling escape sequences
fn parse_string(s: &str) -> String {
    // Remove quotes from string literal
    if s.starts_with("\"\"\"") && s.ends_with("\"\"\"") {
        // Multi-line string
        s[3..s.len()-3].to_string()
    } else if s.starts_with("\"") && s.ends_with("\"") {
        // Single-line string, process escape sequences
        let inner = &s[1..s.len()-1];
        process_escape_sequences(inner)
    } else {
        s.to_string()
    }
}

fn process_escape_sequences(s: &str) -> String {
    let mut result = String::new();
    let mut chars = s.chars();
    while let Some(c) = chars.next() {
        if c == '\\' {
            if let Some(next) = chars.next() {
                match next {
                    'n' => result.push('\n'),
                    't' => result.push('\t'),
                    'r' => result.push('\r'),
                    '\\' => result.push('\\'),
                    '"' => result.push('"'),
                    _ => {
                        result.push('\\');
                        result.push(next);
                    }
                }
            }
        } else {
            result.push(c);
        }
    }
    result
}

/// Construct a struct instance from a type
fn construct_struct(qtype: &QType, args: Vec<QValue>, named_args: Option<HashMap<String, QValue>>, _scope: &mut Scope) -> Result<QValue, String> {
    let mut fields = HashMap::new();

    // Handle named arguments if provided
    if let Some(named_args) = named_args {
        for field_def in &qtype.fields {
            if let Some(value) = named_args.get(&field_def.name) {
                // Validate type if annotation present
                if let Some(ref type_annotation) = field_def.type_annotation {
                    validate_field_type(&value, type_annotation)?;
                }
                fields.insert(field_def.name.clone(), value.clone());
            } else if field_def.optional {
                fields.insert(field_def.name.clone(), QValue::Nil(QNil));
            } else {
                return Err(format!("Required field '{}' not provided for type {}", field_def.name, qtype.name));
            }
        }
        return Ok(QValue::Struct(QStruct::new(qtype.name.clone(), qtype.id, fields)));
    }

    // Handle positional arguments
    if args.is_empty() {
        // No arguments - initialize all fields to nil if optional, error if required
        for field_def in &qtype.fields {
            if field_def.optional {
                fields.insert(field_def.name.clone(), QValue::Nil(QNil));
            } else {
                return Err(format!("Required field '{}' not provided for type {}", field_def.name, qtype.name));
            }
        }
    } else if args.len() == 1 {
        // Check if single argument is a dict (named arguments)
        if let QValue::Dict(dict) = &args[0] {
            // Named arguments via dict
            for field_def in &qtype.fields {
                if let Some(value) = dict.get(&field_def.name) {
                    // Validate type if annotation present
                    if let Some(ref type_annotation) = field_def.type_annotation {
                        validate_field_type(&value, type_annotation)?;
                    }
                    fields.insert(field_def.name.clone(), value.clone());
                } else if field_def.optional {
                    fields.insert(field_def.name.clone(), QValue::Nil(QNil));
                } else {
                    return Err(format!("Required field '{}' not provided for type {}", field_def.name, qtype.name));
                }
            }
        } else {
            // Single positional argument
            if qtype.fields.is_empty() {
                return Err(format!("Type {} has no fields, but got 1 argument", qtype.name));
            }

            // Check if we have exactly 1 required field, or 1+ fields where only first is required
            let required_count = qtype.fields.iter().filter(|f| !f.optional).count();
            if required_count > 1 {
                return Err(format!("Type {} requires {} arguments, got 1", qtype.name, required_count));
            }

            let field_def = &qtype.fields[0];
            if let Some(ref type_annotation) = field_def.type_annotation {
                validate_field_type(&args[0], type_annotation)?;
            }
            fields.insert(field_def.name.clone(), args[0].clone());

            // Fill remaining optional fields with nil
            for field_def in &qtype.fields[1..] {
                fields.insert(field_def.name.clone(), QValue::Nil(QNil));
            }
        }
    } else {
        // Multiple positional arguments
        if args.len() != qtype.fields.len() {
            // Check if extra args can be skipped (optional fields)
            let required_count = qtype.fields.iter().filter(|f| !f.optional).count();
            if args.len() < required_count {
                return Err(format!("Type {} requires at least {} arguments, got {}", qtype.name, required_count, args.len()));
            }
            if args.len() > qtype.fields.len() {
                return Err(format!("Type {} expects at most {} arguments, got {}", qtype.name, qtype.fields.len(), args.len()));
            }
        }

        for (i, field_def) in qtype.fields.iter().enumerate() {
            if i < args.len() {
                // Validate type if annotation present
                if let Some(ref type_annotation) = field_def.type_annotation {
                    validate_field_type(&args[i], type_annotation)?;
                }
                fields.insert(field_def.name.clone(), args[i].clone());
            } else if field_def.optional {
                fields.insert(field_def.name.clone(), QValue::Nil(QNil));
            } else {
                return Err(format!("Required field '{}' not provided for type {}", field_def.name, qtype.name));
            }
        }
    }

    Ok(QValue::Struct(QStruct::new(qtype.name.clone(), qtype.id, fields)))
}

/// Validate that a value matches a type annotation
fn validate_field_type(value: &QValue, type_annotation: &str) -> Result<(), String> {
    let matches = match type_annotation {
        "num" => matches!(value, QValue::Num(_)),
        "str" => matches!(value, QValue::Str(_)),
        "bool" => matches!(value, QValue::Bool(_)),
        "array" => matches!(value, QValue::Array(_)),
        "dict" => matches!(value, QValue::Dict(_)),
        "nil" => matches!(value, QValue::Nil(_)),
        _ => true, // Unknown types pass validation (duck typing)
    };

    if matches {
        Ok(())
    } else {
        Err(format!("Type mismatch: expected {}, got {}", type_annotation, value.as_obj().cls()))
    }
}

fn call_user_function(user_fun: &QUserFun, args: Vec<QValue>, parent_scope: &mut Scope) -> Result<QValue, String> {
    // Check parameter count
    if args.len() != user_fun.params.len() {
        return Err(format!(
            "Function {} expects {} arguments, got {}",
            user_fun.name.as_ref().unwrap_or(&"<anonymous>".to_string()),
            user_fun.params.len(),
            args.len()
        ));
    }

    // If this function has a module scope, use it (like we do for direct module calls)
    // Otherwise, use the parent scope normally
    let mut execution_scope;
    let scope_to_use: &mut Scope = if let Some(ref module_scope) = user_fun.module_scope {
        // Function came from a module - create a scope with module's shared base
        // Module functions are completely isolated and only have access to:
        // 1. Module members (in scopes[0], the shared base)
        // 2. Their parameters
        // 3. Their local variables
        execution_scope = Scope::with_shared_base(
            Rc::clone(module_scope),
            Rc::clone(&parent_scope.module_cache)
        );

        // Push a new scope level for function execution
        execution_scope.push();

        // Push stack frame for exception tracking
        let func_name = user_fun.name.clone().unwrap_or_else(|| "<anonymous>".to_string());
        execution_scope.push_stack_frame(StackFrame::new(func_name));

        &mut execution_scope
    } else {
        // Regular function - use parent scope
        parent_scope.push_stack_frame(StackFrame::new(
            user_fun.name.clone().unwrap_or_else(|| "<anonymous>".to_string())
        ));

        // Create closure scope if we have captured variables
        if let Some(ref closure_env) = user_fun.closure_env {
            parent_scope.push();
            let closure_scope = parent_scope.scopes.last().unwrap();
            for (var_name, var_value) in closure_env.iter() {
                closure_scope.borrow_mut().insert(var_name.clone(), var_value.clone());
            }
        }

        // Now push the actual function execution scope
        parent_scope.push();

        parent_scope
    };

    // Bind parameters to arguments in the function execution scope
    let current_scope = scope_to_use.scopes.last().unwrap();
    for (param_name, arg_value) in user_fun.params.iter().zip(args.iter()) {
        current_scope.borrow_mut().insert(param_name.clone(), arg_value.clone());
    }

    // Parse and evaluate the body
    let pairs = QuestParser::parse(Rule::program, &user_fun.body)
        .map_err(|e| format!("Parse error in function body: {}", e))?;

    let mut result = QValue::Nil(QNil);
    for pair in pairs {
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }

            // Evaluate statement - if it fails, stack frame will be in call_stack
            match eval_pair(statement, scope_to_use) {
                Ok(val) => result = val,
                Err(e) => {
                    // Pop function execution scope
                    scope_to_use.pop();
                    // Pop closure scope if it exists
                    if user_fun.module_scope.is_none() && user_fun.closure_env.is_some() {
                        scope_to_use.pop();
                    }
                    return Err(e);
                }
            }

            // Check for early return (not implemented yet - would need return statement handling)
        }
    }

    // Pop function execution scope
    scope_to_use.pop();
    // Pop closure scope if it exists (for non-module functions)
    if user_fun.module_scope.is_none() && user_fun.closure_env.is_some() {
        scope_to_use.pop();
    }
    scope_to_use.pop_stack_frame();

    Ok(result)
}

fn call_array_higher_order_method(arr: &QArray, method_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, String> {
    match method_name {
        "map" => {
            // map(fn) - Transform each element
            if args.len() != 1 {
                return Err(format!("map expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("map expects a function argument".to_string())
                };
                new_elements.push(result);
            }
            Ok(QValue::Array(QArray::new(new_elements)))
        }
        "filter" => {
            // filter(fn) - Select elements matching predicate
            if args.len() != 1 {
                return Err(format!("filter expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("filter expects a function argument".to_string())
                };

                if result.as_bool() {
                    new_elements.push(elem.clone());
                }
            }
            Ok(QValue::Array(QArray::new(new_elements)))
        }
        "each" => {
            // each(fn) - Iterate over elements (for side effects)
            if args.len() != 1 {
                return Err(format!("each expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (idx, elem) in arr.elements.iter().enumerate() {
                match func {
                    QValue::UserFun(user_fn) => {
                        // Call with element and index
                        if user_fn.params.len() == 1 {
                            call_user_function(user_fn, vec![elem.clone()], scope)?;
                        } else if user_fn.params.len() == 2 {
                            call_user_function(user_fn, vec![elem.clone(), QValue::Num(QNum::new(idx as f64))], scope)?;
                        } else {
                            return Err("each function must accept 1 or 2 parameters (element, index)".to_string());
                        }
                    }
                    _ => return Err("each expects a function argument".to_string())
                };
            }
            Ok(QValue::Nil(QNil))
        }
        "reduce" => {
            // reduce(fn, initial) - Reduce to single value
            if args.len() != 2 {
                return Err(format!("reduce expects 2 arguments (function, initial), got {}", args.len()));
            }
            let func = &args[0];
            let mut accumulator = args[1].clone();

            for elem in &arr.elements {
                accumulator = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![accumulator, elem.clone()], scope)?
                    }
                    _ => return Err("reduce expects a function argument".to_string())
                };
            }
            Ok(accumulator)
        }
        "any" => {
            // any(fn) - Check if any element matches
            if args.len() != 1 {
                return Err(format!("any expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("any expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(QValue::Bool(QBool::new(true)));
                }
            }
            Ok(QValue::Bool(QBool::new(false)))
        }
        "all" => {
            // all(fn) - Check if all elements match
            if args.len() != 1 {
                return Err(format!("all expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("all expects a function argument".to_string())
                };

                if !result.as_bool() {
                    return Ok(QValue::Bool(QBool::new(false)));
                }
            }
            Ok(QValue::Bool(QBool::new(true)))
        }
        "find" => {
            // find(fn) - Find first matching element
            if args.len() != 1 {
                return Err(format!("find expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("find expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(elem.clone());
                }
            }
            Ok(QValue::Nil(QNil))
        }
        "find_index" => {
            // find_index(fn) - Find index of first match
            if args.len() != 1 {
                return Err(format!("find_index expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (idx, elem) in arr.elements.iter().enumerate() {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_function(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("find_index expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(QValue::Num(QNum::new(idx as f64)));
                }
            }
            Ok(QValue::Num(QNum::new(-1.0)))
        }
        _ => Err(format!("Unknown array higher-order method: {}", method_name))
    }
}

fn call_dict_higher_order_method(dict: &QDict, method_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, String> {
    match method_name {
        "each" => {
            // each(fn) - Iterate over key-value pairs
            if args.len() != 1 {
                return Err(format!("each expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (key, value) in &dict.map {
                match func {
                    QValue::UserFun(user_fn) => {
                        // Call with key and value
                        if user_fn.params.len() == 2 {
                            call_user_function(user_fn, vec![QValue::Str(QString::new(key.clone())), value.clone()], scope)?;
                        } else {
                            return Err("dict.each function must accept 2 parameters (key, value)".to_string());
                        }
                    }
                    _ => return Err("each expects a function argument".to_string())
                };
            }
            Ok(QValue::Nil(QNil))
        }
        _ => Err(format!("Unknown dict higher-order method: {}", method_name))
    }
}

fn call_builtin_function(func_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "sys.load_module" => {
            if args.len() != 1 {
                return Err(format!("sys.load_module expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();

            // Resolve path (handle relative paths)
            let resolved_path = if std::path::Path::new(&path).is_absolute() {
                path.to_string()
            } else {
                // Resolve relative to current working directory
                std::env::current_dir()
                    .map_err(|e| format!("Cannot get current directory: {}", e))?
                    .join(&path)
                    .to_string_lossy()
                    .to_string()
            };

            // Canonicalize path for security (prevents directory traversal)
            let canonical_path = std::path::Path::new(&resolved_path)
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
                let module_name = std::path::Path::new(&canonical_path)
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
            // Exit the program with the specified status code
            let exit_code = if args.is_empty() {
                0
            } else if args.len() == 1 {
                args[0].as_num()? as i32
            } else {
                return Err(format!("sys.exit expects 0 or 1 arguments, got {}", args.len()));
            };
            std::process::exit(exit_code);
        }
        "time.ticks_ms" => {
            // Return milliseconds elapsed since program start
            if !args.is_empty() {
                return Err(format!("time.ticks_ms() expects 0 arguments, got {}", args.len()));
            }
            let elapsed = get_start_time().elapsed().as_millis() as f64;
            Ok(QValue::Num(QNum::new(elapsed)))
        }
        "puts" => {
            // Print each argument using _str() method
            for arg in &args {
                print!("{}", arg.as_str());
            }
            println!(); // Add newline at the end
            // puts returns nil
            Ok(QValue::Nil(QNil))
        }
        "print" => {
            // Print without newline
            for arg in &args {
                print!("{}", arg.as_str());
            }
            Ok(QValue::Nil(QNil))
        }
        // Math stdlib functions (single argument)
        "math.sin" | "math.cos" | "math.tan" | "math.asin" | "math.acos" | "math.atan" |
        "math.abs" | "math.sqrt" | "math.ln" | "math.log10" | "math.exp" |
        "math.floor" | "math.ceil" => {
            if args.len() != 1 {
                return Err(format!("{} expects 1 argument, got {}", func_name, args.len()));
            }
            let value = args[0].as_num()?;
            let result = match func_name.trim_start_matches("math.") {
                "sin" => value.sin(),
                "cos" => value.cos(),
                "tan" => value.tan(),
                "asin" => value.asin(),
                "acos" => value.acos(),
                "atan" => value.atan(),
                "abs" => value.abs(),
                "sqrt" => value.sqrt(),
                "ln" => value.ln(),
                "log10" => value.log10(),
                "exp" => value.exp(),
                "floor" => value.floor(),
                "ceil" => value.ceil(),
                _ => unreachable!(),
            };
            Ok(QValue::Num(QNum::new(result)))
        }
        "math.round" => {
            // round(num) - round to nearest integer
            // round(num, places) - round to N decimal places
            if args.is_empty() || args.len() > 2 {
                return Err(format!("math.round expects 1 or 2 arguments, got {}", args.len()));
            }
            let value = args[0].as_num()?;

            if args.len() == 1 {
                // Round to nearest integer
                Ok(QValue::Num(QNum::new(value.round())))
            } else {
                // Round to N decimal places
                let places = args[1].as_num()? as i32;
                if places < 0 {
                    return Err("math.round places must be non-negative".to_string());
                }
                let multiplier = 10_f64.powi(places);
                let result = (value * multiplier).round() / multiplier;
                Ok(QValue::Num(QNum::new(result)))
            }
        }
        // OS module functions
        "os.getcwd" => {
            if !args.is_empty() {
                return Err(format!("getcwd expects 0 arguments, got {}", args.len()));
            }
            let cwd = env::current_dir()
                .map_err(|e| format!("Failed to get current directory: {}", e))?;
            Ok(QValue::Str(QString::new(cwd.to_string_lossy().to_string())))
        }
        "os.chdir" => {
            if args.len() != 1 {
                return Err(format!("chdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            env::set_current_dir(&path)
                .map_err(|e| format!("Failed to change directory to '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.listdir" => {
            if args.len() != 1 {
                return Err(format!("listdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let entries = fs::read_dir(&path)
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
                return Err(format!("mkdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            fs::create_dir(&path)
                .map_err(|e| format!("Failed to create directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.rmdir" => {
            if args.len() != 1 {
                return Err(format!("rmdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            fs::remove_dir(&path)
                .map_err(|e| format!("Failed to remove directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.remove" => {
            if args.len() != 1 {
                return Err(format!("remove expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let path_obj = std::path::Path::new(&path);
            if path_obj.is_file() {
                fs::remove_file(&path)
                    .map_err(|e| format!("Failed to remove file '{}': {}", path, e))?;
            } else if path_obj.is_dir() {
                fs::remove_dir_all(&path)
                    .map_err(|e| format!("Failed to remove directory '{}': {}", path, e))?;
            } else {
                return Err(format!("Path '{}' does not exist", path));
            }
            Ok(QValue::Nil(QNil))
        }
        "os.rename" => {
            if args.len() != 2 {
                return Err(format!("rename expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            fs::rename(&src, &dst)
                .map_err(|e| format!("Failed to rename '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        "os.getenv" => {
            if args.len() != 1 {
                return Err(format!("getenv expects 1 argument, got {}", args.len()));
            }
            let key = args[0].as_str();
            match env::var(&key) {
                Ok(value) => Ok(QValue::Str(QString::new(value))),
                Err(_) => Ok(QValue::Nil(QNil)),
            }
        }
        // Term module functions - helper for color codes
        "term.red" | "term.green" | "term.yellow" |
        "term.blue" | "term.magenta" | "term.cyan" |
        "term.white" | "term.grey" => {
            if args.is_empty() {
                return Err(format!("{} expects at least 1 argument, got 0", func_name));
            }
            let text = args[0].as_str();
            let color_code = match func_name.trim_start_matches("term.") {
                "red" => "31",
                "green" => "32",
                "yellow" => "33",
                "blue" => "34",
                "magenta" => "35",
                "cyan" => "36",
                "white" => "37",
                "grey" => "90",
                _ => unreachable!(),
            };

            // Check if there are attributes (second arg should be array)
            let mut result = format!("\x1b[{}m{}\x1b[0m", color_code, text);
            if args.len() > 1 {
                if let QValue::Array(attrs) = &args[1] {
                    let mut codes = vec![color_code.to_string()];
                    for attr in &attrs.elements {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                    result = format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text);
                }
            }
            Ok(QValue::Str(QString::new(result)))
        }
        "term.color" => {
            if args.len() < 2 {
                return Err(format!("color expects at least 2 arguments, got {}", args.len()));
            }
            let text = args[0].as_str();
            let color = args[1].as_str();

            let color_code = match color.as_str() {
                "red" => "31",
                "green" => "32",
                "yellow" => "33",
                "blue" => "34",
                "magenta" => "35",
                "cyan" => "36",
                "white" => "37",
                "grey" => "90",
                _ => return Err(format!("Unknown color: {}", color)),
            };

            let mut codes = vec![color_code.to_string()];
            if args.len() > 2 {
                if let QValue::Array(attrs) = &args[2] {
                    for attr in &attrs.elements {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                }
            }

            let result = format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text);
            Ok(QValue::Str(QString::new(result)))
        }
        "term.on_color" => {
            if args.len() != 2 {
                return Err(format!("on_color expects 2 arguments, got {}", args.len()));
            }
            let text = args[0].as_str();
            let color = args[1].as_str();

            let color_code = match color.as_str() {
                "red" => "41",
                "green" => "42",
                "yellow" => "43",
                "blue" => "44",
                "magenta" => "45",
                "cyan" => "46",
                "white" => "47",
                "grey" => "100",
                _ => return Err(format!("Unknown color: {}", color)),
            };

            let result = format!("\x1b[{}m{}\x1b[0m", color_code, text);
            Ok(QValue::Str(QString::new(result)))
        }
        "term.bold" | "term.dim" | "term.dimmed" |
        "term.underline" | "term.blink" |
        "term.reverse" | "term.hidden" => {
            if args.len() != 1 {
                return Err(format!("{} expects 1 argument, got {}", func_name, args.len()));
            }
            let text = args[0].as_str();
            let attr_code = match func_name.trim_start_matches("term.") {
                "bold" => "1",
                "dim" | "dimmed" => "2",
                "underline" => "4",
                "blink" => "5",
                "reverse" => "7",
                "hidden" => "8",
                _ => unreachable!(),
            };
            let result = format!("\x1b[{}m{}\x1b[0m", attr_code, text);
            Ok(QValue::Str(QString::new(result)))
        }
        "term.styled" => {
            if args.is_empty() {
                return Err(format!("styled expects at least 1 argument, got 0"));
            }
            let text = args[0].as_str();
            let mut codes = Vec::new();

            // fg color (arg 1)
            if args.len() > 1 {
                if let QValue::Str(fg) = &args[1] {
                    let fg_str = &fg.value;
                    if !fg_str.is_empty() && fg_str != "nil" {
                        let color_code = match fg_str.as_str() {
                            "red" => "31",
                            "green" => "32",
                            "yellow" => "33",
                            "blue" => "34",
                            "magenta" => "35",
                            "cyan" => "36",
                            "white" => "37",
                            "grey" => "90",
                            _ => return Err(format!("Unknown foreground color: {}", fg_str)),
                        };
                        codes.push(color_code.to_string());
                    }
                }
            }

            // bg color (arg 2)
            if args.len() > 2 {
                if let QValue::Str(bg) = &args[2] {
                    let bg_str = &bg.value;
                    if !bg_str.is_empty() && bg_str != "nil" {
                        let color_code = match bg_str.as_str() {
                            "red" => "41",
                            "green" => "42",
                            "yellow" => "43",
                            "blue" => "44",
                            "magenta" => "45",
                            "cyan" => "46",
                            "white" => "47",
                            "grey" => "100",
                            _ => return Err(format!("Unknown background color: {}", bg_str)),
                        };
                        codes.push(color_code.to_string());
                    }
                }
            }

            // attrs (arg 3)
            if args.len() > 3 {
                if let QValue::Array(attrs) = &args[3] {
                    for attr in &attrs.elements {
                        let attr_str = attr.as_str();
                        let attr_code = match attr_str.as_str() {
                            "bold" => "1",
                            "dim" => "2",
                            "underline" => "4",
                            "blink" => "5",
                            "reverse" => "7",
                            "hidden" => "8",
                            _ => continue,
                        };
                        codes.push(attr_code.to_string());
                    }
                }
            }

            let result = if codes.is_empty() {
                text
            } else {
                format!("\x1b[{}m{}\x1b[0m", codes.join(";"), text)
            };
            Ok(QValue::Str(QString::new(result)))
        }
        "term.move_up" | "term.move_down" | "term.move_left" | "term.move_right" => {
            let n = if args.is_empty() {
                1
            } else {
                args[0].as_num()? as i32
            };
            let code = match func_name.trim_start_matches("term.") {
                "move_up" => format!("\x1b[{}A", n),
                "move_down" => format!("\x1b[{}B", n),
                "move_right" => format!("\x1b[{}C", n),
                "move_left" => format!("\x1b[{}D", n),
                _ => unreachable!(),
            };
            print!("{}", code);
            Ok(QValue::Nil(QNil))
        }
        "term.move_to" => {
            if args.len() != 2 {
                return Err(format!("move_to expects 2 arguments, got {}", args.len()));
            }
            let row = args[0].as_num()? as i32;
            let col = args[1].as_num()? as i32;
            print!("\x1b[{};{}H", row, col);
            Ok(QValue::Nil(QNil))
        }
        "term.save_cursor" => {
            if !args.is_empty() {
                return Err(format!("save_cursor expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[s");
            Ok(QValue::Nil(QNil))
        }
        "term.restore_cursor" => {
            if !args.is_empty() {
                return Err(format!("restore_cursor expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[u");
            Ok(QValue::Nil(QNil))
        }
        "term.clear" => {
            if !args.is_empty() {
                return Err(format!("clear expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[2J\x1b[H");
            Ok(QValue::Nil(QNil))
        }
        "term.clear_line" => {
            if !args.is_empty() {
                return Err(format!("clear_line expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[2K");
            Ok(QValue::Nil(QNil))
        }
        "term.clear_to_end" => {
            if !args.is_empty() {
                return Err(format!("clear_to_end expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[J");
            Ok(QValue::Nil(QNil))
        }
        "term.clear_to_start" => {
            if !args.is_empty() {
                return Err(format!("clear_to_start expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[1J");
            Ok(QValue::Nil(QNil))
        }
        "term.width" | "term.height" | "term.size" => {
            if !args.is_empty() {
                return Err(format!("{} expects 0 arguments, got {}", func_name, args.len()));
            }
            // Try to get terminal size or fallback
            let base_name = func_name.trim_start_matches("term.");
            if let Some((w, h)) = term_size::dimensions() {
                match base_name {
                    "width" => Ok(QValue::Num(QNum::new(w as f64))),
                    "height" => Ok(QValue::Num(QNum::new(h as f64))),
                    "size" => {
                        let arr = vec![
                            QValue::Num(QNum::new(h as f64)),
                            QValue::Num(QNum::new(w as f64)),
                        ];
                        Ok(QValue::Array(QArray::new(arr)))
                    }
                    _ => unreachable!(),
                }
            } else {
                // Fallback to default size
                match base_name {
                    "width" => Ok(QValue::Num(QNum::new(80.0))),
                    "height" => Ok(QValue::Num(QNum::new(24.0))),
                    "size" => {
                        let arr = vec![
                            QValue::Num(QNum::new(24.0)),
                            QValue::Num(QNum::new(80.0)),
                        ];
                        Ok(QValue::Array(QArray::new(arr)))
                    }
                    _ => unreachable!(),
                }
            }
        }
        "term.reset" => {
            if !args.is_empty() {
                return Err(format!("reset expects 0 arguments, got {}", args.len()));
            }
            Ok(QValue::Str(QString::new("\x1b[0m".to_string())))
        }
        "term.strip_colors" => {
            if args.len() != 1 {
                return Err(format!("strip_colors expects 1 argument, got {}", args.len()));
            }
            let text = args[0].as_str();
            // Simple regex-like replacement to strip ANSI codes
            let mut result = String::new();
            let mut chars = text.chars().peekable();
            while let Some(ch) = chars.next() {
                if ch == '\x1b' {
                    // Skip escape sequence
                    if chars.peek() == Some(&'[') {
                        chars.next(); // consume '['
                        // Skip until we find a letter (the command)
                        while let Some(&c) = chars.peek() {
                            chars.next();
                            if c.is_ascii_alphabetic() {
                                break;
                            }
                        }
                    }
                } else {
                    result.push(ch);
                }
            }
            Ok(QValue::Str(QString::new(result)))
        }
        // JSON module functions
        "json.parse" => {
            if args.len() != 1 {
                return Err(format!("parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let json_value: serde_json::Value = serde_json::from_str(&json_str)
                .map_err(|e| format!("JSON parse error: {}", e))?;
            json_to_qvalue(json_value)
        }
        "json.try_parse" => {
            if args.len() != 1 {
                return Err(format!("try_parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            match serde_json::from_str::<serde_json::Value>(&json_str) {
                Ok(json_value) => json_to_qvalue(json_value),
                Err(_) => Ok(QValue::Nil(QNil)),
            }
        }
        "json.is_valid" => {
            if args.len() != 1 {
                return Err(format!("is_valid expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let is_valid = serde_json::from_str::<serde_json::Value>(&json_str).is_ok();
            Ok(QValue::Bool(QBool::new(is_valid)))
        }
        "json.stringify" => {
            if args.is_empty() {
                return Err(format!("stringify expects at least 1 argument, got 0"));
            }
            let value = &args[0];
            let json_value = qvalue_to_json(value)?;
            let json_str = serde_json::to_string(&json_value)
                .map_err(|e| format!("JSON stringify error: {}", e))?;
            Ok(QValue::Str(QString::new(json_str)))
        }
        "json.stringify_pretty" => {
            if args.is_empty() {
                return Err(format!("stringify_pretty expects at least 1 argument, got 0"));
            }
            let value = &args[0];
            let json_value = qvalue_to_json(value)?;
            let json_str = serde_json::to_string_pretty(&json_value)
                .map_err(|e| format!("JSON stringify error: {}", e))?;
            Ok(QValue::Str(QString::new(json_str)))
        }
        "is_array" => {
            if args.len() != 1 {
                return Err(format!("is_array expects 1 argument, got {}", args.len()));
            }
            let is_arr = matches!(&args[0], QValue::Array(_));
            Ok(QValue::Bool(QBool::new(is_arr)))
        }
        "io.glob" => {
            if args.len() != 1 {
                return Err(format!("glob expects 1 argument, got {}", args.len()));
            }
            let pattern = args[0].as_str();

            let mut paths = Vec::new();
            match glob_pattern(&pattern) {
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

            // Use glob's Pattern matching
            match glob::Pattern::new(&pattern) {
                Ok(glob_pattern) => {
                    let matches = glob_pattern.matches(&path);
                    Ok(QValue::Bool(QBool::new(matches)))
                }
                Err(e) => Err(format!("Invalid glob pattern: {}", e)),
            }
        }
        // IO module functions (namespaced versions)
        "io.read" => {
            if args.len() != 1 {
                return Err(format!("read expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = fs::read_to_string(&path)
                .map_err(|e| format!("Failed to read file '{}': {}", path, e))?;
            Ok(QValue::Str(QString::new(content)))
        }
        "io.write" => {
            if args.len() != 2 {
                return Err(format!("write expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = args[1].as_str();
            fs::write(&path, content)
                .map_err(|e| format!("Failed to write file '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.append" => {
            if args.len() != 2 {
                return Err(format!("append expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = args[1].as_str();
            let mut file = fs::OpenOptions::new()
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
            let metadata = fs::metadata(&path)
                .map_err(|e| format!("Failed to get metadata for '{}': {}", path, e))?;
            Ok(QValue::Num(QNum::new(metadata.len() as f64)))
        }
        "copy" => {
            if args.len() != 2 {
                return Err(format!("copy expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            fs::copy(&src, &dst)
                .map_err(|e| format!("Failed to copy '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        "move" => {
            if args.len() != 2 {
                return Err(format!("move expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            fs::rename(&src, &dst)
                .map_err(|e| format!("Failed to move '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        // Hash module functions
        "hash.md5" => {
            if args.len() != 1 {
                return Err(format!("md5 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use md5::Digest;
            let hash = format!("{:x}", Md5::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha1" => {
            if args.len() != 1 {
                return Err(format!("sha1 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha1::Digest;
            let hash = format!("{:x}", Sha1::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha256" => {
            if args.len() != 1 {
                return Err(format!("sha256 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", Sha256::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha512" => {
            if args.len() != 1 {
                return Err(format!("sha512 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", Sha512::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.crc32" => {
            if args.len() != 1 {
                return Err(format!("crc32 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Crc32Hasher::new();
            hasher.update(data.as_bytes());
            let checksum = hasher.finalize();
            Ok(QValue::Str(QString::new(format!("{:08x}", checksum))))
        }
        // Regex module functions
        "regex.match" => {
            if args.len() != 2 {
                return Err(format!("regex.match expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;
            Ok(QValue::Bool(QBool::new(re.is_match(&text))))
        }
        "regex.find" => {
            if args.len() != 2 {
                return Err(format!("regex.find expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            match re.find(&text) {
                Some(m) => Ok(QValue::Str(QString::new(m.as_str().to_string()))),
                None => Ok(QValue::Nil(QNil)),
            }
        }
        "regex.find_all" => {
            if args.len() != 2 {
                return Err(format!("regex.find_all expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let matches: Vec<QValue> = re.find_iter(&text)
                .map(|m| QValue::Str(QString::new(m.as_str().to_string())))
                .collect();
            Ok(QValue::Array(QArray::new(matches)))
        }
        "regex.captures" => {
            if args.len() != 2 {
                return Err(format!("regex.captures expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            match re.captures(&text) {
                Some(caps) => {
                    let captured: Vec<QValue> = caps.iter()
                        .map(|c| match c {
                            Some(m) => QValue::Str(QString::new(m.as_str().to_string())),
                            None => QValue::Nil(QNil),
                        })
                        .collect();
                    Ok(QValue::Array(QArray::new(captured)))
                }
                None => Ok(QValue::Nil(QNil)),
            }
        }
        "regex.captures_all" => {
            if args.len() != 2 {
                return Err(format!("regex.captures_all expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let all_captures: Vec<QValue> = re.captures_iter(&text)
                .map(|caps| {
                    let captured: Vec<QValue> = caps.iter()
                        .map(|c| match c {
                            Some(m) => QValue::Str(QString::new(m.as_str().to_string())),
                            None => QValue::Nil(QNil),
                        })
                        .collect();
                    QValue::Array(QArray::new(captured))
                })
                .collect();
            Ok(QValue::Array(QArray::new(all_captures)))
        }
        "regex.replace" => {
            if args.len() != 3 {
                return Err(format!("regex.replace expects 3 arguments (pattern, text, replacement), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();
            let replacement = args[2].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let result = re.replace(&text, replacement.as_str()).to_string();
            Ok(QValue::Str(QString::new(result)))
        }
        "regex.replace_all" => {
            if args.len() != 3 {
                return Err(format!("regex.replace_all expects 3 arguments (pattern, text, replacement), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();
            let replacement = args[2].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let result = re.replace_all(&text, replacement.as_str()).to_string();
            Ok(QValue::Str(QString::new(result)))
        }
        "regex.split" => {
            if args.len() != 2 {
                return Err(format!("regex.split expects 2 arguments (pattern, text), got {}", args.len()));
            }
            let pattern = args[0].as_str();
            let text = args[1].as_str();

            let re = Regex::new(&pattern)
                .map_err(|e| format!("Invalid regex pattern: {}", e))?;

            let parts: Vec<QValue> = re.split(&text)
                .map(|s| QValue::Str(QString::new(s.to_string())))
                .collect();
            Ok(QValue::Array(QArray::new(parts)))
        }
        "regex.is_valid" => {
            if args.len() != 1 {
                return Err(format!("regex.is_valid expects 1 argument, got {}", args.len()));
            }
            let pattern = args[0].as_str();

            match Regex::new(&pattern) {
                Ok(_) => Ok(QValue::Bool(QBool::new(true))),
                Err(_) => Ok(QValue::Bool(QBool::new(false))),
            }
        }
        // Base64 encoding functions (std/encoding/b64)
        "b64.encode" => {
            if args.len() != 1 {
                return Err(format!("b64_encode expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::STANDARD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "b64.decode" => {
            if args.len() != 1 {
                return Err(format!("b64_decode expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let decoded = general_purpose::STANDARD.decode(data.as_bytes())
                .map_err(|e| format!("Base64 decode error: {}", e))?;
            let decoded_str = String::from_utf8(decoded)
                .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
            Ok(QValue::Str(QString::new(decoded_str)))
        }
        "b64.encode_url" => {
            if args.len() != 1 {
                return Err(format!("b64_encode_url expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::URL_SAFE_NO_PAD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "b64.decode_url" => {
            if args.len() != 1 {
                return Err(format!("b64_decode_url expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let decoded = general_purpose::URL_SAFE_NO_PAD.decode(data.as_bytes())
                .map_err(|e| format!("Base64 decode error: {}", e))?;
            let decoded_str = String::from_utf8(decoded)
                .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
            Ok(QValue::Str(QString::new(decoded_str)))
        }
        // Crypto module functions (HMAC)
        "crypto.hmac_sha256" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha256 expects 2 arguments (message, key), got {}", args.len()));
            }
            let message = args[0].as_str();
            let key = args[1].as_str();

            use hmac::{Hmac, Mac};
            use sha2::Sha256;
            type HmacSha256 = Hmac<Sha256>;

            let mut mac = HmacSha256::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(message.as_bytes());
            let result = mac.finalize();
            let code_bytes = result.into_bytes();

            Ok(QValue::Str(QString::new(format!("{:x}", code_bytes))))
        }
        "crypto.hmac_sha512" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha512 expects 2 arguments (message, key), got {}", args.len()));
            }
            let message = args[0].as_str();
            let key = args[1].as_str();

            use hmac::{Hmac, Mac};
            use sha2::Sha512;
            type HmacSha512 = Hmac<Sha512>;

            let mut mac = HmacSha512::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(message.as_bytes());
            let result = mac.finalize();
            let code_bytes = result.into_bytes();

            Ok(QValue::Str(QString::new(format!("{:x}", code_bytes))))
        }
        // Time module functions
        "time.now" => {
            if !args.is_empty() {
                return Err(format!("time.now expects 0 arguments, got {}", args.len()));
            }
            use modules::time::QTimestamp;
            let now = jiff::Timestamp::now();
            Ok(QValue::Timestamp(QTimestamp::new(now)))
        }
        "time.now_local" => {
            if !args.is_empty() {
                return Err(format!("time.now_local expects 0 arguments, got {}", args.len()));
            }
            use modules::time::QZoned;
            let now = jiff::Zoned::now();
            Ok(QValue::Zoned(QZoned::new(now)))
        }
        "time.today" => {
            if !args.is_empty() {
                return Err(format!("time.today expects 0 arguments, got {}", args.len()));
            }
            use modules::time::QDate;
            let now = jiff::Zoned::now();
            let today = now.date();
            Ok(QValue::Date(QDate::new(today)))
        }
        "time.time_now" => {
            if !args.is_empty() {
                return Err(format!("time.time_now expects 0 arguments, got {}", args.len()));
            }
            use modules::time::QTime;
            let now = jiff::Zoned::now();
            let time = now.time();
            Ok(QValue::Time(QTime::new(time)))
        }
        "time.datetime" => {
            // time.datetime(year, month, day, hour, minute, second, timezone?)
            if args.len() < 6 || args.len() > 7 {
                return Err(format!("time.datetime expects 6 or 7 arguments (year, month, day, hour, minute, second, timezone?), got {}", args.len()));
            }
            use modules::time::QZoned;
            use jiff::tz::TimeZone;

            let year = args[0].as_num()? as i16;
            let month = args[1].as_num()? as i8;
            let day = args[2].as_num()? as i8;
            let hour = args[3].as_num()? as i8;
            let minute = args[4].as_num()? as i8;
            let second = args[5].as_num()? as i8;

            let tz_name = if args.len() == 7 {
                args[6].as_str()
            } else {
                "UTC".to_string()
            };

            let tz = TimeZone::get(&tz_name)
                .map_err(|e| format!("Invalid timezone '{}': {}", tz_name, e))?;

            let zoned = jiff::civil::date(year, month, day)
                .at(hour, minute, second, 0)
                .to_zoned(tz)
                .map_err(|e| format!("Failed to create datetime: {}", e))?;

            Ok(QValue::Zoned(QZoned::new(zoned)))
        }
        "time.date" => {
            // time.date(year, month, day)
            if args.len() != 3 {
                return Err(format!("time.date expects 3 arguments (year, month, day), got {}", args.len()));
            }
            use modules::time::QDate;
            use jiff::civil::Date;

            let year = args[0].as_num()? as i16;
            let month = args[1].as_num()? as i8;
            let day = args[2].as_num()? as i8;

            let date = Date::new(year, month, day)
                .map_err(|e| format!("Invalid date: {}", e))?;

            Ok(QValue::Date(QDate::new(date)))
        }
        "time.time" => {
            // time.time(hour, minute, second, nanosecond?)
            if args.len() < 3 || args.len() > 4 {
                return Err(format!("time.time expects 3 or 4 arguments (hour, minute, second, nanosecond?), got {}", args.len()));
            }
            use modules::time::QTime;
            use jiff::civil::Time;

            let hour = args[0].as_num()? as i8;
            let minute = args[1].as_num()? as i8;
            let second = args[2].as_num()? as i8;
            let nanosecond = if args.len() == 4 {
                args[3].as_num()? as i32
            } else {
                0
            };

            let time = Time::new(hour, minute, second, nanosecond)
                .map_err(|e| format!("Invalid time: {}", e))?;

            Ok(QValue::Time(QTime::new(time)))
        }
        "time.days" => {
            if args.len() != 1 {
                return Err(format!("time.days expects 1 argument, got {}", args.len()));
            }
            use modules::time::QSpan;
            use jiff::ToSpan;

            let days = args[0].as_num()? as i64;
            let span = days.days();

            Ok(QValue::Span(QSpan::new(span)))
        }
        "time.hours" => {
            if args.len() != 1 {
                return Err(format!("time.hours expects 1 argument, got {}", args.len()));
            }
            use modules::time::QSpan;
            use jiff::ToSpan;

            let hours = args[0].as_num()? as i64;
            let span = hours.hours();

            Ok(QValue::Span(QSpan::new(span)))
        }
        "time.minutes" => {
            if args.len() != 1 {
                return Err(format!("time.minutes expects 1 argument, got {}", args.len()));
            }
            use modules::time::QSpan;
            use jiff::ToSpan;

            let minutes = args[0].as_num()? as i64;
            let span = minutes.minutes();

            Ok(QValue::Span(QSpan::new(span)))
        }
        "time.seconds" => {
            if args.len() != 1 {
                return Err(format!("time.seconds expects 1 argument, got {}", args.len()));
            }
            use modules::time::QSpan;
            use jiff::ToSpan;

            let seconds = args[0].as_num()? as i64;
            let span = seconds.seconds();

            Ok(QValue::Span(QSpan::new(span)))
        }
        "time.sleep" => {
            if args.len() != 1 {
                return Err(format!("time.sleep expects 1 argument, got {}", args.len()));
            }
            use std::thread;
            use std::time::Duration;

            let seconds = args[0].as_num()?;
            if seconds < 0.0 {
                return Err("time.sleep expects a non-negative number".to_string());
            }

            let duration = Duration::from_secs_f64(seconds);
            thread::sleep(duration);

            Ok(QValue::Nil(QNil))
        }
        "time.is_leap_year" => {
            if args.len() != 1 {
                return Err(format!("time.is_leap_year expects 1 argument, got {}", args.len()));
            }

            let year = args[0].as_num()? as i16;
            let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

            Ok(QValue::Bool(QBool::new(is_leap)))
        }
        _ => Err(format!("Undefined function: {}", func_name)),
    }
}

// Helper function to convert serde_json::Value to QValue
fn print_help() {
    println!("Quest REPL Commands:");
    println!("  :help    - Show this help message");
    println!("  :exit    - Exit the REPL");
    println!("  :quit    - Exit the REPL");
    println!();
    println!("Supported operators:");
    println!("  Arithmetic: + - * / %");
    println!("  Comparison: == != < > <= >=");
    println!("  Logical: and or !");
    println!("  Bitwise: & |");
    println!();
    println!("Number methods:");
    println!("  Arithmetic: plus(n) minus(n) times(n) div(n) mod(n)");
    println!("  Comparison: eq(n) neq(n) gt(n) lt(n) gte(n) lte(n)");
    println!();
    println!("Boolean methods:");
    println!("  eq(b) neq(b)");
    println!();
    println!("String methods:");
    println!("  len() concat(s) upper() lower() eq(s) neq(s)");
    println!();
    println!("Built-in functions:");
    println!("  puts(...)  - Print values with newline");
    println!("  print(...) - Print values without newline");
    println!();
    println!("Control flow:");
    println!("  if condition");
    println!("    statements");
    println!("  elif condition");
    println!("    statements");
    println!("  else");
    println!("    statements");
    println!("  end");
    println!();
    println!("  Inline: value if condition else other_value");
    println!();
    println!("Examples:");
    println!("  puts(\"Hello World\")");
    println!("  puts(\"Answer: \", 42)");
    println!("  2 + 3 * 4        or  2.plus(3.times(4))");
    println!("  \"yes\" if true else \"no\"");
    println!("  if 5.gt(3)");
    println!("    puts(\"5 is greater\")");
    println!("  end");
}

fn run_script(source: &str, args: &[String], script_path: Option<&str>) -> Result<(), String> {
    // Set global script args and path for sys module (only set once)
    let _ = SCRIPT_ARGS.set(args.to_vec());
    let _ = SCRIPT_PATH.set(script_path.map(|s| s.to_string()));

    let mut scope = Scope::new();

    // Set the current script path if provided (for relative imports)
    if let Some(path) = script_path {
        let canonical_path = std::path::Path::new(path)
            .canonicalize()
            .ok()
            .and_then(|p| p.to_str().map(|s| s.to_string()))
            .unwrap_or_else(|| path.to_string());
        *scope.current_script_path.borrow_mut() = Some(canonical_path);
    }

    // Trim trailing whitespace to avoid parse errors on empty lines
    let source = source.trim_end();

    // Parse as a program (allows comments and multiple statements)
    let pairs = QuestParser::parse(Rule::program, source)
        .map_err(|e| format!("Parse error: {}", e))?;

    // Evaluate each statement in the program
    let mut _last_result = QValue::Nil(QNil);
    for pair in pairs {
        // Skip EOI and SOI
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }

        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }
            _last_result = eval_pair(statement, &mut scope)?;
        }
    }

    Ok(())
}

fn run_repl() -> rustyline::Result<()> {
    println!("Quest REPL v0.1.0");
    println!("(type ':help' for help, ':exit' or ':quit' to exit)");
    println!();

    let mut rl = DefaultEditor::new()?;
    let mut buffer = String::new();
    let mut nesting_level = 0;
    let mut scope = Scope::new();

    loop {
        let prompt = if nesting_level > 0 {
            format!("{}> ", ".".repeat(nesting_level))
        } else {
            "quest> ".to_string()
        };

        let readline = rl.readline(&prompt);
        match readline {
            Ok(line) => {
                let trimmed = line.trim();

                if trimmed.is_empty() && nesting_level == 0 {
                    continue;
                }

                // Handle commands starting with : (only at top level)
                if trimmed.starts_with(':') && nesting_level == 0 {
                    match trimmed {
                        ":exit" | ":quit" => {
                            println!("Goodbye!");
                            break;
                        }
                        ":help" => {
                            print_help();
                            continue;
                        }
                        _ => {
                            eprintln!("Unknown command: {}. Type ':help' for available commands.", trimmed);
                            continue;
                        }
                    }
                }

                // Track nesting level for multi-line constructs
                let line_lower = trimmed.to_lowercase();
                if line_lower.starts_with("if ") || line_lower.starts_with("fun ") {
                    nesting_level += 1;
                }
                if line_lower.starts_with("elif ") || line_lower.starts_with("else") {
                    // These don't change nesting, but indicate we're still in a block
                }
                if trimmed == "end" {
                    nesting_level = nesting_level.saturating_sub(1);
                }

                // Add to buffer
                if !buffer.is_empty() {
                    buffer.push('\n');
                }
                buffer.push_str(trimmed);

                // If we're at nesting level 0, evaluate the complete statement
                if nesting_level == 0 && !buffer.is_empty() {
                    rl.add_history_entry(&buffer)?;

                    match eval_expression(&buffer, &mut scope) {
                        Ok(result) => {
                            // Don't print nil results (from statements like puts)
                            if !matches!(result, QValue::Nil(_)) {
                                // Always use the _rep() method for REPL output
                                println!("{}", result.as_obj()._rep());
                            }
                        }
                        Err(e) => eprintln!("Error: {}", e),
                    }

                    // Clear buffer for next statement
                    buffer.clear();
                }
            }
            Err(ReadlineError::Interrupted) => {
                println!("^C");
                break;
            }
            Err(ReadlineError::Eof) => {
                println!("^D");
                break;
            }
            Err(err) => {
                eprintln!("Error: {:?}", err);
                break;
            }
        }
    }

    Ok(())
}

// Structure for parsing project config (quest.toml or project.yaml)
#[derive(Debug, Deserialize)]
#[allow(dead_code)] // Metadata fields are for documentation and future use
struct ProjectConfig {
    // Project metadata
    name: Option<String>,
    version: Option<String>,
    description: Option<String>,
    authors: Option<Vec<String>>,
    license: Option<String>,
    homepage: Option<String>,
    repository: Option<String>,
    keywords: Option<Vec<String>>,

    // Scripts to run
    scripts: Option<HashMap<String, String>>,
}

// Handle the 'run' command: quest run <script_name>
fn handle_run_command(script_name: &str, remaining_args: &[String]) -> Result<(), Box<dyn std::error::Error>> {
    // Look for quest.toml first, then fall back to project.yaml
    let (project_path, config_format) = if PathBuf::from("quest.toml").exists() {
        (PathBuf::from("quest.toml"), "toml")
    } else if PathBuf::from("project.yaml").exists() {
        (PathBuf::from("project.yaml"), "yaml")
    } else {
        return Err(format!("quest.toml or project.yaml not found in current directory").into());
    };

    // Parse the config file
    let content = fs::read_to_string(&project_path)?;
    let project: ProjectConfig = if config_format == "toml" {
        toml::from_str(&content)
            .map_err(|e| format!("Failed to parse quest.toml: {}", e))?
    } else {
        serde_yaml::from_str(&content)
            .map_err(|e| format!("Failed to parse project.yaml: {}", e))?
    };

    // Find the script
    let config_name = if config_format == "toml" { "quest.toml" } else { "project.yaml" };
    let scripts = project.scripts.ok_or_else(|| format!("No 'scripts' section found in {}", config_name))?;
    let script_value = scripts.get(script_name)
        .ok_or_else(|| format!("Script '{}' not found in {}", script_name, config_name))?;

    // Get the directory containing the config file
    // Canonicalize to get absolute path
    let project_dir = project_path
        .canonicalize()
        .ok()
        .and_then(|p| p.parent().map(|parent| parent.to_path_buf()))
        .unwrap_or_else(|| env::current_dir().unwrap_or_else(|_| PathBuf::from(".")));

    // Check if it's a shell command:
    // - Contains spaces (e.g., "cargo build --release")
    // - Is a relative path without .q extension (e.g., "./build.sh", "pwd")
    // - Starts with absolute path to system binary (e.g., "/bin/echo")
    let is_shell_command = script_value.contains(' ') ||
                          (!script_value.ends_with(".q") &&
                           (!script_value.contains('/') || script_value.starts_with('/')));

    if is_shell_command {
        // It's a shell command - execute it with sh/cmd
        let shell = if cfg!(windows) { "cmd" } else { "/bin/sh" };
        let shell_arg = if cfg!(windows) { "/C" } else { "-c" };

        let mut cmd = Command::new(shell);
        cmd.arg(shell_arg);

        // Build the full command with arguments
        let mut full_command = script_value.clone();
        for arg in remaining_args {
            full_command.push(' ');
            // Quote arguments that contain spaces
            if arg.contains(' ') {
                full_command.push_str(&format!("\"{}\"", arg));
            } else {
                full_command.push_str(arg);
            }
        }

        cmd.arg(&full_command);
        cmd.current_dir(project_dir);

        let status = cmd.status()
            .map_err(|e| format!("Failed to execute shell command '{}': {} (command: {} {} \"{}\")",
                                 script_value, e, shell, shell_arg, full_command))?;

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }

        return Ok(());
    }

    // Resolve the script path relative to project.yaml
    let resolved_path = project_dir.join(script_value);

    // Check if it's a .q file
    if script_value.ends_with(".q") {
        // It's a Quest script - run it directly
        let source = fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read file '{}': {}", resolved_path.display(), e))?;

        // Create args array: [script_path, ...remaining_args]
        let mut script_args = vec![resolved_path.to_string_lossy().to_string()];
        script_args.extend_from_slice(remaining_args);

        if let Err(e) = run_script(&source, &script_args, Some(&resolved_path.to_string_lossy())) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
    } else {
        // It's an executable - spawn it
        let mut cmd = Command::new(&resolved_path);
        cmd.args(remaining_args);

        let status = cmd.status()
            .map_err(|e| format!("Failed to execute '{}': {}", resolved_path.display(), e))?;

        if !status.success() {
            std::process::exit(status.code().unwrap_or(1));
        }
    }

    Ok(())
}

// Display help information
fn show_help() {
    println!("Quest - A vibe coded scripting language focused on developer happiness.");
    println!();
    println!("USAGE:");
    println!("    quest [OPTIONS] [FILE] [ARGS...]");
    println!("    quest [COMMAND] [ARGS...]");
    println!();
    println!("MODES:");
    println!("    quest              Start interactive REPL");
    println!("    quest <file.q>     Execute a Quest script file");
    println!("    quest run <name>   Run a script from quest.toml");
    println!("    cat file.q | quest Read and execute from stdin");
    println!();
    println!("OPTIONS:");
    println!("    -h, --help         Display this help message");
    println!("    -v, --version      Display version information");
    println!();
    println!("COMMANDS:");
    println!("    run <script_name> [args...]");
    println!("        Execute a named script defined in quest.toml (or project.yaml)");
    println!("        Similar to 'npm run' - looks up the script path");
    println!("        and executes it with optional arguments.");
    println!();
    println!("        Example quest.toml:");
    println!("            [scripts]");
    println!("            test = \"scripts/test.q\"");
    println!("            install = \"cargo install --path .\"");
    println!();
    println!("        Usage:");
    println!("            quest run test");
    println!("            quest run install");
    println!();
    println!("ARGUMENTS:");
    println!("    When running a script file, arguments are accessible via:");
    println!("        sys.argv - Array of arguments (including script name)");
    println!("        sys.argc - Number of arguments");
    println!();
    println!("EXAMPLES:");
    println!("    quest                      # Start REPL");
    println!("    quest script.q             # Run script.q");
    println!("    quest script.q arg1 arg2   # Run with arguments");
    println!("    quest run test             # Run 'test' from quest.toml");
    println!("    echo 'puts(\"hi\")' | quest  # Execute from stdin");
    println!();
    println!("For more information, visit: https://github.com/quest-lang/quest");
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    // Check if we have positional arguments
    if args.len() > 1 {
        let first_arg = &args[1];

        // Check for help flag
        if first_arg == "--help" || first_arg == "-h" {
            show_help();
            return Ok(());
        }

        // Check for version flag
        if first_arg == "--version" || first_arg == "-v" {
            println!("Quest version 0.1.0");
            return Ok(());
        }

        let first_arg_lower = first_arg.to_lowercase();

        // Check if first argument is a COMMAND (case insensitive)
        if first_arg_lower == "run" {
            // Handle 'run' command: quest run <script_name> [args...]
            if args.len() < 3 {
                eprintln!("Usage: quest run <script_name> [args...]");
                std::process::exit(1);
            }

            let script_name = &args[2];
            let remaining_args = if args.len() > 3 { &args[3..] } else { &[] };

            return handle_run_command(script_name, remaining_args);
        }

        // Otherwise, treat the first positional argument as a file path
        let filename = &args[1];
        let source = fs::read_to_string(filename)
            .map_err(|e| format!("Failed to read file '{}': {}", filename, e))?;

        // Pass all arguments (including script name) to the script along with script path
        if let Err(e) = run_script(&source, &args[1..], Some(filename)) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
        return Ok(());
    }

    // Check if stdin is being piped
    if !io::stdin().is_terminal() {
        let mut source = String::new();
        io::stdin().read_to_string(&mut source)?;

        // For piped input, pass program name only, no script path
        if let Err(e) = run_script(&source, &args, None) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
        return Ok(());
    }

    // Otherwise, run interactive REPL
    run_repl()?;
    Ok(())
}
