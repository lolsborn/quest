use super::*;

#[derive(Debug, Clone)]
pub struct QModule {
    pub name: String,
    pub members: Rc<RefCell<HashMap<String, QValue>>>,
    pub doc: Option<String>,  // Module docstring from first string literal in file
    pub id: u64,
    #[allow(dead_code)]
    pub source_path: Option<String>,  // Track source file for cache updates
}

impl QModule {
    pub fn new(name: String, members: HashMap<String, QValue>) -> Self {
        QModule {
            name,
            members: Rc::new(RefCell::new(members)),
            doc: None,
            id: next_object_id(),
            source_path: None,
        }
    }

    pub fn with_doc(name: String, members: HashMap<String, QValue>, source_path: Option<String>, doc: Option<String>) -> Self {
        QModule {
            name,
            members: Rc::new(RefCell::new(members)),
            doc,
            id: next_object_id(),
            source_path,
        }
    }

    pub fn get_member(&self, member_name: &str) -> Option<QValue> {
        self.members.borrow().get(member_name).cloned()
    }
}

impl QObj for QModule {
    fn cls(&self) -> String {
        "Module".to_string()
    }

    fn q_type(&self) -> &'static str {
        "module"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "module" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("<module {}>", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        if let Some(ref doc) = self.doc {
            doc.clone()
        } else {
            format!("Module: {}", self.name)
        }
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
