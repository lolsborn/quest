// QEP-049: Iterative Evaluator with Explicit Stack
//
// This module implements an iterative replacement for the recursive eval_pair function.
// Instead of using Rust's call stack (limited to ~8MB), we use an explicit heap-allocated
// stack of evaluation frames, allowing deep nesting and complex expressions without
// stack overflow.

use pest::iterators::Pair;
use crate::{Rule, QValue, QNil};
use crate::scope::Scope;
use crate::types::*;
use crate::string_utils;
use crate::{value_err, runtime_err};
use std::collections::HashMap;

// ============================================================================
// Core Data Structures
// ============================================================================

/// An evaluation frame represents one node in the AST being evaluated.
/// The frame tracks:
/// - The AST node (Pair) - We clone pairs instead of using references
/// - Current evaluation state (state machine position)
/// - Partial results accumulated so far
/// - Optional context data for complex evaluations
///
/// Note: Pest's Pair uses Rc internally, so cloning is cheap (just incrementing refcount)
pub struct EvalFrame<'i> {
    pub pair: Pair<'i, Rule>,
    pub state: EvalState,
    pub partial_results: Vec<QValue>,
    pub context: Option<EvalContext<'i>>,
}

impl<'i> EvalFrame<'i> {
    /// Create a new frame in Initial state
    pub fn new(pair: Pair<'i, Rule>) -> Self {
        Self {
            pair,
            state: EvalState::Initial,
            partial_results: Vec::new(),
            context: None,
        }
    }

    /// Create a frame with a specific initial state
    pub fn with_state(pair: Pair<'i, Rule>, state: EvalState) -> Self {
        Self {
            pair,
            state,
            partial_results: Vec::new(),
            context: None,
        }
    }

    /// Create a frame with existing partial results
    pub fn with_results(pair: Pair<'i, Rule>, state: EvalState, results: Vec<QValue>) -> Self {
        Self {
            pair,
            state,
            partial_results: results,
            context: None,
        }
    }

    /// Create a frame with context
    pub fn with_context(
        pair: Pair<'i, Rule>,
        state: EvalState,
        context: EvalContext<'i>,
    ) -> Self {
        Self {
            pair,
            state,
            partial_results: Vec::new(),
            context: Some(context),
        }
    }
}

/// State machine states for evaluation.
/// Each AST Rule may transition through multiple states during evaluation.
#[derive(Debug, Clone, PartialEq)]
pub enum EvalState {
    // ========== Universal States ==========
    /// Initial state - just started evaluating this node
    Initial,
    /// Complete - evaluation finished, result in partial_results
    Complete,

    // ========== Binary Operators ==========
    /// Evaluating left operand
    EvalLeft,
    /// Evaluating right operand (left result in partial_results[0])
    EvalRight,
    /// Apply binary operation (both operands in partial_results)
    ApplyOp,

    // ========== Unary Operators ==========
    /// Evaluating operand for unary operator
    EvalOperand,
    /// Apply unary operation
    ApplyUnaryOp,

    // ========== Control Flow - If Statement ==========
    /// Evaluating condition
    IfEvalCondition,
    /// Evaluating a specific branch (index into if/elif/else branches)
    IfEvalBranch(usize),
    /// If statement complete, skip remaining evaluation
    IfComplete,

    // ========== Control Flow - Match Statement ==========
    /// Evaluating match expression
    MatchEvalExpr,
    /// Evaluating a specific case value (case_index, value_index in case)
    MatchEvalCase(usize, usize),
    /// Evaluating the body of a matched case
    MatchEvalBody(usize),
    /// Match complete
    MatchComplete,

    // ========== Control Flow - While Loop ==========
    /// Checking while condition
    WhileCheckCondition,
    /// Evaluating while body
    WhileEvalBody,
    /// While loop complete
    WhileComplete,

    // ========== Control Flow - For Loop ==========
    /// Evaluating collection to iterate over
    ForEvalCollection,
    /// Iterating through collection (current_index)
    ForIterateBody(usize),
    /// For loop complete
    ForComplete,

