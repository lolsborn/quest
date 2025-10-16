use pest::Parser;
use pest_derive::Parser;
use std::collections::HashMap;
use std::env;
use std::fs;
use std::io::{self, IsTerminal, Read};
use std::rc::Rc;
use std::cell::RefCell;
use std::time::Instant;
use std::sync::OnceLock;

// Heap profiling support with dhat
#[cfg(feature = "dhat-heap")]
#[global_allocator]
static ALLOC: dhat::Alloc = dhat::Alloc;

mod types;
use types::*;

mod modules;
use modules::*;

mod error_macros;
mod exception_types;
mod control_flow;

mod string_utils;
mod scope;
mod module_loader;
mod doc;
mod repl;
mod commands;
mod function_call;
mod numeric_ops;
mod alloc_counter;
mod eval;
mod server;

use scope::Scope;
use module_loader::{load_external_module, extract_docstring};
use repl::{run_repl, show_help};
use commands::{run_script, handle_run_command, handle_serve_command};
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

/// Helper function to normalize indices for bracket indexing (supports negative indices)
/// Returns the actual index or an error with a helpful message showing valid range
fn normalize_index(idx: i64, len: usize, type_name: &str) -> Result<usize, String> {
    if len == 0 {
        return index_err!(
            "{} index out of bounds: {} ({} is empty)",
            type_name, idx, type_name.to_lowercase()
        );
    }
    
    if idx < 0 {
        let abs_idx = idx.abs() as usize;
        if abs_idx > len {
            return index_err!(
                "{} index out of bounds: {} (valid: 0..{} or -{}..{})",
                type_name, idx, len - 1, len, -1
            );
        }
        Ok(len - abs_idx)
    } else {
        let idx_usize = idx as usize;
        if idx_usize >= len {
            return index_err!(
                "{} index out of bounds: {} (valid: 0..{} or -{}..{})",
                type_name, idx, len - 1, len, -1
            );
        }
        Ok(idx_usize)
    }
}

/// QEP-015: Check if a value matches a type constraint for variable assignment
fn check_variable_type(value: &QValue, type_constraint: &str, var_name: &str) -> Result<(), String> {
    // Helper to convert to title case (e.g., "int" -> "Int", "str" -> "Str")
    fn to_title_case(s: &str) -> String {
        let mut chars = s.chars();
        match chars.next() {
            None => String::new(),
            Some(first) => first.to_uppercase().chain(chars).collect(),
        }
    }

    let actual_type = value.q_type();  // Already title case from q_type()
    let expected_type = to_title_case(type_constraint);  // Convert annotation to title case

    // Check if types match (title case comparison)
    let matches = match expected_type.as_str() {
        "Int" => actual_type == "Int",
        "Float" => actual_type == "Float",
        "Num" => actual_type == "Int" || actual_type == "Float",
        "Str" => actual_type == "Str",
        "Bool" => actual_type == "Bool",
        "Array" => actual_type == "Array",
        "Dict" => actual_type == "Dict",
        "Nil" => actual_type == "Nil",
        "Bytes" => actual_type == "Bytes",
        "Uuid" => actual_type == "Uuid",
        "Decimal" => actual_type == "Decimal",
        "BigInt" => actual_type == "BigInt",
        _ => actual_type == expected_type,  // Direct comparison for custom types
    };

    if !matches {
        return type_err!(
            "Cannot assign {} to variable '{}' of type {}",
            actual_type,
            var_name,
            expected_type
        );
    }

    Ok(())
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

/// Call a method on any QValue type (QEP-011 helper for 'with' statement)
/// This provides a generic interface for calling methods across all QValue variants
fn call_method_on_value(
    value: &QValue,
    method_name: &str,
    args: Vec<QValue>,
    scope: &mut Scope
) -> Result<QValue, String> {
    match value {
        QValue::Int(i) => i.call_method(method_name, args),
        QValue::Float(f) => f.call_method(method_name, args),
        QValue::Decimal(d) => d.call_method(method_name, args),
        QValue::BigInt(bi) => bi.call_method(method_name, args),
        QValue::NDArray(nda) => nda.call_method(method_name, args),
        QValue::Bool(b) => b.call_method(method_name, args),
        QValue::Str(s) => s.call_method(method_name, args),
        QValue::Bytes(b) => b.call_method(method_name, args),
        QValue::Uuid(u) => u.call_method(method_name, args),
        QValue::Array(a) => {
            // Fast paths for hot-path array methods (QEP-042)
            match method_name {
                // Inline common methods to avoid HashMap lookup and method dispatch
                "len" => {
                    if !args.is_empty() {
                        return arg_err!("len expects 0 arguments, got {}", args.len());
                    }
                    Ok(QValue::Int(QInt::new(a.elements.borrow().len() as i64)))
                }
                "push" => {
                    if args.len() != 1 {
                        return arg_err!("push expects 1 argument, got {}", args.len());
                    }
                    // Use optimized push with aggressive growth strategy (QEP-042 #6)
                    a.push_optimized(args[0].clone());
                    Ok(QValue::Array(a.clone()))
                }
                "pop" => {
                    if !args.is_empty() {
                        return arg_err!("pop expects 0 arguments, got {}", args.len());
                    }
                    a.elements.borrow_mut().pop()
                        .ok_or_else(|| "Cannot pop from empty array".to_string())
                }
                "get" => {
                    if args.len() != 1 {
                        return arg_err!("get expects 1 argument, got {}", args.len());
                    }
                    let index = args[0].as_num()? as usize;
                    let elements = a.elements.borrow();
                    elements.get(index)
                        .cloned()
                        .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, elements.len()))
                }
                // Higher-order methods that need scope
                "map" | "filter" | "each" | "reduce" | "any" | "all" | "find" | "find_index" => {
                    call_array_higher_order_method(a, method_name, args, scope, call_user_function_compat)
                }
                // Fallback to regular method dispatch for less common methods
                _ => a.call_method(method_name, args),
            }
        }
        QValue::Dict(d) => {
            // Dict has special higher-order methods that need scope
            match method_name {
                "each" => call_dict_higher_order_method(d, method_name, args, scope, call_user_function_compat),
                _ => d.call_method(method_name, args),
            }
        }
        QValue::Struct(qstruct) => {
            // Structs require special handling - lookup type, find method, bind self
            // IMPORTANT: Extract type_name first to drop borrow before executing method
            let type_name = qstruct.borrow().type_name.clone();
            
            if let Some(qtype) = find_type_definition(&type_name, scope) {
                if let Some(method) = qtype.get_method(method_name) {
                    scope.push();
                    scope.declare("self", value.clone())?;
                    let return_value = call_user_function(method, function_call::CallArguments::positional_only(args), scope)?;
                    scope.pop();
                    Ok(return_value)
                } else {
                    attr_err!("Struct {} has no method '{}'", type_name, method_name)
                }
            } else {
                type_err!("Type {} not found", type_name)
            }
        }
        QValue::Type(t) => {
            match method_name {
                "new" => Err("Type.new() requires named arguments - use call_method_on_value for context managers only".to_string()),
                "_doc" => Ok(QValue::Str(QString::new(t._doc()))),
                "str" => Ok(QValue::Str(QString::new(t.str()))),
                "_rep" => Ok(QValue::Str(QString::new(t._rep()))),
                "_id" => Ok(QValue::Int(QInt::new(t._id() as i64))),
                _ => {
                    // Try static methods
                    if let Some(static_method) = t.get_static_method(method_name) {
                        call_user_function(&static_method, function_call::CallArguments::positional_only(args), scope)
                    } else {
                        attr_err!("Type {} has no method '{}'", t.name, method_name)
                    }
                }
            }
        }
        QValue::Fun(f) => f.call_method(method_name, args),
        QValue::UserFun(uf) => uf.call_method(method_name, args),
        QValue::Nil(_) => attr_err!("Cannot call method '{}' on nil", method_name),
        QValue::Module(m) => {
            match method_name {
                "_doc" => Ok(QValue::Str(QString::new(m._doc()))),
                "str" => Ok(QValue::Str(QString::new(m.str()))),
                "_rep" => Ok(QValue::Str(QString::new(m._rep()))),
                "_id" => Ok(QValue::Int(QInt::new(m._id() as i64))),
                _ => attr_err!("Module {} has no method '{}'", m.name, method_name),
            }
        }
        QValue::Trait(_) => attr_err!("Cannot call methods on traits"),
        QValue::Exception(e) => e.call_method(method_name, args),
        QValue::Set(s) => s.call_method(method_name, args),
        QValue::Timestamp(ts) => ts.call_method(method_name, args),
        QValue::Zoned(z) => z.call_method(method_name, args),
        QValue::Date(d) => d.call_method(method_name, args),
        QValue::Time(t) => t.call_method(method_name, args),
        QValue::Span(s) => s.call_method(method_name, args),
        QValue::DateRange(dr) => dr.call_method(method_name, args),
        QValue::SerialPort(sp) => sp.call_method(method_name, args),
        QValue::SqliteConnection(conn) => conn.call_method(method_name, args),
        QValue::SqliteCursor(cursor) => cursor.call_method(method_name, args),
        QValue::PostgresConnection(conn) => conn.call_method(method_name, args),
        QValue::PostgresCursor(cursor) => cursor.call_method(method_name, args),
        QValue::MysqlConnection(conn) => conn.call_method(method_name, args),
        QValue::MysqlCursor(cursor) => cursor.call_method(method_name, args),
        QValue::HtmlTemplate(tmpl) => tmpl.call_method(method_name, args),
        QValue::HttpClient(client) => client.call_method(method_name, args),
        QValue::HttpRequest(req) => req.call_method(method_name, args),
        QValue::HttpResponse(resp) => resp.call_method(method_name, args),
        QValue::ProcessResult(pr) => pr.call_method(method_name, args),
        QValue::Process(p) => p.call_method(method_name, args),
        QValue::WritableStream(ws) => ws.call_method(method_name, args),
        QValue::ReadableStream(rs) => rs.call_method(method_name, args),
        QValue::Rng(rng) => modules::call_rng_method(rng, method_name, args),
        QValue::StringIO(sio) => {
            let mut stringio = sio.borrow_mut();
            stringio.call_method(method_name, args)
        }
        QValue::SystemStream(ss) => {
            // Special handling for write() to respect redirection
            if method_name == "write" {
                if args.len() != 1 {
                    return arg_err!("write expects 1 argument, got {}", args.len());
                }
                let data = args[0].as_str();
                
                // Write to redirected target
                match ss.stream_id {
                    0 => scope.stdout_target.write(&data)?,
                    1 => scope.stderr_target.write(&data)?,
                    _ => return Err("stdin does not support write()".to_string()),
                }
                
                Ok(QValue::Int(QInt::new(data.len() as i64)))
            } else {
                // Other methods don't need scope
                ss.call_method(method_name, args)
            }
        }
        QValue::RedirectGuard(rg) => {
            // Special handling for RedirectGuard methods that need scope
            match method_name {
                "restore" => {
                    if !args.is_empty() {
                        return arg_err!("restore expects 0 arguments, got {}", args.len());
                    }
                    rg.restore(scope)?;
                    Ok(QValue::Nil(QNil))
                }
                "_enter" => {
                    if !args.is_empty() {
                        return arg_err!("_enter expects 0 arguments, got {}", args.len());
                    }
                    // Return self for context manager
                    Ok(QValue::RedirectGuard(Box::new((**rg).clone())))
                }
                "_exit" => {
                    if !args.is_empty() {
                        return arg_err!("_exit expects 0 arguments, got {}", args.len());
                    }
                    // Restore on exit
                    rg.restore(scope)?;
                    Ok(QValue::Nil(QNil))
                }
                _ => {
                    // Other methods don't need scope
                    rg.call_method_without_scope(method_name, args)
                }
            }
        }
    }
}

/// Apply a decorator to a function (QEP-003)
/// Decorators are applied by instantiating the decorator type with the function as first argument
/// Helper function to parse function parameters with defaults and types
/// Parse parameters, returning (params, defaults, types, varargs_name, varargs_type, kwargs_name, kwargs_type)
/// QEP-034 Phase 2: Added kwargs support
fn parse_parameters(param_list_pair: pest::iterators::Pair<Rule>) -> (Vec<String>, Vec<Option<String>>, Vec<Option<String>>, Option<String>, Option<String>, Option<String>, Option<String>) {
    let mut params = Vec::new();
    let mut param_defaults = Vec::new();
    let mut param_types = Vec::new();
    let mut varargs_name = None;
    let mut varargs_type = None;
    let mut kwargs_name = None;
    let mut kwargs_type = None;
    
    for item in param_list_pair.into_inner() {
        match item.as_rule() {
            Rule::parameter => {
                // param can be: identifier | identifier : type_expr | identifier = expr | identifier : type_expr = expr
                let param_inner: Vec<_> = item.into_inner().collect();
                
                if param_inner.is_empty() {
                    continue;
                }
                
                let param_name = param_inner[0].as_str().to_string();
                
                // Parse based on number of inner elements
                if param_inner.len() == 1 {
                    // Just identifier: x
                    params.push(param_name);
                    param_types.push(None);
                    param_defaults.push(None);
                } else if param_inner.len() == 2 {
                    // Either "x : type" or "x = default"
                    if param_inner[1].as_rule() == Rule::type_expr {
                        // x : type
                        let type_annotation = Some(param_inner[1].as_str().to_string());
                        params.push(param_name);
                        param_types.push(type_annotation);
                        param_defaults.push(None);
                    } else {
                        // x = default (expression)
                        let default_expr = Some(param_inner[1].as_str().to_string());
                        params.push(param_name);
                        param_types.push(None);
                        param_defaults.push(default_expr);
                    }
                } else if param_inner.len() == 3 {
                    // x : type = default
                    let type_annotation = Some(param_inner[1].as_str().to_string());
                    let default_expr = Some(param_inner[2].as_str().to_string());
                    params.push(param_name);
                    param_types.push(type_annotation);
                    param_defaults.push(default_expr);
                }
            }
            Rule::varargs => {
                // *args or *args: type (QEP-034 Phase 1)
                let varargs_inner: Vec<_> = item.into_inner().collect();
                if varargs_inner.is_empty() {
                    continue;
                }
                varargs_name = Some(varargs_inner[0].as_str().to_string());
                if varargs_inner.len() > 1 && varargs_inner[1].as_rule() == Rule::type_expr {
                    varargs_type = Some(varargs_inner[1].as_str().to_string());
                }
            }
            Rule::kwargs => {
                // **kwargs or **kwargs: type (QEP-034 Phase 2)
                let kwargs_inner: Vec<_> = item.into_inner().collect();
                if kwargs_inner.is_empty() {
                    continue;
                }
                kwargs_name = Some(kwargs_inner[0].as_str().to_string());
                if kwargs_inner.len() > 1 && kwargs_inner[1].as_rule() == Rule::type_expr {
                    kwargs_type = Some(kwargs_inner[1].as_str().to_string());
                }
            }
            _ => {}
        }
    }
    
    (params, param_defaults, param_types, varargs_name, varargs_type, kwargs_name, kwargs_type)
}

