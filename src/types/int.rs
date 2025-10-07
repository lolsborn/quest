use super::*;
use std::sync::OnceLock;
use crate::{arg_err , attr_err};

#[derive(Debug, Clone)]
pub struct QInt {
    pub value: i64,
    pub id: u64,
}

// Integer cache for small values [-128, 127]
const CACHE_MIN: i64 = -128;
const CACHE_MAX: i64 = 127;
const CACHE_SIZE: usize = (CACHE_MAX - CACHE_MIN + 1) as usize;

static INT_CACHE: OnceLock<[QInt; CACHE_SIZE]> = OnceLock::new();

fn init_int_cache() -> [QInt; CACHE_SIZE] {
    let mut cache = Vec::with_capacity(CACHE_SIZE);
    for i in CACHE_MIN..=CACHE_MAX {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Int", id);
        cache.push(QInt { value: i, id });
    }
    cache.try_into().unwrap()
}

impl QInt {
    pub fn new(value: i64) -> Self {
        // Return cached instance for small integers
        if value >= CACHE_MIN && value <= CACHE_MAX {
            let cache = INT_CACHE.get_or_init(init_int_cache);
            let index = (value - CACHE_MIN) as usize;
            cache[index].clone()
        } else {
            // Outside cache range: allocate normally
            let id = next_object_id();
            crate::alloc_counter::track_alloc("Int", id);
            QInt { value, id }
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
                    _ => Err("plus expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "minus" => {
                if args.len() != 1 {
                    return arg_err!("minus expects 1 argument, got {}", args.len());
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
                    _ => Err("minus expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "times" => {
                if args.len() != 1 {
                    return arg_err!("times expects 1 argument, got {}", args.len());
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
                    _ => Err("times expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "div" => {
                if args.len() != 1 {
                    return arg_err!("div expects 1 argument, got {}", args.len());
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
                    _ => Err("div expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "mod" => {
                if args.len() != 1 {
                    return arg_err!("mod expects 1 argument, got {}", args.len());
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
                    _ => Err("mod expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            // Comparison methods
            "eq" => {
                if args.len() != 1 {
                    return arg_err!("eq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value == other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 == other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec == other.value)))
                    }
                    _ => Ok(QValue::Bool(QBool::new(false))),
                }
            }
            "neq" => {
                if args.len() != 1 {
                    return arg_err!("neq expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value != other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 != other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec != other.value)))
                    }
                    _ => Ok(QValue::Bool(QBool::new(true))),
                }
            }
            "gt" => {
                if args.len() != 1 {
                    return arg_err!("gt expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value > other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 > other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec > other.value)))
                    }
                    _ => Err("gt expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "lt" => {
                if args.len() != 1 {
                    return arg_err!("lt expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value < other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new((self.value as f64) < other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec < other.value)))
                    }
                    _ => Err("lt expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "gte" => {
                if args.len() != 1 {
                    return arg_err!("gte expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value >= other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 >= other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec >= other.value)))
                    }
                    _ => Err("gte expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            "lte" => {
                if args.len() != 1 {
                    return arg_err!("lte expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(other) => Ok(QValue::Bool(QBool::new(self.value <= other.value))),
                    QValue::Float(other) => Ok(QValue::Bool(QBool::new(self.value as f64 <= other.value))),
                    QValue::Decimal(other) => {
                        let self_dec = rust_decimal::Decimal::from(self.value);
                        Ok(QValue::Bool(QBool::new(self_dec <= other.value)))
                    }
                    _ => Err("lte expects an Int, Float, Decimal, or Num argument".to_string()),
                }
            }
            // Conversion methods
            "to_f64" | "to_num" => {
                if !args.is_empty() {
                    return arg_err!("to_f64 expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Float(QFloat::new(self.value as f64)))
            }
            "to_string" => {
                if !args.is_empty() {
                    return arg_err!("to_string expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.value.to_string())))
            }
            "abs" => {
                if !args.is_empty() {
                    return arg_err!("abs expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.value.abs())))
            }
            // Number trait methods (aliases and additions)
            "add" => self.call_method("plus", args),
            "sub" => self.call_method("minus", args),
            "mul" => self.call_method("times", args),
            "pow" => {
                if args.len() != 1 {
                    return arg_err!("pow expects 1 argument, got {}", args.len());
                }
                let exp = args[0].as_num()? as i32;
                if exp < 0 {
                    // Negative exponent -> float result
                    Ok(QValue::Float(QFloat::new((self.value as f64).powi(exp))))
                } else {
                    match self.value.checked_pow(exp as u32) {
                        Some(result) => Ok(QValue::Int(QInt::new(result))),
                        None => Err("Integer overflow in power operation".to_string()),
                    }
                }
            }
            "neg" => {
                if !args.is_empty() {
                    return arg_err!("neg expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(-self.value)))
            }
            "round" | "floor" | "ceil" | "trunc" => {
                // For integers, these are all identity operations
                if !args.is_empty() {
                    return arg_err!("{} expects 0 arguments, got {}", method_name, args.len());
                }
                Ok(QValue::Int(self.clone()))
            }
            "sign" => {
                if !args.is_empty() {
                    return arg_err!("sign expects 0 arguments, got {}", args.len());
                }
                let sign = if self.value > 0 { 1 } else if self.value < 0 { -1 } else { 0 };
                Ok(QValue::Int(QInt::new(sign)))
            }
            "min" => {
                if args.len() != 1 {
                    return arg_err!("min expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_num()? as i64;
                Ok(QValue::Int(QInt::new(self.value.min(other))))
            }
            "max" => {
                if args.len() != 1 {
                    return arg_err!("max expects 1 argument, got {}", args.len());
                }
                let other = args[0].as_num()? as i64;
                Ok(QValue::Int(QInt::new(self.value.max(other))))
            }
            _ => attr_err!("Unknown method '{}' for int type", method_name),
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

impl Drop for QInt {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Int", self.id);
    }
}
