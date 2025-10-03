use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::rc::Rc;
use std::cell::RefCell;

// Submodules
mod num;
mod bool;
mod string;
mod bytes;
mod nil;
mod function;
mod module;
mod array;
mod dict;
mod user_types;
mod exception;
mod uuid;

// Re-export all types
pub use num::QNum;
pub use bool::QBool;
pub use string::QString;
pub use bytes::QBytes;
pub use nil::QNil;
pub use function::{QFun, QUserFun, create_fn};
pub use module::QModule;
pub use array::QArray;
pub use dict::QDict;
pub use user_types::{FieldDef, QType, QStruct, QTrait, TraitMethod};
pub use exception::QException;
pub use uuid::QUuid;

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
    Bytes(QBytes),
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
    Uuid(QUuid),
    // Time types (from std/time module)
    Timestamp(crate::modules::time::QTimestamp),
    Zoned(crate::modules::time::QZoned),
    Date(crate::modules::time::QDate),
    Time(crate::modules::time::QTime),
    Span(crate::modules::time::QSpan),
    // Serial port (from std/serial module)
    SerialPort(crate::modules::serial::QSerialPort),
    // SQLite database (from std/db/sqlite module)
    SqliteConnection(crate::modules::db::sqlite::QSqliteConnection),
    SqliteCursor(crate::modules::db::sqlite::QSqliteCursor),
    // PostgreSQL database (from std/db/postgres module)
    PostgresConnection(crate::modules::db::postgres::QPostgresConnection),
    PostgresCursor(crate::modules::db::postgres::QPostgresCursor),
    // MySQL database (from std/db/mysql module)
    MysqlConnection(crate::modules::db::mysql::QMysqlConnection),
    MysqlCursor(crate::modules::db::mysql::QMysqlCursor),
}

impl QValue {
    pub fn as_obj(&self) -> &dyn QObj {
        match self {
            QValue::Num(n) => n,
            QValue::Bool(b) => b,
            QValue::Str(s) => s,
            QValue::Bytes(b) => b,
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
            QValue::Uuid(u) => u,
            QValue::Timestamp(ts) => ts,
            QValue::Zoned(z) => z,
            QValue::Date(d) => d,
            QValue::Time(t) => t,
            QValue::Span(s) => s,
            QValue::SerialPort(sp) => sp,
            QValue::SqliteConnection(conn) => conn,
            QValue::SqliteCursor(cursor) => cursor,
            QValue::PostgresConnection(conn) => conn,
            QValue::PostgresCursor(cursor) => cursor,
            QValue::MysqlConnection(conn) => conn,
            QValue::MysqlCursor(cursor) => cursor,
        }
    }

    pub fn as_num(&self) -> Result<f64, String> {
        match self {
            QValue::Num(n) => Ok(n.value),
            QValue::Bool(b) => Ok(if b.value { 1.0 } else { 0.0 }),
            QValue::Str(s) => s.value.parse::<f64>()
                .map_err(|_| format!("Cannot convert string '{}' to number", s.value)),
            QValue::Bytes(_) => Err("Cannot convert bytes to number".to_string()),
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
            QValue::Uuid(_) => Err("Cannot convert uuid to number".to_string()),
            QValue::Timestamp(ts) => Ok(ts.timestamp.as_second() as f64),
            QValue::Zoned(_) => Err("Cannot convert zoned datetime to number".to_string()),
            QValue::Date(_) => Err("Cannot convert date to number".to_string()),
            QValue::Time(_) => Err("Cannot convert time to number".to_string()),
            QValue::Span(_) => Err("Cannot convert span to number".to_string()),
            QValue::SerialPort(_) => Err("Cannot convert serial port to number".to_string()),
            QValue::SqliteConnection(_) => Err("Cannot convert sqlite connection to number".to_string()),
            QValue::SqliteCursor(_) => Err("Cannot convert sqlite cursor to number".to_string()),
            QValue::PostgresConnection(_) => Err("Cannot convert postgres connection to number".to_string()),
            QValue::PostgresCursor(_) => Err("Cannot convert postgres cursor to number".to_string()),
            QValue::MysqlConnection(_) => Err("Cannot convert mysql connection to number".to_string()),
            QValue::MysqlCursor(_) => Err("Cannot convert mysql cursor to number".to_string()),
        }
    }

