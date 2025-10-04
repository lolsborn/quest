use super::*;

#[derive(Debug, Clone)]
pub struct QInt {
    pub value: i64,
    pub id: u64,
}

impl QInt {
    pub fn new(value: i64) -> Self {
        QInt {
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
                    QValue::Int(other) => {
                        Ok(QValue::Int(QInt::new(self.value.checked_add(other.value)
                            .ok_or("Integer overflow in addition")?)))
                    }
                    QValue::Float(other) => {
                        // Int + Float = Float
                        Ok(QValue::Float(QFloat::new(self.value as f64 + other.value)))
                    }
                    QValue::Decimal(other) => {
                        // Int + Decimal = Decimal
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Decimal(QDecimal::new(self_dec + other.value)))
                    }
                    QValue::Num(other) => {
                        // Int + Num = Num (legacy compatibility)
                        Ok(QValue::Num(QNum::new(self.value as f64 + other.value)))
                    }
                    _ => Err("plus expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return Err(format!("minus expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => {
                        Ok(QValue::Int(QInt::new(self.value.checked_sub(other.value)
                            .ok_or("Integer overflow in subtraction")?)))
                    }
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value as f64 - other.value)))
                    }
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Decimal(QDecimal::new(self_dec - other.value)))
                    }
                    QValue::Num(other) => {
                        Ok(QValue::Num(QNum::new(self.value as f64 - other.value)))
                    }
                    _ => Err("minus expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return Err(format!("times expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => {
                        Ok(QValue::Int(QInt::new(self.value.checked_mul(other.value)
                            .ok_or("Integer overflow in multiplication")?)))
                    }
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value as f64 * other.value)))
                    }
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Decimal(QDecimal::new(self_dec * other.value)))
                    }
                    QValue::Num(other) => {
                        Ok(QValue::Num(QNum::new(self.value as f64 * other.value)))
                    }
                    _ => Err("times expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return Err(format!("div expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => {
                        if other.value == 0 {
                            return Err("Division by zero".to_string());
                        }
                        // Integer division returns Int
                        Ok(QValue::Int(QInt::new(self.value.checked_div(other.value)
                            .ok_or("Integer overflow in division")?)))
                    }
                    QValue::Float(other) => {
                        if other.value == 0.0 {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Float(QFloat::new(self.value as f64 / other.value)))
                    }
                    QValue::Decimal(other) => {
                        if other.value.is_zero() {
                            return Err("Division by zero".to_string());
                        }
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Decimal(QDecimal::new(self_dec / other.value)))
                    }
                    QValue::Num(other) => {
                        if other.value == 0.0 {
                            return Err("Division by zero".to_string());
                        }
                        Ok(QValue::Num(QNum::new(self.value as f64 / other.value)))
                    }
                    _ => Err("div expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return Err(format!("mod expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => {
                        if other.value == 0 {
                            return Err("Modulo by zero".to_string());
                        }
                        Ok(QValue::Int(QInt::new(self.value % other.value)))
                    }
                    QValue::Float(other) => {
                        Ok(QValue::Float(QFloat::new(self.value as f64 % other.value)))
                    }
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Decimal(QDecimal::new(self_dec % other.value)))
                    }
                    QValue::Num(other) => {
                        Ok(QValue::Num(QNum::new(self.value as f64 % other.value)))
                    }
                    _ => Err("mod expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            // Comparison methods
            "eq" => {
                if args.len() != 1 {
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value == other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 == other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec == other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new(self.value as f64 == other.value))),
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "neq" => {
                if args.len() != 1 {
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value != other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 != other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec != other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new(self.value as f64 != other.value))),
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            "gt" => {
                if args.len() != 1 {
                    return Err(format!("gt expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value > other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 > other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec > other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new(self.value as f64 > other.value))),
                    _ => Err("gt expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "lt" => {
                if args.len() != 1 {
                    return Err(format!("lt expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value < other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new((self.value as f64) < other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec < other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new((self.value as f64) < other.value))),
                    _ => Err("lt expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "gte" => {
                if args.len() != 1 {
                    return Err(format!("gte expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value >= other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 >= other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec >= other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new(self.value as f64 >= other.value))),
                    _ => Err("gte expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "lte" => {
                if args.len() != 1 {
                    return Err(format!("lte expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value <= other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 <= other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec <= other.value)))
                    }
                    QValue::Num(other) => Ok(QValue::Bool(QBool::new(self.value as f64 <= other.value))),
                    _ => Err("lte expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            // Conversion methods
            "to_f64" | "to_num" => {
                if !args.is_empty() {
                    return Err(format!("to_f64 expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.value as f64)))
            }
            "to_string" => {
                if !args.is_empty() {
                    return Err(format!("to_string expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            "abs" => {
                if !args.is_empty() {
                    return Err(format!("abs expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.value.abs())))
            }
            _ => Err(format!("Unknown method '{}' for int type", method_name)),
        }
    }
}

impl QObj for QInt {
    fn cls(&self) -> String {
        "Int".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Int"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Int" || type_name == "obj"
    }

    fn _str(&self) -> String {
        self.value.to_string()
    }

    fn _rep(&self) -> String {
        self.value.to_string()
    }

    fn _doc(&self) -> String {
        "Int type - 64-bit signed integer".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
