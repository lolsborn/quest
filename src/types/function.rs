use super::*;
use crate::attr_err;

// ============================================================================
// QFun - Reference to built-in methods (e.g., "3.plus")
// ============================================================================

#[derive(Debug, Clone)]
pub struct QFun {
    pub name: String,
    pub parent_type: String,
    pub id: u64,
}

impl QFun {
    pub fn new(name: String, parent_type: String) -> Self {
        QFun {
            name,
            parent_type,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }
        attr_err!("Fun has no method '{}'", method_name)
    }
}

impl QObj for QFun {
    fn cls(&self) -> String { "Fun".to_string() }
    fn q_type(&self) -> &'static str { "fun" }
    fn is(&self, type_name: &str) -> bool { type_name == "fun" || type_name == "obj" }
    fn str(&self) -> String { format!("<fun {}.{}>", self.parent_type, self.name) }
    fn _rep(&self) -> String { self.str() }
    fn _doc(&self) -> String { crate::doc::get_or_load_doc(&self.parent_type, &self.name) }
    fn _id(&self) -> u64 { self.id }
}

// ============================================================================
// QUserFun - User-defined functions with closure support
// ============================================================================

#[derive(Debug, Clone)]
pub struct QUserFun {
    pub name: Option<String>,
    pub params: Vec<String>,
    pub param_defaults: Vec<Option<String>>,
    pub param_types: Vec<Option<String>>,
    pub body: String,
    pub doc: Option<String>,
    pub id: u64,
    /// Captured scope for closure-by-reference semantics
    /// When a function is defined, it captures the scope where it was created.
    /// This allows the function to:
    /// - Access variables from outer scopes
    /// - Modify outer variables (closure by reference)
    /// - Share state with other functions in the same scope
    pub captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
    /// Variadic parameters support (QEP-034)
    pub varargs: Option<String>,           // Name of *args parameter (if any)
    pub varargs_type: Option<String>,      // Type annotation for *args elements
    pub kwargs: Option<String>,            // Name of **kwargs parameter (if any)
    pub kwargs_type: Option<String>,       // Type annotation for **kwargs values
    /// Return type annotation (QEP-015)
    pub return_type: Option<String>,       // Return type annotation (if any)
    /// QEP-057: Line offset for accurate line numbers in stack traces
    /// The line number in the source file where the function body starts
    pub line_offset: usize,
}

impl QUserFun {
    /// Create function with captured scope chain for proper closures
    pub fn new(
        name: Option<String>,
        params: Vec<String>,
        param_defaults: Vec<Option<String>>,
        param_types: Vec<Option<String>>,
        body: String,
        doc: Option<String>,
        captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>
    ) -> Self {
        QUserFun {
            name,
            params,
            param_defaults,
            param_types,
            body,
            doc,
            id: next_object_id(),
            captured_scopes,
            varargs: None,
            varargs_type: None,
            kwargs: None,
            kwargs_type: None,
            return_type: None,
            line_offset: 0,  // QEP-057: TODO - capture actual line offset
        }
    }

    /// Create function with variadic parameters support (QEP-034)
    pub fn new_with_variadics(
        name: Option<String>,
        params: Vec<String>,
        param_defaults: Vec<Option<String>>,
        param_types: Vec<Option<String>>,
        body: String,
        doc: Option<String>,
        captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
        varargs: Option<String>,
        varargs_type: Option<String>,
        kwargs: Option<String>,
        kwargs_type: Option<String>,
        return_type: Option<String>,
    ) -> Self {
        QUserFun {
            name,
            params,
            param_defaults,
            param_types,
            body,
            doc,
            id: next_object_id(),
            captured_scopes,
            varargs,
            varargs_type,
            kwargs,
            kwargs_type,
            return_type,
            line_offset: 0,  // QEP-057: TODO - capture actual line offset
        }
    }

    /// Legacy constructor for backwards compatibility (QEP-034)
    #[allow(dead_code)]
    pub fn new_with_varargs(
        name: Option<String>,
        params: Vec<String>,
        param_defaults: Vec<Option<String>>,
        param_types: Vec<Option<String>>,
        body: String,
        doc: Option<String>,
        captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>,
        varargs: Option<String>,
        varargs_type: Option<String>,
    ) -> Self {
        Self::new_with_variadics(
            name, params, param_defaults, param_types, body, doc,
            captured_scopes, varargs, varargs_type, None, None, None
        )
    }
}

impl QObj for QUserFun {
    fn cls(&self) -> String { "UserFun".to_string() }
    fn q_type(&self) -> &'static str { "fun" }
    fn is(&self, type_name: &str) -> bool { type_name == "fun" || type_name == "obj" }

    fn str(&self) -> String {
        match &self.name {
            Some(name) => format!("<fun {}>", name),
            None => "<fun <anonymous>>".to_string(),
        }
    }

    fn _rep(&self) -> String { self.str() }

    fn _doc(&self) -> String {
        if let Some(ref doc) = self.doc {
            return doc.clone();
        }
        match &self.name {
            Some(name) => format!("User-defined function: {}", name),
            None => "Anonymous function".to_string(),
        }
    }

    fn _id(&self) -> u64 { self.id }
}

impl QUserFun {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, EvalError> {
        match method_name {
            "_name" => Ok(QValue::Str(QString::new(
                self.name.clone().unwrap_or_else(|| "<anonymous>".to_string())
            ))),
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "str" => Ok(QValue::Str(QString::new(self.str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_id" => Ok(QValue::Int(QInt::new(self._id() as i64))),
            _ => attr_err!("UserFun has no method '{}'", method_name),
        }
    }
}

pub fn create_fn(module: &str, name: &str) -> QValue {
    QValue::Fun(QFun::new(name.to_string(), module.to_string()))
}