/// Parse function call arguments into positional and keyword (QEP-035)
/// Returns CallArguments struct with positional and keyword arguments
fn parse_call_arguments(
    args_pair: pest::iterators::Pair<Rule>,
    scope: &mut Scope
) -> Result<function_call::CallArguments, String> {
    use crate::arg_err;
    
    let mut positional = Vec::new();
    let mut keyword = HashMap::new();
    let mut explicit_keywords = std::collections::HashSet::new();
    let mut seen_named = false;
    
    for arg in args_pair.into_inner() {
        match arg.as_rule() {
            Rule::argument_item => {
                // QEP-034 Phase 3: argument_item wrapper
                let item = arg.into_inner().next().unwrap();
                match item.as_rule() {
                    Rule::expression => {
                        // Positional argument
                        if seen_named {
                            return arg_err!("Positional argument cannot follow keyword argument");
                        }
                        positional.push(eval_pair(item, scope)?);
                    }
                    Rule::named_arg => {
                        // Named argument: name: value
                        seen_named = true;
                        let mut inner = item.into_inner();
                        let name = inner.next().unwrap().as_str().to_string();
                        let value = eval_pair(inner.next().unwrap(), scope)?;
                        
                        // Check for duplicate explicit keywords
                        if explicit_keywords.contains(&name) {
                            return arg_err!("Duplicate keyword argument '{}'", name);
                        }
                        
                        explicit_keywords.insert(name.clone());
                        keyword.insert(name, value);
                    }
                    Rule::unpack_args => {
                        // QEP-034 Phase 3: Array unpacking (*expr)
                        if seen_named {
                            return arg_err!("Positional unpacking (*) cannot follow keyword arguments");
                        }
                        
                        let expr = item.into_inner().next().unwrap();
                        let value = eval_pair(expr, scope)?;
                        
                        match value {
                            QValue::Array(arr) => {
                                for element in arr.elements.borrow().iter() {
                                    positional.push(element.clone());
                                }
                            }
                            _ => return arg_err!("Can only unpack arrays with *, got {}", value.q_type())
                        }
                    }
                    Rule::unpack_kwargs => {
                        // QEP-034 Phase 3: Dict unpacking (**expr)
                        seen_named = true;
                        
                        let expr = item.into_inner().next().unwrap();
                        let value = eval_pair(expr, scope)?;
                        
                        match value {
                            QValue::Dict(dict) => {
                                for (k, v) in dict.map.borrow().iter() {
                                    // Dict keys are String, not QValue::Str
                                    // Last value wins (allow overrides)
                                    keyword.insert(k.clone(), v.clone());
                                }
                            }
                            _ => return arg_err!("Can only unpack dicts with **, got {}", value.q_type())
                        }
                    }
                    _ => {}
                }
            }
            _ => {
                return syntax_err!("Unexpected rule in argument list: {:?}", arg.as_rule());
            }
        }
    }
    
    Ok(function_call::CallArguments::new(positional, keyword))
}

