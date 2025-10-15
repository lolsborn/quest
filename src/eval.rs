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
use crate::{value_err, runtime_err, attr_err, name_err};
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
    /// Evaluating while body statement at index
    WhileEvalBody(usize),
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
    /// Try/catch/ensure exception handling state
    Try(TryState<'i>),
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
    /// Current statement being evaluated in body
    pub current_stmt: usize,
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
    /// Method name (for method calls)
    pub method_name: Option<String>,
    /// Evaluated positional arguments
    pub args: Vec<QValue>,
    /// Evaluated keyword arguments
    pub kwargs: HashMap<String, QValue>,
    /// Unevaluated argument expressions
    pub arg_pairs: Vec<Pair<'i, Rule>>,
    /// Current argument index being evaluated
    pub current_arg: usize,
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

/// State for try/catch/ensure exception handling
#[derive(Clone)]
pub struct TryState<'i> {
    /// Try block statements
    pub try_body: Vec<Pair<'i, Rule>>,
    /// Catch clauses: (var_name, optional_type_filter, body_statements)
    pub catch_clauses: Vec<(String, Option<String>, Vec<Pair<'i, Rule>>)>,
    /// Ensure block statements (always executed)
    pub ensure_block: Option<Vec<Pair<'i, Rule>>>,
    /// Caught exception (if any)
    pub exception: Option<QException>,
    /// Result from try or catch block
    pub result: Option<QValue>,
    /// Whether exception was caught
    pub caught: bool,
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
    'eval_loop: while let Some(mut frame) = stack.pop() {
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

            // REMOVED: Duplicate expression handler - complete version at line ~871

            (Rule::literal, EvalState::Initial) => {
                let inner = frame.pair.into_inner().next().unwrap();
                stack.push(EvalFrame::new(inner));
            }

            // Passthrough for operator precedence rules (when no operator present)
            (Rule::multiplication, EvalState::Initial) => {
                // multiplication = { unary ~ (mul_op ~ unary)* }
                let mut inner = frame.pair.clone().into_inner();
                let count = inner.clone().count();

                if count == 1 {
                    // No operator, just pass through to unary
                    let left = inner.next().unwrap();
                    stack.push(EvalFrame::new(left));
                } else {
                    // Has operators - implement iteratively
                    let left = inner.next().unwrap();
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

            (Rule::multiplication, EvalState::EvalLeft) => {
                // Left operand evaluated, process operators
                let left_result = frame.partial_results.pop().unwrap();
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left (already evaluated)

                let mut result = left_result;

                // Process each operator
                while let Some(op_pair) = inner.next() {
                    if op_pair.as_rule() == Rule::mul_op {
                        let op = op_pair.as_str();
                        let right_pair = inner.next().unwrap();

                        // Evaluate right operand (using recursive eval for now)
                        let right = crate::eval_pair_impl(right_pair, scope)?;

                        result = match op {
                            "*" => {
                                // Fast path for Int * Int (QEP-042 optimization)
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
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
                                // Fast path for Int / Int
                                if let (QValue::Int(l), QValue::Int(r)) = (&result, &right) {
                                    if r.value == 0 {
                                        return Err("Division by zero".to_string());
                                    }
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
                                // Fast path for Int % Int
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
                            _ => return Err(format!("Unknown operator: {}", op)),
                        };
                    }
                }

                push_result_to_parent(&mut stack, result, &mut final_result)?;
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
                // Base has been evaluated, now collect and process postfix operations
                let base_result = frame.partial_results.pop().unwrap();

                // Collect all postfix operations
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip primary (already evaluated)
                let operations: Vec<_> = inner.collect();

                if operations.is_empty() {
                    // No operations, just return base
                    push_result_to_parent(&mut stack, base_result, &mut final_result)?;
                } else {
                    // Setup postfix state and start processing operations
                    let context = EvalContext::Postfix(PostfixState {
                        operations: operations.clone(),
                        current_base: Some(base_result),
                    });

                    // Push frame to apply first operation
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::PostfixApplyOperation(0),
                        partial_results: Vec::new(),
                        context: Some(context),
                    });
                }
            }

            (Rule::postfix, EvalState::PostfixApplyOperation(op_index)) => {
                // Apply a postfix operation (method call, member access, or indexing)
                let mut context = frame.context.unwrap();

                if let EvalContext::Postfix(ref mut postfix_state) = context {
                    let op_index = *op_index;

                    if op_index >= postfix_state.operations.len() {
                        // All operations applied, return final result
                        let final_val = postfix_state.current_base.take().unwrap();
                        push_result_to_parent(&mut stack, final_val, &mut final_result)?;
                    } else {
                        let operation = &postfix_state.operations[op_index];
                        let current_base = postfix_state.current_base.as_ref().unwrap();

                        match operation.as_rule() {
                            Rule::method_name | Rule::identifier => {
                                // This is either member access or method call
                                // We need to check if there's an argument_list following
                                let method_name = operation.as_str();

                                // Check if next operation is argument_list
                                let has_args = op_index + 1 < postfix_state.operations.len()
                                    && postfix_state.operations[op_index + 1].as_rule() == Rule::argument_list;

                                // Also check if original source has () for zero-arg calls
                                let pair_str = frame.pair.as_str();
                                let pair_start = frame.pair.as_span().start();
                                let span_end_absolute = operation.as_span().end();
                                let span_end_relative = span_end_absolute - pair_start;

                                let has_parens = if let Some(remaining) = pair_str.get(span_end_relative..) {
                                    remaining.trim_start().starts_with("()")
                                } else {
                                    false
                                };

                                if has_parens || has_args {
                                    // METHOD CALL - evaluate arguments iteratively
                                    let (arg_pairs, needs_fallback) = if has_args {
                                        // Parse argument_list
                                        let args_pair = postfix_state.operations[op_index + 1].clone();
                                        // Extract argument items (simplified - only handle expressions for now)
                                        let mut items = Vec::new();
                                        let mut has_complex_args = false;
                                        for arg_item in args_pair.into_inner() {
                                            if arg_item.as_rule() == Rule::argument_item {
                                                let item = arg_item.into_inner().next().unwrap();
                                                // For now, only handle simple expressions (not named_arg, unpack_args, unpack_kwargs)
                                                if item.as_rule() == Rule::expression {
                                                    items.push(item);
                                                } else {
                                                    // Has named args, unpacking, etc - need fallback
                                                    has_complex_args = true;
                                                    break;
                                                }
                                            }
                                        }
                                        (items, has_complex_args)
                                    } else {
                                        (Vec::new(), false)
                                    };

                                    if needs_fallback {
                                        // Has named args, unpacking, etc - fall back to recursive
                                        let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                                        push_result_to_parent(&mut stack, result, &mut final_result)?;
                                    } else {
                                        // Store method name and next operation index
                                        let next_op = if has_args { op_index + 2 } else { op_index + 1 };

                                        // Setup call state
                                        let call_state = CallState {
                                            function: Some(current_base.clone()),
                                            method_name: Some(method_name.to_string()),
                                            args: Vec::new(),
                                            kwargs: HashMap::new(),
                                            arg_pairs: arg_pairs,
                                            current_arg: 0,
                                            array_unpacks: Vec::new(),
                                            dict_unpacks: Vec::new(),
                                        };

                                        // Push frame to continue postfix chain after call completes
                                        stack.push(EvalFrame {
                                            pair: frame.pair.clone(),
                                            state: EvalState::PostfixApplyOperation(next_op),
                                            partial_results: Vec::new(),
                                            context: Some(context.clone()),
                                        });

                                        // Push frame to start evaluating arguments
                                        stack.push(EvalFrame {
                                            pair: frame.pair.clone(),
                                            state: EvalState::CallEvalArg(0),
                                            partial_results: Vec::new(),
                                            context: Some(EvalContext::FunctionCall(call_state)),
                                        });
                                    }
                                } else {
                                    // MEMBER ACCESS - Return method reference or field value
                                    use crate::attr_err;
                                    let result = match current_base {
                                        QValue::Module(module) => {
                                            // Access module member
                                            module.get_member(method_name)
                                                .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?
                                        }
                                        QValue::Process(proc) => {
                                            // Access process streams
                                            match method_name {
                                                "stdin" => QValue::WritableStream(proc.stdin.clone()),
                                                "stdout" => QValue::ReadableStream(proc.stdout.clone()),
                                                "stderr" => QValue::ReadableStream(proc.stderr.clone()),
                                                _ => return attr_err!("Process has no field '{}'", method_name),
                                            }
                                        }
                                        QValue::Struct(qstruct) => {
                                            // Struct field access with privacy checks
                                            let (field_value_opt, type_name, qstruct_id) = {
                                                let borrowed = qstruct.borrow();
                                                (
                                                    borrowed.fields.get(method_name).cloned(),
                                                    borrowed.type_name.clone(),
                                                    borrowed.id
                                                )
                                            };

                                            if let Some(field_value) = field_value_opt {
                                                // Check if field is public (unless accessing self)
                                                let is_self_access = if let Some(QValue::Struct(self_struct)) = scope.get("self") {
                                                    self_struct.borrow().id == qstruct_id
                                                } else {
                                                    false
                                                };

                                                if !is_self_access {
                                                    if let Some(qtype) = crate::find_type_definition(&type_name, scope) {
                                                        if let Some(field_def) = qtype.fields.iter().find(|f| f.name == method_name) {
                                                            if !field_def.is_public {
                                                                return attr_err!("Field '{}' of type {} is private", method_name, type_name);
                                                            }
                                                        }
                                                    }
                                                }
                                                field_value
                                            } else {
                                                return attr_err!("Struct {} has no field '{}'", type_name, method_name);
                                            }
                                        }
                                        _ => {
                                            // Return method reference (QFun)
                                            let parent_type = current_base.as_obj().cls();
                                            QValue::Fun(QFun::new(method_name.to_string(), parent_type))
                                        }
                                    };

                                    // Update current_base with result
                                    postfix_state.current_base = Some(result);

                                    // Continue with next operation
                                    stack.push(EvalFrame {
                                        pair: frame.pair.clone(),
                                        state: EvalState::PostfixApplyOperation(op_index + 1),
                                        partial_results: Vec::new(),
                                        context: Some(context),
                                    });
                                }
                            }

                            Rule::index_access => {
                                // INDEX ACCESS - arr[i] or dict[key]
                                // Evaluate index expression iteratively
                                let mut index_inner = operation.clone().into_inner();
                                let index_expr = index_inner.next().unwrap();

                                // Check for multi-dimensional access (not yet supported)
                                if index_inner.next().is_some() {
                                    return Err("Multi-dimensional array access not yet implemented".to_string());
                                }

                                // Push frame to apply index after it's evaluated
                                stack.push(EvalFrame {
                                    pair: frame.pair.clone(),
                                    state: EvalState::PostfixEvalOperation(op_index),
                                    partial_results: Vec::new(),
                                    context: Some(context.clone()),
                                });

                                // Push frame to evaluate index expression
                                stack.push(EvalFrame::new(index_expr));
                            }

                            Rule::argument_list => {
                                // Skip - handled by method_call case above
                                stack.push(EvalFrame {
                                    pair: frame.pair.clone(),
                                    state: EvalState::PostfixApplyOperation(op_index + 1),
                                    partial_results: Vec::new(),
                                    context: Some(context),
                                });
                            }

                            _ => {
                                return Err(format!("Unsupported postfix operation: {:?}", operation.as_rule()));
                            }
                        }
                    }
                } else {
                    return Err("Invalid context for PostfixApplyOperation".to_string());
                }
            }

            (Rule::postfix, EvalState::PostfixEvalOperation(op_index)) => {
                // Index expression has been evaluated, now apply the index operation
                let index_value = frame.partial_results.pop().unwrap();
                let mut context = frame.context.unwrap();

                if let EvalContext::Postfix(ref mut postfix_state) = context {
                    let current_base = postfix_state.current_base.as_ref().unwrap();

                    // Apply index operation based on type
                    let result = match current_base {
                        QValue::Array(arr) => {
                            let index = index_value.as_num()? as i64;
                            let len = arr.len() as i64;

                            // Support negative indexing
                            let actual_index = if index < 0 {
                                (len + index) as usize
                            } else {
                                index as usize
                            };

                            arr.get(actual_index)
                                .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, arr.len()))?
                                .clone()
                        }
                        QValue::Dict(dict) => {
                            let key = index_value.as_str();
                            match dict.get(&key) {
                                Some(v) => v.clone(),
                                None => QValue::Nil(QNil),
                            }
                        }
                        QValue::Str(s) => {
                            // String indexing requires Int or BigInt (that fits in Int)
                            use crate::type_err;
                            if !matches!(index_value, QValue::Int(_) | QValue::BigInt(_)) {
                                return type_err!("String index must be Int, got {}", index_value.as_obj().cls());
                            }
                            let index = index_value.as_num()? as i64;
                            let len = s.value.chars().count() as i64;

                            // Support negative indexing
                            let actual_index = if index < 0 {
                                (len + index) as usize
                            } else {
                                index as usize
                            };

                            let ch = s.value.chars().nth(actual_index)
                                .ok_or_else(|| format!("Index {} out of bounds for string of length {}", index, len))?;
                            QValue::Str(QString::new(ch.to_string()))
                        }
                        QValue::Bytes(b) => {
                            // Bytes indexing requires Int or BigInt (that fits in Int)
                            use crate::type_err;
                            if !matches!(index_value, QValue::Int(_) | QValue::BigInt(_)) {
                                return type_err!("Bytes index must be Int, got {}", index_value.as_obj().cls());
                            }
                            let index = index_value.as_num()? as i64;
                            let len = b.data.len() as i64;

                            // Support negative indexing
                            let actual_index = if index < 0 {
                                (len + index) as usize
                            } else {
                                index as usize
                            };

                            let byte = b.data.get(actual_index)
                                .ok_or_else(|| format!("Index {} out of bounds for bytes of length {}", index, len))?;
                            QValue::Int(QInt::new(*byte as i64))
                        }
                        _ => {
                            return Err(format!("Type {} does not support indexing", current_base.as_obj().cls()));
                        }
                    };

                    // Update current_base with the result
                    postfix_state.current_base = Some(result);

                    // Continue with next operation
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::PostfixApplyOperation(*op_index + 1),
                        partial_results: Vec::new(),
                        context: Some(context),
                    });
                } else {
                    return Err("Invalid context for PostfixEvalOperation".to_string());
                }
            }

            // ================================================================
            // Function/Method Call Argument Evaluation
            // ================================================================

            (_rule, EvalState::CallEvalArg(arg_index)) => {
                // Check if we're starting to evaluate an argument or collecting its result
                let mut context = frame.context.ok_or("Missing context for CallEvalArg")?;

                if let EvalContext::FunctionCall(ref mut call_state) = context {
                    let arg_idx = *arg_index;

                    if !frame.partial_results.is_empty() {
                        // We have a result - this is the return from evaluating the argument expression
                        let arg_value = frame.partial_results.pop().unwrap();
                        call_state.args.push(arg_value);
                        call_state.current_arg = arg_idx + 1;

                        // Check if there are more arguments to evaluate
                        if call_state.current_arg < call_state.arg_pairs.len() {
                            // Evaluate next argument
                            let next_arg_pair = call_state.arg_pairs[call_state.current_arg].clone();

                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::CallEvalArg(call_state.current_arg),
                                partial_results: Vec::new(),
                                context: Some(context),
                            });

                            stack.push(EvalFrame::new(next_arg_pair));
                        } else {
                            // All arguments evaluated, execute the call
                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::CallExecute,
                                partial_results: Vec::new(),
                                context: Some(context),
                            });
                        }
                    } else {
                        // Starting evaluation - push the first argument expression
                        if arg_idx < call_state.arg_pairs.len() {
                            let arg_pair = call_state.arg_pairs[arg_idx].clone();

                            // Push frame to collect result
                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::CallEvalArg(arg_idx),
                                partial_results: Vec::new(),
                                context: Some(context),
                            });

                            // Push frame to evaluate expression
                            stack.push(EvalFrame::new(arg_pair));
                        } else {
                            // No arguments, go straight to execute
                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::CallExecute,
                                partial_results: Vec::new(),
                                context: Some(context),
                            });
                        }
                    }
                } else {
                    return Err("Invalid context for CallEvalArg".to_string());
                }
            }

            (_rule, EvalState::CallExecute) => {
                // All arguments have been evaluated, now execute the method call
                let context = frame.context.ok_or("Missing context for CallExecute")?;

                if let EvalContext::FunctionCall(call_state) = context {
                    let method_name = call_state.method_name.as_ref()
                        .ok_or("Missing method name in CallState")?;

                    let base = call_state.function.as_ref()
                        .ok_or("Missing function in CallState")?;

                    // Special handling for module method calls
                    let result = if let QValue::Module(module) = base {
                        // Check for built-in module methods first
                        match method_name.as_str() {
                            "_doc" => QValue::Str(QString::new(module._doc())),
                            "str" => QValue::Str(QString::new(module.str())),
                            "_rep" => QValue::Str(QString::new(module._rep())),
                            "_id" => QValue::Int(QInt::new(module._id() as i64)),
                            _ => {
                                // Get member and call it as a function
                                let func = module.get_member(method_name)
                                    .ok_or_else(|| format!("Module {} has no member '{}'", module.name, method_name))?;

                                match func {
                                    QValue::Fun(f) => {
                                        // Call builtin function with namespaced name
                                        let namespaced_name = if f.parent_type.is_empty() {
                                            f.name.clone()
                                        } else {
                                            format!("{}.{}", f.parent_type, f.name)
                                        };
                                        crate::call_builtin_function(&namespaced_name, call_state.args.clone(), scope)?
                                    }
                                    QValue::UserFun(user_fn) => {
                                        use std::rc::Rc;
                                        let mut module_scope = Scope::with_shared_base(
                                            module.get_members_ref(),
                                            Rc::clone(&scope.module_cache)
                                        );

                                        module_scope.push();
                                        for (k, v) in scope.to_flat_map() {
                                            if !module_scope.scopes[0].borrow().contains_key(&k) {
                                                module_scope.scopes[1].borrow_mut().insert(k, v);
                                            }
                                        }

                                        // Inherit I/O redirection
                                        module_scope.stdout_target = scope.stdout_target.clone();
                                        module_scope.stderr_target = scope.stderr_target.clone();

                                        // Convert args to CallArguments
                                        let call_args = crate::function_call::CallArguments::positional_only(call_state.args.clone());
                                        crate::call_user_function(&user_fn, call_args, &mut module_scope)?
                                    }
                                    _ => return Err(format!("Module member '{}' is not a function", method_name)),
                                }
                            }
                        }
                    } else if method_name == "is" {
                        // Universal .is() method for all types
                        use crate::arg_err;
                        if call_state.args.len() != 1 {
                            return arg_err!(".is() expects 1 argument (type name), got {}", call_state.args.len());
                        }
                        // Accept either Type objects or string type names (lowercase)
                        let type_name = match &call_state.args[0] {
                            QValue::Type(t) => t.name.as_str(),
                            QValue::Str(s) => s.value.as_str(),
                            _ => return Err(".is() argument must be a type or string".to_string()),
                        };
                        // Compare using lowercase
                        let actual_type = base.as_obj().cls().to_lowercase();
                        let expected_type = type_name.to_lowercase();
                        QValue::Bool(QBool::new(actual_type == expected_type))
                    } else if let QValue::Trait(qtrait) = base {
                        // Trait built-in methods
                        match method_name.as_str() {
                            "_doc" => QValue::Str(QString::new(qtrait._doc())),
                            "str" => QValue::Str(QString::new(qtrait.str())),
                            "_rep" => QValue::Str(QString::new(qtrait._rep())),
                            "_id" => QValue::Int(QInt::new(qtrait._id() as i64)),
                            _ => return attr_err!("Trait {} has no method '{}'", qtrait.name, method_name),
                        }
                    } else if let QValue::Type(qtype) = base {
                        // Type static methods and built-in methods
                        match method_name.as_str() {
                            "_doc" => QValue::Str(QString::new(qtype._doc())),
                            "str" => QValue::Str(QString::new(qtype.str())),
                            "_rep" => QValue::Str(QString::new(qtype._rep())),
                            "_id" => QValue::Int(QInt::new(qtype._id() as i64)),
                            "new" => {
                                // Type.new() constructor - fall back to recursive evaluator
                                // This requires complex constructor handling (positional + named args)
                                crate::eval_pair_impl(frame.pair.clone(), scope)?
                            }
                            _ => {
                                // Try static methods
                                if let Some(static_method) = qtype.get_static_method(method_name) {
                                    let call_args = crate::function_call::CallArguments::positional_only(call_state.args.clone());
                                    crate::call_user_function(&static_method, call_args, scope)?
                                } else if qtype.name == "BigInt" {
                                    // BigInt static methods (from_int, from_bytes, etc.)
                                    crate::types::bigint::call_bigint_static_method(method_name, call_state.args.clone())?
                                } else if qtype.name == "Decimal" {
                                    // Decimal static methods
                                    crate::types::decimal::call_decimal_static_method(method_name, call_state.args.clone())?
                                } else if qtype.name == "Array" {
                                    // Array static methods (Array.new)
                                    crate::types::array::call_array_static_method(method_name, call_state.args.clone())?
                                } else {
                                    return attr_err!("Type {} has no method '{}'", qtype.name, method_name);
                                }
                            }
                        }
                    } else if let QValue::Struct(qstruct) = base {
                        // Struct special methods (does)
                        if method_name == "does" {
                            // Check if struct's type implements a trait
                            use crate::arg_err;
                            if call_state.args.len() != 1 {
                                return arg_err!(".does() expects 1 argument (trait), got {}", call_state.args.len());
                            }
                            if let QValue::Trait(check_trait) = &call_state.args[0] {
                                let type_name = qstruct.borrow().type_name.clone();
                                if let Some(qtype) = crate::find_type_definition(&type_name, scope) {
                                    QValue::Bool(QBool::new(qtype.implemented_traits.contains(&check_trait.name)))
                                } else {
                                    return Err(format!("Type {} not found", type_name));
                                }
                            } else {
                                return Err(".does() argument must be a trait".to_string());
                            }
                        } else {
                            // Other struct methods - use call_method_on_value
                            crate::call_method_on_value(base, method_name, call_state.args.clone(), scope)?
                        }
                    } else {
                        // For other values, use call_method_on_value
                        crate::call_method_on_value(
                            base,
                            method_name,
                            call_state.args.clone(),
                            scope
                        )?
                    };

                    // Update current_base in the parent PostfixApplyOperation frame
                    if let Some(parent) = stack.last_mut() {
                        if let Some(EvalContext::Postfix(ref mut postfix_state)) = parent.context {
                            postfix_state.current_base = Some(result);
                        }
                    }
                } else {
                    return Err("Invalid context for CallExecute".to_string());
                }
            }

            // REMOVED: Duplicate primary handler - complete version at line ~1874


            // ================================================================
            // Expression (top level)
            // ================================================================

            (Rule::expression, EvalState::Initial) => {
                // expression = { lambda | elvis_expr }
                let mut inner = frame.pair.clone().into_inner();
                let child = inner.next().unwrap();

                // Check if it's a lambda (starts with "fun")
                if frame.pair.as_str().trim_start().starts_with("fun") {
                    // Lambda - fall back to recursive
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                } else {
                    // Elvis expression - evaluate iteratively
                    stack.push(EvalFrame::new(child));
                }
            }

            // More operator precedence passthroughs
            (Rule::elvis_expr, EvalState::Initial) => {
                // elvis_expr = { logical_or ~ (elvis_op ~ logical_or)* }
                // QEP-019: expr ?: default - if expr is nil, use default
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                // Check if there are elvis operators
                let has_ops = inner.clone().count() > 0;
                if !has_ops {
                    stack.push(EvalFrame::new(left));
                } else {
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::elvis_expr, EvalState::EvalLeft) => {
                let mut result = frame.partial_results.pop().unwrap();
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left

                for next in inner {
                    // Skip elvis_op tokens
                    if matches!(next.as_rule(), Rule::elvis_op) {
                        continue;
                    }

                    // If result is nil, evaluate right side and use it
                    if matches!(result, QValue::Nil(_)) {
                        result = crate::eval_pair_impl(next, scope)?;
                    }
                    // Otherwise keep result (short-circuit)
                }

                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            (Rule::logical_or, EvalState::Initial) => {
                // logical_or = { logical_and ~ (or_op ~ logical_and)* }
                let mut inner = frame.pair.clone().into_inner();
                let count = inner.clone().count();

                if count == 1 {
                    // No operators, pass through
                    let first = inner.next().unwrap();
                    stack.push(EvalFrame::new(first));
                } else {
                    // Has OR operators - need short-circuit evaluation
                    let first = inner.next().unwrap();
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(first));
                }
            }

            (Rule::logical_or, EvalState::EvalLeft) => {
                // Left evaluated, check for short-circuit
                let left_result = frame.partial_results.pop().unwrap();

                // Short-circuit: if left is truthy, return it immediately
                if left_result.as_bool() {
                    push_result_to_parent(&mut stack, left_result, &mut final_result)?;
                } else {
                    // Left is falsy, evaluate right side
                    let mut inner = frame.pair.clone().into_inner();
                    inner.next(); // Skip left (already evaluated)

                    // Skip or_op tokens and evaluate remaining operands
                    let mut result = left_result;
                    for next in inner {
                        if matches!(next.as_rule(), Rule::or_op) {
                            continue;
                        }
                        // Evaluate right operand
                        result = crate::eval_pair_impl(next, scope)?;
                        // Short-circuit if truthy
                        if result.as_bool() {
                            break;
                        }
                    }
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::logical_and, EvalState::Initial) => {
                // logical_and = { logical_not ~ (and_op ~ logical_not)* }
                let mut inner = frame.pair.clone().into_inner();
                let count = inner.clone().count();

                if count == 1 {
                    // No operators, pass through
                    let first = inner.next().unwrap();
                    stack.push(EvalFrame::new(first));
                } else {
                    // Has AND operators - need short-circuit evaluation
                    let first = inner.next().unwrap();
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(first));
                }
            }

            (Rule::logical_and, EvalState::EvalLeft) => {
                // Left evaluated, check for short-circuit
                let left_result = frame.partial_results.pop().unwrap();

                // Short-circuit: if left is falsy, return it immediately
                if !left_result.as_bool() {
                    push_result_to_parent(&mut stack, left_result, &mut final_result)?;
                } else {
                    // Left is truthy, evaluate right side
                    let mut inner = frame.pair.clone().into_inner();
                    inner.next(); // Skip left (already evaluated)

                    // Skip and_op tokens and evaluate remaining operands
                    let mut result = left_result;
                    for next in inner {
                        if matches!(next.as_rule(), Rule::and_op) {
                            continue;
                        }
                        // Evaluate right operand
                        result = crate::eval_pair_impl(next, scope)?;
                        // Short-circuit if falsy
                        if !result.as_bool() {
                            break;
                        }
                    }
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::comparison, EvalState::Initial) => {
                // comparison = { concat ~ (comparison_op ~ concat)* }
                let mut inner = frame.pair.clone().into_inner();
                let count = inner.clone().count();

                if count == 1 {
                    // No operators, just evaluate left
                    let left = inner.next().unwrap();
                    stack.push(EvalFrame::new(left));
                } else {
                    // Has comparison operators - use hybrid approach
                    let left = inner.next().unwrap();
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
                        let right = crate::eval_pair_impl(right_pair, scope)?;

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
                // concat = { addition ~ (".." ~ addition)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                // Check if there are concat operators (..)
                let remaining: Vec<_> = inner.collect();
                if remaining.is_empty() {
                    // No concat operators - just evaluate left
                    stack.push(EvalFrame::new(left));
                } else {
                    // Has concat operators - evaluate left first
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::concat, EvalState::EvalLeft) => {
                // Left evaluated, concatenate remaining parts
                let left_result = frame.partial_results.pop().unwrap();
                let mut concat_result = left_result.as_str();

                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left (already evaluated)

                // Concatenate all remaining parts (skip ".." operator tokens)
                for next in inner {
                    let right = crate::eval_pair_impl(next, scope)?;
                    concat_result.push_str(&right.as_str());
                }

                let value = QValue::Str(QString::new(concat_result));
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::logical_not, EvalState::Initial) => {
                // logical_not = { not_op* ~ bitwise_or }
                // Count NOT operators, evaluate bitwise_or, apply NOTs
                let mut inner = frame.pair.clone().into_inner();
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

                if not_count == 0 {
                    // No NOT operators - just evaluate bitwise_or
                    stack.push(EvalFrame::new(expr_pair.unwrap()));
                } else {
                    // Has NOT operators - evaluate expression first
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(expr_pair.unwrap()));
                }
            }

            (Rule::logical_not, EvalState::EvalLeft) => {
                // Expression evaluated, apply NOT operators
                let mut value = frame.partial_results.pop().unwrap();

                // Count NOTs from original pair
                let mut inner = frame.pair.clone().into_inner();
                let mut not_count = 0;
                for child in inner {
                    if child.as_rule() == Rule::not_op {
                        not_count += 1;
                    }
                }

                // Apply NOT not_count times
                for _ in 0..not_count {
                    value = QValue::Bool(QBool::new(!value.as_bool()));
                }

                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::bitwise_or, EvalState::Initial) => {
                // bitwise_or = { bitwise_xor ~ ("|" ~ bitwise_xor)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();
                let remaining: Vec<_> = inner.collect();

                if remaining.is_empty() {
                    // No operators - passthrough
                    stack.push(EvalFrame::new(left));
                } else {
                    // Has operators - evaluate left first
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::bitwise_or, EvalState::EvalLeft) => {
                // Left evaluated, apply bitwise OR to remaining operands
                let left_result = frame.partial_results.pop().unwrap();
                let mut int_result = left_result.as_num()? as i64;

                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left

                for next in inner {
                    let right = crate::eval_pair_impl(next, scope)?.as_num()? as i64;
                    int_result |= right;
                }

                let value = QValue::Int(QInt::new(int_result));
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::bitwise_xor, EvalState::Initial) => {
                // bitwise_xor = { bitwise_and ~ ("^" ~ bitwise_and)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();
                let remaining: Vec<_> = inner.collect();

                if remaining.is_empty() {
                    stack.push(EvalFrame::new(left));
                } else {
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::bitwise_xor, EvalState::EvalLeft) => {
                let left_result = frame.partial_results.pop().unwrap();
                let mut int_result = left_result.as_num()? as i64;

                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left

                for next in inner {
                    let right = crate::eval_pair_impl(next, scope)?.as_num()? as i64;
                    int_result ^= right;
                }

                let value = QValue::Int(QInt::new(int_result));
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::bitwise_and, EvalState::Initial) => {
                // bitwise_and = { shift ~ ("&" ~ shift)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();
                let remaining: Vec<_> = inner.collect();

                if remaining.is_empty() {
                    stack.push(EvalFrame::new(left));
                } else {
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::bitwise_and, EvalState::EvalLeft) => {
                let left_result = frame.partial_results.pop().unwrap();
                let mut int_result = left_result.as_num()? as i64;

                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left

                for next in inner {
                    let right = crate::eval_pair_impl(next, scope)?.as_num()? as i64;
                    int_result &= right;
                }

                let value = QValue::Int(QInt::new(int_result));
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::shift, EvalState::Initial) => {
                // shift = { comparison ~ (("<<" | ">>") ~ comparison)* }
                let mut inner = frame.pair.clone().into_inner();
                let left = inner.next().unwrap();

                // Check if there are shift operators
                let has_ops = inner.next().is_some();
                if !has_ops {
                    stack.push(EvalFrame::new(left));
                } else {
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft,
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(left));
                }
            }

            (Rule::shift, EvalState::EvalLeft) => {
                let mut result = frame.partial_results.pop().unwrap();
                let mut inner = frame.pair.clone().into_inner();
                inner.next(); // Skip left

                while let Some(op_pair) = inner.next() {
                    let operator = op_pair.as_str();
                    let right = crate::eval_pair_impl(inner.next().unwrap(), scope)?;

                    let left_val = result.as_num()? as i64;
                    let right_val = right.as_num()? as i64;

                    let shifted = match operator {
                        "<<" => left_val.checked_shl(right_val as u32)
                            .ok_or_else(|| format!("Left shift overflow: {} << {}", left_val, right_val))?,
                        ">>" => left_val.checked_shr(right_val as u32)
                            .ok_or_else(|| format!("Right shift overflow: {} >> {}", left_val, right_val))?,
                        _ => return Err(format!("Unknown shift operator: {}", operator)),
                    };

                    result = QValue::Int(QInt::new(shifted));
                }

                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            // ================================================================
            // Unary Operators (-, +, ~)
            // ================================================================

            (Rule::unary, EvalState::Initial) => {
                // unary = { unary_op* ~ postfix }
                // Collect operators, evaluate postfix, apply ops right-to-left
                let mut inner = frame.pair.clone().into_inner();
                let mut ops = Vec::new();
                let mut postfix_pair = None;

                for child in inner {
                    match child.as_rule() {
                        Rule::unary_op => ops.push(child.as_str().to_string()),
                        Rule::postfix => {
                            postfix_pair = Some(child);
                            break;
                        }
                        _ => {}
                    }
                }

                if ops.is_empty() {
                    // No unary operators - just evaluate postfix
                    stack.push(EvalFrame::new(postfix_pair.unwrap()));
                } else {
                    // Has unary operators - evaluate postfix first, then apply ops
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::EvalLeft, // Reuse EvalLeft for "postfix evaluated"
                        partial_results: Vec::new(),
                        context: None,
                    });
                    stack.push(EvalFrame::new(postfix_pair.unwrap()));
                }
            }

            (Rule::unary, EvalState::EvalLeft) => {
                // Postfix evaluated, now apply unary operators
                let mut value = frame.partial_results.pop().unwrap();

                // Collect operators from the original pair
                let mut inner = frame.pair.clone().into_inner();
                let mut ops = Vec::new();
                for child in inner {
                    if child.as_rule() == Rule::unary_op {
                        ops.push(child.as_str());
                    }
                }

                // Apply operators right-to-left (closest to operand first)
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
                                QValue::Int(_) => value, // Unary plus does nothing
                                QValue::Float(_) => value,
                                _ => QValue::Float(QFloat::new(value.as_num()?)),
                            }
                        },
                        "~" => {
                            // Bitwise NOT (complement) - only works on integers
                            let int_val = value.as_num()? as i64;
                            QValue::Int(QInt::new(!int_val))
                        },
                        _ => return Err(format!("Unknown unary operator: {}", op)),
                    };
                }

                push_result_to_parent(&mut stack, value, &mut final_result)?;
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
                            return crate::eval_pair_impl(frame.pair.clone(), scope);
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
                let value = match scope.get(name) {
                    Some(v) => v,
                    None => return name_err!("Undefined variable: {}", name),
                };
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
                    let mut should_break_loop = false;
                    let mut should_continue_loop = false;
                    for stmt in if_body {
                        match crate::eval_pair_impl(stmt, scope) {
                            Ok(v) => result = v,
                            Err(e) if e == "__LOOP_BREAK__" => {
                                should_break_loop = true;
                                break;
                            }
                            Err(e) if e == "__LOOP_CONTINUE__" => {
                                should_continue_loop = true;
                                break;
                            }
                            Err(e) => {
                                scope.pop();
                                return Err(e);
                            }
                        }
                    }

                    // Check if we need to propagate loop control to outer loop
                    if should_break_loop || should_continue_loop {
                        // Pop scope first
                        if let Some(updated_self) = scope.get("self") {
                            scope.pop();
                            scope.set("self", updated_self);
                        } else {
                            scope.pop();
                        }

                        // Find loop context and set flag
                        for frame in stack.iter_mut().rev() {
                            if let Some(EvalContext::Loop(ref mut loop_state)) = frame.context {
                                if should_break_loop {
                                    loop_state.should_break = true;
                                } else {
                                    loop_state.should_continue = true;
                                }
                                push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                                continue 'eval_loop;
                            }
                        }
                        // No loop found - this is an error
                        if should_break_loop {
                            return Err("__LOOP_BREAK__".to_string());
                        } else {
                            return Err("__LOOP_CONTINUE__".to_string());
                        }
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
                                let elif_condition = crate::eval_pair_impl(elif_inner.next().unwrap(), scope)?;

                                if elif_condition.as_bool() {
                                    scope.push();
                                    let mut result = QValue::Nil(QNil);
                                    let mut should_break_loop = false;
                                    let mut should_continue_loop = false;
                                    for stmt in elif_inner {
                                        match crate::eval_pair_impl(stmt, scope) {
                                            Ok(v) => result = v,
                                            Err(e) if e == "__LOOP_BREAK__" => {
                                                should_break_loop = true;
                                                break;
                                            }
                                            Err(e) if e == "__LOOP_CONTINUE__" => {
                                                should_continue_loop = true;
                                                break;
                                            }
                                            Err(e) => {
                                                scope.pop();
                                                return Err(e);
                                            }
                                        }
                                    }

                                    // Propagate self mutations
                                    if let Some(updated_self) = scope.get("self") {
                                        scope.pop();
                                        scope.set("self", updated_self);
                                    } else {
                                        scope.pop();
                                    }

                                    // Handle loop control
                                    if should_break_loop || should_continue_loop {
                                        for frame in stack.iter_mut().rev() {
                                            if let Some(EvalContext::Loop(ref mut loop_state)) = frame.context {
                                                if should_break_loop {
                                                    loop_state.should_break = true;
                                                } else {
                                                    loop_state.should_continue = true;
                                                }
                                                push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                                                continue 'eval_loop;
                                            }
                                        }
                                        // No loop found - propagate error
                                        if should_break_loop {
                                            return Err("__LOOP_BREAK__".to_string());
                                        } else {
                                            return Err("__LOOP_CONTINUE__".to_string());
                                        }
                                    }

                                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                                    found_match = true;
                                    break;
                                }
                            }
                            Rule::else_clause => {
                                scope.push();
                                let mut result = QValue::Nil(QNil);
                                let mut should_break_loop = false;
                                let mut should_continue_loop = false;
                                for stmt in clause_pair.into_inner() {
                                    match crate::eval_pair_impl(stmt, scope) {
                                        Ok(v) => result = v,
                                        Err(e) if e == "__LOOP_BREAK__" => {
                                            should_break_loop = true;
                                            break;
                                        }
                                        Err(e) if e == "__LOOP_CONTINUE__" => {
                                            should_continue_loop = true;
                                            break;
                                        }
                                        Err(e) => {
                                            scope.pop();
                                            return Err(e);
                                        }
                                    }
                                }

                                // Propagate self mutations
                                if let Some(updated_self) = scope.get("self") {
                                    scope.pop();
                                    scope.set("self", updated_self);
                                } else {
                                    scope.pop();
                                }

                                // Handle loop control
                                if should_break_loop || should_continue_loop {
                                    for frame in stack.iter_mut().rev() {
                                        if let Some(EvalContext::Loop(ref mut loop_state)) = frame.context {
                                            if should_break_loop {
                                                loop_state.should_break = true;
                                            } else {
                                                loop_state.should_continue = true;
                                            }
                                            push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                                            continue 'eval_loop;
                                        }
                                    }
                                    // No loop found - propagate error
                                    if should_break_loop {
                                        return Err("__LOOP_BREAK__".to_string());
                                    } else {
                                        return Err("__LOOP_CONTINUE__".to_string());
                                    }
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
            // Control Flow - While Loop
            // ================================================================

            (Rule::while_statement, EvalState::Initial) => {
                // while expression ~ statement* ~ end
                let mut iter = frame.pair.clone().into_inner();
                let condition = iter.next().unwrap();

                // Push continuation frame to check condition
                stack.push(EvalFrame {
                    pair: frame.pair.clone(),
                    state: EvalState::WhileCheckCondition,
                    partial_results: Vec::new(),
                    context: None,
                });

                // Evaluate condition
                stack.push(EvalFrame::new(condition));
            }

            (Rule::while_statement, EvalState::WhileCheckCondition) => {
                // Condition evaluated - check if we should continue
                let condition_value = frame.partial_results.pop().unwrap();

                if condition_value.as_bool() {
                    // Condition is true - execute body iteratively
                    scope.push(); // New scope for loop iteration

                    let mut iter = frame.pair.clone().into_inner();
                    iter.next(); // Skip condition

                    // Collect body statements
                    let body_stmts: Vec<_> = iter.collect();

                    if body_stmts.is_empty() {
                        // Empty body - just loop condition again
                        scope.pop();
                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::WhileCheckCondition,
                            partial_results: Vec::new(),
                            context: None,
                        });

                        let mut iter = frame.pair.clone().into_inner();
                        let condition = iter.next().unwrap();
                        stack.push(EvalFrame::new(condition));
                    } else {
                        // Start evaluating body statements iteratively
                        let loop_state = LoopState {
                            loop_var: None,
                            collection: None,
                            current_iteration: 0,
                            body_pairs: body_stmts,
                            current_stmt: 0,
                            should_break: false,
                            should_continue: false,
                        };

                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::WhileEvalBody(0),
                            partial_results: Vec::new(),
                            context: Some(EvalContext::Loop(loop_state)),
                        });
                    }
                } else {
                    // Condition is false - exit loop
                    push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                }
            }

            (Rule::while_statement, EvalState::WhileEvalBody(stmt_index)) => {
                // Evaluating body statements one at a time
                let mut context = frame.context.ok_or("Missing context for WhileEvalBody")?;

                if let EvalContext::Loop(ref mut loop_state) = context {
                    // Check if we have a statement result (not first iteration)
                    if !frame.partial_results.is_empty() {
                        let _stmt_result = frame.partial_results.pop().unwrap();
                        // We can ignore the result for now
                    }

                    // Check for break/continue flags
                    if loop_state.should_break {
                        scope.pop();
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                        continue 'eval_loop;
                    }

                    if loop_state.should_continue {
                        // Continue to next iteration - re-check condition
                        scope.pop();
                        loop_state.should_continue = false; // Reset flag

                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::WhileCheckCondition,
                            partial_results: Vec::new(),
                            context: None,
                        });

                        let mut iter = frame.pair.clone().into_inner();
                        let condition = iter.next().unwrap();
                        stack.push(EvalFrame::new(condition));
                        continue 'eval_loop;
                    }

                    let stmt_idx = *stmt_index;

                    if stmt_idx >= loop_state.body_pairs.len() {
                        // Finished all statements in body - loop again
                        scope.pop();

                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::WhileCheckCondition,
                            partial_results: Vec::new(),
                            context: None,
                        });

                        // Evaluate condition again
                        let mut iter = frame.pair.clone().into_inner();
                        let condition = iter.next().unwrap();
                        stack.push(EvalFrame::new(condition));
                    } else {
                        // Evaluate next statement
                        let next_stmt = loop_state.body_pairs[stmt_idx].clone();

                        // Push continuation frame for next statement
                        loop_state.current_stmt = stmt_idx + 1;
                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::WhileEvalBody(stmt_idx + 1),
                            partial_results: Vec::new(),
                            context: Some(context),
                        });

                        // Evaluate current statement
                        stack.push(EvalFrame::new(next_stmt));
                    }
                } else {
                    return Err("Invalid context for WhileEvalBody".to_string());
                }
            }

            // ================================================================
            // Control Flow - For Loop
            // ================================================================


            (Rule::for_statement, EvalState::Initial) => {
                // for identifier ~ ("," ~ identifier)? ~ "in" ~ for_range ~ statement* ~ "end"
                let mut iter = frame.pair.clone().into_inner();
                let loop_var = iter.next().unwrap().as_str().to_string();

                // Check for optional second variable (dict iteration: for k, v in dict)
                let mut second_var = None;
                let mut next_item = iter.next().unwrap();
                if next_item.as_rule() == Rule::identifier {
                    second_var = Some(next_item.as_str().to_string());
                    next_item = iter.next().unwrap();
                }

                // next_item is now for_range
                let range_pair = next_item;

                // Parse for_range to get expression(s)
                let range_parts: Vec<_> = range_pair.into_inner()
                    .filter(|p| !matches!(p.as_rule(), Rule::to_kw | Rule::until_kw | Rule::step_kw))
                    .collect();

                if range_parts.len() == 1 && second_var.is_none() {
                    // Simple single-variable collection iteration
                    stack.push(EvalFrame {
                        pair: frame.pair.clone(),
                        state: EvalState::ForEvalCollection,
                        partial_results: Vec::new(),
                        context: Some(EvalContext::Loop(LoopState {
                            loop_var: Some(loop_var),
                            collection: None,
                            current_iteration: 0,
                            body_pairs: iter.collect(), // Remaining are body statements
                            current_stmt: 0,
                            should_break: false,
                            should_continue: false,
                        })),
                    });

                    // Evaluate the collection expression
                    stack.push(EvalFrame::new(range_parts[0].clone()));
                } else {
                    // Range iteration (0 to 10, etc.) - fall back to recursive for now
                    let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                    push_result_to_parent(&mut stack, result, &mut final_result)?;
                }
            }

            (Rule::for_statement, EvalState::ForEvalCollection) => {
                // Collection/range evaluated - start iteration
                let collection_value = frame.partial_results.pop().unwrap();
                let mut context = frame.context.unwrap();

                if let EvalContext::Loop(ref mut loop_state) = context {
                    // Convert collection to array of values to iterate
                    let elements = match collection_value {
                        QValue::Array(arr) => arr.elements.borrow().clone(),
                        QValue::Dict(dict) => {
                            // Dict iteration yields [key, value] pairs
                            dict.map.borrow().iter()
                                .map(|(k, v)| QValue::Array(crate::types::QArray::new(vec![
                                    QValue::Str(QString::new(k.clone())),
                                    v.clone()
                                ])))
                                .collect()
                        }
                        QValue::Str(s) => {
                            // String iteration yields individual characters
                            s.value.chars()
                                .map(|c| QValue::Str(QString::new(c.to_string())))
                                .collect()
                        }
                        _ => return Err(format!("Cannot iterate over {}", collection_value.as_obj().cls())),
                    };

                    loop_state.collection = Some(elements);

                    // Start iteration at index 0
                    if loop_state.collection.as_ref().unwrap().is_empty() {
                        // Empty collection - skip loop
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                    } else {
                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::ForIterateBody(0),
                            partial_results: Vec::new(),
                            context: Some(context),
                        });
                    }
                } else {
                    return Err("Invalid context for ForEvalCollection".to_string());
                }
            }

            (Rule::for_statement, EvalState::ForIterateBody(index)) => {
                // Execute body for current element
                let context = frame.context.ok_or("Missing context for ForIterateBody")?;

                if let EvalContext::Loop(loop_state) = context {
                    let index = *index;
                    let collection = loop_state.collection.as_ref().unwrap();

                    if index >= collection.len() {
                        // Finished iterating
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                    } else {
                        // Bind loop variable
                        scope.push();
                        let loop_var = loop_state.loop_var.as_ref().unwrap();
                        scope.declare(loop_var, collection[index].clone())?;

                        // Execute body statements
                        let mut should_break = false;
                        let mut result = QValue::Nil(QNil);
                        for stmt in &loop_state.body_pairs {
                            match crate::eval_pair_impl(stmt.clone(), scope) {
                                Ok(val) => result = val,
                                Err(e) if e == "__LOOP_BREAK__" => {
                                    should_break = true;
                                    break;
                                }
                                Err(e) if e == "__LOOP_CONTINUE__" => {
                                    break; // Exit stmt loop, move to next iteration
                                }
                                Err(e) => {
                                    scope.pop();
                                    return Err(e);
                                }
                            }
                        }

                        scope.pop();

                        if should_break {
                            // Break out of for loop completely
                            push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                        } else {
                            // Move to next iteration
                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::ForIterateBody(index + 1),
                                partial_results: Vec::new(),
                                context: Some(EvalContext::Loop(loop_state)),
                            });
                        }
                    }
                } else {
                    return Err("Invalid context for ForIterateBody".to_string());
                }
            }

            // ================================================================
            // Exception Handling - Try/Catch/Ensure
            // ================================================================

            (Rule::try_statement, EvalState::Initial) => {
                // try statement* catch_clause+ ensure_clause? end
                // Parse the try/catch/ensure structure
                let inner = frame.pair.clone().into_inner();

                let mut try_body = Vec::new();
                let mut catch_clauses = Vec::new();
                let mut ensure_block = None;

                for part in inner {
                    match part.as_rule() {
                        Rule::catch_clause => {
                            let mut catch_inner = part.into_inner();
                            let var_name = catch_inner.next().unwrap().as_str().to_string();

                            // Check for optional type filter
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

                // Create TryState and push continuation frame
                let try_state = TryState {
                    try_body: try_body.clone(),
                    catch_clauses,
                    ensure_block,
                    exception: None,
                    result: None,
                    caught: false,
                };

                stack.push(EvalFrame {
                    pair: frame.pair.clone(),
                    state: EvalState::TryEvalBody,
                    partial_results: Vec::new(),
                    context: Some(EvalContext::Try(try_state)),
                });

                // Execute try body statements (using recursive eval for now)
                // TODO: Could make this fully iterative in the future
                scope.push(); // New scope for try block
                let mut result = QValue::Nil(QNil);
                let mut exception_occurred = false;
                let mut exception_msg = String::new();

                for stmt in try_body {
                    match crate::eval_pair_impl(stmt, scope) {
                        Ok(val) => result = val,
                        Err(e) => {
                            exception_occurred = true;
                            exception_msg = e;
                            break;
                        }
                    }
                }

                scope.pop();

                if exception_occurred {
                    // Store the exception for the catch handler
                    // Push exception info to partial_results as a marker
                    stack.last_mut().unwrap().partial_results.push(QValue::Str(QString::new(exception_msg)));
                    stack.last_mut().unwrap().partial_results.push(QValue::Bool(QBool::new(true))); // Exception flag
                } else {
                    // No exception - store result
                    stack.last_mut().unwrap().partial_results.push(result);
                    stack.last_mut().unwrap().partial_results.push(QValue::Bool(QBool::new(false))); // No exception flag
                }
            }

            (Rule::try_statement, EvalState::TryEvalBody) => {
                // Try body completed - check if exception occurred
                let exception_flag = frame.partial_results.pop().unwrap();
                let result_or_error = frame.partial_results.pop().unwrap();

                let mut context = frame.context.unwrap();
                if let EvalContext::Try(ref mut try_state) = context {
                    if exception_flag.as_bool() {
                        // Exception occurred - parse it and try catch clauses
                        let error_msg = result_or_error.as_str();

                        // Parse exception type from error message
                        let (exc_type, exc_msg) = if let Some(colon_pos) = error_msg.find(": ") {
                            let type_str = &error_msg[..colon_pos];
                            let msg = &error_msg[colon_pos + 2..];
                            (ExceptionType::from_str(type_str), msg.to_string())
                        } else {
                            (ExceptionType::RuntimeErr, error_msg.clone())
                        };

                        // Create exception object
                        let mut exception = QException::new(exc_type.clone(), exc_msg, None, None);
                        exception.stack = scope.get_stack_trace();
                        scope.current_exception = Some(exception.clone());
                        scope.call_stack.clear();

                        try_state.exception = Some(exception.clone());

                        // Try to find matching catch clause
                        let mut matched_clause_idx = None;
                        for (idx, (_, exception_type_filter, _)) in try_state.catch_clauses.iter().enumerate() {
                            let matches = if let Some(ref expected_type_str) = exception_type_filter {
                                let expected_type = ExceptionType::from_str(expected_type_str);
                                exception.exception_type.is_subtype_of(&expected_type)
                            } else {
                                true // Catch-all
                            };

                            if matches {
                                matched_clause_idx = Some(idx);
                                break;
                            }
                        }

                        if let Some(clause_idx) = matched_clause_idx {
                            // Execute matching catch clause
                            try_state.caught = true;
                            let (var_name, _, body) = try_state.catch_clauses[clause_idx].clone();

                            // Bind exception to variable
                            scope.declare(&var_name, QValue::Exception(exception.clone())).ok();

                            // Execute catch body (using recursive eval)
                            let mut catch_result = QValue::Nil(QNil);
                            let mut catch_error = None;
                            for stmt in body {
                                match crate::eval_pair_impl(stmt, scope) {
                                    Ok(val) => catch_result = val,
                                    Err(e) => {
                                        catch_error = Some(e);
                                        break;
                                    }
                                }
                            }

                            // Remove exception variable
                            scope.delete(&var_name).ok();

                            if let Some(err) = catch_error {
                                // Exception in catch block
                                try_state.result = None;
                                // Store error to re-throw after ensure
                                stack.push(EvalFrame {
                                    pair: frame.pair.clone(),
                                    state: EvalState::TryEvalEnsure,
                                    partial_results: vec![QValue::Str(QString::new(err)), QValue::Bool(QBool::new(true))],
                                    context: Some(context),
                                });
                            } else {
                                try_state.result = Some(catch_result.clone());
                                // Move to ensure
                                stack.push(EvalFrame {
                                    pair: frame.pair.clone(),
                                    state: EvalState::TryEvalEnsure,
                                    partial_results: vec![catch_result, QValue::Bool(QBool::new(false))],
                                    context: Some(context),
                                });
                            }
                        } else {
                            // No matching catch - will re-throw after ensure
                            try_state.result = None;
                            stack.push(EvalFrame {
                                pair: frame.pair.clone(),
                                state: EvalState::TryEvalEnsure,
                                partial_results: vec![QValue::Str(QString::new(error_msg)), QValue::Bool(QBool::new(true))],
                                context: Some(context),
                            });
                        }
                    } else {
                        // No exception - just move to ensure
                        try_state.result = Some(result_or_error.clone());
                        stack.push(EvalFrame {
                            pair: frame.pair.clone(),
                            state: EvalState::TryEvalEnsure,
                            partial_results: vec![result_or_error, QValue::Bool(QBool::new(false))],
                            context: Some(context),
                        });
                    }
                } else {
                    return Err("Invalid context for TryEvalBody".to_string());
                }
            }

            (Rule::try_statement, EvalState::TryEvalEnsure) => {
                // Execute ensure block (if present), then return result or re-throw exception
                let exception_flag = frame.partial_results.pop().unwrap();
                let result_or_error = frame.partial_results.pop().unwrap();

                let context = frame.context.unwrap();
                if let EvalContext::Try(try_state) = context {
                    // Execute ensure block if present
                    if let Some(ensure_stmts) = try_state.ensure_block {
                        for stmt in ensure_stmts {
                            crate::eval_pair_impl(stmt, scope)?;
                        }
                    }

                    // Clear current exception
                    scope.current_exception = None;

                    // Return result or propagate exception
                    if exception_flag.as_bool() {
                        // Re-throw exception
                        return Err(result_or_error.as_str());
                    } else {
                        // Return result
                        push_result_to_parent(&mut stack, result_or_error, &mut final_result)?;
                    }
                } else {
                    return Err("Invalid context for TryEvalEnsure".to_string());
                }
            }

            // ================================================================
            // Break / Continue Statements
            // ================================================================

            (Rule::break_statement, EvalState::Initial) => {
                // Break out of current loop - find the enclosing loop context and set flag
                // We need to walk up the stack to find the loop context
                for frame in stack.iter_mut().rev() {
                    if let Some(EvalContext::Loop(ref mut loop_state)) = frame.context {
                        loop_state.should_break = true;
                        // Return nil as result for this break statement
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                        continue 'eval_loop;
                    }
                }
                // If no loop found, fall back to recursive (which will error)
                let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                push_result_to_parent(&mut stack, result, &mut final_result)?;
            }

            (Rule::continue_statement, EvalState::Initial) => {
                // Continue to next iteration - find the enclosing loop context and set flag
                for frame in stack.iter_mut().rev() {
                    if let Some(EvalContext::Loop(ref mut loop_state)) = frame.context {
                        loop_state.should_continue = true;
                        // Return nil as result for this continue statement
                        push_result_to_parent(&mut stack, QValue::Nil(QNil), &mut final_result)?;
                        continue 'eval_loop;
                    }
                }
                // If no loop found, fall back to recursive (which will error)
                let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                push_result_to_parent(&mut stack, result, &mut final_result)?;
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
                        let right_result = crate::eval_pair_impl(right_pair, scope)?;

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
            // Primary Expressions
            // ================================================================

            (Rule::identifier, EvalState::Initial) => {
                let name = frame.pair.as_str();
                let value = match scope.get(name) {
                    Some(v) => v,
                    None => return name_err!("Undefined variable: {}", name),
                };
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::primary, EvalState::Initial) => {
                let pair_str = frame.pair.as_str();

                // Check for "self" keyword
                if pair_str == "self" {
                    let value = scope.get("self")
                        .ok_or_else(|| "'self' is only valid inside methods".to_string())?;
                    push_result_to_parent(&mut stack, value, &mut final_result)?;
                } else {
                    // Detect function calls: identifier(...), Type.new(...), Type.dim(...)
                    // Only if first child is identifier - avoids catching (expressions) or other cases
                    let mut inner = frame.pair.clone().into_inner();
                    let first_child = inner.next();

                    let is_function_call = if let Some(child) = &first_child {
                        matches!(child.as_rule(), Rule::identifier) && pair_str.contains('(')
                    } else {
                        false
                    };

                    if is_function_call {
                        // Function/constructor call - fall back to recursive evaluator
                        let result = crate::eval_pair_impl(frame.pair.clone(), scope)?;
                        push_result_to_parent(&mut stack, result, &mut final_result)?;
                    } else {
                        // Not a function call - pass through to child
                        if let Some(child) = first_child {
                            stack.push(EvalFrame::new(child));
                        } else {
                            return Err("Empty primary expression".to_string());
                        }
                    }
                }
            }

            (Rule::array_literal, EvalState::Initial) => {
                // [expression, expression, ...]
                let inner = frame.pair.clone().into_inner();

                // Check if we have array_elements
                let elements_pair = inner.clone().next();
                if elements_pair.is_none() {
                    // Empty array [] - Pre-allocate with capacity 16 (QEP-042 #6)
                    let value = QValue::Array(crate::types::QArray::new_with_capacity(16));
                    push_result_to_parent(&mut stack, value, &mut final_result)?;
                } else {
                    let elements_pair = elements_pair.unwrap();
                    if elements_pair.as_rule() != Rule::array_elements {
                        // Empty array - Pre-allocate with capacity 16 (QEP-042 #6)
                        let value = QValue::Array(crate::types::QArray::new_with_capacity(16));
                        push_result_to_parent(&mut stack, value, &mut final_result)?;
                    } else {
                        // Parse array elements (use recursive eval for now)
                        let mut elements = Vec::new();
                        for element in elements_pair.into_inner() {
                            if element.as_rule() == Rule::array_row {
                                return Err("2D arrays not yet implemented".to_string());
                            } else {
                                elements.push(crate::eval_pair_impl(element, scope)?);
                            }
                        }
                        let value = QValue::Array(crate::types::QArray::new(elements));
                        push_result_to_parent(&mut stack, value, &mut final_result)?;
                    }
                }
            }

            (Rule::dict_literal, EvalState::Initial) => {
                // {key: value, key: value, ...}
                let inner = frame.pair.clone().into_inner();
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
                                match crate::eval_pair_impl(key_part, scope)? {
                                    QValue::Str(s) => s.value.as_ref().clone(),
                                    _ => return Err("Dict key must be a string".to_string())
                                }
                            }
                            _ => return Err(format!("Invalid dict key type: {:?}", key_part.as_rule()))
                        };

                        let value = crate::eval_pair_impl(value_part, scope)?;
                        map.insert(key, value);
                    }
                }

                let value = QValue::Dict(Box::new(crate::types::QDict::new(map)));
                push_result_to_parent(&mut stack, value, &mut final_result)?;
            }

            (Rule::literal, EvalState::Initial) => {
                // Literal is just a wrapper - pass through to child
                let mut inner = frame.pair.clone().into_inner();
                if let Some(child) = inner.next() {
                    stack.push(EvalFrame::new(child));
                } else {
                    return Err("Empty literal".to_string());
                }
            }

            // ================================================================
            // TODO: Implement remaining Rule cases
            // Phase 5 in progress - operators done, need array/dict literals, postfix
            // ================================================================

            _ => {
                // Unimplemented in iterative evaluator - fall back to recursive
                // This allows gradual migration of rules to iterative evaluation
                match crate::eval_pair_impl(frame.pair.clone(), scope) {
                    Ok(result) => {
                        push_result_to_parent(&mut stack, result, &mut final_result)?;
                    }
                    Err(e) if e == "__LOOP_BREAK__" => {
                        // Break from recursive evaluation - find loop context and set flag
                        let mut loop_frame_idx = None;
                        for (idx, frame) in stack.iter().enumerate().rev() {
                            if frame.context.is_some() {
                                if let Some(EvalContext::Loop(_)) = frame.context {
                                    loop_frame_idx = Some(idx);
                                    break;
                                }
                            }
                        }

                        if let Some(idx) = loop_frame_idx {
                            // Set the break flag
                            if let Some(EvalContext::Loop(ref mut loop_state)) = stack[idx].context {
                                loop_state.should_break = true;
                            }
                            // Pop all frames above the loop frame
                            let frames_to_pop = stack.len() - idx - 1;
                            for _ in 0..frames_to_pop {
                                stack.pop();
                            }
                        } else {
                            // No loop context found - propagate error
                            return Err(e);
                        }
                    }
                    Err(e) if e == "__LOOP_CONTINUE__" => {
                        // Continue from recursive evaluation - find loop context and set flag
                        let mut loop_frame_idx = None;
                        for (idx, frame) in stack.iter().enumerate().rev() {
                            if frame.context.is_some() {
                                if let Some(EvalContext::Loop(_)) = frame.context {
                                    loop_frame_idx = Some(idx);
                                    break;
                                }
                            }
                        }

                        if let Some(idx) = loop_frame_idx {
                            // Set the continue flag
                            if let Some(EvalContext::Loop(ref mut loop_state)) = stack[idx].context {
                                loop_state.should_continue = true;
                            }
                            // Pop all frames above the loop frame
                            let frames_to_pop = stack.len() - idx - 1;
                            for _ in 0..frames_to_pop {
                                stack.pop();
                            }
                        } else {
                            // No loop context found - propagate error
                            return Err(e);
                        }
                    }
                    Err(e) => return Err(e),
                }
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
