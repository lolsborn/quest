use super::*;

#[derive(Debug, Clone)]
pub struct QFun {
    pub name: String,
    pub parent_type: String,
    pub doc: String,
    pub id: u64,
}

impl QFun {
    pub fn new(name: String, parent_type: String, doc: String) -> Self {
        QFun {
            name,
            parent_type,
            doc,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // All QFun methods are QObj trait methods
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }
        Err(format!("Fun has no method '{}'", method_name))
    }
}

impl QObj for QFun {
    fn cls(&self) -> String {
        "Fun".to_string()
    }

    fn q_type(&self) -> &'static str {
        "fun"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "fun" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("<fun {}.{}>", self.parent_type, self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        self.doc.clone()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QUserFun {
    pub name: Option<String>,  // None for anonymous functions
    pub params: Vec<String>,
    pub body: String,  // Store body as string to re-eval
    pub doc: Option<String>,   // Docstring extracted from first string literal in body
    #[allow(dead_code)]
    pub id: u64,
}

impl QUserFun {
    pub fn new(name: Option<String>, params: Vec<String>, body: String) -> Self {
        QUserFun {
            name,
            params,
            body,
            doc: None,
            id: next_object_id(),
        }
    }

    pub fn with_doc(name: Option<String>, params: Vec<String>, body: String, doc: Option<String>) -> Self {
        QUserFun {
            name,
            params,
            body,
            doc,
            id: next_object_id(),
        }
    }
}

impl QObj for QUserFun {
    fn cls(&self) -> String {
        "UserFun".to_string()
    }

    fn q_type(&self) -> &'static str {
        "fun"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "fun" || type_name == "obj"
    }

    fn _str(&self) -> String {
        match &self.name {
            Some(name) => format!("<fun {}>", name),
            None => "<fun <anonymous>>".to_string(),
        }
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // Return docstring if available
        if let Some(ref doc) = self.doc {
            return doc.clone();
        }

        // Otherwise return default doc
        match &self.name {
            Some(name) => format!("User-defined function: {}", name),
            None => "Anonymous function".to_string(),
        }
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl QUserFun {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "_str" => Ok(QValue::Str(QString::new(self._str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_id" => Ok(QValue::Num(QNum::new(self._id() as f64))),
            _ => Err(format!("UserFun has no method '{}'", method_name)),
        }
    }
}


pub fn create_fn(module: &str, name: &str, doc: &str) -> QValue {
    QValue::Fun(QFun::new(name.to_string(), module.to_string(), doc.to_string()))
}
