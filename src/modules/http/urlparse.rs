// URL Parsing Module - Python urllib.parse inspired
// Provides URL parsing, encoding, and manipulation functions

use crate::types::*;
use crate::Scope;
use std::collections::HashMap;
use urlparse::{urlparse as parse_url, quote, unquote, Url};

/// Create the urlparse module
pub fn create_urlparse_module() -> QValue {
    let mut members = HashMap::new();

    // URL parsing
    members.insert("urlparse".to_string(), create_fn("urlparse", "urlparse"));
    members.insert("urljoin".to_string(), create_fn("urlparse", "urljoin"));

    // Query string handling
    members.insert("parse_qs".to_string(), create_fn("urlparse", "parse_qs"));
    members.insert("parse_qsl".to_string(), create_fn("urlparse", "parse_qsl"));
    members.insert("urlencode".to_string(), create_fn("urlparse", "urlencode"));

    // URL encoding/decoding
    members.insert("quote".to_string(), create_fn("urlparse", "quote"));
    members.insert("quote_plus".to_string(), create_fn("urlparse", "quote_plus"));
    members.insert("unquote".to_string(), create_fn("urlparse", "unquote"));
    members.insert("unquote_plus".to_string(), create_fn("urlparse", "unquote_plus"));

    QValue::Module(Box::new(QModule::new("urlparse".to_string(), members)))
}

