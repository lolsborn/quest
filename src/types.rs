use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::rc::Rc;
use std::cell::RefCell;

// Global ID counter for Quest objects
static NEXT_ID: AtomicU64 = AtomicU64::new(1);

pub fn next_object_id() -> u64 {
    NEXT_ID.fetch_add(1, Ordering::Relaxed)
}

// Helper function for Quest value equality comparison
pub fn values_equal(a: &QValue, b: &QValue) -> bool {
    match (a, b) {
        (QValue::Num(a_num), QValue::Num(b_num)) => (a_num.value - b_num.value).abs() < f64::EPSILON,
        (QValue::Bool(a_bool), QValue::Bool(b_bool)) => a_bool.value == b_bool.value,
        (QValue::Str(a_str), QValue::Str(b_str)) => a_str.value == b_str.value,
        (QValue::Nil(_), QValue::Nil(_)) => true,
        (QValue::Array(a_arr), QValue::Array(b_arr)) => {
            if a_arr.elements.len() != b_arr.elements.len() {
                return false;
            }
            for (a_elem, b_elem) in a_arr.elements.iter().zip(b_arr.elements.iter()) {
                if !values_equal(a_elem, b_elem) {
                    return false;
                }
            }
            true
        }
        _ => false, // Different types or unsupported types (Dict, Fun, etc.)
    }
}

// Helper function for comparing Quest values (for sorting)
pub fn compare_values(a: &QValue, b: &QValue) -> Option<std::cmp::Ordering> {
    use std::cmp::Ordering;

    match (a, b) {
        // Numbers compare naturally
        (QValue::Num(a_num), QValue::Num(b_num)) => {
            a_num.value.partial_cmp(&b_num.value)
        }
        // Strings compare lexicographically
        (QValue::Str(a_str), QValue::Str(b_str)) => {
            Some(a_str.value.cmp(&b_str.value))
        }
        // Booleans: false < true
        (QValue::Bool(a_bool), QValue::Bool(b_bool)) => {
            Some(a_bool.value.cmp(&b_bool.value))
        }
        // Nil is equal to nil
        (QValue::Nil(_), QValue::Nil(_)) => Some(Ordering::Equal),

        // Mixed types: order by type priority
        // Nil < Bool < Num < Str < Array < Dict < Fun < Module
        (QValue::Nil(_), _) => Some(Ordering::Less),
        (_, QValue::Nil(_)) => Some(Ordering::Greater),
        (QValue::Bool(_), QValue::Num(_)) => Some(Ordering::Less),
        (QValue::Num(_), QValue::Bool(_)) => Some(Ordering::Greater),
        (QValue::Bool(_), QValue::Str(_)) => Some(Ordering::Less),
        (QValue::Str(_), QValue::Bool(_)) => Some(Ordering::Greater),
        (QValue::Num(_), QValue::Str(_)) => Some(Ordering::Less),
        (QValue::Str(_), QValue::Num(_)) => Some(Ordering::Greater),

        // For other types, consider them equal (or handle specially if needed)
        _ => Some(Ordering::Equal)
    }
}

// Helper function to handle QObj trait methods that should be callable on all types
// Returns Some(result) if the method is a QObj trait method, None otherwise
pub fn try_call_qobj_method<T: QObj>(obj: &T, method_name: &str, args: &[QValue]) -> Option<Result<QValue, String>> {
    match method_name {
        "cls" => {
            if !args.is_empty() {
                return Some(Err(format!("cls expects 0 arguments, got {}", args.len())));
            }
            Some(Ok(QValue::Str(QString::new(obj.cls()))))
        }
        "_str" => {
            if !args.is_empty() {
                return Some(Err(format!("_str expects 0 arguments, got {}", args.len())));
            }
            Some(Ok(QValue::Str(QString::new(obj._str()))))
        }
        "_rep" => {
            if !args.is_empty() {
                return Some(Err(format!("_rep expects 0 arguments, got {}", args.len())));
            }
            Some(Ok(QValue::Str(QString::new(obj._rep()))))
        }
        "_doc" => {
            if !args.is_empty() {
                return Some(Err(format!("_doc expects 0 arguments, got {}", args.len())));
            }
            Some(Ok(QValue::Str(QString::new(obj._doc()))))
        }
        "_id" => {
            if !args.is_empty() {
                return Some(Err(format!("_id expects 0 arguments, got {}", args.len())));
            }
            Some(Ok(QValue::Num(QNum::new(obj._id() as f64))))
        }
        _ => None, // Not a QObj trait method, let the type handle it
    }
}

// Quest Object System
pub trait QObj {
    fn cls(&self) -> String;
    #[allow(dead_code)]
    fn q_type(&self) -> &'static str;
    #[allow(dead_code)]
    fn is(&self, type_name: &str) -> bool;
    fn _str(&self) -> String;
    fn _rep(&self) -> String;
    fn _doc(&self) -> String;
    fn _id(&self) -> u64;
}

#[derive(Debug, Clone)]
pub enum QValue {
    Num(QNum),
    Bool(QBool),
    Str(QString),
    Nil(QNil),
    Fun(QFun),
    UserFun(QUserFun),
    Module(QModule),
    Array(QArray),
    Dict(QDict),
    Type(QType),
    Struct(QStruct),
    Trait(QTrait),
    Exception(QException),
    // Time types (from std/time module)
    Timestamp(crate::modules::time::QTimestamp),
    Zoned(crate::modules::time::QZoned),
    Date(crate::modules::time::QDate),
    Time(crate::modules::time::QTime),
    Span(crate::modules::time::QSpan),
}

impl QValue {
    pub fn as_obj(&self) -> &dyn QObj {
        match self {
            QValue::Num(n) => n,
            QValue::Bool(b) => b,
            QValue::Str(s) => s,
            QValue::Nil(n) => n,
            QValue::Fun(f) => f,
            QValue::UserFun(f) => f,
            QValue::Module(m) => m,
            QValue::Array(a) => a,
            QValue::Dict(d) => d,
            QValue::Type(t) => t,
            QValue::Struct(s) => s,
            QValue::Trait(t) => t,
            QValue::Exception(e) => e,
            QValue::Timestamp(ts) => ts,
            QValue::Zoned(z) => z,
            QValue::Date(d) => d,
            QValue::Time(t) => t,
            QValue::Span(s) => s,
        }
    }