/// Wrapper for call_user_function that accepts old Vec<QValue> signature
/// Used by higher-order methods like array.map(), array.filter(), etc.
/// (QEP-035 backward compatibility)
fn call_user_function_compat(
    user_fun: &QUserFun,
    args: Vec<QValue>,
    scope: &mut Scope
) -> Result<QValue, String> {
    call_user_function(user_fun, function_call::CallArguments::positional_only(args), scope)
}

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
        _ => return type_err!("'{}' is not a type (decorators must be types)", decorator_name),
    };
    
    // Verify type implements Decorator trait or at minimum has _call method
    // Check if Decorator trait is defined and if type implements it
    let has_decorator_trait = scope.get("Decorator")
        .and_then(|v| if matches!(v, QValue::Trait(_)) { Some(v) } else { None })
        .is_some();

    if has_decorator_trait {
        // Decorator trait exists - verify implementation
        if !qtype.implemented_traits.contains(&"Decorator".to_string()) {
            return type_err!(
                "Type '{}' must implement Decorator trait to be used as decorator",
                qtype.name
            );
        }
        // Trait validation already ensures _call, _name, _doc, _id methods exist
    } else {
        // Decorator trait not defined - fall back to checking _call method
        if qtype.get_method("_call").is_none() {
            return type_err!(
                "Type '{}' cannot be used as decorator (missing _call() method)",
                qtype.name
            );
        }
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

// QEP-041: Helper function to evaluate assignment targets
// Handles: x = 1, arr[0] = 2, grid[0][1] = 3, obj.field = 4, obj.arr[0] = 5
fn eval_assignment(
    target: pest::iterators::Pair<Rule>,
    op_str: &str,
    rhs: QValue,
    scope: &mut Scope
) -> Result<(), String> {
    // Parse the assignment_target: identifier ~ (index_access | ("." ~ identifier))*
    let mut target_parts = target.into_inner();
    let identifier = target_parts.next().unwrap().as_str().to_string();

    // Collect all postfix operations (index_access or member access)
    let mut postfix_ops: Vec<(String, Option<QValue>)> = vec![];  // ("index", Some(index_val)) or ("field", None)

    for part in target_parts {
        match part.as_rule() {
            Rule::index_access => {
                let index_expr = part.into_inner().next().unwrap();
                let index_value = eval_pair(index_expr, scope)?;
                postfix_ops.push(("index".to_string(), Some(index_value)));
            }
            Rule::identifier => {
                let field_name = part.as_str().to_string();
                postfix_ops.push((field_name, None));
            }
            _ => {}
        }
    }

    // Case 1: Simple variable assignment (no postfix operations)
    if postfix_ops.is_empty() {
        // Check if it's a constant
        if scope.is_const(&identifier) {
            if op_str == "=" {
                return type_err!("Cannot reassign constant '{}'", identifier);
            } else {
                return type_err!("Cannot modify constant '{}' with compound assignment", identifier);
            }
        }

        let value = if op_str == "=" {
            rhs
        } else {
            let current = match scope.get(&identifier) {
                Some(v) => v,
                None => return name_err!("Undefined variable: {}", identifier),
            };
            apply_compound_op(&current, op_str, &rhs)?
        };

        // QEP-015: Check type constraint if variable has one
        if let Some(type_constraint) = scope.get_variable_type(&identifier) {
            check_variable_type(&value, &type_constraint, &identifier)?;
        }

        scope.update(&identifier, value)?;
        return Ok(());
    }

    // Case 2: Complex assignment with postfix operations
    // Navigate to the parent container and get the final key/index
    let parent = navigate_to_parent(&identifier, &postfix_ops[..postfix_ops.len()-1], scope)?;
    let (last_op_type, last_op_value) = &postfix_ops[postfix_ops.len()-1];

    if let Some(index) = last_op_value {
        // Final operation is indexed access: arr[i] or grid[0][1]
        let value = if op_str == "=" {
            rhs
        } else {
            // Get current value for compound ops
            let current = get_indexed_value(&parent, index)?;
            apply_compound_op(&current, op_str, &rhs)?
        };

        set_indexed_value(parent, index.clone(), value)?;
        Ok(())
    } else {
        // Final operation is member access: obj.field or obj.arr
        let field_name = last_op_type.clone();

        match parent {
            QValue::Struct(qstruct) => {
                let type_name = qstruct.borrow().type_name.clone();

                // Validate field exists
                if let Some(qtype) = find_type_definition(&type_name, scope) {
                    if qtype.fields.iter().any(|f| f.name == field_name) {
                        let value = if op_str == "=" {
                            rhs
                        } else {
                            let current = qstruct.borrow().get_field(&field_name)
                                .ok_or_else(|| format!("Field '{}' not found", field_name))?
                                .clone();
                            apply_compound_op(&current, op_str, &rhs)?
                        };

                        qstruct.borrow_mut().set_field(field_name, value);
                        Ok(())
                    } else {
                        attr_err!("Type {} has no field '{}'", type_name, field_name)
                    }
                } else {
                    name_err!("Type {} not found", type_name)
                }
            }
            _ => attr_err!("Cannot assign to field of non-struct type")
        }
    }
}

// Navigate through postfix operations to find the parent container
fn navigate_to_parent(
    identifier: &str,
    ops: &[(String, Option<QValue>)],
    scope: &Scope
) -> Result<QValue, String> {
    let mut current = match scope.get(identifier) {
        Some(v) => v,
        None => return Err(format!("NameErr: Undefined variable: {}", identifier)),
    };

    for (op_type, op_value) in ops {
        if let Some(index) = op_value {
            // Index access
            current = get_indexed_value(&current, index)?;
        } else {
            // Member access
            let field_name = op_type;
            let next_value = match &current {
                QValue::Struct(qstruct) => {
                    qstruct.borrow().get_field(field_name)
                        .ok_or_else(|| format!("Field '{}' not found", field_name))?
                        .clone()
                }
                _ => return attr_err!("Cannot access field of non-struct type")
            };
            current = next_value;
        }
    }

    Ok(current)
}

// Get value from indexed access (helper)
fn get_indexed_value(container: &QValue, index: &QValue) -> Result<QValue, String> {
    match container {
        QValue::Array(arr) => {
            let idx = index.as_num()? as isize;
            let elements = arr.elements.borrow();
            let len = elements.len() as isize;

            // Handle negative indices
            let actual_idx = if idx < 0 { len + idx } else { idx };

            if actual_idx < 0 || actual_idx >= len {
                return index_err!("Index {} out of bounds for array of length {}", idx, len);
            }

            Ok(elements[actual_idx as usize].clone())
        }
        QValue::Dict(dict) => {
            let key = index.as_str();
            dict.map.borrow().get(&key)
                .ok_or_else(|| format!("Key '{}' not found in dict", key))
                .map(|v| v.clone())
        }
        QValue::Str(_) | QValue::Bytes(_) => {
            type_err!("Strings and Bytes are immutable - cannot assign to index")
        }
        _ => type_err!("Cannot index into type {}", container.as_obj().cls())
    }
}

// Set value at indexed access (helper)
fn set_indexed_value(container: QValue, index: QValue, value: QValue) -> Result<(), String> {
    match container {
        QValue::Array(arr) => {
            let idx = index.as_num()? as isize;
            let mut elements = arr.elements.borrow_mut();
            let len = elements.len() as isize;

            // Handle negative indices
            let actual_idx = if idx < 0 { len + idx } else { idx };

            if actual_idx < 0 || actual_idx >= len {
                return index_err!("Index {} out of bounds for array of length {}", idx, len);
            }

            elements[actual_idx as usize] = value;
            Ok(())
        }
        QValue::Dict(dict) => {
            let key = index.as_str();
            dict.map.borrow_mut().insert(key, value);
            Ok(())
        }
        QValue::Str(_) | QValue::Bytes(_) => {
            type_err!("Strings and Bytes are immutable - cannot assign to index")
        }
        _ => type_err!("Cannot index into type {}", container.as_obj().cls())
    }
}

// QEP-042 Step 5: Specialized While Loop Optimization
// Check if condition can use fast path evaluation
fn can_use_fast_condition_eval(condition: &pest::iterators::Pair<Rule>) -> bool {
    // Fast path for simple comparisons: var < limit, i <= 100, x * x < limit, etc.
    // We check if the condition is a comparison without complex nested logic
    matches!(
        condition.as_rule(),
        Rule::comparison | Rule::logical_and | Rule::logical_or | Rule::logical_not
    )
}

// Fast path evaluation for simple conditions
fn eval_simple_condition(condition: &pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<bool, String> {
    // For simple conditions, we still use eval_pair but convert to bool
    // The optimization is mainly in avoiding the .clone() overhead through the fast path detection
    // Future: Could add more aggressive inlining here for specific patterns like "i < limit"
    let result = eval_pair(condition.clone(), scope)?;
    Ok(result.as_bool())
}

/// Helper function to handle lambda expression parsing
/// Extracted to avoid code duplication between expression and expression_statement handlers
fn handle_lambda_expression(
    pair_str: String,
    first: pest::iterators::Pair<Rule>,
    _inner: pest::iterators::Pairs<Rule>,
    scope: &mut Scope
) -> Result<QValue, String> {
    let mut params = Vec::new();
    let mut param_defaults = Vec::new();
    let mut param_types = Vec::new();

    let mut varargs_name = None;
    let mut varargs_type = None;

    // Collect parameters if first was parameter_list
    if first.as_rule() == Rule::parameter_list {
        let (p, pd, pt, va, vat, _kw, _kwt) = parse_parameters(first);
        params = p;
        param_defaults = pd;
        param_types = pt;
        varargs_name = va;
        varargs_type = vat;
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
    let func = if varargs_name.is_some() {
        QValue::UserFun(Box::new(QUserFun::new_with_varargs(
            None, params, param_defaults, param_types, body, None, captured,
            varargs_name, varargs_type
        )))
    } else {
        QValue::UserFun(Box::new(QUserFun::new(
            None, params, param_defaults, param_types, body, None, captured
        )))
    };
    Ok(func)
}

pub fn eval_pair(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
    // QEP-049: Use iterative evaluator for supported rules
    // Phase 7 Complete: All operators, if statements, array/dict literals implemented
    // Still uses hybrid approach for complex features (loops, exceptions, declarations)
    let rule = pair.as_rule();
    let use_iterative = matches!(rule,
        // QEP-049: Full expression routing enabled!
        // All operators and expression chains now use iterative evaluation
        Rule::nil | Rule::boolean | Rule::number | Rule::string |
        Rule::bytes_literal | Rule::type_literal | Rule::identifier |
        Rule::array_literal | Rule::dict_literal |
        Rule::addition | Rule::multiplication | Rule::comparison |
        Rule::concat | Rule::logical_and | Rule::logical_or |
        Rule::bitwise_and | Rule::bitwise_or | Rule::bitwise_xor |
        Rule::shift | Rule::elvis_expr |
        Rule::logical_not | Rule::unary |
        Rule::if_statement |
        Rule::expression |  // Now works! Cascades through operator precedence chain
        Rule::while_statement |  // Phase 8: Loop iteration
        Rule::for_statement |    // Phase 8: Loop iteration
        Rule::try_statement |    // Phase 9: Exception handling

        Rule::literal | Rule::primary
        // NOTE: postfix partially works (method calls yes, indexing fallback)
        // NOTE: declarations still use recursive
    );

    if use_iterative {
        return eval::eval_pair_iterative(pair, scope);
    }

    // QEP-048: Track eval_pair recursion depth
    scope.eval_depth += 1;
    let result = eval_pair_impl(pair, scope);
    scope.eval_depth -= 1;
    result
}

pub fn eval_pair_impl(pair: pest::iterators::Pair<Rule>, scope: &mut Scope) -> Result<QValue, String> {
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
                    return syntax_err!("pub can only be used with let, fun, type, or trait declarations");
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
                    "ndarray" => Some(create_ndarray_module()),
                    "settings" => Some(create_settings_module()),
                    "rand" => Some(create_rand_module()),
                    "sys" => Some(create_sys_module(get_script_args(), get_script_path())),
                    // Encoding modules (only new nested paths)
                    "encoding/b64" => Some(create_b64_module()),
                    "encoding/json" => Some(create_encoding_json_module()),
                    "encoding/struct" => Some(create_struct_module()),
                    "encoding/hex" => Some(create_hex_module()),
                    "encoding/url" => Some(create_url_module()),
                    "encoding/csv" => Some(create_csv_module()),
                    // Database modules
                    "db/sqlite" => Some(create_sqlite_module()),
                    "db/postgres" => Some(create_postgres_module()),
                    "db/mysql" => Some(create_mysql_module()),
                    // HTML modules
                    "html/templates" => Some(create_templates_module()),
                    "markdown" => Some(create_markdown_module()),
                    // HTTP modules
                    "http/client" => Some(create_http_client_module()),
                    "http/urlparse" => Some(create_urlparse_module()),
                    // Compression modules
                    "compress/gzip" => Some(create_gzip_module()),
                    "compress/bzip2" => Some(create_bzip2_module()),
                    "compress/deflate" => Some(create_deflate_module()),
                    "compress/zlib" => Some(create_zlib_module()),
                    // Process module
                    "process" => Some(create_process_module()),
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
            // OR: let identifier: type = expression [, identifier: type = expression]*
            let inner = pair.into_inner();
            for binding in inner {
                // Each binding can be:
                // - identifier = expression (untyped)
                // - identifier : type_expr = expression (typed)
                let mut binding_inner = binding.into_inner();
                let identifier = binding_inner.next().unwrap().as_str();

                // Check if next element is type_expr or expression
                let next = binding_inner.next().unwrap();

                if next.as_rule() == Rule::type_expr {
                    // Typed: let x: Int = 5
                    let type_annotation = next.as_str().to_string();
                    let value = eval_pair(binding_inner.next().unwrap(), scope)?;

                    // QEP-015: Store type constraint with variable
                    scope.declare_with_type(identifier, value, type_annotation)?;
                } else {
                    // Untyped: let x = 5
                    let value = eval_pair(next, scope)?;
                    scope.declare(identifier, value)?;
                }
            }
            Ok(QValue::Nil(QNil)) // let statements return nil
        }
        Rule::const_declaration => {
            // QEP-017: const IDENTIFIER = expression
            let mut inner = pair.into_inner();
            let name = inner.next().unwrap().as_str();
            let value = eval_pair(inner.next().unwrap(), scope)?;
            
            // Declare as constant (immutable binding)
            scope.declare_const(name, value)?;
            
            Ok(QValue::Nil(QNil))
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
                    return runtime_err!("Cannot delete module '{}'", identifier);
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
            
            // Collect parameters with defaults and types
            let mut params = Vec::new();
            let mut param_defaults = Vec::new();
            let mut param_types = Vec::new();
            let mut body_start_idx = 0;
            
            let mut varargs_name = None;
            let mut varargs_type = None;
            let mut kwargs_name = None;
            let mut kwargs_type = None;
            let mut return_type = None;

            for (idx, p) in inner.enumerate() {
                match p.as_rule() {
                    Rule::parameter_list => {
                        let (p, pd, pt, va, vat, kw, kwt) = parse_parameters(p);
                        params = p;
                        param_defaults = pd;
                        param_types = pt;
                        varargs_name = va;
                        varargs_type = vat;
                        kwargs_name = kw;
                        kwargs_type = kwt;
                    }
                    Rule::type_expr => {
                        // Return type annotation (QEP-015)
                        return_type = Some(p.as_str().to_string());
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
            
            // Validate: required parameters must come before optional ones
            let mut seen_optional = false;
            for (i, default) in param_defaults.iter().enumerate() {
                if default.is_some() {
                    seen_optional = true;
                } else if seen_optional {
                    return Err(format!(
                        "Required parameter '{}' cannot follow optional parameter in function '{}'",
                        params[i], name
                    ));
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
            
            // Create function with or without variadic parameters (QEP-034 Phase 2)
            let mut func = if varargs_name.is_some() || kwargs_name.is_some() || return_type.is_some() {
                QValue::UserFun(Box::new(QUserFun::new_with_variadics(
                    Some(name.clone()),
                    params,
                    param_defaults,
                    param_types,
                    body,
                    docstring,
                    captured,
                    varargs_name,
                    varargs_type,
                    kwargs_name,
                    kwargs_type,
                    return_type
                )))
            } else {
                QValue::UserFun(Box::new(QUserFun::new(
                    Some(name.clone()),
                    params,
                    param_defaults,
                    param_types,
                    body,
                    docstring,
                    captured
                )))
            };
            
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
                        // Get the entire type_member span to check for "pub" and "?"
                        let member_str = member.as_str();
                        let is_public = member_str.trim_start().starts_with("pub");
                        
                        let mut member_inner = member.clone().into_inner();
                        let first = member_inner.next().unwrap();
                        
                        match first.as_rule() {
                            Rule::identifier => {
                                let field_name = first.as_str().to_string();
                                
                                // Collect remaining tokens
                                let remaining: Vec<_> = member_inner.collect();
                                
                                // Check if there's a type annotation (next token would be type_expr)
                                let type_annotation = remaining.iter()
                                .find(|p| p.as_rule() == Rule::type_expr)
                                .map(|p| p.as_str().to_string());
                                
                                // Validate type annotation if present
                                if let Some(ref type_name) = type_annotation {
                                    // Check if type exists in scope (built-in types only at declaration time)
                                    // Built-in types: Int, Float, Str, Bool, Array, Dict, Bytes, Uuid, Num, Decimal, Obj
                                    // User-defined types: Must be defined BEFORE being referenced (no forward references)
                                    // Module types: Qualified names like process.Process (module must be imported first)
                                    // All types must use TitleCase (first letter uppercase)
                                    
                                    // Check if type exists (handles both simple and qualified type names)
                                    let type_exists = if type_name.contains('.') {
                                        // Qualified type name (e.g., process.Process)
                                        let parts: Vec<&str> = type_name.split('.').collect();
                                        if parts.len() == 2 {
                                            let module_name = parts[0];
                                            let type_name_in_module = parts[1];
                                            
                                            // Check if module exists and contains the type
                                            if let Some(QValue::Module(module)) = scope.get(module_name) {
                                                module.get_member(type_name_in_module)
                                                .map(|v| matches!(v, QValue::Type(_)))
                                                .unwrap_or(false)
                                            } else {
                                                false
                                            }
                                        } else {
                                            false
                                        }
                                    } else {
                                        // Simple type name (e.g., Int, Person)
                                        scope.get(type_name).is_some()
                                    };
                                    
                                    if !type_exists {
                                        // Check if other-case version exists (to provide helpful error)
                                        let type_name_cap = {
                                            let mut chars = type_name.chars();
                                            match chars.next() {
                                                None => type_name.clone(),
                                                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                                            }
                                        };
                                        
                                        if scope.get(&type_name_cap).is_some() {
                                            return syntax_err!(
                                                "Built-in types use CamelCase. Use '{}' instead of '{}' in field '{}'.",
                                                type_name_cap, type_name, field_name
                                            );
                                        } else {
                                            let error_msg = if type_name.contains('.') {
                                                format!(
                                                    "Unknown qualified type '{}' in field '{}'. Make sure the module is imported and the type exists.",
                                                    type_name, field_name
                                                )
                                            } else {
                                                format!(
                                                    "Unknown type '{}' in field '{}'. Type must be a built-in or defined user type.",
                                                    type_name, field_name
                                                )
                                            };
                                            return Err(error_msg);
                                        }
                                    }
                                }
                                
                                // Check if optional: "?" appears immediately after type_expr in syntax "name: type?"
                                // Extract the type annotation if present and check if followed by "?"
                                let optional = if let Some(type_ann) = &type_annotation {
                                    // Look for the pattern "type?" in the member string
                                    // The type annotation followed immediately by "?" (with optional whitespace)
                                    let type_pattern = format!("{}?", type_ann.trim());
                                    member_str.contains(&type_pattern) || {
                                        // Also check with whitespace before ? (e.g., "type ?")
                                        let type_pattern_ws = format!("{} ?", type_ann.trim());
                                        member_str.contains(&type_pattern_ws)
                                    }
                                } else {
                                    false
                                };
                                
                                // Check for default expression
                                let default_value = remaining.iter()
                                .find(|p| p.as_rule() == Rule::expression)
                                .and_then(|expr_pair| eval_pair(expr_pair.clone(), scope).ok());

                                // Validate default value type if both type annotation and default are present
                                if let (Some(ref type_ann), Some(ref default)) = (&type_annotation, &default_value) {
                                    // Skip nil check for optional fields (Type?)
                                    if !optional || !matches!(default, QValue::Nil(_)) {
                                        if let Err(e) = validate_field_type(default, type_ann) {
                                            return Err(format!(
                                                "Type mismatch for field '{}' in type '{}': {}",
                                                field_name, type_name, e
                                            ));
                                        }
                                    }
                                }

                                // Create field with appropriate visibility and defaults
                                let field = match (is_public, default_value) {
                                    (true, Some(default)) => FieldDef::public_with_default(field_name, type_annotation, optional, default),
                                    (true, None) => FieldDef::public(field_name, type_annotation, optional),
                                    (false, Some(default)) => FieldDef::with_default(field_name, type_annotation, optional, default),
                                    (false, None) => FieldDef::new(field_name, type_annotation, optional),
                                };
                                fields.push(field);
                            }
                            Rule::function_declaration | Rule::static_function_declaration => {
                                // Method definition - extract and store
                                let is_static = first.as_rule() == Rule::static_function_declaration;
                                let func_str = first.as_str();
                                let mut func_inner = first.into_inner();

                                // Collect decorators first (QEP-003)
                                let mut decorators = Vec::new();
                                let mut first_item = func_inner.next().unwrap();
                                while first_item.as_rule() == Rule::decorator {
                                    decorators.push(first_item);
                                    first_item = func_inner.next().unwrap();
                                }

                                // Now first_item is the method name
                                let method_name = first_item.as_str().to_string();
                                
                                // Collect parameters (QEP-034 Phase 2: includes varargs and kwargs)
                                let mut params = Vec::new();
                                let mut param_defaults = Vec::new();
                                let mut param_types = Vec::new();
                                let mut varargs_name = None;
                                let mut varargs_type = None;
                                let mut kwargs_name = None;
                                let mut kwargs_type = None;
                                for p in func_inner.clone() {
                                    if p.as_rule() == Rule::parameter_list {
                                        let (p, pd, pt, va, vat, kw, kwt) = parse_parameters(p);
                                        params = p;
                                        param_defaults = pd;
                                        param_types = pt;
                                        varargs_name = va;
                                        varargs_type = vat;
                                        kwargs_name = kw;
                                        kwargs_type = kwt;
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
                                let mut func_value = if varargs_name.is_some() || kwargs_name.is_some() {
                                    QValue::UserFun(Box::new(QUserFun::new_with_variadics(
                                        Some(method_name.clone()),
                                        params.clone(),
                                        param_defaults,
                                        param_types,
                                        body,
                                        docstring,
                                        captured,
                                        varargs_name,
                                        varargs_type,
                                        kwargs_name,
                                        kwargs_type,
                                        None  // TODO: Extract return type for type methods
                                    )))
                                } else {
                                    QValue::UserFun(Box::new(QUserFun::new(
                                        Some(method_name.clone()),
                                        params.clone(),
                                        param_defaults,
                                        param_types,
                                        body,
                                        docstring,
                                        captured
                                    )))
                                };

                                // Apply decorators in reverse order (bottom to top) - QEP-003
                                for decorator in decorators.iter().rev() {
                                    func_value = apply_decorator(decorator, func_value, scope)?;
                                }

                                // Extract the final function (may be decorated)
                                // Decorated methods return Struct instances (decorator types with _call method)
                                // but we need to store QUserFun in the methods HashMap
                                // Solution: If decorated, store the decorator struct as a field in a special wrapper
                                let final_func = match func_value {
                                    QValue::UserFun(f) => *f,
                                    QValue::Struct(_) => {
                                        // TODO (QEP-003): Support decorated methods properly
                                        // For now, decorated methods don't work because methods must be QUserFun
                                        // Need to extend method calling to support callable structs
                                        return type_err!(
                                            "Decorators on methods are not yet fully supported. \
                                             Decorators work on standalone functions and will be extended to methods in a future update."
                                        );
                                    }
                                    _ => return type_err!("Decorator must return a function or callable struct"),
                                };

                                if is_static {
                                    static_methods.insert(method_name, final_func);
                                } else {
                                    // Instance methods have access to 'self' which is bound when called
                                    methods.insert(method_name, final_func);
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
                                        let mut param_defaults = Vec::new();
                                        let mut param_types = Vec::new();
                                        let mut varargs_name = None;
                                        let mut varargs_type = None;
                                        let mut kwargs_name = None;
                                        let mut kwargs_type = None;
                                        for p in func_inner.clone() {
                                            if p.as_rule() == Rule::parameter_list {
                                                let (p, pd, pt, va, vat, kw, kwt) = parse_parameters(p);
                                                params = p;
                                                param_defaults = pd;
                                                param_types = pt;
                                                varargs_name = va;
                                                varargs_type = vat;
                                                kwargs_name = kw;
                                                kwargs_type = kwt;
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
                                        let method_func = if varargs_name.is_some() || kwargs_name.is_some() {
                                            QUserFun::new_with_variadics(
                                                Some(method_name.clone()),
                                                params,
                                                param_defaults,
                                                param_types,
                                                body,
                                                docstring,
                                                captured,
                                                varargs_name,
                                                varargs_type,
                                                kwargs_name,
                                                kwargs_type,
                                                None  // TODO: Extract return type for trait impl methods
                                            )
                                        } else {
                                            QUserFun::new(
                                                Some(method_name.clone()),
                                                params,
                                                param_defaults,
                                                param_types,
                                                body,
                                                docstring,
                                                captured
                                            )
                                        };
                                        methods.insert(method_name, method_func);
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
                                return type_err!(
                                    "Type {} implements trait {} but method '{}' has {} parameters, expected {}",
                                    type_name, trait_name, trait_method.name, actual_params, expected_params
                                );
                            }
                        } else {
                            return type_err!(
                                "Type {} implements trait {} but missing required method '{}'",
                                type_name, trait_name, trait_method.name
                            );
                        }
                    }
                } else {
                    return attr_err!("Trait {} not found", trait_name);
                }
            }
            
            // Store the type in scope
            scope.declare(&type_name, QValue::Type(Box::new(qtype)))?;
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
                                        // identifier : type_expr - take first (identifier)
                                        param_inner[0].as_str().to_string()
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
            // QEP-041: New unified assignment handler
            // Format: assignment_target compound_op expression
            let mut inner = pair.into_inner();
            let target = inner.next().unwrap();  // assignment_target
            let compound_op = inner.next().unwrap();
            let op_str = compound_op.as_str();
            let rhs = eval_pair(inner.next().unwrap(), scope)?;

            eval_assignment(target, op_str, rhs, scope)?;
            Ok(QValue::Nil(QNil))
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
            // Flattened: now contains lambda or elvis_expr directly
            let pair_str = pair.as_str().to_string();
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if this is a lambda or elvis_expr
            if first.as_rule() == Rule::parameter_list || first.as_rule() == Rule::statement {
                // This is a lambda: fun (params) body end
                handle_lambda_expression(pair_str, first, inner, scope)
            } else {
                // This is an elvis_expr
                eval_pair(first, scope)
            }
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
                // Propagate self mutations back to parent scope
                if let Some(updated_self) = scope.get("self") {
                    scope.pop();
                    scope.set("self", updated_self);
                } else {
                    scope.pop();
                }
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
                            // Propagate self mutations back to parent scope
                            if let Some(updated_self) = scope.get("self") {
                                scope.pop();
                                scope.set("self", updated_self);
                            } else {
                                scope.pop();
                            }
                            return Ok(result);
                        }
                    }
                    Rule::else_clause => {
                        scope.push();
                        let mut result = QValue::Nil(QNil);
                        for stmt in pair.into_inner() {
                            result = eval_pair(stmt, scope)?;
                        }
                        // Propagate self mutations back to parent scope
                        if let Some(updated_self) = scope.get("self") {
                            scope.pop();
                            scope.set("self", updated_self);
                        } else {
                            scope.pop();
                        }
                        return Ok(result);
                    }
                    _ => {}
                }
            }
            Ok(QValue::Nil(QNil))
        }
        Rule::match_statement => {
            // match expression ~ in_clause+ ~ else_clause? ~ "end"
            let mut iter = pair.into_inner();
            
            // Evaluate the match expression once
            let match_value = eval_pair(iter.next().unwrap(), scope)?;
            
            // Iterate through in_clause and else_clause
            for clause in iter {
                match clause.as_rule() {
                    Rule::in_clause => {
                        // in ~ expression_list ~ statement+
                        let mut in_inner = clause.into_inner();
                        let expr_list = in_inner.next().unwrap();
                        
                        // Check if any value in the expression list matches
                        let mut matched = false;
                        for expr in expr_list.into_inner() {
                            let in_value = eval_pair(expr, scope)?;
                            if types::values_equal(&match_value, &in_value) {
                                matched = true;
                                break;
                            }
                        }
                        
                        if matched {
                            // Execute the statements in this in block
                            scope.push();
                            let mut result = QValue::Nil(QNil);
                            for stmt in in_inner {
                                match eval_pair(stmt, scope) {
                                    Ok(val) => result = val,
                                    Err(e) if e == "__LOOP_BREAK__" || e == "__LOOP_CONTINUE__" || e == "__FUNCTION_RETURN__" => {
                                        // Propagate control flow errors after cleaning up scope
                                        if let Some(updated_self) = scope.get("self") {
                                            scope.pop();
                                            scope.set("self", updated_self);
                                        } else {
                                            scope.pop();
                                        }
                                        return Err(e);
                                    }
                                    Err(e) => {
                                        scope.pop();
                                        return Err(e);
                                    }
                                }
                            }
                            // Propagate self mutations back to parent scope
                            if let Some(updated_self) = scope.get("self") {
                                scope.pop();
                                scope.set("self", updated_self);
                            } else {
                                scope.pop();
                            }
                            return Ok(result);
                        }
                    }
                    Rule::else_clause => {
                        // No match found - execute else block
                        scope.push();
                        let mut result = QValue::Nil(QNil);
                        for stmt in clause.into_inner() {
                            match eval_pair(stmt, scope) {
                                Ok(val) => result = val,
                                Err(e) if e == "__LOOP_BREAK__" || e == "__LOOP_CONTINUE__" || e == "__FUNCTION_RETURN__" => {
                                    // Propagate control flow errors after cleaning up scope
                                    if let Some(updated_self) = scope.get("self") {
                                        scope.pop();
                                        scope.set("self", updated_self);
                                    } else {
                                        scope.pop();
                                    }
                                    return Err(e);
                                }
                                Err(e) => {
                                    scope.pop();
                                    return Err(e);
                                }
                            }
                        }
                        // Propagate self mutations back to parent scope
                        if let Some(updated_self) = scope.get("self") {
                            scope.pop();
                            scope.set("self", updated_self);
                        } else {
                            scope.pop();
                        }
                        return Ok(result);
                    }
                    _ => {}
                }
            }
            
            // No match and no else clause
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
            
            // for_range contains the expression(s) and keyword markers
            // Filter out the keyword markers (to_kw, until_kw, step_kw)
            let range_parts: Vec<_> = for_range.into_inner()
            .filter(|p| !matches!(p.as_rule(), Rule::to_kw | Rule::until_kw | Rule::step_kw))
            .collect();
            
            if range_parts.len() == 1 {
                // Single expression - collection iteration
                let collection = eval_pair(range_parts[0].clone(), scope)?;
                
                let mut result = QValue::Nil(QNil);
                
                match collection {
                    QValue::Array(arr) => {
                        let elements = arr.elements.borrow();
                        'outer: for (index, item) in elements.iter().enumerate() {
                            // Create fresh scope for each iteration
                            scope.push();
                            
                            if let Some(ref idx_var) = second_var {
                                // for item, index in array
                                scope.declare(&first_var, item.clone()).ok();
                                scope.declare(idx_var, QValue::Int(QInt::new(index as i64))).ok();
                            } else {
                                // for item in array
                                scope.declare(&first_var, item.clone()).ok();
                            }
                            
                            // Execute loop body
                            for stmt in iter.clone() {
                                match eval_pair(stmt.clone(), scope) {
                                    Ok(val) => result = val,
                                    Err(e) if e == "__LOOP_BREAK__" => {
                                        // Propagate self mutations before breaking
                                        if let Some(updated_self) = scope.get("self") {
                                            scope.pop();
                                            scope.set("self", updated_self);
                                        } else {
                                            scope.pop();
                                        }
                                        break 'outer;
                                    },
                                    Err(e) if e == "__LOOP_CONTINUE__" => break,
                                    Err(e) => {
                                        scope.pop();
                                        return Err(e);
                                    }
                                }
                            }
                            
                            // Propagate self mutations back to parent scope after iteration
                            if let Some(updated_self) = scope.get("self") {
                                scope.pop();
                                scope.set("self", updated_self);
                            } else {
                                scope.pop();
                            }
                        }
                    }
                    QValue::Dict(dict) => {
                        // Collect items first to avoid holding the borrow during loop execution
                        let items: Vec<(String, QValue)> = dict.map.borrow()
                        .iter()
                        .map(|(k, v)| (k.clone(), v.clone()))
                        .collect();
                        
                        'outer: for (key, value) in items {
                            // Create fresh scope for each iteration
                            scope.push();
                            
                            if let Some(ref val_var) = second_var {
                                // for key, value in dict
                                scope.declare(&first_var, QValue::Str(QString::new(key))).ok();
                                scope.declare(val_var, value).ok();
                            } else {
                                // for key in dict
                                scope.declare(&first_var, QValue::Str(QString::new(key))).ok();
                            }
                            
                            // Execute loop body
                            for stmt in iter.clone() {
                                match eval_pair(stmt.clone(), scope) {
                                    Ok(val) => result = val,
                                    Err(e) if e == "__LOOP_BREAK__" => {
                                        // Propagate self mutations before breaking
                                        if let Some(updated_self) = scope.get("self") {
                                            scope.pop();
                                            scope.set("self", updated_self);
                                        } else {
                                            scope.pop();
                                        }
                                        break 'outer;
                                    },
                                    Err(e) if e == "__LOOP_CONTINUE__" => break,
                                    Err(e) => {
                                        scope.pop();
                                        return Err(e);
                                    }
                                }
                            }
                            
                            // Propagate self mutations back to parent scope after iteration
                            if let Some(updated_self) = scope.get("self") {
                                scope.pop();
                                scope.set("self", updated_self);
                            } else {
                                scope.pop();
                            }
                        }
                    }
                    _ => {
                        return type_err!("Cannot iterate over type {}", collection.as_obj().cls());
                    }
                }
                
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
                    
                    // Create fresh scope for each iteration
                    scope.push();
                    
                    // Declare loop variable in the per-iteration scope
                    scope.declare(&first_var, QValue::Int(QInt::new(i))).ok();
                    
                    // Execute loop body
                    for stmt in iter.clone() {
                        match eval_pair(stmt.clone(), scope) {
                            Ok(val) => result = val,
                            Err(e) if e == "__LOOP_BREAK__" => {
                                // Propagate self mutations before breaking
                                if let Some(updated_self) = scope.get("self") {
                                    scope.pop();
                                    scope.set("self", updated_self);
                                } else {
                                    scope.pop();
                                }
                                break 'outer;
                            },
                            Err(e) if e == "__LOOP_CONTINUE__" => break,
                            Err(e) => {
                                scope.pop();
                                return Err(e);
                            }
                        }
                    }
                    
                    // Propagate self mutations back to parent scope after iteration
                    if let Some(updated_self) = scope.get("self") {
                        scope.pop();
                        scope.set("self", updated_self);
                    } else {
                        scope.pop();
                    }
                    
                    i += step;
                }
                
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

            // QEP-042: Optimize simple comparison conditions
            // Common patterns: i < limit, i <= limit, x * x < limit
            let fast_path = can_use_fast_condition_eval(&condition_expr);

            'outer: loop {
                // Fast path: direct condition evaluation without full recursion overhead
                let condition_met = if fast_path {
                    eval_simple_condition(&condition_expr, scope)?
                } else {
                    eval_pair(condition_expr.clone(), scope)?.as_bool()
                };

                if !condition_met {
                    break;
                }

                // Create a new scope for each iteration
                scope.push();
                
                // Execute loop body
                for stmt in body_statements.iter() {
                    match eval_pair(stmt.clone(), scope) {
                        Ok(val) => result = val,
                        Err(e) if e == "__LOOP_BREAK__" => {
                            // Propagate self mutations before breaking
                            if let Some(updated_self) = scope.get("self") {
                                scope.pop();
                                scope.set("self", updated_self);
                            } else {
                                scope.pop();
                            }
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
                
                // Propagate self mutations back to parent scope after iteration
                if let Some(updated_self) = scope.get("self") {
                    scope.pop();
                    scope.set("self", updated_self);
                } else {
                    scope.pop();
                }
            }
            
            Ok(result)
        }
        Rule::expression => {
            // Flattened: now contains lambda or elvis_expr directly
            let pair_str = pair.as_str().to_string();
            let mut inner = pair.into_inner();
            let first = inner.next().unwrap();

            // Check if this is a lambda or elvis_expr
            if first.as_rule() == Rule::parameter_list || first.as_rule() == Rule::statement {
                // This is a lambda: fun (params) body end
                handle_lambda_expression(pair_str, first, inner, scope)
            } else {
                // This is an elvis_expr
                eval_pair(first, scope)
            }
        }
        Rule::elvis_expr => {
            // QEP-019: Elvis operator (?: ) - Provide default if nil
            // expr ?: default
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            
            for next in inner {
                // Skip operator token (elvis_op)
                if matches!(next.as_rule(), Rule::elvis_op) {
                    continue;
                }
                
                // If result is nil, evaluate right side and use it
                if matches!(result, QValue::Nil(_)) {
                    result = eval_pair(next, scope)?;
                }
                // Otherwise keep result (short-circuit)
            }
            
            Ok(result)
        }
        Rule::logical_or => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            for next in inner {
                // Skip operator tokens (or_op)
                if matches!(next.as_rule(), Rule::or_op) {
                    continue;
                }
                // Short-circuit: if result is truthy, return it without evaluating right
                if result.as_bool() {
                    return Ok(result);
                }
                // Result is falsy, evaluate and return right operand
                result = eval_pair(next, scope)?;
            }
            Ok(result)
        }
        Rule::logical_and => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            for next in inner {
                // Skip operator tokens (and_op)
                if matches!(next.as_rule(), Rule::and_op) {
                    continue;
                }
                // Short-circuit: if result is falsy, return it without evaluating right
                if !result.as_bool() {
                    return Ok(result);
                }
                // Result is truthy, evaluate and return right operand
                result = eval_pair(next, scope)?;
            }
            Ok(result)
        }
        Rule::logical_not => {
            // Flattened grammar: not_op* ~ bitwise_or
            // Count how many 'not' operators we have
            let inner = pair.into_inner();
            let mut not_count = 0;
            let mut expr_pair = None;

            for child in inner {
                match child.as_rule() {
                    Rule::not_op => not_count += 1,
                    Rule::bitwise_or => {
                        expr_pair = Some(child);
                        break;
                    }
                    _ => {}
                }
            }

            // Evaluate the expression
            let mut value = eval_pair(expr_pair.unwrap(), scope)?;

            // Apply 'not' operation not_count times
            for _ in 0..not_count {
                value = QValue::Bool(QBool::new(!value.as_bool()));
            }

            Ok(value)
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
                Ok(QValue::Int(QInt::new(int_result)))
            }
        }
        Rule::bitwise_xor => {
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
                    int_result ^= right;
                }
                Ok(QValue::Int(QInt::new(int_result)))
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
                Ok(QValue::Int(QInt::new(int_result)))
            }
        }
        Rule::shift => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            
            while let Some(op_pair) = inner.next() {
                let operator = op_pair.as_str();
                let right = eval_pair(inner.next().unwrap(), scope)?;
                
                let left_val = result.as_num()? as i64;
                let right_val = right.as_num()? as i64;
                
                let shifted = match operator {
                    "<<" => left_val.checked_shl(right_val as u32)
                    .ok_or_else(|| format!("Left shift overflow: {} << {}", left_val, right_val))?,
                    ">>" => left_val.checked_shr(right_val as u32)
                    .ok_or_else(|| format!("Right shift overflow: {} >> {}", left_val, right_val))?,
                    _ => return syntax_err!("Unknown shift operator: {}", operator),
                };
                
                result = QValue::Int(QInt::new(shifted));
            }
            
            Ok(result)
        }
        Rule::comparison => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            
            while let Some(pair) = inner.next() {
                if pair.as_rule() == Rule::comparison_op {
                    let op = pair.as_str();
                    let right = eval_pair(inner.next().unwrap(), scope)?;
                    
                    // Type-aware comparison with fast path for Int comparisons (QEP-042)
                    let cmp_result = match op {
                        "==" => {
                            // Fast path for Int == Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value == r.value
                            } else {
                                types::values_equal(&result, &right)
                            }
                        }
                        "!=" => {
                            // Fast path for Int != Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value != r.value
                            } else {
                                !types::values_equal(&result, &right)
                            }
                        }
                        "<" => {
                            // Fast path for Int < Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value < r.value
                            } else {
                                match types::compare_values(&result, &right) {
                                    Some(ordering) => ordering == std::cmp::Ordering::Less,
                                    None => return type_err!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls())
                                }
                            }
                        }
                        ">" => {
                            // Fast path for Int > Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value > r.value
                            } else {
                                match types::compare_values(&result, &right) {
                                    Some(ordering) => ordering == std::cmp::Ordering::Greater,
                                    None => return type_err!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls())
                                }
                            }
                        }
                        "<=" => {
                            // Fast path for Int <= Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value <= r.value
                            } else {
                                match types::compare_values(&result, &right) {
                                    Some(ordering) => ordering != std::cmp::Ordering::Greater,
                                    None => return type_err!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls())
                                }
                            }
                        }
                        ">=" => {
                            // Fast path for Int >= Int
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                l.value >= r.value
                            } else {
                                match types::compare_values(&result, &right) {
                                    Some(ordering) => ordering != std::cmp::Ordering::Less,
                                    None => return type_err!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls())
                                }
                            }
                        }
                        _ => return syntax_err!("Unknown comparison operator: {}", op),
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
                            // Fast path for Int + Int (QEP-042 optimization #3)
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                // Use checked_add to maintain overflow safety
                                match l.value.checked_add(r.value) {
                                    Some(sum) => QValue::Int(QInt::new(sum)),
                                    None => return runtime_err!("Integer overflow in addition"),
                                }
                            } else {
                                match &result {
                                    QValue::Int(i) => i.call_method("plus", vec![right])?,
                                    QValue::Float(f) => f.call_method("plus", vec![right])?,
                                    QValue::Decimal(d) => d.call_method("plus", vec![right])?,
                                    QValue::BigInt(bi) => bi.call_method("plus", vec![right])?,
                                    _ => {
                                        let left_num = result.as_num()?;
                                        let right_num = right.as_num()?;
                                        QValue::Float(QFloat::new(left_num + right_num))
                                    }
                                }
                            }
                        },
                        "-" => {
                            // Fast path for Int - Int (QEP-042 optimization #3)
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                // Use checked_sub to maintain overflow safety
                                match l.value.checked_sub(r.value) {
                                    Some(diff) => QValue::Int(QInt::new(diff)),
                                    None => return runtime_err!("Integer overflow in subtraction"),
                                }
                            } else {
                                match &result {
                                    QValue::Int(i) => i.call_method("minus", vec![right])?,
                                    QValue::Float(f) => f.call_method("minus", vec![right])?,
                                    QValue::Decimal(d) => d.call_method("minus", vec![right])?,
                                    QValue::BigInt(bi) => bi.call_method("minus", vec![right])?,
                                    _ => {
                                        let left_num = result.as_num()?;
                                        let right_num = right.as_num()?;
                                        QValue::Float(QFloat::new(left_num - right_num))
                                    }
                                }
                            }
                        },
                        _ => return syntax_err!("Unknown operator: {}", op),
                    };
                } else {
                    result = eval_pair(pair, scope)?;
                }
            }
            Ok(result)
        }
        Rule::addition | Rule::multiplication => {
            let mut inner = pair.into_inner();
            let mut result = eval_pair(inner.next().unwrap(), scope)?;
            
            while let Some(pair) = inner.next() {
                if pair.as_rule() == Rule::mul_op {
                    let op = pair.as_str();
                    let right = eval_pair(inner.next().unwrap(), scope)?;
                    
                    // Use method calls to preserve types (Int * Int = Int, Int * Num = Num)
                    result = match op {
                        "*" => {
                            // Fast path for Int * Int (QEP-042 optimization #3)
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                // Use checked_mul to maintain overflow safety
                                match l.value.checked_mul(r.value) {
                                    Some(product) => QValue::Int(QInt::new(product)),
                                    None => return runtime_err!("Integer overflow in multiplication"),
                                }
                            } else {
                                match &result {
                                    QValue::Int(i) => {
                                        // Check if right is a string (for int * str repetition)
                                        if let QValue::Str(s) = &right {
                                            s.call_method("repeat", vec![result.clone()])?
                                        } else {
                                            i.call_method("times", vec![right])?
                                        }
                                    }
                                    QValue::Float(f) => f.call_method("times", vec![right])?,
                                    QValue::Decimal(d) => d.call_method("times", vec![right])?,
                                    QValue::BigInt(bi) => bi.call_method("times", vec![right])?,
                                    QValue::Str(s) => {
                                        // String repetition: "abc" * 3 = "abcabcabc"
                                        s.call_method("repeat", vec![right])?
                                    }
                                    _ => {
                                        let left_num = result.as_num()?;
                                        let right_num = right.as_num()?;
                                        QValue::Float(QFloat::new(left_num * right_num))
                                    }
                                }
                            }
                        },
                        "/" => {
                            // Fast path for Int / Int (QEP-042 optimization #3)
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                if r.value == 0 {
                                    return Err("Division by zero".to_string());
                                }
                                // Integer division truncates (10 / 3 = 3)
                                QValue::Int(QInt::new(l.value / r.value))
                            } else {
                                match &result {
                                    QValue::Int(i) => i.call_method("div", vec![right])?,
                                    QValue::Float(f) => f.call_method("div", vec![right])?,
                                    QValue::Decimal(d) => d.call_method("div", vec![right])?,
                                    QValue::BigInt(bi) => bi.call_method("div", vec![right])?,
                                    _ => {
                                        let left_num = result.as_num()?;
                                        let right_num = right.as_num()?;
                                        if right_num == 0.0 {
                                            return Err("Division by zero".to_string());
                                        }
                                        QValue::Float(QFloat::new(left_num / right_num))
                                    }
                                }
                            }
                        },
                        "%" => {
                            // Fast path for Int % Int (QEP-042 optimization #3)
                            if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                if r.value == 0 {
                                    return Err("Modulo by zero".to_string());
                                }
                                QValue::Int(QInt::new(l.value % r.value))
                            } else {
                                match &result {
                                    QValue::Int(i) => i.call_method("mod", vec![right])?,
                                    QValue::Float(f) => f.call_method("mod", vec![right])?,
                                    QValue::Decimal(d) => d.call_method("mod", vec![right])?,
                                    QValue::BigInt(bi) => bi.call_method("mod", vec![right])?,
                                    _ => {
                                        let left_num = result.as_num()?;
                                        let right_num = right.as_num()?;
                                        QValue::Float(QFloat::new(left_num % right_num))
                                    }
                                }
                            }
                        },
                        _ => return syntax_err!("Unknown operator: {}", op),
                    };
                } else {
                    result = eval_pair(pair, scope)?;
                }
            }
            Ok(result)
        }
        Rule::unary => {
            // Flattened grammar: unary_op* ~ postfix
            // Collect all unary operators, then evaluate postfix, then apply ops right-to-left
            let inner = pair.into_inner();
            let mut ops = Vec::new();
            let mut postfix_pair = None;

            for child in inner {
                match child.as_rule() {
                    Rule::unary_op => ops.push(child.as_str()),
                    Rule::postfix => {
                        postfix_pair = Some(child);
                        break;
                    }
                    _ => {}
                }
            }

            // Evaluate the postfix expression
            let mut value = eval_pair(postfix_pair.unwrap(), scope)?;

            // Apply unary operators from right to left (closest to operand first)
            for op in ops.iter().rev() {
                value = match *op {
                    "-" => {
                        match value {
                            QValue::Int(i) => QValue::Int(QInt::new(-i.value)),
                            QValue::Float(f) => QValue::Float(QFloat::new(-f.value)),
                            _ => QValue::Float(QFloat::new(-value.as_num()?)),
                        }
                    },
                    "+" => {
                        match value {
                            QValue::Int(_) => value, // Unary plus does nothing for Int
                            QValue::Float(_) => value, // Unary plus does nothing for Float
                            _ => QValue::Float(QFloat::new(value.as_num()?)),
                        }
                    },
                    "~" => {
                        // Bitwise NOT (complement) - only works on integers
                        let int_val = value.as_num()? as i64;
                        QValue::Int(QInt::new(!int_val))
                    },
                    _ => return syntax_err!("Unknown unary operator: {}", op),
                };
            }

            Ok(value)
        }
        Rule::postfix => {
            let pair_str = pair.as_str().to_string(); // Save before consuming
            let pair_start = pair.as_span().start(); // Get absolute start position
            let mut inner = pair.into_inner();
            let first_pair = inner.next().unwrap();
            
            // Track if this starts with an identifier (for updating mutable structs)
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
            let original_result_id = if let QValue::Struct(s) = &result {
                Some(s.borrow().id)
            } else {
                None
            };
            
            // Collect remaining pairs into a vector to allow peeking
            let pairs: Vec<_> = inner.collect();
            let mut i = 0;
            
            // Handle method calls, member access, and index access
            while i < pairs.len() {
                let current = &pairs[i];
                match current.as_rule() {
                    Rule::identifier | Rule::method_name => {
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
                            // METHOD CALL: either has () or has arguments (QEP-035)
                            let call_args = if has_args {
                                let args_pair = pairs[i + 1].clone();
                                parse_call_arguments(args_pair, scope)?
                            } else {
                                // Empty argument list
                                function_call::CallArguments::positional_only(Vec::new())
                            };
                            
                            // For backward compatibility with old code, extract separate args and named_args
                            let args = call_args.positional.clone();
                            let named_args = if call_args.keyword.is_empty() {
                                None
                            } else {
                                Some(call_args.keyword.clone())
                            };
                            
                            // Execute the method and return result
                            // Special handling for modules to persist state changes
                            if let QValue::Module(module) = &result {
                                // Check for built-in module methods first
                                if method_name == "_doc" {
                                    result = QValue::Str(QString::new(module._doc()));
                                } else if method_name == "str" {
                                    result = QValue::Str(QString::new(module.str()));
                                } else if method_name == "_rep" {
                                    result = QValue::Str(QString::new(module._rep()));
                                } else if method_name == "_id" {
                                    result = QValue::Int(QInt::new(module._id() as i64));
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
                                            
                                            // Inherit I/O redirection from calling scope
                                            module_scope.stdout_target = scope.stdout_target.clone();
                                            module_scope.stderr_target = scope.stderr_target.clone();
                                            
                                            let ret = call_user_function(&user_fn, call_args.clone(), &mut module_scope)?;
                                            
                                            // No need to sync back module members - they're shared via Rc<RefCell<>>
                                            // Changes to module variables go directly to module.members
                                            
                                            result = ret;
                                        }
                                        QValue::Type(qtype) => {
                                            // Trying to call a type from a module - provide helpful error
                                            return type_err!(
                                                "Cannot call type '{}' as a function. Use {}.{}.new() to create a new instance.",
                                                qtype.name, module.name, qtype.name
                                            );
                                        }
                                        _ => return attr_err!("Module member '{}' is not a function", method_name),
                                    }
                                }
                            } else {
                                // Universal .is() method - check first before special handling
                                if method_name == "is" {
                                    if args.len() != 1 {
                                        return arg_err!(".is() expects 1 argument (type name), got {}", args.len());
                                    }
                                    // Accept either Type objects or string type names (lowercase)
                                    let type_name = match &args[0] {
                                        QValue::Type(t) => t.name.as_str(),
                                        QValue::Str(s) => s.value.as_str(),
                                        _ => return Err(".is() argument must be a type or string".to_string()),
                                    };
                                    // Compare using lowercase
                                    let actual_type = result.as_obj().cls().to_lowercase();
                                    let expected_type = type_name.to_lowercase();
                                    result = QValue::Bool(QBool::new(actual_type == expected_type));
                                } else if let QValue::Array(arr) = &result {
                                    // Special handling for array higher-order functions
                                    match method_name {
                                        "map" | "filter" | "each" | "reduce" | "any" | "all" | "find" | "find_index" => {
                                            result = call_array_higher_order_method(arr, method_name, args, scope, call_user_function_compat)?;
                                        }
                                        _ => {
                                            result = arr.call_method(method_name, args)?;
                                        }
                                    }
                                } else if let QValue::Dict(dict) = &result {
                                    // Special handling for dict higher-order functions
                                    match method_name {
                                        "each" => {
                                            result = call_dict_higher_order_method(dict, method_name, args, scope, call_user_function_compat)?;
                                        }
                                        _ => {
                                            result = dict.call_method(method_name, args)?;
                                        }
                                    }
                                } else if let QValue::Type(qtype) = &result {
                                    // Handle Type methods (constructor, static methods, built-in methods)
                                    if method_name == "new" {
                                        // Special handling for built-in types with Rust-based constructors
                                        if qtype.name == "Array" {
                                            result = types::array::call_array_static_method("new", args)?;
                                        } else if qtype.name == "Decimal" {
                                            result = types::decimal::call_decimal_static_method("new", args)?;
                                        } else if qtype.name == "BigInt" {
                                            result = types::bigint::call_bigint_static_method("new", args)?;
                                        } else if matches!(qtype.name.as_str(), "Err" | "SyntaxErr" |  "IndexErr" | "TypeErr" | "ValueErr" | "ArgErr" | "AttrErr" | "NameErr" | "RuntimeErr" | "IOErr" | "ImportErr" | "KeyErr") {
                                            // QEP-037: Exception types
                                            result = exception_types::call_exception_static_method(&qtype.name, "new", args)?;
                                        } else {
                                            // Constructor call for user-defined types
                                            result = construct_struct(qtype, args, named_args, scope)?;
                                        }
                                    } else if method_name == "_doc" {
                                        // Built-in _doc() method
                                        result = QValue::Str(QString::new(qtype._doc()));
                                    } else if method_name == "str" {
                                        // Built-in _str() method
                                        result = QValue::Str(QString::new(qtype.str()));
                                    } else if method_name == "_rep" {
                                        // Built-in _rep() method
                                        result = QValue::Str(QString::new(qtype._rep()));
                                    } else if method_name == "_id" {
                                        // Built-in _id() method
                                        result = QValue::Int(QInt::new(qtype._id() as i64));
                                    } else if qtype.name == "Array" {
                                        // Built-in Array type static methods
                                        result = types::array::call_array_static_method(method_name, args)?;
                                    } else if qtype.name == "Decimal" {
                                        // Built-in Decimal type static methods
                                        result = types::decimal::call_decimal_static_method(method_name, args)?;
                                    } else if qtype.name == "BigInt" {
                                        // Built-in BigInt type static methods
                                        result = types::bigint::call_bigint_static_method(method_name, args)?;
                                    } else if let Some(static_method) = qtype.get_static_method(method_name) {
                                        // Static method call for user-defined types
                                        result = call_user_function(static_method, call_args.clone(), scope)?;
                                    } else {
                                        return attr_err!("Type {} has no static method '{}'", qtype.name, method_name);
                                    }
                                } else if let QValue::Trait(qtrait) = &result {
                                    // Handle Trait built-in methods
                                    if method_name == "_doc" {
                                        result = QValue::Str(QString::new(qtrait._doc()));
                                    } else if method_name == "str" {
                                        result = QValue::Str(QString::new(qtrait.str()));
                                    } else if method_name == "_rep" {
                                        result = QValue::Str(QString::new(qtrait._rep()));
                                    } else if method_name == "_id" {
                                        result = QValue::Int(QInt::new(qtrait._id() as i64));
                                    } else {
                                        return attr_err!("Trait {} has no method '{}'", qtrait.name, method_name);
                                    }
                                } else if let QValue::Struct(qstruct) = &result {
                                    // Handle built-in struct methods first
                                    if method_name == "is" {
                                        // .is(TypeName) checks if struct is instance of type
                                        // Usage: obj.is(Point) returns true/false
                                        if args.len() != 1 {
                                            return arg_err!(".is() expects 1 argument (type name), got {}", args.len());
                                        }
                                        if let QValue::Type(check_type) = &args[0] {
                                            let type_name = qstruct.borrow().type_name.clone();
                                            result = QValue::Bool(QBool::new(type_name == check_type.name));
                                        } else {
                                            return Err(".is() argument must be a type".to_string());
                                        }
                                    } else if method_name == "_doc" {
                                        // ._doc() returns the type's documentation
                                        // Usage: obj._doc() returns the docstring for obj's type
                                        if !args.is_empty() {
                                            return arg_err!("._doc() expects 0 arguments, got {}", args.len());
                                        }
                                        // Look up the type to get documentation
                                        let type_name = qstruct.borrow().type_name.clone();
                                        if let Some(qtype) = find_type_definition(&type_name, scope) {
                                            let doc = qtype.doc.as_deref().unwrap_or("No documentation available");
                                            result = QValue::Str(QString::new(doc.to_string()));
                                        } else {
                                            return type_err!("Type {} not found", type_name);
                                        }
                                    } else if method_name == "does" {
                                        // .does(TraitName) checks if struct's type implements trait
                                        // Usage: obj.does(Drawable) returns true/false
                                        if args.len() != 1 {
                                            return arg_err!(".does() expects 1 argument (trait), got {}", args.len());
                                        }
                                        if let QValue::Trait(check_trait) = &args[0] {
                                            // Look up the type to check implemented traits
                                            let type_name = qstruct.borrow().type_name.clone();
                                            if let Some(qtype) = find_type_definition(&type_name, scope) {
                                                result = QValue::Bool(QBool::new(
                                                    qtype.implemented_traits.contains(&check_trait.name)
                                                ));
                                            } else {
                                                return type_err!("Type {} not found", type_name);
                                            }
                                        } else {
                                            return Err(".does() argument must be a trait".to_string());
                                        }
                                    } else {
                                        // Handle user-defined instance methods
                                        // First, look up the type to find the method
                                        let type_name = qstruct.borrow().type_name.clone();
                                        if let Some(qtype) = find_type_definition(&type_name, scope) {
                                            if let Some(method) = qtype.get_method(method_name) {
                                                // Bind 'self' to the struct and call method
                                                scope.push();
                                                scope.declare("self", result.clone())?;
                                                let return_value = call_user_function(method, call_args.clone(), scope)?;
                                                scope.pop();

                                                // Always use the actual return value
                                                result = return_value;

                                                // No need to copy back - Rc<RefCell<>> provides reference semantics!
                                            } else {
                                                // Method not found - check if there's a field with this name (QEP-003)
                                                // This allows: self.func() where func is a field containing a function
                                                let field_value = qstruct.borrow().fields.get(method_name).cloned();
                                                if let Some(field_val) = field_value {
                                                    // Field exists - check if it's callable
                                                    match field_val {
                                                        QValue::UserFun(ref user_fn) => {
                                                            result = call_user_function(user_fn, call_args.clone(), scope)?;
                                                        }
                                                        QValue::Fun(ref qfun) => {
                                                            // Extract positional args for builtin function call
                                                            let args = call_args.positional.clone();
                                                            let func_name = if qfun.parent_type.is_empty() {
                                                                qfun.name.clone()
                                                            } else {
                                                                format!("{}.{}", qfun.parent_type, qfun.name)
                                                            };
                                                            result = call_builtin_function(&func_name, args, scope)?;
                                                        }
                                                        QValue::Struct(ref struct_inst) => {
                                                            // Check if struct has _call() method (callable decorator/functor)
                                                            let struct_type_name = struct_inst.borrow().type_name.clone();
                                                            if let Some(struct_qtype) = find_type_definition(&struct_type_name, scope) {
                                                                if let Some(call_method) = struct_qtype.get_method("_call") {
                                                                    // Bind 'self' to the callable struct and call _call
                                                                    scope.push();
                                                                    scope.declare("self", field_val.clone())?;
                                                                    let return_value = call_user_function(call_method, call_args.clone(), scope)?;
                                                                    scope.pop();
                                                                    result = return_value;
                                                                } else {
                                                                    return type_err!("Field '{}' is not callable (type {} has no _call method)", method_name, struct_type_name);
                                                                }
                                                            } else {
                                                                return type_err!("Type {} not found", struct_type_name);
                                                            }
                                                        }
                                                        _ => {
                                                            return type_err!("Field '{}' is not callable", method_name);
                                                        }
                                                    }
                                                } else {
                                                    return attr_err!("Struct {} has no method or callable field '{}'", type_name, method_name);
                                                }
                                            }
                                        } else {
                                            return type_err!("Type {} not found", type_name);
                                        }
                                    }
                                } else {
                                    // Universal .is() method for all types
                                    if method_name == "is" {
                                        if args.len() != 1 {
                                            return arg_err!(".is() expects 1 argument (type name), got {}", args.len());
                                        }
                                        // Accept either Type objects or string type names (lowercase)
                                        let type_name = match &args[0] {
                                            QValue::Type(t) => t.name.as_str(),
                                            QValue::Str(s) => s.value.as_str(),
                                            _ => return Err(".is() argument must be a type or string".to_string()),
                                        };
                                        // Compare using lowercase
                                        let actual_type = result.as_obj().cls().to_lowercase();
                                        let expected_type = type_name.to_lowercase();
                                        result = QValue::Bool(QBool::new(actual_type == expected_type));
                                    } else {
                                        result = match &result {
                                            QValue::Int(i) => i.call_method(method_name, args)?,
                                            QValue::Float(f) => f.call_method(method_name, args)?,
                                            QValue::Decimal(d) => d.call_method(method_name, args)?,
                                            QValue::BigInt(bi) => bi.call_method(method_name, args)?,
                                            QValue::NDArray(nda) => nda.call_method(method_name, args)?,
                                            QValue::Bool(b) => b.call_method(method_name, args)?,
                                            QValue::Str(s) => s.call_method(method_name, args)?,
                                            QValue::Bytes(b) => b.call_method(method_name, args)?,
                                            QValue::Fun(f) => f.call_method(method_name, args)?,
                                            QValue::UserFun(uf) => uf.call_method(method_name, args)?,
                                            QValue::Dict(d) => d.call_method(method_name, args)?,
                                            QValue::Set(s) => s.call_method(method_name, args)?,
                                            QValue::Exception(e) => e.call_method(method_name, args)?,
                                            QValue::Uuid(u) => u.call_method(method_name, args)?,
                                            QValue::Timestamp(ts) => ts.call_method(method_name, args)?,
                                            QValue::Zoned(z) => z.call_method(method_name, args)?,
                                            QValue::Date(d) => d.call_method(method_name, args)?,
                                            QValue::Time(t) => t.call_method(method_name, args)?,
                                            QValue::Span(s) => s.call_method(method_name, args)?,
                                            QValue::DateRange(dr) => dr.call_method(method_name, args)?,
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
                                            QValue::ProcessResult(pr) => pr.call_method(method_name, args)?,
                                            QValue::Process(p) => p.call_method(method_name, args)?,
                                            QValue::WritableStream(ws) => ws.call_method(method_name, args)?,
                                            QValue::ReadableStream(rs) => rs.call_method(method_name, args)?,
                                            QValue::Rng(rng) => modules::call_rng_method(rng, method_name, args)?,
                                            QValue::StringIO(sio) => {
                                                let mut stringio = sio.borrow_mut();
                                                stringio.call_method(method_name, args)?
                                            }
                                            QValue::SystemStream(ss) => {
                                                // Special handling for write() to respect redirection
                                                if method_name == "write" {
                                                    if args.len() != 1 {
                                                        return arg_err!("write expects 1 argument, got {}", args.len());
                                                    }
                                                    let data = args[0].as_str();
                                                    
                                                    // Write to redirected target
                                                    match ss.stream_id {
                                                        0 => scope.stdout_target.write(&data)?,
                                                        1 => scope.stderr_target.write(&data)?,
                                                        _ => return Err("stdin does not support write()".to_string()),
                                                    }
                                                    
                                                    QValue::Int(QInt::new(data.len() as i64))
                                                } else {
                                                    // Other methods don't need scope
                                                    ss.call_method(method_name, args)?
                                                }
                                            }
                                            QValue::RedirectGuard(rg) => {
                                                // Special handling for RedirectGuard methods that need scope
                                                match method_name {
                                                    "restore" => {
                                                        if !args.is_empty() {
                                                            return arg_err!("restore expects 0 arguments, got {}", args.len());
                                                        }
                                                        rg.restore(scope)?;
                                                        QValue::Nil(QNil)
                                                    }
                                                    "_enter" => {
                                                        if !args.is_empty() {
                                                            return arg_err!("_enter expects 0 arguments, got {}", args.len());
                                                        }
                                                        // Return self for context manager
                                                        QValue::RedirectGuard(Box::new((**rg).clone()))
                                                    }
                                                    "_exit" => {
                                                        if !args.is_empty() {
                                                            return arg_err!("_exit expects 0 arguments, got {}", args.len());
                                                        }
                                                        // Restore on exit
                                                        rg.restore(scope)?;
                                                        QValue::Nil(QNil)
                                                    }
                                                    _ => {
                                                        // Other methods don't need scope
                                                        rg.call_method_without_scope(method_name, args)?
                                                    }
                                                }
                                            }
                                            _ => return type_err!("Type {} does not support method calls", result.as_obj().cls()),
                                        };
                                    }
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
                            } else if let QValue::Process(proc) = &result {
                                // Access process stdin/stdout/stderr streams
                                match method_name {
                                    "stdin" => {
                                        result = QValue::WritableStream(proc.stdin.clone());
                                        i += 1;
                                    }
                                    "stdout" => {
                                        result = QValue::ReadableStream(proc.stdout.clone());
                                        i += 1;
                                    }
                                    "stderr" => {
                                        result = QValue::ReadableStream(proc.stderr.clone());
                                        i += 1;
                                    }
                                    _ => {
                                        return attr_err!("Process has no field '{}'", method_name);
                                    }
                                }
                            } else if let QValue::Struct(qstruct) = &result {
                                // Fast path: Direct struct field access (QEP-042 #7)
                                // Extract all needed values in one borrow to minimize RefCell overhead
                                let (field_value_opt, type_name, qstruct_id) = {
                                    let borrowed = qstruct.borrow();
                                    (
                                        borrowed.fields.get(method_name).cloned(),  // Direct HashMap access
                                        borrowed.type_name.clone(),
                                        borrowed.id
                                    )
                                };

                                if let Some(field_value) = field_value_opt {
                                    // Field exists - check if it's public (unless accessing self)
                                    let is_self_access = if let Some(QValue::Struct(self_struct)) = scope.get("self") {
                                        self_struct.borrow().id == qstruct_id
                                    } else {
                                        false
                                    };

                                    if !is_self_access {
                                        if let Some(qtype) = find_type_definition(&type_name, scope) {
                                            if let Some(field_def) = qtype.fields.iter().find(|f| f.name == method_name) {
                                                if !field_def.is_public {
                                                    return attr_err!("Field '{}' of type {} is private", method_name, type_name);
                                                }
                                            }
                                        }
                                    }
                                    result = field_value;
                                    i += 1;
                                } else {
                                    return attr_err!("Struct {} has no field '{}'", type_name, method_name);
                                }
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
                        // Array, dict, string, or bytes index access
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
                                .unwrap_or(QValue::Nil(QNil));
                                i += 1;
                            }
                            QValue::Str(s) => {
                                // Validate index type (Int or BigInt that fits in i64)
                                let index = match &index_value {
                                    QValue::Int(i) => i.value,
                                    QValue::BigInt(n) => {
                                        use num_traits::ToPrimitive;
                                        n.value.to_i64().ok_or_else(|| "Index too large (must fit in Int)".to_string())?
                                    }
                                    _ => return type_err!("String index must be Int, got: {}", index_value.q_type()),
                                };
                                
                                // Get character count for UTF-8 string (code points)
                                let str_val = s.value.as_ref();
                                let char_count = str_val.chars().count();
                                let actual_index = normalize_index(index, char_count, "String")?;
                                
                                // Get the character at the index
                                let ch = str_val.chars().nth(actual_index)
                                .ok_or_else(|| format!("String index out of bounds: {}", index))?;
                                
                                result = QValue::Str(QString::new(ch.to_string()));
                                i += 1;
                            }
                            QValue::Bytes(bytes) => {
                                // Validate index type (Int or BigInt that fits in i64)
                                let index = match &index_value {
                                    QValue::Int(i) => i.value,
                                    QValue::BigInt(n) => {
                                        use num_traits::ToPrimitive;
                                        n.value.to_i64().ok_or_else(|| "Index too large (must fit in Int)".to_string())?
                                    }
                                    _ => return type_err!("Bytes index must be Int, got: {}", index_value.q_type()),
                                };
                                
                                let actual_index = normalize_index(index, bytes.data.len(), "Bytes")?;
                                
                                // Get the byte value at the index
                                let byte_val = bytes.data[actual_index];
                                result = QValue::Int(QInt::new(byte_val as i64));
                                i += 1;
                            }
                            _ => {
                                return attr_err!("Cannot index into type {}", result.as_obj().cls());
                            }
                        }
                    }
                    _ => {
                        return syntax_err!("Unsupported postfix operation: {:?}", current.as_rule());
                    }
                }
            }
            
            // If we started with a variable and the result is a modified struct, update the variable
            // Bug #008 fix: Never update 'self' this way - it should only be modified explicitly
            if let (Some(var_name), Some(_orig_id)) = (original_identifier, original_result_id) {
                if var_name != "self" {  // Don't auto-update self!
                if let QValue::Struct(_s) = &result {
                    // Check if struct was modified (different ID than original means it's been cloned/modified)
                    // Actually, the ID should be the same if it's the same struct, but fields might have changed
                    // We need a better heuristic: if any method was called, assume it might have mutated
                    // For now, always update if we called methods on a struct
                    if !pairs.is_empty() {
                        scope.set(&var_name, result.clone());
                    }
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
                // Check for builtin type constructors first
                if func_name == "Set" {
                    let call_args = if let Some(args_pair) = inner.next() {
                        if args_pair.as_rule() == Rule::argument_list {
                            parse_call_arguments(args_pair, scope)?
                        } else {
                            function_call::CallArguments::positional_only(Vec::new())
                        }
                    } else {
                        function_call::CallArguments::positional_only(Vec::new())
                    };
                    
                    if call_args.positional.len() != 1 {
                        return arg_err!("Set.new expects 1 argument (array), got {}", call_args.positional.len());
                    }
                    let args = call_args.positional;
                    return match &args[0] {
                        QValue::Array(arr) => {
                            let elements: Result<Vec<SetElement>, String> = arr.elements.borrow()
                            .iter()
                            .map(|v| SetElement::from_qvalue(v))
                            .collect();
                            Ok(QValue::Set(QSet::new(elements?)))
                        }
                        _ => arg_err!("Set.new expects Array, got {}", args[0].as_obj().cls()),
                    };
                }
                
                // Check if this is a module (module.method() calls need special handling)
                if let Some(QValue::Module(_)) = scope.get(func_name) {
                    // This is module.new() - treat as module function call
                    let function_name = format!("{}.new", func_name);
                    let args = if let Some(args_pair) = inner.next() {
                        if args_pair.as_rule() == Rule::argument_list {
                            parse_call_arguments(args_pair, scope)?.positional
                        } else {
                            Vec::new()
                        }
                    } else {
                        Vec::new()
                    };
                    // Dispatch to appropriate module function handler
                    return match func_name {
                        "ndarray" => modules::call_ndarray_function(&function_name, args),
                        "uuid" => modules::call_uuid_function(&function_name, args, scope),
                        "http" => modules::call_http_client_function(&function_name, args, scope),
                        _ => attr_err!("Unknown module function: {}", function_name),
                    };
                } else if let Some(QValue::Type(qtype)) = scope.get(func_name) {
                    // This is TypeName.new(...) constructor
                    // Special handling for built-in types with Rust-based constructors
                    if qtype.name == "Array" {
                        let args = if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                parse_call_arguments(args_pair, scope)?.positional
                            } else {
                                Vec::new()
                            }
                        } else {
                            Vec::new()
                        };
                        return types::array::call_array_static_method("new", args);
                    } else if qtype.name == "Decimal" {
                        let args = if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                parse_call_arguments(args_pair, scope)?.positional
                            } else {
                                Vec::new()
                            }
                        } else {
                            Vec::new()
                        };
                        return types::decimal::call_decimal_static_method("new", args);
                    } else if qtype.name == "BigInt" {
                        let args = if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                parse_call_arguments(args_pair, scope)?.positional
                            } else {
                                Vec::new()
                            }
                        } else {
                            Vec::new()
                        };
                        return types::bigint::call_bigint_static_method("new", args);
                    } else if matches!(qtype.name.as_str(), "Err" | "IndexErr" | "TypeErr" | "ValueErr" | "ArgErr" | "AttrErr" | "NameErr" | "RuntimeErr" | "IOErr" | "ImportErr" | "KeyErr") {
                        // QEP-037: Exception types
                        let args = if let Some(args_pair) = inner.next() {
                            if args_pair.as_rule() == Rule::argument_list {
                                parse_call_arguments(args_pair, scope)?.positional
                            } else {
                                Vec::new()
                            }
                        } else {
                            Vec::new()
                        };
                        return exception_types::call_exception_static_method(&qtype.name, "new", args);
                    }
                    
                    // Parse arguments using parse_call_arguments
                    if let Some(args_pair) = inner.next() {
                        if args_pair.as_rule() == Rule::argument_list {
                            let call_args = parse_call_arguments(args_pair, scope)?;
                            let named_args = if call_args.keyword.is_empty() {
                                None
                            } else {
                                Some(call_args.keyword)
                            };
                            return construct_struct(&qtype, call_args.positional, named_args, scope);
                        }
                    }
                    // No arguments
                    return construct_struct(&qtype, Vec::new(), None, scope);
                } else {
                    return type_err!("Type {} not defined", func_name);
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
                let call_args = if has_args {
                    let args_pair = inner.next().unwrap();
                    parse_call_arguments(args_pair, scope)?
                } else {
                    function_call::CallArguments::positional_only(Vec::new())
                };
                
                // Check if it's a user-defined function or callable struct
                if let Some(func_value) = scope.get(func_name) {
                    match func_value {
                        QValue::UserFun(user_fun) => {
                            return call_user_function(&user_fun, call_args, scope);
                        }
                        QValue::Type(qtype) => {
                            // Trying to call a type directly - provide helpful error
                            return attr_err!(
                                "Cannot call type '{}' as a function. Use {}.new() to create a new instance.",
                                qtype.name, qtype.name
                            );
                        }
                        QValue::Struct(struct_inst) => {
                            // Check if struct has _call() method (callable decorator/functor)
                            let type_name = struct_inst.borrow().type_name.clone();
                            if let Some(qtype) = find_type_definition(&type_name, scope) {
                                if let Some(call_method) = qtype.get_method("_call") {
                                    // Bind 'self' to the struct and call _call method
                                    scope.push();
                                    scope.declare("self", QValue::Struct(struct_inst.clone()))?;
                                    let result = call_user_function(call_method, call_args, scope)?;
                                    scope.pop();
                                    return Ok(result);
                                } else {
                                    return type_err!(
                                        "Type '{}' is not callable (missing _call() method)",
                                        type_name
                                    );
                                }
                            } else {
                                return type_err!("Type '{}' not found", type_name);
                            }
                        }
                        _ => {}
                    }
                }
                
                // For builtin functions, extract positional args
                // (builtin functions don't yet support named arguments - future enhancement)
                return call_builtin_function(func_name, call_args.positional, scope);
            }
            
            // Just a bare identifier (variable reference)
            return match scope.get(func_name) {
                Some(v) => Ok(v),
                None => name_err!("Undefined variable: {}", func_name),
            };
        }
        
        // Otherwise, evaluate the inner expression
        eval_pair(first, scope)
    }
    Rule::number => {
        let num_str = pair.as_str();
        
        // Check if it's a BigInt literal (ends with 'n' or 'N')
        if num_str.ends_with('n') || num_str.ends_with('N') {
            use num_bigint::BigInt;
            use num_traits::Num;
            use std::str::FromStr;
            
            // Remove 'n' suffix and underscores
            let cleaned = num_str[..num_str.len()-1].replace("_", "");
            
            let bigint = if cleaned.starts_with("0x") || cleaned.starts_with("0X") {
                BigInt::from_str_radix(&cleaned[2..], 16)
                .map_err(|e| format!("Invalid hex BigInt literal '{}': {}", num_str, e))?
            } else if cleaned.starts_with("0b") || cleaned.starts_with("0B") {
                BigInt::from_str_radix(&cleaned[2..], 2)
                .map_err(|e| format!("Invalid binary BigInt literal '{}': {}", num_str, e))?
            } else if cleaned.starts_with("0o") || cleaned.starts_with("0O") {
                BigInt::from_str_radix(&cleaned[2..], 8)
                .map_err(|e| format!("Invalid octal BigInt literal '{}': {}", num_str, e))?
            } else {
                BigInt::from_str(&cleaned)
                .map_err(|e| format!("Invalid BigInt literal '{}': {}", num_str, e))?
            };
            
            return Ok(QValue::BigInt(QBigInt::new(bigint)));
        }
        
        // Regular Int/Float literals
        let cleaned = num_str.replace("_", "");
        
        // Handle hex literals (0x or 0X prefix)
        if cleaned.starts_with("0x") || cleaned.starts_with("0X") {
            let hex_str = &cleaned[2..];
            let value = i64::from_str_radix(hex_str, 16)
            .map_err(|e| format!("Invalid hexadecimal literal '{}': {}", num_str, e))?;
            return Ok(QValue::Int(QInt::new(value)));
        }
        
        // Handle binary literals (0b or 0B prefix)
        if cleaned.starts_with("0b") || cleaned.starts_with("0B") {
            let bin_str = &cleaned[2..];
            let value = i64::from_str_radix(bin_str, 2)
            .map_err(|e| format!("Invalid binary literal '{}': {}", num_str, e))?;
            return Ok(QValue::Int(QInt::new(value)));
        }
        
        // Handle octal literals (0o or 0O prefix)
        if cleaned.starts_with("0o") || cleaned.starts_with("0O") {
            let oct_str = &cleaned[2..];
            let value = i64::from_str_radix(oct_str, 8)
            .map_err(|e| format!("Invalid octal literal '{}': {}", num_str, e))?;
            return Ok(QValue::Int(QInt::new(value)));
        }
        
        // Check if it's an integer (no decimal point, no scientific notation)
        if !cleaned.contains('.') && !cleaned.contains('e') && !cleaned.contains('E') {
            // Try to parse as integer
            if let Ok(int_value) = cleaned.parse::<i64>() {
                return Ok(QValue::Int(QInt::new(int_value)));
            }
        }
        // Parse as float (Float type for literals with decimal point or scientific notation)
        let value = cleaned
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
            // Empty array [] - Pre-allocate with capacity 16 (QEP-042 #6)
            return Ok(QValue::Array(QArray::new_with_capacity(16)));
        }

        let elements_pair = elements_pair.unwrap();
        if elements_pair.as_rule() != Rule::array_elements {
            // Empty array - Pre-allocate with capacity 16 (QEP-042 #6)
            return Ok(QValue::Array(QArray::new_with_capacity(16)));
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
                            QValue::Str(s) => s.value.as_ref().clone(),
                            _ => return Err("Dict key must be a string".to_string())
                        }
                    }
                    _ => return type_err!("Invalid dict key type: {:?}", key_part.as_rule())
                };
                
                let value = eval_pair(value_part, scope)?;
                map.insert(key, value);
            }
        }
        
        Ok(QValue::Dict(Box::new(QDict::new(map))))
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
    Rule::type_literal => {
        // Type literals evaluate to lowercase strings
        // e.g., "int" stays "int", "str" stays "str"
        Ok(QValue::Str(QString::new(pair.as_str().to_string())))
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
                    Some(c) => return value_err!("Invalid escape sequence: \\{}", c),
                    None => return Err("Invalid escape sequence at end of bytes literal".to_string()),
                }
            } else {
                // Regular ASCII character
                if ch.is_ascii() {
                    bytes.push(ch as u8);
                } else {
                    return value_err!("Non-ASCII character '{}' in bytes literal", ch);
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
                    let unquoted = if s.starts_with("\"\"\"") || s.starts_with("'''") {
                        // Multi-line string (triple quotes)
                        s[3..s.len()-3].to_string()
                    } else {
                        // Single-line string - remove quotes (single or double) and process escapes
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
                                let value = match scope.get(var_name) {
                                    Some(v) => v,
                                    None => return name_err!("Undefined variable: {}", var_name),
                                };
                                
                                // Format the value
                                let formatted = if let Some(spec) = format_spec {
                                    string_utils::format_value(&value, spec)?
                                } else {
                                    value.as_str()
                                };
                                result.push_str(&formatted);
                            }
                            Rule::fstring_dq_char | Rule::fstring_sq_char => {
                                let ch = part.as_str();
                                result.push_str(&string_utils::process_escape_sequences(ch));
                            }
                            _ => {}
                        }
                    }
                    Ok(QValue::Str(QString::new(result)))
                }
                _ => value_err!("Unexpected string type: {:?}", string_pair.as_rule())
            }
        } else {
            Err("Empty string rule".to_string())
        }
    }
    Rule::return_statement => {
        // Return statement: return expression?
        // Get span before consuming pair
        let return_span = pair.as_span();
        let return_str = return_span.as_str();

        let mut inner = pair.into_inner();
        let return_val = if let Some(expr) = inner.next() {
            // Check if the expression is on the same line as the return keyword
            // to avoid consuming the next statement as the return value
            // Get the text between "return" and the expression start
            // If there's a newline, treat this as a bare return
            let expr_start_offset = expr.as_span().start() - return_span.start();
            let between = &return_str[6..expr_start_offset]; // Skip "return" keyword

            if between.contains('\n') {
                // Newline found - don't evaluate the expression, treat as bare return
                QValue::Nil(QNil)
            } else {
                eval_pair(expr, scope)?
            }
        } else {
            QValue::Nil(QNil)
        };
        // Store the return value in scope for backward compatibility
        scope.return_value = Some(return_val.clone());
        // Use new control flow mechanism
        Err("__FUNCTION_RETURN__".to_string())
    }
    Rule::break_statement => {
        // Break out of the current loop - use new control flow mechanism
        Err("__LOOP_BREAK__".to_string())
    }
    Rule::continue_statement => {
        // Continue to next iteration - use new control flow mechanism
        Err("__LOOP_CONTINUE__".to_string())
    }
    Rule::raise_statement => {
        // raise expression or bare raise for re-raising (QEP-037)
        let mut inner = pair.into_inner();
        
        if let Some(expr_pair) = inner.next() {
            // raise with expression
            let value = eval_pair(expr_pair, scope)?;
            
            match value {
                QValue::Str(s) => {
                    // String raise: treat as RuntimeErr (QEP-037)
                    return runtime_err!("{}", s.value);
                }
                QValue::Exception(e) => {
                    // Built-in exception object: raise IndexErr.new("msg")
                    return Err(format!("{}: {}", e.exception_type, e.message));
                }
                QValue::Struct(s) => {
                    // Custom exception type (user-defined struct)
                    // TODO QEP-037: Check if implements Error trait
                    let borrowed = s.borrow();
                    let msg = borrowed.fields.get("message")
                    .map(|v| v.as_str())
                    .unwrap_or_else(|| "No message".to_string());
                    return Err(format!("{}: {}", borrowed.type_name, msg));
                }
                _ => {
                    return runtime_err!("Cannot raise type '{}' - must implement Error trait", value.q_type());
                }
            }
        } else {
            // Bare raise - re-raise current exception
            if let Some(exc) = &scope.current_exception {
                return Err(format!("{}: {}", exc.exception_type, exc.message));
            } else {
                return runtime_err!("No active exception to re-raise");
            }
        }
    }
    Rule::doc_fun | Rule::doc_const | Rule::doc_type | Rule::doc_trait => {
        // QEP-002: % documentation declarations (inlined from doc_declaration)
        // These are metadata only - they don't execute or declare anything
        // For now, we just parse and silently return nil
        // Phase 2 will extract and store this documentation for lazy loading
        Ok(QValue::Nil(QNil))
    }
    Rule::with_statement => {
        // QEP-011: with statement (context managers)
        // Phase 3: Support multiple context managers
        // with with_item ("," with_item)* statement* end
        // where with_item = expression as_clause?
        let inner = pair.into_inner();
        
        // 1. Parse all with_items (context managers with optional 'as' clauses)
        struct WithItem {
            ctx_manager: QValue,
            as_var: Option<String>,
            saved_var: Option<QValue>,
        }
        
        let mut items: Vec<WithItem> = Vec::new();
        let mut statements = Vec::new();
        
        for item in inner {
            match item.as_rule() {
                Rule::with_item => {
                    let mut with_item_inner = item.into_inner();
                    
                    // Get the expression (context manager)
                    let ctx_expr = with_item_inner.next().unwrap();
                    let ctx_manager = eval_pair(ctx_expr, scope)?;
                    
                    // Check for as_clause
                    let as_var = if let Some(as_clause) = with_item_inner.next() {
                        if as_clause.as_rule() == Rule::as_clause {
                            let var_name = as_clause.into_inner().next().unwrap().as_str().to_string();
                            Some(var_name)
                        } else {
                            None
                        }
                    } else {
                        None
                    };
                    
                    // Save shadowed variable if needed
                    let saved_var = if let Some(ref var_name) = as_var {
                        scope.get(var_name)
                    } else {
                        None
                    };
                    
                    items.push(WithItem {
                        ctx_manager,
                        as_var,
                        saved_var,
                    });
                }
                _ => statements.push(item),
            }
        }
        
        // 2. Call _enter() on all context managers in forward order
        for item in &items {
            let enter_result = call_method_on_value(&item.ctx_manager, "_enter", vec![], scope)?;
            
            // Bind result to variable if 'as' clause present
            if let Some(ref var_name) = item.as_var {
                scope.set(var_name, enter_result);
            }
        }
        
        // 3. Execute block (with exception handling)
        let mut exception = None;
        
        for stmt in statements {
            match eval_pair(stmt, scope) {
                Ok(_val) => {}, // Ignore return value (Python-compatible)
                Err(e) => {
                    exception = Some(e);
                    break;
                }
            }
        }
        
        // 4. Call _exit() on all context managers in REVERSE order (even if exception occurred)
        // Also track if any _exit() suppresses the exception
        let mut suppress_exception = false;
        
        for item in items.iter().rev() {
            let exit_result = call_method_on_value(&item.ctx_manager, "_exit", vec![], scope);
            
            // If _exit() raises, that takes precedence
            if let Err(exit_err) = exit_result {
                // Restore remaining variables before propagating
                for remaining_item in items.iter().rev() {
                    if std::ptr::eq(remaining_item, item) {
                        break;
                    }
                    if let Some(ref var_name) = remaining_item.as_var {
                        if let Some(ref saved) = remaining_item.saved_var {
                            scope.set(var_name, saved.clone());
                        } else {
                            let _ = scope.delete(var_name);
                        }
                    }
                }
                return Err(exit_err);
            }
            
            // Phase 2: Check if this _exit() wants to suppress the exception
            if let Ok(exit_return_val) = exit_result {
                if exit_return_val.as_bool() {
                    suppress_exception = true;
                }
            }
        }
        
        // 5. Restore all variable scopes in reverse order
        for item in items.iter().rev() {
            if let Some(ref var_name) = item.as_var {
                if let Some(ref saved) = item.saved_var {
                    // Restore shadowed variable
                    scope.set(var_name, saved.clone());
                } else {
                    // Remove variable (it didn't exist before)
                    let _ = scope.delete(var_name);
                }
            }
        }
        
        // 6. Handle exceptions
        // Re-raise original exception if any (unless suppressed by _exit())
        if let Some(e) = exception {
            if !suppress_exception {
                return Err(e);
            }
            // Exception suppressed by _exit() returning true
        }
        
        // 7. Always return nil (Python-compatible)
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
                // Parse the error message to extract exception type (QEP-037)
                let (exc_type, exc_msg) = if let Some(colon_pos) = error_msg.find(": ") {
                    let type_str = &error_msg[..colon_pos];
                    let msg = &error_msg[colon_pos + 2..];
                    (ExceptionType::from_str(type_str), msg.to_string())
                } else {
                    // No type prefix - treat as generic RuntimeErr
                    (ExceptionType::RuntimeErr, error_msg.clone())
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
                    // Check if this catch clause matches the exception type (QEP-037)
                    let matches = if let Some(ref expected_type_str) = exception_type_filter {
                        let expected_type = ExceptionType::from_str(expected_type_str);
                        // Use subtype checking (enables catching Err to match all exceptions)
                        exception.exception_type.is_subtype_of(&expected_type)
                    } else {
                        true // catch-all (no type specified)
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
                        
                        // Remove exception variable from scope after catch block
                        scope.delete(&var_name).ok();
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
    // For loop keywords - these are just markers and don't evaluate to anything
    Rule::to_kw | Rule::until_kw | Rule::step_kw => {
        Ok(QValue::Nil(QNil))
    }
    // QEP-034: argument_item is a wrapper around expressions/named_arg/unpack_*
    // It should not normally be evaluated directly, but handle it by unwrapping
    Rule::argument_item => {
        let inner = pair.into_inner().next().unwrap();
        eval_pair(inner, scope)
    }
    // QEP-035: named_arg should only appear in function call contexts
    Rule::named_arg | Rule::unpack_args | Rule::unpack_kwargs => {
        syntax_err!("{:?} can only be used in function calls", pair.as_rule())
    }
    _ => runtime_err!("Unsupported rule: {:?}", pair.as_rule()),
}
}

/// Helper function to find a type definition by name
/// Checks local scope first, then searches through all modules
fn find_type_definition(type_name: &str, scope: &Scope) -> Option<QType> {
    // First, check local scope
    if let Some(QValue::Type(qtype)) = scope.get(type_name) {
        return Some((*qtype).clone());
    }
    
    // If not found, search through all modules
    let flat_map = scope.to_flat_map();
    for value in flat_map.values() {
        if let QValue::Module(module) = value {
            if let Some(QValue::Type(qtype)) = module.get_member(type_name) {
                return Some((*qtype).clone());
            }
        }
    }
    
    None
}

/// Recursively deep clone a QValue, creating fresh Rc wrappers for mutable types
fn deep_clone_value(value: &QValue) -> QValue {
    match value {
        QValue::Array(arr) => {
            // Recursively deep clone each element
            let elements: Vec<QValue> = arr.elements.borrow()
                .iter()
                .map(|elem| deep_clone_value(elem))
                .collect();
            QValue::Array(QArray::new(elements))
        }
        QValue::Dict(dict) => {
            // Recursively deep clone each value in the dict
            let entries: HashMap<String, QValue> = dict.map.borrow()
                .iter()
                .map(|(k, v)| (k.clone(), deep_clone_value(v)))
                .collect();
            QValue::Dict(Box::new(QDict::new(entries)))
        }
        // Immutable types are safe to shallow clone
        _ => value.clone()
    }
}

/// Helper function to get field value (from args, defaults, or nil)
fn get_field_value(field_def: &FieldDef, provided_value: Option<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    if let Some(value) = provided_value {
        // Value was provided
        return Ok(value);
    }

    // No value provided - check for default
    if let Some(ref default_value) = field_def.default_value {
        // Deep clone mutable defaults to avoid shared state across instances (QEP-045).
        // Arrays and Dicts use Rc<RefCell<...>> internally, so a shallow clone would
        // create multiple struct instances sharing the same underlying collection.
        // We use recursive deep cloning to handle nested mutable structures.
        return Ok(deep_clone_value(default_value));
    }

    // No default - use nil if optional, error if required
    if field_def.optional {
        Ok(QValue::Nil(QNil))
    } else {
        arg_err!("Required field '{}' not provided and has no default", field_def.name)
    }
}

// Format a value according to a Rust-style format specification
/// Construct a struct instance from a type
fn construct_struct(qtype: &QType, args: Vec<QValue>, named_args: Option<HashMap<String, QValue>>, scope: &mut Scope) -> Result<QValue, String> {
    let mut fields = HashMap::new();
    
    // Handle named arguments if provided
    if let Some(named_args) = named_args {
        for field_def in &qtype.fields {
            let provided = named_args.get(&field_def.name).cloned();
            let value = get_field_value(field_def, provided, scope)?;
            
            // Validate type if annotation present (skip nil for optional fields)
            if let Some(ref type_annotation) = field_def.type_annotation {
                if !field_def.optional || !matches!(value, QValue::Nil(_)) {
                    validate_field_type(&value, type_annotation)?;
                }
            }
            fields.insert(field_def.name.clone(), value);
        }
        return Ok(QValue::Struct(Rc::new(RefCell::new(QStruct::new(qtype.name.clone(), qtype.id, fields)))));
    }
    
    // Handle positional arguments
    if args.is_empty() {
        // No arguments - use defaults, nil if optional, or error if required
        for field_def in &qtype.fields {
            let value = get_field_value(field_def, None, scope)?;
            fields.insert(field_def.name.clone(), value);
        }
    } else if args.len() == 1 {
        // Check if single argument is a dict (named arguments)
        if let QValue::Dict(dict) = &args[0] {
            // Named arguments via dict
            for field_def in &qtype.fields {
                let provided = dict.get(&field_def.name);
                let value = get_field_value(field_def, provided, scope)?;
                
                // Validate type if annotation present (skip nil for optional fields)
                if let Some(ref type_annotation) = field_def.type_annotation {
                    if !field_def.optional || !matches!(value, QValue::Nil(_)) {
                        validate_field_type(&value, type_annotation)?;
                    }
                }
                fields.insert(field_def.name.clone(), value);
            }
        } else {
            // Single positional argument
            if qtype.fields.is_empty() {
                return arg_err!("Type {} has no fields, but got 1 argument", qtype.name);
            }
            
            // Check if we have exactly 1 required field, or 1+ fields where only first is required
            let required_count = qtype.fields.iter().filter(|f| !f.optional).count();
            if required_count > 1 {
                return arg_err!("Type {} requires {} arguments, got 1", qtype.name, required_count);
            }
            
            let field_def = &qtype.fields[0];
            if let Some(ref type_annotation) = field_def.type_annotation {
                validate_field_type(&args[0], type_annotation)?;
            }
            fields.insert(field_def.name.clone(), args[0].clone());
            
            // Fill remaining fields with defaults or nil
            for field_def in &qtype.fields[1..] {
                let value = get_field_value(field_def, None, scope)?;
                fields.insert(field_def.name.clone(), value);
            }
        }
    } else {
        // Multiple positional arguments
        if args.len() != qtype.fields.len() {
            // Check if extra args can be skipped (optional fields)
            let required_count = qtype.fields.iter().filter(|f| !f.optional).count();
            if args.len() < required_count {
                return arg_err!("Type {} requires at least {} arguments, got {}", qtype.name, required_count, args.len());
            }
            if args.len() > qtype.fields.len() {
                return arg_err!("Type {} expects at most {} arguments, got {}", qtype.name, qtype.fields.len(), args.len());
            }
        }
        
        for (i, field_def) in qtype.fields.iter().enumerate() {
            if i < args.len() {
                // Validate type if annotation present
                if let Some(ref type_annotation) = field_def.type_annotation {
                    validate_field_type(&args[i], type_annotation)?;
                }
                fields.insert(field_def.name.clone(), args[i].clone());
            } else {
                // No positional arg provided - use default or nil
                let value = get_field_value(field_def, None, scope)?;
                fields.insert(field_def.name.clone(), value);
            }
        }
    }
    
    Ok(QValue::Struct(Rc::new(RefCell::new(QStruct::new(qtype.name.clone(), qtype.id, fields)))))
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
        // Delegate ndarray.* functions to ndarray module
        name if name.starts_with("ndarray.") => {
            modules::call_ndarray_function(name, args)
        }
        // Delegate settings.* functions to settings module
        name if name.starts_with("settings.") => {
            modules::call_settings_function(name, args)
        }
        // Delegate struct.* functions to encoding/struct module
        name if name.starts_with("struct.") => {
            modules::call_struct_function(name, args, scope)
        }
        // Delegate hex.* functions to encoding/hex module
        name if name.starts_with("hex.") => {
            modules::call_hex_function(name, args, scope)
        }
        // Delegate url.* functions to encoding/url module
        name if name.starts_with("url.") => {
            modules::call_url_function(name, args, scope)
        }
        // Delegate csv.* functions to encoding/csv module
        name if name.starts_with("csv.") => {
            modules::call_csv_function(name, args, scope)
        }
        // Delegate rand.* functions to rand module
        name if name.starts_with("rand.") => {
            modules::call_rand_function(name, args, scope)
        }
        // Delegate templates.* functions to html/templates module
        name if name.starts_with("templates.") => {
            modules::call_templates_function(name, args, scope)
        }
        // Delegate markdown.* functions to markdown module
        name if name.starts_with("markdown.") => {
            modules::call_markdown_function(name, args, scope)
        }
        // Delegate http.* functions to http/client module
        name if name.starts_with("http.") => {
            modules::call_http_client_function(name, args, scope)
        }
        // Delegate urlparse.* functions to http/urlparse module
        name if name.starts_with("urlparse.") => {
            modules::call_urlparse_function(name, args, scope)
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
        // Delegate gzip.* functions to compress/gzip module
        name if name.starts_with("gzip.") => {
            modules::call_gzip_function(name, args, scope)
        }
        // Delegate bzip2.* functions to compress/bzip2 module
        name if name.starts_with("bzip2.") => {
            modules::call_bzip2_function(name, args, scope)
        }
        // Delegate deflate.* functions to compress/deflate module
        name if name.starts_with("deflate.") => {
            modules::call_deflate_function(name, args, scope)
        }
        // Delegate zlib.* functions to compress/zlib module
        name if name.starts_with("zlib.") => {
            modules::call_zlib_function(name, args, scope)
        }
        // Delegate process.* functions to process module
        name if name.starts_with("process.") => {
            modules::call_process_function(name, args, scope)
        }
        "puts" => {
            // Build output string
            let mut output = String::new();
            for arg in &args {
                output.push_str(&arg.as_str());
            }
            output.push('\n');
            
            // Write to current stdout target (supports redirection)
            scope.stdout_target.write(&output)?;
            Ok(QValue::Nil(QNil))
        }
        "print" => {
            // Build output string (no newline)
            let mut output = String::new();
            for arg in &args {
                output.push_str(&arg.as_str());
            }
            
            // Write to current stdout target (supports redirection)
            scope.stdout_target.write(&output)?;
            Ok(QValue::Nil(QNil))
        }
        "is_array" => {
            if args.len() != 1 {
                return arg_err!("is_array expects 1 argument, got {}", args.len());
            }
            let is_arr = matches!(&args[0], QValue::Array(_));
            Ok(QValue::Bool(QBool::new(is_arr)))
        }
        "chr" => {
            // chr(codepoint) - convert Unicode codepoint to character
            if args.len() != 1 {
                return arg_err!("chr expects 1 argument, got {}", args.len());
            }
            let codepoint = args[0].as_num()? as u32;
            
            let ch = char::from_u32(codepoint)
            .ok_or_else(|| format!("Invalid Unicode codepoint: {}", codepoint))?;
            
            Ok(QValue::Str(QString::new(ch.to_string())))
        }
        "ord" => {
            // ord(string) - get Unicode codepoint of first character
            if args.len() != 1 {
                return arg_err!("ord expects 1 argument, got {}", args.len());
            }
            let s = args[0].as_str();
            
            let ch = s.chars().next()
            .ok_or_else(|| "ord expects non-empty string".to_string())?;
            
            Ok(QValue::Int(QInt::new(ch as i64)))
        }
        _ => attr_err!("Undefined function: {}", func_name),
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Initialize heap profiler if enabled
    #[cfg(feature = "dhat-heap")]
    let _profiler = dhat::Profiler::new_heap();
    
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
            println!("Quest version 0.1.1");
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

        if first_arg_lower == "serve" {
            // Handle 'serve' command: quest serve [OPTIONS] <script>
            let remaining_args = if args.len() > 2 { &args[2..] } else { &[] };
            return handle_serve_command(remaining_args);
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
            alloc_counter::print_stats();
            std::process::exit(1);
        }
        alloc_counter::print_stats();
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
            alloc_counter::print_stats();
            std::process::exit(1);
        }
        alloc_counter::print_stats();
        return Ok(());
    }
    
    // Otherwise, run interactive REPL
    run_repl()?;
    
    // Print debug stats if QUEST_CLONE_DEBUG is enabled
    alloc_counter::print_stats();
    
    Ok(())
}
