use std::collections::HashMap;
use crate::control_flow::EvalError;
use crate::types::*;
use crate::{arg_err, attr_err};

pub fn create_hash_module() -> QValue {
    let mut members = HashMap::new();

    // Cryptographic hash functions
    members.insert("md5".to_string(), create_fn("hash", "md5"));
    members.insert("sha1".to_string(), create_fn("hash", "sha1"));
    members.insert("sha256".to_string(), create_fn("hash", "sha256"));
    members.insert("sha512".to_string(), create_fn("hash", "sha512"));

    // HMAC functions
    members.insert("hmac_sha256".to_string(), create_fn("hash", "hmac_sha256"));
    members.insert("hmac_sha512".to_string(), create_fn("hash", "hmac_sha512"));

    // Non-cryptographic hash
    members.insert("crc32".to_string(), create_fn("hash", "crc32"));

    QValue::Module(Box::new(QModule::new("hash".to_string(), members)))
}

/// Handle hash.* function calls
pub fn call_hash_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "hash.md5" => {
            if args.len() != 1 {
                return arg_err!("md5 expects 1 argument, got {}", args.len());
            }
            let data = args[0].as_str();
            use md5::Digest;
            let hash = format!("{:x}", md5::Md5::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha1" => {
            if args.len() != 1 {
                return arg_err!("sha1 expects 1 argument, got {}", args.len());
            }
            let data = args[0].as_str();
            use sha1::Digest;
            let hash = format!("{:x}", sha1::Sha1::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha256" => {
            if args.len() != 1 {
                return arg_err!("sha256 expects 1 argument, got {}", args.len());
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", sha2::Sha256::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.sha512" => {
            if args.len() != 1 {
                return arg_err!("sha512 expects 1 argument, got {}", args.len());
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", sha2::Sha512::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }
        "hash.crc32" => {
            if args.len() != 1 {
                return arg_err!("crc32 expects 1 argument, got {}", args.len());
            }
            let data = args[0].as_str();
            use crc32fast::Hasher as Crc32Hasher;
            let mut hasher = Crc32Hasher::new();
            hasher.update(data.as_bytes());
            let checksum = hasher.finalize();
            Ok(QValue::Str(QString::new(format!("{:08x}", checksum))))
        }
        _ => attr_err!("Unknown hash function: {}", func_name)
    }
}
