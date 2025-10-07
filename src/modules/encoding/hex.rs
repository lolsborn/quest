use std::collections::HashMap;
use crate::{arg_err, attr_err, value_err};
use crate::types::*;

pub fn create_hex_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("encode".to_string(), create_fn("hex", "encode"));
    members.insert("encode_upper".to_string(), create_fn("hex", "encode_upper"));
    members.insert("encode_with_sep".to_string(), create_fn("hex", "encode_with_sep"));
    members.insert("decode".to_string(), create_fn("hex", "decode"));
    members.insert("is_valid".to_string(), create_fn("hex", "is_valid"));

    QValue::Module(Box::new(QModule::new("hex".to_string(), members)))
}

pub fn call_hex_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "hex.encode" => hex_encode(args, false),
        "hex.encode_upper" => hex_encode(args, true),
        "hex.encode_with_sep" => hex_encode_with_sep(args),
        "hex.decode" => hex_decode(args),
        "hex.is_valid" => hex_is_valid(args),
        _ => attr_err!("Unknown hex function: {}", func_name)
    }
}

fn hex_encode(args: Vec<QValue>, uppercase: bool) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("encode expects 1 argument, got {}", args.len());
    }

    let bytes = match &args[0] {
        QValue::Bytes(b) => &b.data,
        _ => return value_err!("encode expects Bytes, got {}", args[0].as_obj().cls()),
    };

    let hex_str = if uppercase {
        bytes.iter().map(|b| format!("{:02X}", b)).collect::<String>()
    } else {
        bytes.iter().map(|b| format!("{:02x}", b)).collect::<String>()
    };

    Ok(QValue::Str(QString::new(hex_str)))
}

fn hex_encode_with_sep(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 2 {
        return arg_err!("encode_with_sep expects 2 arguments, got {}", args.len());
    }

    let bytes = match &args[0] {
        QValue::Bytes(b) => &b.data,
        _ => return value_err!("encode_with_sep expects Bytes as first argument, got {}", args[0].as_obj().cls()),
    };

    let separator = args[1].as_str();

    let hex_parts: Vec<String> = bytes.iter().map(|b| format!("{:02x}", b)).collect();
    let hex_str = hex_parts.join(&separator);

    Ok(QValue::Str(QString::new(hex_str)))
}

fn hex_decode(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("decode expects 1 argument, got {}", args.len());
    }

    let hex_str = args[0].as_str();

    // Remove common separators and whitespace
    let cleaned: String = hex_str.chars()
        .filter(|c| !matches!(c, ':' | '-' | ' ' | '\t' | '\n' | '\r'))
        .collect();

    // Check for odd number of hex digits
    if cleaned.len() % 2 != 0 {
        return value_err!("Invalid hex string: odd number of hex digits ({})", cleaned.len());
    }

    // Decode hex string to bytes
    let mut bytes = Vec::new();
    let mut chars = cleaned.chars();

    while let (Some(high), Some(low)) = (chars.next(), chars.next()) {
        let high_val = hex_char_to_value(high)
            .ok_or_else(|| format!("Invalid hex character: '{}'", high))?;
        let low_val = hex_char_to_value(low)
            .ok_or_else(|| format!("Invalid hex character: '{}'", low))?;

        bytes.push((high_val << 4) | low_val);
    }

    Ok(QValue::Bytes(QBytes::new(bytes)))
}

fn hex_is_valid(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("is_valid expects 1 argument, got {}", args.len());
    }

    let hex_str = args[0].as_str();

    // Remove common separators and whitespace
    let cleaned: String = hex_str.chars()
        .filter(|c| !matches!(c, ':' | '-' | ' ' | '\t' | '\n' | '\r'))
        .collect();

    // Check for even number of hex digits
    if cleaned.len() % 2 != 0 {
        return Ok(QValue::Bool(QBool::new(false)));
    }

    // Check all characters are valid hex
    let is_valid = cleaned.chars().all(|c| hex_char_to_value(c).is_some());

    Ok(QValue::Bool(QBool::new(is_valid)))
}

fn hex_char_to_value(c: char) -> Option<u8> {
    match c {
        '0'..='9' => Some((c as u8) - b'0'),
        'a'..='f' => Some((c as u8) - b'a' + 10),
        'A'..='F' => Some((c as u8) - b'A' + 10),
        _ => None,
    }
}
