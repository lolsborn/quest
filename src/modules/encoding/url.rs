use std::collections::HashMap;
use crate::types::*;

pub fn create_url_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("encode".to_string(), create_fn("url", "encode"));
    members.insert("encode_component".to_string(), create_fn("url", "encode_component"));
    members.insert("encode_path".to_string(), create_fn("url", "encode_path"));
    members.insert("encode_query".to_string(), create_fn("url", "encode_query"));
    members.insert("decode".to_string(), create_fn("url", "decode"));
    members.insert("decode_component".to_string(), create_fn("url", "decode_component"));
    members.insert("build_query".to_string(), create_fn("url", "build_query"));
    members.insert("parse_query".to_string(), create_fn("url", "parse_query"));

    QValue::Module(QModule::new("url".to_string(), members))
}

pub fn call_url_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "url.encode" => url_encode(args, EncodeMode::Standard),
        "url.encode_component" => url_encode(args, EncodeMode::Component),
        "url.encode_path" => url_encode(args, EncodeMode::Path),
        "url.encode_query" => url_encode(args, EncodeMode::Query),
        "url.decode" => url_decode(args, true),
        "url.decode_component" => url_decode(args, false),
        "url.build_query" => url_build_query(args),
        "url.parse_query" => url_parse_query(args),
        _ => Err(format!("Unknown url function: {}", func_name))
    }
}

#[derive(Debug, Clone, Copy)]
enum EncodeMode {
    Standard,   // Encode for query values (all except alphanumeric and -_.~)
    Component,  // Stricter encoding
    Path,       // Preserve /
    Query,      // Preserve = and &
}

fn url_encode(args: Vec<QValue>, mode: EncodeMode) -> Result<QValue, String> {
    if args.len() != 1 {
        return Err(format!("encode expects 1 argument, got {}", args.len()));
    }

    let text = args[0].as_str();
    let encoded = percent_encode(&text, mode);

    Ok(QValue::Str(QString::new(encoded)))
}

fn percent_encode(text: &str, mode: EncodeMode) -> String {
    let mut result = String::new();

    for byte in text.bytes() {
        let should_encode = match mode {
            EncodeMode::Standard => {
                // RFC 3986 unreserved characters: A-Z a-z 0-9 - . _ ~
                !matches!(byte,
                    b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' |
                    b'-' | b'.' | b'_' | b'~'
                )
            }
            EncodeMode::Component => {
                // Unreserved + sub-delimiters: ! * ' ( )
                !matches!(byte,
                    b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' |
                    b'-' | b'.' | b'_' | b'~' |
                    b'!' | b'*' | b'\'' | b'(' | b')'
                )
            }
            EncodeMode::Path => {
                // Preserve path separator /
                !matches!(byte,
                    b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' |
                    b'-' | b'.' | b'_' | b'~' | b'/'
                )
            }
            EncodeMode::Query => {
                // Preserve query delimiters = and &
                !matches!(byte,
                    b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' |
                    b'-' | b'.' | b'_' | b'~' | b'=' | b'&'
                )
            }
        };

        if should_encode {
            result.push_str(&format!("%{:02X}", byte));
        } else {
            result.push(byte as char);
        }
    }

    result
}

fn url_decode(args: Vec<QValue>, plus_as_space: bool) -> Result<QValue, String> {
    if args.len() != 1 {
        return Err(format!("decode expects 1 argument, got {}", args.len()));
    }

    let text = args[0].as_str();
    let decoded = percent_decode(&text, plus_as_space)?;

    Ok(QValue::Str(QString::new(decoded)))
}

fn percent_decode(text: &str, plus_as_space: bool) -> Result<String, String> {
    let mut bytes = Vec::new();
    let mut chars = text.chars();

    while let Some(ch) = chars.next() {
        match ch {
            '%' => {
                // Read next two hex digits
                let high = chars.next()
                    .ok_or_else(|| "Invalid percent encoding: missing hex digit".to_string())?;
                let low = chars.next()
                    .ok_or_else(|| "Invalid percent encoding: missing hex digit".to_string())?;

                let high_val = hex_char_to_value(high)
                    .ok_or_else(|| format!("Invalid hex digit in percent encoding: '{}'", high))?;
                let low_val = hex_char_to_value(low)
                    .ok_or_else(|| format!("Invalid hex digit in percent encoding: '{}'", low))?;

                bytes.push((high_val << 4) | low_val);
            }
            '+' if plus_as_space => {
                bytes.push(b' ');
            }
            _ => {
                // Regular character - convert to bytes
                let mut buf = [0u8; 4];
                let char_bytes = ch.encode_utf8(&mut buf).as_bytes();
                bytes.extend_from_slice(char_bytes);
            }
        }
    }

    String::from_utf8(bytes)
        .map_err(|e| format!("Invalid UTF-8 in decoded string: {}", e))
}

fn hex_char_to_value(c: char) -> Option<u8> {
    match c {
        '0'..='9' => Some((c as u8) - b'0'),
        'a'..='f' => Some((c as u8) - b'a' + 10),
        'A'..='F' => Some((c as u8) - b'A' + 10),
        _ => None,
    }
}

fn url_build_query(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return Err(format!("build_query expects 1 argument, got {}", args.len()));
    }

    let dict = match &args[0] {
        QValue::Dict(d) => d,
        _ => return Err(format!("build_query expects Dict, got {}", args[0].as_obj().cls())),
    };

    let mut parts = Vec::new();

    for (key, value) in dict.map.iter() {
        let encoded_key = percent_encode(key, EncodeMode::Standard);
        let encoded_value = percent_encode(&value.as_str(), EncodeMode::Standard);
        parts.push(format!("{}={}", encoded_key, encoded_value));
    }

    Ok(QValue::Str(QString::new(parts.join("&"))))
}

fn url_parse_query(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return Err(format!("parse_query expects 1 argument, got {}", args.len()));
    }

    let query = args[0].as_str();

    // Strip leading ? if present
    let query = query.strip_prefix('?').unwrap_or(&query);

    let mut params = HashMap::new();

    // Split by &
    for pair in query.split('&') {
        if pair.is_empty() {
            continue;
        }

        // Split by =
        if let Some((key, value)) = pair.split_once('=') {
            let decoded_key = percent_decode(key, true)?;
            let decoded_value = percent_decode(value, true)?;
            params.insert(decoded_key, QValue::Str(QString::new(decoded_value)));
        } else {
            // Key without value
            let decoded_key = percent_decode(pair, true)?;
            params.insert(decoded_key, QValue::Str(QString::new(String::new())));
        }
    }

    Ok(QValue::Dict(QDict::new(params)))
}
