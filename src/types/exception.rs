use super::*;
use std::fmt;
use crate::attr_err;

/// Typed exception enum for QEP-037
#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum ExceptionType {
    // Base exception type
    Err,

    // Specific exception types
    ValueErr,      // Invalid value for operation
    TypeErr,       // Wrong type for operation
    IndexErr,      // Sequence index out of range
    KeyErr,        // Dictionary key not found
    ArgErr,        // Wrong number/type of arguments
    AttrErr,       // Object has no attribute/method
    NameErr,       // Name not found in scope
    RuntimeErr,    // Generic runtime error
    IOErr,         // Input/output operation failed
    ImportErr,     // Module import failed
    SyntaxErr,     // Syntax or parsing error

    // User-defined exception (from Quest code)
    Custom(String),
}

impl ExceptionType {
    /// Get the string name of this exception type
    pub fn name(&self) -> &str {
        match self {
            ExceptionType::Err => "Err",
            ExceptionType::ValueErr => "ValueErr",
            ExceptionType::TypeErr => "TypeErr",
            ExceptionType::IndexErr => "IndexErr",
            ExceptionType::KeyErr => "KeyErr",
            ExceptionType::ArgErr => "ArgErr",
            ExceptionType::AttrErr => "AttrErr",
            ExceptionType::NameErr => "NameErr",
            ExceptionType::RuntimeErr => "RuntimeErr",
            ExceptionType::IOErr => "IOErr",
            ExceptionType::ImportErr => "ImportErr",
            ExceptionType::SyntaxErr => "SyntaxErr",
            ExceptionType::Custom(name) => name,
        }
    }

    /// Check if this exception type is a subtype of (or equal to) parent
    pub fn is_subtype_of(&self, parent: &ExceptionType) -> bool {
        // Base case: same type
        if self == parent {
            return true;
        }

        // Err is the base type - all exceptions are subtypes of Err
        if matches!(parent, ExceptionType::Err) {
            return true;
        }

        // Future: add subtype relationships for user-defined types
        // (would require trait-based hierarchy design)
        false
    }

    /// Parse exception type from string (used in catch clauses and error parsing)
    pub fn from_str(s: &str) -> Self {
        match s {
            "Err" => ExceptionType::Err,
            "ValueErr" => ExceptionType::ValueErr,
            "TypeErr" => ExceptionType::TypeErr,
            "IndexErr" => ExceptionType::IndexErr,
            "KeyErr" => ExceptionType::KeyErr,
            "ArgErr" => ExceptionType::ArgErr,
            "AttrErr" => ExceptionType::AttrErr,
            "NameErr" => ExceptionType::NameErr,
            "RuntimeErr" => ExceptionType::RuntimeErr,
            "IOErr" => ExceptionType::IOErr,
            "ImportErr" => ExceptionType::ImportErr,
            "SyntaxErr" => ExceptionType::SyntaxErr,
            _ => ExceptionType::Custom(s.to_string()),
        }
    }
}

impl fmt::Display for ExceptionType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.name())
    }
}

#[derive(Debug, Clone)]
pub struct QException {
    pub exception_type: ExceptionType,  // Changed from String to enum
    pub message: String,
    pub line: Option<usize>,
    pub file: Option<String>,
    pub stack: Vec<String>,
    pub cause: Option<Box<QException>>,
    pub id: u64,
}

impl QException {
    pub fn new(exception_type: ExceptionType, message: String, line: Option<usize>, file: Option<String>) -> Self {
        QException {
            exception_type,
            message,
            line,
            file,
            stack: Vec::new(),
            cause: None,
            id: next_object_id(),
        }
    }

    /// Convenience constructor from string (parses exception type)
    pub fn from_string(exception_type: String, message: String, line: Option<usize>, file: Option<String>) -> Self {
        QException::new(ExceptionType::from_str(&exception_type), message, line, file)
    }
}

impl QObj for QException {
    fn cls(&self) -> String {
        "Exception".to_string()
    }

    fn q_type(&self) -> &'static str {
        "exception"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "exception" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("{}: {}", self.exception_type, self.message)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        let mut doc = format!("Exception: {}\nMessage: {}", self.exception_type, self.message);
        if let Some(ref line) = self.line {
            doc.push_str(&format!("\nLine: {}", line));
        }
        if let Some(ref file) = self.file {
            doc.push_str(&format!("\nFile: {}", file));
        }
        if !self.stack.is_empty() {
            doc.push_str("\nStack trace:\n");
            for frame in &self.stack {
                doc.push_str(&format!("  {}\n", frame));
            }
        }
        if let Some(ref cause) = self.cause {
            doc.push_str(&format!("\nCaused by: {}", cause._str()));
        }
        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl QException {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "type" => {
                // Return the exception type as a Type object (QEP-037)
                // This allows direct comparison with exception type constants like RuntimeErr
                let type_name = self.exception_type.name();
                let type_obj = QType::with_doc(
                    type_name.to_string(),
                    Vec::new(),
                    Some(format!("{} exception type", type_name))
                );
                Ok(QValue::Type(Box::new(type_obj)))
            },
            "message" => Ok(QValue::Str(QString::new(self.message.clone()))),
            "stack" => {
                let stack_arr = self.stack.iter()
                    .map(|s| QValue::Str(QString::new(s.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(stack_arr)))
            },
            "line" => {
                if let Some(line) = self.line {
                    Ok(QValue::Int(QInt::new(line as i64)))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "file" => {
                if let Some(ref file) = self.file {
                    Ok(QValue::Str(QString::new(file.clone())))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "cause" => {
                if let Some(ref cause) = self.cause {
                    Ok(QValue::Exception((**cause).clone()))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "_str" => Ok(QValue::Str(QString::new(self._str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            _ => attr_err!("Exception has no method '{}'", method_name)
        }
    }
}
