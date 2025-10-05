use super::*;

#[derive(Debug, Clone)]
pub struct FieldDef {
    pub name: String,
    pub type_annotation: Option<String>,  // "num", "str", etc.
    pub optional: bool,                    // true if field is optional (num?: x)
    pub default_value: Option<QValue>,    // Evaluated default value (evaluated at type definition time)
    pub is_public: bool,                   // true if field is marked with pub
}

impl FieldDef {
    pub fn new(name: String, type_annotation: Option<String>, optional: bool) -> Self {
        FieldDef {
            name,
            type_annotation,
            optional,
            default_value: None,
            is_public: false,  // Private by default
        }
    }

    pub fn with_default(name: String, type_annotation: Option<String>, optional: bool, default_value: QValue) -> Self {
        FieldDef {
            name,
            type_annotation,
            optional,
            default_value: Some(default_value),
            is_public: false,  // Private by default
        }
    }

    pub fn public(name: String, type_annotation: Option<String>, optional: bool) -> Self {
        FieldDef {
            name,
            type_annotation,
            optional,
            default_value: None,
            is_public: true,
        }
    }

    pub fn public_with_default(name: String, type_annotation: Option<String>, optional: bool, default_value: QValue) -> Self {
        FieldDef {
            name,
            type_annotation,
            optional,
            default_value: Some(default_value),
            is_public: true,
        }
    }
}

/// Type definition (created by `type` keyword)
#[derive(Debug, Clone)]
pub struct QType {
    pub name: String,
    pub fields: Vec<FieldDef>,
    pub methods: HashMap<String, QUserFun>,
    pub static_methods: HashMap<String, QUserFun>,
    pub implemented_traits: Vec<String>,
    pub doc: Option<String>,  // Docstring from first string literal after type declaration
    pub id: u64,
}

impl QType {
    pub fn with_doc(name: String, fields: Vec<FieldDef>, doc: Option<String>) -> Self {
        QType {
            name,
            fields,
            methods: HashMap::new(),
            static_methods: HashMap::new(),
            implemented_traits: Vec::new(),
            doc,
            id: next_object_id(),
        }
    }

    pub fn add_method(&mut self, name: String, func: QUserFun) {
        self.methods.insert(name, func);
    }

    pub fn add_static_method(&mut self, name: String, func: QUserFun) {
        self.static_methods.insert(name, func);
    }

    pub fn add_trait(&mut self, trait_name: String) {
        if !self.implemented_traits.contains(&trait_name) {
            self.implemented_traits.push(trait_name);
        }
    }

    pub fn get_method(&self, method_name: &str) -> Option<&QUserFun> {
        self.methods.get(method_name)
    }

    pub fn get_static_method(&self, method_name: &str) -> Option<&QUserFun> {
        self.static_methods.get(method_name)
    }
}

impl QObj for QType {
    fn cls(&self) -> String {
        "Type".to_string()
    }

    fn q_type(&self) -> &'static str {
        "type"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "type" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("type {}", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // If docstring is available, return it followed by field info
        let mut doc = if let Some(ref docstring) = self.doc {
            format!("{}\n\n", docstring)
        } else {
            format!("Type definition: {}\n", self.name)
        };

        // Add field information
        if !self.fields.is_empty() {
            let field_docs: Vec<String> = self.fields.iter().map(|f| {
                let optional_marker = if f.optional { "?" } else { "" };
                let type_prefix = if let Some(ref t) = f.type_annotation {
                    format!("{}{}: ", t, optional_marker)
                } else {
                    String::new()
                };
                format!("  {}{}", type_prefix, f.name)
            }).collect();
            doc.push_str(&format!("Fields:\n{}", field_docs.join("\n")));
        }

        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Struct instance (an instance of a QType)
#[derive(Debug, Clone)]
pub struct QStruct {
    pub type_name: String,
    #[allow(dead_code)]
    pub type_id: u64,
    pub fields: HashMap<String, QValue>,
    pub id: u64,
}

impl QStruct {
    pub fn new(type_name: String, type_id: u64, fields: HashMap<String, QValue>) -> Self {
        QStruct {
            type_name,
            type_id,
            fields,
            id: next_object_id(),
        }
    }

    pub fn get_field(&self, name: &str) -> Option<&QValue> {
        self.fields.get(name)
    }

    pub fn set_field(&mut self, name: String, value: QValue) {
        self.fields.insert(name, value);
    }
}

impl QObj for QStruct {
    fn cls(&self) -> String {
        self.type_name.clone()
    }

    fn q_type(&self) -> &'static str {
        "struct"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == self.type_name || type_name == "struct" || type_name == "obj"
    }

    fn _str(&self) -> String {
        let fields_str: Vec<String> = self.fields
            .iter()
            .map(|(k, v)| format!("{}: {}", k, v.as_obj()._str()))
            .collect();
        format!("{}{{ {} }}", self.type_name, fields_str.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Instance of type {}", self.type_name)
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Trait method signature
#[derive(Debug, Clone)]
pub struct TraitMethod {
    pub name: String,
    pub parameters: Vec<String>,
    #[allow(dead_code)]
    pub return_type: Option<String>,
}

impl TraitMethod {
    pub fn new(name: String, parameters: Vec<String>, return_type: Option<String>) -> Self {
        TraitMethod {
            name,
            parameters,
            return_type,
        }
    }
}

/// Trait definition
#[derive(Debug, Clone)]
pub struct QTrait {
    pub name: String,
    pub required_methods: Vec<TraitMethod>,
    pub doc: Option<String>,  // Docstring from first string literal after trait declaration
    pub id: u64,
}

impl QTrait {
    pub fn with_doc(name: String, required_methods: Vec<TraitMethod>, doc: Option<String>) -> Self {
        QTrait {
            name,
            required_methods,
            doc,
            id: next_object_id(),
        }
    }
}

impl QObj for QTrait {
    fn cls(&self) -> String {
        "Trait".to_string()
    }

    fn q_type(&self) -> &'static str {
        "trait"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "trait" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("trait {}", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // If docstring is available, return it followed by method info
        let mut doc = if let Some(ref docstring) = self.doc {
            format!("{}\n\n", docstring)
        } else {
            format!("Trait definition: {}\n", self.name)
        };

        // Add required methods information
        if !self.required_methods.is_empty() {
            let method_docs: Vec<String> = self.required_methods.iter().map(|m| {
                let params = m.parameters.join(", ");
                let return_annotation = if let Some(ref ret) = m.return_type {
                    format!(" -> {}", ret)
                } else {
                    String::new()
                };
                format!("  fun {}({}){}", m.name, params, return_annotation)
            }).collect();
            doc.push_str(&format!("Required methods:\n{}", method_docs.join("\n")));
        }

        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
