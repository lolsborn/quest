use std::collections::HashMap;
use crate::types::*;

pub fn create_struct_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("pack".to_string(), create_fn("struct", "pack"));
    members.insert("unpack".to_string(), create_fn("struct", "unpack"));
    members.insert("unpack_from".to_string(), create_fn("struct", "unpack_from"));
    members.insert("calcsize".to_string(), create_fn("struct", "calcsize"));
    members.insert("pack_into".to_string(), create_fn("struct", "pack_into"));

    QValue::Module(QModule::new("struct".to_string(), members))
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum ByteOrder {
    Native,
    NativeStandard,
    LittleEndian,
    BigEndian,
    Network,
}

#[derive(Debug, Clone)]
struct FormatChar {
    char: char,
    count: usize,
}

#[derive(Debug)]
struct Format {
    byte_order: ByteOrder,
    chars: Vec<FormatChar>,
}

impl Format {
    fn parse(format_str: &str) -> Result<Self, String> {
        if format_str.is_empty() {
            return Err("Format string cannot be empty".to_string());
        }

        let mut chars = format_str.chars().peekable();

        // Parse byte order prefix
        let byte_order = match chars.peek() {
            Some('@') => { chars.next(); ByteOrder::Native }
            Some('=') => { chars.next(); ByteOrder::NativeStandard }
            Some('<') => { chars.next(); ByteOrder::LittleEndian }
            Some('>') => { chars.next(); ByteOrder::BigEndian }
            Some('!') => { chars.next(); ByteOrder::Network }
            _ => ByteOrder::Native,
        };

        // Parse format characters with counts
        let mut format_chars = Vec::new();
        let mut current_count = String::new();

        while let Some(ch) = chars.next() {
            if ch.is_ascii_digit() {
                current_count.push(ch);
            } else {
                let count = if current_count.is_empty() {
                    1
                } else {
                    current_count.parse::<usize>()
                        .map_err(|_| format!("Invalid repeat count: {}", current_count))?
                };
                current_count.clear();

                // Validate format character
                if !is_valid_format_char(ch) {
                    return Err(format!("Invalid format character: '{}'", ch));
                }

                format_chars.push(FormatChar { char: ch, count });
            }
        }

        if !current_count.is_empty() {
            return Err("Format string ends with count but no format character".to_string());
        }

        Ok(Format {
            byte_order,
            chars: format_chars,
        })
    }

    fn calcsize(&self) -> usize {
        self.chars.iter().map(|fc| {
            let char_size = get_format_size(fc.char);
            char_size * fc.count
        }).sum()
    }
}

fn is_valid_format_char(ch: char) -> bool {
    matches!(ch, 'x' | 'c' | 'b' | 'B' | '?' | 'h' | 'H' | 'i' | 'I' | 'l' | 'L' | 'q' | 'Q' | 'f' | 'd' | 's' | 'p')
}

fn get_format_size(ch: char) -> usize {
    match ch {
        'x' | 'c' | 'b' | 'B' | '?' => 1,
        'h' | 'H' => 2,
        'i' | 'I' | 'l' | 'L' | 'f' => 4,
        'q' | 'Q' | 'd' => 8,
        's' | 'p' => 1, // Per-character, multiplied by count
        _ => 0,
    }
}

pub fn call_struct_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "struct.pack" => struct_pack(args),
        "struct.unpack" => struct_unpack(args),
        "struct.unpack_from" => struct_unpack_from(args),
        "struct.calcsize" => struct_calcsize(args),
        "struct.pack_into" => struct_pack_into(args),
        _ => Err(format!("Unknown struct function: {}", func_name))
    }
}

fn struct_calcsize(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return Err(format!("calcsize expects 1 argument, got {}", args.len()));
    }

    let format_str = args[0].as_str();
    let format = Format::parse(&format_str)?;
    let size = format.calcsize();

    Ok(QValue::Int(QInt::new(size as i64)))
}

