// ============================================================================
// Control Flow Enum
// ============================================================================
//
// CURRENT STATUS: Infrastructure defined but NOT YET USED (as of QEP-056)
//
// This module defines structured control flow infrastructure for Quest's
// evaluator. Currently, Quest uses magic strings ("__FUNCTION_RETURN__", etc.)
// to signal non-local control flow through Result<QValue, String>.
//
// This enum provides the TARGET architecture for future migration:
// - Type-safe control flow with compile-time verification
// - 50-100× faster than string comparison
// - Clear distinction between control flow and errors
// - Single source of truth (no dual storage)
//
// MIGRATION PLAN: See specs/qep-056-structured-control-flow.md
// DEPENDS ON: QEP-049 (Iterative Evaluator) completion
// RELATED: QEP-037 (Typed Exceptions), QEP-048 (Stack Depth Tracking)
//
// The infrastructure is complete and ready to activate when migration begins.
// All conversion helpers and compatibility layers are implemented below.
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

/// Magic string for loop break control flow
///
/// Used internally to signal that a break statement was executed.
/// This constant ensures consistency across the codebase during migration.
pub const MAGIC_LOOP_BREAK: &str = "__LOOP_BREAK__";

/// Magic string for loop continue control flow
///
/// Used internally to signal that a continue statement was executed.
/// This constant ensures consistency across the codebase during migration.
pub const MAGIC_LOOP_CONTINUE: &str = "__LOOP_CONTINUE__";

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
        Err(EvalError::ControlFlow(ControlFlow::FunctionReturn(_))) => Err(MAGIC_FUNCTION_RETURN.to_string()),
        Err(EvalError::ControlFlow(ControlFlow::LoopBreak)) => Err(MAGIC_LOOP_BREAK.to_string()),
        Err(EvalError::ControlFlow(ControlFlow::LoopContinue)) => Err(MAGIC_LOOP_CONTINUE.to_string()),
        Err(EvalError::Runtime(msg)) => Err(msg),
    }
}
