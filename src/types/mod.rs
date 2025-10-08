use std::collections::HashMap;
use std::sync::atomic::{AtomicU64, Ordering};
use std::rc::Rc;
use std::cell::RefCell;
use rust_decimal::prelude::*;
use crate::{arg_err, attr_err, type_err};

// Submodules
mod int;
mod float;
pub mod decimal;
pub mod bigint;
mod bool;
mod string;
mod bytes;
mod nil;
mod ndarray;
mod function;
mod module;
pub mod array;
mod dict;
mod set;
mod user_types;
mod exception;
mod uuid;
mod stringio;
mod system_stream;
mod redirect_guard;

#[cfg(test)]
mod size_test;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn print_qvalue_sizes() {
        size_test::print_sizes();
    }
}

// Re-export all types
pub use int::QInt;
pub use float::QFloat;
pub use decimal::{QDecimal, create_decimal_type};
pub use bigint::{QBigInt, create_bigint_type};
pub use bool::QBool;
pub use string::QString;
pub use bytes::QBytes;
pub use nil::QNil;
pub use ndarray::QNDArray;
pub use function::{QFun, QUserFun, create_fn};
pub use module::QModule;
pub use array::{QArray, create_array_type};
pub use dict::QDict;
pub use set::{QSet, SetElement};
pub use user_types::{FieldDef, QType, QStruct, QTrait, TraitMethod};
pub use exception::{QException, ExceptionType};
pub use uuid::QUuid;
pub use stringio::QStringIO;
pub use system_stream::QSystemStream;
pub use redirect_guard::QRedirectGuard;
pub use redirect_guard::StreamType;  // Re-export for use in modules

// Global ID counter for Quest objects
static NEXT_ID: AtomicU64 = AtomicU64::new(1);

pub fn next_object_id() -> u64 {
    NEXT_ID.fetch_add(1, Ordering::Relaxed)
}

// Helper function for Quest value equality comparison
pub fn values_equal(a: &QValue, b: &QValue) -> bool {
    match (a, b) {
        (QValue::Int(a_int), QValue::Int(b_int)) => a_int.value == b_int.value,
        (QValue::Float(a_float), QValue::Float(b_float)) => (a_float.value - b_float.value).abs() < f64::EPSILON,
        // Allow Int and Float to be compared with each other
        (QValue::Int(a_int), QValue::Float(b_float)) => (a_int.value as f64 - b_float.value).abs() < f64::EPSILON,
        (QValue::Float(a_float), QValue::Int(b_int)) => (a_float.value - b_int.value as f64).abs() < f64::EPSILON,
        (QValue::Bool(a_bool), QValue::Bool(b_bool)) => a_bool.value == b_bool.value,
        (QValue::Str(a_str), QValue::Str(b_str)) => a_str.value == b_str.value,
        (QValue::Nil(_), QValue::Nil(_)) => true,
        (QValue::Array(a_arr), QValue::Array(b_arr)) => {
            let a_elements = a_arr.elements.borrow();
            let b_elements = b_arr.elements.borrow();
            if a_elements.len() != b_elements.len() {
                return false;
            }
            for (a_elem, b_elem) in a_elements.iter().zip(b_elements.iter()) {
                if !values_equal(a_elem, b_elem) {
                    return false;
                }
            }
            true
        }
        // Compare Types by name (for QEP-037 exception type comparison)
        (QValue::Type(a_type), QValue::Type(b_type)) => a_type.name == b_type.name,
        _ => false, // Different types or unsupported types (Dict, Fun, etc.)
    }
}

