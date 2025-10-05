use crate::types::*;
use crate::QValue;
use std::rc::Rc;
use std::cell::RefCell;

#[derive(Debug, Clone)]
pub struct QStringIO {
    pub buffer: String,
    pub position: usize,
    pub id: u64,
}

impl QStringIO {
    pub fn new() -> Self {
        Self {
            buffer: String::new(),
            position: 0,
            id: next_object_id(),
        }
    }

    pub fn new_with_content(content: String) -> Self {
        Self {
            buffer: content,
            position: 0,
            id: next_object_id(),
        }
    }

    /// Write data to buffer. Always appends to end regardless of position.
    /// Returns number of bytes written.
    pub fn write(&mut self, data: &str) -> usize {
        self.buffer.push_str(data);
        self.position = self.buffer.len();
        data.len()
    }

    /// Write multiple strings to buffer
    pub fn writelines(&mut self, lines: Vec<String>) {
        for line in lines {
            self.write(&line);
        }
    }

    pub fn get_value(&self) -> String {
        self.buffer.clone()
    }

    pub fn read(&mut self, size: Option<usize>) -> String {
        let start = self.position;
        let end = match size {
            Some(n) => std::cmp::min(start + n, self.buffer.len()),
            None => self.buffer.len(),
        };

        let result = self.buffer[start..end].to_string();
        self.position = end;
        result
    }

    pub fn readline(&mut self) -> String {
        let start = self.position;
        if start >= self.buffer.len() {
            return String::new();
        }

        if let Some(newline_pos) = self.buffer[start..].find('\n') {
            let end = start + newline_pos + 1;
            let result = self.buffer[start..end].to_string();
            self.position = end;
            result
        } else {
            // No newline found, return rest of buffer
            let result = self.buffer[start..].to_string();
            self.position = self.buffer.len();
            result
        }
    }

    pub fn readlines(&mut self) -> Vec<String> {
        let mut lines = Vec::new();
        loop {
            let line = self.readline();
            if line.is_empty() {
                break;
            }
            lines.push(line);
        }
        lines
    }

    pub fn tell(&self) -> usize {
        self.position
    }

    /// Seek to position. Returns new position.
    /// offset can be negative for whence=1 (SEEK_CUR) and whence=2 (SEEK_END)
    pub fn seek(&mut self, offset: i64, whence: i32) -> usize {
        self.position = match whence {
            0 => {
                // SEEK_SET - absolute position
                offset.max(0) as usize
            }
            1 => {
                // SEEK_CUR - relative to current position
                let new_pos = (self.position as i64) + offset;
                new_pos.max(0) as usize
            }
            2 => {
                // SEEK_END - relative to end
                let new_pos = (self.buffer.len() as i64) + offset;
                new_pos.max(0) as usize
            }
            _ => self.position,
        };
        // Clamp to valid range
        self.position = std::cmp::min(self.position, self.buffer.len());
        self.position
    }

    pub fn clear(&mut self) {
        self.buffer.clear();
        self.position = 0;
    }

    /// Truncate buffer to size. If size not provided, use current position.
    /// Returns new size.
    pub fn truncate(&mut self, size: Option<usize>) -> usize {
        let truncate_at = size.unwrap_or(self.position);
        let truncate_at = std::cmp::min(truncate_at, self.buffer.len());
        self.buffer.truncate(truncate_at);
        // Adjust position if it's beyond new end
        self.position = std::cmp::min(self.position, self.buffer.len());
        self.buffer.len()
    }

    pub fn len(&self) -> usize {
        self.buffer.len()
    }

    pub fn char_len(&self) -> usize {
        self.buffer.chars().count()
    }

    pub fn empty(&self) -> bool {
        self.buffer.is_empty()
    }

