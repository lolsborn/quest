use super::*;

#[derive(Debug, Clone)]
pub struct QNum {
    pub value: f64,
    pub id: u64,
}

impl QNum {
    pub fn new(value: f64) -> Self {
        QNum {
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
                let other = args[0].as_num()?;
                Ok(QValue::Num(QNum::new(self.value + other)))
            }
            "minus" => {
                if args.len() != 1 {
                    return Err(format!("minus expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Num(QNum::new(self.value - other)))
            }
            "times" => {
                if args.len() != 1 {
                    return Err(format!("times expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Num(QNum::new(self.value * other)))
            }
            "div" => {
                if args.len() != 1 {
                    return Err(format!("div expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                if other == 0.0 {
                    return Err("Division by zero".to_string());
                }
                Ok(QValue::Num(QNum::new(self.value / other)))
            }
            "mod" => {
                if args.len() != 1 {
                    return Err(format!("mod expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Num(QNum::new(self.value % other)))
            }
            // Comparison methods
            "eq" => {
                if args.len() != 1 {
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value == other)))
            }
            "neq" => {
                if args.len() != 1 {
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value != other)))
            }
            "gt" => {
                if args.len() != 1 {
                    return Err(format!("gt expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value > other)))
            }
            "lt" => {
                if args.len() != 1 {
                    return Err(format!("lt expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value < other)))
            }
            "gte" => {
                if args.len() != 1 {
                    return Err(format!("gte expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value >= other)))
            }
            "lte" => {
                if args.len() != 1 {
                    return Err(format!("lte expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_num()?;
                Ok(QValue::Bool(QBool::new(self.value <= other)))
            }
            _ => Err(format!("Unknown method '{}' for num type", method_name)),
        }
    }
}

impl QObj for QNum {
    fn cls(&self) -> String {
        "Num".to_string()
    }

    fn q_type(&self) -> &'static str {
        "num"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "num" || type_name == "obj"
    }

    fn _str(&self) -> String {
        if self.value.fract() == 0.0 && self.value.abs() < 1e10 {
            format!("{}", self.value as i64)
        } else {
            format!("{}", self.value)
        }
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        "Number type - can represent integers and floating point numbers".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
