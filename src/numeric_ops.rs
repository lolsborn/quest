// ============================================================================
// Simplified numeric operations with automatic type promotion
// ============================================================================

use crate::types::{QValue, QInt, QFloat, QDecimal, QString, QArray};
use rust_decimal::prelude::ToPrimitive;

/// Type promotion hierarchy: Int < Float < Decimal
/// This returns the more precise type when two numeric types are mixed
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
enum NumericType {
    Int,
    Float,
    Decimal,
}

impl NumericType {
    fn from_qvalue(v: &QValue) -> Option<NumericType> {
        match v {
            QValue::Int(_) => Some(NumericType::Int),
            QValue::Float(_) => Some(NumericType::Float),
            QValue::Decimal(_) => Some(NumericType::Decimal),
            _ => None,
        }
    }

    fn promote(a: NumericType, b: NumericType) -> NumericType {
        std::cmp::max(a, b)
    }
}

/// Extract numeric value as f64 (for operations that need it)
fn as_f64(v: &QValue) -> Result<f64, String> {
    match v {
        QValue::Int(i) => Ok(i.value as f64),
        QValue::Float(f) => Ok(f.value),
        QValue::Decimal(d) => d.value.to_f64()
            .ok_or_else(|| "Cannot convert decimal to f64".to_string()),
        _ => Err(format!("Expected numeric type, got {}", v.as_obj().cls())),
    }
}

/// Extract numeric value as i64 (for integer operations)
fn as_i64(v: &QValue) -> Result<i64, String> {
    match v {
        QValue::Int(i) => Ok(i.value),
        QValue::Float(f) => Ok(f.value as i64),
        QValue::Decimal(d) => d.value.to_i64()
            .ok_or_else(|| "Cannot convert decimal to i64".to_string()),
        _ => Err(format!("Expected numeric type, got {}", v.as_obj().cls())),
    }
}

/// Extract numeric value as rust_decimal (for decimal operations)
fn as_decimal(v: &QValue) -> Result<rust_decimal::Decimal, String> {
    match v {
        QValue::Int(i) => Ok(rust_decimal::Decimal::from(i.value)),
        QValue::Float(f) => rust_decimal::Decimal::from_f64_retain(f.value)
            .ok_or_else(|| "Cannot convert float to decimal".to_string()),
        QValue::Decimal(d) => Ok(d.value),
        _ => Err(format!("Expected numeric type, got {}", v.as_obj().cls())),
    }
}

/// Create QValue from numeric result based on target type
fn make_numeric(value: f64, target_type: NumericType) -> QValue {
    match target_type {
        NumericType::Int => QValue::Int(QInt::new(value as i64)),
        NumericType::Float => QValue::Float(QFloat::new(value)),
        NumericType::Decimal => {
            if let Some(dec) = rust_decimal::Decimal::from_f64_retain(value) {
                QValue::Decimal(QDecimal::new(dec))
            } else {
                QValue::Float(QFloat::new(value))
            }
        }
    }
}

/// Create QValue from decimal result
fn make_decimal(value: rust_decimal::Decimal, target_type: NumericType) -> QValue {
    match target_type {
        NumericType::Decimal => QValue::Decimal(QDecimal::new(value)),
        NumericType::Float => {
            if let Some(f) = value.to_f64() {
                QValue::Float(QFloat::new(f))
            } else {
                QValue::Decimal(QDecimal::new(value))
            }
        }
        NumericType::Int => {
            if let Some(i) = value.to_i64() {
                QValue::Int(QInt::new(i))
            } else {
                QValue::Decimal(QDecimal::new(value))
            }
        }
    }
}

/// Apply compound assignment operator with automatic type promotion
pub fn apply_compound_op(lhs: &QValue, op: &str, rhs: &QValue) -> Result<QValue, String> {
    match op {
        "=" => Ok(rhs.clone()),

        "+=" => apply_addition(lhs, rhs),
        "-=" => apply_subtraction(lhs, rhs),
        "*=" => apply_multiplication(lhs, rhs),
        "/=" => apply_division(lhs, rhs),
        "%=" => apply_modulo(lhs, rhs),

        _ => Err(format!("Unknown compound operator: {}", op)),
    }
}

fn apply_addition(lhs: &QValue, rhs: &QValue) -> Result<QValue, String> {
    // Handle non-numeric additions
    match (lhs, rhs) {
        (QValue::Str(s1), QValue::Str(s2)) => {
            let combined = format!("{}{}", s1.value, s2.value);
            return Ok(QValue::Str(QString::new(combined)));
        }
        (QValue::Array(a1), QValue::Array(a2)) => {
            let mut elements = a1.elements.borrow().clone();
            elements.extend(a2.elements.borrow().clone());
            return Ok(QValue::Array(QArray::new(elements)));
        }
        _ => {}
    }

    // Numeric addition with type promotion
    let lhs_type = NumericType::from_qvalue(lhs)
        .ok_or_else(|| format!("Cannot use += with type {}", lhs.as_obj().cls()))?;
    let rhs_type = NumericType::from_qvalue(rhs)
        .ok_or_else(|| format!("Cannot use += with type {}", rhs.as_obj().cls()))?;
    let target_type = NumericType::promote(lhs_type, rhs_type);

    // Special handling for Int + Int (no promotion, check overflow)
    if matches!((lhs, rhs), (QValue::Int(_), QValue::Int(_))) {
        let l = as_i64(lhs)?;
        let r = as_i64(rhs)?;
        return Ok(QValue::Int(QInt::new(l.wrapping_add(r))));
    }

    // Use decimal for Decimal operations
    if target_type == NumericType::Decimal {
        let l = as_decimal(lhs)?;
        let r = as_decimal(rhs)?;
        return Ok(make_decimal(l + r, target_type));
    }

    // Use f64 for Float/Num operations
    let l = as_f64(lhs)?;
    let r = as_f64(rhs)?;
    Ok(make_numeric(l + r, target_type))
}

