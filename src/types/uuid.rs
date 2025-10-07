use super::{QObj, next_object_id};
use uuid::Uuid;
use crate::{arg_err, attr_err, value_err};

#[derive(Debug, Clone)]
pub struct QUuid {
    pub value: Uuid,
    pub id: u64,
}

impl QUuid {
    pub fn new(value: Uuid) -> Self {
        QUuid {
            value,
            id: next_object_id(),
        }
    }

    pub fn from_string(s: &str) -> Result<Self, String> {
        match Uuid::parse_str(s) {
            Ok(uuid) => Ok(QUuid::new(uuid)),
            Err(e) => return value_err!("Invalid UUID string: {}", e),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<crate::types::QValue>) -> Result<crate::types::QValue, String> {
        use crate::types::{QValue, QString, QBool, QBytes, QInt, try_call_qobj_method};

        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "to_string" | "str" => {
                if !args.is_empty() {
                    return arg_err!("{} expects 0 arguments, got {}", method_name, args.len());
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            "to_hyphenated" => {
                if !args.is_empty() {
                    return arg_err!("to_hyphenated expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.hyphenated().to_string())))
            }
            "to_simple" => {
                if !args.is_empty() {
                    return arg_err!("to_simple expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.simple().to_string())))
            }
            "to_urn" => {
                if !args.is_empty() {
                    return arg_err!("to_urn expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.urn().to_string())))
            }
            "to_bytes" => {
                if !args.is_empty() {
                    return arg_err!("to_bytes expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bytes(QBytes::new(self.value.as_bytes().to_vec())))
            }
            "version" => {
                if !args.is_empty() {
                    return arg_err!("version expects 0 arguments, got {}", args.len());
                }
                let version = self.value.get_version_num();
                Ok(QValue::Int(QInt::new(version as i64)))
            }
            "variant" => {
                if !args.is_empty() {
                    return arg_err!("variant expects 0 arguments, got {}", args.len());
                }
                let variant = format!("{:?}", self.value.get_variant());
                Ok(QValue::Str(QString::new(variant)))
            }
            "is_nil" => {
                if !args.is_empty() {
                    return arg_err!("is_nil expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_nil())))
            }
            "eq" => {
                if args.len() != 1 {
                    return arg_err!("eq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Uuid(other) => Ok(QValue::Bool(QBool::new(self.value == other.value))),
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "neq" => {
                if args.len() != 1 {
                    return arg_err!("neq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Uuid(other) => Ok(QValue::Bool(QBool::new(self.value != other.value))),
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            _ => attr_err!("Unknown method: Uuid.{}", method_name),
        }
    }
}

impl QObj for QUuid {
    fn cls(&self) -> String {
        "Uuid".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Uuid"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Uuid"
    }

    fn _str(&self) -> String {
        self.value.to_string()
    }

    fn _rep(&self) -> String {
        format!("Uuid(\"{}\")", self.value)
    }

    fn _doc(&self) -> String {
        "UUID (Universally Unique Identifier) value".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
