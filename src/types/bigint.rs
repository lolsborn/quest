use super::*;
use crate::{arg_err, attr_err};
use num_bigint::BigInt;
use num_traits::{Zero, ToPrimitive, Signed, Num};
use num_integer::Integer;
use std::str::FromStr;

#[derive(Debug, Clone)]
pub struct QBigInt {
    pub value: BigInt,
    pub id: u64,
}

impl QBigInt {
    pub fn new(value: BigInt) -> Self {
        QBigInt {
            value,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            // Arithmetic methods
            "plus" => {
                if args.len() != 1 {
                    return arg_err!("plus expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value + &other.value)))
                    }
                    _ => Err("plus expects a BigInt argument".into()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return arg_err!("minus expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value - &other.value)))
                    }
                    _ => Err("minus expects a BigInt argument".into()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return arg_err!("times expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value * &other.value)))
                    }
                    _ => Err("times expects a BigInt argument".into()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return arg_err!("div expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".into());
                        }
                        Ok(QValue::BigInt(QBigInt::new(&self.value / &other.value)))
                    }
                    _ => Err("div expects a BigInt argument".into()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return arg_err!("mod expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Modulo by zero".into());
                        }
                        Ok(QValue::BigInt(QBigInt::new(&self.value % &other.value)))
                    }
                    _ => Err("mod expects a BigInt argument".into()),
                }
            }
            "abs" => {
                if !args.is_empty() {
                    return arg_err!("abs expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::BigInt(QBigInt::new(self.value.abs())))
            }
            "negate" => {
                if !args.is_empty() {
                    return arg_err!("negate expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::BigInt(QBigInt::new(-&self.value)))
            }

            // Comparison methods
            "equals" => {
                if args.len() != 1 {
                    return arg_err!("equals expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value == other.value))),
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "not_equals" => {
                if args.len() != 1 {
                    return arg_err!("not_equals expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value != other.value))),
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            "less_than" => {
                if args.len() != 1 {
                    return arg_err!("less_than expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value < other.value))),
                    _ => Err("less_than expects a BigInt argument".into()),
                }
            }
            "less_equal" => {
                if args.len() != 1 {
                    return arg_err!("less_equal expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value <= other.value))),
                    _ => Err("less_equal expects a BigInt argument".into()),
                }
            }
            "greater" => {
                if args.len() != 1 {
                    return arg_err!("greater expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value > other.value))),
                    _ => Err("greater expects a BigInt argument".into()),
                }
            }
            "greater_equal" => {
                if args.len() != 1 {
                    return arg_err!("greater_equal expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value >= other.value))),
                    _ => Err("greater_equal expects a BigInt argument".into()),
                }
            }

            // Conversion methods
            "to_int" => {
                if !args.is_empty() {
                    return arg_err!("to_int expects 0 arguments, got {}", args.len());
                }
                match self.value.to_i64() {
                    Some(val) => Ok(QValue::Int(QInt::new(val))),
                    None => Err("BigInt value too large to fit in Int (i64 range)".into()),
                }
            }
            "to_float" => {
                if !args.is_empty() {
                    return arg_err!("to_float expects 0 arguments, got {}", args.len());
                }
                match self.value.to_f64() {
                    Some(val) => Ok(QValue::Float(QFloat::new(val))),
                    None => Err("BigInt value cannot be represented as Float".into()),
                }
            }
            "to_string" => {
                let base = if args.is_empty() {
                    10
                } else if args.len() == 1 {
                    match &args[0] {
                        QValue::Int(i) => {
                            let b = i.value;
                            if b < 2 || b > 36 {
                                return Err("Base must be between 2 and 36".into());
                            }
                            b as u32
                        }
                        _ => return Err("to_string expects optional Int argument for base".into()),
                    }
                } else {
                    return arg_err!("to_string expects 0 or 1 arguments, got {}", args.len());
                };

                if base == 10 {
                    Ok(QValue::Str(QString::new(self.value.to_string())))
                } else {
                    use num_bigint::Sign;
                    let (sign, digits) = self.value.to_radix_be(base);
                    let sign_str = if sign == Sign::Minus { "-" } else { "" };
                    let digits_str = digits.iter()
                        .map(|&d| std::char::from_digit(d as u32, base).unwrap())
                        .collect::<String>();
                    Ok(QValue::Str(QString::new(format!("{}{}", sign_str, digits_str))))
                }
            }

            // Utility methods
            "is_zero" => {
                if !args.is_empty() {
                    return arg_err!("is_zero expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_zero())))
            }
            "is_positive" => {
                if !args.is_empty() {
                    return arg_err!("is_positive expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_positive())))
            }
            "is_negative" => {
                if !args.is_empty() {
                    return arg_err!("is_negative expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_negative())))
            }
            "is_even" => {
                if !args.is_empty() {
                    return arg_err!("is_even expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_even())))
            }
            "is_odd" => {
                if !args.is_empty() {
                    return arg_err!("is_odd expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.value.is_odd())))
            }
            "bit_length" => {
                if !args.is_empty() {
                    return arg_err!("bit_length expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.value.bits() as i64)))
            }

            // More arithmetic
            "pow" => {
                if args.is_empty() || args.len() > 2 {
                    return arg_err!("pow expects 1 or 2 arguments (exponent, modulus?), got {}", args.len());
                }

                let exponent = match &args[0] {
                    QValue::BigInt(e) => &e.value,
                    _ => return Err("pow expects BigInt exponent".into()),
                };

                if exponent.is_negative() {
                    return Err("pow exponent must be non-negative".into());
                }

                if args.len() == 2 {
                    // Modular exponentiation - supports arbitrarily large exponents
                    let modulus = match &args[1] {
                        QValue::BigInt(m) => &m.value,
                        _ => return Err("pow modulus must be BigInt".into()),
                    };
                    let result = self.value.modpow(exponent, modulus);
                    Ok(QValue::BigInt(QBigInt::new(result)))
                } else {
                    // Regular exponentiation - limited to u32 exponents for practical reasons
                    // (computing 2^(2^32) would require more memory than exists)
                    let exp_u32 = exponent.to_u32()
                        .ok_or_else(|| format!("Regular pow exponent too large (max: {}). For large exponents, use modular exponentiation: pow(exp, modulus)", u32::MAX))?;

                    use num_traits::pow::Pow;
                    let result = Pow::pow(&self.value, exp_u32);
                    Ok(QValue::BigInt(QBigInt::new(result)))
                }
            }

            "divmod" => {
                if args.len() != 1 {
                    return arg_err!("divmod expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".into());
                        }
                        let quotient = &self.value / &other.value;
                        let remainder = &self.value % &other.value;
                        Ok(QValue::Array(QArray::new(vec![
                            QValue::BigInt(QBigInt::new(quotient)),
                            QValue::BigInt(QBigInt::new(remainder)),
                        ])))
                    }
                    _ => Err("divmod expects a BigInt argument".into()),
                }
            }

            // Bitwise operations
            "bit_and" => {
                if args.len() != 1 {
                    return arg_err!("bit_and expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value & &other.value)))
                    }
                    _ => Err("bit_and expects a BigInt argument".into()),
                }
            }
            "bit_or" => {
                if args.len() != 1 {
                    return arg_err!("bit_or expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value | &other.value)))
                    }
                    _ => Err("bit_or expects a BigInt argument".into()),
                }
            }
            "bit_xor" => {
                if args.len() != 1 {
                    return arg_err!("bit_xor expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value ^ &other.value)))
                    }
                    _ => Err("bit_xor expects a BigInt argument".into()),
                }
            }
            "bit_not" => {
                if !args.is_empty() {
                    return arg_err!("bit_not expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::BigInt(QBigInt::new(!&self.value)))
            }
            "shl" => {
                if args.len() != 1 {
                    return arg_err!("shl expects 1 argument, got {}", args.len());
                }
                let n = match &args[0] {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            return Err("shift amount must be non-negative".into());
                        }
                        usize::try_from(i.value)
                            .map_err(|_| "shift amount too large for platform".to_string())?
                    }
                    _ => return Err("shl expects Int argument".into()),
                };
                Ok(QValue::BigInt(QBigInt::new(&self.value << n)))
            }
            "shr" => {
                if args.len() != 1 {
                    return arg_err!("shr expects 1 argument, got {}", args.len());
                }
                let n = match &args[0] {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            return Err("shift amount must be non-negative".into());
                        }
                        usize::try_from(i.value)
                            .map_err(|_| "shift amount too large for platform".to_string())?
                    }
                    _ => return Err("shr expects Int argument".into()),
                };
                Ok(QValue::BigInt(QBigInt::new(&self.value >> n)))
            }

            // Additional conversion
            "to_bytes" => {
                let signed = if args.is_empty() {
                    true
                } else if args.len() == 1 {
                    match &args[0] {
                        QValue::Bool(b) => b.value,
                        _ => return Err("to_bytes expects optional Bool argument (signed)".into()),
                    }
                } else {
                    return arg_err!("to_bytes expects 0 or 1 arguments, got {}", args.len());
                };

                let bytes_vec = if signed {
                    self.value.to_signed_bytes_be()
                } else {
                    self.value.to_bytes_be().1  // (Sign, Vec<u8>) - take just the bytes
                };

                Ok(QValue::Bytes(QBytes::new(bytes_vec)))
            }

            _ => attr_err!("Unknown method '{}' on BigInt", method_name),
        }
    }
}

impl QObj for QBigInt {
    fn cls(&self) -> String {
        "BigInt".to_string()
    }

    fn q_type(&self) -> &'static str {
        "BigInt"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "BigInt"
    }

    fn str(&self) -> String {
        self.value.to_string()
    }

    fn _rep(&self) -> String {
        format!("BigInt({})", self.value)
    }

    fn _doc(&self) -> String {
        "Arbitrary precision integer from std/bigint module".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Create a QType for BigInt with static methods and constants
pub fn create_bigint_type() -> QType {
    let qtype = QType::with_doc(
        "BigInt".to_string(),
        Vec::new(),
        Some("Arbitrary precision integer type".to_string())
    );

    // Note: Static methods are added via call_bigint_static_method function
    // Constants (ZERO, ONE, TWO, TEN) are added in scope initialization
    qtype
}

/// Call a static method on the BigInt type
pub fn call_bigint_static_method(method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
    match method_name {
        "new" => {
            if args.len() != 1 {
                return arg_err!("BigInt.new expects 1 argument, got {}", args.len());
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
                _ => Err("BigInt.new expects a string or int argument".into()),
            }
        }

        "from_int" => {
            if args.len() != 1 {
                return arg_err!("BigInt.from_int expects 1 argument, got {}", args.len());
            }

            match &args[0] {
                QValue::Int(n) => {
                    Ok(QValue::BigInt(QBigInt::new(BigInt::from(n.value))))
                }
                _ => Err("BigInt.from_int expects an Int argument".into()),
            }
        }

        "from_bytes" => {
            if args.len() < 1 || args.len() > 2 {
                return arg_err!("BigInt.from_bytes expects 1 or 2 arguments (bytes, signed?), got {}", args.len());
            }

            let bytes = match &args[0] {
                QValue::Bytes(b) => b.data.clone(),
                _ => return Err("BigInt.from_bytes expects Bytes as first argument".into()),
            };

            let signed = if args.len() == 2 {
                match &args[1] {
                    QValue::Bool(b) => b.value,
                    _ => return Err("BigInt.from_bytes expects Bool as second argument (signed)".into()),
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

        // Constants as static properties (actually methods that return values)
        "ZERO" => {
            if !args.is_empty() {
                return arg_err!("BigInt.ZERO expects 0 arguments, got {}", args.len());
            }
            use num_traits::Zero;
            Ok(QValue::BigInt(QBigInt::new(BigInt::zero())))
        }

        "ONE" => {
            if !args.is_empty() {
                return arg_err!("BigInt.ONE expects 0 arguments, got {}", args.len());
            }
            use num_traits::One;
            Ok(QValue::BigInt(QBigInt::new(BigInt::one())))
        }

        "TWO" => {
            if !args.is_empty() {
                return arg_err!("BigInt.TWO expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::BigInt(QBigInt::new(BigInt::from(2))))
        }

        "TEN" => {
            if !args.is_empty() {
                return arg_err!("BigInt.TEN expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::BigInt(QBigInt::new(BigInt::from(10))))
        }

        _ => attr_err!("Unknown static method '{}' for BigInt type", method_name),
    }
}
