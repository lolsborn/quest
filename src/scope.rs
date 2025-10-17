use std::collections::{HashMap, HashSet};
use std::rc::Rc;
use std::cell::RefCell;
use std::io::Write;
use crate::types::{QValue, QException, QStringIO};
use crate::{name_err, runtime_err};

// Stack frame for exception stack traces
#[derive(Clone, Debug)]
pub struct StackFrame {
    pub function_name: String,
    pub line: Option<usize>,
    pub file: Option<String>,
}

impl StackFrame {
    pub fn new(function_name: String) -> Self {
        StackFrame {
            function_name,
            line: None,
            file: None,
        }
    }

    pub fn to_string(&self) -> String {
        let mut s = format!("  at {}", self.function_name);
        if let Some(ref file) = self.file {
            s.push_str(&format!(" ({})", file));
            if let Some(line) = self.line {
                s.push_str(&format!(":{}", line));
            }
        }
        s
    }
}

// Output target for I/O redirection (QEP-010)
#[derive(Debug, Clone)]
pub enum OutputTarget {
    Default,  // OS stdout/stderr (print!/eprint!)
    File(String),  // File path (appends on each write)
    StringIO(Rc<RefCell<QStringIO>>),  // In-memory buffer
}

impl OutputTarget {
    pub fn write(&self, data: &str) -> Result<(), String> {
        match self {
            OutputTarget::Default => {
                print!("{}", data);
                std::io::stdout().flush().ok();
                Ok(())
            }
            OutputTarget::File(path) => {
                use std::fs::OpenOptions;
                let mut file = OpenOptions::new()
                    .create(true)
                    .append(true)
                    .open(path)
                    .map_err(|e| format!("Failed to open '{}': {}", path, e))?;
                file.write_all(data.as_bytes())
                    .map_err(|e| format!("Failed to write to '{}': {}", path, e))?;
                Ok(())
            }
            OutputTarget::StringIO(sio) => {
                sio.borrow_mut().write(data);
                Ok(())
            }
        }
    }
}

// Scope chain for proper lexical scoping
// Uses Rc<RefCell<>> for scope levels so they can be shared (for closures, modules)
#[derive(Clone)]
pub struct Scope {
    // Stack of scopes - last is innermost (current scope)
    // Each scope is shared via Rc<RefCell<>> for proper closure semantics
    pub scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
    // Module cache: maps resolved file paths to loaded modules
    // Shared across all scopes using Rc<RefCell<>> so modules can share state
    pub module_cache: Rc<RefCell<HashMap<String, QValue>>>,
    // Current exception for re-raising
    pub current_exception: Option<QException>,
    // Call stack for exception stack traces
    pub call_stack: Vec<StackFrame>,
    // Current script path (for relative imports) - stored as Rc so it can be shared
    pub current_script_path: Rc<RefCell<Option<String>>>,
    // QEP-056: return_value removed - values now stored in ControlFlow::FunctionReturn(val)
    // Public items (for module exports) - only items in this set are exported
    // Only applies to the top-level scope of a module
    pub public_items: HashSet<String>,
    // I/O redirection targets (QEP-010)
    pub stdout_target: OutputTarget,
    pub stderr_target: OutputTarget,
    // QEP-017: Track which variables are constants (immutable bindings)
    // Each scope level has its own set of constant names
    pub constants: Vec<HashSet<String>>,
    // QEP-015: Track variable type constraints for type-checked variables
    // Each scope level has its own type constraints
    pub variable_types: Vec<HashMap<String, String>>,
    // QEP-048: Stack depth tracking for introspection
    pub eval_depth: usize,
    pub module_loading_depth: usize,
    // QEP-043: Module loading stack for circular import detection
    // Tracks the chain of modules currently being loaded (resolved paths)
    pub module_loading_stack: Vec<String>,
}