fn apply_subtraction(lhs: &QValue, rhs: &QValue) -> Result<QValue, String> {
    let lhs_type = NumericType::from_qvalue(lhs)
        .ok_or_else(|| format!("Cannot use -= with type {}", lhs.as_obj().cls()))?;
    let rhs_type = NumericType::from_qvalue(rhs)
        .ok_or_else(|| format!("Cannot use -= with type {}", rhs.as_obj().cls()))?;
    let target_type = NumericType::promote(lhs_type, rhs_type);

    if matches!((lhs, rhs), (QValue::Int(_), QValue::Int(_))) {
        let l = as_i64(lhs)?;
        let r = as_i64(rhs)?;
        return Ok(QValue::Int(QInt::new(l.wrapping_sub(r))));
    }

    if target_type == NumericType::Decimal {
        let l = as_decimal(lhs)?;
        let r = as_decimal(rhs)?;
        return Ok(make_decimal(l - r, target_type));
    }

    let l = as_f64(lhs)?;
    let r = as_f64(rhs)?;
    Ok(make_numeric(l - r, target_type))
}

fn apply_multiplication(lhs: &QValue, rhs: &QValue) -> Result<QValue, String> {
    let lhs_type = NumericType::from_qvalue(lhs)
        .ok_or_else(|| format!("Cannot use *= with type {}", lhs.as_obj().cls()))?;
    let rhs_type = NumericType::from_qvalue(rhs)
        .ok_or_else(|| format!("Cannot use *= with type {}", rhs.as_obj().cls()))?;
    let target_type = NumericType::promote(lhs_type, rhs_type);

    if matches!((lhs, rhs), (QValue::Int(_), QValue::Int(_))) {
        let l = as_i64(lhs)?;
        let r = as_i64(rhs)?;
        return Ok(QValue::Int(QInt::new(l.wrapping_mul(r))));
    }

    if target_type == NumericType::Decimal {
        let l = as_decimal(lhs)?;
        let r = as_decimal(rhs)?;
        return Ok(make_decimal(l * r, target_type));
    }

    let l = as_f64(lhs)?;
    let r = as_f64(rhs)?;
    Ok(make_numeric(l * r, target_type))
}

fn apply_division(lhs: &QValue, rhs: &QValue) -> Result<QValue, String> {
    let lhs_type = NumericType::from_qvalue(lhs)
        .ok_or_else(|| format!("Cannot use /= with type {}", lhs.as_obj().cls()))?;
    let rhs_type = NumericType::from_qvalue(rhs)
        .ok_or_else(|| format!("Cannot use /= with type {}", rhs.as_obj().cls()))?;
    let target_type = NumericType::promote(lhs_type, rhs_type);

    // Check for division by zero
    match rhs {
        QValue::Int(i) if i.value == 0 => return Err("Division by zero".to_string()),
        QValue::Float(f) if f.value == 0.0 => return Err("Division by zero".to_string()),
        QValue::Decimal(d) if d.value.is_zero() => return Err("Division by zero".to_string()),
        _ => {}
    }

    if matches!((lhs, rhs), (QValue::Int(_), QValue::Int(_))) {
        let l = as_i64(lhs)?;
        let r = as_i64(rhs)?;
        return Ok(QValue::Int(QInt::new(l / r)));
    }

    if target_type == NumericType::Decimal {
        let l = as_decimal(lhs)?;
        let r = as_decimal(rhs)?;
        return Ok(make_decimal(l / r, target_type));
    }

    let l = as_f64(lhs)?;
    let r = as_f64(rhs)?;
    Ok(make_numeric(l / r, target_type))
}

fn apply_modulo(lhs: &QValue, rhs: &QValue) -> Result<QValue, String> {
    let lhs_type = NumericType::from_qvalue(lhs)
        .ok_or_else(|| format!("Cannot use %= with type {}", lhs.as_obj().cls()))?;
    let rhs_type = NumericType::from_qvalue(rhs)
        .ok_or_else(|| format!("Cannot use %= with type {}", rhs.as_obj().cls()))?;
    let target_type = NumericType::promote(lhs_type, rhs_type);

    // Check for modulo by zero
    match rhs {
        QValue::Int(i) if i.value == 0 => return Err("Modulo by zero".to_string()),
        QValue::Float(f) if f.value == 0.0 => return Err("Modulo by zero".to_string()),
        QValue::Decimal(d) if d.value.is_zero() => return Err("Modulo by zero".to_string()),
        _ => {}
    }

    if matches!((lhs, rhs), (QValue::Int(_), QValue::Int(_))) {
        let l = as_i64(lhs)?;
        let r = as_i64(rhs)?;
        return Ok(QValue::Int(QInt::new(l % r)));
    }

    if target_type == NumericType::Decimal {
        let l = as_decimal(lhs)?;
        let r = as_decimal(rhs)?;
        return Ok(make_decimal(l % r, target_type));
    }

    let l = as_f64(lhs)?;
    let r = as_f64(rhs)?;
    Ok(make_numeric(l % r, target_type))
}
