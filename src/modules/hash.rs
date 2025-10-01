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
