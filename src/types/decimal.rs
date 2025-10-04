use super::*;
use rust_decimal::Decimal;

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
                    return Err(format!("plus expects 1 argument, got {}", args.len()));
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
                    return Err(format!("minus expects 1 argument, got {}", args.len()));
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
                    return Err(format!("times expects 1 argument, got {}", args.len()));
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
                    return Err(format!("div expects 1 argument, got {}", args.len()));
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
                    return Err(format!("mod expects 1 argument, got {}", args.len()));
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
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
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
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
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
                    return Err(format!("gt expects 1 argument, got {}", args.len()));
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
                    return Err(format!("lt expects 1 argument, got {}", args.len()));
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
                    return Err(format!("gte expects 1 argument, got {}", args.len()));
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
                    return Err(format!("lte expects 1 argument, got {}", args.len()));
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
                    return Err(format!("to_f64 expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Float(QFloat::new(self.value.to_f64().unwrap_or(0.0))))
            }
            "to_string" => {
                if !args.is_empty() {
                    return Err(format!("to_string expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            _ => Err(format!("Unknown method '{}' for decimal type", method_name)),
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

    fn _str(&self) -> String {
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
