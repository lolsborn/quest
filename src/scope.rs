use std::collections::{HashMap, HashSet};
use std::rc::Rc;
use std::cell::RefCell;
use crate::types::{QValue, QException};

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
    // Return value for function returns
    pub return_value: Option<QValue>,
    // Public items (for module exports) - only items in this set are exported
    // Only applies to the top-level scope of a module
    pub public_items: HashSet<String>,
}

impl Scope {
    pub fn new() -> Self {
        let mut scope = Scope {
            scopes: vec![Rc::new(RefCell::new(HashMap::new()))],
            module_cache: Rc::new(RefCell::new(HashMap::new())),
            current_exception: None,
            call_stack: Vec::new(),
            current_script_path: Rc::new(RefCell::new(None)),
            return_value: None,
            public_items: HashSet::new(),
        };

        // Pre-populate with built-in type names (for use with .is() method)
        // These use TitleCase to match the actual type names
        use crate::types::QString;
        let _ = scope.declare("Int", QValue::Str(QString::new("Int".to_string())));
        let _ = scope.declare("Float", QValue::Str(QString::new("Float".to_string())));
        let _ = scope.declare("Decimal", QValue::Str(QString::new("Decimal".to_string())));
        let _ = scope.declare("Str", QValue::Str(QString::new("Str".to_string())));
        let _ = scope.declare("Bool", QValue::Str(QString::new("Bool".to_string())));
        let _ = scope.declare("Array", QValue::Str(QString::new("Array".to_string())));
        let _ = scope.declare("Dict", QValue::Str(QString::new("Dict".to_string())));
        let _ = scope.declare("Nil", QValue::Str(QString::new("Nil".to_string())));
        let _ = scope.declare("Bytes", QValue::Str(QString::new("Bytes".to_string())));
        let _ = scope.declare("Uuid", QValue::Str(QString::new("Uuid".to_string())));
        let _ = scope.declare("Num", QValue::Str(QString::new("Num".to_string())));
        let _ = scope.declare("Obj", QValue::Str(QString::new("Obj".to_string())));

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
            return_value: None,
            public_items: HashSet::new(),
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
    }

    pub fn pop(&mut self) {
        if self.scopes.len() > 1 {
            self.scopes.pop();
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
            return Err(format!("Variable '{}' already declared in this scope", name));
        }
        self.scopes.last().unwrap().borrow_mut().insert(name.to_string(), value);
        Ok(())
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
        Err(format!("Cannot assign to undeclared variable '{}'. Use 'let {} = ...' to declare it first.", name, name))
    }

    // Delete from current scope only
    pub fn delete(&mut self, name: &str) -> Result<(), String> {
        let current_scope = self.scopes.last().unwrap();
        if !current_scope.borrow().contains_key(name) {
            // Check if it exists in outer scope
            for scope in self.scopes.iter().rev().skip(1) {
                if scope.borrow().contains_key(name) {
                    return Err(format!("Cannot delete variable '{}' from outer scope", name));
                }
            }
            return Err(format!("Cannot delete undefined variable '{}'", name));
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
}
