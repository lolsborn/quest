use std::collections::HashMap;
use crate::types::*;

pub fn create_crypto_module() -> QValue {
    let mut members = HashMap::new();
    members.insert("hmac_sha256".to_string(), create_fn(
        "crypto",
        "hmac_sha256",
        "HMAC-SHA256: crypto.hmac_sha256(message, key) - Returns hex-encoded HMAC"
    ));
    members.insert("hmac_sha512".to_string(), create_fn(
        "crypto",
        "hmac_sha512",
        "HMAC-SHA512: crypto.hmac_sha512(message, key) - Returns hex-encoded HMAC"
    ));
    QValue::Module(QModule::new("crypto".to_string(), members))
}

/// Handle crypto.* function calls
pub fn call_crypto_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "crypto.hmac_sha256" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha256 expects 2 arguments (message, key), got {}", args.len()));
            }
            let message = args[0].as_str();
            let key = args[1].as_str();

            use hmac::{Hmac, Mac};
            use sha2::Sha256;
            type HmacSha256 = Hmac<Sha256>;

            let mut mac = HmacSha256::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(message.as_bytes());
            let result = mac.finalize();
            let code_bytes = result.into_bytes();

            Ok(QValue::Str(QString::new(format!("{:x}", code_bytes))))
        }
        "crypto.hmac_sha512" => {
            if args.len() != 2 {
                return Err(format!("hmac_sha512 expects 2 arguments (message, key), got {}", args.len()));
            }
            let message = args[0].as_str();
            let key = args[1].as_str();

            use hmac::{Hmac, Mac};
            use sha2::Sha512;
            type HmacSha512 = Hmac<Sha512>;

            let mut mac = HmacSha512::new_from_slice(key.as_bytes())
                .map_err(|e| format!("HMAC key error: {}", e))?;
            mac.update(message.as_bytes());
            let result = mac.finalize();
            let code_bytes = result.into_bytes();

            Ok(QValue::Str(QString::new(format!("{:x}", code_bytes))))
        }
        _ => Err(format!("Unknown crypto function: {}", func_name))
    }
}