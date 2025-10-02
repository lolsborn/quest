use std::collections::HashMap;
use crate::types::*;

pub fn create_crypto_module() -> QValue {
    fn create_crypto_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "crypto".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    members.insert("hmac_sha256".to_string(), create_crypto_fn(
        "hmac_sha256",
        "HMAC-SHA256: crypto.hmac_sha256(message, key) - Returns hex-encoded HMAC"
    ));

    members.insert("hmac_sha512".to_string(), create_crypto_fn(
        "hmac_sha512",
        "HMAC-SHA512: crypto.hmac_sha512(message, key) - Returns hex-encoded HMAC"
    ));

    QValue::Module(QModule::new("crypto".to_string(), members))
}