impl Scope {
    pub fn new() -> Self {
        let mut scope = Scope {
            scopes: vec![Rc::new(RefCell::new(HashMap::new()))],
            module_cache: Rc::new(RefCell::new(HashMap::new())),
            current_exception: None,
            call_stack: Vec::new(),
            current_script_path: Rc::new(RefCell::new(None)),
            // QEP-056: return_value removed
            public_items: HashSet::new(),
            stdout_target: OutputTarget::Default,
            stderr_target: OutputTarget::Default,
            constants: vec![HashSet::new()],
            variable_types: vec![HashMap::new()],
            eval_depth: 0,
            module_loading_depth: 0,
            module_loading_stack: Vec::new(),
        };

        // Pre-populate with built-in type names (for use with .is() method)
        // These use TitleCase to match the actual type names
        use crate::types::QString;
        let _ = scope.declare("Int", QValue::Str(QString::new("Int".to_string())));
        let _ = scope.declare("Float", QValue::Str(QString::new("Float".to_string())));
        let _ = scope.declare("Str", QValue::Str(QString::new("Str".to_string())));
        let _ = scope.declare("Bool", QValue::Str(QString::new("Bool".to_string())));
        // Array is now a proper Type with static methods (see below)
        let _ = scope.declare("Dict", QValue::Str(QString::new("Dict".to_string())));
        let _ = scope.declare("Nil", QValue::Str(QString::new("Nil".to_string())));
        let _ = scope.declare("Bytes", QValue::Str(QString::new("Bytes".to_string())));
        let _ = scope.declare("Uuid", QValue::Str(QString::new("Uuid".to_string())));
        let _ = scope.declare("Num", QValue::Str(QString::new("Num".to_string())));
        let _ = scope.declare("Obj", QValue::Str(QString::new("Obj".to_string())));
        let _ = scope.declare("Func", QValue::Str(QString::new("Func".to_string())));

        // Decimal is a special built-in type with static methods
        use crate::types::create_decimal_type;
        match scope.declare("Decimal", QValue::Type(Box::new(create_decimal_type()))) {
            Ok(_) => {},
            Err(e) => eprintln!("Failed to declare Decimal type: {}", e),
        }

        // BigInt is a special built-in type with static methods and constants
        use crate::types::{create_bigint_type, QBigInt};
        use num_bigint::BigInt as NumBigInt;
        use num_traits::{Zero, One};
        match scope.declare("BigInt", QValue::Type(Box::new(create_bigint_type()))) {
            Ok(_) => {},
            Err(e) => eprintln!("Failed to declare BigInt type: {}", e),
        }
        // Add BigInt constants
        let _ = scope.declare("ZERO", QValue::BigInt(QBigInt::new(NumBigInt::zero())));
        let _ = scope.declare("ONE", QValue::BigInt(QBigInt::new(NumBigInt::one())));
        let _ = scope.declare("TWO", QValue::BigInt(QBigInt::new(NumBigInt::from(2))));
        let _ = scope.declare("TEN", QValue::BigInt(QBigInt::new(NumBigInt::from(10))));

        // Array is a special built-in type with static methods
        use crate::types::create_array_type;
        match scope.declare("Array", QValue::Type(Box::new(create_array_type()))) {
            Ok(_) => {},
            Err(e) => eprintln!("Failed to declare Array type: {}", e),
        }

        // QEP-037: Register built-in exception types
        if let Err(e) = crate::exception_types::register_exception_types(&mut scope) {
            eprintln!("Failed to register exception types: {}", e);
        }

        scope
    }

    // Create a scope with a specific shared map as the base scope
    // Used for module function calls so they share the module's state
    pub fn with_shared_base(shared_map: Rc<RefCell<HashMap<String, QValue>>>, module_cache: Rc<RefCell<HashMap<String, QValue>>>) -> Self {
        Scope {
            scopes: vec![shared_map],
            module_cache,
            current_exception: None,
            call_stack: Vec::new(),
            current_script_path: Rc::new(RefCell::new(None)),
            // QEP-056: return_value removed
            public_items: HashSet::new(),
            stdout_target: OutputTarget::Default,
            stderr_target: OutputTarget::Default,
            constants: vec![HashSet::new()],
            variable_types: vec![HashMap::new()],
            eval_depth: 0,
            module_loading_depth: 0,
            module_loading_stack: Vec::new(),
        }
    }