    // ========== Postfix Chains (method calls, field access, indexing) ==========
    /// Evaluating the base expression
    PostfixEvalBase,
    /// Evaluating operation at index (operation_index)
    PostfixEvalOperation(usize),
    /// Applying operation at index (operation already evaluated)
    PostfixApplyOperation(usize),
    /// Postfix chain complete
    PostfixComplete,

    // ========== Function/Method Calls ==========
    /// Evaluating positional argument at index
    CallEvalArg(usize),
    /// Evaluating keyword argument at index
    CallEvalKwarg(usize),
    /// Evaluating array unpacking expression
    CallEvalArrayUnpack(usize),
    /// Evaluating dict unpacking expression
    CallEvalDictUnpack(usize),
    /// Execute the function call (all args evaluated)
    CallExecute,

    // ========== Exception Handling ==========
    /// Evaluating try body
    TryEvalBody,
    /// Evaluating catch clause at index
    TryEvalCatch(usize),
    /// Evaluating ensure block
    TryEvalEnsure,
    /// Exception handling complete
    TryComplete,

    // ========== Assignment ==========
    /// Evaluating the right-hand side of assignment
    AssignEvalRhs,
    /// Evaluating index for indexed assignment (arr[i] = x)
    AssignEvalIndex(usize),
    /// Applying assignment
    AssignApply,

    // ========== Let/Const Declarations ==========
    /// Evaluating binding at index
    LetEvalBinding(usize),
    /// Let complete
    LetComplete,

    // ========== Array/Dict Literals ==========
    /// Evaluating element at index
    ArrayEvalElement(usize),
    /// Array literal complete
    ArrayComplete,
    /// Evaluating dict key at index
    DictEvalKey(usize),
    /// Evaluating dict value at index
    DictEvalValue(usize),
    /// Dict literal complete
    DictComplete,

    // ========== Return/Break/Continue ==========
    /// Evaluating return value
    ReturnEvalValue,
    /// Return complete (value in partial_results)
    ReturnComplete,
}

/// Additional context for complex evaluations.
/// Some evaluation states need more data than just partial results.
#[derive(Clone)]
pub enum EvalContext<'i> {
    /// Loop iteration state
    Loop(LoopState<'i>),
    /// Postfix operation chain state
    Postfix(PostfixState<'i>),
    /// Function/method call state
    FunctionCall(CallState<'i>),
    /// Match statement state
    Match(MatchState<'i>),
    /// Assignment state
    Assignment(AssignmentState),
}

/// State for loop evaluation (while/for)
#[derive(Clone)]
pub struct LoopState<'i> {
    /// Loop variable name (for for-loops)
    pub loop_var: Option<String>,
    /// Collection being iterated (for for-loops)
    pub collection: Option<Vec<QValue>>,
    /// Current iteration index
    pub current_iteration: usize,
    /// Body statements (cloned for each iteration)
    pub body_pairs: Vec<Pair<'i, Rule>>,
    /// Break flag
    pub should_break: bool,
    /// Continue flag
    pub should_continue: bool,
}

/// State for postfix operation chains (obj.method().field[index])
#[derive(Clone)]
pub struct PostfixState<'i> {
    /// List of operations to apply in sequence
    pub operations: Vec<Pair<'i, Rule>>,
    /// Current base value (updated as we apply operations)
    pub current_base: Option<QValue>,
}

/// State for function/method calls
#[derive(Clone)]
pub struct CallState<'i> {
    /// Function or method to call
    pub function: Option<QValue>,
    /// Evaluated positional arguments
    pub args: Vec<QValue>,
    /// Evaluated keyword arguments
    pub kwargs: HashMap<String, QValue>,
    /// Number of positional args to evaluate
    pub arg_count: usize,
    /// Number of keyword args to evaluate
    pub kwarg_count: usize,
    /// Array unpacking expressions (*args)
    pub array_unpacks: Vec<Pair<'i, Rule>>,
    /// Dict unpacking expressions (**kwargs)
    pub dict_unpacks: Vec<Pair<'i, Rule>>,
}

/// State for match statement evaluation
#[derive(Clone)]
pub struct MatchState<'i> {
    /// The value being matched against
    pub match_value: Option<QValue>,
    /// Case pairs (each case may have multiple values)
    pub cases: Vec<Pair<'i, Rule>>,
    /// Else block pair (if present)
    pub else_block: Option<Pair<'i, Rule>>,
    /// Index of matched case (if any)
    pub matched_case: Option<usize>,
}

