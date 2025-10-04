use crate::types::{QValue, QObj, QNum, QInt, QDecimal, QString, next_object_id, try_call_qobj_method};

#[derive(Debug, Clone)]
pub struct QFloat {
    pub value: f64,
    pub id: u64,
}

impl QFloat {
    pub fn new(value: f64) -> Self {
        QFloat {
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
            "plus" => {
                if args.len() != 1 {
                    return Err(format!("plus expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value + other.value)))
                    }
                    QValue::Int(other) => {
                        // Float + Int = Float
                        Ok(QValue::Float(QFloat::new(self.value + other.value as f64)))
                    }
                    QValue::Num(other) => {
                        // Float + Num = Float
                        Ok(QValue::Float(QFloat::new(self.value + other.value)))
                    }
                    QValue::Decimal(other) => {
                        // Float + Decimal = Decimal (promote to higher precision)
                        let self_decimal = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self_decimal + other.value)))
                    }
                    _ => Err("plus expects a numeric argument".to_string()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return Err(format!("minus expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value - other.value)))
                    }
                    QValue::Int(other) => {
                        Ok(QValue::Float(QFloat::new(self.value - other.value as f64)))
                    }
                    QValue::Num(other) => {
                        Ok(QValue::Float(QFloat::new(self.value - other.value)))
                    }
                    QValue::Decimal(other) => {
                        let self_decimal = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self_decimal - other.value)))
                    }
                    _ => Err("minus expects a numeric argument".to_string()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return Err(format!("times expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value * other.value)))
                    }
                    QValue::Int(other) => {
                        Ok(QValue::Float(QFloat::new(self.value * other.value as f64)))
                    }
                    QValue::Num(other) => {
                        Ok(QValue::Float(QFloat::new(self.value * other.value)))
                    }
                    QValue::Decimal(other) => {
                        let self_decimal = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self_decimal * other.value)))
                    }
                    _ => Err("times expects a numeric argument".to_string()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return Err(format!("div expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Float(other) => {
                        if other.value == 0.0 {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value / other.value)))
                    }
                    QValue::Int(other) => {
                        if other.value == 0 {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value / other.value as f64)))
                    }
                    QValue::Num(other) => {
                        if other.value == 0.0 {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value / other.value)))
                    }
                    QValue::Decimal(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".to_string());
                        }
                        let self_decimal = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self_decimal / other.value)))
                    }
                    _ => Err("div expects a numeric argument".to_string()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return Err(format!("mod expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Float(other) => {
                        if other.value == 0.0 {
                            return Err("Modulo by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value % other.value)))
                    }
                    QValue::Int(other) => {
                        if other.value == 0 {
                            return Err("Modulo by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value % other.value as f64)))
                    }
                    QValue::Num(other) => {
                        if other.value == 0.0 {
                            return Err("Modulo by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value % other.value)))
                    }
                    QValue::Decimal(other) => {
                        if other.value.is_zero() {
                            return Err("Modulo by zero".to_string());
                        }
                        let self_decimal = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        Ok(QValue::Decimal(QDecimal::new(self_decimal % other.value)))
                    }
                    _ => Err("mod expects a numeric argument".to_string()),
                }
            }
            "eq" => {
                if args.len() != 1 {
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => (self.value - other.value).abs() < f64::EPSILON,
                    QValue::Int(other) => (self.value - other.value as f64).abs() < f64::EPSILON,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec == other.value)));
                    }
                    QValue::Num(other) => (self.value - other.value).abs() < f64::EPSILON,
                    _ => false,
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "neq" => {
                if args.len() != 1 {
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => (self.value - other.value).abs() >= f64::EPSILON,
                    QValue::Int(other) => (self.value - other.value as f64).abs() >= f64::EPSILON,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec != other.value)));
                    }
                    QValue::Num(other) => (self.value - other.value).abs() >= f64::EPSILON,
                    _ => true,
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "gt" => {
                if args.len() != 1 {
                    return Err(format!("gt expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => self.value > other.value,
                    QValue::Int(other) => self.value > other.value as f64,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec > other.value)));
                    }
                    QValue::Num(other) => self.value > other.value,
                    _ => return Err("gt expects a numeric argument".to_string()),
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "lt" => {
                if args.len() != 1 {
                    return Err(format!("lt expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => self.value < other.value,
                    QValue::Int(other) => self.value < other.value as f64,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec < other.value)));
                    }
                    QValue::Num(other) => self.value < other.value,
                    _ => return Err("lt expects a numeric argument".to_string()),
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "gte" => {
                if args.len() != 1 {
                    return Err(format!("gte expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => self.value >= other.value,
                    QValue::Int(other) => self.value >= other.value as f64,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec >= other.value)));
                    }
                    QValue::Num(other) => self.value >= other.value,
                    _ => return Err("gte expects a numeric argument".to_string()),
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "lte" => {
                if args.len() != 1 {
                    return Err(format!("lte expects 1 argument, got {}", args.len()));
                }
                let result = match &args[0] {
                    QValue::Float(other) => self.value <= other.value,
                    QValue::Int(other) => self.value <= other.value as f64,
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from_f64_retain(self.value)
                            .ok_or("Cannot convert float to decimal")?;
                        return Ok(QValue::Bool(crate::types::QBool::new(self_dec <= other.value)));
                    }
                    QValue::Num(other) => self.value <= other.value,
                    _ => return Err("lte expects a numeric argument".to_string()),
                };
                Ok(QValue::Bool(crate::types::QBool::new(result)))
            }
            "abs" => {
                if !args.is_empty() {
                    return Err(format!("abs expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Float(QFloat::new(self.value.abs())))
            }
            "floor" => {
                if !args.is_empty() {
                    return Err(format!("floor expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value.floor() as i64)))
            }
            "ceil" => {
                if !args.is_empty() {
                    return Err(format!("ceil expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value.ceil() as i64)))
            }
            "round" => {
                if !args.is_empty() {
                    return Err(format!("round expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value.round() as i64)))
            }
            "to_int" => {
                if !args.is_empty() {
                    return Err(format!("to_int expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value as i64)))
            }
            "to_string" => {
                if !args.is_empty() {
                    return Err(format!("to_string expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            "is_nan" => {
                if !args.is_empty() {
                    return Err(format!("is_nan expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(crate::types::QBool::new(self.value.is_nan())))
            }
            "is_infinite" => {
                if !args.is_empty() {
                    return Err(format!("is_infinite expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(crate::types::QBool::new(self.value.is_infinite())))
            }
            "is_finite" => {
                if !args.is_empty() {
                    return Err(format!("is_finite expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(crate::types::QBool::new(self.value.is_finite())))
            }
            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' for Float type", method_name)),
        }
    }
}

impl QObj for QFloat {
    fn cls(&self) -> String {
        "Float".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Float"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Float"
    }

    fn _str(&self) -> String {
        // Display as integer if it's a whole number and not too large
        if self.value.fract() == 0.0 && self.value.abs() < 1e10 {
            format!("{:.0}", self.value)
        } else {
            self.value.to_string()
        }
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        "Float: 64-bit floating-point number".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
