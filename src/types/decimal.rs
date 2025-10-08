use super::*;
use rust_decimal::Decimal;
use std::str::FromStr;
use crate::{arg_err, attr_err};

#[derive(Debug, Clone)]
pub struct QDecimal {
    pub value: Decimal,
    pub id: u64,
}

impl QDecimal {
    pub fn new(value: Decimal) -> Self {
        QDecimal {
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
                    return arg_err!("plus expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value + other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Decimal(QDecimal::new(self.value + other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value + other_dec)))
                    }
                    _ => Err("plus expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return arg_err!("minus expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value - other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Decimal(QDecimal::new(self.value - other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value - other_dec)))
                    }
                    _ => Err("minus expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return arg_err!("times expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value * other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Decimal(QDecimal::new(self.value * other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value * other_dec)))
                    }
                    _ => Err("times expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return arg_err!("div expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Decimal(QDecimal::new(self.value / other.value)))
                    }
                    QValue::Int(other) => {
                        if other.value == 0 {
                            return Err("Division by zero".to_string());
                        }
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Decimal(QDecimal::new(self.value / other_dec)))
                    }
                    QValue::Float(other) => {
                        if other.value == 0.0 {
                            return Err("Division by zero".to_string());
                        }
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value / other_dec)))
                    }
                    _ => Err("div expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return arg_err!("mod expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value % other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Decimal(QDecimal::new(self.value % other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value % other_dec)))
                    }
                    _ => Err("mod expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            // Comparison methods
            "eq" => {
                if args.len() != 1 {
                    return arg_err!("eq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value == other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value == other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value == other_dec)))
                    }
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "neq" => {
                if args.len() != 1 {
                    return arg_err!("neq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value != other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value != other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value != other_dec)))
                    }
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            "gt" => {
                if args.len() != 1 {
                    return arg_err!("gt expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value > other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value > other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value > other_dec)))
                    }
                    _ => Err("gt expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "lt" => {
                if args.len() != 1 {
                    return arg_err!("lt expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value < other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value < other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value < other_dec)))
                    }
                    _ => Err("lt expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "gte" => {
                if args.len() != 1 {
                    return arg_err!("gte expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value >= other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value >= other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value >= other_dec)))
                    }
                    _ => Err("gte expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            "lte" => {
                if args.len() != 1 {
                    return arg_err!("lte expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Bool(QBool::new(self.value <= other.value)))
                    }
                    QValue::Int(other) => {
                        let other_dec = Decimal::from(other.value);
                        Ok(QValue::Bool(QBool::new(self.value <= other_dec)))
                    }
                    QValue::Float(other) => {
                        let other_dec = Decimal::from_f64_retain(other.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Bool(QBool::new(self.value <= other_dec)))
                    }
                    _ => Err("lte expects a Decimal, Int, Float, or Num argument".to_string()),
                }
            }
            // Conversion methods
            "to_f64" => {
                if !args.is_empty() {
                    return arg_err!("to_f64 expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Float(QFloat::new(self.value.to_f64().unwrap_or(0.0))))
            }
            "to_string" => {
                if !args.is_empty() {
                    return arg_err!("to_string expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            // Number trait methods (aliases and additions)
            "add" => self.call_method("plus", args),
            "sub" => self.call_method("minus", args),
            "mul" => self.call_method("times", args),
            "pow" => {
                if args.len() != 1 {
                    return arg_err!("pow expects 1 argument, got {}", args.len());
                }
                // Decimal doesn't have native pow, convert to f64
                let exp = args[0].as_num()?;
                let result = self.value.to_f64().unwrap_or(0.0).powf(exp);
                Ok(QValue::Float(QFloat::new(result)))
            }
            "abs" => {
                if !args.is_empty() {
                    return arg_err!("abs expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(self.value.abs())))
            }
            "neg" => {
                if !args.is_empty() {
                    return arg_err!("neg expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(-self.value)))
            }
            "round" => {
                if !args.is_empty() {
                    return arg_err!("round expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(self.value.round())))
            }
            "floor" => {
                if !args.is_empty() {
                    return arg_err!("floor expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(self.value.floor())))
            }
            "ceil" => {
                if !args.is_empty() {
                    return arg_err!("ceil expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(self.value.ceil())))
            }
            "trunc" => {
                if !args.is_empty() {
                    return arg_err!("trunc expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Decimal(QDecimal::new(self.value.trunc())))
            }
            "sign" => {
                if !args.is_empty() {
                    return arg_err!("sign expects 0 arguments, got {}", args.len());
                }
                let sign = if self.value.is_sign_positive() && self.value != rust_decimal::Decimal::ZERO {
                    rust_decimal::Decimal::ONE
                } else if self.value.is_sign_negative() {
                    -rust_decimal::Decimal::ONE
                } else {
                    rust_decimal::Decimal::ZERO
                };
                Ok(QValue::Decimal(QDecimal::new(sign)))
            }
            "min" => {
                if args.len() != 1 {
                    return arg_err!("min expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value.min(other.value))))
                    }
                    _ => {
                        let other = args[0].as_num()?;
                        let other_dec = rust_decimal::Decimal::from_f64_retain(other)
                            .ok_or("Cannot convert to Decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value.min(other_dec))))
                    }
                }
            }
            "max" => {
                if args.len() != 1 {
                    return arg_err!("max expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Decimal(other) => {
                        Ok(QValue::Decimal(QDecimal::new(self.value.max(other.value))))
                    }
                    _ => {
                        let other = args[0].as_num()?;
                        let other_dec = rust_decimal::Decimal::from_f64_retain(other)
                            .ok_or("Cannot convert to Decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self.value.max(other_dec))))
                    }
                }
            }
            _ => attr_err!("Unknown method '{}' for decimal type", method_name),
        }
    }
}

impl QObj for QDecimal {
    fn cls(&self) -> String {
        "Decimal".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Decimal"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Decimal" || type_name == "obj"
    }

    fn str(&self) -> String {
        self.value.to_string()
    }

    fn _rep(&self) -> String {
        format!("Decimal({})", self.value)
    }

    fn _doc(&self) -> String {
        "Decimal type - arbitrary precision decimal number".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Create a QType for Decimal with static methods
pub fn create_decimal_type() -> QType {
    let qtype = QType::with_doc(
        "Decimal".to_string(),
        Vec::new(),
        Some("Arbitrary precision decimal number type".to_string())
    );

    // Note: Static methods are added via call_decimal_static_method function
    // since they need to be Rust functions, not QUserFun
    qtype
}

/// Call a static method on the Decimal type
pub fn call_decimal_static_method(method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match method_name {
        "new" => {
            if args.len() != 1 {
                return arg_err!("Decimal.new expects 1 argument, got {}", args.len());
            }

            match &args[0] {
                QValue::Str(s) => {
                    let decimal = Decimal::from_str(&s.value)
                        .map_err(|e| format!("Invalid decimal string '{}': {}", s.value, e))?;
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                QValue::Int(n) => {
                    let decimal = Decimal::from(n.value);
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                QValue::Float(n) => {
                    let decimal = Decimal::from_f64_retain(n.value)
                        .ok_or_else(|| format!("Cannot convert {} to decimal", n.value))?;
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                QValue::Decimal(d) => {
                    // Already a decimal, just return a clone
                    Ok(QValue::Decimal(d.clone()))
                }
                _ => Err("Decimal.new expects a string or number argument".to_string()),
            }
        }
        "from_f64" => {
            if args.len() != 1 {
                return arg_err!("Decimal.from_f64 expects 1 argument, got {}", args.len());
            }

            match &args[0] {
                QValue::Int(n) => {
                    let decimal = Decimal::from(n.value);
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                QValue::Float(n) => {
                    let decimal = Decimal::from_f64_retain(n.value)
                        .ok_or_else(|| format!("Cannot convert {} to decimal", n.value))?;
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                _ => Err("Decimal.from_f64 expects a number argument".to_string()),
            }
        }
        "zero" => {
            if !args.is_empty() {
                return arg_err!("Decimal.zero expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Decimal(QDecimal::new(Decimal::ZERO)))
        }
        "one" => {
            if !args.is_empty() {
                return arg_err!("Decimal.one expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Decimal(QDecimal::new(Decimal::ONE)))
        }
        _ => attr_err!("Unknown static method '{}' for Decimal type", method_name),
    }
}
