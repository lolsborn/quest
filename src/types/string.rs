use super::*;
use std::rc::Rc;
use num_traits::Num;  // For BigInt::from_str_radix
use crate::{arg_err, attr_err};

#[derive(Debug, Clone)]
pub struct QString {
    pub value: Rc<String>,
    pub id: u64,
}

impl QString {
    pub fn new(value: String) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Str", id);
        QString {
            value: Rc::new(value),
            id,
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => {
                if !args.is_empty() {
                    return arg_err!("len expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.value.len() as i64)))
            }
            "concat" => {
                if args.len() != 1 {
                    return arg_err!("concat expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_str();
                Ok(QValue::Str(QString::new(format!("{}{}", self.value, other))))
            }
            "upper" => {
                if !args.is_empty() {
                    return arg_err!("upper expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.to_uppercase())))
            }
            "lower" => {
                if !args.is_empty() {
                    return arg_err!("lower expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.to_lowercase())))
            }
            "eq" => {
                if args.len() != 1 {
                    return arg_err!("eq expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.as_str() == other)))
            }
            "neq" => {
                if args.len() != 1 {
                    return arg_err!("neq expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.as_str() != other)))
            }
            // Case conversion methods
            "capitalize" => {
                if !args.is_empty() {
                    return arg_err!("capitalize expects 0 arguments, got {}", args.len());
                }
                let mut chars = self.value.chars();
                let capitalized = match chars.next() {
                    None => String::new(),
                    Some(first) => first.to_uppercase().chain(chars.as_str().to_lowercase().chars()).collect(),
                };
                Ok(QValue::Str(QString::new(capitalized)))
            }
            "title" => {
                if !args.is_empty() {
                    return arg_err!("title expects 0 arguments, got {}", args.len());
                }
                let mut result = String::new();
                let mut capitalize_next = true;
                for ch in self.value.chars() {
                    if ch.is_whitespace() {
                        result.push(ch);
                        capitalize_next = true;
                    } else if capitalize_next {
                        result.extend(ch.to_uppercase());
                        capitalize_next = false;
                    } else {
                        result.extend(ch.to_lowercase());
                    }
                }
                Ok(QValue::Str(QString::new(result)))
            }
            // Trim methods
            "trim" => {
                if !args.is_empty() {
                    return arg_err!("trim expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.trim().to_string())))
            }
            "ltrim" => {
                if !args.is_empty() {
                    return arg_err!("ltrim expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.trim_start().to_string())))
            }
            "rtrim" => {
                if !args.is_empty() {
                    return arg_err!("rtrim expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.trim_end().to_string())))
            }
            "repeat" => {
                if args.len() != 1 {
                    return arg_err!("repeat expects 1 argument, got {}", args.len());
                }
                let count = match &args[0] {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            return Err("repeat count must be non-negative".into());
                        }
                        i.value as usize
                    }
                    _ => return Err("repeat expects an integer argument".into()),
                };
                Ok(QValue::Str(QString::new(self.value.repeat(count))))
            }
            // String checking methods
            "isalnum" => {
                if !args.is_empty() {
                    return arg_err!("isalnum expects 0 arguments, got {}", args.len());
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_alphanumeric());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isalpha" => {
                if !args.is_empty() {
                    return arg_err!("isalpha expects 0 arguments, got {}", args.len());
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_alphabetic());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isascii" => {
                if !args.is_empty() {
                    return arg_err!("isascii expects 0 arguments, got {}", args.len());
                }
                let result = self.value.chars().all(|c| c.is_ascii());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isdigit" => {
                if !args.is_empty() {
                    return arg_err!("isdigit expects 0 arguments, got {}", args.len());
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_ascii_digit());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isnumeric" => {
                if !args.is_empty() {
                    return arg_err!("isnumeric expects 0 arguments, got {}", args.len());
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_numeric());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "islower" => {
                if !args.is_empty() {
                    return arg_err!("islower expects 0 arguments, got {}", args.len());
                }
                let has_cased = self.value.chars().any(|c| c.is_alphabetic());
                let all_lower = self.value.chars().filter(|c| c.is_alphabetic()).all(|c| c.is_lowercase());
                Ok(QValue::Bool(QBool::new(has_cased && all_lower)))
            }
            "isupper" => {
                if !args.is_empty() {
                    return arg_err!("isupper expects 0 arguments, got {}", args.len());
                }
                let has_cased = self.value.chars().any(|c| c.is_alphabetic());
                let all_upper = self.value.chars().filter(|c| c.is_alphabetic()).all(|c| c.is_uppercase());
                Ok(QValue::Bool(QBool::new(has_cased && all_upper)))
            }
            "isspace" => {
                if !args.is_empty() {
                    return arg_err!("isspace expects 0 arguments, got {}", args.len());
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_whitespace());
                Ok(QValue::Bool(QBool::new(result)))
            }
            // Query methods
            "count" => {
                if args.len() != 1 {
                    return arg_err!("count expects 1 argument, got {}", args.len());
                }
                let substring = args[0].as_str();
                let count = self.value.matches(&substring).count();
                Ok(QValue::Int(QInt::new(count as i64)))
            }
            "endswith" => {
                if args.len() != 1 {
                    return arg_err!("endswith expects 1 argument, got {}", args.len());
                }
                let suffix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.ends_with(&suffix))))
            }
            "startswith" => {
                if args.len() != 1 {
                    return arg_err!("startswith expects 1 argument, got {}", args.len());
                }
                let prefix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.starts_with(&prefix))))
            }
            "index_of" => {
                if args.len() != 1 {
                    return arg_err!("index_of expects 1 argument, got {}", args.len());
                }
                let substring = args[0].as_str();
                let index = self.value.find(&substring)
                    .map(|i| i as i64)
                    .unwrap_or(-1);
                Ok(QValue::Int(QInt::new(index)))
            }
            "contains" => {
                if args.len() != 1 {
                    return arg_err!("contains expects 1 argument, got {}", args.len());
                }
                let substring = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.contains(&substring))))
            }
            "starts_with" => {
                if args.len() != 1 {
                    return arg_err!("starts_with expects 1 argument, got {}", args.len());
                }
                let prefix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.starts_with(&prefix))))
            }
            "ends_with" => {
                if args.len() != 1 {
                    return arg_err!("ends_with expects 1 argument, got {}", args.len());
                }
                let suffix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.ends_with(&suffix))))
            }
            "isdecimal" => {
                if !args.is_empty() {
                    return arg_err!("isdecimal expects 0 arguments, got {}", args.len());
                }
                // In Python, isdecimal() checks if all characters are decimal characters (0-9)
                // This is stricter than isdigit() which also accepts superscript digits
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_ascii_digit());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "istitle" => {
                if !args.is_empty() {
                    return arg_err!("istitle expects 0 arguments, got {}", args.len());
                }
                // Title case: first letter of each word is uppercase, rest are lowercase
                // Words are separated by whitespace or non-alphabetic characters
                if self.value.is_empty() {
                    return Ok(QValue::Bool(QBool::new(false)));
                }

                let mut found_word = false;
                let mut prev_is_alpha = false;
                let mut is_title = true;

                for c in self.value.chars() {
                    if c.is_alphabetic() {
                        if !prev_is_alpha {
                            // Start of a word - must be uppercase
                            if !c.is_uppercase() {
                                is_title = false;
                                break;
                            }
                            found_word = true;
                        } else {
                            // Middle of a word - must be lowercase
                            if c.is_uppercase() {
                                is_title = false;
                                break;
                            }
                        }
                        prev_is_alpha = true;
                    } else {
                        prev_is_alpha = false;
                    }
                }

                Ok(QValue::Bool(QBool::new(is_title && found_word)))
            }
            "expandtabs" => {
                // expandtabs(tabsize=8) - replaces tabs with spaces
                let tabsize = if args.is_empty() {
                    8
                } else if args.len() == 1 {
                    args[0].as_num()? as usize
                } else {
                    return arg_err!("expandtabs expects 0 or 1 arguments, got {}", args.len());
                };

                let mut result = String::new();
                let mut column = 0;

                for c in self.value.chars() {
                    if c == '\t' {
                        // Calculate number of spaces to next tab stop
                        let spaces = tabsize - (column % tabsize);
                        result.push_str(&" ".repeat(spaces));
                        column += spaces;
                    } else if c == '\n' || c == '\r' {
                        result.push(c);
                        column = 0;
                    } else {
                        result.push(c);
                        column += 1;
                    }
                }

                Ok(QValue::Str(QString::new(result)))
            }
            "encode" => {
                // encode(encoding="utf-8") - returns encoded string
                let encoding = if args.is_empty() {
                    "utf-8"
                } else if args.len() == 1 {
                    &args[0].as_str()
                } else {
                    return arg_err!("encode expects 0 or 1 arguments, got {}", args.len());
                };

                match encoding {
                    "utf-8" | "utf8" => {
                        // Return a string representation of the bytes
                        let bytes: Vec<String> = self.value.bytes().map(|b| format!("{}", b)).collect();
                        let result = format!("[{}]", bytes.join(", "));
                        Ok(QValue::Str(QString::new(result)))
                    }
                    "hex" => {
                        // Return hex representation
                        let hex: String = self.value.bytes().map(|b| format!("{:02x}", b)).collect();
                        Ok(QValue::Str(QString::new(hex)))
                    }
                    "b64" | "base64" => {
                        // Return base64 encoded string
                        use base64::{Engine as _, engine::general_purpose};
                        let encoded = general_purpose::STANDARD.encode(self.value.as_bytes());
                        Ok(QValue::Str(QString::new(encoded)))
                    }
                    "b64url" | "base64url" => {
                        // Return URL-safe base64 encoded string
                        use base64::{Engine as _, engine::general_purpose};
                        let encoded = general_purpose::URL_SAFE_NO_PAD.encode(self.value.as_bytes());
                        Ok(QValue::Str(QString::new(encoded)))
                    }
                    _ => arg_err!("Unknown encoding: {}. Supported: utf-8, hex, b64, b64url", encoding)
                }
            }
            "decode" => {
                // decode(encoding) - decodes encoded string
                if args.len() != 1 {
                    return arg_err!("decode expects 1 argument (encoding), got {}", args.len());
                }
                let encoding = args[0].as_str();

                match encoding.as_str() {
                    "b64" | "base64" => {
                        use base64::{Engine as _, engine::general_purpose};
                        let decoded = general_purpose::STANDARD.decode(self.value.as_bytes())
                            .map_err(|e| format!("Base64 decode error: {}", e))?;
                        let decoded_str = String::from_utf8(decoded)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    "b64url" | "base64url" => {
                        use base64::{Engine as _, engine::general_purpose};
                        let decoded = general_purpose::URL_SAFE_NO_PAD.decode(self.value.as_bytes())
                            .map_err(|e| format!("Base64 decode error: {}", e))?;
                        let decoded_str = String::from_utf8(decoded)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    "hex" => {
                        // Decode hex string to regular string
                        let bytes: Result<Vec<u8>, _> = (0..self.value.len())
                            .step_by(2)
                            .map(|i| u8::from_str_radix(&self.value[i..i+2], 16))
                            .collect();
                        let bytes = bytes.map_err(|e| format!("Hex decode error: {}", e))?;
                        let decoded_str = String::from_utf8(bytes)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    _ => arg_err!("Unknown encoding: {}. Supported: b64, b64url, hex", encoding)
                }
            }
            "fmt" => {
                // Format string with positional arguments
                // Supports: {}, {0}, {1}, {:.2}, {0:.2}, etc.
                let mut result = String::new();
                let mut chars = self.value.chars().peekable();
                let mut arg_index = 0;

                while let Some(ch) = chars.next() {
                    if ch == '{' {
                        if chars.peek() == Some(&'{') {
                            // Escaped brace {{
                            chars.next();
                            result.push('{');
                        } else {
                            // Parse placeholder: {}, {0}, {:.2}, {0:.2}
                            let mut placeholder = String::new();
                            while let Some(&next_ch) = chars.peek() {
                                if next_ch == '}' {
                                    chars.next();
                                    break;
                                }
                                placeholder.push(next_ch);
                                chars.next();
                            }

                            // Parse placeholder: [index][:spec]
                            let (index, format_spec) = if let Some(colon_pos) = placeholder.find(':') {
                                let idx_str = &placeholder[..colon_pos];
                                let spec = &placeholder[colon_pos + 1..];
                                if idx_str.is_empty() {
                                    (arg_index, Some(spec))
                                } else {
                                    (idx_str.parse::<usize>().map_err(|_| format!("Invalid placeholder index: {}", idx_str))?, Some(spec))
                                }
                            } else if placeholder.is_empty() {
                                (arg_index, None)
                            } else {
                                (placeholder.parse::<usize>().map_err(|_| format!("Invalid placeholder index: {}", placeholder))?, None)
                            };

                            // Get the argument
                            if index >= args.len() {
                                return arg_err!("Placeholder index {} out of range (have {} args)", index, args.len());
                            }
                            let value = &args[index];

                            // Format the value
                            let formatted = if let Some(spec) = format_spec {
                                crate::string_utils::format_value(value, spec)?
                            } else {
                                value.as_str()
                            };
                            result.push_str(&formatted);

                            // Only auto-increment if it was an empty placeholder
                            if placeholder.is_empty() || (!placeholder.contains(':') && placeholder.parse::<usize>().is_ok()) {
                                arg_index += 1;
                            }
                        }
                    } else if ch == '}' {
                        if chars.peek() == Some(&'}') {
                            // Escaped brace }}
                            chars.next();
                            result.push('}');
                        } else {
                            result.push('}');
                        }
                    } else {
                        result.push(ch);
                    }
                }

                Ok(QValue::Str(QString::new(result)))
            }
            "hash" => {
                if args.len() != 1 {
                    return arg_err!("hash expects 1 argument (algorithm name), got {}", args.len());
                }
                let algorithm = args[0].as_str();

                use md5::{Md5, Digest};
                use sha1::Sha1;
                use sha2::{Sha256, Sha512};
                use crc32fast::Hasher as Crc32Hasher;

                let hash_result = match algorithm.as_str() {
                    "md5" => format!("{:x}", Md5::digest(self.value.as_bytes())),
                    "sha1" => format!("{:x}", Sha1::digest(self.value.as_bytes())),
                    "sha256" => format!("{:x}", Sha256::digest(self.value.as_bytes())),
                    "sha512" => format!("{:x}", Sha512::digest(self.value.as_bytes())),
                    "crc32" => {
                        let mut hasher = Crc32Hasher::new();
                        hasher.update(self.value.as_bytes());
                        format!("{:08x}", hasher.finalize())
                    }
                    _ => return arg_err!("Unknown hash algorithm '{}'. Supported: md5, sha1, sha256, sha512, crc32", algorithm),
                };
                Ok(QValue::Str(QString::new(hash_result)))
            }
            "str" => {
                if !args.is_empty() {
                    return arg_err!("_str expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.str())))
            }
            "_rep" => {
                if !args.is_empty() {
                    return arg_err!("_rep expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self._rep())))
            }
            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            "split" => {
                // Split string by delimiter, returns array of strings
                if args.len() != 1 {
                    return arg_err!("split expects 1 argument, got {}", args.len());
                }
                let delimiter = args[0].as_str();

                let parts: Vec<QValue> = if delimiter.is_empty() {
                    // Split into individual characters
                    self.value.chars()
                        .map(|c| QValue::Str(QString::new(c.to_string())))
                        .collect()
                } else {
                    self.value.split(&delimiter)
                        .map(|s| QValue::Str(QString::new(s.to_string())))
                        .collect()
                };

                Ok(QValue::Array(QArray::new(parts)))
            }
            "slice" => {
                // Return substring from start to end (exclusive)
                if args.len() != 2 {
                    return arg_err!("slice expects 2 arguments, got {}", args.len());
                }
                let start = args[0].as_num()? as i64;
                let end = args[1].as_num()? as i64;
                let len = self.value.chars().count() as i64;

                // Handle negative indices
                let actual_start = if start < 0 {
                    (len + start).max(0) as usize
                } else {
                    start.min(len) as usize
                };

                let actual_end = if end < 0 {
                    (len + end).max(0) as usize
                } else {
                    end.min(len) as usize
                };

                if actual_start > actual_end {
                    return Ok(QValue::Str(QString::new(String::new())));
                }

                // Use chars() to handle Unicode properly
                let result: String = self.value.chars()
                    .skip(actual_start)
                    .take(actual_end - actual_start)
                    .collect();

                Ok(QValue::Str(QString::new(result)))
            }
            "bytes" => {
                // Returns QBytes object from string's UTF-8 bytes
                if !args.is_empty() {
                    return arg_err!("bytes expects 0 arguments, got {}", args.len());
                }

                // Rust strings are always valid UTF-8, so this is guaranteed to work
                let bytes: Vec<u8> = self.value.bytes().collect();
                Ok(QValue::Bytes(QBytes::new(bytes)))
            }
            "replace" => {
                // Replace all occurrences of substring with replacement
                if args.len() != 2 {
                    return arg_err!("replace expects 2 arguments (old, new), got {}", args.len());
                }
                let old = args[0].as_str();
                let new = args[1].as_str();

                let result = self.value.replace(&old, &new);
                Ok(QValue::Str(QString::new(result)))
            }
            "to_int" => {
                // Convert string to integer
                // Supports decimal (default), hex (0x), binary (0b), octal (0o)
                if !args.is_empty() {
                    return arg_err!("to_int expects 0 arguments, got {}", args.len());
                }

                let trimmed = self.value.trim();

                // Parse with automatic base detection
                let parsed = if trimmed.starts_with("0x") || trimmed.starts_with("0X") {
                    // Hexadecimal
                    i64::from_str_radix(&trimmed[2..], 16)
                        .map_err(|e| format!("Invalid hexadecimal integer '{}': {}", self.value, e))
                } else if trimmed.starts_with("0b") || trimmed.starts_with("0B") {
                    // Binary
                    i64::from_str_radix(&trimmed[2..], 2)
                        .map_err(|e| format!("Invalid binary integer '{}': {}", self.value, e))
                } else if trimmed.starts_with("0o") || trimmed.starts_with("0O") {
                    // Octal
                    i64::from_str_radix(&trimmed[2..], 8)
                        .map_err(|e| format!("Invalid octal integer '{}': {}", self.value, e))
                } else {
                    // Decimal (with underscores allowed)
                    let cleaned = trimmed.replace('_', "");
                    cleaned.parse::<i64>()
                        .map_err(|e| format!("Invalid integer '{}': {}", self.value, e))
                }?;

                Ok(QValue::Int(QInt::new(parsed)))
            }
            "to_float" => {
                // Convert string to floating point number
                if !args.is_empty() {
                    return arg_err!("to_float expects 0 arguments, got {}", args.len());
                }

                let trimmed = self.value.trim();
                let cleaned = trimmed.replace('_', "");

                let parsed = cleaned.parse::<f64>()
                    .map_err(|e| format!("Invalid float '{}': {}", self.value, e))?;

                Ok(QValue::Float(QFloat::new(parsed)))
            }
            "to_decimal" => {
                // Convert string to arbitrary precision decimal
                if !args.is_empty() {
                    return arg_err!("to_decimal expects 0 arguments, got {}", args.len());
                }

                use rust_decimal::Decimal;
                let trimmed = self.value.trim();

                let parsed = Decimal::from_str(trimmed)
                    .map_err(|e| format!("Invalid decimal '{}': {}", self.value, e))?;

                Ok(QValue::Decimal(QDecimal::new(parsed)))
            }
            "to_bigint" => {
                // Convert string to arbitrary precision integer (BigInt)
                // Supports decimal (default), hex (0x), binary (0b), octal (0o)
                // Strips trailing 'n' if present
                if !args.is_empty() {
                    return arg_err!("to_bigint expects 0 arguments, got {}", args.len());
                }

                use num_bigint::BigInt;
                let trimmed = self.value.trim();

                // Strip trailing 'n' if present (for BigInt literal syntax compatibility)
                let cleaned = if trimmed.ends_with('n') {
                    &trimmed[..trimmed.len()-1]
                } else {
                    trimmed
                };

                // Parse with automatic base detection
                let parsed = if cleaned.starts_with("0x") || cleaned.starts_with("0X") {
                    // Hexadecimal
                    BigInt::from_str_radix(&cleaned[2..], 16)
                        .map_err(|e| format!("Invalid hexadecimal bigint '{}': {}", self.value, e))
                } else if cleaned.starts_with("0b") || cleaned.starts_with("0B") {
                    // Binary
                    BigInt::from_str_radix(&cleaned[2..], 2)
                        .map_err(|e| format!("Invalid binary bigint '{}': {}", self.value, e))
                } else if cleaned.starts_with("0o") || cleaned.starts_with("0O") {
                    // Octal
                    BigInt::from_str_radix(&cleaned[2..], 8)
                        .map_err(|e| format!("Invalid octal bigint '{}': {}", self.value, e))
                } else {
                    // Decimal (with underscores allowed)
                    let final_cleaned = cleaned.replace('_', "");
                    BigInt::from_str(&final_cleaned)
                        .map_err(|e| format!("Invalid bigint '{}': {}", self.value, e))
                }?;

                Ok(QValue::BigInt(QBigInt::new(parsed)))
            }
            "ord" => {
                // Get Unicode codepoint of first character
                if !args.is_empty() {
                    return arg_err!("ord expects 0 arguments, got {}", args.len());
                }

                let ch = self.value.chars().next()
                    .ok_or_else(|| "ord requires non-empty string".to_string())?;

                Ok(QValue::Int(QInt::new(ch as i64)))
            }
            "_url_decode" => {
                // URL-decode a string (e.g., "hello%20world" → "hello world")
                if !args.is_empty() {
                    return arg_err!("_url_decode expects 0 arguments, got {}", args.len());
                }

                let mut result = String::new();
                let bytes = self.value.as_bytes();
                let mut i = 0;

                while i < bytes.len() {
                    if bytes[i] == b'%' && i + 2 < bytes.len() {
                        // Try to parse hex escape
                        if let Ok(hex_str) = std::str::from_utf8(&bytes[i+1..i+3]) {
                            if let Ok(byte_val) = u8::from_str_radix(hex_str, 16) {
                                result.push(byte_val as char);
                                i += 3;
                                continue;
                            }
                        }
                    }

                    // Not a valid hex escape, just push the byte as-is
                    result.push(bytes[i] as char);
                    i += 1;
                }

                Ok(QValue::Str(QString::new(result)))
            }
            _ => attr_err!("Unknown method '{}' for str type", method_name),
        }
    }
}

impl QObj for QString {
    fn cls(&self) -> String {
        "Str".to_string()
    }

    fn q_type(&self) -> &'static str {
        "str"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "str" || type_name == "obj"
    }

    fn str(&self) -> String {
        self.value.as_ref().clone()
    }

    fn _rep(&self) -> String {
        // In REPL, show strings with quotes
        format!("\"{}\"", self.value)
    }

    fn _doc(&self) -> String {
        "String type - represents text".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QString {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Str", self.id);
    }
}
