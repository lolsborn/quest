use crate::types::*;
use num_bigint::BigInt;
use num_traits::{Zero, One, Num};
use std::str::FromStr;
use std::collections::HashMap;

pub fn create_bigint_module() -> QValue {
    let mut members = HashMap::new();

    // Construction functions
    members.insert("new".to_string(), create_fn("bigint", "new"));
    members.insert("from_int".to_string(), create_fn("bigint", "from_int"));
    members.insert("from_bytes".to_string(), create_fn("bigint", "from_bytes"));

    // Constants
    members.insert("ZERO".to_string(), QValue::BigInt(QBigInt::new(BigInt::zero())));
    members.insert("ONE".to_string(), QValue::BigInt(QBigInt::new(BigInt::one())));
    members.insert("TWO".to_string(), QValue::BigInt(QBigInt::new(BigInt::from(2))));
    members.insert("TEN".to_string(), QValue::BigInt(QBigInt::new(BigInt::from(10))));

    QValue::Module(Box::new(QModule::new("bigint".to_string(), members)))
}

pub fn call_bigint_function(name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match name {
        "bigint.new" => {
            if args.len() != 1 {
                return Err(format!("bigint.new expects 1 argument, got {}", args.len()));
            }

            match &args[0] {
                QValue::Str(s) => {
                    // Parse string - supports decimal, hex (0x), binary (0b), octal (0o)
                    let value_str = s.value.as_ref();

                    let bigint = if let Some(hex_str) = value_str.strip_prefix("0x").or_else(|| value_str.strip_prefix("0X")) {
                        BigInt::from_str_radix(hex_str, 16)
                            .map_err(|e| format!("Invalid hex BigInt string '{}': {}", value_str, e))?
                    } else if let Some(bin_str) = value_str.strip_prefix("0b").or_else(|| value_str.strip_prefix("0B")) {
                        BigInt::from_str_radix(bin_str, 2)
                            .map_err(|e| format!("Invalid binary BigInt string '{}': {}", value_str, e))?
                    } else if let Some(oct_str) = value_str.strip_prefix("0o").or_else(|| value_str.strip_prefix("0O")) {
                        BigInt::from_str_radix(oct_str, 8)
                            .map_err(|e| format!("Invalid octal BigInt string '{}': {}", value_str, e))?
                    } else {
                        // Decimal
                        BigInt::from_str(value_str)
                            .map_err(|e| format!("Invalid BigInt string '{}': {}", value_str, e))?
                    };

                    Ok(QValue::BigInt(QBigInt::new(bigint)))
                }
                QValue::Int(n) => {
                    Ok(QValue::BigInt(QBigInt::new(BigInt::from(n.value))))
                }
                QValue::BigInt(b) => {
                    // Already a BigInt, just return a clone
                    Ok(QValue::BigInt(b.clone()))
                }
                _ => Err("bigint.new expects a string or int argument".to_string()),
            }
        }

        "bigint.from_int" => {
            if args.len() != 1 {
                return Err(format!("bigint.from_int expects 1 argument, got {}", args.len()));
            }

            match &args[0] {
                QValue::Int(n) => {
                    Ok(QValue::BigInt(QBigInt::new(BigInt::from(n.value))))
                }
                _ => Err("bigint.from_int expects an Int argument".to_string()),
            }
        }

        "bigint.from_bytes" => {
            if args.len() < 1 || args.len() > 2 {
                return Err(format!("bigint.from_bytes expects 1 or 2 arguments (bytes, signed?), got {}", args.len()));
            }

            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("bigint.from_bytes expects Bytes as first argument".to_string()),
            };

            let signed = if args.len() == 2 {
                match &args[1] {
                    QValue::Bool(b) => b.value,
                    _ => return Err("bigint.from_bytes expects Bool as second argument (signed)".to_string()),
                }
            } else {
                true  // Default to signed
            };

            let bigint = if signed {
                BigInt::from_signed_bytes_be(&bytes)
            } else {
                BigInt::from_bytes_be(num_bigint::Sign::Plus, &bytes)
            };

            Ok(QValue::BigInt(QBigInt::new(bigint)))
        }

        _ => Err(format!("Unknown bigint function: {}", name)),
    }
}
