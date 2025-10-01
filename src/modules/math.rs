use std::collections::HashMap;
use crate::types::*;

pub fn create_math_module() -> QValue {
    // Create a wrapper for math functions that take one argument
    fn create_math_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "math".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Mathematical constants
    members.insert("pi".to_string(), QValue::Num(QNum::new(std::f64::consts::PI)));
    members.insert("tau".to_string(), QValue::Num(QNum::new(std::f64::consts::TAU)));

    // Trigonometric functions
    members.insert("sin".to_string(), create_math_fn("sin", "Calculate sine of angle in radians"));
    members.insert("cos".to_string(), create_math_fn("cos", "Calculate cosine of angle in radians"));
    members.insert("tan".to_string(), create_math_fn("tan", "Calculate tangent of angle in radians"));
    members.insert("asin".to_string(), create_math_fn("asin", "Calculate arcsine (inverse sine)"));
    members.insert("acos".to_string(), create_math_fn("acos", "Calculate arccosine (inverse cosine)"));
    members.insert("atan".to_string(), create_math_fn("atan", "Calculate arctangent (inverse tangent)"));

    // Other math functions
    members.insert("abs".to_string(), create_math_fn("abs", "Calculate absolute value"));
    members.insert("sqrt".to_string(), create_math_fn("sqrt", "Calculate square root"));
    members.insert("ln".to_string(), create_math_fn("ln", "Calculate natural logarithm (base e)"));
    members.insert("log10".to_string(), create_math_fn("log10", "Calculate logarithm base 10"));
    members.insert("exp".to_string(), create_math_fn("exp", "Calculate e raised to the power"));
    members.insert("floor".to_string(), create_math_fn("floor", "Round down to nearest integer"));
    members.insert("ceil".to_string(), create_math_fn("ceil", "Round up to nearest integer"));
    members.insert("round".to_string(), create_math_fn("round", "Round to nearest integer"));

    QValue::Module(QModule::new("math".to_string(), members))
}