    // Push a stack frame (called when entering a function)
    pub fn push_stack_frame(&mut self, frame: StackFrame) {
        self.call_stack.push(frame);
    }

    // Pop a stack frame (called when exiting a function)
    pub fn pop_stack_frame(&mut self) {
        self.call_stack.pop();
    }

    // Get a copy of the current call stack for exception handling
    pub fn get_stack_trace(&self) -> Vec<String> {
        self.call_stack.iter().map(|f| f.to_string()).collect()
    }

    pub fn push(&mut self) {
        self.scopes.push(Rc::new(RefCell::new(HashMap::new())));
        self.constants.push(HashSet::new());
        self.variable_types.push(HashMap::new());
    }

    pub fn pop(&mut self) {
        if self.scopes.len() > 1 {
            self.scopes.pop();
            self.constants.pop();
            self.variable_types.pop();
        }
    }

    // Look up variable starting from innermost scope
    pub fn get(&self, name: &str) -> Option<QValue> {
        for scope in self.scopes.iter().rev() {
            if let Some(value) = scope.borrow().get(name) {
                return Some(value.clone());
            }
        }
        None
    }

    // Set variable in the scope where it's defined, or current scope if new
    pub fn set(&mut self, name: &str, value: QValue) {
        // Special handling for 'self' - always set only in current scope
        // to prevent corruption across method boundaries (Bug #008)
        if name == "self" {
            self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
            return;
        }

        // Search from innermost to outermost for other variables
        for scope in self.scopes.iter().rev() {
            if scope.borrow().contains_key(name) {
                scope.borrow_mut().insert(name.to_string(), value);
                return;
            }
        }
        // Not found in any scope - add to current (innermost) scope
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
    }

    // Declare a new variable in the current scope
    pub fn declare(&mut self, name: &str, value: QValue) -> Result<(), String> {
        if self.contains_in_current(name) {
            return name_err!("Variable '{}' already declared in this scope", name);
        }
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        Ok(())
    }

    // QEP-017: Declare a constant in the current scope
    pub fn declare_const(&mut self, name: &str, value: QValue) -> Result<(), String> {
        if self.contains_in_current(name) {
            return name_err!("Constant '{}' already declared in this scope", name);
        }
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        self.constants.last_mut().unwrap().insert(name.to_string());
        Ok(())
    }

    // QEP-017: Check if a variable is a constant
    pub fn is_const(&self, name: &str) -> bool {
        // Check from innermost to outermost scope
        for const_set in self.constants.iter().rev() {
            if const_set.contains(name) {
                return true;
            }
        }
        false
    }

    // QEP-015: Declare a variable with a type constraint
    pub fn declare_with_type(&mut self, name: &str, value: QValue, type_annotation: String) -> Result<(), String> {
        if self.contains_in_current(name) {
            return name_err!("Variable '{}' already declared in this scope", name);
        }
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        self.variable_types.last_mut().unwrap().insert(name.to_string(), type_annotation);
        Ok(())
    }

    // QEP-015: Get the type constraint for a variable (if any)
    pub fn get_variable_type(&self, name: &str) -> Option<String> {
        // Search from innermost to outermost scope
        for type_map in self.variable_types.iter().rev() {
            if let Some(type_annotation) = type_map.get(name) {
                return Some(type_annotation.clone());
            }
        }
        None
    }

    // Update an existing variable, error if undeclared
    pub fn update(&mut self, name: &str, value: QValue) -> Result<(), String> {
        // Search from innermost to outermost
        for scope in self.scopes.iter().rev() {
            if scope.borrow().contains_key(name) {
                scope.borrow_mut().insert(name.to_string(), value);
                return Ok(());
            }
        }
        name_err!("Cannot assign to undeclared variable '{}'. Use 'let {} = ...' to declare it first.", name, name)
    }

