use super::*;

#[derive(Debug, Clone)]
pub struct QException {
    pub exception_type: String,
    pub message: String,
    pub line: Option<usize>,
    pub file: Option<String>,
    pub stack: Vec<String>,
    pub cause: Option<Box<QException>>,
    pub id: u64,
}

impl QException {
    pub fn new(exception_type: String, message: String, line: Option<usize>, file: Option<String>) -> Self {
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
            "exc_type" | "type" => Ok(QValue::Str(QString::new(self.exception_type.clone()))),
            "message" => Ok(QValue::Str(QString::new(self.message.clone()))),
            "stack" => {
                let stack_arr = self.stack.iter()
                    .map(|s| QValue::Str(QString::new(s.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(stack_arr)))
            },
            "line" => {
                if let Some(line) = self.line {
                    Ok(QValue::Num(QNum::new(line as f64)))
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
            "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
            _ => Err(format!("Exception has no method '{}'", method_name))
        }
    }
}