/// State for assignment operations
#[derive(Clone)]
pub struct AssignmentState {
    /// Variable name (for simple assignment)
    pub var_name: Option<String>,
    /// Base object (for indexed assignment: arr[i] = x)
    pub base: Option<QValue>,
    /// Indices (for nested indexed assignment: arr[i][j] = x)
    pub indices: Vec<QValue>,
    /// Compound operator (for +=, -=, etc.)
    pub compound_op: Option<String>,
}

// ============================================================================
// Main Iterative Evaluator
// ============================================================================

/// Iteratively evaluate an AST node using an explicit stack.
/// This replaces the recursive eval_pair function.
///
/// # Arguments
/// * `initial_pair` - The AST node to evaluate
/// * `scope` - Mutable reference to the variable scope
///
/// # Returns
/// Result containing the evaluated QValue or an error message
pub fn eval_pair_iterative<'i>(
    initial_pair: Pair<'i, Rule>,
    scope: &mut Scope,
) -> Result<QValue, String> {
    // Explicit evaluation stack
    let mut stack: Vec<EvalFrame<'i>> = vec![EvalFrame::new(initial_pair)];

    // Final result (set when stack becomes empty with a result)
    let mut final_result: Option<QValue> = None;

    // Main evaluation loop - continues until stack is empty
    while let Some(mut frame) = stack.pop() {
        // Track depth for compatibility with QEP-048
        // Note: With iterative evaluation, we're not limited by Rust's stack
        // The depth is tracked for introspection purposes (sys.get_call_depth)
        scope.eval_depth = stack.len() + 1;

        // Dispatch based on (Rule, State) combination
        match (frame.pair.as_rule(), &frame.state) {
            // ================================================================
            // Terminal Cases (literals that evaluate to themselves)
            // ================================================================

            (Rule::nil, EvalState::Initial) => {
                push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
            }

            // ================================================================
            // Passthrough Rules (just evaluate inner node)
            // ================================================================

            (Rule::statement, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            (Rule::expression_statement, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            (Rule::expression, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            (Rule::literal, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            // Passthrough for operator precedence rules (when no operator present)
            (Rule::multiplication, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();

                // Check if there's an operator
                if inner.next().is_none() {
                    // No operator, just pass through to unary
                    stack.push(EvalFrame::new(first));
                } else {
                    // Has operators - not yet implemented
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::unary, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();

                // Check if it's a unary operator or just a postfix
                if first.as_rule() == Rule::unary_op {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                } else {
                    // Just pass through to postfix
                    stack.push(EvalFrame::new(first));
                }
            }

            (Rule::postfix, EvalState::Initial) => {
                // postfix = { primary ~ (identifier | method_name | index_access | argument_list)* }
                // Hybrid approach: evaluate base, then fall back to recursive for postfix operations
                let mut inner = frame.pair.clone().into_inner();
                let base = inner.next().unwrap();

                // Check if there are postfix operations
                let has_ops = inner.next().is_some();

                if has_ops {
                    // Has postfix operations - use hybrid approach
                    // Evaluate base iteratively, then apply operations recursively

                    // Push continuation frame to apply postfix operations
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::PostfixEvalBase,
                        partial_results: Vec::new(),
                        context: None,
                    });

                    // Push base evaluation
                    stack.push(EvalFrame::new(base));
                } else {
                    // No postfix ops, just evaluate base
                    stack.push(EvalFrame::new(base));
                }
            }

            (Rule::postfix, EvalState::PostfixEvalBase) => {
                // Base has been evaluated, now apply postfix operations
                // For now, fall back to recursive evaluator for the postfix chain
                // This is a hybrid approach that still gives us iterative base evaluation

                // The postfix operations are complex (method calls, indexing, etc.)
                // Rather than implement all 600 lines now, fall back to recursive
                let _base_result = frame.partial_results.pop().unwrap();

                // Call the recursive implementation directly (eval_pair_impl)
                // to avoid routing back through iterative evaluator
                let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;

                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            (Rule::primary, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            // Complex expressions - fall back to recursive for now
            (Rule::array_literal, EvalState::Initial) => {
                let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            (Rule::dict_literal, EvalState::Initial) => {
                let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            // More operator precedence passthroughs
            (Rule::elvis_expr, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::logical_or, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::logical_and, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::comparison, EvalState::Initial) => {
                // comparison = { concat ~ (comparison_op ~ concat)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                // Check if there are comparison operators
                if inner.next().is_none() {
                    // No operators, just evaluate left
                    stack.push(EvalFrame::new(left));
                } else {
                    // Has comparison operators - use hybrid approach
                    // Push continuation frame
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });

                    // Push left operand evaluation
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::comparison, EvalState::EvalLeft) => {
                // Left operand evaluated, now process comparisons
                let left_result = frame.partial_results.pop().unwrap();
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left (already evaluated)

                let mut result = left_result;

                // Process each comparison operator
                while let Some(op_pair) = inner.next() {
                    if op_pair.as_rule() == Rule::comparison_op {
                        let op = op_pair.as_str();
                        let right_pair = inner.next().unwrap();

                        // Evaluate right operand (using recursive eval for now)
                        let right = crate::eval_pair(right_pair, scope)?;

                        // Type-aware comparison with fast path for Int comparisons
                        let cmp_result = match op {
                            "==" => {
                                // Fast path for Int == Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value == r.value
                                } else {
                                    crate::types::values_equal(&result, &right)
                                }
                            }
                            "!=" => {
                                // Fast path for Int != Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value != r.value
                                } else {
                                    !crate::types::values_equal(&result, &right)
                                }
                            }
                            "<" => {
                                // Fast path for Int < Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value < r.value
                                } else {
                                    match crate::types::compare_values(&result, &right) {
                                        Some(ordering) => ordering == std::cmp::Ordering::Less,
                                        None => return Err(format!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls()))
                                    }
                                }
                            }
                            ">" => {
                                // Fast path for Int > Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value > r.value
                                } else {
                                    match crate::types::compare_values(&result, &right) {
                                        Some(ordering) => ordering == std::cmp::Ordering::Greater,
                                        None => return Err(format!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls()))
                                    }
                                }
                            }
                            "<=" => {
                                // Fast path for Int <= Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value <= r.value
                                } else {
                                    match crate::types::compare_values(&result, &right) {
                                        Some(ordering) => ordering != std::cmp::Ordering::Greater,
                                        None => return Err(format!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls()))
                                    }
                                }
                            }
                            ">=" => {
                                // Fast path for Int >= Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    l.value >= r.value
                                } else {
                                    match crate::types::compare_values(&result, &right) {
                                        Some(ordering) => ordering != std::cmp::Ordering::Less,
                                        None => return Err(format!("Cannot compare {} and {}", result.as_obj().cls(), right.as_obj().cls()))
                                    }
                                }
                            }
                            _ => return Err(format!("Unknown comparison operator: {}", op)),
                        };
                        result = QValue::Bool(QBool::new(cmp_result));
                    }
                }

                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            (Rule::concat, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::logical_not, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                // logical_not = { not_op* ~ bitwise_or }
                // If first is bitwise_or (not not_op), just pass through
                if first.as_rule() == Rule::bitwise_or {
                    stack.push(EvalFrame::new(first));
                } else {
                    // Has NOT operator - fall back to recursive
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::bitwise_or, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::bitwise_xor, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::bitwise_and, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::shift, EvalState::Initial) => {
                let mut inner = frame.pair.clone().into_inner();
                let first = inner.next().unwrap();
                if inner.next().is_none() {
                    stack.push(EvalFrame::new(first));
                } else {
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            // ================================================================
            // Literals
            // ================================================================

            (Rule::boolean, EvalState::Initial) => {
                let value = match frame.pair.as_str() {
                    "true" => QValue::Bool(QBool::new(true)),
                    "false" => QValue::Bool(QBool::new(false)),
                    _ => return Err("Invalid boolean".to_string()),
                };
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::number, EvalState::Initial) => {
                let num_str = frame.pair.as_str();

                // Check if it's a BigInt literal (ends with 'n' or 'N')
                let value = if num_str.ends_with('n') || num_str.ends_with('N') {
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

                    QValue::BigInt(QBigInt::new(bigint))
                } else {
                    // Regular Int/Float literals
                    let cleaned = num_str.replace("_", "");

                    // Handle hex literals (0x or 0X prefix)
                    if cleaned.starts_with("0x") || cleaned.starts_with("0X") {
                        let hex_str = &cleaned[2..];
                        let value = i64::from_str_radix(hex_str, 16)
                        .map_err(|e| format!("Invalid hexadecimal literal '{}': {}", num_str, e))?;
                        QValue::Int(QInt::new(value))
                    } else if cleaned.starts_with("0b") || cleaned.starts_with("0B") {
                        let bin_str = &cleaned[2..];
                        let value = i64::from_str_radix(bin_str, 2)
                        .map_err(|e| format!("Invalid binary literal '{}': {}", num_str, e))?;
                        QValue::Int(QInt::new(value))
                    } else if cleaned.starts_with("0o") || cleaned.starts_with("0O") {
                        let oct_str = &cleaned[2..];
                        let value = i64::from_str_radix(oct_str, 8)
                        .map_err(|e| format!("Invalid octal literal '{}': {}", num_str, e))?;
                        QValue::Int(QInt::new(value))
                    } else if !cleaned.contains('.') && !cleaned.contains('e') && !cleaned.contains('E') {
                        // Try to parse as integer
                        if let Ok(int_value) = cleaned.parse::<i64>() {
                            QValue::Int(QInt::new(int_value))
                        } else {
                            return Err(format!("Invalid integer: {}", num_str));
                        }
                    } else {
                        // Parse as float
                        let value = cleaned
                        .parse::<f64>()
                        .map_err(|e| format!("Invalid number: {}", e))?;
                        QValue::Float(QFloat::new(value))
                    }
                };

                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::string, EvalState::Initial) => {
                // String can be either fstring or plain_string
                let mut inner = frame.pair.clone().into_inner();
                if let Some(string_pair) = inner.next() {
                    let value = match string_pair.as_rule() {
                        Rule::plain_string => {
                            // Plain string (no interpolation)
                            let s = string_pair.as_str();
                            let unquoted = if s.starts_with("\"\"\"") || s.starts_with("'''") {
                                // Multi-line string (triple quotes)
                                s[3..s.len()-3].to_string()
                            } else {
                                // Single-line string - remove quotes and process escapes
                                string_utils::process_escape_sequences(&s[1..s.len()-1])
                            };
                            QValue::Str(QString::new(unquoted))
                        }
                        Rule::fstring => {
                            // F-string with interpolation - fall back to recursive evaluator
                            return crate::eval_pair(frame.pair.clone(), scope);
                        }
                        _ => return value_err!("Unexpected string type: {:?}", string_pair.as_rule())
                    };
                    push_result_to_parent(&mut stack, value, &mut final_result)?;
                } else {
                    return Err("Empty string rule".to_string());
                }
            }

            (Rule::bytes_literal, EvalState::Initial) => {
                let s = frame.pair.as_str();
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

                push_result_to_parent(&mut stack, QValue::Bytes(QBytes::new(bytes)), &mut final_result)?;
            }

            (Rule::type_literal, EvalState::Initial) => {
                // Type literals evaluate to lowercase strings
                push_result_to_parent(&mut stack, QValue::Str(QString::new(frame.pair.as_str().to_string())), &mut final_result)?;
            }

            (Rule::identifier, EvalState::Initial) => {
                // Variable lookup
                let name = frame.pair.as_str();
                let value = scope.get(name)
                    .ok_or_else(|| format!("Undefined variable: {}", name))?;
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            // ================================================================
            // Control Flow - If Statement
            // ================================================================

            (Rule::if_statement, EvalState::Initial) => {
                // if expression ~ statement* ~ elif_clause* ~ else_clause? ~ end
                // Parse structure and push continuation to evaluate condition
                let mut iter = frame.pair.clone().into_inner();
                let condition = iter.next().unwrap();

                // Push continuation frame that will handle the result of condition evaluation
                stack.push(EvalFrame {
                    pair: frame.pair.clone(),
                    state: EvalState::IfEvalCondition,
                    partial_results: Vec::new(),
                    context: None,
                });

                // Push condition evaluation
                stack.push(EvalFrame::new(condition));
            }

            (Rule::if_statement, EvalState::IfEvalCondition) => {
                // Condition has been evaluated
                let condition_value = frame.partial_results.pop().unwrap();
                let condition_bool = condition_value.as_bool();

                let mut iter = frame.pair.clone().into_inner();
                iter.next(); // Skip condition (already evaluated)

                if condition_bool {
                    // Execute if block
                    scope.push(); // New scope for if block

                    let mut if_body = Vec::new();
                    for stmt_pair in iter.by_ref() {
                        if matches!(stmt_pair.as_rule(), Rule::elif_clause | Rule::else_clause) {
                            break;
                        }
                        if_body.push(stmt_pair);
                    }

                    // Execute body statements (using recursive eval for now)
                    let mut result = QValue::Nil(QNil);
                    for stmt in if_body {
                        result = crate::eval_pair(stmt, scope)?;
                    }

                    // Propagate self mutations
                    if let Some(updated_self) = scope.get("self") {
                        scope.pop();
                        scope.set("self", updated_self);
                    } else {
                        scope.pop();
                    }

                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                } else {
                    // Check elif/else clauses
                    let mut found_match = false;

                    for clause_pair in iter {
                        match clause_pair.as_rule() {
                            Rule::elif_clause => {
                                let mut elif_inner = clause_pair.into_inner();
                                let elif_condition = crate::eval_pair(elif_inner.next().unwrap(), scope)?;

                                if elif_condition.as_bool() {
                                    scope.push();
                                    let mut result = QValue::Nil(QNil);
                                    for stmt in elif_inner {
                                        result = crate::eval_pair(stmt, scope)?;
                                    }

                                    // Propagate self mutations
                                    if let Some(updated_self) = scope.get("self") {
                                        scope.pop();
                                        scope.set("self", updated_self);
                                    } else {
                                        scope.pop();
                                    }

                                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                                    found_match = true;
                                    break;
                                }
                            }
                            Rule::else_clause => {
                                scope.push();
                                let mut result = QValue::Nil(QNil);
                                for stmt in clause_pair.into_inner() {
                                    result = crate::eval_pair(stmt, scope)?;
                                }

                                // Propagate self mutations
                                if let Some(updated_self) = scope.get("self") {
                                    scope.pop();
                                    scope.set("self", updated_self);
                                } else {
                                    scope.pop();
                                }

                                push_result_to_parent(&mut stack, result, &mut final_result)?;
                                found_match = true;
                                break;
                            }
                            _ => {}
                        }
                    }

                    if !found_match {
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                    }
                }
            }

            // ================================================================
            // Binary Operators - Addition (+ -)
            // ================================================================

            (Rule::addition, EvalState::Initial) => {
                // addition = { multiplication ~ (add_op ~ multiplication)* }
                // We need to evaluate left, then for each operator+right pair
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                // Collect operations (operator + right operand pairs)
                let mut ops = Vec::new();
                while let Some(op_pair) = inner.next() {
                    if op_pair.as_rule() == Rule::add_op {
                        let op = op_pair.as_str().to_string();
                        let right = inner.next().unwrap();
                        ops.push((op, right));
                    }
                }

                if ops.is_empty() {
                    // No operators, just evaluate the single operand
                    stack.push(EvalFrame::new(left));
                } else {
                    // Push continuation frame
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: Some(EvalContext::Assignment(AssignmentState {
                            var_name: None,
                            base: None,
                            indices: Vec::new(),
                            compound_op: None, // We'll store op count here temporarily
                        })),
                    });

                    // Push left operand evaluation
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::addition, EvalState::EvalLeft) => {
                // Left is now evaluated, process operators
                let left_result = frame.partial_results.pop().unwrap();
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left (already evaluated)

                let mut result = left_result;

                // Process each operator
                while let Some(op_pair) = inner.next() {
                    if op_pair.as_rule() == Rule::add_op {
                        let op = op_pair.as_str();
                        let right_pair = inner.next().unwrap();

                        // Evaluate right operand
                        // Push continuation + right evaluation
                        // For simplicity now, we'll process iteratively in a loop
                        // TODO: Make this properly iterative by using states
                        let right_result = crate::eval_pair(right_pair, scope)?;

                        result = match op {
                            "+" => {
                                // Fast path for Int + Int (QEP-042 optimization #3)
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right_result) {
                                    match l.value.checked_add(r.value) {
                                        Some(sum) => QValue::Int(QInt::new(sum)),
                                        None => return runtime_err!("Integer overflow in addition"),
                                    }
                                } else {
                                    match &result {
                                        QValue::Int(i) => i.call_method("plus", vec![right_result])?,
                                        QValue::Float(f) => f.call_method("plus", vec![right_result])?,
                                        QValue::Decimal(d) => d.call_method("plus", vec![right_result])?,
                                        QValue::BigInt(bi) => bi.call_method("plus", vec![right_result])?,
                                        _ => {
                                            let left_num = result.as_num()?;
                                            let right_num = right_result.as_num()?;
                                            QValue::Float(QFloat::new(left_num + right_num))
                                        }
                                    }
                                }
                            },
                            "-" => {
                                // Fast path for Int - Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right_result) {
                                    match l.value.checked_sub(r.value) {
                                        Some(diff) => QValue::Int(QInt::new(diff)),
                                        None => return runtime_err!("Integer overflow in subtraction"),
                                    }
                                } else {
                                    match &result {
                                        QValue::Int(i) => i.call_method("minus", vec![right_result])?,
                                        QValue::Float(f) => f.call_method("minus", vec![right_result])?,
                                        QValue::Decimal(d) => d.call_method("minus", vec![right_result])?,
                                        QValue::BigInt(bi) => bi.call_method("minus", vec![right_result])?,
                                        _ => {
                                            let left_num = result.as_num()?;
                                            let right_num = right_result.as_num()?;
                                            QValue::Float(QFloat::new(left_num - right_num))
                                        }
                                    }
                                }
                            },
                            _ => return Err(format!("Unknown operator: {}", op)),
                        };
                    }
                }

                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            // ================================================================
            // TODO: Implement remaining Rule cases
            // Phase 2 in progress - literals done, addition done, need more operators
            // ================================================================

            _ => {
                return Err(format!(
                    "Unimplemented rule in iterative evaluator: {:?} in state {:?}",
                    frame.pair.as_rule(),
                    frame.state
                ));
            }
        }
    }

    // Return the final result
    final_result.ok_or_else(|| "Evaluation completed without producing a result".to_string())
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Push a result to the parent frame's partial_results.
/// If there's no parent frame, return the result (it's the final value).
fn push_result_to_parent<'i>(
    stack: &mut Vec<EvalFrame<'i>>,
    result: QValue,
    final_result: &mut Option<QValue>,
) -> Result<(), String> {
    if let Some(parent) = stack.last_mut() {
        parent.partial_results.push(result);
        Ok(())
    } else {
        // No parent - this is the final result
        *final_result = Some(result);
        Ok(())
    }
}

// ============================================================================
// Future Implementation Notes
// ============================================================================

// Phase 2 (Simple Rules):
// - Literals: boolean, integer, float, string, bytes, etc.
// - Unary operators: logical_not, unary_minus, etc.
// - Binary operators: addition, subtraction, multiplication, etc.
// - Comparisons: eq, neq, lt, gt, lte, gte

// Phase 3 (Control Flow):
// - if_statement with elif/else chains
// - match_statement with case matching
// - while_statement with break/continue
// - for_statement with iterators

// Phase 4 (Postfix Chains):
// - method_call with argument evaluation
// - field_access
// - index_access
// - Chained operations: obj.method()[0].field

// Phase 5 (Complex Features):
// - function_declaration (capture closures)
// - type_declaration (parse fields/methods)
// - try/catch/ensure with exception propagation
// - with_statement (context managers)
// - assignment (simple and indexed)
// - let_statement / const_declaration

// Phase 6 (Integration):
// - Replace all eval_pair call sites
// - Maintain call_stack for debugging
// - Update function call integration
