use super::*;
use std::collections::HashSet;

// ============================================================================
// QModule - Module with public/private encapsulation
// ============================================================================

#[derive(Debug, Clone)]
pub struct QModule {
    pub name: String,
    pub doc: Option<String>,
    pub source_path: Option<String>,
    pub id: u64,

    /// All module members (both public and private)
    /// Private members are accessible to functions defined in the module
    /// (via their captured_scope) but not from external code
    members: Rc<RefCell<HashMap<String, QValue>>>,

    /// Set of public member names
    /// Only these are accessible via module.member syntax from outside
    public_items: HashSet<String>,
}

impl QModule {
    /// Create module with all members public (for built-in Rust modules)
    pub fn new(name: String, members: HashMap<String, QValue>) -> Self {
        let public_items: HashSet<String> = members.keys().cloned().collect();
        Self::with_public_items(name, members, public_items, None, None)
    }

    /// Create module with documentation (all members public)
    pub fn with_doc(
        name: String,
        members: HashMap<String, QValue>,
        source_path: Option<String>,
        doc: Option<String>
    ) -> Self {
        let public_items: HashSet<String> = members.keys().cloned().collect();
        Self::with_public_items(name, members, public_items, source_path, doc)
    }

    /// Create module with explicit public/private separation
    pub fn with_public_items(
        name: String,
        members: HashMap<String, QValue>,
        public_items: HashSet<String>,
        source_path: Option<String>,
        doc: Option<String>
    ) -> Self {
        QModule {
            name,
            members: Rc::new(RefCell::new(members)),
            public_items,
            doc,
            source_path,
            id: next_object_id(),
        }
    }

    /// Get a member by name (only if public)
    /// Returns None if member doesn't exist or is private
    pub fn get_member(&self, member_name: &str) -> Option<QValue> {
        if self.public_items.contains(member_name) {
            self.members.borrow().get(member_name).cloned()
        } else {
            None
        }
    }

    /// Get the shared members map for function capture
    /// This is used when creating functions in module scope
    /// Functions capture this and can access private members
    pub fn get_members_ref(&self) -> Rc<RefCell<HashMap<String, QValue>>> {
        Rc::clone(&self.members)
    }

    /// Check if a member is public
    pub fn is_public(&self, member_name: &str) -> bool {
        self.public_items.contains(member_name)
    }

    /// Get all public member names (for introspection)
    pub fn public_member_names(&self) -> Vec<String> {
        self.public_items.iter().cloned().collect()
    }
}

impl QObj for QModule {
    fn cls(&self) -> String { "Module".to_string() }
    fn q_type(&self) -> &'static str { "module" }
    fn is(&self, type_name: &str) -> bool { type_name == "module" || type_name == "obj" }
    fn str(&self) -> String { format!("<module {}>", self.name) }
    fn _rep(&self) -> String { self.str() }

    fn _doc(&self) -> String {
        if let Some(ref doc) = self.doc {
            match crate::doc::format_with_quest(doc) {
                Ok(formatted) => formatted,
                Err(_) => doc.clone(),
            }
        } else {
            format!("Module: {}", self.name)
        }
    }

    fn _id(&self) -> u64 { self.id }
}