fn struct_pack(args: Vec<QValue>) -> Result<QValue, String> {
    if args.is_empty() {
        return Err("pack expects at least 1 argument (format string)".to_string());
    }

    let format_str = args[0].as_str();
    let format = Format::parse(&format_str)?;
    let values = &args[1..];

    // Count expected values (excluding pad bytes)
    let expected_count: usize = format.chars.iter()
        .filter(|fc| fc.char != 'x')
        .map(|fc| if fc.char == 's' || fc.char == 'p' { 1 } else { fc.count })
        .sum();

    if values.len() != expected_count {
        return Err(format!(
            "pack expected {} values for format '{}', got {}",
            expected_count, format_str, values.len()
        ));
    }

    let mut buffer = Vec::new();
    let mut value_idx = 0;

    for fc in &format.chars {
        match fc.char {
            'x' => {
                // Pad bytes
                buffer.extend(vec![0u8; fc.count]);
            }
            's' => {
                // String (fixed length)
                let s = values[value_idx].as_str();
                let bytes = s.as_bytes();
                let len = fc.count;

                if bytes.len() > len {
                    buffer.extend_from_slice(&bytes[..len]);
                } else {
                    buffer.extend_from_slice(bytes);
                    buffer.extend(vec![0u8; len - bytes.len()]); // Pad with zeros
                }
                value_idx += 1;
            }
            'c' => {
                // Char (single byte from string)
                for _ in 0..fc.count {
                    let s = values[value_idx].as_str();
                    if s.len() != 1 {
                        return Err(format!("'c' format requires string of length 1, got {}", s.len()));
                    }
                    buffer.push(s.as_bytes()[0]);
                    value_idx += 1;
                }
            }
            '?' => {
                // Bool
                for _ in 0..fc.count {
                    let b = values[value_idx].as_bool();
                    buffer.push(if b { 1 } else { 0 });
                    value_idx += 1;
                }
            }
            _ => {
                // Numeric types
                for _ in 0..fc.count {
                    pack_numeric(&mut buffer, &values[value_idx], fc.char, format.byte_order)?;
                    value_idx += 1;
                }
            }
        }
    }

    Ok(QValue::Bytes(QBytes::new(buffer)))
}

fn extract_i64(value: &QValue) -> Result<i64, String> {
    match value {
        QValue::Int(i) => Ok(i.value),
        QValue::Float(f) => Ok(f.value as i64),
        _ => Err(format!("Expected Int or Float, got {}", value.as_obj().cls())),
    }
}

fn extract_f64(value: &QValue) -> Result<f64, String> {
    match value {
        QValue::Int(i) => Ok(i.value as f64),
        QValue::Float(f) => Ok(f.value),
        _ => Err(format!("Expected Int or Float, got {}", value.as_obj().cls())),
    }
}