/// Handle urlparse.* function calls
pub fn call_urlparse_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "urlparse.urlparse" => {
            // Parse URL into components (scheme, netloc, path, params, query, fragment)
            if args.is_empty() || args.len() > 2 {
                return Err(format!("urlparse expects 1-2 arguments (url, [scheme]), got {}", args.len()));
            }

            let url_str = args[0].as_str();
            let _default_scheme = if args.len() == 2 {
                Some(args[1].as_str())
            } else {
                None
            };

            // Use the urlparse crate
            let parsed = parse_url(&url_str);

            let mut result = HashMap::new();
            result.insert("scheme".to_string(), QValue::Str(QString::new(parsed.scheme)));
            result.insert("netloc".to_string(), QValue::Str(QString::new(parsed.netloc)));
            result.insert("path".to_string(), QValue::Str(QString::new(parsed.path)));
            result.insert("params".to_string(), QValue::Str(QString::new(String::new()))); // urlparse crate doesn't separate params
            result.insert("query".to_string(), QValue::Str(QString::new(parsed.query.unwrap_or_default())));
            result.insert("fragment".to_string(), QValue::Str(QString::new(parsed.fragment.unwrap_or_default())));

            // Add convenience fields
            if let Some(host) = &parsed.hostname {
                result.insert("hostname".to_string(), QValue::Str(QString::new(host.clone())));
            } else {
                result.insert("hostname".to_string(), QValue::Nil(QNil));
            }

            if let Some(port) = parsed.port {
                result.insert("port".to_string(), QValue::Int(QInt::new(port as i64)));
            } else {
                result.insert("port".to_string(), QValue::Nil(QNil));
            }

            if let Some(username) = &parsed.username {
                result.insert("username".to_string(), QValue::Str(QString::new(username.clone())));
            } else {
                result.insert("username".to_string(), QValue::Nil(QNil));
            }

            if let Some(password) = &parsed.password {
                result.insert("password".to_string(), QValue::Str(QString::new(password.clone())));
            } else {
                result.insert("password".to_string(), QValue::Nil(QNil));
            }

            Ok(QValue::Dict(Box::new(QDict::new(result))))
        }

        "urlparse.urljoin" => {
            // Join a base URL with a relative URL
            if args.len() != 2 {
                return Err(format!("urljoin expects 2 arguments (base, url), got {}", args.len()));
            }

            let base = args[0].as_str();
            let relative = args[1].as_str();

            // Parse base URL
            let base_parsed = parse_url(&base);
            let base_url = Url {
                scheme: base_parsed.scheme,
                username: base_parsed.username,
                password: base_parsed.password,
                hostname: base_parsed.hostname,
                port: base_parsed.port,
                netloc: base_parsed.netloc,
                path: base_parsed.path,
                query: base_parsed.query,
                fragment: base_parsed.fragment,
            };

            // Simple join logic
            let joined = if relative.starts_with("http://") || relative.starts_with("https://") {
                // Absolute URL - use as-is
                relative.to_string()
            } else if relative.starts_with("/") {
                // Absolute path - replace path
                let scheme = if base_url.scheme.is_empty() { "http" } else { &base_url.scheme };
                let netloc = &base_url.netloc;
                format!("{}://{}{}", scheme, netloc, relative)
            } else {
                // Relative path - join with base path
                let scheme = if base_url.scheme.is_empty() { "http" } else { &base_url.scheme };
                let netloc = &base_url.netloc;
                let base_path = if base_url.path.is_empty() { "/" } else { &base_url.path };

                // Remove last segment of base path
                let mut path_parts: Vec<&str> = base_path.split('/').collect();
                if path_parts.len() > 1 {
                    path_parts.pop();
                }
                path_parts.push(&relative);
                let joined_path = path_parts.join("/");

                format!("{}://{}{}", scheme, netloc, joined_path)
            };

            Ok(QValue::Str(QString::new(joined)))
        }

        "urlparse.parse_qs" => {
            // Parse query string into dict of arrays
            if args.is_empty() || args.len() > 2 {
                return Err(format!("parse_qs expects 1-2 arguments (qs, [keep_blank_values]), got {}", args.len()));
            }

            let qs = args[0].as_str();
            let _keep_blank = if args.len() == 2 { args[1].as_bool() } else { false };

            let mut result = HashMap::new();

            for pair in qs.split('&') {
                if let Some((key, value)) = pair.split_once('=') {
                    let decoded_key = unquote(key).map_err(|e| format!("Failed to decode key: {}", e))?;
                    let decoded_value = unquote(value).map_err(|e| format!("Failed to decode value: {}", e))?;

                    // Add to array for this key
                    result.entry(decoded_key.clone())
                        .or_insert_with(Vec::new)
                        .push(QValue::Str(QString::new(decoded_value)));
                }
            }

            // Convert to Quest dict of arrays
            let quest_dict: HashMap<String, QValue> = result.into_iter()
                .map(|(k, v)| (k, QValue::Array(QArray::new(v))))
                .collect();

            Ok(QValue::Dict(Box::new(QDict::new(quest_dict))))
        }

        "urlparse.parse_qsl" => {
            // Parse query string into array of [key, value] pairs
            if args.is_empty() || args.len() > 2 {
                return Err(format!("parse_qsl expects 1-2 arguments (qs, [keep_blank_values]), got {}", args.len()));
            }

            let qs = args[0].as_str();
            let mut pairs = Vec::new();

            for pair in qs.split('&') {
                if let Some((key, value)) = pair.split_once('=') {
                    let decoded_key = unquote(key).map_err(|e| format!("Failed to decode key: {}", e))?;
                    let decoded_value = unquote(value).map_err(|e| format!("Failed to decode value: {}", e))?;

                    pairs.push(QValue::Array(QArray::new(vec![
                        QValue::Str(QString::new(decoded_key)),
                        QValue::Str(QString::new(decoded_value)),
                    ])));
                }
            }

            Ok(QValue::Array(QArray::new(pairs)))
        }

        "urlparse.urlencode" => {
            // Encode dict or array of pairs to query string
            if args.len() != 1 {
                return Err(format!("urlencode expects 1 argument (dict or array), got {}", args.len()));
            }

            let mut pairs = Vec::new();

            match &args[0] {
                QValue::Dict(dict) => {
                    // Dict -> query string
                    for (key, value) in &dict.as_ref().map {
                        let value_str = value.as_str();
                        let encoded_key = quote(&key, b"").map_err(|e| format!("Failed to encode key: {}", e))?;
                        let encoded_value = quote(&value_str, b"").map_err(|e| format!("Failed to encode value: {}", e))?;
                        pairs.push(format!("{}={}", encoded_key, encoded_value));
                    }
                }
                QValue::Array(arr) => {
                    // Array of [key, value] pairs -> query string
                    for pair in arr.elements.borrow().iter() {
                        if let QValue::Array(kv) = pair {
                            let elements = kv.elements.borrow();
                            if elements.len() == 2 {
                                let key = elements[0].as_str();
                                let value = elements[1].as_str();
                                let encoded_key = quote(&key, b"").map_err(|e| format!("Failed to encode key: {}", e))?;
                                let encoded_value = quote(&value, b"").map_err(|e| format!("Failed to encode value: {}", e))?;
                                pairs.push(format!("{}={}", encoded_key, encoded_value));
                            }
                        }
                    }
                }
                _ => return Err("urlencode expects dict or array of [key, value] pairs".to_string()),
            }

            Ok(QValue::Str(QString::new(pairs.join("&"))))
        }

        "urlparse.quote" => {
            // Percent-encode string
            if args.is_empty() || args.len() > 2 {
                return Err(format!("quote expects 1-2 arguments (string, [safe]), got {}", args.len()));
            }

            let string = args[0].as_str();
            let safe_str;
            let safe = if args.len() == 2 {
                safe_str = args[1].as_str();
                safe_str.as_bytes()
            } else {
                b"/"
            };

            let encoded = quote(&string, safe).map_err(|e| format!("Failed to quote: {}", e))?;
            Ok(QValue::Str(QString::new(encoded)))
        }

        "urlparse.quote_plus" => {
            // Percent-encode string, converting spaces to +
            if args.len() != 1 {
                return Err(format!("quote_plus expects 1 argument, got {}", args.len()));
            }

            let string = args[0].as_str();
            let encoded = quote(&string, b"").map_err(|e| format!("Failed to quote: {}", e))?;
            let with_plus = encoded.replace("%20", "+");
            Ok(QValue::Str(QString::new(with_plus)))
        }

        "urlparse.unquote" => {
            // Decode percent-encoded string
            if args.len() != 1 {
                return Err(format!("unquote expects 1 argument, got {}", args.len()));
            }

            let string = args[0].as_str();
            let decoded = unquote(&string).map_err(|e| format!("Failed to unquote: {}", e))?;
            Ok(QValue::Str(QString::new(decoded)))
        }

        "urlparse.unquote_plus" => {
            // Decode percent-encoded string, converting + to spaces
            if args.len() != 1 {
                return Err(format!("unquote_plus expects 1 argument, got {}", args.len()));
            }

            let string = args[0].as_str();
            let with_spaces = string.replace("+", " ");
            let decoded = unquote(&with_spaces).map_err(|e| format!("Failed to unquote: {}", e))?;
            Ok(QValue::Str(QString::new(decoded)))
        }

        _ => Err(format!("Unknown urlparse function: {}", func_name))
    }
}
