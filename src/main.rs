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

// Hash function imports
use md5::{Md5, Digest as Md5Digest};
use sha1::{Sha1, Digest as Sha1Digest};
use sha2::{Sha256, Sha512, Digest as Sha2Digest};
use hmac::{Hmac, Mac};
use crc32fast::Hasher as Crc32Hasher;

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
}

impl Scope {
    fn new() -> Self {
        Scope {
            scopes: vec![Rc::new(RefCell::new(HashMap::new()))],
            module_cache: Rc::new(RefCell::new(HashMap::new())),
        }
    }

    // Create a scope with a specific shared map as the base scope
    // Used for module function calls so they share the module's state
    fn with_shared_base(shared_map: Rc<RefCell<HashMap<String, QValue>>>, module_cache: Rc<RefCell<HashMap<String, QValue>>>) -> Self {
        Scope {
            scopes: vec![shared_map],
            module_cache,
        }
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

    // Create from flat HashMap (creates owned scope)
    fn from_flat_map(map: HashMap<String, QValue>) -> Self {
        Scope {
            scopes: vec![Rc::new(RefCell::new(map))],
            module_cache: Rc::new(RefCell::new(HashMap::new())),
        }
    }

    // Get cached module by path
    fn get_cached_module(&self, path: &str) -> Option<QValue> {
        self.module_cache.borrow().get(path).cloned()
    }

    // Cache a module by its resolved path
    fn cache_module(&mut self, path: String, module: QValue) {
        self.module_cache.borrow_mut().insert(path, module);
    }

    // Update cached module if it has a source path
    fn update_module_cache(&mut self, module: &QValue) {
        if let QValue::Module(qmod) = module {
            if let Some(source_path) = &qmod.source_path {
                self.module_cache.borrow_mut().insert(source_path.clone(), module.clone());
            }
        }
    }
}

// Helper function to load an external module
fn load_external_module(scope: &mut Scope, path: &str, alias: &str) -> Result<(), String> {
    // Get search paths from os.search_path if it exists
    let mut search_paths = vec![];
    if let Some(QValue::Module(os_module)) = scope.get("os") {
        if let Some(QValue::Array(arr)) = os_module.members.borrow().get("search_path") {
            for elem in &arr.elements {
                if let QValue::Str(s) = elem {
                    search_paths.push(s.value.clone());
                }
            }
        }
    }

    // Resolve the module path using search paths
    let resolved_path = resolve_module_path(path, &search_paths)?;

    // Check if module is already cached
    let module = if let Some(cached) = scope.get_cached_module(&resolved_path) {
        // Module already loaded - use cached version
        cached
    } else {
        // Load and evaluate the external .q file
        let file_content = std::fs::read_to_string(&resolved_path)
            .map_err(|e| format!("Failed to read module file '{}': {}", resolved_path, e))?;

        // Create a fresh scope for the module (not cloned from parent)
        // This prevents variable name conflicts when multiple files import the same module
        // Share the parent scope's module cache so nested imports can access it
        let mut module_scope = Scope::new();
        module_scope.module_cache = Rc::clone(&scope.module_cache);

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

        let new_module = QValue::Module(QModule::with_source_path(
            alias.to_string(),
            members,
            resolved_path.clone()
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
                    "json" => Some(create_json_module()),
                    "io" => Some(create_io_module()),
                    "encode" => Some(create_encode_module()),
                    "test.q" | "test" => None, // std/test.q is a file, not built-in
                    _ => None, // Not a built-in, try filesystem
                };

                if let Some(module) = module_opt {
                    // Use provided alias or derive from builtin name
                    let alias = alias_opt.unwrap_or_else(|| builtin_name.to_string());
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
            // let identifier = expression
            let mut inner = pair.into_inner();
            let identifier = inner.next().unwrap().as_str();
            let value = eval_pair(inner.next().unwrap(), scope)?;
            scope.declare(identifier, value)?;
            Ok(QValue::Nil(QNil)) // let statements return nil
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

            let func = QValue::UserFun(QUserFun::new(
                Some(name.clone()),
                params,
                body
            ));

            scope.declare(&name, func)?;
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

                    scope.set(&identifier, value);
                    Ok(QValue::Nil(QNil))
                }
                Rule::expression => {
                    // Simple: identifier = expression (old grammar path)
                    let value = eval_pair(next, scope)?;
                    scope.set(&identifier, value);
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
            let mut range_parts: Vec<_> = for_range.into_inner().collect();

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

                let func = QValue::UserFun(QUserFun::new(None, params, body));
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
        Rule::bitwise_or => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

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
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

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
            let mut result = eval_pair(inner.next().unwrap(), scope)?;

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
                    "!" => Ok(QValue::Bool(QBool::new(!value.as_bool()))),
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
            let original_identifier = match first_pair.as_rule() {
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
                            let args = if has_args {
                                let args_pair = &pairs[i + 1];
                                let mut args = Vec::new();
                                for arg in args_pair.clone().into_inner() {
                                    args.push(eval_pair(arg, scope)?);
                                }
                                args
                            } else {
                                Vec::new()
                            };

                            // Execute the method and return result
                            // Special handling for modules to persist state changes
                            if let QValue::Module(module) = &result {
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
                                        result = call_builtin_function(&namespaced_name, args)?;
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
                                } else {
                                    result = match &result {
                                        QValue::Num(n) => n.call_method(method_name, args)?,
                                        QValue::Bool(b) => b.call_method(method_name, args)?,
                                        QValue::Str(s) => s.call_method(method_name, args)?,
                                        QValue::Fun(f) => f.call_method(method_name, args)?,
                                        QValue::Dict(d) => d.call_method(method_name, args)?,
                                        _ => return Err(format!("Type {} does not support method calls", result.as_obj().cls())),
                                    };
                                }
                            }
                            i += if has_args { 2 } else { 1 }; // Skip identifier and optionally argument_list
                        } else {
                            // MEMBER ACCESS: no parentheses and no arguments
                            // Special handling for modules
                            if let QValue::Module(module) = &result {
                                // Access module member
                                result = module.get_member(method_name)
                                    .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?
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
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if this is a function call: identifier followed by argument_list or ()
            if first.as_rule() == Rule::identifier {
                let func_name = first.as_str();

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

                    return call_builtin_function(func_name, args);
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
    let mut zero_pad = false;
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
        zero_pad = true;
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

    // Create new scope for function - push a new scope level
    parent_scope.push();

    // Bind parameters to arguments in the new scope
    for (param_name, arg_value) in user_fun.params.iter().zip(args.iter()) {
        parent_scope.declare(param_name, arg_value.clone())?;
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
            result = eval_pair(statement, parent_scope)?;

            // Check for early return (not implemented yet - would need return statement handling)
        }
    }

    // Pop function scope
    parent_scope.pop();

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

fn call_builtin_function(func_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match func_name {
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
        // Math stdlib functions
        "math.sin" | "math.cos" | "math.tan" | "math.asin" | "math.acos" | "math.atan" |
        "math.abs" | "math.sqrt" | "math.ln" | "math.log10" | "math.exp" |
        "math.floor" | "math.ceil" | "math.round" => {
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
                "round" => value.round(),
                _ => unreachable!(),
            };
            Ok(QValue::Num(QNum::new(result)))
        }
        // OS module functions
        "getcwd" => {
            if !args.is_empty() {
                return Err(format!("getcwd expects 0 arguments, got {}", args.len()));
            }
            let cwd = env::current_dir()
                .map_err(|e| format!("Failed to get current directory: {}", e))?;
            Ok(QValue::Str(QString::new(cwd.to_string_lossy().to_string())))
        }
        "chdir" => {
            if args.len() != 1 {
                return Err(format!("chdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            env::set_current_dir(&path)
                .map_err(|e| format!("Failed to change directory to '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "listdir" => {
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
        "mkdir" => {
            if args.len() != 1 {
                return Err(format!("mkdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            fs::create_dir(&path)
                .map_err(|e| format!("Failed to create directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "rmdir" => {
            if args.len() != 1 {
                return Err(format!("rmdir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            fs::remove_dir(&path)
                .map_err(|e| format!("Failed to remove directory '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "remove" => {
            if args.len() != 1 {
                return Err(format!("remove expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            fs::remove_file(&path)
                .map_err(|e| format!("Failed to remove file '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "rename" => {
            if args.len() != 2 {
                return Err(format!("rename expects 2 arguments, got {}", args.len()));
            }
            let src = args[0].as_str();
            let dst = args[1].as_str();
            fs::rename(&src, &dst)
                .map_err(|e| format!("Failed to rename '{}' to '{}': {}", src, dst, e))?;
            Ok(QValue::Nil(QNil))
        }
        "getenv" => {
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
        "term.red" | "red" | "term.green" | "green" | "term.yellow" | "yellow" |
        "term.blue" | "blue" | "term.magenta" | "magenta" | "term.cyan" | "cyan" |
        "term.white" | "white" | "term.grey" | "grey" => {
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
        "color" => {
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
        "on_color" => {
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
        "term.bold" | "bold" | "term.dim" | "term.dimmed" | "dimmed" |
        "term.underline" | "underline" | "term.blink" | "blink" |
        "term.reverse" | "reverse" | "term.hidden" | "hidden" => {
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
        "term.styled" | "styled" => {
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
        "move_up" | "move_down" | "move_left" | "move_right" => {
            let n = if args.is_empty() {
                1
            } else {
                args[0].as_num()? as i32
            };
            let code = match func_name {
                "move_up" => format!("\x1b[{}A", n),
                "move_down" => format!("\x1b[{}B", n),
                "move_right" => format!("\x1b[{}C", n),
                "move_left" => format!("\x1b[{}D", n),
                _ => unreachable!(),
            };
            print!("{}", code);
            Ok(QValue::Nil(QNil))
        }
        "move_to" => {
            if args.len() != 2 {
                return Err(format!("move_to expects 2 arguments, got {}", args.len()));
            }
            let row = args[0].as_num()? as i32;
            let col = args[1].as_num()? as i32;
            print!("\x1b[{};{}H", row, col);
            Ok(QValue::Nil(QNil))
        }
        "save_cursor" => {
            if !args.is_empty() {
                return Err(format!("save_cursor expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[s");
            Ok(QValue::Nil(QNil))
        }
        "restore_cursor" => {
            if !args.is_empty() {
                return Err(format!("restore_cursor expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[u");
            Ok(QValue::Nil(QNil))
        }
        "clear" => {
            if !args.is_empty() {
                return Err(format!("clear expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[2J\x1b[H");
            Ok(QValue::Nil(QNil))
        }
        "clear_line" => {
            if !args.is_empty() {
                return Err(format!("clear_line expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[2K");
            Ok(QValue::Nil(QNil))
        }
        "clear_to_end" => {
            if !args.is_empty() {
                return Err(format!("clear_to_end expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[J");
            Ok(QValue::Nil(QNil))
        }
        "clear_to_start" => {
            if !args.is_empty() {
                return Err(format!("clear_to_start expects 0 arguments, got {}", args.len()));
            }
            print!("\x1b[1J");
            Ok(QValue::Nil(QNil))
        }
        "width" | "height" | "size" => {
            if !args.is_empty() {
                return Err(format!("{} expects 0 arguments, got {}", func_name, args.len()));
            }
            // Try to get terminal size or fallback
            if let Some((w, h)) = term_size::dimensions() {
                match func_name {
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
                match func_name {
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
        "term.reset" | "reset" => {
            if !args.is_empty() {
                return Err(format!("reset expects 0 arguments, got {}", args.len()));
            }
            Ok(QValue::Str(QString::new("\x1b[0m".to_string())))
        }
        "strip_colors" => {
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
        // Hash module functions
        "md5" => {
            if args.len() != 1 {
                return Err(format!("md5 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Md5::new();
            hasher.update(data.as_bytes());
            let result = hasher.finalize();
            let hex = format!("{:x}", result);
            Ok(QValue::Str(QString::new(hex)))
        }
        "sha1" => {
            if args.len() != 1 {
                return Err(format!("sha1 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Sha1::new();
            hasher.update(data.as_bytes());
            let result = hasher.finalize();
            let hex = format!("{:x}", result);
            Ok(QValue::Str(QString::new(hex)))
        }
        "sha256" => {
            if args.len() != 1 {
                return Err(format!("sha256 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Sha256::new();
            hasher.update(data.as_bytes());
            let result = hasher.finalize();
            let hex = format!("{:x}", result);
            Ok(QValue::Str(QString::new(hex)))
        }
        "sha512" => {
            if args.len() != 1 {
                return Err(format!("sha512 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Sha512::new();
            hasher.update(data.as_bytes());
            let result = hasher.finalize();
            let hex = format!("{:x}", result);
            Ok(QValue::Str(QString::new(hex)))
        }
        "hmac_sha256" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha256 expects 2 arguments, got {}", args.len()));
            }
            let data = args[0].as_str();
            let key = args[1].as_str();

            type HmacSha256 = Hmac<Sha256>;
            let mut mac = HmacSha256::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(data.as_bytes());
            let result = mac.finalize();
            let hex = format!("{:x}", result.into_bytes());
            Ok(QValue::Str(QString::new(hex)))
        }
        "hmac_sha512" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha512 expects 2 arguments, got {}", args.len()));
            }
            let data = args[0].as_str();
            let key = args[1].as_str();

            type HmacSha512 = Hmac<Sha512>;
            let mut mac = HmacSha512::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(data.as_bytes());
            let result = mac.finalize();
            let hex = format!("{:x}", result.into_bytes());
            Ok(QValue::Str(QString::new(hex)))
        }
        "crc32" => {
            if args.len() != 1 {
                return Err(format!("crc32 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Crc32Hasher::new();
            hasher.update(data.as_bytes());
            let checksum = hasher.finalize();
            Ok(QValue::Num(QNum::new(checksum as f64)))
        }
        // JSON module functions
        "json.parse" | "parse" => {
            if args.len() != 1 {
                return Err(format!("parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let json_value: serde_json::Value = serde_json::from_str(&json_str)
                .map_err(|e| format!("JSON parse error: {}", e))?;
            json_to_qvalue(json_value)
        }
        "json.try_parse" | "try_parse" => {
            if args.len() != 1 {
                return Err(format!("try_parse expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            match serde_json::from_str::<serde_json::Value>(&json_str) {
                Ok(json_value) => json_to_qvalue(json_value),
                Err(_) => Ok(QValue::Nil(QNil)),
            }
        }
        "json.is_valid" | "is_valid" => {
            if args.len() != 1 {
                return Err(format!("is_valid expects 1 argument, got {}", args.len()));
            }
            let json_str = args[0].as_str();
            let is_valid = serde_json::from_str::<serde_json::Value>(&json_str).is_ok();
            Ok(QValue::Bool(QBool::new(is_valid)))
        }
        "json.stringify" | "stringify" => {
            if args.is_empty() {
                return Err(format!("stringify expects at least 1 argument, got 0"));
            }
            let value = &args[0];
            let json_value = qvalue_to_json(value)?;
            let json_str = serde_json::to_string(&json_value)
                .map_err(|e| format!("JSON stringify error: {}", e))?;
            Ok(QValue::Str(QString::new(json_str)))
        }
        "json.stringify_pretty" | "stringify_pretty" => {
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
        "io.glob" | "glob" => {
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
        "glob_match" => {
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
        "io.read" | "read" => {
            if args.len() != 1 {
                return Err(format!("read expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = fs::read_to_string(&path)
                .map_err(|e| format!("Failed to read file '{}': {}", path, e))?;
            Ok(QValue::Str(QString::new(content)))
        }
        "io.write" | "write" => {
            if args.len() != 2 {
                return Err(format!("write expects 2 arguments, got {}", args.len()));
            }
            let path = args[0].as_str();
            let content = args[1].as_str();
            fs::write(&path, content)
                .map_err(|e| format!("Failed to write file '{}': {}", path, e))?;
            Ok(QValue::Nil(QNil))
        }
        "io.append" | "append" => {
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
        "io.exists" | "exists" => {
            if args.len() != 1 {
                return Err(format!("exists expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let exists = std::path::Path::new(&path).exists();
            Ok(QValue::Bool(QBool::new(exists)))
        }
        "is_file" => {
            if args.len() != 1 {
                return Err(format!("is_file expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let is_file = std::path::Path::new(&path).is_file();
            Ok(QValue::Bool(QBool::new(is_file)))
        }
        "is_dir" => {
            if args.len() != 1 {
                return Err(format!("is_dir expects 1 argument, got {}", args.len()));
            }
            let path = args[0].as_str();
            let is_dir = std::path::Path::new(&path).is_dir();
            Ok(QValue::Bool(QBool::new(is_dir)))
        }
        "size" => {
            if args.len() != 1 {
                return Err(format!("size expects 1 argument, got {}", args.len()));
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
        "hash.md5" | "md5" => {
            if args.len() != 1 {
                return Err(format!("md5 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use md5::Digest;
            let hash = format!("{:x}", Md5::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha1" | "sha1" => {
            if args.len() != 1 {
                return Err(format!("sha1 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha1::Digest;
            let hash = format!("{:x}", Sha1::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha256" | "sha256" => {
            if args.len() != 1 {
                return Err(format!("sha256 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", Sha256::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha512" | "sha512" => {
            if args.len() != 1 {
                return Err(format!("sha512 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", Sha512::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.crc32" | "crc32" => {
            if args.len() != 1 {
                return Err(format!("crc32 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let mut hasher = Crc32Hasher::new();
            hasher.update(data.as_bytes());
            let checksum = hasher.finalize();
            Ok(QValue::Str(QString::new(format!("{:08x}", checksum))))
        }
        // Encode module functions (base64)
        "encode.b64_encode" | "b64_encode" => {
            if args.len() != 1 {
                return Err(format!("b64_encode expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::STANDARD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "encode.b64_decode" | "b64_decode" => {
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
        "encode.b64_encode_url" | "b64_encode_url" => {
            if args.len() != 1 {
                return Err(format!("b64_encode_url expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            let encoded = general_purpose::URL_SAFE_NO_PAD.encode(data.as_bytes());
            Ok(QValue::Str(QString::new(encoded)))
        }
        "encode.b64_decode_url" | "b64_decode_url" => {
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

fn run_script(source: &str, args: &[String]) -> Result<(), String> {
    let mut scope = Scope::new();

    // Add sys module with argc and argv
    let sys_module = create_sys_module(args);
    scope.declare("sys", sys_module)?;

    // Trim trailing whitespace to avoid parse errors on empty lines
    let source = source.trim_end();

    // Parse as a program (allows comments and multiple statements)
    let pairs = QuestParser::parse(Rule::program, source)
        .map_err(|e| format!("Parse error: {}", e))?;

    // Evaluate each statement in the program
    let mut last_result = QValue::Nil(QNil);
    for pair in pairs {
        // Skip EOI and SOI
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }

        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }
            last_result = eval_pair(statement, &mut scope)?;
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

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    // Check if we have a script file argument
    if args.len() > 1 {
        let filename = &args[1];
        let source = fs::read_to_string(filename)
            .map_err(|e| format!("Failed to read file '{}': {}", filename, e))?;

        // Pass all arguments (including script name) to the script
        if let Err(e) = run_script(&source, &args[1..]) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
        return Ok(());
    }

    // Check if stdin is being piped
    if !io::stdin().is_terminal() {
        let mut source = String::new();
        io::stdin().read_to_string(&mut source)?;

        // For piped input, pass program name only
        if let Err(e) = run_script(&source, &args) {
            eprintln!("Error: {}", e);
            std::process::exit(1);
        }
        return Ok(());
    }

    // Otherwise, run interactive REPL
    run_repl()?;
    Ok(())
}