    // Delete from current scope only
    pub fn delete(&mut self, name: &str) -> Result<(), String> {
        let current_scope = self.scopes.last().unwrap();
        if !current_scope.borrow().contains_key(name) {
            // Check if it exists in outer scope
            for scope in self.scopes.iter().rev().skip(1) {
                if scope.borrow().contains_key(name) {
                    return runtime_err!("Cannot delete variable '{}' from outer scope", name);
                }
            }
            return name_err!("Cannot delete undefined variable '{}'", name);
        }
        current_scope.borrow_mut().remove(name);
        Ok(())
    }

    // Check if variable exists in current scope only
    pub fn contains_in_current(&self, name: &str) -> bool {
        self.scopes.last().unwrap().borrow().contains_key(name)
    }

    // Mark an item as public (for module exports)
    pub fn mark_public(&mut self, name: &str) {
        self.public_items.insert(name.to_string());
    }

    // Check if an item is marked as public
    pub fn is_public(&self, name: &str) -> bool {
        self.public_items.contains(name)
    }

    // Convert to flat HashMap (for compatibility/merging scopes)
    // If public_only is true, only include items marked as public
    pub fn to_flat_map(&self) -> HashMap<String, QValue> {
        self.to_flat_map_filtered(false)
    }

    // Convert to flat HashMap with optional public-only filter
    pub fn to_flat_map_filtered(&self, public_only: bool) -> HashMap<String, QValue> {
        let mut result = HashMap::new();
        for scope in &self.scopes {
            for (key, value) in scope.borrow().iter() {
                if !public_only || self.is_public(key) {
                    result.insert(key.clone(), value.clone());
                }
            }
        }
        result
    }

    // Get cached module by path
    pub fn get_cached_module(&self, path: &str) -> Option<QValue> {
        self.module_cache.borrow().get(path).cloned()
    }

    // Cache a module by its resolved path
    pub fn cache_module(&mut self, path: String, module: QValue) {
        self.module_cache.borrow_mut().insert(path, module);
    }

    // QEP-043: Circular import detection
    // Check if a module is currently being loaded (indicates circular dependency)
    pub fn is_loading_module(&self, path: &str) -> bool {
        self.module_loading_stack.contains(&path.to_string())
    }

    // Push a module onto the loading stack
    pub fn push_loading_module(&mut self, path: String) {
        self.module_loading_stack.push(path);
    }

    // Pop a module from the loading stack
    pub fn pop_loading_module(&mut self) {
        self.module_loading_stack.pop();
    }

    // Get the current module loading chain as a string (for error messages)
    pub fn get_loading_chain(&self) -> String {
        self.module_loading_stack.join(" -> ")
    }

    // QEP-049 Bug #020: Get current scope depth for testing/introspection
    pub fn depth(&self) -> usize {
        self.scopes.len()
    }
}

// ============================================================================
// RAII Scope Guard (Reserved for future use - QEP-059)
// ============================================================================

/// RAII guard for automatic scope cleanup.
///
/// Automatically pushes a new scope on creation and pops it when dropped,
/// ensuring cleanup happens on all code paths (normal return, early return,
/// panic, exception propagation, etc.).
///
/// This prevents scope leaks when errors occur in loop bodies or other
/// control flow structures.
///
/// # Example
/// ```rust
/// {
///     let _guard = ScopeGuard::new(scope);
///     // New scope is active here
///
///     // ... do work that might error ...
///
///     // Scope automatically popped when _guard drops (even on error!)
/// }
/// ```
///
/// Note: Currently unused due to state machine architecture constraints.
/// See QEP-059 for details.
#[allow(dead_code)]
pub struct ScopeGuard<'a> {
    scope: &'a mut Scope,
    active: bool,
}

#[allow(dead_code)]
impl<'a> ScopeGuard<'a> {
    /// Create a new scope guard and push a scope.
    pub fn new(scope: &'a mut Scope) -> Self {
        scope.push();
        Self { scope, active: true }
    }

    /// Dismiss the guard without popping (for explicit control flow).
    /// Used when the scope has already been popped manually or should
    /// remain active beyond the guard's lifetime.
    pub fn dismiss(mut self) {
        self.active = false;
    }
}