    pub fn call_method(&mut self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "write" => {
                if args.len() != 1 {
                    return Err(format!("write expects 1 argument, got {}", args.len()));
                }
                let data = match &args[0] {
                    QValue::Str(s) => s.value.clone(),
                    _ => return Err("write expects a Str argument".to_string()),
                };
                let count = self.write(&data);
                Ok(QValue::Int(QInt::new(count as i64)))
            }
            "writelines" => {
                if args.len() != 1 {
                    return Err(format!("writelines expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Array(arr) => {
                        let elements = arr.elements.borrow();
                        let lines: Vec<String> = elements.iter()
                            .map(|v| match v {
                                QValue::Str(s) => Ok((*s.value).clone()),
                                _ => Err("writelines expects an Array of Str".to_string()),
                            })
                            .collect::<Result<Vec<_>, _>>()?;
                        self.writelines(lines);
                        Ok(QValue::Nil(QNil))
                    }
                    _ => Err("writelines expects an Array argument".to_string())
                }
            }
            "read" => {
                let size = if args.is_empty() {
                    None
                } else if args.len() == 1 {
                    match &args[0] {
                        QValue::Int(n) => Some(n.value as usize),
                        _ => return Err("read expects an Int argument".to_string()),
                    }
                } else {
                    return Err(format!("read expects 0 or 1 argument, got {}", args.len()));
                };
                let result = self.read(size);
                Ok(QValue::Str(QString::new(result)))
            }
            "readline" => {
                if !args.is_empty() {
                    return Err(format!("readline expects 0 arguments, got {}", args.len()));
                }
                let result = self.readline();
                Ok(QValue::Str(QString::new(result)))
            }
            "readlines" => {
                if !args.is_empty() {
                    return Err(format!("readlines expects 0 arguments, got {}", args.len()));
                }
                let lines = self.readlines();
                let qlines: Vec<QValue> = lines.into_iter()
                    .map(|s| QValue::Str(QString::new(s)))
                    .collect();
                Ok(QValue::Array(QArray::new(qlines)))
            }
            "get_value" | "getvalue" => {
                if !args.is_empty() {
                    return Err(format!("{} expects 0 arguments, got {}", method_name, args.len()));
                }
                Ok(QValue::Str(QString::new(self.get_value())))
            }
            "tell" => {
                if !args.is_empty() {
                    return Err(format!("tell expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.tell() as i64)))
            }
            "seek" => {
                if args.is_empty() || args.len() > 2 {
                    return Err(format!("seek expects 1 or 2 arguments, got {}", args.len()));
                }
                let offset = match &args[0] {
                    QValue::Int(n) => n.value,
                    _ => return Err("seek expects Int argument for offset".to_string()),
                };
                let whence = if args.len() == 2 {
                    match &args[1] {
                        QValue::Int(n) => n.value as i32,
                        _ => return Err("seek expects Int argument for whence".to_string()),
                    }
                } else {
                    0  // Default to SEEK_SET
                };
                let new_pos = self.seek(offset, whence);
                Ok(QValue::Int(QInt::new(new_pos as i64)))
            }
            "clear" => {
                if !args.is_empty() {
                    return Err(format!("clear expects 0 arguments, got {}", args.len()));
                }
                self.clear();
                Ok(QValue::Nil(QNil))
            }
            "truncate" => {
                if args.len() > 1 {
                    return Err(format!("truncate expects 0 or 1 argument, got {}", args.len()));
                }
                let size = if args.len() == 1 {
                    match &args[0] {
                        QValue::Int(n) => Some(n.value as usize),
                        _ => return Err("truncate expects an Int argument".to_string()),
                    }
                } else {
                    None
                };
                let new_size = self.truncate(size);
                Ok(QValue::Int(QInt::new(new_size as i64)))
            }
            "flush" | "close" => {
                // No-ops for compatibility
                if !args.is_empty() {
                    return Err(format!("{} expects 0 arguments, got {}", method_name, args.len()));
                }
                Ok(QValue::Nil(QNil))
            }
            "closed" => {
                if !args.is_empty() {
                    return Err(format!("closed expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(false)))  // Always false
            }
            "len" => {
                if !args.is_empty() {
                    return Err(format!("len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.len() as i64)))
            }
            "char_len" => {
                if !args.is_empty() {
                    return Err(format!("char_len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.char_len() as i64)))
            }
            "empty" => {
                if !args.is_empty() {
                    return Err(format!("empty expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.empty())))
            }
            "_enter" => {
                if !args.is_empty() {
                    return Err(format!("_enter expects 0 arguments, got {}", args.len()));
                }
                // Return self wrapped back in StringIO
                Ok(QValue::StringIO(Rc::new(RefCell::new(self.clone()))))
            }
            "_exit" => {
                if !args.is_empty() {
                    return Err(format!("_exit expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Nil(QNil))
            }
            _ => Err(format!("Unknown method '{}' on StringIO", method_name))
        }
    }
}

impl QObj for QStringIO {
    fn cls(&self) -> String {
        "StringIO".to_string()
    }

    fn q_type(&self) -> &'static str {
        "StringIO"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "StringIO"
    }

    fn _str(&self) -> String {
        format!("<StringIO: {} bytes at position {}>", self.buffer.len(), self.position)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        "In-memory string buffer with file-like interface".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
