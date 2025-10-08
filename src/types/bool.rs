use super::*;
use std::sync::OnceLock;
use crate::{attr_err, arg_err};

#[derive(Debug, Clone)]
pub struct QBool {
    pub value: bool,
    pub id: u64,
}

// Singleton instances for true and false
static TRUE_INSTANCE: OnceLock<QBool> = OnceLock::new();
static FALSE_INSTANCE: OnceLock<QBool> = OnceLock::new();

impl QBool {
    pub fn new(value: bool) -> Self {
        // Return singleton instance for true or false
        if value {
            TRUE_INSTANCE.get_or_init(|| {
                let id = next_object_id();
                crate::alloc_counter::track_alloc("Bool", id);
                QBool { value: true, id }
            }).clone()
        } else {
            FALSE_INSTANCE.get_or_init(|| {
                let id = next_object_id();
                crate::alloc_counter::track_alloc("Bool", id);
                QBool { value: false, id }
            }).clone()
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "eq" => {
                if args.len() != 1 {
                    return arg_err!("eq expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_bool();
                Ok(QValue::Bool(QBool::new(self.value == other)))
            }
            "neq" => {
                if args.len() != 1 {
                    return arg_err!("neq expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_bool();
                Ok(QValue::Bool(QBool::new(self.value != other)))
            }
            _ => attr_err!("Unknown method '{}' for bool type", method_name),
        }
    }
}

impl QObj for QBool {
    fn cls(&self) -> String {
        "Bool".to_string()
    }

    fn q_type(&self) -> &'static str {
        "bool"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "bool" || type_name == "obj"
    }

    fn str(&self) -> String {
        if self.value { "true".to_string() } else { "false".to_string() }
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        "Boolean type - represents true or false".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QBool {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Bool", self.id);
    }
}