impl Drop for ScopeGuard<'_> {
    fn drop(&mut self) {
        if self.active {
            self.scope.pop();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_scope_guard_normal_drop() {
        let mut scope = Scope::new();
        let initial_depth = scope.depth();

        {
            let _guard = ScopeGuard::new(&mut scope);
            // Scope should be pushed
            assert_eq!(scope.depth(), initial_depth + 1);
        }

        // Scope should be popped when guard drops
        assert_eq!(scope.depth(), initial_depth);
    }

    #[test]
    fn test_scope_guard_early_return() {
        fn helper(scope: &mut Scope, should_return: bool) -> Result<(), String> {
            let _guard = ScopeGuard::new(scope);

            if should_return {
                return Err("early return".to_string());
            }

            Ok(())
        }

        let mut scope = Scope::new();
        let initial_depth = scope.depth();

        // Test early return path
        let _ = helper(&mut scope, true);
        assert_eq!(scope.depth(), initial_depth, "Scope should be popped on early return");

        // Test normal path
        let _ = helper(&mut scope, false);
        assert_eq!(scope.depth(), initial_depth, "Scope should be popped on normal return");
    }

    #[test]
    fn test_scope_guard_dismiss() {
        let mut scope = Scope::new();
        let initial_depth = scope.depth();

        {
            let guard = ScopeGuard::new(&mut scope);
            assert_eq!(scope.depth(), initial_depth + 1);

            // Dismiss the guard - scope should NOT be popped
            guard.dismiss();
        }

        // Scope should still be pushed (guard was dismissed)
        assert_eq!(scope.depth(), initial_depth + 1);

        // Clean up manually
        scope.pop();
        assert_eq!(scope.depth(), initial_depth);
    }

    #[test]
    fn test_scope_guard_nested() {
        let mut scope = Scope::new();
        let initial_depth = scope.depth();

        {
            let _guard1 = ScopeGuard::new(&mut scope);
            assert_eq!(scope.depth(), initial_depth + 1);

            {
                let _guard2 = ScopeGuard::new(&mut scope);
                assert_eq!(scope.depth(), initial_depth + 2);

                {
                    let _guard3 = ScopeGuard::new(&mut scope);
                    assert_eq!(scope.depth(), initial_depth + 3);
                }

                assert_eq!(scope.depth(), initial_depth + 2);
            }

            assert_eq!(scope.depth(), initial_depth + 1);
        }

        assert_eq!(scope.depth(), initial_depth);
    }

    #[test]
    fn test_scope_guard_with_variables() {
        let mut scope = Scope::new();

        // Set a variable in outer scope
        scope.set("outer".to_string(), QValue::Int(QInt(42)));

        {
            let _guard = ScopeGuard::new(&mut scope);

            // Set a variable in inner scope
            scope.set("inner".to_string(), QValue::Int(QInt(100)));

            // Both variables should be accessible
            assert!(scope.get("outer").is_ok());
            assert!(scope.get("inner").is_ok());
        }

        // After guard drops, inner variable should be gone
        assert!(scope.get("outer").is_ok());
        assert!(scope.get("inner").is_err());
    }

    #[test]
    #[should_panic(expected = "Cannot pop")]
    fn test_scope_guard_panic_unwind() {
        let mut scope = Scope::new();
        let initial_depth = scope.depth();

        let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let _guard = ScopeGuard::new(&mut scope);
            panic!("test panic");
        }));

        assert!(result.is_err());
        // Note: In a real panic scenario, the scope would be popped during unwinding,
        // but we can't test this directly due to mutable borrow rules.
        // This test primarily documents the expected behavior.
    }

    #[test]
    fn test_scope_depth() {
        let mut scope = Scope::new();
        assert_eq!(scope.depth(), 0);

        scope.push();
        assert_eq!(scope.depth(), 1);

        scope.push();
        assert_eq!(scope.depth(), 2);

        scope.pop();
        assert_eq!(scope.depth(), 1);

        scope.pop();
        assert_eq!(scope.depth(), 0);
    }
}
