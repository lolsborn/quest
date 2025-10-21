// ============================================================================
// Simplified function calling with proper closure support
// ============================================================================

use crate::scope::{Scope, StackFrame};
use crate::types::{QValue, QUserFun, QNil};
use crate::{QuestParser, Rule};
use crate::control_flow::{EvalError, ControlFlow};
use pest::Parser;
use std::rc::Rc;
use std::cell::RefCell;
use std::collections::HashMap;

use crate::arg_err;

/// Arguments passed to a function call (QEP-035)
/// Separates positional and named arguments for flexible parameter binding
#[derive(Debug, Clone)]
pub struct CallArguments {
    pub positional: Vec<QValue>,
    pub keyword: HashMap<String, QValue>,
}

impl CallArguments {
    /// Create new CallArguments with only positional args (backward compatibility)
    pub fn positional_only(args: Vec<QValue>) -> Self {
        CallArguments {
            positional: args,
            keyword: HashMap::new(),
        }
    }

    /// Create new CallArguments with both positional and keyword args
    pub fn new(positional: Vec<QValue>, keyword: HashMap<String, QValue>) -> Self {
        CallArguments { positional, keyword }
    }
}

/// Call a user-defined function with proper closure semantics (QEP-035)
///
/// This implements closure-by-reference:
/// - Functions execute in their captured scope (where they were defined)
/// - They can see and modify outer variables
/// - Module functions can access private module members
///
/// Supports both positional and named arguments (QEP-035)
/// QEP-057: call_line captures the line number where the function was called
pub fn call_user_function(
    user_fun: &QUserFun,
    call_args: CallArguments,
    parent_scope: &mut Scope,
    call_line: Option<usize>,  // QEP-057: Line number where function was called
) -> Result<QValue, String> {
    let anon = "<anonymous>".to_string();
    let func_name = user_fun.name.as_ref().unwrap_or(&anon);

    // Create function execution scope with captured scope chain
    let mut func_scope = if !user_fun.captured_scopes.is_empty() {
        // Function has captured scopes - use them as base
        // This is the key to closure-by-reference semantics
        let mut new_scope = Scope::new();
        new_scope.scopes = user_fun.captured_scopes.clone();
        new_scope.module_cache = parent_scope.module_cache.clone();
        new_scope
    } else {
        // No captured scopes - create fresh scope (legacy behavior)
        let mut new_scope = Scope::new();
        new_scope.module_cache = parent_scope.module_cache.clone();
        new_scope
    };

    // Share call_stack, exception state, script path, and I/O targets with parent
    // This ensures stack traces work correctly and I/O redirection is inherited
    // QEP-057: Use Rc::clone instead of cloning the vector (efficient shared state)
    func_scope.call_stack = Rc::clone(&parent_scope.call_stack);
    func_scope.current_exception = parent_scope.current_exception.clone();
    func_scope.current_script_path = Rc::clone(&parent_scope.current_script_path);
    func_scope.stdout_target = parent_scope.stdout_target.clone();
    func_scope.stderr_target = parent_scope.stderr_target.clone();

    // QEP-057: Copy execution context from parent
    func_scope.current_file = parent_scope.current_file.clone();
    func_scope.current_line = parent_scope.current_line;
    func_scope.current_function = Some(func_name.clone());

    // Push stack frame for exception tracking (QEP-057 enhanced)
    // Since call_stack is now shared, this automatically updates both scopes
    let stack_frame = StackFrame::with_location(
        func_name.clone(),
        parent_scope.current_file.clone(),
        call_line  // QEP-057: Use explicit call site line number
    );
    func_scope.push_stack_frame(stack_frame);

    // Push new scope level for local variables and parameters
    func_scope.push();

    // Check if parent scope has 'self' (for instance methods)
    // If so, bind it in the function scope so instance methods can access it
    if let Some(self_value) = parent_scope.get("self") {
        func_scope.declare("self", self_value)?;
    }

    // ============================================================================
    // QEP-035: Named Arguments - Four-phase binding algorithm
    // ============================================================================

    let mut param_index = 0;

    // Bind positional arguments
    for pos_value in call_args.positional.iter() {
        if param_index >= user_fun.params.len() {
            // Excess positional args
            if user_fun.varargs.is_some() {
                break;  // TODO: Collect in varargs
            } else {
                return arg_err!(
                    "Function {} takes at most {} positional arguments, got {}",
                    func_name,
                    user_fun.params.len(),
                    call_args.positional.len()
                );
            }
        }

        let param_name = &user_fun.params[param_index];

        // Check if also specified by keyword
        if call_args.keyword.contains_key(param_name) {
            return arg_err!(
                "Parameter '{}' specified both positionally and by keyword",
                param_name
            );
        }

        // Type check (if parameter has type annotation)
        if let Some(param_type) = &user_fun.param_types[param_index] {
            check_parameter_type(pos_value, param_type, param_name)?;
        }

        func_scope.declare(param_name, pos_value.clone())?;
        param_index += 1;
    }

    // Bind keyword arguments to remaining parameters
    let mut unmatched_kwargs = call_args.keyword.clone();

    for i in param_index..user_fun.params.len() {
        let param_name = &user_fun.params[i];

        if let Some(kw_value) = unmatched_kwargs.remove(param_name) {
            // Keyword arg provided for this param
            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&kw_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, kw_value)?;
        } else if let Some(default_expr) = &user_fun.param_defaults[i] {
            // Use default value
            let pairs = QuestParser::parse(Rule::expression, default_expr)
                .map_err(|e| format!("Parse error in default for parameter '{}': {}", param_name, e))?;

            let pair = pairs.into_iter().next()
                .ok_or_else(|| format!("Empty expression for default parameter '{}'", param_name))?;
            let default_value = crate::eval_pair(pair, &mut func_scope)?;

            if let Some(param_type) = &user_fun.param_types[i] {
                check_parameter_type(&default_value, param_type, param_name)?;
            }

            func_scope.declare(param_name, default_value)?;
        } else {
            return arg_err!("Missing required parameter '{}'", param_name);
        }
    }

    // Handle varargs (if any)
    if let Some(varargs_name) = &user_fun.varargs {
        let remaining_positional = call_args.positional[param_index..].to_vec();
        let varargs_array = crate::types::QArray::new(remaining_positional);
        func_scope.declare(varargs_name, QValue::Array(varargs_array))?;
    }

    // Handle kwargs (if any)
    if let Some(kwargs_name) = &user_fun.kwargs {
        // QDict expects HashMap<String, QValue>, so unmatched_kwargs is already the right format
        let kwargs_dict = crate::types::QDict::new(unmatched_kwargs);
        func_scope.declare(kwargs_name, QValue::Dict(Box::new(kwargs_dict)))?;
    } else if !unmatched_kwargs.is_empty() {
        // Unknown keyword arguments (function doesn't accept **kwargs)
        let unknown: Vec<_> = unmatched_kwargs.keys().map(|s| s.as_str()).collect();
        return arg_err!(
            "Unknown keyword arguments: {}",
            unknown.join(", ")
        );
    }

    // Parse and evaluate function body
    let pairs = QuestParser::parse(Rule::program, &user_fun.body)
        .map_err(|e| format!("Parse error in function body: {}", e))?;

    let mut result = QValue::Nil(QNil);
    let mut early_return = false;  // QEP-056: Track if we hit an early return
    for pair in pairs {
        if matches!(pair.as_rule(), Rule::EOI) {
            continue;
        }
        for statement in pair.into_inner() {
            if matches!(statement.as_rule(), Rule::EOI) {
                continue;
            }

            // Evaluate statement
            // QEP-056: Use structured control flow (no dual storage)
            match crate::eval_pair(statement, &mut func_scope) {
                Ok(val) => result = val,
                Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(val))) => {
                    // Early return - value is in the ControlFlow enum
                    result = val;
                    early_return = true;  // QEP-056: Mark that we're returning early
                    break;
                }
                Err(e) => {
                    // Pop scope but keep stack frame for exception tracing
                    // Stack frames will be cleared by try/catch handler after capturing
                    func_scope.pop();
                    return Err(e.to_string());
                }
            }
        }
        // QEP-056: If we hit an early return, stop processing remaining pairs
        if early_return {
            break;
        }
    }

    // Copy modified 'self' back to parent scope (for mutable instance methods)
    if let Some(updated_self) = func_scope.get("self") {
        // Only update if parent scope also has 'self' (i.e., this was an instance method call)
        if parent_scope.get("self").is_some() {
            parent_scope.set("self", updated_self);
        }
    }

    // Pop scope and stack frame
    // QEP-057: Only pop once since call_stack is shared
    func_scope.pop();
    func_scope.pop_stack_frame();

    // QEP-015: Check return type if function has return type annotation
    if let Some(return_type) = &user_fun.return_type {
        check_return_type(&result, return_type, func_name)?;
    }

    Ok(result)
}