    pub fn as_bool(&self) -> bool {
        match self {
            QValue::Num(n) => n.value != 0.0,
            QValue::Bool(b) => b.value,
            QValue::Str(s) => !s.value.is_empty(),
            QValue::Bytes(b) => !b.data.is_empty(),  // Empty bytes are falsy
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
            QValue::Uuid(_) => true, // UUIDs are truthy
            QValue::Timestamp(_) => true, // Timestamps are truthy
            QValue::Zoned(_) => true, // Zoned datetimes are truthy
            QValue::Date(_) => true, // Dates are truthy
            QValue::Time(_) => true, // Times are truthy
            QValue::Span(_) => true, // Spans are truthy
            QValue::SerialPort(_) => true, // Serial ports are truthy
            QValue::SqliteConnection(_) => true, // SQLite connections are truthy
            QValue::SqliteCursor(_) => true, // SQLite cursors are truthy
            QValue::PostgresConnection(_) => true, // Postgres connections are truthy
            QValue::PostgresCursor(_) => true, // Postgres cursors are truthy
            QValue::MysqlConnection(_) => true, // MySQL connections are truthy
            QValue::MysqlCursor(_) => true, // MySQL cursors are truthy
        }
    }

    pub fn as_str(&self) -> String {
        match self {
            QValue::Num(n) => n._str(),
            QValue::Bool(b) => b._str(),
            QValue::Str(s) => s.value.clone(),
            QValue::Bytes(b) => b._str(),
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
            QValue::Uuid(u) => u._str(),
            QValue::Timestamp(ts) => ts._str(),
            QValue::Zoned(z) => z._str(),
            QValue::Date(d) => d._str(),
            QValue::Time(t) => t._str(),
            QValue::Span(s) => s._str(),
            QValue::SerialPort(sp) => sp._str(),
            QValue::SqliteConnection(conn) => conn._str(),
            QValue::SqliteCursor(cursor) => cursor._str(),
            QValue::PostgresConnection(conn) => conn._str(),
            QValue::PostgresCursor(cursor) => cursor._str(),
            QValue::MysqlConnection(conn) => conn._str(),
            QValue::MysqlCursor(cursor) => cursor._str(),
        }
    }

    pub fn q_type(&self) -> &'static str {
        match self {
            QValue::Num(_) => "Num",
            QValue::Bool(_) => "Bool",
            QValue::Str(_) => "Str",
            QValue::Bytes(_) => "Bytes",
            QValue::Nil(_) => "Nil",
            QValue::Fun(_) => "Fun",
            QValue::UserFun(_) => "UserFun",
            QValue::Module(_) => "Module",
            QValue::Array(_) => "Array",
            QValue::Dict(_) => "Dict",
            QValue::Type(_) => "Type",
            QValue::Struct(_) => "Struct",
            QValue::Trait(_) => "Trait",
            QValue::Exception(_) => "Exception",
            QValue::Uuid(_) => "Uuid",
            QValue::Timestamp(_) => "Timestamp",
            QValue::Zoned(_) => "Zoned",
            QValue::Date(_) => "Date",
            QValue::Time(_) => "Time",
            QValue::Span(_) => "Span",
            QValue::SerialPort(_) => "SerialPort",
            QValue::SqliteConnection(_) => "SqliteConnection",
            QValue::SqliteCursor(_) => "SqliteCursor",
            QValue::PostgresConnection(_) => "PostgresConnection",
            QValue::PostgresCursor(_) => "PostgresCursor",
            QValue::MysqlConnection(_) => "MysqlConnection",
            QValue::MysqlCursor(_) => "MysqlCursor",
        }
    }
}

