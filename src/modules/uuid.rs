use crate::types::{QValue, QUuid, QModule, QFun, next_object_id};
use crate::scope::Scope;
use std::collections::HashMap;
use uuid::{Uuid, Timestamp};
use std::time::{SystemTime, UNIX_EPOCH};

/// Create the uuid module with all functions
pub fn create_uuid_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("v4".to_string(), QValue::Fun(QFun {
        name: "v4".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v7".to_string(), QValue::Fun(QFun {
        name: "v7".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("nil_uuid".to_string(), QValue::Fun(QFun {
        name: "nil_uuid".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("parse".to_string(), QValue::Fun(QFun {
        name: "parse".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("from_bytes".to_string(), QValue::Fun(QFun {
        name: "from_bytes".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v1".to_string(), QValue::Fun(QFun {
        name: "v1".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v3".to_string(), QValue::Fun(QFun {
        name: "v3".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v5".to_string(), QValue::Fun(QFun {
        name: "v5".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v6".to_string(), QValue::Fun(QFun {
        name: "v6".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    members.insert("v8".to_string(), QValue::Fun(QFun {
        name: "v8".to_string(),
        parent_type: "uuid".to_string(),
        id: next_object_id(),
    }));

    // Add namespace constants
    members.insert("NAMESPACE_DNS".to_string(), QValue::Uuid(QUuid::new(Uuid::NAMESPACE_DNS)));
    members.insert("NAMESPACE_URL".to_string(), QValue::Uuid(QUuid::new(Uuid::NAMESPACE_URL)));
    members.insert("NAMESPACE_OID".to_string(), QValue::Uuid(QUuid::new(Uuid::NAMESPACE_OID)));
    members.insert("NAMESPACE_X500".to_string(), QValue::Uuid(QUuid::new(Uuid::NAMESPACE_X500)));

    QValue::Module(QModule::new("uuid".to_string(), members))
}

/// Call uuid module functions
pub fn call_uuid_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "uuid.v4" => {
            if !args.is_empty() {
                return Err(format!("uuid.v4 expects 0 arguments, got {}", args.len()));
            }
            let uuid = Uuid::new_v4();
            Ok(QValue::Uuid(QUuid::new(uuid)))
        }

        "uuid.v7" => {
            if !args.is_empty() {
                return Err(format!("uuid.v7 expects 0 arguments, got {}", args.len()));
            }
            let uuid = Uuid::now_v7();
            Ok(QValue::Uuid(QUuid::new(uuid)))
        }

        "uuid.nil_uuid" => {
            if !args.is_empty() {
                return Err(format!("uuid.nil_uuid expects 0 arguments, got {}", args.len()));
            }
            Ok(QValue::Uuid(QUuid::new(Uuid::nil())))
        }

        "uuid.parse" => {
            if args.len() != 1 {
                return Err(format!("uuid.parse expects 1 argument (string), got {}", args.len()));
            }
            let s = args[0].as_str();
            QUuid::from_string(&s).map(|u| QValue::Uuid(u))
        }

        "uuid.from_bytes" => {
            if args.len() != 1 {
                return Err(format!("uuid.from_bytes expects 1 argument (bytes), got {}", args.len()));
            }
            match &args[0] {
                QValue::Bytes(b) => {
                    if b.data.len() != 16 {
                        return Err(format!("UUID requires exactly 16 bytes, got {}", b.data.len()));
                    }
                    let mut bytes = [0u8; 16];
                    bytes.copy_from_slice(&b.data);
                    Ok(QValue::Uuid(QUuid::new(Uuid::from_bytes(bytes))))
                }
                _ => Err("uuid.from_bytes expects a Bytes argument".to_string())
            }
        }

        "uuid.v1" => {
            // v1 takes optional node_id (6 bytes) - if not provided, generate random
            let node_id = if args.is_empty() {
                // Generate random node ID
                let mut node = [0u8; 6];
                use rand::Rng;
                rand::thread_rng().fill(&mut node);
                node
            } else if args.len() == 1 {
                match &args[0] {
                    QValue::Bytes(b) => {
                        if b.data.len() != 6 {
                            return Err(format!("uuid.v1 node_id must be exactly 6 bytes, got {}", b.data.len()));
                        }
                        let mut node = [0u8; 6];
                        node.copy_from_slice(&b.data);
                        node
                    }
                    _ => return Err("uuid.v1 expects Bytes argument for node_id".to_string())
                }
            } else {
                return Err(format!("uuid.v1 expects 0 or 1 argument (optional node_id bytes), got {}", args.len()));
            };

            // Create timestamp from current time
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(|e| format!("System time error: {}", e))?;

            let ts = Timestamp::from_unix(
                uuid::NoContext,
                now.as_secs(),
                now.subsec_nanos()
            );

            Ok(QValue::Uuid(QUuid::new(Uuid::new_v1(ts, &node_id))))
        }

        "uuid.v3" => {
            // v3 takes namespace UUID and name string/bytes
            if args.len() != 2 {
                return Err(format!("uuid.v3 expects 2 arguments (namespace, name), got {}", args.len()));
            }

            let namespace = match &args[0] {
                QValue::Uuid(u) => &u.value,
                _ => return Err("uuid.v3 expects first argument to be a Uuid (namespace)".to_string())
            };

            let name_bytes = match &args[1] {
                QValue::Str(s) => s.value.as_bytes(),
                QValue::Bytes(b) => &b.data[..],
                _ => return Err("uuid.v3 expects second argument to be a Str or Bytes (name)".to_string())
            };

            Ok(QValue::Uuid(QUuid::new(Uuid::new_v3(namespace, name_bytes))))
        }

        "uuid.v5" => {
            // v5 takes namespace UUID and name string/bytes
            if args.len() != 2 {
                return Err(format!("uuid.v5 expects 2 arguments (namespace, name), got {}", args.len()));
            }

            let namespace = match &args[0] {
                QValue::Uuid(u) => &u.value,
                _ => return Err("uuid.v5 expects first argument to be a Uuid (namespace)".to_string())
            };

            let name_bytes = match &args[1] {
                QValue::Str(s) => s.value.as_bytes(),
                QValue::Bytes(b) => &b.data[..],
                _ => return Err("uuid.v5 expects second argument to be a Str or Bytes (name)".to_string())
            };

            Ok(QValue::Uuid(QUuid::new(Uuid::new_v5(namespace, name_bytes))))
        }

        "uuid.v6" => {
            // v6 takes optional node_id (6 bytes) - if not provided, generate random
            let node_id = if args.is_empty() {
                // Generate random node ID
                let mut node = [0u8; 6];
                use rand::Rng;
                rand::thread_rng().fill(&mut node);
                node
            } else if args.len() == 1 {
                match &args[0] {
                    QValue::Bytes(b) => {
                        if b.data.len() != 6 {
                            return Err(format!("uuid.v6 node_id must be exactly 6 bytes, got {}", b.data.len()));
                        }
                        let mut node = [0u8; 6];
                        node.copy_from_slice(&b.data);
                        node
                    }
                    _ => return Err("uuid.v6 expects Bytes argument for node_id".to_string())
                }
            } else {
                return Err(format!("uuid.v6 expects 0 or 1 argument (optional node_id bytes), got {}", args.len()));
            };

            // Create timestamp from current time
            let now = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .map_err(|e| format!("System time error: {}", e))?;

            let ts = Timestamp::from_unix(
                uuid::NoContext,
                now.as_secs(),
                now.subsec_nanos()
            );

            Ok(QValue::Uuid(QUuid::new(Uuid::new_v6(ts, &node_id))))
        }

        "uuid.v8" => {
            // v8 takes 16 bytes of custom data
            if args.len() != 1 {
                return Err(format!("uuid.v8 expects 1 argument (16 bytes), got {}", args.len()));
            }

            match &args[0] {
                QValue::Bytes(b) => {
                    if b.data.len() != 16 {
                        return Err(format!("uuid.v8 requires exactly 16 bytes, got {}", b.data.len()));
                    }
                    let mut buf = [0u8; 16];
                    buf.copy_from_slice(&b.data);
                    Ok(QValue::Uuid(QUuid::new(Uuid::new_v8(buf))))
                }
                _ => Err("uuid.v8 expects a Bytes argument".to_string())
            }
        }

        _ => Err(format!("Unknown function: {}", func_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_uuid_v4_generates_valid_uuid() {
        let mut scope = Scope::new();
        let result = call_uuid_function("uuid.v4", vec![], &mut scope);
        assert!(result.is_ok());
        match result.unwrap() {
            QValue::Uuid(_) => {},
            _ => panic!("Expected Uuid value"),
        }
    }

    #[test]
    fn test_uuid_nil_creates_nil_uuid() {
        let mut scope = Scope::new();
        let result = call_uuid_function("uuid.nil_uuid", vec![], &mut scope);
        assert!(result.is_ok());
        match result.unwrap() {
            QValue::Uuid(u) => {
                assert!(u.value.is_nil());
            }
            _ => panic!("Expected Uuid value"),
        }
    }

    #[test]
    fn test_uuid_parse_valid_string() {
        use crate::types::QString;
        let mut scope = Scope::new();
        let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
        let result = call_uuid_function("uuid.parse", vec![QValue::Str(QString::new(uuid_str.to_string()))], &mut scope);
        assert!(result.is_ok());
    }

    #[test]
    fn test_uuid_parse_invalid_string() {
        use crate::types::QString;
        let mut scope = Scope::new();
        let result = call_uuid_function("uuid.parse", vec![QValue::Str(QString::new("invalid".to_string()))], &mut scope);
        assert!(result.is_err());
    }
}