/// Helper to capture current scope chain for function creation
/// Returns a clone of the entire scope chain (all levels)
/// This allows closures to:
/// - See variables from all outer scopes
/// - Modify outer variables (closure-by-reference)
pub fn capture_current_scope(scope: &Scope) -> Vec<Rc<RefCell<HashMap<String, QValue>>>> {
    scope.scopes.clone()
}

/// Type check a parameter value against its type annotation (QEP-015/QEP-035)
fn check_parameter_type(value: &QValue, param_type: &str, param_name: &str) -> Result<(), String> {
    use crate::type_err;

    // Helper to convert to title case (e.g., "int" -> "Int", "str" -> "Str")
    fn to_title_case(s: &str) -> String {
        let mut chars = s.chars();
        match chars.next() {
            None => String::new(),
            Some(first) => first.to_uppercase().chain(chars).collect(),
        }
    }

    let actual_type = value.q_type();  // Already title case from q_type()
    let expected_type = to_title_case(param_type);  // Convert annotation to title case

    // Check if types match (title case comparison)
    // Future: Support union types (Int|Str), nullable (?), generics, etc.
    let matches = match expected_type.as_str() {
        "Int" => actual_type == "Int",
        "Float" => actual_type == "Float",
        "Num" => actual_type == "Int" || actual_type == "Float",
        "Str" => actual_type == "Str",
        "Bool" => actual_type == "Bool",
        "Array" => actual_type == "Array",
        "Dict" => actual_type == "Dict",
        "Nil" => actual_type == "Nil",
        _ => actual_type == expected_type,  // Direct comparison for custom types
    };

    if !matches {
        return type_err!(
            "Parameter '{}' expects type {}, got {}",
            param_name,
            expected_type,
            actual_type
        );
    }

    Ok(())
}

/// Type check a return value against its type annotation (QEP-015)
fn check_return_type(value: &QValue, return_type: &str, func_name: &str) -> Result<(), String> {
    use crate::type_err;

    // Helper to convert to title case (e.g., "int" -> "Int", "str" -> "Str")
    fn to_title_case(s: &str) -> String {
        let mut chars = s.chars();
        match chars.next() {
            None => String::new(),
            Some(first) => first.to_uppercase().chain(chars).collect(),
        }
    }

    let actual_type = value.q_type();  // Already title case from q_type()
    let expected_type = to_title_case(return_type);  // Convert annotation to title case

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
            "Function '{}' declared return type {}, but returned {}",
            func_name,
            expected_type,
            actual_type
        );
    }

    Ok(())
}
