use super::*;

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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }
        Err(format!("Fun has no method '{}'", method_name))
    }
}

impl QObj for QFun {
    fn cls(&self) -> String { "Fun".to_string() }
    fn q_type(&self) -> &'static str { "fun" }
    fn is(&self, type_name: &str) -> bool { type_name == "fun" || type_name == "obj" }
    fn _str(&self) -> String { format!("<fun {}.{}>", self.parent_type, self.name) }
    fn _rep(&self) -> String { self._str() }
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
}

impl QUserFun {
    /// Create function with captured scope chain for proper closures
    pub fn new(
        name: Option<String>,
        params: Vec<String>,
        body: String,
        doc: Option<String>,
        captured_scopes: Vec<Rc<RefCell<HashMap<String, QValue>>>>
    ) -> Self {
        QUserFun {
            name,
            params,
            body,
            doc,
            id: next_object_id(),
            captured_scopes,
        }
    }
}

impl QObj for QUserFun {
    fn cls(&self) -> String { "UserFun".to_string() }
    fn q_type(&self) -> &'static str { "fun" }
    fn is(&self, type_name: &str) -> bool { type_name == "fun" || type_name == "obj" }

    fn _str(&self) -> String {
        match &self.name {
            Some(name) => format!("<fun {}>", name),
            None => "<fun <anonymous>>".to_string(),
        }
    }

    fn _rep(&self) -> String { self._str() }

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
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "_name" => Ok(QValue::Str(QString::new(
                self.name.clone().unwrap_or_else(|| "<anonymous>".to_string())
            ))),
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "_str" => Ok(QValue::Str(QString::new(self._str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_id" => Ok(QValue::Int(QInt::new(self._id() as i64))),
            _ => Err(format!("UserFun has no method '{}'", method_name)),
        }
    }
}

pub fn create_fn(module: &str, name: &str) -> QValue {
    QValue::Fun(QFun::new(name.to_string(), module.to_string()))
}
