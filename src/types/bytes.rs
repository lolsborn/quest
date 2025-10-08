use super::*;
use crate::{arg_err, attr_err, index_err, value_err};

#[derive(Debug, Clone)]
pub struct QBytes {
    pub data: Vec<u8>,
    pub id: u64,
}

impl QBytes {
    pub fn new(data: Vec<u8>) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Bytes", id);
        QBytes {
            data,
            id,
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "len" => {
                if !args.is_empty() {
                    return arg_err!("len expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.data.len() as i64)))
            }
            "get" => {
                if args.len() != 1 {
                    return arg_err!("get expects 1 argument (index), got {}", args.len());
                }
                let index = args[0].as_num()? as usize;
                if index >= self.data.len() {
                    return index_err!("Index {} out of bounds for bytes of length {}", index, self.data.len());
                }
                Ok(QValue::Int(QInt::new(self.data[index] as i64)))
            }
            "slice" => {
                if args.len() != 2 {
                    return arg_err!("slice expects 2 arguments (start, end), got {}", args.len());
                }
                let start = args[0].as_num()? as usize;
                let end = args[1].as_num()? as usize;

                if start > self.data.len() || end > self.data.len() || start > end {
                    return index_err!("Invalid slice range {}:{} for bytes of length {}", start, end, self.data.len());
                }

                Ok(QValue::Bytes(QBytes::new(self.data[start..end].to_vec())))
            }
            "decode" => {
                // decode([encoding]) - decodes bytes to string
                let encoding = if args.is_empty() {
                    "utf-8"
                } else if args.len() == 1 {
                    &args[0].as_str()
                } else {
                    return arg_err!("decode expects 0 or 1 arguments, got {}", args.len());
                };

                match encoding {
                    "utf-8" | "utf8" => {
                        match String::from_utf8(self.data.clone()) {
                            Ok(s) => Ok(QValue::Str(QString::new(s))),
                            Err(e) => value_err!("Invalid UTF-8 in bytes: {}", e),
                        }
                    }
                    "hex" => {
                        let hex: String = self.data.iter()
                            .map(|b| format!("{:02x}", b))
                            .collect();
                        Ok(QValue::Str(QString::new(hex)))
                    }
                    "ascii" => {
                        // Allow ASCII decoding (will error on non-ASCII bytes)
                        if self.data.iter().all(|&b| b < 128) {
                            Ok(QValue::Str(QString::new(String::from_utf8_lossy(&self.data).to_string())))
                        } else {
                            Err("Bytes contain non-ASCII characters".to_string())
                        }
                    }
                    _ => value_err!("Unknown encoding: {}. Supported: utf-8, hex, ascii", encoding)
                }
            }
            "to_array" => {
                // Convert bytes to array of numbers
                if !args.is_empty() {
                    return arg_err!("to_array expects 0 arguments, got {}", args.len());
                }
                let array: Vec<QValue> = self.data.iter()
                    .map(|&b| QValue::Int(QInt::new(b as i64)))
                    .collect();
                Ok(QValue::Array(QArray::new(array)))
            }
            _ => attr_err!("Unknown method '{}' for bytes type", method_name),
        }
    }
}

impl QObj for QBytes {
    fn cls(&self) -> String {
        "Bytes".to_string()
    }

    fn q_type(&self) -> &'static str {
        "bytes"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "bytes" || type_name == "obj"
    }

    fn str(&self) -> String {
        // Display as b"..." with escaped bytes
        let mut result = String::from("b\"");
        for &byte in &self.data {
            if byte >= 32 && byte < 127 && byte != b'\\' && byte != b'"' {
                result.push(byte as char);
            } else {
                result.push_str(&format!("\\x{:02x}", byte));
            }
        }
        result.push('"');
        result
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        "Bytes type - represents binary data".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QBytes {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Bytes", self.id);
    }
}
