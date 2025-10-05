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
    // Check parameter count
    if args.len() != user_fun.params.len() {
        return Err(format!(
            "Function {} expects {} arguments, got {}",
            user_fun.name.as_ref().unwrap_or(&"<anonymous>".to_string()),
            user_fun.params.len(),
            args.len()
        ));
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

    // Bind parameters to arguments
    for (param_name, arg_value) in user_fun.params.iter().zip(args.iter()) {
        func_scope.declare(param_name, arg_value.clone())?;
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
