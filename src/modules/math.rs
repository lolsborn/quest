use std::collections::HashMap;
use crate::types::*;

pub fn create_math_module() -> QValue {
    let mut members = HashMap::new();

    // Mathematical constants
    members.insert("pi".to_string(), QValue::Float(QFloat::new(std::f64::consts::PI)));
    members.insert("tau".to_string(), QValue::Float(QFloat::new(std::f64::consts::TAU)));

    // Trigonometric functions
    members.insert("sin".to_string(), create_fn("math", "sin"));
    members.insert("cos".to_string(), create_fn("math", "cos"));
    members.insert("tan".to_string(), create_fn("math", "tan"));
    members.insert("asin".to_string(), create_fn("math", "asin"));
    members.insert("acos".to_string(), create_fn("math", "acos"));
    members.insert("atan".to_string(), create_fn("math", "atan"));

    // Other math functions
    members.insert("abs".to_string(), create_fn("math", "abs"));
    members.insert("sqrt".to_string(), create_fn("math", "sqrt"));
    members.insert("ln".to_string(), create_fn("math", "ln"));
    members.insert("log10".to_string(), create_fn("math", "log10"));
    members.insert("exp".to_string(), create_fn("math", "exp"));
    members.insert("floor".to_string(), create_fn("math", "floor"));
    members.insert("ceil".to_string(), create_fn("math", "ceil"));
    members.insert("round".to_string(), create_fn("math", "round"));

    QValue::Module(Box::new(QModule::new("math".to_string(), members)))
}

/// Handle math.* function calls
pub fn call_math_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "math.sin" | "math.cos" | "math.tan" | "math.asin" | "math.acos" | "math.atan" |
        "math.abs" | "math.sqrt" | "math.ln" | "math.log10" | "math.exp" |
        "math.floor" | "math.ceil" => {
            if args.len() != 1 {
                return Err(format!("{} expects 1 argument, got {}", func_name, args.len()));
            }
            let value = args[0].as_num()?;
            let result = match func_name.trim_start_matches("math.") {
                "sin" => value.sin(),
                "cos" => value.cos(),
                "tan" => value.tan(),
                "asin" => value.asin(),
                "acos" => value.acos(),
                "atan" => value.atan(),
                "abs" => value.abs(),
                "sqrt" => value.sqrt(),
                "ln" => value.ln(),
                "log10" => value.log10(),
                "exp" => value.exp(),
                "floor" => value.floor(),
                "ceil" => value.ceil(),
                _ => unreachable!(),
            };
            Ok(QValue::Float(QFloat::new(result)))
        }
        "math.round" => {
            // round(num) - round to nearest integer
            // round(num, places) - round to N decimal places
            if args.is_empty() || args.len() > 2 {
                return Err(format!("math.round expects 1 or 2 arguments, got {}", args.len()));
            }
            let value = args[0].as_num()?;

            if args.len() == 1 {
                // Round to nearest integer
                Ok(QValue::Float(QFloat::new(value.round())))
            } else {
                // Round to N decimal places
                let places = args[1].as_num()? as i32;
                if places < 0 {
                    return Err("math.round places must be non-negative".to_string());
                }
                let multiplier = 10_f64.powi(places);
                let result = (value * multiplier).round() / multiplier;
                Ok(QValue::Float(QFloat::new(result)))
            }
        }
        _ => Err(format!("Unknown math function: {}", func_name))
    }
}
