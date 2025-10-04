use crate::types::*;
use rust_decimal::Decimal;
use std::str::FromStr;
use std::collections::HashMap;

pub fn create_decimal_module() -> QValue {
    let mut members = HashMap::new();

    members.insert(
        "new".to_string(),
        QValue::Fun(QFun {
            name: "new".to_string(),
            parent_type: "decimal".to_string(),
            doc: "Creates a new Decimal from a string or number.\n\nArgs:\n  value: String or Num - The value to convert to Decimal\n\nReturns:\n  Decimal - The created Decimal value\n\nExamples:\n  decimal.new(\"123.45\")\n  decimal.new(123.45)\n  decimal.new(\"99999999999999999999.9999999999\")".to_string(),
            id: next_object_id(),
        })
    );

    members.insert(
        "from_f64".to_string(),
        QValue::Fun(QFun {
            name: "from_f64".to_string(),
            parent_type: "decimal".to_string(),
            doc: "Creates a Decimal from a 64-bit float.\n\nArgs:\n  value: Num - The float value\n\nReturns:\n  Decimal - The created Decimal value\n\nExample:\n  decimal.from_f64(123.45)".to_string(),
            id: next_object_id(),
        })
    );

    members.insert(
        "zero".to_string(),
        QValue::Fun(QFun {
            name: "zero".to_string(),
            parent_type: "decimal".to_string(),
            doc: "Returns a Decimal representing zero.\n\nReturns:\n  Decimal - Zero as a Decimal".to_string(),
            id: next_object_id(),
        })
    );

    members.insert(
        "one".to_string(),
        QValue::Fun(QFun {
            name: "one".to_string(),
            parent_type: "decimal".to_string(),
            doc: "Returns a Decimal representing one.\n\nReturns:\n  Decimal - One as a Decimal".to_string(),
            id: next_object_id(),
        })
    );

    QValue::Module(QModule::new("decimal".to_string(), members))
}

pub fn call_decimal_function(name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match name {
        "decimal.new" => {
            if args.len() != 1 {
                return Err(format!("decimal.new expects 1 argument, got {}", args.len()));
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
                QValue::Num(n) => {
                    let decimal = Decimal::from_f64_retain(n.value)
                        .ok_or_else(|| format!("Cannot convert {} to decimal", n.value))?;
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                QValue::Decimal(d) => {
                    // Already a decimal, just return a clone
                    Ok(QValue::Decimal(d.clone()))
                }
                _ => Err("decimal.new expects a string or number argument".to_string()),
            }
        }
        "decimal.from_f64" => {
            if args.len() != 1 {
                return Err(format!("decimal.from_f64 expects 1 argument, got {}", args.len()));
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
                QValue::Num(n) => {
                    let decimal = Decimal::from_f64_retain(n.value)
                        .ok_or_else(|| format!("Cannot convert {} to decimal", n.value))?;
                    Ok(QValue::Decimal(QDecimal::new(decimal)))
                }
                _ => Err("decimal.from_f64 expects a number argument".to_string()),
            }
        }
        "decimal.zero" => {
            if !args.is_empty() {
                return Err(format!("decimal.zero expects 0 arguments, got {}", args.len()));
            }
            Ok(QValue::Decimal(QDecimal::new(Decimal::ZERO)))
        }
        "decimal.one" => {
            if !args.is_empty() {
                return Err(format!("decimal.one expects 0 arguments, got {}", args.len()));
            }
            Ok(QValue::Decimal(QDecimal::new(Decimal::ONE)))
        }
        _ => Err(format!("Unknown decimal function: {}", name)),
    }
}
