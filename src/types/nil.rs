use super::*;

#[derive(Debug, Clone)]
pub struct QNil;

impl QObj for QNil {
    fn cls(&self) -> String {
        "Nil".to_string()
    }

    fn q_type(&self) -> &'static str {
        "nil"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "nil" || type_name == "obj"
    }

    fn str(&self) -> String {
        "nil".to_string()
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        "Nil type - represents absence of value".to_string()
    }

    fn _id(&self) -> u64 {
        0 // nil is a singleton, always has ID 0
    }
}
