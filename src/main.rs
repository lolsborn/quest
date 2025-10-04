use pest::Parser;
use pest_derive::Parser;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{self, IsTerminal, Read};
use std::rc::Rc;
use std::time::Instant;
use std::sync::OnceLock;

mod types;
use types::*;

mod modules;
use modules::*;

mod string_utils;
mod scope;
mod module_loader;
mod doc;
mod repl;
mod commands;
mod function_call;
mod numeric_ops;

use scope::Scope;
use module_loader::{load_external_module, extract_docstring};
use repl::{run_repl, show_help};
use commands::{run_script, handle_run_command};
use function_call::call_user_function;
use numeric_ops::apply_compound_op;

#[derive(Parser)]
#[grammar = "quest.pest"]
pub struct QuestParser;

// Program start time for ticks_ms() function
static START_TIME: OnceLock<Instant> = OnceLock::new();

fn get_start_time() -> &'static Instant {
    START_TIME.get_or_init(|| Instant::now())
}

// Script args and path (set once at script invocation, accessed when sys module is imported)
pub static SCRIPT_ARGS: OnceLock<Vec<String>> = OnceLock::new();
pub static SCRIPT_PATH: OnceLock<Option<String>> = OnceLock::new();

fn get_script_args() -> &'static [String] {
    SCRIPT_ARGS.get().map(|v| v.as_slice()).unwrap_or(&[])
}

fn get_script_path() -> Option<&'static str> {
    SCRIPT_PATH.get().and_then(|opt| opt.as_deref())
}