    pub fn as_num(&self) -> Result<f64, String> {
        match self {
            QValue::Num(n) => Ok(n.value),
            QValue::Bool(b) => Ok(if b.value { 1.0 } else { 0.0 }),
            QValue::Str(s) => s.value.parse::<f64>()
                .map_err(|_| format!("Cannot convert string '{}' to number", s.value)),
            QValue::Nil(_) => Ok(0.0),
            QValue::Fun(_) => Err("Cannot convert fun to number".to_string()),
            QValue::UserFun(_) => Err("Cannot convert fun to number".to_string()),
            QValue::Module(_) => Err("Cannot convert module to number".to_string()),
            QValue::Array(_) => Err("Cannot convert array to number".to_string()),
            QValue::Dict(_) => Err("Cannot convert dict to number".to_string()),
            QValue::Type(_) => Err("Cannot convert type to number".to_string()),
            QValue::Struct(_) => Err("Cannot convert struct to number".to_string()),
            QValue::Trait(_) => Err("Cannot convert trait to number".to_string()),
            QValue::Exception(_) => Err("Cannot convert exception to number".to_string()),
            QValue::Timestamp(ts) => Ok(ts.timestamp.as_second() as f64),
            QValue::Zoned(_) => Err("Cannot convert zoned datetime to number".to_string()),
            QValue::Date(_) => Err("Cannot convert date to number".to_string()),
            QValue::Time(_) => Err("Cannot convert time to number".to_string()),
            QValue::Span(_) => Err("Cannot convert span to number".to_string()),
        }
    }

    pub fn as_bool(&self) -> bool {
        match self {
            QValue::Num(n) => n.value != 0.0,
            QValue::Bool(b) => b.value,
            QValue::Str(s) => !s.value.is_empty(),
            QValue::Nil(_) => false,
            QValue::Fun(_) => true, // Functions are truthy
            QValue::UserFun(_) => true, // User functions are truthy
            QValue::Module(_) => true, // Modules are truthy
            QValue::Array(a) => !a.elements.is_empty(), // Empty arrays are falsy
            QValue::Dict(d) => !d.map.is_empty(), // Empty dicts are falsy
            QValue::Type(_) => true, // Types are truthy
            QValue::Struct(_) => true, // Struct instances are truthy
            QValue::Trait(_) => true, // Traits are truthy
            QValue::Exception(_) => true, // Exceptions are truthy
            QValue::Timestamp(_) => true, // Timestamps are truthy
            QValue::Zoned(_) => true, // Zoned datetimes are truthy
            QValue::Date(_) => true, // Dates are truthy
            QValue::Time(_) => true, // Times are truthy
            QValue::Span(_) => true, // Spans are truthy
        }
    }

    pub fn as_str(&self) -> String {
        match self {
            QValue::Num(n) => n._str(),
            QValue::Bool(b) => b._str(),
            QValue::Str(s) => s.value.clone(),
            QValue::Nil(_) => "nil".to_string(),
            QValue::Fun(f) => f._str(),
            QValue::UserFun(f) => f._str(),
            QValue::Module(m) => m._str(),
            QValue::Array(a) => a._str(),
            QValue::Dict(d) => d._str(),
            QValue::Type(t) => t._str(),
            QValue::Struct(s) => s._str(),
            QValue::Trait(t) => t._str(),
            QValue::Exception(e) => e._str(),
            QValue::Timestamp(ts) => ts._str(),
            QValue::Zoned(z) => z._str(),
            QValue::Date(d) => d._str(),
            QValue::Time(t) => t._str(),
            QValue::Span(s) => s._str(),
        }
    }
}

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

#[derive(Debug, Clone)]
pub struct QBool {
    pub value: bool,
    pub id: u64,
}

