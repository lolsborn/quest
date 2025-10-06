use super::*;
use num_bigint::BigInt;
use num_traits::{Zero, ToPrimitive, Signed};
use num_integer::Integer;

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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            // Arithmetic methods
            "plus" => {
                if args.len() != 1 {
                    return Err(format!("plus expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value + &other.value)))
                    }
                    _ => Err("plus expects a BigInt argument".to_string()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return Err(format!("minus expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value - &other.value)))
                    }
                    _ => Err("minus expects a BigInt argument".to_string()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return Err(format!("times expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value * &other.value)))
                    }
                    _ => Err("times expects a BigInt argument".to_string()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return Err(format!("div expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::BigInt(QBigInt::new(&self.value / &other.value)))
                    }
                    _ => Err("div expects a BigInt argument".to_string()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return Err(format!("mod expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Modulo by zero".to_string());
                        }
                        Ok(QValue::BigInt(QBigInt::new(&self.value % &other.value)))
                    }
                    _ => Err("mod expects a BigInt argument".to_string()),
                }
            }
            "abs" => {
                if !args.is_empty() {
                    return Err(format!("abs expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::BigInt(QBigInt::new(self.value.abs())))
            }
            "negate" => {
                if !args.is_empty() {
                    return Err(format!("negate expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::BigInt(QBigInt::new(-&self.value)))
            }

            // Comparison methods
            "equals" => {
                if args.len() != 1 {
                    return Err(format!("equals expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value == other.value))),
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "not_equals" => {
                if args.len() != 1 {
                    return Err(format!("not_equals expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value != other.value))),
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            "less_than" => {
                if args.len() != 1 {
                    return Err(format!("less_than expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value < other.value))),
                    _ => Err("less_than expects a BigInt argument".to_string()),
                }
            }
            "less_equal" => {
                if args.len() != 1 {
                    return Err(format!("less_equal expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value <= other.value))),
                    _ => Err("less_equal expects a BigInt argument".to_string()),
                }
            }
            "greater" => {
                if args.len() != 1 {
                    return Err(format!("greater expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value > other.value))),
                    _ => Err("greater expects a BigInt argument".to_string()),
                }
            }
            "greater_equal" => {
                if args.len() != 1 {
                    return Err(format!("greater_equal expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => Ok(QValue::Bool(QBool::new(self.value >= other.value))),
                    _ => Err("greater_equal expects a BigInt argument".to_string()),
                }
            }

            // Conversion methods
            "to_int" => {
                if !args.is_empty() {
                    return Err(format!("to_int expects 0 arguments, got {}", args.len()));
                }
                match self.value.to_i64() {
                    Some(val) => Ok(QValue::Int(QInt::new(val))),
                    None => Err("BigInt value too large to fit in Int (i64 range)".to_string()),
                }
            }
            "to_float" => {
                if !args.is_empty() {
                    return Err(format!("to_float expects 0 arguments, got {}", args.len()));
                }
                match self.value.to_f64() {
                    Some(val) => Ok(QValue::Float(QFloat::new(val))),
                    None => Err("BigInt value cannot be represented as Float".to_string()),
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
                                return Err("Base must be between 2 and 36".to_string());
                            }
                            b as u32
                        }
                        _ => return Err("to_string expects optional Int argument for base".to_string()),
                    }
                } else {
                    return Err(format!("to_string expects 0 or 1 arguments, got {}", args.len()));
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
                    return Err(format!("is_zero expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.value.is_zero())))
            }
            "is_positive" => {
                if !args.is_empty() {
                    return Err(format!("is_positive expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.value.is_positive())))
            }
            "is_negative" => {
                if !args.is_empty() {
                    return Err(format!("is_negative expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.value.is_negative())))
            }
            "is_even" => {
                if !args.is_empty() {
                    return Err(format!("is_even expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.value.is_even())))
            }
            "is_odd" => {
                if !args.is_empty() {
                    return Err(format!("is_odd expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.value.is_odd())))
            }
            "bit_length" => {
                if !args.is_empty() {
                    return Err(format!("bit_length expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value.bits() as i64)))
            }

            // More arithmetic
            "pow" => {
                if args.is_empty() || args.len() > 2 {
                    return Err(format!("pow expects 1 or 2 arguments (exponent, modulus?), got {}", args.len()));
                }

                let exponent = match &args[0] {
                    QValue::BigInt(e) => &e.value,
                    _ => return Err("pow expects BigInt exponent".to_string()),
                };

                if exponent.is_negative() {
                    return Err("pow exponent must be non-negative".to_string());
                }

                if args.len() == 2 {
                    // Modular exponentiation - supports arbitrarily large exponents
                    let modulus = match &args[1] {
                        QValue::BigInt(m) => &m.value,
                        _ => return Err("pow modulus must be BigInt".to_string()),
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
                    return Err(format!("divmod expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".to_string());
                        }
                        let quotient = &self.value / &other.value;
                        let remainder = &self.value % &other.value;
                        Ok(QValue::Array(QArray::new(vec![
                            QValue::BigInt(QBigInt::new(quotient)),
                            QValue::BigInt(QBigInt::new(remainder)),
                        ])))
                    }
                    _ => Err("divmod expects a BigInt argument".to_string()),
                }
            }

            // Bitwise operations
            "bit_and" => {
                if args.len() != 1 {
                    return Err(format!("bit_and expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value & &other.value)))
                    }
                    _ => Err("bit_and expects a BigInt argument".to_string()),
                }
            }
            "bit_or" => {
                if args.len() != 1 {
                    return Err(format!("bit_or expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value | &other.value)))
                    }
                    _ => Err("bit_or expects a BigInt argument".to_string()),
                }
            }
            "bit_xor" => {
                if args.len() != 1 {
                    return Err(format!("bit_xor expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::BigInt(other) => {
                        Ok(QValue::BigInt(QBigInt::new(&self.value ^ &other.value)))
                    }
                    _ => Err("bit_xor expects a BigInt argument".to_string()),
                }
            }
            "bit_not" => {
                if !args.is_empty() {
                    return Err(format!("bit_not expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::BigInt(QBigInt::new(!&self.value)))
            }
            "shl" => {
                if args.len() != 1 {
                    return Err(format!("shl expects 1 argument, got {}", args.len()));
                }
                let n = match &args[0] {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            return Err("shift amount must be non-negative".to_string());
                        }
                        usize::try_from(i.value)
                            .map_err(|_| "shift amount too large for platform".to_string())?
                    }
                    _ => return Err("shl expects Int argument".to_string()),
                };
                Ok(QValue::BigInt(QBigInt::new(&self.value << n)))
            }
            "shr" => {
                if args.len() != 1 {
                    return Err(format!("shr expects 1 argument, got {}", args.len()));
                }
                let n = match &args[0] {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            return Err("shift amount must be non-negative".to_string());
                        }
                        usize::try_from(i.value)
                            .map_err(|_| "shift amount too large for platform".to_string())?
                    }
                    _ => return Err("shr expects Int argument".to_string()),
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
                        _ => return Err("to_bytes expects optional Bool argument (signed)".to_string()),
                    }
                } else {
                    return Err(format!("to_bytes expects 0 or 1 arguments, got {}", args.len()));
                };

                let bytes_vec = if signed {
                    self.value.to_signed_bytes_be()
                } else {
                    self.value.to_bytes_be().1  // (Sign, Vec<u8>) - take just the bytes
                };

                Ok(QValue::Bytes(QBytes::new(bytes_vec)))
            }

            _ => Err(format!("Unknown method '{}' on BigInt", method_name)),
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

    fn _str(&self) -> String {
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
