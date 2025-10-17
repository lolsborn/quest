// Redirect guard for I/O redirection
use crate::control_flow::EvalError;
use crate::types::*;
use crate::scope::OutputTarget;
use std::rc::Rc;
use std::cell::RefCell;
use crate::{arg_err, attr_err, runtime_err};

#[derive(Debug, Clone, PartialEq)]
pub enum StreamType {
    Stdout,
    Stderr,
}

/// RedirectGuard - Manages stream restoration for I/O redirection
///
/// Returned by sys.redirect_stdout() and sys.redirect_stderr().
/// Calling restore() returns the stream to its previous state.
/// Guards are idempotent - restore() can be called multiple times safely.
#[derive(Debug, Clone)]
pub struct QRedirectGuard {
    pub id: u64,
    pub stream_type: StreamType,
    // Shared state for idempotent restoration
    pub previous_target: Rc<RefCell<Option<OutputTarget>>>,
}

impl QRedirectGuard {
    pub fn new(stream_type: StreamType, previous: OutputTarget) -> Self {
        Self {
            id: next_object_id(),
            stream_type,
            previous_target: Rc::new(RefCell::new(Some(previous))),
        }
    }

    pub fn is_active(&self) -> bool {
        self.previous_target.borrow().is_some()
    }

    pub fn restore(&self, scope: &mut crate::Scope) -> Result<(), String> {
        let mut prev = self.previous_target.borrow_mut();

        if let Some(target) = prev.take() {
            match self.stream_type {
                StreamType::Stdout => scope.stdout_target = target,
                StreamType::Stderr => scope.stderr_target = target,
            }
        }
        // If already restored (None), this is a no-op (idempotent)

        Ok(())
    }

    // Note: call_method will be added separately in main.rs where we have scope access
    pub fn call_method_without_scope(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "is_active" => {
                if !args.is_empty() {
                    return arg_err!("is_active expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.is_active())))
            }
            "restore" | "_enter" | "_exit" => {
                // These need scope access - will be handled in main.rs
                runtime_err!("{} requires scope access - call from main.rs", method_name)
            }
            _ => attr_err!("RedirectGuard has no method '{}'", method_name)
        }
    }
}

impl QObj for QRedirectGuard {
    fn cls(&self) -> String {
        "RedirectGuard".to_string()
    }

    fn q_type(&self) -> &'static str {
        "RedirectGuard"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "RedirectGuard"
    }

    fn str(&self) -> String {
        let status = if self.is_active() { "active" } else { "restored" };
        let stream = match self.stream_type {
            StreamType::Stdout => "stdout",
            StreamType::Stderr => "stderr",
        };
        format!("<RedirectGuard for {} ({})>", stream, status)
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        let stream = match self.stream_type {
            StreamType::Stdout => "stdout",
            StreamType::Stderr => "stderr",
        };
        format!("Guard object for {} redirection", stream)
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