fn pack_numeric(buffer: &mut Vec<u8>, value: &QValue, format_char: char, byte_order: ByteOrder) -> Result<(), String> {
    // Helper to determine if we should use little-endian
    let is_little_endian = match byte_order {
        ByteOrder::LittleEndian => true,
        ByteOrder::BigEndian | ByteOrder::Network => false,
        ByteOrder::Native | ByteOrder::NativeStandard => cfg!(target_endian = "little"),
    };

    match format_char {
        'b' => {
            // Signed byte
            let n = extract_i64(value)?;
            if n < -128 || n > 127 {
                return Err(format!("Value {} out of range for signed byte (-128 to 127)", n));
            }
            buffer.push(n as i8 as u8);
        }
        'B' => {
            // Unsigned byte
            let n = extract_i64(value)?;
            if n < 0 || n > 255 {
                return Err(format!("Value {} out of range for unsigned byte (0 to 255)", n));
            }
            buffer.push(n as u8);
        }
        'h' => {
            // Signed short (2 bytes)
            let n = extract_i64(value)?;
            if n < -32768 || n > 32767 {
                return Err(format!("Value {} out of range for signed short (-32768 to 32767)", n));
            }
            if is_little_endian {
                buffer.extend_from_slice(&(n as i16).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(n as i16).to_be_bytes());
            }
        }
        'H' => {
            // Unsigned short (2 bytes)
            let n = extract_i64(value)?;
            if n < 0 || n > 65535 {
                return Err(format!("Value {} out of range for unsigned short (0 to 65535)", n));
            }
            if is_little_endian {
                buffer.extend_from_slice(&(n as u16).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(n as u16).to_be_bytes());
            }
        }
        'i' | 'l' => {
            // Signed int (4 bytes)
            let n = extract_i64(value)?;
            if n < -2147483648 || n > 2147483647 {
                return Err(format!("Value {} out of range for signed int (-2147483648 to 2147483647)", n));
            }
            if is_little_endian {
                buffer.extend_from_slice(&(n as i32).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(n as i32).to_be_bytes());
            }
        }
        'I' | 'L' => {
            // Unsigned int (4 bytes)
            let n = extract_i64(value)?;
            if n < 0 || n > 4294967295 {
                return Err(format!("Value {} out of range for unsigned int (0 to 4294967295)", n));
            }
            if is_little_endian {
                buffer.extend_from_slice(&(n as u32).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(n as u32).to_be_bytes());
            }
        }
        'q' => {
            // Signed long long (8 bytes)
            let n = extract_i64(value)?;
            if is_little_endian {
                buffer.extend_from_slice(&n.to_le_bytes());
            } else {
                buffer.extend_from_slice(&n.to_be_bytes());
            }
        }
        'Q' => {
            // Unsigned long long (8 bytes)
            let n = extract_i64(value)?;
            if n < 0 {
                return Err(format!("Value {} cannot be negative for unsigned long long", n));
            }
            if is_little_endian {
                buffer.extend_from_slice(&(n as u64).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(n as u64).to_be_bytes());
            }
        }
        'f' => {
            // Float (4 bytes)
            let f = extract_f64(value)?;
            if is_little_endian {
                buffer.extend_from_slice(&(f as f32).to_le_bytes());
            } else {
                buffer.extend_from_slice(&(f as f32).to_be_bytes());
            }
        }
        'd' => {
            // Double (8 bytes)
            let f = extract_f64(value)?;
            if is_little_endian {
                buffer.extend_from_slice(&f.to_le_bytes());
            } else {
                buffer.extend_from_slice(&f.to_be_bytes());
            }
        }
        _ => {
            return Err(format!("Unsupported numeric format character: '{}'", format_char));
        }
    }

    Ok(())
}

fn struct_unpack(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 2 {
        return Err(format!("unpack expects 2 arguments, got {}", args.len()));
    }

    let format_str = args[0].as_str();
    let data = match &args[1] {
        QValue::Bytes(b) => b.data.clone(),
        _ => return Err("unpack expects Bytes as second argument".to_string()),
    };

    unpack_data(&format_str, &data, 0)
}

fn struct_unpack_from(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 3 {
        return Err(format!("unpack_from expects 3 arguments, got {}", args.len()));
    }

    let format_str = args[0].as_str();
    let data = match &args[1] {
        QValue::Bytes(b) => b.data.clone(),
        _ => return Err("unpack_from expects Bytes as second argument".to_string()),
    };
    let offset = extract_i64(&args[2])?;
    if offset < 0 {
        return Err("Offset cannot be negative".to_string());
    }

    unpack_data(&format_str, &data, offset as usize)
}

fn unpack_data(format_str: &str, data: &[u8], offset: usize) -> Result<QValue, String> {
    let format = Format::parse(format_str)?;
    let required_size = format.calcsize();

    if offset + required_size > data.len() {
        return Err(format!(
            "unpack requires {} bytes, but only {} bytes available from offset {}",
            required_size,
            data.len() - offset,
            offset
        ));
    }

    let data = &data[offset..];
    let mut values = Vec::new();
    let mut byte_idx = 0;

    for fc in &format.chars {
        match fc.char {
            'x' => {
                // Skip pad bytes
                byte_idx += fc.count;
            }
            's' => {
                // String (fixed length)
                let bytes = &data[byte_idx..byte_idx + fc.count];
                // Find null terminator or use full length
                let end = bytes.iter().position(|&b| b == 0).unwrap_or(bytes.len());
                let s = String::from_utf8_lossy(&bytes[..end]).to_string();
                values.push(QValue::Str(QString::new(s)));
                byte_idx += fc.count;
            }
            'c' => {
                // Char (single byte as string)
                for _ in 0..fc.count {
                    let ch = data[byte_idx] as char;
                    values.push(QValue::Str(QString::new(ch.to_string())));
                    byte_idx += 1;
                }
            }
            '?' => {
                // Bool
                for _ in 0..fc.count {
                    let b = data[byte_idx] != 0;
                    values.push(QValue::Bool(QBool::new(b)));
                    byte_idx += 1;
                }
            }
            _ => {
                // Numeric types
                for _ in 0..fc.count {
                    let value = unpack_numeric(data, &mut byte_idx, fc.char, format.byte_order)?;
                    values.push(value);
                }
            }
        }
    }

    Ok(QValue::Array(QArray::new(values)))
}