pub fn eval_expression(input: &str, scope: &mut Scope) -> Result<QValue, String> {
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

// apply_compound_op now imported from numeric_ops module

/// Apply a decorator to a function (QEP-003)
/// Decorators are applied by instantiating the decorator type with the function as first argument
fn apply_decorator(
    decorator_pair: &pest::iterators::Pair<Rule>,
    func: QValue,
    scope: &mut Scope
) -> Result<QValue, String> {
    // decorator = { "@" ~ decorator_expression }
    let decorator_expr = decorator_pair.clone().into_inner().next().unwrap();

    // decorator_expression = { identifier ~ ("." ~ identifier)* ~ decorator_args? }
    let inner = decorator_expr.into_inner();

    // Get decorator name (may have dots for module-qualified names)
    let mut decorator_name = String::new();
    let mut has_args = false;
    let mut args_pair = None;

    for part in inner {
        match part.as_rule() {
            Rule::identifier => {
                if !decorator_name.is_empty() {
                    decorator_name.push('.');
                }
                decorator_name.push_str(part.as_str());
            }
            Rule::decorator_args => {
                has_args = true;
                args_pair = Some(part);
            }
            _ => {}
        }
    }

    // Look up the decorator type
    let decorator_type = scope.get(&decorator_name)
        .ok_or_else(|| format!("Decorator '{}' not found", decorator_name))?;

    // Verify it's a type
    let qtype = match decorator_type {
        QValue::Type(t) => t,
        _ => return Err(format!("'{}' is not a type (decorators must be types)", decorator_name)),
    };

    // TODO: Verify type implements Decorator trait
    // For now, we just check if it has a _call method
    if qtype.get_method("_call").is_none() {
        return Err(format!(
            "Type '{}' cannot be used as decorator (missing _call() method)",
            qtype.name
        ));
    }

    // Evaluate decorator arguments (if any)
    if has_args {
        if let Some(args) = args_pair {
            let args_inner: Vec<_> = args.into_inner().collect();

            if args_inner.is_empty() {
                // No arguments - just pass the function
                return construct_struct(&qtype, vec![func], None, scope);
            }

            // Check if first argument is a named_arg
            if args_inner[0].as_rule() == Rule::named_arg {
                // Named arguments - collect into HashMap
                let mut named_args = HashMap::new();
                // First positional arg is always the function being decorated
                named_args.insert("func".to_string(), func);

                for arg in args_inner {
                    let mut arg_inner = arg.into_inner();
                    let name = arg_inner.next().unwrap().as_str().to_string();
                    let value = eval_pair(arg_inner.next().unwrap(), scope)?;
                    named_args.insert(name, value);
                }
                return construct_struct(&qtype, Vec::new(), Some(named_args), scope);
            } else {
                // Positional arguments
                let mut constructor_args = vec![func];
                for arg in args_inner {
                    let arg_value = eval_pair(arg, scope)?;
                    constructor_args.push(arg_value);
                }
                return construct_struct(&qtype, constructor_args, None, scope);
            }
        }
    }

    // No arguments - just pass the function
    construct_struct(&qtype, vec![func], None, scope)
}

pub fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    match pair.as_rule() {
        Rule::statement => {
            // A statement can be various things, just evaluate the inner
            let inner = pair.into_inner().next().unwrap();
            eval_pair(inner, scope)
        }
        Rule::pub_statement => {
            // pub let_statement | pub function_declaration | pub type_declaration | pub trait_declaration
            let inner_statement = pair.into_inner().next().unwrap();
            let rule = inner_statement.as_rule();

            // Evaluate the inner statement first
            let result = eval_pair(inner_statement.clone(), scope)?;

            // Mark declared items as public
            match rule {
                Rule::let_statement => {
                    for binding in inner_statement.into_inner() {
                        let mut binding_inner = binding.into_inner();
                        let identifier = binding_inner.next().unwrap().as_str();
                        scope.mark_public(identifier);
                    }
                }
                Rule::function_declaration => {
                    let mut func_inner = inner_statement.into_inner();
                    // Skip decorators
                    while func_inner.peek().map(|p| p.as_rule()) == Some(Rule::decorator) {
                        func_inner.next();
                    }
                    let func_name = func_inner.next().unwrap().as_str();
                    scope.mark_public(func_name);
                }
                Rule::type_declaration => {
                    let mut type_inner = inner_statement.into_inner();
                    let type_name = type_inner.next().unwrap().as_str();
                    scope.mark_public(type_name);
                }
                Rule::trait_declaration => {
                    let mut trait_inner = inner_statement.into_inner();
                    let trait_name = trait_inner.next().unwrap().as_str();
                    scope.mark_public(trait_name);
                }
                _ => {
                    return Err(format!("pub can only be used with let, fun, type, or trait declarations"));
                }
            }

            Ok(result)
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
                    let path = string_utils::parse_string(inner[0].as_str());
                    (path, None)
                }
                2 => {
                    // use "path" as alias
                    let path = string_utils::parse_string(inner[0].as_str());
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
                    "serial" => Some(create_serial_module()),
                    "regex" => Some(create_regex_module()),
                    "uuid" => Some(create_uuid_module()),
                    "decimal" => Some(create_decimal_module()),
                    "settings" => Some(create_settings_module()),
                    "sys" => Some(create_sys_module(get_script_args(), get_script_path())),
                    // Encoding modules (only new nested paths)
                    "encoding/b64" => Some(create_b64_module()),
                    "encoding/json" => Some(create_encoding_json_module()),
                    // Database modules
                    "db/sqlite" => Some(create_sqlite_module()),
                    "db/postgres" => Some(create_postgres_module()),
                    "db/mysql" => Some(create_mysql_module()),
                    // HTML modules
                    "html/templates" => Some(create_templates_module()),
                    // HTTP modules
                    "http/client" => Some(create_http_client_module()),
                    "test.q" | "test" => None, // std/test.q is a file, not built-in
                    _ => None, // Not a built-in, try filesystem
                };

                if let Some(module) = module_opt {
                    // Use provided alias or derive from builtin name (last segment for nested paths)
                    let alias = alias_opt.unwrap_or_else(|| {
                        builtin_name.split('/').last().unwrap_or(builtin_name).to_string()
                    });

                    // QEP-002: Apply Quest overlay if lib/{module_path}.q exists
                    let final_module = module_loader::apply_module_overlay(module, &path_str, scope)?;

                    scope.declare(&alias, final_module)?;
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
            // decorator* fun name(params) statements end
            let pair_str = pair.as_str();
            let mut inner = pair.into_inner();

            // Collect decorators first
            let mut decorators = Vec::new();
            let mut first_item = inner.next().unwrap();

            while first_item.as_rule() == Rule::decorator {
                decorators.push(first_item);
                first_item = inner.next().unwrap();
            }

            // Now first_item is the function name
            let name = first_item.as_str().to_string();

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
            // Skip decorators by finding "fun" keyword first
            let fun_start = pair_str.find("fun ").unwrap_or(0);
            let func_str = &pair_str[fun_start..];

            let body = if let Some(paren_pos) = func_str.find('(') {
                if let Some(close_paren) = func_str[paren_pos..].find(')') {
                    let after_params = paren_pos + close_paren + 1;
                    let mut body_str = &func_str[after_params..];

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
                    let after_name_idx = func_str.find(&name).unwrap() + name.len();
                    let mut body_str = &func_str[after_name_idx..];
                    body_str = body_str.trim_start();
                    if body_str.ends_with("end") {
                        body_str = &body_str[..body_str.len()-3].trim_end();
                    }
                    body_str.to_string()
                }
            } else {
                // No parentheses - parameterless function
                let after_name_idx = func_str.find(&name).unwrap() + name.len();
                let mut body_str = &func_str[after_name_idx..];
                body_str = body_str.trim_start();
                if body_str.ends_with("end") {
                    body_str = &body_str[..body_str.len()-3].trim_end();
                }
                body_str.to_string()
            };

            // Extract docstring from body
            let docstring = extract_docstring(&body);

            // Capture current scope for closure support
            let captured = function_call::capture_current_scope(scope);

            let mut func = QValue::UserFun(QUserFun::new(
                Some(name.clone()),
                params,
                body,
                docstring,
                captured
            ));

            // Apply decorators in reverse order (bottom to top)
            for decorator in decorators.iter().rev() {
                func = apply_decorator(decorator, func, scope)?;
            }

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
                let docstring_text = string_utils::parse_string(docstring_pair.as_str());
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

                                // Capture current scope for closure support
                                let captured = function_call::capture_current_scope(scope);
                                let func = QUserFun::new(Some(method_name.clone()), params.clone(), body, docstring, captured);

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

                                        // Capture current scope for closure support
                                        let captured = function_call::capture_current_scope(scope);
                                        methods.insert(method_name.clone(), QUserFun::new(
                                            Some(method_name),
                                            params,
                                            body,
                                            docstring,
                                            captured
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
                let docstring_text = string_utils::parse_string(docstring_pair.as_str());
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

                // Capture current scope for closure support
                let captured = function_call::capture_current_scope(scope);
                let func = QValue::UserFun(QUserFun::new(None, params, body, None, captured));
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

                    // Use method calls to preserve types (Int + Int = Int, Int + Num = Num)
                    result = match op {
                        "+" => {
                            match &result {
                                QValue::Int(i) => i.call_method("plus", vec![right])?,
                                QValue::Num(n) => n.call_method("plus", vec![right])?,
                                QValue::Float(f) => f.call_method("plus", vec![right])?,
                                QValue::Decimal(d) => d.call_method("plus", vec![right])?,
                                _ => {
                                    let left_num = result.as_num()?;
                                    let right_num = right.as_num()?;
                                    QValue::Num(QNum::new(left_num + right_num))
                                }
                            }
                        },
                        "-" => {
                            match &result {
                                QValue::Int(i) => i.call_method("minus", vec![right])?,
                                QValue::Num(n) => n.call_method("minus", vec![right])?,
                                QValue::Float(f) => f.call_method("minus", vec![right])?,
                                QValue::Decimal(d) => d.call_method("minus", vec![right])?,
                                _ => {
                                    let left_num = result.as_num()?;
                                    let right_num = right.as_num()?;
                                    QValue::Num(QNum::new(left_num - right_num))
                                }
                            }
                        },
                        _ => return Err(format!("Unknown operator: {}", op)),
                    };
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

                    // Use method calls to preserve types (Int * Int = Int, Int * Num = Num)
                    result = match op {
                        "*" => {
                            match &result {
                                QValue::Int(i) => i.call_method("times", vec![right])?,
                                QValue::Num(n) => n.call_method("times", vec![right])?,
                                QValue::Float(f) => f.call_method("times", vec![right])?,
                                QValue::Decimal(d) => d.call_method("times", vec![right])?,
                                _ => {
                                    let left_num = result.as_num()?;
                                    let right_num = right.as_num()?;
                                    QValue::Num(QNum::new(left_num * right_num))
                                }
                            }
                        },
                        "/" => {
                            match &result {
                                QValue::Int(i) => i.call_method("div", vec![right])?,
                                QValue::Num(n) => n.call_method("div", vec![right])?,
                                QValue::Float(f) => f.call_method("div", vec![right])?,
                                QValue::Decimal(d) => d.call_method("div", vec![right])?,
                                _ => {
                                    let left_num = result.as_num()?;
                                    let right_num = right.as_num()?;
                                    if right_num == 0.0 {
                                        return Err("Division by zero".to_string());
                                    }
                                    QValue::Num(QNum::new(left_num / right_num))
                                }
                            }
                        },
                        "%" => {
                            match &result {
                                QValue::Int(i) => i.call_method("mod", vec![right])?,
                                QValue::Num(n) => n.call_method("mod", vec![right])?,
                                QValue::Float(f) => f.call_method("mod", vec![right])?,
                                QValue::Decimal(d) => d.call_method("mod", vec![right])?,
                                _ => {
                                    let left_num = result.as_num()?;
                                    let right_num = right.as_num()?;
                                    QValue::Num(QNum::new(left_num % right_num))
                                }
                            }
                        },
                        _ => return Err(format!("Unknown operator: {}", op)),
                    };
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
                    "-" => {
                        match value {
                            QValue::Int(i) => Ok(QValue::Int(QInt::new(-i.value))),
                            QValue::Float(f) => Ok(QValue::Float(QFloat::new(-f.value))),
                            _ => Ok(QValue::Num(QNum::new(-value.as_num()?))),
                        }
                    },
                    "+" => {
                        match value {
                            QValue::Int(_) => Ok(value), // Unary plus does nothing for Int
                            QValue::Float(_) => Ok(value), // Unary plus does nothing for Float
                            _ => Ok(QValue::Num(QNum::new(value.as_num()?))),
                        }
                    },
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
                                        let mut module_scope = Scope::with_shared_base(
                                            module.get_members_ref(),
                                            Rc::clone(&scope.module_cache)
                                        );

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
                                            result = call_array_higher_order_method(arr, method_name, args, scope, call_user_function)?;
                                        }
                                        _ => {
                                            result = arr.call_method(method_name, args)?;
                                        }
                                    }
                                } else if let QValue::Dict(dict) = &result {
                                    // Special handling for dict higher-order functions
                                    match method_name {
                                        "each" => {
                                            result = call_dict_higher_order_method(dict, method_name, args, scope, call_user_function)?;
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
                                        QValue::Int(i) => i.call_method(method_name, args)?,
                                        QValue::Float(f) => f.call_method(method_name, args)?,
                                        QValue::Decimal(d) => d.call_method(method_name, args)?,
                                        QValue::Bool(b) => b.call_method(method_name, args)?,
                                        QValue::Str(s) => s.call_method(method_name, args)?,
                                        QValue::Bytes(b) => b.call_method(method_name, args)?,
                                        QValue::Fun(f) => f.call_method(method_name, args)?,
                                        QValue::UserFun(uf) => uf.call_method(method_name, args)?,
                                        QValue::Dict(d) => d.call_method(method_name, args)?,
                                        QValue::Exception(e) => e.call_method(method_name, args)?,
                                        QValue::Uuid(u) => u.call_method(method_name, args)?,
                                        QValue::Timestamp(ts) => ts.call_method(method_name, args)?,
                                        QValue::Zoned(z) => z.call_method(method_name, args)?,
                                        QValue::Date(d) => d.call_method(method_name, args)?,
                                        QValue::Time(t) => t.call_method(method_name, args)?,
                                        QValue::Span(s) => s.call_method(method_name, args)?,
                                        QValue::SerialPort(sp) => sp.call_method(method_name, args)?,
                                        QValue::SqliteConnection(conn) => conn.call_method(method_name, args)?,
                                        QValue::SqliteCursor(cursor) => cursor.call_method(method_name, args)?,
                                        QValue::PostgresConnection(conn) => conn.call_method(method_name, args)?,
                                        QValue::PostgresCursor(cursor) => cursor.call_method(method_name, args)?,
                                        QValue::MysqlConnection(conn) => conn.call_method(method_name, args)?,
                                        QValue::MysqlCursor(cursor) => cursor.call_method(method_name, args)?,
                                        QValue::HtmlTemplate(tmpl) => tmpl.call_method(method_name, args)?,
                                        QValue::HttpClient(client) => client.call_method(method_name, args)?,
                                        QValue::HttpRequest(req) => req.call_method(method_name, args)?,
                                        QValue::HttpResponse(resp) => resp.call_method(method_name, args)?,
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
                                result = QValue::Fun(QFun::new(
                                    method_name.to_string(),
                                    parent_type
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
                    // Check if this is a module (module.method() calls need special handling)
                    if let Some(QValue::Module(_)) = scope.get(func_name) {
                        // This is module.new() - treat as module function call
                        let function_name = format!("{}.new", func_name);
                        let mut args = Vec::new();
                        if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                for arg in args_pair.into_inner() {
                                    args.push(eval_pair(arg, scope)?);
                                }
                            }
                        }
                        // Dispatch to appropriate module function handler
                        return match func_name {
                            "decimal" => modules::call_decimal_function(&function_name, args),
                            "uuid" => modules::call_uuid_function(&function_name, args, scope),
                            "http" => modules::call_http_client_function(&function_name, args, scope),
                            _ => Err(format!("Unknown module function: {}", function_name)),
                        };
                    } else if let Some(QValue::Type(qtype)) = scope.get(func_name) {
                        // This is TypeName.new(...) constructor
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

                    // Check if it's a user-defined function or callable struct
                    if let Some(func_value) = scope.get(func_name) {
                        match func_value {
                            QValue::UserFun(user_fun) => {
                                return call_user_function(&user_fun, args, scope);
                            }
                            QValue::Struct(struct_inst) => {
                                // Check if struct has _call() method (callable decorator/functor)
                                if let Some(QValue::Type(qtype)) = scope.get(&struct_inst.type_name) {
                                    if let Some(call_method) = qtype.get_method("_call") {
                                        // Bind 'self' to the struct and call _call method
                                        scope.push();
                                        scope.declare("self", QValue::Struct(struct_inst.clone()))?;
                                        let result = call_user_function(call_method, args, scope)?;
                                        scope.pop();
                                        return Ok(result);
                                    } else {
                                        return Err(format!(
                                            "Type '{}' is not callable (missing _call() method)",
                                            struct_inst.type_name
                                        ));
                                    }
                                } else {
                                    return Err(format!("Type '{}' not found", struct_inst.type_name));
                                }
                            }
                            _ => {}
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
            let num_str = pair.as_str();
            // Check if it's an integer (no decimal point, no scientific notation)
            if !num_str.contains('.') && !num_str.contains('e') && !num_str.contains('E') {
                // Try to parse as integer
                if let Ok(int_value) = num_str.parse::<i64>() {
                    return Ok(QValue::Int(QInt::new(int_value)));
                }
            }
            // Parse as float (Float type for literals with decimal point or scientific notation)
            let value = num_str
                .parse::<f64>()
                .map_err(|e| format!("Invalid number: {}", e))?;
            Ok(QValue::Float(QFloat::new(value)))
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
        Rule::bytes_literal => {
            // Parse bytes literal: b"..."
            let s = pair.as_str();
            // Remove b" prefix and " suffix
            let content = &s[2..s.len()-1];

            let mut bytes = Vec::new();
            let mut chars = content.chars().peekable();

            while let Some(ch) = chars.next() {
                if ch == '\\' {
                    // Handle escape sequence
                    match chars.next() {
                        Some('x') => {
                            // Hex escape: \xFF
                            let hex1 = chars.next().ok_or("Invalid hex escape: missing first digit")?;
                            let hex2 = chars.next().ok_or("Invalid hex escape: missing second digit")?;
                            let hex_str = format!("{}{}", hex1, hex2);
                            let byte = u8::from_str_radix(&hex_str, 16)
                                .map_err(|_| format!("Invalid hex escape: \\x{}", hex_str))?;
                            bytes.push(byte);
                        }
                        Some('n') => bytes.push(b'\n'),
                        Some('r') => bytes.push(b'\r'),
                        Some('t') => bytes.push(b'\t'),
                        Some('0') => bytes.push(b'\0'),
                        Some('\\') => bytes.push(b'\\'),
                        Some('"') => bytes.push(b'"'),
                        Some(c) => return Err(format!("Invalid escape sequence: \\{}", c)),
                        None => return Err("Invalid escape sequence at end of bytes literal".to_string()),
                    }
                } else {
                    // Regular ASCII character
                    if ch.is_ascii() {
                        bytes.push(ch as u8);
                    } else {
                        return Err(format!("Non-ASCII character '{}' in bytes literal", ch));
                    }
                }
            }

            Ok(QValue::Bytes(QBytes::new(bytes)))
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
                            string_utils::process_escape_sequences(&s[1..s.len()-1])
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
                                        string_utils::format_value(&value, spec)?
                                    } else {
                                        value.as_str()
                                    };
                                    result.push_str(&formatted);
                                }
                                Rule::fstring_char => {
                                    let ch = part.as_str();
                                    result.push_str(&string_utils::process_escape_sequences(ch));
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
            let return_val = if let Some(expr) = inner.next() {
                eval_pair(expr, scope)?
            } else {
                QValue::Nil(QNil)
            };
            // Store the return value in scope and signal function return
            scope.return_value = Some(return_val);
            Err("__FUNCTION_RETURN__".to_string())
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
        Rule::doc_declaration => {
            // QEP-002: % documentation declarations
            // These are metadata only - they don't execute or declare anything
            // For now, we just parse and silently return nil
            // Phase 2 will extract and store this documentation for lazy loading
            Ok(QValue::Nil(QNil))
        }
        Rule::doc_fun | Rule::doc_const => {
            // These are inner rules that should only appear inside doc_declaration
            // But handle them gracefully just in case
            Ok(QValue::Nil(QNil))
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


fn call_builtin_function(func_name: &str, args: Vec<QValue>, scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        // Delegate sys.* functions to sys module
        name if name.starts_with("sys.") => {
            modules::call_sys_function(name, args, scope)
        }
        // Delegate time.* functions to time module
        name if name.starts_with("time.") => {
            modules::call_time_function(name, args, scope)
        }
        // Delegate crypto.* functions to crypto module
        name if name.starts_with("crypto.") => {
            modules::call_crypto_function(name, args, scope)
        }
        // Delegate math.* functions to math module
        name if name.starts_with("math.") => {
            modules::call_math_function(name, args, scope)
        }
        // Delegate term.* functions to term module
        name if name.starts_with("term.") => {
            modules::call_term_function(name, args, scope)
        }
        // Delegate os.* functions to os module
        name if name.starts_with("os.") => {
            modules::call_os_function(name, args, scope)
        }
        // Delegate io.* functions to io module
        name if name.starts_with("io.") => {
            modules::call_io_function(name, args, scope)
        }
        // Delegate json.* functions to encoding/json module
        name if name.starts_with("json.") => {
            modules::call_json_function(name, args, scope)
        }
        // Delegate hash.* functions to hash module
        name if name.starts_with("hash.") => {
            modules::call_hash_function(name, args, scope)
        }
        // Delegate regex.* functions to regex module
        name if name.starts_with("regex.") => {
            modules::call_regex_function(name, args, scope)
        }
        // Delegate serial.* functions to serial module
        name if name.starts_with("serial.") => {
            modules::call_serial_function(name, args, scope)
        }
        // Delegate uuid.* functions to uuid module
        name if name.starts_with("uuid.") => {
            modules::call_uuid_function(name, args, scope)
        }
        // Delegate decimal.* functions to decimal module
        name if name.starts_with("decimal.") => {
            modules::call_decimal_function(name, args)
        }
        // Delegate settings.* functions to settings module
        name if name.starts_with("settings.") => {
            modules::call_settings_function(name, args)
        }
        // Delegate templates.* functions to html/templates module
        name if name.starts_with("templates.") => {
            modules::call_templates_function(name, args, scope)
        }
        // Delegate http.* functions to http/client module
        name if name.starts_with("http.") => {
            modules::call_http_client_function(name, args, scope)
        }
        // Delegate sqlite.* functions to db/sqlite module
        name if name.starts_with("sqlite.") => {
            modules::call_sqlite_function(name, args, scope)
        }
        // Delegate postgres.* functions to db/postgres module
        name if name.starts_with("postgres.") => {
            modules::call_postgres_function(name, args, scope)
        }
        // Delegate mysql.* functions to db/mysql module
        name if name.starts_with("mysql.") => {
            modules::call_mysql_function(name, args, scope)
        }
        // Delegate b64.* functions to encoding/b64 module
        name if name.starts_with("b64.") => {
            modules::call_b64_function(name, args, scope)
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
        "is_array" => {
            if args.len() != 1 {
                return Err(format!("is_array expects 1 argument, got {}", args.len()));
            }
            let is_arr = matches!(&args[0], QValue::Array(_));
            Ok(QValue::Bool(QBool::new(is_arr)))
        }
        _ => Err(format!("Undefined function: {}", func_name)),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().collect();

    // Initialize settings from .settings.toml if it exists
    if let Err(e) = modules::init_settings() {
        eprintln!("Error loading .settings.toml: {}", e);
        std::process::exit(1);
    }

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
            // Don't add "Error: " prefix if the error already has it
            if e.starts_with("Error: ") || e.contains(": ") {
                eprintln!("{}", e);
            } else {
                eprintln!("Error: {}", e);
            }
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
            // Don't add "Error: " prefix if the error already has it
            if e.starts_with("Error: ") || e.contains(": ") {
                eprintln!("{}", e);
            } else {
                eprintln!("Error: {}", e);
            }
            std::process::exit(1);
        }
        return Ok(());
    }

    // Otherwise, run interactive REPL
    run_repl()?;
    Ok(())
}
