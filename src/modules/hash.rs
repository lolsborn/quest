use std::collections::HashMap;
use crate::types::*;

pub fn create_hash_module() -> QValue {
    // Create a wrapper for hash functions
    fn create_hash_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "hash".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Cryptographic hash functions
    members.insert("md5".to_string(), create_hash_fn("md5", "Calculate MD5 hash"));
    members.insert("sha1".to_string(), create_hash_fn("sha1", "Calculate SHA-1 hash"));
    members.insert("sha256".to_string(), create_hash_fn("sha256", "Calculate SHA-256 hash"));
    members.insert("sha512".to_string(), create_hash_fn("sha512", "Calculate SHA-512 hash"));

    // HMAC functions
    members.insert("hmac_sha256".to_string(), create_hash_fn("hmac_sha256", "Calculate HMAC-SHA256"));
    members.insert("hmac_sha512".to_string(), create_hash_fn("hmac_sha512", "Calculate HMAC-SHA512"));

    // Non-cryptographic hash
    members.insert("crc32".to_string(), create_hash_fn("crc32", "Calculate CRC32 checksum"));

    QValue::Module(QModule::new("hash".to_string(), members))
}

/// Handle hash.* function calls
pub fn call_hash_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "hash.md5" => {
            if args.len() != 1 {
                return Err(format!("md5 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use md5::Digest;
            let hash = format!("{:x}", md5::Md5::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }

        "hash.sha1" => {
            if args.len() != 1 {
                return Err(format!("sha1 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha1::Digest;
            let hash = format!("{:x}", sha1::Sha1::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }

        "hash.sha256" => {
            if args.len() != 1 {
                return Err(format!("sha256 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", sha2::Sha256::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }

        "hash.sha512" => {
            if args.len() != 1 {
                return Err(format!("sha512 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use sha2::Digest;
            let hash = format!("{:x}", sha2::Sha512::digest(data.as_bytes()));
            Ok(QValue::Str(QString::new(hash)))
        }

        "hash.crc32" => {
            if args.len() != 1 {
                return Err(format!("crc32 expects 1 argument, got {}", args.len()));
            }
            let data = args[0].as_str();
            use crc32fast::Hasher as Crc32Hasher;
            let mut hasher = Crc32Hasher::new();
            hasher.update(data.as_bytes());
            let checksum = hasher.finalize();
            Ok(QValue::Str(QString::new(format!("{:08x}", checksum))))
        }

        _ => Err(format!("Unknown hash function: {}", func_name))
    }
}
