// ============================================================================
// Control Flow Enum
// ============================================================================
//
// This module defines the control flow mechanism for Quest's evaluator.
// Previously, control flow was signaled using magic strings like
// "__FUNCTION_RETURN__", which was error-prone and had poor performance.
//
// This enum provides type-safe control flow handling with compile-time
// verification and better performance through direct enum matching.
//
// ============================================================================

use crate::types::QValue;

// ============================================================================
// Magic String Constants (for backward compatibility during migration)
// ============================================================================

/// Magic string for function return control flow
///
/// Used internally to signal that a return statement was executed.
/// This constant ensures consistency across the codebase during migration.
pub const MAGIC_FUNCTION_RETURN: &str = "__FUNCTION_RETURN__";

/// Control flow signals for the evaluator
///
/// These are returned as `Err(ControlFlow::...)` from evaluation functions
/// to signal non-local control flow (return, break, continue).
///
/// Using an enum instead of strings provides:
/// - Type safety: Compiler catches typos and missing match arms
/// - Performance: Direct enum comparison vs string comparison
/// - Clarity: Explicit semantics vs magic strings
/// - Debugging: Better error messages and IDE support
#[derive(Debug, Clone)]
pub enum ControlFlow {
    /// Function return with optional value
    ///
    /// Signals that a `return` statement was executed.
    /// The QValue is stored here for consistency, though it's also
    /// stored in `scope.return_value` for backward compatibility.
    FunctionReturn(QValue),

    /// Loop break
    ///
    /// Signals that a `break` statement was executed.
    /// Should only be caught by loop constructs.
    LoopBreak,

    /// Loop continue
    ///
    /// Signals that a `continue` statement was executed.
    /// Should only be caught by loop constructs.
    LoopContinue,
}

impl ControlFlow {
    /// Check if this is a function return
    pub fn is_return(&self) -> bool {
        matches!(self, ControlFlow::FunctionReturn(_))
    }

    /// Check if this is a loop break
    pub fn is_break(&self) -> bool {
        matches!(self, ControlFlow::LoopBreak)
    }

    /// Check if this is a loop continue
    pub fn is_continue(&self) -> bool {
        matches!(self, ControlFlow::LoopContinue)
    }

    /// Extract return value if this is a FunctionReturn
    pub fn into_return_value(self) -> Option<QValue> {
        match self {
            ControlFlow::FunctionReturn(val) => Some(val),
            _ => None,
        }
    }
}

/// Result type for evaluation that can signal control flow
///
/// This is the return type for all evaluation functions.
/// - Ok(QValue): Normal evaluation succeeded
/// - Err(EvalError::ControlFlow(cf)): Control flow signal (return/break/continue)
/// - Err(EvalError::Runtime(msg)): Actual runtime error
#[derive(Debug, Clone)]
pub enum EvalError {
    /// Control flow signal (return, break, continue)
    ControlFlow(ControlFlow),

    /// Actual runtime error
    Runtime(String),
}

impl EvalError {
    /// Create a runtime error
    pub fn runtime(msg: impl Into<String>) -> Self {
        EvalError::Runtime(msg.into())
    }

    /// Create a function return control flow
    pub fn function_return(val: QValue) -> Self {
        EvalError::ControlFlow(ControlFlow::FunctionReturn(val))
    }

    /// Create a loop break control flow
    pub fn loop_break() -> Self {
        EvalError::ControlFlow(ControlFlow::LoopBreak)
    }

    /// Create a loop continue control flow
    pub fn loop_continue() -> Self {
        EvalError::ControlFlow(ControlFlow::LoopContinue)
    }

    /// Check if this is a control flow signal
    pub fn is_control_flow(&self) -> bool {
        matches!(self, EvalError::ControlFlow(_))
    }

    /// Check if this is a runtime error
    pub fn is_runtime(&self) -> bool {
        matches!(self, EvalError::Runtime(_))
    }

    /// Extract control flow if present
    pub fn as_control_flow(&self) -> Option<&ControlFlow> {
        match self {
            EvalError::ControlFlow(cf) => Some(cf),
            _ => None,
        }
    }

    /// Extract runtime error message if present
    pub fn as_runtime(&self) -> Option<&str> {
        match self {
            EvalError::Runtime(msg) => Some(msg),
            _ => None,
        }
    }

    /// Convert to string representation
    pub fn to_string(&self) -> String {
        match self {
            EvalError::ControlFlow(cf) => format!("ControlFlow::{:?}", cf),
            EvalError::Runtime(msg) => msg.clone(),
        }
    }
}

// Implement From<String> for backward compatibility with existing error handling
impl From<String> for EvalError {
    fn from(msg: String) -> Self {
        EvalError::Runtime(msg)
    }
}

impl From<&str> for EvalError {
    fn from(msg: &str) -> Self {
        EvalError::Runtime(msg.to_string())
    }
}

// Implement Into<String> for compatibility with existing code that expects String errors
impl From<EvalError> for String {
    fn from(err: EvalError) -> Self {
        err.to_string()
    }
}

/// Type alias for evaluation results
#[allow(dead_code)]
pub type EvalResult<T> = Result<T, EvalError>;

/// Convert EvalResult to string Result for backward compatibility
///
/// This helper converts new-style `EvalResult<QValue>` to old-style `Result<QValue, String>`,
/// converting ControlFlow back to magic strings.
#[allow(dead_code)]
pub fn convert_to_string_result(result: EvalResult<QValue>) -> Result<QValue, String> {
    match result {
        Ok(val) => Ok(val),
        Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(_))) => Err("__FUNCTION_RETURN__".to_string()),
        Err(EvalError::ControlFlow(ControlFlow::LoopBreak)) => Err("__LOOP_BREAK__".to_string()),
        Err(EvalError::ControlFlow(ControlFlow::LoopContinue)) => Err("__LOOP_CONTINUE__".to_string()),
        Err(EvalError::Runtime(msg)) => Err(msg),
    }
}