// Higher-order array methods that need scope access
pub fn call_array_higher_order_method<F>(
    arr: &QArray,
    method_name: &str,
    args: Vec<QValue>,
    scope: &mut crate::scope::Scope,
    call_user_fn: F
) -> Result<QValue, String>
where
    F: Fn(&QUserFun, Vec<QValue>, &mut crate::scope::Scope) -> Result<QValue, String>
{
    match method_name {
        "map" => {
            // map(fn) - Transform each element
            if args.len() != 1 {
                return Err(format!("map expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("map expects a function argument".to_string())
                };
                new_elements.push(result);
            }
            Ok(QValue::Array(QArray::new(new_elements)))
        }
        "filter" => {
            // filter(fn) - Select elements matching predicate
            if args.len() != 1 {
                return Err(format!("filter expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("filter expects a function argument".to_string())
                };

                if result.as_bool() {
                    new_elements.push(elem.clone());
                }
            }
            Ok(QValue::Array(QArray::new(new_elements)))
        }
        "each" => {
            // each(fn) - Iterate over elements (for side effects)
            if args.len() != 1 {
                return Err(format!("each expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (idx, elem) in arr.elements.iter().enumerate() {
                match func {
                    QValue::UserFun(user_fn) => {
                        // Call with element and index
                        if user_fn.params.len() == 1 {
                            call_user_fn(user_fn, vec![elem.clone()], scope)?;
                        } else if user_fn.params.len() == 2 {
                            call_user_fn(user_fn, vec![elem.clone(), QValue::Num(QNum::new(idx as f64))], scope)?;
                        } else {
                            return Err("each function must accept 1 or 2 parameters (element, index)".to_string());
                        }
                    }
                    _ => return Err("each expects a function argument".to_string())
                };
            }
            Ok(QValue::Nil(QNil))
        }
        "reduce" => {
            // reduce(fn, initial) - Reduce to single value
            if args.len() != 2 {
                return Err(format!("reduce expects 2 arguments (function, initial), got {}", args.len()));
            }
            let func = &args[0];
            let mut accumulator = args[1].clone();

            for elem in &arr.elements {
                accumulator = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![accumulator, elem.clone()], scope)?
                    }
                    _ => return Err("reduce expects a function argument".to_string())
                };
            }
            Ok(accumulator)
        }
        "any" => {
            // any(fn) - Check if any element matches
            if args.len() != 1 {
                return Err(format!("any expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("any expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(QValue::Bool(QBool::new(true)));
                }
            }
            Ok(QValue::Bool(QBool::new(false)))
        }
        "all" => {
            // all(fn) - Check if all elements match
            if args.len() != 1 {
                return Err(format!("all expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("all expects a function argument".to_string())
                };

                if !result.as_bool() {
                    return Ok(QValue::Bool(QBool::new(false)));
                }
            }
            Ok(QValue::Bool(QBool::new(true)))
        }
        "find" => {
            // find(fn) - Find first matching element
            if args.len() != 1 {
                return Err(format!("find expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for elem in &arr.elements {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("find expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(elem.clone());
                }
            }
            Ok(QValue::Nil(QNil))
        }
        "find_index" => {
            // find_index(fn) - Find index of first match
            if args.len() != 1 {
                return Err(format!("find_index expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (idx, elem) in arr.elements.iter().enumerate() {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("find_index expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(QValue::Num(QNum::new(idx as f64)));
                }
            }
            Ok(QValue::Num(QNum::new(-1.0)))
        }
        _ => Err(format!("Unknown array higher-order method: {}", method_name))
    }
}

// Higher-order dict methods that need scope access
pub fn call_dict_higher_order_method<F>(
    dict: &QDict,
    method_name: &str,
    args: Vec<QValue>,
    scope: &mut crate::scope::Scope,
    call_user_fn: F
) -> Result<QValue, String>
where
    F: Fn(&QUserFun, Vec<QValue>, &mut crate::scope::Scope) -> Result<QValue, String>
{
    match method_name {
        "each" => {
            // each(fn) - Iterate over key-value pairs
            if args.len() != 1 {
                return Err(format!("each expects 1 argument (function), got {}", args.len()));
            }
            let func = &args[0];

            for (key, value) in &dict.map {
                match func {
                    QValue::UserFun(user_fn) => {
                        // Call with key and value
                        if user_fn.params.len() == 2 {
                            call_user_fn(user_fn, vec![QValue::Str(QString::new(key.clone())), value.clone()], scope)?;
                        } else {
                            return Err("dict.each function must accept 2 parameters (key, value)".to_string());
                        }
                    }
                    _ => return Err("each expects a function argument".to_string())
                };
            }
            Ok(QValue::Nil(QNil))
        }
        _ => Err(format!("Unknown dict higher-order method: {}", method_name))
    }
}

/// Validate that a value matches a type annotation
pub fn validate_field_type(value: &QValue, type_annotation: &str) -> Result<(), String> {
    let matches = match type_annotation {
        "num" => matches!(value, QValue::Num(_)),
        "str" => matches!(value, QValue::Str(_)),
        "bool" => matches!(value, QValue::Bool(_)),
        "array" => matches!(value, QValue::Array(_)),
        "dict" => matches!(value, QValue::Dict(_)),
        "nil" => matches!(value, QValue::Nil(_)),
        "uuid" => matches!(value, QValue::Uuid(_)),
        _ => true, // Unknown types pass validation (duck typing)
    };

    if matches {
        Ok(())
    } else {
        Err(format!("Type mismatch: expected {}, got {}", type_annotation, value.as_obj().cls()))
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