fn unpack_numeric(data: &[u8], byte_idx: &mut usize, format_char: char, byte_order: ByteOrder) -> Result<QValue, String> {
    let is_little_endian = match byte_order {
        ByteOrder::LittleEndian => true,
        ByteOrder::BigEndian | ByteOrder::Network => false,
        ByteOrder::Native | ByteOrder::NativeStandard => cfg!(target_endian = "little"),
    };

    let result = match format_char {
        'b' => {
            let val = data[*byte_idx] as i8;
            *byte_idx += 1;
            QValue::Int(QInt::new(val as i64))
        }
        'B' => {
            let val = data[*byte_idx];
            *byte_idx += 1;
            QValue::Int(QInt::new(val as i64))
        }
        'h' => {
            let bytes = &data[*byte_idx..*byte_idx + 2];
            let val = if is_little_endian {
                i16::from_le_bytes([bytes[0], bytes[1]])
            } else {
                i16::from_be_bytes([bytes[0], bytes[1]])
            };
            *byte_idx += 2;
            QValue::Int(QInt::new(val as i64))
        }
        'H' => {
            let bytes = &data[*byte_idx..*byte_idx + 2];
            let val = if is_little_endian {
                u16::from_le_bytes([bytes[0], bytes[1]])
            } else {
                u16::from_be_bytes([bytes[0], bytes[1]])
            };
            *byte_idx += 2;
            QValue::Int(QInt::new(val as i64))
        }
        'i' | 'l' => {
            let bytes = &data[*byte_idx..*byte_idx + 4];
            let val = if is_little_endian {
                i32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            } else {
                i32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            };
            *byte_idx += 4;
            QValue::Int(QInt::new(val as i64))
        }
        'I' | 'L' => {
            let bytes = &data[*byte_idx..*byte_idx + 4];
            let val = if is_little_endian {
                u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            } else {
                u32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            };
            *byte_idx += 4;
            QValue::Int(QInt::new(val as i64))
        }
        'q' => {
            let bytes = &data[*byte_idx..*byte_idx + 8];
            let val = if is_little_endian {
                i64::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            } else {
                i64::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            };
            *byte_idx += 8;
            QValue::Int(QInt::new(val))
        }
        'Q' => {
            let bytes = &data[*byte_idx..*byte_idx + 8];
            let val = if is_little_endian {
                u64::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            } else {
                u64::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            };
            *byte_idx += 8;
            // Note: This could overflow i64, but we're limited by QValue::Int using i64
            QValue::Int(QInt::new(val as i64))
        }
        'f' => {
            let bytes = &data[*byte_idx..*byte_idx + 4];
            let val = if is_little_endian {
                f32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            } else {
                f32::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3]])
            };
            *byte_idx += 4;
            QValue::Float(QFloat::new(val as f64))
        }
        'd' => {
            let bytes = &data[*byte_idx..*byte_idx + 8];
            let val = if is_little_endian {
                f64::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            } else {
                f64::from_be_bytes([bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7]])
            };
            *byte_idx += 8;
            QValue::Float(QFloat::new(val))
        }
        _ => {
            return Err(format!("Unsupported numeric format character: '{}'", format_char));
        }
    };

    Ok(result)
}

fn struct_pack_into(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() < 3 {
        return Err(format!("pack_into expects at least 3 arguments, got {}", args.len()));
    }

    let _format_str = args[0].as_str();
    match &args[1] {
        QValue::Bytes(_) => return Err("pack_into buffer modification not yet implemented (bytes are immutable)".to_string()),
        _ => return Err("pack_into expects Bytes as second argument".to_string()),
    }
}