impl QBool {
    pub fn new(value: bool) -> Self {
        QBool {
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
            "eq" => {
                if args.len() != 1 {
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_bool();
                Ok(QValue::Bool(QBool::new(self.value == other)))
            }
            "neq" => {
                if args.len() != 1 {
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_bool();
                Ok(QValue::Bool(QBool::new(self.value != other)))
            }
            _ => Err(format!("Unknown method '{}' for bool type", method_name)),
        }
    }
}

impl QObj for QBool {
    fn cls(&self) -> String {
        "Bool".to_string()
    }

    fn q_type(&self) -> &'static str {
        "bool"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "bool" || type_name == "obj"
    }

    fn _str(&self) -> String {
        if self.value { "true".to_string() } else { "false".to_string() }
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        "Boolean type - represents true or false".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QString {
    pub value: String,
    pub id: u64,
}

impl QString {
    pub fn new(value: String) -> Self {
        QString {
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
            "len" => {
                if !args.is_empty() {
                    return Err(format!("len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.value.len() as f64)))
            }
            "concat" => {
                if args.len() != 1 {
                    return Err(format!("concat expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_str();
                Ok(QValue::Str(QString::new(format!("{}{}", self.value, other))))
            }
            "upper" => {
                if !args.is_empty() {
                    return Err(format!("upper expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.to_uppercase())))
            }
            "lower" => {
                if !args.is_empty() {
                    return Err(format!("lower expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.to_lowercase())))
            }
            "eq" => {
                if args.len() != 1 {
                    return Err(format!("eq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value == other)))
            }
            "neq" => {
                if args.len() != 1 {
                    return Err(format!("neq expects 1 argument, got {}", args.len()));
                }
                let other = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value != other)))
            }
            // Case conversion methods
            "capitalize" => {
                if !args.is_empty() {
                    return Err(format!("capitalize expects 0 arguments, got {}", args.len()));
                }
                let mut chars = self.value.chars();
                let capitalized = match chars.next() {
                    None => String::new(),
                    Some(first) => first.to_uppercase().chain(chars.as_str().to_lowercase().chars()).collect(),
                };
                Ok(QValue::Str(QString::new(capitalized)))
            }
            "title" => {
                if !args.is_empty() {
                    return Err(format!("title expects 0 arguments, got {}", args.len()));
                }
                let mut result = String::new();
                let mut capitalize_next = true;
                for ch in self.value.chars() {
                    if ch.is_whitespace() {
                        result.push(ch);
                        capitalize_next = true;
                    } else if capitalize_next {
                        result.extend(ch.to_uppercase());
                        capitalize_next = false;
                    } else {
                        result.extend(ch.to_lowercase());
                    }
                }
                Ok(QValue::Str(QString::new(result)))
            }
            // Trim methods
            "trim" => {
                if !args.is_empty() {
                    return Err(format!("trim expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.trim().to_string())))
            }
            "ltrim" => {
                if !args.is_empty() {
                    return Err(format!("ltrim expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.trim_start().to_string())))
            }
            "rtrim" => {
                if !args.is_empty() {
                    return Err(format!("rtrim expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.value.trim_end().to_string())))
            }
            // String checking methods
            "isalnum" => {
                if !args.is_empty() {
                    return Err(format!("isalnum expects 0 arguments, got {}", args.len()));
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_alphanumeric());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isalpha" => {
                if !args.is_empty() {
                    return Err(format!("isalpha expects 0 arguments, got {}", args.len()));
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_alphabetic());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isascii" => {
                if !args.is_empty() {
                    return Err(format!("isascii expects 0 arguments, got {}", args.len()));
                }
                let result = self.value.chars().all(|c| c.is_ascii());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isdigit" => {
                if !args.is_empty() {
                    return Err(format!("isdigit expects 0 arguments, got {}", args.len()));
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_ascii_digit());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "isnumeric" => {
                if !args.is_empty() {
                    return Err(format!("isnumeric expects 0 arguments, got {}", args.len()));
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_numeric());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "islower" => {
                if !args.is_empty() {
                    return Err(format!("islower expects 0 arguments, got {}", args.len()));
                }
                let has_cased = self.value.chars().any(|c| c.is_alphabetic());
                let all_lower = self.value.chars().filter(|c| c.is_alphabetic()).all(|c| c.is_lowercase());
                Ok(QValue::Bool(QBool::new(has_cased && all_lower)))
            }
            "isupper" => {
                if !args.is_empty() {
                    return Err(format!("isupper expects 0 arguments, got {}", args.len()));
                }
                let has_cased = self.value.chars().any(|c| c.is_alphabetic());
                let all_upper = self.value.chars().filter(|c| c.is_alphabetic()).all(|c| c.is_uppercase());
                Ok(QValue::Bool(QBool::new(has_cased && all_upper)))
            }
            "isspace" => {
                if !args.is_empty() {
                    return Err(format!("isspace expects 0 arguments, got {}", args.len()));
                }
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_whitespace());
                Ok(QValue::Bool(QBool::new(result)))
            }
            // Query methods
            "count" => {
                if args.len() != 1 {
                    return Err(format!("count expects 1 argument, got {}", args.len()));
                }
                let substring = args[0].as_str();
                let count = self.value.matches(&substring).count();
                Ok(QValue::Num(QNum::new(count as f64)))
            }
            "endswith" => {
                if args.len() != 1 {
                    return Err(format!("endswith expects 1 argument, got {}", args.len()));
                }
                let suffix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.ends_with(&suffix))))
            }
            "startswith" => {
                if args.len() != 1 {
                    return Err(format!("startswith expects 1 argument, got {}", args.len()));
                }
                let prefix = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.starts_with(&prefix))))
            }
            "index_of" => {
                if args.len() != 1 {
                    return Err(format!("index_of expects 1 argument, got {}", args.len()));
                }
                let substring = args[0].as_str();
                let index = self.value.find(&substring)
                    .map(|i| i as f64)
                    .unwrap_or(-1.0);
                Ok(QValue::Num(QNum::new(index)))
            }
            "contains" => {
                if args.len() != 1 {
                    return Err(format!("contains expects 1 argument, got {}", args.len()));
                }
                let substring = args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.value.contains(&substring))))
            }
            "isdecimal" => {
                if !args.is_empty() {
                    return Err(format!("isdecimal expects 0 arguments, got {}", args.len()));
                }
                // In Python, isdecimal() checks if all characters are decimal characters (0-9)
                // This is stricter than isdigit() which also accepts superscript digits
                let result = !self.value.is_empty() && self.value.chars().all(|c| c.is_ascii_digit());
                Ok(QValue::Bool(QBool::new(result)))
            }
            "istitle" => {
                if !args.is_empty() {
                    return Err(format!("istitle expects 0 arguments, got {}", args.len()));
                }
                // Title case: first letter of each word is uppercase, rest are lowercase
                // Words are separated by whitespace or non-alphabetic characters
                if self.value.is_empty() {
                    return Ok(QValue::Bool(QBool::new(false)));
                }

                let mut found_word = false;
                let mut prev_is_alpha = false;
                let mut is_title = true;

                for c in self.value.chars() {
                    if c.is_alphabetic() {
                        if !prev_is_alpha {
                            // Start of a word - must be uppercase
                            if !c.is_uppercase() {
                                is_title = false;
                                break;
                            }
                            found_word = true;
                        } else {
                            // Middle of a word - must be lowercase
                            if c.is_uppercase() {
                                is_title = false;
                                break;
                            }
                        }
                        prev_is_alpha = true;
                    } else {
                        prev_is_alpha = false;
                    }
                }

                Ok(QValue::Bool(QBool::new(is_title && found_word)))
            }
            "expandtabs" => {
                // expandtabs(tabsize=8) - replaces tabs with spaces
                let tabsize = if args.is_empty() {
                    8
                } else if args.len() == 1 {
                    args[0].as_num()? as usize
                } else {
                    return Err(format!("expandtabs expects 0 or 1 arguments, got {}", args.len()));
                };

                let mut result = String::new();
                let mut column = 0;

                for c in self.value.chars() {
                    if c == '\t' {
                        // Calculate number of spaces to next tab stop
                        let spaces = tabsize - (column % tabsize);
                        result.push_str(&" ".repeat(spaces));
                        column += spaces;
                    } else if c == '\n' || c == '\r' {
                        result.push(c);
                        column = 0;
                    } else {
                        result.push(c);
                        column += 1;
                    }
                }

                Ok(QValue::Str(QString::new(result)))
            }
            "encode" => {
                // encode(encoding="utf-8") - returns encoded string
                let encoding = if args.is_empty() {
                    "utf-8"
                } else if args.len() == 1 {
                    &args[0].as_str()
                } else {
                    return Err(format!("encode expects 0 or 1 arguments, got {}", args.len()));
                };

                match encoding {
                    "utf-8" | "utf8" => {
                        // Return a string representation of the bytes
                        let bytes: Vec<String> = self.value.bytes().map(|b| format!("{}", b)).collect();
                        let result = format!("[{}]", bytes.join(", "));
                        Ok(QValue::Str(QString::new(result)))
                    }
                    "hex" => {
                        // Return hex representation
                        let hex: String = self.value.bytes().map(|b| format!("{:02x}", b)).collect();
                        Ok(QValue::Str(QString::new(hex)))
                    }
                    "b64" | "base64" => {
                        // Return base64 encoded string
                        use base64::{Engine as _, engine::general_purpose};
                        let encoded = general_purpose::STANDARD.encode(self.value.as_bytes());
                        Ok(QValue::Str(QString::new(encoded)))
                    }
                    "b64url" | "base64url" => {
                        // Return URL-safe base64 encoded string
                        use base64::{Engine as _, engine::general_purpose};
                        let encoded = general_purpose::URL_SAFE_NO_PAD.encode(self.value.as_bytes());
                        Ok(QValue::Str(QString::new(encoded)))
                    }
                    _ => Err(format!("Unknown encoding: {}. Supported: utf-8, hex, b64, b64url", encoding))
                }
            }
            "decode" => {
                // decode(encoding) - decodes encoded string
                if args.len() != 1 {
                    return Err(format!("decode expects 1 argument (encoding), got {}", args.len()));
                }
                let encoding = args[0].as_str();

                match encoding.as_str() {
                    "b64" | "base64" => {
                        use base64::{Engine as _, engine::general_purpose};
                        let decoded = general_purpose::STANDARD.decode(self.value.as_bytes())
                            .map_err(|e| format!("Base64 decode error: {}", e))?;
                        let decoded_str = String::from_utf8(decoded)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    "b64url" | "base64url" => {
                        use base64::{Engine as _, engine::general_purpose};
                        let decoded = general_purpose::URL_SAFE_NO_PAD.decode(self.value.as_bytes())
                            .map_err(|e| format!("Base64 decode error: {}", e))?;
                        let decoded_str = String::from_utf8(decoded)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    "hex" => {
                        // Decode hex string to regular string
                        let bytes: Result<Vec<u8>, _> = (0..self.value.len())
                            .step_by(2)
                            .map(|i| u8::from_str_radix(&self.value[i..i+2], 16))
                            .collect();
                        let bytes = bytes.map_err(|e| format!("Hex decode error: {}", e))?;
                        let decoded_str = String::from_utf8(bytes)
                            .map_err(|e| format!("Invalid UTF-8 in decoded data: {}", e))?;
                        Ok(QValue::Str(QString::new(decoded_str)))
                    }
                    _ => Err(format!("Unknown encoding: {}. Supported: b64, b64url, hex", encoding))
                }
            }
            "fmt" => {
                // Format string with positional arguments
                // Supports: {}, {0}, {1}, {:.2}, {0:.2}, etc.
                let mut result = String::new();
                let mut chars = self.value.chars().peekable();
                let mut arg_index = 0;

                while let Some(ch) = chars.next() {
                    if ch == '{' {
                        if chars.peek() == Some(&'{') {
                            // Escaped brace {{
                            chars.next();
                            result.push('{');
                        } else {
                            // Parse placeholder: {}, {0}, {:.2}, {0:.2}
                            let mut placeholder = String::new();
                            while let Some(&next_ch) = chars.peek() {
                                if next_ch == '}' {
                                    chars.next();
                                    break;
                                }
                                placeholder.push(next_ch);
                                chars.next();
                            }

                            // Parse placeholder: [index][:spec]
                            let (index, format_spec) = if let Some(colon_pos) = placeholder.find(':') {
                                let idx_str = &placeholder[..colon_pos];
                                let spec = &placeholder[colon_pos + 1..];
                                if idx_str.is_empty() {
                                    (arg_index, Some(spec))
                                } else {
                                    (idx_str.parse::<usize>().map_err(|_| format!("Invalid placeholder index: {}", idx_str))?, Some(spec))
                                }
                            } else if placeholder.is_empty() {
                                (arg_index, None)
                            } else {
                                (placeholder.parse::<usize>().map_err(|_| format!("Invalid placeholder index: {}", placeholder))?, None)
                            };

                            // Get the argument
                            if index >= args.len() {
                                return Err(format!("Placeholder index {} out of range (have {} args)", index, args.len()));
                            }
                            let value = &args[index];

                            // Format the value
                            let formatted = if let Some(spec) = format_spec {
                                crate::format_value(value, spec)?
                            } else {
                                value.as_str()
                            };
                            result.push_str(&formatted);

                            // Only auto-increment if it was an empty placeholder
                            if placeholder.is_empty() || (!placeholder.contains(':') && placeholder.parse::<usize>().is_ok()) {
                                arg_index += 1;
                            }
                        }
                    } else if ch == '}' {
                        if chars.peek() == Some(&'}') {
                            // Escaped brace }}
                            chars.next();
                            result.push('}');
                        } else {
                            result.push('}');
                        }
                    } else {
                        result.push(ch);
                    }
                }

                Ok(QValue::Str(QString::new(result)))
            }
            "hash" => {
                if args.len() != 1 {
                    return Err(format!("hash expects 1 argument (algorithm name), got {}", args.len()));
                }
                let algorithm = args[0].as_str();

                use md5::{Md5, Digest};
                use sha1::Sha1;
                use sha2::{Sha256, Sha512};
                use crc32fast::Hasher as Crc32Hasher;

                let hash_result = match algorithm.as_str() {
                    "md5" => format!("{:x}", Md5::digest(self.value.as_bytes())),
                    "sha1" => format!("{:x}", Sha1::digest(self.value.as_bytes())),
                    "sha256" => format!("{:x}", Sha256::digest(self.value.as_bytes())),
                    "sha512" => format!("{:x}", Sha512::digest(self.value.as_bytes())),
                    "crc32" => {
                        let mut hasher = Crc32Hasher::new();
                        hasher.update(self.value.as_bytes());
                        format!("{:08x}", hasher.finalize())
                    }
                    _ => return Err(format!("Unknown hash algorithm '{}'. Supported: md5, sha1, sha256, sha512, crc32", algorithm)),
                };
                Ok(QValue::Str(QString::new(hash_result)))
            }
            "_str" => {
                if !args.is_empty() {
                    return Err(format!("_str expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self._str())))
            }
            "_rep" => {
                if !args.is_empty() {
                    return Err(format!("_rep expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self._rep())))
            }
            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            "split" => {
                // Split string by delimiter, returns array of strings
                if args.len() != 1 {
                    return Err(format!("split expects 1 argument, got {}", args.len()));
                }
                let delimiter = args[0].as_str();

                let parts: Vec<QValue> = if delimiter.is_empty() {
                    // Split into individual characters
                    self.value.chars()
                        .map(|c| QValue::Str(QString::new(c.to_string())))
                        .collect()
                } else {
                    self.value.split(&delimiter)
                        .map(|s| QValue::Str(QString::new(s.to_string())))
                        .collect()
                };

                Ok(QValue::Array(QArray::new(parts)))
            }
            "slice" => {
                // Return substring from start to end (exclusive)
                if args.len() != 2 {
                    return Err(format!("slice expects 2 arguments, got {}", args.len()));
                }
                let start = args[0].as_num()? as i64;
                let end = args[1].as_num()? as i64;
                let len = self.value.chars().count() as i64;

                // Handle negative indices
                let actual_start = if start < 0 {
                    (len + start).max(0) as usize
                } else {
                    start.min(len) as usize
                };

                let actual_end = if end < 0 {
                    (len + end).max(0) as usize
                } else {
                    end.min(len) as usize
                };

                if actual_start > actual_end {
                    return Ok(QValue::Str(QString::new(String::new())));
                }

                // Use chars() to handle Unicode properly
                let result: String = self.value.chars()
                    .skip(actual_start)
                    .take(actual_end - actual_start)
                    .collect();

                Ok(QValue::Str(QString::new(result)))
            }
            _ => Err(format!("Unknown method '{}' for str type", method_name)),
        }
    }
}

impl QObj for QString {
    fn cls(&self) -> String {
        "Str".to_string()
    }

    fn q_type(&self) -> &'static str {
        "str"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "str" || type_name == "obj"
    }

    fn _str(&self) -> String {
        self.value.clone()
    }

    fn _rep(&self) -> String {
        // In REPL, show strings with quotes
        format!("\"{}\"", self.value)
    }

    fn _doc(&self) -> String {
        "String type - represents text".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QNil;

impl QObj for QNil {
    fn cls(&self) -> String {
        "Nil".to_string()
    }

    fn q_type(&self) -> &'static str {
        "nil"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "nil" || type_name == "obj"
    }

    fn _str(&self) -> String {
        "nil".to_string()
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        "Nil type - represents absence of value".to_string()
    }

    fn _id(&self) -> u64 {
        0 // nil is a singleton, always has ID 0
    }
}

#[derive(Debug, Clone)]
pub struct QFun {
    pub name: String,
    pub parent_type: String,
    pub doc: String,
    pub id: u64,
}

impl QFun {
    pub fn new(name: String, parent_type: String, doc: String) -> Self {
        QFun {
            name,
            parent_type,
            doc,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // All QFun methods are QObj trait methods
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }
        Err(format!("Fun has no method '{}'", method_name))
    }
}

impl QObj for QFun {
    fn cls(&self) -> String {
        "Fun".to_string()
    }

    fn q_type(&self) -> &'static str {
        "fun"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "fun" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("<fun {}.{}>", self.parent_type, self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        self.doc.clone()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QUserFun {
    pub name: Option<String>,  // None for anonymous functions
    pub params: Vec<String>,
    pub body: String,  // Store body as string to re-eval
    pub doc: Option<String>,   // Docstring extracted from first string literal in body
    #[allow(dead_code)]
    pub id: u64,
}

impl QUserFun {
    pub fn new(name: Option<String>, params: Vec<String>, body: String) -> Self {
        QUserFun {
            name,
            params,
            body,
            doc: None,
            id: next_object_id(),
        }
    }

    pub fn with_doc(name: Option<String>, params: Vec<String>, body: String, doc: Option<String>) -> Self {
        QUserFun {
            name,
            params,
            body,
            doc,
            id: next_object_id(),
        }
    }
}

impl QObj for QUserFun {
    fn cls(&self) -> String {
        "UserFun".to_string()
    }

    fn q_type(&self) -> &'static str {
        "fun"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "fun" || type_name == "obj"
    }

    fn _str(&self) -> String {
        match &self.name {
            Some(name) => format!("<fun {}>", name),
            None => "<fun <anonymous>>".to_string(),
        }
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // Return docstring if available
        if let Some(ref doc) = self.doc {
            return doc.clone();
        }

        // Otherwise return default doc
        match &self.name {
            Some(name) => format!("User-defined function: {}", name),
            None => "Anonymous function".to_string(),
        }
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl QUserFun {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "_str" => Ok(QValue::Str(QString::new(self._str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_id" => Ok(QValue::Num(QNum::new(self._id() as f64))),
            _ => Err(format!("UserFun has no method '{}'", method_name)),
        }
    }
}

#[derive(Debug, Clone)]
pub struct QModule {
    pub name: String,
    pub members: Rc<RefCell<HashMap<String, QValue>>>,
    pub doc: Option<String>,  // Module docstring from first string literal in file
    #[allow(dead_code)]
    pub id: u64,
    #[allow(dead_code)]
    pub source_path: Option<String>,  // Track source file for cache updates
}

impl QModule {
    pub fn new(name: String, members: HashMap<String, QValue>) -> Self {
        QModule {
            name,
            members: Rc::new(RefCell::new(members)),
            doc: None,
            id: next_object_id(),
            source_path: None,
        }
    }

    pub fn with_doc(name: String, members: HashMap<String, QValue>, source_path: Option<String>, doc: Option<String>) -> Self {
        QModule {
            name,
            members: Rc::new(RefCell::new(members)),
            doc,
            id: next_object_id(),
            source_path,
        }
    }

    pub fn get_member(&self, member_name: &str) -> Option<QValue> {
        self.members.borrow().get(member_name).cloned()
    }
}

impl QObj for QModule {
    fn cls(&self) -> String {
        "Module".to_string()
    }

    fn q_type(&self) -> &'static str {
        "module"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "module" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("<module {}>", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        if let Some(ref doc) = self.doc {
            doc.clone()
        } else {
            format!("Module: {}", self.name)
        }
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QArray {
    pub elements: Vec<QValue>,
    #[allow(dead_code)]
    pub id: u64,
}

impl QArray {
    pub fn new(elements: Vec<QValue>) -> Self {
        QArray {
            elements,
            id: next_object_id(),
        }
    }

    pub fn len(&self) -> usize {
        self.elements.len()
    }

    pub fn get(&self, index: usize) -> Option<&QValue> {
        self.elements.get(index)
    }

    #[allow(dead_code)]
    pub fn set(&mut self, index: usize, value: QValue) -> Result<(), String> {
        if index < self.elements.len() {
            self.elements[index] = value;
            Ok(())
        } else {
            Err(format!("Index {} out of bounds for array of length {}", index, self.elements.len()))
        }
    }

    #[allow(dead_code)]
    pub fn push(&mut self, value: QValue) {
        self.elements.push(value);
    }

    #[allow(dead_code)]
    pub fn pop(&mut self) -> Option<QValue> {
        self.elements.pop()
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => {
                if !args.is_empty() {
                    return Err(format!("len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.elements.len() as f64)))
            }
            "push" => {
                // Returns a new array with the element added to the end
                if args.len() != 1 {
                    return Err(format!("push expects 1 argument, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();
                new_elements.push(args[0].clone());
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "pop" => {
                // Returns a new array with the last element removed
                if !args.is_empty() {
                    return Err(format!("pop expects 0 arguments, got {}", args.len()));
                }
                if self.elements.is_empty() {
                    return Err("Cannot pop from empty array".to_string());
                }
                let mut new_elements = self.elements.clone();
                new_elements.pop();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "shift" => {
                // Returns a new array with the first element removed
                if !args.is_empty() {
                    return Err(format!("shift expects 0 arguments, got {}", args.len()));
                }
                if self.elements.is_empty() {
                    return Err("Cannot shift from empty array".to_string());
                }
                let new_elements = self.elements[1..].to_vec();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "unshift" => {
                // Returns a new array with the element added to the beginning
                if args.len() != 1 {
                    return Err(format!("unshift expects 1 argument, got {}", args.len()));
                }
                let mut new_elements = vec![args[0].clone()];
                new_elements.extend(self.elements.clone());
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "get" => {
                // Get element at index
                if args.len() != 1 {
                    return Err(format!("get expects 1 argument, got {}", args.len()));
                }
                let index = args[0].as_num()? as usize;
                self.elements.get(index)
                    .cloned()
                    .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, self.elements.len()))
            }
            "first" => {
                // Get first element
                if !args.is_empty() {
                    return Err(format!("first expects 0 arguments, got {}", args.len()));
                }
                self.elements.first()
                    .cloned()
                    .ok_or_else(|| "Cannot get first element of empty array".to_string())
            }
            "last" => {
                // Get last element
                if !args.is_empty() {
                    return Err(format!("last expects 0 arguments, got {}", args.len()));
                }
                self.elements.last()
                    .cloned()
                    .ok_or_else(|| "Cannot get last element of empty array".to_string())
            }
            "reverse" => {
                // Return new array with elements in reverse order
                if !args.is_empty() {
                    return Err(format!("reverse expects 0 arguments, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();
                new_elements.reverse();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "slice" => {
                // Return subarray from start to end (exclusive)
                if args.len() != 2 {
                    return Err(format!("slice expects 2 arguments, got {}", args.len()));
                }
                let start = args[0].as_num()? as i64;
                let end = args[1].as_num()? as i64;
                let len = self.elements.len() as i64;

                // Handle negative indices
                let actual_start = if start < 0 {
                    (len + start).max(0) as usize
                } else {
                    start.min(len) as usize
                };

                let actual_end = if end < 0 {
                    (len + end).max(0) as usize
                } else {
                    end.min(len) as usize
                };

                if actual_start > actual_end {
                    return Ok(QValue::Array(QArray::new(Vec::new())));
                }

                let new_elements = self.elements[actual_start..actual_end].to_vec();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "concat" => {
                // Combine this array with another array
                if args.len() != 1 {
                    return Err(format!("concat expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Array(other) => {
                        let mut new_elements = self.elements.clone();
                        new_elements.extend(other.elements.clone());
                        Ok(QValue::Array(QArray::new(new_elements)))
                    }
                    _ => Err("concat expects an array argument".to_string())
                }
            }
            "join" => {
                // Convert array to string with separator
                if args.len() != 1 {
                    return Err(format!("join expects 1 argument, got {}", args.len()));
                }
                let separator = args[0].as_str();
                let strings: Vec<String> = self.elements.iter()
                    .map(|v| v.as_obj()._str())
                    .collect();
                Ok(QValue::Str(QString::new(strings.join(&separator))))
            }
            "contains" => {
                // Check if array contains a value
                if args.len() != 1 {
                    return Err(format!("contains expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                for elem in &self.elements {
                    // Use Quest's equality comparison
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Bool(QBool::new(true)));
                    }
                }
                Ok(QValue::Bool(QBool::new(false)))
            }
            "index_of" => {
                // Find index of first occurrence of value
                if args.len() != 1 {
                    return Err(format!("index_of expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                for (i, elem) in self.elements.iter().enumerate() {
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Num(QNum::new(i as f64)));
                    }
                }
                Ok(QValue::Num(QNum::new(-1.0)))
            }
            "count" => {
                // Count occurrences of value
                if args.len() != 1 {
                    return Err(format!("count expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                let mut count = 0;
                for elem in &self.elements {
                    if values_equal(elem, search_value) {
                        count += 1;
                    }
                }
                Ok(QValue::Num(QNum::new(count as f64)))
            }
            "empty" => {
                // Check if array is empty
                if !args.is_empty() {
                    return Err(format!("empty expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.elements.is_empty())))
            }
            "sort" => {
                // Return sorted array (ascending order)
                if !args.is_empty() {
                    return Err(format!("sort expects 0 arguments, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();

                // Sort with type-aware comparison
                new_elements.sort_by(|a, b| {
                    compare_values(a, b).unwrap_or(std::cmp::Ordering::Equal)
                });

                Ok(QValue::Array(QArray::new(new_elements)))
            }
            _ => Err(format!("Array has no method '{}'", method_name)),
        }
    }
}

impl QObj for QArray {
    fn cls(&self) -> String {
        "Array".to_string()
    }

    fn q_type(&self) -> &'static str {
        "array"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "array" || type_name == "obj"
    }

    fn _str(&self) -> String {
        let elements: Vec<String> = self.elements.iter().map(|e| e.as_str()).collect();
        format!("[{}]", elements.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Array with {} elements", self.elements.len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

#[derive(Debug, Clone)]
pub struct QDict {
    pub map: HashMap<String, QValue>,
    #[allow(dead_code)]
    pub id: u64,
}

impl QDict {
    pub fn new(map: HashMap<String, QValue>) -> Self {
        QDict {
            map,
            id: next_object_id(),
        }
    }

    pub fn get(&self, key: &str) -> Option<&QValue> {
        self.map.get(key)
    }

    pub fn has(&self, key: &str) -> bool {
        self.map.contains_key(key)
    }

    pub fn keys(&self) -> Vec<String> {
        self.map.keys().cloned().collect()
    }

    pub fn values(&self) -> Vec<QValue> {
        self.map.values().cloned().collect()
    }

    pub fn len(&self) -> usize {
        self.map.len()
    }

    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &_args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => Ok(QValue::Num(QNum::new(self.len() as f64))),
            "keys" => {
                let keys: Vec<QValue> = self.keys().iter()
                    .map(|k| QValue::Str(QString::new(k.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(keys)))
            }
            "values" => {
                Ok(QValue::Array(QArray::new(self.values())))
            }
            "has" => {
                if _args.len() != 1 {
                    return Err(format!("has() expects 1 argument, got {}", _args.len()));
                }
                let key = _args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.has(&key))))
            }
            "get" => {
                // Get value for key, returns nil if not found (or default if provided)
                if _args.is_empty() || _args.len() > 2 {
                    return Err(format!("get() expects 1 or 2 arguments, got {}", _args.len()));
                }
                let key = _args[0].as_str();
                match self.get(&key) {
                    Some(value) => Ok(value.clone()),
                    None => {
                        // Return default if provided, else nil
                        if _args.len() == 2 {
                            Ok(_args[1].clone())
                        } else {
                            Ok(QValue::Nil(QNil))
                        }
                    }
                }
            }
            "set" => {
                // Returns new dict with key set to value (immutable)
                if _args.len() != 2 {
                    return Err(format!("set() expects 2 arguments (key, value), got {}", _args.len()));
                }
                let key = _args[0].as_str();
                let value = _args[1].clone();

                let mut new_map = self.map.clone();
                new_map.insert(key, value);
                Ok(QValue::Dict(QDict::new(new_map)))
            }
            "remove" => {
                // Returns new dict with key removed (immutable)
                if _args.len() != 1 {
                    return Err(format!("remove() expects 1 argument, got {}", _args.len()));
                }
                let key = _args[0].as_str();

                let mut new_map = self.map.clone();
                new_map.remove(&key);
                Ok(QValue::Dict(QDict::new(new_map)))
            }
            _ => Err(format!("Dict has no method '{}'", method_name)),
        }
    }
}

impl QObj for QDict {
    fn cls(&self) -> String {
        "Dict".to_string()
    }

    fn q_type(&self) -> &'static str {
        "dict"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "dict" || type_name == "obj"
    }

    fn _str(&self) -> String {
        let mut pairs: Vec<String> = self.map.iter()
            .map(|(k, v)| format!("{}: {}", k, v.as_str()))
            .collect();
        pairs.sort();
        format!("{{{}}}", pairs.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Dict with {} entries", self.map.len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

pub fn get_method_doc(parent_type: &str, method_name: &str) -> String {
    match parent_type {
        "Fun" => match method_name {
            "_doc" => "Returns the documentation string for this function".to_string(),
            "_str" => "Returns the string representation of this function".to_string(),
            "_rep" => "Returns the REPL representation of this function".to_string(),
            "_id" => "Returns the unique ID of this function".to_string(),
            _ => format!("Unknown method: {}", method_name),
        },
        "Num" => match method_name {
            "plus" => "Adds a number to this number".to_string(),
            "minus" => "Subtracts a number from this number".to_string(),
            "times" => "Multiplies this number by another".to_string(),
            "div" => "Divides this number by another".to_string(),
            "mod" => "Returns the modulo of this number with another".to_string(),
            "eq" => "Checks if this number equals another".to_string(),
            "neq" => "Checks if this number does not equal another".to_string(),
            "gt" => "Checks if this number is greater than another".to_string(),
            "lt" => "Checks if this number is less than another".to_string(),
            "gte" => "Checks if this number is greater than or equal to another".to_string(),
            "lte" => "Checks if this number is less than or equal to another".to_string(),
            "_id" => "Returns the unique ID of this number".to_string(),
            _ => format!("Unknown method: {}", method_name),
        },
        "Bool" => match method_name {
            "eq" => "Checks if this boolean equals another".to_string(),
            "neq" => "Checks if this boolean does not equal another".to_string(),
            "_id" => "Returns the unique ID of this boolean".to_string(),
            _ => format!("Unknown method: {}", method_name),
        },
        "Str" => match method_name {
            "len" => "Returns the length of the string".to_string(),
            "concat" => "Concatenates this string with another".to_string(),
            "upper" => "Converts the string to uppercase".to_string(),
            "lower" => "Converts the string to lowercase".to_string(),
            "capitalize" => "Capitalizes the first character and lowercases the rest".to_string(),
            "title" => "Converts the string to title case".to_string(),
            "trim" => "Removes leading and trailing whitespace".to_string(),
            "ltrim" => "Removes leading whitespace".to_string(),
            "rtrim" => "Removes trailing whitespace".to_string(),
            "isalnum" => "Checks if all characters are alphanumeric".to_string(),
            "isalpha" => "Checks if all characters are alphabetic".to_string(),
            "isascii" => "Checks if all characters are ASCII".to_string(),
            "isdigit" => "Checks if all characters are digits".to_string(),
            "isnumeric" => "Checks if all characters are numeric".to_string(),
            "islower" => "Checks if all alphabetic characters are lowercase".to_string(),
            "isupper" => "Checks if all alphabetic characters are uppercase".to_string(),
            "isspace" => "Checks if all characters are whitespace".to_string(),
            "count" => "Counts occurrences of a substring".to_string(),
            "endswith" => "Checks if the string ends with a suffix".to_string(),
            "startswith" => "Checks if the string starts with a prefix".to_string(),
            "eq" => "Checks if this string equals another".to_string(),
            "neq" => "Checks if this string does not equal another".to_string(),
            "_id" => "Returns the unique ID of this string".to_string(),
            _ => format!("Unknown method: {}", method_name),
        },
        _ => "Type does not support methods".to_string(),
    }
}

// ============================================================================
// Type System: QType, QStruct, QTrait
// ============================================================================

/// Field definition in a type
#[derive(Debug, Clone)]
pub struct FieldDef {
    pub name: String,
    pub type_annotation: Option<String>,  // "num", "str", etc.
    pub optional: bool,                    // true if field is optional (num?: x)
}

impl FieldDef {
    pub fn new(name: String, type_annotation: Option<String>, optional: bool) -> Self {
        FieldDef {
            name,
            type_annotation,
            optional,
        }
    }
}

/// Type definition (created by `type` keyword)
#[derive(Debug, Clone)]
pub struct QType {
    pub name: String,
    pub fields: Vec<FieldDef>,
    pub methods: HashMap<String, QUserFun>,
    pub static_methods: HashMap<String, QUserFun>,
    pub implemented_traits: Vec<String>,
    pub doc: Option<String>,  // Docstring from first string literal after type declaration
    pub id: u64,
}

impl QType {
    pub fn with_doc(name: String, fields: Vec<FieldDef>, doc: Option<String>) -> Self {
        QType {
            name,
            fields,
            methods: HashMap::new(),
            static_methods: HashMap::new(),
            implemented_traits: Vec::new(),
            doc,
            id: next_object_id(),
        }
    }

    pub fn add_method(&mut self, name: String, func: QUserFun) {
        self.methods.insert(name, func);
    }

    pub fn add_static_method(&mut self, name: String, func: QUserFun) {
        self.static_methods.insert(name, func);
    }

    pub fn add_trait(&mut self, trait_name: String) {
        if !self.implemented_traits.contains(&trait_name) {
            self.implemented_traits.push(trait_name);
        }
    }

    pub fn get_method(&self, method_name: &str) -> Option<&QUserFun> {
        self.methods.get(method_name)
    }

    pub fn get_static_method(&self, method_name: &str) -> Option<&QUserFun> {
        self.static_methods.get(method_name)
    }
}

impl QObj for QType {
    fn cls(&self) -> String {
        "Type".to_string()
    }

    fn q_type(&self) -> &'static str {
        "type"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "type" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("type {}", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // If docstring is available, return it followed by field info
        let mut doc = if let Some(ref docstring) = self.doc {
            format!("{}\n\n", docstring)
        } else {
            format!("Type definition: {}\n", self.name)
        };

        // Add field information
        if !self.fields.is_empty() {
            let field_docs: Vec<String> = self.fields.iter().map(|f| {
                let optional_marker = if f.optional { "?" } else { "" };
                let type_prefix = if let Some(ref t) = f.type_annotation {
                    format!("{}{}: ", t, optional_marker)
                } else {
                    String::new()
                };
                format!("  {}{}", type_prefix, f.name)
            }).collect();
            doc.push_str(&format!("Fields:\n{}", field_docs.join("\n")));
        }

        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Struct instance (an instance of a QType)
#[derive(Debug, Clone)]
pub struct QStruct {
    pub type_name: String,
    #[allow(dead_code)]
    pub type_id: u64,
    pub fields: HashMap<String, QValue>,
    #[allow(dead_code)]
    pub id: u64,
}

impl QStruct {
    pub fn new(type_name: String, type_id: u64, fields: HashMap<String, QValue>) -> Self {
        QStruct {
            type_name,
            type_id,
            fields,
            id: next_object_id(),
        }
    }

    pub fn get_field(&self, name: &str) -> Option<&QValue> {
        self.fields.get(name)
    }
}

impl QObj for QStruct {
    fn cls(&self) -> String {
        self.type_name.clone()
    }

    fn q_type(&self) -> &'static str {
        "struct"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == self.type_name || type_name == "struct" || type_name == "obj"
    }

    fn _str(&self) -> String {
        let fields_str: Vec<String> = self.fields
            .iter()
            .map(|(k, v)| format!("{}: {}", k, v.as_obj()._str()))
            .collect();
        format!("{}{{ {} }}", self.type_name, fields_str.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Instance of type {}", self.type_name)
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Trait method signature
#[derive(Debug, Clone)]
pub struct TraitMethod {
    pub name: String,
    pub parameters: Vec<String>,
    #[allow(dead_code)]
    pub return_type: Option<String>,
}

impl TraitMethod {
    pub fn new(name: String, parameters: Vec<String>, return_type: Option<String>) -> Self {
        TraitMethod {
            name,
            parameters,
            return_type,
        }
    }
}

/// Trait definition
#[derive(Debug, Clone)]
pub struct QTrait {
    pub name: String,
    pub required_methods: Vec<TraitMethod>,
    pub doc: Option<String>,  // Docstring from first string literal after trait declaration
    #[allow(dead_code)]
    pub id: u64,
}

impl QTrait {
    pub fn with_doc(name: String, required_methods: Vec<TraitMethod>, doc: Option<String>) -> Self {
        QTrait {
            name,
            required_methods,
            doc,
            id: next_object_id(),
        }
    }
}

impl QObj for QTrait {
    fn cls(&self) -> String {
        "Trait".to_string()
    }

    fn q_type(&self) -> &'static str {
        "trait"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "trait" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("trait {}", self.name)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        // If docstring is available, return it followed by method info
        let mut doc = if let Some(ref docstring) = self.doc {
            format!("{}\n\n", docstring)
        } else {
            format!("Trait definition: {}\n", self.name)
        };

        // Add required methods information
        if !self.required_methods.is_empty() {
            let method_docs: Vec<String> = self.required_methods.iter().map(|m| {
                let params = m.parameters.join(", ");
                let return_annotation = if let Some(ref ret) = m.return_type {
                    format!(" -> {}", ret)
                } else {
                    String::new()
                };
                format!("  fun {}({}){}", m.name, params, return_annotation)
            }).collect();
            doc.push_str(&format!("Required methods:\n{}", method_docs.join("\n")));
        }

        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// Exception type for error handling
#[derive(Debug, Clone)]
pub struct QException {
    pub exception_type: String,
    pub message: String,
    pub line: Option<usize>,
    pub file: Option<String>,
    pub stack: Vec<String>,
    pub cause: Option<Box<QException>>,
    pub id: u64,
}

impl QException {
    pub fn new(exception_type: String, message: String, line: Option<usize>, file: Option<String>) -> Self {
        QException {
            exception_type,
            message,
            line,
            file,
            stack: Vec::new(),
            cause: None,
            id: next_object_id(),
        }
    }

    #[allow(dead_code)]
    pub fn with_cause(exception_type: String, message: String, cause: QException) -> Self {
        QException {
            exception_type,
            message,
            line: None,
            file: None,
            stack: Vec::new(),
            cause: Some(Box::new(cause)),
            id: next_object_id(),
        }
    }

    #[allow(dead_code)]
    pub fn add_stack_frame(&mut self, frame: String) {
        self.stack.push(frame);
    }
}

impl QObj for QException {
    fn cls(&self) -> String {
        "Exception".to_string()
    }

    fn q_type(&self) -> &'static str {
        "exception"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "exception" || type_name == "obj"
    }

    fn _str(&self) -> String {
        format!("{}: {}", self.exception_type, self.message)
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        let mut doc = format!("Exception: {}\nMessage: {}", self.exception_type, self.message);
        if let Some(ref line) = self.line {
            doc.push_str(&format!("\nLine: {}", line));
        }
        if let Some(ref file) = self.file {
            doc.push_str(&format!("\nFile: {}", file));
        }
        if !self.stack.is_empty() {
            doc.push_str("\nStack trace:\n");
            for frame in &self.stack {
                doc.push_str(&format!("  {}\n", frame));
            }
        }
        if let Some(ref cause) = self.cause {
            doc.push_str(&format!("\nCaused by: {}", cause._str()));
        }
        doc
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl QException {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "exc_type" | "type" => Ok(QValue::Str(QString::new(self.exception_type.clone()))),
            "message" => Ok(QValue::Str(QString::new(self.message.clone()))),
            "stack" => {
                let stack_arr = self.stack.iter()
                    .map(|s| QValue::Str(QString::new(s.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(stack_arr)))
            },
            "line" => {
                if let Some(line) = self.line {
                    Ok(QValue::Num(QNum::new(line as f64)))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "file" => {
                if let Some(ref file) = self.file {
                    Ok(QValue::Str(QString::new(file.clone())))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "cause" => {
                if let Some(ref cause) = self.cause {
                    Ok(QValue::Exception((**cause).clone()))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            },
            "_str" => Ok(QValue::Str(QString::new(self._str()))),
            "_rep" => Ok(QValue::Str(QString::new(self._rep()))),
            "_doc" => Ok(QValue::Str(QString::new(self._doc()))),
            "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
            _ => Err(format!("Exception has no method '{}'", method_name))
        }
    }
}