// Helper function for comparing Quest values (for sorting)
pub fn compare_values(a: &QValue, b: &QValue) -> Option<std::cmp::Ordering> {
    use std::cmp::Ordering;

    match (a, b) {
        // Integers compare naturally
        (QValue::Int(a_int), QValue::Int(b_int)) => {
            Some(a_int.value.cmp(&b_int.value))
        }
        // Floats compare naturally
        (QValue::Float(a_float), QValue::Float(b_float)) => {
            a_float.value.partial_cmp(&b_float.value)
        }
        // Mixed Int/Float comparisons
        (QValue::Int(a_int), QValue::Float(b_float)) => {
            (a_int.value as f64).partial_cmp(&b_float.value)
        }
        (QValue::Float(a_float), QValue::Int(b_int)) => {
            a_float.value.partial_cmp(&(b_int.value as f64))
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
        // Nil < Bool < Int < Float < Str < Array < Dict < Fun < Module
        (QValue::Nil(_), _) => Some(Ordering::Less),
        (_, QValue::Nil(_)) => Some(Ordering::Greater),
        (QValue::Bool(_), QValue::Int(_)) => Some(Ordering::Less),
        (QValue::Int(_), QValue::Bool(_)) => Some(Ordering::Greater),
        (QValue::Bool(_), QValue::Str(_)) => Some(Ordering::Less),
        (QValue::Str(_), QValue::Bool(_)) => Some(Ordering::Greater),
        (QValue::Int(_), QValue::Str(_)) => Some(Ordering::Less),
        (QValue::Str(_), QValue::Int(_)) => Some(Ordering::Greater),

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
                return Some(arg_err!("cls expects 0 arguments, got {}", args.len()));
            }
            Some(Ok(QValue::Str(QString::new(obj.cls()))))
        }
        "str" => {
            if !args.is_empty() {
                return Some(arg_err!("_str expects 0 arguments, got {}", args.len()));
            }
            Some(Ok(QValue::Str(QString::new(obj.str()))))
        }
        "_rep" => {
            if !args.is_empty() {
                return Some(arg_err!("_rep expects 0 arguments, got {}", args.len()));
            }
            Some(Ok(QValue::Str(QString::new(obj._rep()))))
        }
        "_doc" => {
            if !args.is_empty() {
                return Some(arg_err!("_doc expects 0 arguments, got {}", args.len()));
            }
            Some(Ok(QValue::Str(QString::new(obj._doc()))))
        }
        "_id" => {
            if !args.is_empty() {
                return Some(arg_err!("_id expects 0 arguments, got {}", args.len()));
            }
            Some(Ok(QValue::Int(QInt::new(obj._id() as i64))))
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
    fn str(&self) -> String;
    fn _rep(&self) -> String;
    fn _doc(&self) -> String;
    fn _id(&self) -> u64;
}

#[derive(Debug, Clone)]
pub enum QValue {
    Int(QInt),
    Float(QFloat),
    Decimal(QDecimal),
    BigInt(QBigInt),
    NDArray(QNDArray),
    Bool(QBool),
    Str(QString),
    Bytes(QBytes),
    Nil(QNil),
    Fun(QFun),
    UserFun(Box<QUserFun>),
    Module(Box<QModule>),
    Array(QArray),
    Dict(Box<QDict>),
    Set(QSet),
    Type(Box<QType>),
    Struct(Rc<RefCell<QStruct>>),
    Trait(QTrait),
    Exception(QException),
    Uuid(QUuid),
    // Time types (from std/time module)
    Timestamp(crate::modules::time::QTimestamp),
    Zoned(crate::modules::time::QZoned),
    Date(crate::modules::time::QDate),
    Time(crate::modules::time::QTime),
    Span(crate::modules::time::QSpan),
    DateRange(crate::modules::time::QDateRange),
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
    // HTML templates (from std/html/templates module)
    HtmlTemplate(crate::modules::html::QHtmlTemplate),
    // HTTP client (from std/http/client module)
    HttpClient(crate::modules::http::QHttpClient),
    HttpRequest(crate::modules::http::QHttpRequest),
    HttpResponse(crate::modules::http::QHttpResponse),
    // Random number generator (from std/rand module)
    Rng(Box<crate::modules::rand::QRng>),
    // StringIO (from std/io module)
    StringIO(Rc<RefCell<QStringIO>>),
    // System streams (from std/sys module)
    SystemStream(QSystemStream),
    // Redirect guard (from std/sys module)
    RedirectGuard(Box<QRedirectGuard>),
    // Process types (from std/process module)
    ProcessResult(crate::modules::process::QProcessResult),
    Process(crate::modules::process::QProcess),
    WritableStream(crate::modules::process::QWritableStream),
    ReadableStream(crate::modules::process::QReadableStream),
}

impl QValue {
    pub fn as_obj(&self) -> &dyn QObj {
        match self {
            QValue::Int(i) => i,
            QValue::Float(f) => f,
            QValue::Decimal(d) => d,
            QValue::BigInt(bi) => bi,
            QValue::NDArray(nda) => nda,
            QValue::Bool(b) => b,
            QValue::Str(s) => s,
            QValue::Bytes(by) => by,
            QValue::Nil(n) => n,
            QValue::Fun(f) => f,
            QValue::UserFun(f) => f.as_ref(),
            QValue::Module(m) => m.as_ref(),
            QValue::Array(a) => a,
            QValue::Dict(d) => d.as_ref(),
            QValue::Set(s) => s,
            QValue::Type(t) => t.as_ref(),
            QValue::Struct(s) => {
                // For Struct wrapped in Rc<RefCell<>>, use the same pattern as StringIO
                unsafe {
                    // SAFETY: We're assuming single-threaded access and that the borrow
                    // will be short-lived (just for the QObj method call)
                    &*(s.as_ptr() as *const QStruct as *const dyn QObj)
                }
            }
            QValue::Trait(t) => t,
            QValue::Exception(e) => e,
            QValue::Uuid(u) => u,
            QValue::Timestamp(ts) => ts,
            QValue::Zoned(z) => z,
            QValue::Date(d) => d,
            QValue::Time(t) => t,
            QValue::Span(s) => s,
            QValue::DateRange(dr) => dr,
            QValue::SerialPort(sp) => sp,
            QValue::SqliteConnection(conn) => conn,
            QValue::SqliteCursor(cursor) => cursor,
            QValue::PostgresConnection(conn) => conn,
            QValue::PostgresCursor(cursor) => cursor,
            QValue::MysqlConnection(conn) => conn,
            QValue::MysqlCursor(cursor) => cursor,
            QValue::HtmlTemplate(tmpl) => tmpl,
            QValue::HttpClient(client) => client,
            QValue::HttpRequest(req) => req,
            QValue::HttpResponse(resp) => resp,
            QValue::Rng(rng) => rng.as_ref(),
            QValue::StringIO(sio) => {
                // For StringIO wrapped in Rc<RefCell<>>, we need special handling
                // Return a temporary object that implements QObj
                // This is a workaround since we can't directly borrow from RefCell
                unsafe {
                    // SAFETY: We're assuming single-threaded access and that the borrow
                    // will be short-lived (just for the QObj method call)
                    &*(sio.as_ptr() as *const QStringIO as *const dyn QObj)
                }
            }
            QValue::SystemStream(ss) => ss,
            QValue::RedirectGuard(rg) => rg.as_ref(),
            QValue::ProcessResult(pr) => pr,
            QValue::Process(p) => p,
            QValue::WritableStream(ws) => ws,
            QValue::ReadableStream(rs) => rs,
        }
    }

    pub fn as_num(&self) -> Result<f64, String> {
        match self {
            QValue::Int(i) => Ok(i.value as f64),
            QValue::Float(f) => Ok(f.value),
            QValue::Decimal(d) => Ok(d.value.to_f64().ok_or("Cannot convert decimal to f64")?),
            QValue::BigInt(bi) => bi.value.to_f64().ok_or("Cannot convert BigInt to f64".to_string()),
            QValue::NDArray(_) => Err("Cannot convert NDArray to number".to_string()),
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
            QValue::Set(_) => Err("Cannot convert set to number".to_string()),
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
            QValue::DateRange(_) => Err("Cannot convert date range to number".to_string()),
            QValue::SerialPort(_) => Err("Cannot convert serial port to number".to_string()),
            QValue::SqliteConnection(_) => Err("Cannot convert sqlite connection to number".to_string()),
            QValue::SqliteCursor(_) => Err("Cannot convert sqlite cursor to number".to_string()),
            QValue::PostgresConnection(_) => Err("Cannot convert postgres connection to number".to_string()),
            QValue::PostgresCursor(_) => Err("Cannot convert postgres cursor to number".to_string()),
            QValue::MysqlConnection(_) => Err("Cannot convert mysql connection to number".to_string()),
            QValue::MysqlCursor(_) => Err("Cannot convert mysql cursor to number".to_string()),
            QValue::HtmlTemplate(_) => Err("Cannot convert html template to number".to_string()),
            QValue::HttpClient(_) => Err("Cannot convert http client to number".to_string()),
            QValue::HttpRequest(_) => Err("Cannot convert http request to number".to_string()),
            QValue::HttpResponse(_) => Err("Cannot convert http response to number".to_string()),
            QValue::Rng(_) => Err("Cannot convert RNG to number".to_string()),
            QValue::StringIO(_) => Err("Cannot convert StringIO to number".to_string()),
            QValue::SystemStream(_) => Err("Cannot convert SystemStream to number".to_string()),
            QValue::RedirectGuard(_) => Err("Cannot convert RedirectGuard to number".to_string()),
            QValue::ProcessResult(_) => Err("Cannot convert ProcessResult to number".to_string()),
            QValue::Process(_) => Err("Cannot convert Process to number".to_string()),
            QValue::WritableStream(_) => Err("Cannot convert WritableStream to number".to_string()),
            QValue::ReadableStream(_) => Err("Cannot convert ReadableStream to number".to_string()),
        }
    }

    pub fn as_bool(&self) -> bool {
        match self {
            QValue::Int(i) => i.value != 0,
            QValue::Float(f) => f.value != 0.0,
            QValue::Decimal(d) => !d.value.is_zero(),
            QValue::BigInt(bi) => !bi.value.is_zero(),
            QValue::NDArray(nda) => nda.size() > 0,
            QValue::Bool(b) => b.value,
            QValue::Str(s) => !s.value.is_empty(),
            QValue::Bytes(b) => !b.data.is_empty(),  // Empty bytes are falsy
            QValue::Nil(_) => false,
            QValue::Fun(_) => true, // Functions are truthy
            QValue::UserFun(_) => true, // User functions are truthy
            QValue::Module(_) => true, // Modules are truthy
            QValue::Array(a) => !a.elements.borrow().is_empty(), // Empty arrays are falsy
            QValue::Dict(d) => !d.as_ref().map.borrow().is_empty(), // Empty dicts are falsy
            QValue::Set(s) => !s.is_empty(), // Empty sets are falsy
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
            QValue::DateRange(_) => true, // Date ranges are truthy
            QValue::SerialPort(_) => true, // Serial ports are truthy
            QValue::SqliteConnection(_) => true, // SQLite connections are truthy
            QValue::SqliteCursor(_) => true, // SQLite cursors are truthy
            QValue::PostgresConnection(_) => true, // Postgres connections are truthy
            QValue::PostgresCursor(_) => true, // Postgres cursors are truthy
            QValue::MysqlConnection(_) => true, // MySQL connections are truthy
            QValue::MysqlCursor(_) => true, // MySQL cursors are truthy
            QValue::HtmlTemplate(_) => true, // HTML templates are truthy
            QValue::HttpClient(_) => true, // HTTP clients are truthy
            QValue::HttpRequest(_) => true, // HTTP requests are truthy
            QValue::HttpResponse(_) => true, // HTTP responses are truthy
            QValue::Rng(_) => true, // RNG objects are truthy
            QValue::StringIO(sio) => !sio.borrow().empty(), // Empty StringIO is falsy
            QValue::SystemStream(_) => true, // System streams are truthy
            QValue::RedirectGuard(rg) => rg.is_active(), // Active guards are truthy, restored are falsy
            QValue::ProcessResult(pr) => pr.code == 0, // Success is truthy, failure is falsy
            QValue::Process(_) => true, // Processes are truthy
            QValue::WritableStream(_) => true, // Writable streams are truthy
            QValue::ReadableStream(_) => true, // Readable streams are truthy
        }
    }

    pub fn as_str(&self) -> String {
        match self {
            QValue::Int(i) => i.str(),
            QValue::Float(f) => f.str(),
            QValue::Decimal(d) => d.str(),
            QValue::BigInt(bi) => bi.str(),
            QValue::NDArray(nda) => nda.str(),
            QValue::Bool(b) => b.str(),
            QValue::Str(s) => s.value.as_ref().clone(),
            QValue::Bytes(b) => b.str(),
            QValue::Nil(_) => "nil".to_string(),
            QValue::Fun(f) => f.str(),
            QValue::UserFun(f) => f.str(),
            QValue::Module(m) => m.str(),
            QValue::Array(a) => a.str(),
            QValue::Dict(d) => d.str(),
            QValue::Set(s) => s.str(),
            QValue::Type(t) => t.str(),
            QValue::Struct(s) => s.borrow().str(),
            QValue::Trait(t) => t.str(),
            QValue::Exception(e) => e.str(),
            QValue::Uuid(u) => u.str(),
            QValue::Timestamp(ts) => ts.str(),
            QValue::Zoned(z) => z.str(),
            QValue::Date(d) => d.str(),
            QValue::Time(t) => t.str(),
            QValue::Span(s) => s.str(),
            QValue::DateRange(dr) => dr.str(),
            QValue::SerialPort(sp) => sp.str(),
            QValue::SqliteConnection(conn) => conn.str(),
            QValue::SqliteCursor(cursor) => cursor.str(),
            QValue::PostgresConnection(conn) => conn.str(),
            QValue::PostgresCursor(cursor) => cursor.str(),
            QValue::MysqlConnection(conn) => conn.str(),
            QValue::MysqlCursor(cursor) => cursor.str(),
            QValue::HtmlTemplate(tmpl) => tmpl.str(),
            QValue::HttpClient(client) => client.str(),
            QValue::HttpRequest(req) => req.str(),
            QValue::HttpResponse(resp) => resp.str(),
            QValue::Rng(rng) => rng.str(),
            QValue::StringIO(sio) => sio.borrow().str(),
            QValue::SystemStream(ss) => ss.str(),
            QValue::RedirectGuard(rg) => rg.str(),
            QValue::ProcessResult(pr) => pr.str(),
            QValue::Process(p) => p.str(),
            QValue::WritableStream(ws) => ws.str(),
            QValue::ReadableStream(rs) => rs.str(),
        }
    }

    pub fn q_type(&self) -> &'static str {
        match self {
            QValue::Int(_) => "Int",
            QValue::Float(_) => "Float",
            QValue::Decimal(_) => "Decimal",
            QValue::BigInt(_) => "BigInt",
            QValue::NDArray(_) => "NDArray",
            QValue::Bool(_) => "Bool",
            QValue::Str(_) => "Str",
            QValue::Bytes(_) => "Bytes",
            QValue::Nil(_) => "Nil",
            QValue::Fun(_) => "Fun",
            QValue::UserFun(_) => "UserFun",
            QValue::Module(_) => "Module",
            QValue::Array(_) => "Array",
            QValue::Dict(_) => "Dict",
            QValue::Set(_) => "Set",
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
            QValue::DateRange(_) => "DateRange",
            QValue::SerialPort(_) => "SerialPort",
            QValue::SqliteConnection(_) => "SqliteConnection",
            QValue::SqliteCursor(_) => "SqliteCursor",
            QValue::PostgresConnection(_) => "PostgresConnection",
            QValue::PostgresCursor(_) => "PostgresCursor",
            QValue::MysqlConnection(_) => "MysqlConnection",
            QValue::MysqlCursor(_) => "MysqlCursor",
            QValue::HtmlTemplate(_) => "HtmlTemplate",
            QValue::HttpClient(_) => "HttpClient",
            QValue::HttpRequest(_) => "HttpRequest",
            QValue::HttpResponse(_) => "HttpResponse",
            QValue::Rng(_) => "RNG",
            QValue::StringIO(_) => "StringIO",
            QValue::SystemStream(_) => "SystemStream",
            QValue::RedirectGuard(_) => "RedirectGuard",
            QValue::ProcessResult(_) => "ProcessResult",
            QValue::Process(_) => "Process",
            QValue::WritableStream(_) => "WritableStream",
            QValue::ReadableStream(_) => "ReadableStream",
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
                return arg_err!("map expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("filter expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];
            let mut new_elements = Vec::new();

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("each expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            let elements = arr.elements.borrow();
            for (idx, elem) in elements.iter().enumerate() {
                match func {
                    QValue::UserFun(user_fn) => {
                        // Call with element and index
                        if user_fn.params.len() == 1 {
                            call_user_fn(user_fn, vec![elem.clone()], scope)?;
                        } else if user_fn.params.len() == 2 {
                            call_user_fn(user_fn, vec![elem.clone(), QValue::Int(QInt::new(idx as i64))], scope)?;
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
                return arg_err!("reduce expects 2 arguments (function, initial), got {}", args.len());
            }
            let func = &args[0];
            let mut accumulator = args[1].clone();

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("any expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("all expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("find expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            let elements = arr.elements.borrow();
            for elem in elements.iter() {
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
                return arg_err!("find_index expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            let elements = arr.elements.borrow();
            for (idx, elem) in elements.iter().enumerate() {
                let result = match func {
                    QValue::UserFun(user_fn) => {
                        call_user_fn(user_fn, vec![elem.clone()], scope)?
                    }
                    _ => return Err("find_index expects a function argument".to_string())
                };

                if result.as_bool() {
                    return Ok(QValue::Int(QInt::new(idx as i64)));
                }
            }
            Ok(QValue::Int(QInt::new(-1)))
        }
        _ => attr_err!("Unknown array higher-order method: {}", method_name)
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
                return arg_err!("each expects 1 argument (function), got {}", args.len());
            }
            let func = &args[0];

            for (key, value) in dict.map.borrow().iter() {
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
        _ => attr_err!("Unknown dict higher-order method: {}", method_name)
    }
}

/// Validate that a value matches a type annotation
/// All built-in type annotations MUST use Title Case
pub fn validate_field_type(value: &QValue, type_annotation: &str) -> Result<(), String> {
    let matches = match type_annotation {
        "Int" => matches!(value, QValue::Int(_)),
        "Float" => matches!(value, QValue::Float(_)),
        "Num" => matches!(value, QValue::Int(_) | QValue::Float(_)), // Accept any numeric type
        "Decimal" => matches!(value, QValue::Decimal(_)),
        "BigInt" => matches!(value, QValue::BigInt(_)),
        "Str" => matches!(value, QValue::Str(_)),
        "Bool" => matches!(value, QValue::Bool(_)),
        "Array" => matches!(value, QValue::Array(_)),
        "Dict" => matches!(value, QValue::Dict(_)),
        "Nil" => matches!(value, QValue::Nil(_)),
        "Uuid" => matches!(value, QValue::Uuid(_)),
        "Bytes" => matches!(value, QValue::Bytes(_)),
        "Func" => matches!(value, QValue::Fun(_) | QValue::UserFun(_)),
        _ => true, // Unknown types pass validation (duck typing for user-defined types)
    };

    if matches {
        Ok(())
    } else {
        type_err!("Type mismatch: expected {}, got {}", type_annotation, value.as_obj().cls())
    }
}
