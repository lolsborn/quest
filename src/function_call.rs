// ============================================================================
// Simplified function calling with proper closure support
// ============================================================================

use crate::scope::{Scope, StackFrame};
use crate::types::{QValue, QUserFun, QNil};
use crate::{QuestParser, Rule};
use pest::Parser;
use std::rc::Rc;
use std::cell::RefCell;
use std::collections::HashMap;

use crate::arg_err;

/// Call a user-defined function with proper closure semantics
///
/// This implements closure-by-reference:
/// - Functions execute in their captured scope (where they were defined)
/// - They can see and modify outer variables
/// - Module functions can access private module members
pub fn call_user_function(
    user_fun: &QUserFun,
    args: Vec<QValue>,
    parent_scope: &mut Scope
) -> Result<QValue, String> {
    // Calculate required parameter count (those without defaults)
    let required_count = user_fun.param_defaults.iter()
        .filter(|d| d.is_none())
        .count();

    // Check parameter count
    if args.len() < required_count {
        return arg_err!(
            "Function {} requires at least {} arguments, got {}",
            user_fun.name.as_ref().unwrap_or(&"<anonymous>".to_string()),
            required_count,
            args.len()
        );
    }

    if args.len() > user_fun.params.len() {
        return arg_err!(
            "Function {} takes at most {} arguments, got {}",
            user_fun.name.as_ref().unwrap_or(&"<anonymous>".to_string()),
            user_fun.params.len(),
            args.len()
        );
    }

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
    func_scope.call_stack = parent_scope.call_stack.clone();
    func_scope.current_exception = parent_scope.current_exception.clone();
    func_scope.current_script_path = Rc::clone(&parent_scope.current_script_path);
    func_scope.stdout_target = parent_scope.stdout_target.clone();
    func_scope.stderr_target = parent_scope.stderr_target.clone();

    // Push stack frame for exception tracking
    let func_name = user_fun.name.clone().unwrap_or_else(|| "<anonymous>".to_string());
    func_scope.push_stack_frame(StackFrame::new(func_name.clone()));

    // Also push to parent scope so exceptions can see it
    parent_scope.push_stack_frame(StackFrame::new(func_name));

    // Push new scope level for local variables and parameters
    func_scope.push();

    // Check if parent scope has 'self' (for instance methods)
    // If so, bind it in the function scope so instance methods can access it
    if let Some(self_value) = parent_scope.get("self") {
        func_scope.declare("self", self_value)?;
    }

    // Phase 1: Bind provided arguments to parameters
    for (i, arg_value) in args.iter().enumerate() {
        func_scope.declare(&user_fun.params[i], arg_value.clone())?;
    }

    // Phase 2: Evaluate defaults for omitted parameters (left-to-right)
    for i in args.len()..user_fun.params.len() {
        let default_expr = user_fun.param_defaults[i].as_ref()
            .ok_or_else(|| format!("Missing required parameter '{}'", user_fun.params[i]))?;

        // Evaluate default in function scope (can see earlier params)
        // Parse and evaluate the default expression
        let pairs = QuestParser::parse(Rule::expression, default_expr)
            .map_err(|e| format!("Parse error in default for parameter '{}': {}", user_fun.params[i], e))?;

        let default_value = crate::eval_pair(pairs.into_iter().next().unwrap(), &mut func_scope)?;

        // TODO: Type check default value if parameter has type annotation
        // This will be implemented when QEP-015 (Type Annotations) is fully supported

        func_scope.declare(&user_fun.params[i], default_value)?;
    }

    // Parse and evaluate function body
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

            // Evaluate statement
            match crate::eval_pair(statement, &mut func_scope) {
                Ok(val) => result = val,
                Err(e) if e == "__FUNCTION_RETURN__" => {
                    // Early return - retrieve the return value from scope
                    result = func_scope.return_value.take().unwrap_or(QValue::Nil(QNil));
                    break;
                }
                Err(e) => {
                    // Pop scope but keep stack frame for exception tracing
                    // Stack frames will be cleared by try/catch handler after capturing
                    func_scope.pop();
                    return Err(e);
                }
            }

            // Check for early return (alternative mechanism)
            if func_scope.return_value.is_some() {
                result = func_scope.return_value.take().unwrap();
                break;
            }
        }

        if func_scope.return_value.is_some() {
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

    // Pop scope and stack frame (from both func_scope and parent_scope)
    func_scope.pop();
    func_scope.pop_stack_frame();
    parent_scope.pop_stack_frame();

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
