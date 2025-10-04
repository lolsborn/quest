use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use mysql::{Conn, Row, Params, Value, prelude::*};
use crate::types::*;
use crate::scope::Scope;
use chrono::{DateTime, Utc, NaiveDate, NaiveTime, NaiveDateTime};
use rust_decimal::Decimal;

/// Wrapper for MySQL Connection that implements QObj
#[derive(Clone)]
pub struct QMysqlConnection {
    conn: Arc<Mutex<Conn>>,
    id: u64,
}

impl std::fmt::Debug for QMysqlConnection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QMysqlConnection")
            .field("id", &self.id)
            .finish()
    }
}

impl QMysqlConnection {
    pub fn new(conn: Conn) -> Self {
        QMysqlConnection {
            conn: Arc::new(Mutex::new(conn)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "close" => {
                // Connection will be closed when dropped
                Ok(QValue::Nil(QNil))
            }

            "commit" => {
                let mut conn = self.conn.lock().unwrap();
                conn.query_drop("COMMIT")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "rollback" => {
                let mut conn = self.conn.lock().unwrap();
                conn.query_drop("ROLLBACK")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "cursor" => {
                Ok(QValue::MysqlCursor(QMysqlCursor::new(self.conn.clone())))
            }

            "execute" => {
                if args.is_empty() {
                    return Err("execute expects at least 1 argument (sql)".to_string());
                }
                let sql = args[0].as_str();
                let params = if args.len() > 1 {
                    Some(&args[1])
                } else {
                    None
                };

                let mut conn = self.conn.lock().unwrap();
                let count = execute_with_params(&mut conn, &sql, params)?;
                Ok(QValue::Int(QInt::new(count as i64)))
            }

            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<MysqlConnection {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<MysqlConnection {}>", self.id)))),

            _ => Err(format!("Unknown method '{}' on MysqlConnection", method_name))
        }
    }
}

impl QObj for QMysqlConnection {
    fn cls(&self) -> String {
        "MysqlConnection".to_string()
    }

    fn q_type(&self) -> &'static str {
        "MysqlConnection"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "MysqlConnection"
    }

    fn _str(&self) -> String {
        format!("<MysqlConnection {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<MysqlConnection {}>", self.id)
    }

    fn _doc(&self) -> String {
        "MySQL database connection".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// Column description for cursor.description
#[derive(Debug, Clone)]
struct ColumnDescription {
    name: String,
    type_code: String,
}

/// Wrapper for MySQL cursor (connection + results)
#[derive(Clone)]
pub struct QMysqlCursor {
    conn: Arc<Mutex<Conn>>,
    current_results: Arc<Mutex<Vec<HashMap<String, QValue>>>>,
    position: Arc<Mutex<usize>>,
    row_count: Arc<Mutex<i64>>,
    description: Arc<Mutex<Option<Vec<ColumnDescription>>>>,
    id: u64,
}

impl std::fmt::Debug for QMysqlCursor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QMysqlCursor")
            .field("id", &self.id)
            .field("row_count", &self.row_count)
            .finish()
    }
}

impl QMysqlCursor {
    pub fn new(conn: Arc<Mutex<Conn>>) -> Self {
        QMysqlCursor {
            conn,
            current_results: Arc::new(Mutex::new(Vec::new())),
            position: Arc::new(Mutex::new(0)),
            row_count: Arc::new(Mutex::new(-1)),
            description: Arc::new(Mutex::new(None)),
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "execute" => {
                if args.is_empty() {
                    return Err("execute expects at least 1 argument (sql)".to_string());
                }
                let sql = args[0].as_str();
                let params = if args.len() > 1 {
                    Some(&args[1])
                } else {
                    None
                };

                self.execute_internal(&sql, params)?;
                Ok(QValue::Nil(QNil))
            }

            "execute_many" => {
                if args.len() != 2 {
                    return Err(format!("execute_many expects 2 arguments (sql, params_seq), got {}", args.len()));
                }
                let sql = args[0].as_str();
                let params_seq = match &args[1] {
                    QValue::Array(arr) => arr,
                    _ => return Err("execute_many expects second argument to be an array".to_string()),
                };

                let mut total_count = 0;
                for params in &params_seq.elements {
                    let mut conn = self.conn.lock().unwrap();
                    let count = execute_with_params(&mut conn, &sql, Some(params))?;
                    total_count += count;
                }

                *self.row_count.lock().unwrap() = total_count as i64;
                Ok(QValue::Nil(QNil))
            }

            "fetch_one" => {
                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                if *pos < results.len() {
                    let row = results[*pos].clone();
                    *pos += 1;
                    Ok(QValue::Dict(QDict::new(row)))
                } else {
                    Ok(QValue::Nil(QNil))
                }
            }

            "fetch_many" => {
                let size = if args.is_empty() {
                    10
                } else {
                    args[0].as_num()? as usize
                };

                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                let end = std::cmp::min(*pos + size, results.len());
                let rows: Vec<QValue> = results[*pos..end]
                    .iter()
                    .map(|row| QValue::Dict(QDict::new(row.clone())))
                    .collect();

                *pos = end;
                Ok(QValue::Array(QArray::new(rows)))
            }

            "fetch_all" => {
                let mut pos = self.position.lock().unwrap();
                let results = self.current_results.lock().unwrap();

                let rows: Vec<QValue> = results[*pos..]
                    .iter()
                    .map(|row| QValue::Dict(QDict::new(row.clone())))
                    .collect();

                *pos = results.len();
                Ok(QValue::Array(QArray::new(rows)))
            }

            "close" => {
                // Clear results
                self.current_results.lock().unwrap().clear();
                *self.position.lock().unwrap() = 0;
                *self.row_count.lock().unwrap() = -1;
                *self.description.lock().unwrap() = None;
                Ok(QValue::Nil(QNil))
            }

            "description" => {
                let desc = self.description.lock().unwrap();
                match &*desc {
                    Some(columns) => {
                        let result: Vec<QValue> = columns.iter().map(|col| {
                            let mut map = HashMap::new();
                            map.insert("name".to_string(), QValue::Str(QString::new(col.name.clone())));
                            map.insert("type_code".to_string(), QValue::Str(QString::new(col.type_code.clone())));
                            map.insert("display_size".to_string(), QValue::Nil(QNil));
                            map.insert("internal_size".to_string(), QValue::Nil(QNil));
                            map.insert("precision".to_string(), QValue::Nil(QNil));
                            map.insert("scale".to_string(), QValue::Nil(QNil));
                            map.insert("null_ok".to_string(), QValue::Bool(QBool::new(true)));
                            QValue::Dict(QDict::new(map))
                        }).collect();
                        Ok(QValue::Array(QArray::new(result)))
                    }
                    None => Ok(QValue::Nil(QNil))
                }
            }

            "row_count" => {
                let count = *self.row_count.lock().unwrap();
                Ok(QValue::Int(QInt::new(count)))
            }

            "_id" => Ok(QValue::Int(QInt::new(self.id as i64))),
            "_str" => Ok(QValue::Str(QString::new(format!("<MysqlCursor {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<MysqlCursor {}>", self.id)))),

            _ => Err(format!("Unknown method '{}' on MysqlCursor", method_name))
        }
    }

    fn execute_internal(&self, sql: &str, params: Option<&QValue>) -> Result<(), String> {
        let mut conn = self.conn.lock().unwrap();

        // Check if this is a SELECT query
        let is_query = sql.trim().to_uppercase().starts_with("SELECT");

        if is_query {
            // Execute query and fetch all results with column metadata
            let (rows, columns) = query_with_params_and_metadata(&mut conn, sql, params)?;
            let row_count = rows.len() as i64;

            // Store results
            *self.current_results.lock().unwrap() = rows;
            *self.position.lock().unwrap() = 0;
            *self.row_count.lock().unwrap() = row_count;
            *self.description.lock().unwrap() = Some(columns);
        } else {
            // Execute non-query statement
            let count = execute_with_params(&mut conn, sql, params)?;
            *self.row_count.lock().unwrap() = count as i64;
            *self.description.lock().unwrap() = None;
            *self.current_results.lock().unwrap() = Vec::new();
            *self.position.lock().unwrap() = 0;
        }

        Ok(())
    }
}

impl QObj for QMysqlCursor {
    fn cls(&self) -> String {
        "MysqlCursor".to_string()
    }

    fn q_type(&self) -> &'static str {
        "MysqlCursor"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "MysqlCursor"
    }

    fn _str(&self) -> String {
        format!("<MysqlCursor {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<MysqlCursor {}>", self.id)
    }

    fn _doc(&self) -> String {
        "MySQL database cursor".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// =============================================================================
// Date/Time Conversion Helpers
// =============================================================================

/// Convert jiff Timestamp to chrono NaiveDateTime (MySQL DATETIME)
fn jiff_timestamp_to_chrono(ts: &crate::modules::time::QTimestamp) -> NaiveDateTime {
    let seconds = ts.timestamp.as_second();
    let nanos = ts.timestamp.subsec_nanosecond() as u32;
    DateTime::from_timestamp(seconds, nanos)
        .unwrap_or_else(|| Utc::now())
        .naive_utc()
}

/// Convert jiff Date to chrono NaiveDate
fn jiff_date_to_chrono(date: &crate::modules::time::QDate) -> NaiveDate {
    NaiveDate::from_ymd_opt(
        date.date.year() as i32,
        date.date.month() as u32,
        date.date.day() as u32
    ).unwrap()
}

/// Convert jiff Time to chrono NaiveTime
fn jiff_time_to_chrono(time: &crate::modules::time::QTime) -> NaiveTime {
    NaiveTime::from_hms_nano_opt(
        time.time.hour() as u32,
        time.time.minute() as u32,
        time.time.second() as u32,
        time.time.subsec_nanosecond() as u32
    ).unwrap()
}

/// Convert MySQL Value::Date to Quest Timestamp
fn mysql_date_to_timestamp(year: u16, month: u8, day: u8, hour: u8, min: u8, sec: u8, micro: u32) -> crate::modules::time::QTimestamp {
    use jiff::civil::date;

    // Build a civil datetime
    let dt = date(year as i16, month as i8, day as i8)
        .at(hour as i8, min as i8, sec as i8, (micro * 1000) as i32);

    // Convert to timestamp (assumes UTC)
    let ts = dt.to_zoned(jiff::tz::TimeZone::UTC).unwrap().timestamp();
    crate::modules::time::QTimestamp::new(ts)
}

/// Convert MySQL Value::Time to Quest Span (duration)
fn mysql_time_to_span(is_negative: bool, days: u32, hours: u8, minutes: u8, seconds: u8, micros: u32) -> crate::modules::time::QSpan {
    use jiff::Span;

    let mut span = Span::new()
        .days(days as i64)
        .hours(hours as i64)
        .minutes(minutes as i64)
        .seconds(seconds as i64)
        .microseconds(micros as i64);

    if is_negative {
        span = span.negate();
    }

    crate::modules::time::QSpan::new(span)
}

/// Parse MySQL DATETIME/TIMESTAMP string to Quest Timestamp
/// Formats: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD HH:MM:SS.ffffff"
fn parse_mysql_datetime(s: &str) -> Option<crate::modules::time::QTimestamp> {
    use jiff::civil::date;

    // Split by space to separate date and time
    let parts: Vec<&str> = s.split(' ').collect();
    if parts.len() != 2 {
        return None;
    }

    // Parse date part: YYYY-MM-DD
    let date_parts: Vec<&str> = parts[0].split('-').collect();
    if date_parts.len() != 3 {
        return None;
    }
    let year: i16 = date_parts[0].parse().ok()?;
    let month: i8 = date_parts[1].parse().ok()?;
    let day: i8 = date_parts[2].parse().ok()?;

    // Parse time part: HH:MM:SS or HH:MM:SS.ffffff
    let time_parts: Vec<&str> = parts[1].split(':').collect();
    if time_parts.len() != 3 {
        return None;
    }
    let hour: i8 = time_parts[0].parse().ok()?;
    let minute: i8 = time_parts[1].parse().ok()?;

    // Handle seconds and microseconds
    let sec_parts: Vec<&str> = time_parts[2].split('.').collect();
    let second: i8 = sec_parts[0].parse().ok()?;
    let nanos: i32 = if sec_parts.len() > 1 {
        // Pad to 9 digits (nanoseconds)
        let frac = format!("{:0<9}", sec_parts[1]);
        frac.parse().ok()?
    } else {
        0
    };

    // Build datetime and convert to timestamp
    let dt = date(year, month, day).at(hour, minute, second, nanos);
    let ts = dt.to_zoned(jiff::tz::TimeZone::UTC).ok()?.timestamp();
    Some(crate::modules::time::QTimestamp::new(ts))
}

/// Parse MySQL DATE string to Quest Date
/// Format: "YYYY-MM-DD"
fn parse_mysql_date(s: &str) -> Option<crate::modules::time::QDate> {
    use jiff::civil::Date;

    let parts: Vec<&str> = s.split('-').collect();
    if parts.len() != 3 {
        return None;
    }

    let year: i16 = parts[0].parse().ok()?;
    let month: i8 = parts[1].parse().ok()?;
    let day: i8 = parts[2].parse().ok()?;

    let date = Date::new(year, month, day).ok()?;
    Some(crate::modules::time::QDate::new(date))
}

/// Parse MySQL TIME string to Quest Time
/// Format: "HH:MM:SS" or "HH:MM:SS.ffffff"
fn parse_mysql_time(s: &str) -> Option<crate::modules::time::QTime> {
    use jiff::civil::Time;

    let parts: Vec<&str> = s.split(':').collect();
    if parts.len() != 3 {
        return None;
    }

    let hour: i8 = parts[0].parse().ok()?;
    let minute: i8 = parts[1].parse().ok()?;

    // Handle seconds and microseconds
    let sec_parts: Vec<&str> = parts[2].split('.').collect();
    let second: i8 = sec_parts[0].parse().ok()?;
    let nanos: i32 = if sec_parts.len() > 1 {
        // Pad to 9 digits (nanoseconds)
        let frac = format!("{:0<9}", sec_parts[1]);
        frac.parse().ok()?
    } else {
        0
    };

    let time = Time::new(hour, minute, second, nanos).ok()?;
    Some(crate::modules::time::QTime::new(time))
}

// =============================================================================
// Parameter Conversion
// =============================================================================

/// Convert QValue to MySQL parameter
fn qvalue_to_mysql_param(value: &QValue) -> Value {
    match value {
        QValue::Nil(_) => Value::NULL,
        QValue::Int(i) => Value::Int(i.value),
        QValue::Num(n) => {
            if n.value.fract() == 0.0 && n.value.abs() < 1e10 {
                Value::Int(n.value as i64)
            } else {
                Value::Double(n.value)
            }
        }
        QValue::Float(f) => Value::Double(f.value),
        QValue::Decimal(d) => {
            // Convert Decimal to string for MySQL
            // This preserves full precision
            Value::Bytes(d.value.to_string().into_bytes())
        }
        QValue::Str(s) => Value::Bytes(s.value.clone().into_bytes()),
        QValue::Bool(b) => Value::Int(if b.value { 1 } else { 0 }),
        QValue::Bytes(b) => Value::Bytes(b.data.clone()),
        QValue::Uuid(u) => {
            // Convert UUID to BINARY(16) format
            Value::Bytes(u.value.as_bytes().to_vec())
        }

        // Date/Time types
        QValue::Timestamp(ts) => {
            // Convert to NaiveDateTime and format as string for MySQL
            let dt = jiff_timestamp_to_chrono(ts);
            let formatted = dt.format("%Y-%m-%d %H:%M:%S%.6f").to_string();
            Value::Bytes(formatted.into_bytes())
        }
        QValue::Date(d) => {
            let date = jiff_date_to_chrono(d);
            let formatted = date.format("%Y-%m-%d").to_string();
            Value::Bytes(formatted.into_bytes())
        }
        QValue::Time(t) => {
            let time = jiff_time_to_chrono(t);
            let formatted = time.format("%H:%M:%S%.6f").to_string();
            Value::Bytes(formatted.into_bytes())
        }
        QValue::Zoned(z) => {
            // MySQL doesn't have native timezone support, convert to UTC timestamp
            let seconds = z.zoned.timestamp().as_second();
            let nanos = z.zoned.timestamp().subsec_nanosecond() as u32;
            let dt = DateTime::from_timestamp(seconds, nanos)
                .unwrap_or_else(|| Utc::now())
                .naive_utc();
            let formatted = dt.format("%Y-%m-%d %H:%M:%S%.6f").to_string();
            Value::Bytes(formatted.into_bytes())
        }
        QValue::Span(_s) => {
            // MySQL TIME type is tricky for spans, just format as string for now
            // TODO: Could convert to Value::Time format
            Value::NULL
        }

        _ => Value::NULL
    }
}

/// Execute statement with parameters
fn execute_with_params(conn: &mut Conn, sql: &str, params: Option<&QValue>) -> Result<u64, String> {
    if let Some(params_value) = params {
        match params_value {
            QValue::Array(arr) => {
                // Positional parameters (?)
                let mysql_params: Vec<Value> = arr.elements.iter()
                    .map(qvalue_to_mysql_param)
                    .collect();

                conn.exec_drop(sql, Params::Positional(mysql_params))
                    .map_err(|e| map_mysql_error(e))?;

                Ok(conn.affected_rows())
            }
            _ => Err("MySQL only supports positional parameters (arrays)".to_string())
        }
    } else {
        conn.query_drop(sql)
            .map_err(|e| map_mysql_error(e))?;
        Ok(conn.affected_rows())
    }
}

/// Query with parameters and return rows with column metadata
fn query_with_params_and_metadata(conn: &mut Conn, sql: &str, params: Option<&QValue>) -> Result<(Vec<HashMap<String, QValue>>, Vec<ColumnDescription>), String> {
    let rows: Vec<Row> = if let Some(params_value) = params {
        match params_value {
            QValue::Array(arr) => {
                // Positional parameters
                let mysql_params: Vec<Value> = arr.elements.iter()
                    .map(qvalue_to_mysql_param)
                    .collect();

                conn.exec(sql, Params::Positional(mysql_params))
                    .map_err(|e| map_mysql_error(e))?
            }
            _ => return Err("MySQL only supports positional parameters (arrays)".to_string())
        }
    } else {
        conn.query(sql)
            .map_err(|e| map_mysql_error(e))?
    };

    // Get column metadata
    let columns: Vec<ColumnDescription> = if let Some(first_row) = rows.first() {
        first_row.columns().iter().map(|col| ColumnDescription {
            name: col.name_str().to_string(),
            type_code: format!("{:?}", col.column_type()),
        }).collect()
    } else {
        // For empty result sets, we need to execute again to get column info
        // MySQL doesn't provide an easy way to get column metadata without rows
        Vec::new()
    };

    let mut results = Vec::new();
    for row in rows {
        results.push(row_to_dict(&row)?);
    }
    Ok((results, columns))
}

/// Convert MySQL row to Quest dict
fn row_to_dict(row: &Row) -> Result<HashMap<String, QValue>, String> {
    let mut dict = HashMap::new();

    for (idx, column) in row.columns().iter().enumerate() {
        let col_name = column.name_str().to_string();
        let col_type = format!("{:?}", column.column_type());

        // Get value by index - MySQL's from_value handles type conversion
        let value: Value = row.get(idx).ok_or_else(|| format!("Failed to get column {}", idx))?;

        let qvalue = match value {
            Value::NULL => QValue::Nil(QNil),
            Value::Bytes(b) => {
                // If it's exactly 16 bytes, try to parse as UUID first
                if b.len() == 16 {
                    if let Ok(uuid_bytes) = <[u8; 16]>::try_from(b.as_slice()) {
                        let uuid = uuid::Uuid::from_bytes(uuid_bytes);
                        QValue::Uuid(QUuid::new(uuid))
                    } else {
                        // Fallback to bytes if conversion fails
                        QValue::Bytes(QBytes::new(b))
                    }
                } else {
                    // Try to decode as UTF-8 string
                    match String::from_utf8(b.clone()) {
                        Ok(s) => {
                            // Check column type and parse accordingly
                            if col_type.contains("DATETIME") || col_type.contains("TIMESTAMP") {
                                if let Some(ts) = parse_mysql_datetime(&s) {
                                    QValue::Timestamp(ts)
                                } else {
                                    QValue::Str(QString::new(s))
                                }
                            } else if col_type.contains("DATE") {
                                if let Some(date) = parse_mysql_date(&s) {
                                    QValue::Date(date)
                                } else {
                                    QValue::Str(QString::new(s))
                                }
                            } else if col_type.contains("TIME") {
                                if let Some(time) = parse_mysql_time(&s) {
                                    QValue::Time(time)
                                } else {
                                    QValue::Str(QString::new(s))
                                }
                            } else if col_type.contains("DECIMAL") || col_type.contains("NEWDECIMAL") {
                                // Parse DECIMAL/NUMERIC as Decimal for full precision
                                if let Ok(decimal) = s.parse::<Decimal>() {
                                    QValue::Decimal(QDecimal::new(decimal))
                                } else {
                                    QValue::Str(QString::new(s))
                                }
                            } else if s.contains('.') || s.contains('e') || s.contains('E') {
                                // Contains decimal point or scientific notation - parse as float
                                if let Ok(num) = s.parse::<f64>() {
                                    QValue::Float(QFloat::new(num))
                                } else {
                                    QValue::Str(QString::new(s))
                                }
                            } else if let Ok(num) = s.parse::<i64>() {
                                // Integer string
                                QValue::Int(QInt::new(num))
                            } else {
                                QValue::Str(QString::new(s))
                            }
                        }
                        Err(_) => QValue::Bytes(QBytes::new(b)),
                    }
                }
            }
            Value::Int(i) => QValue::Int(QInt::new(i)),
            Value::UInt(u) => QValue::Int(QInt::new(u as i64)),
            Value::Float(f) => QValue::Float(QFloat::new(f as f64)),
            Value::Double(d) => QValue::Float(QFloat::new(d)),
            Value::Date(y, m, d, h, min, s, micro) => {
                // Convert MySQL DATETIME to Quest Timestamp (includes microseconds)
                QValue::Timestamp(mysql_date_to_timestamp(y, m, d, h, min, s, micro))
            }
            Value::Time(is_neg, d, h, m, s, micro) => {
                // Convert MySQL TIME (duration) to Quest Span
                QValue::Span(mysql_time_to_span(is_neg, d, h, m, s, micro))
            }
        };

        dict.insert(col_name, qvalue);
    }

    Ok(dict)
}

/// Map MySQL errors to QEP-001 exception hierarchy
fn map_mysql_error(err: mysql::Error) -> String {
    match &err {
        mysql::Error::MySqlError(e) => {
            match e.code {
                1062 => format!("IntegrityError: {}", e.message),  // Duplicate entry
                1451 | 1452 => format!("IntegrityError: {}", e.message),  // Foreign key constraint
                1054 | 1146 => format!("ProgrammingError: {}", e.message),  // Unknown column/table
                1064 => format!("ProgrammingError: {}", e.message),  // Syntax error
                1406 => format!("DataError: {}", e.message),  // Data too long
                _ => format!("DatabaseError: {}", e.message)
            }
        }
        _ => format!("DatabaseError: {}", err)
    }
}

/// Create the mysql module
pub fn create_mysql_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("connect".to_string(), QValue::Fun(QFun {
        name: "connect".to_string(),
        parent_type: "mysql".to_string(),
        id: next_object_id(),
    }));

    QValue::Module(QModule::new("mysql".to_string(), members))
}

/// Call mysql module functions
pub fn call_mysql_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "mysql.connect" => {
            if args.len() != 1 {
                return Err(format!("mysql.connect expects 1 argument (connection_string), got {}", args.len()));
            }
            let conn_str = args[0].as_str();

            let mut conn = Conn::new(&*conn_str)
                .map_err(|e| format!("DatabaseError: Failed to connect to database: {}", e))?;

            // Disable autocommit for proper transaction support
            conn.query_drop("SET autocommit=0")
                .map_err(|e| format!("DatabaseError: Failed to disable autocommit: {}", e))?;

            Ok(QValue::MysqlConnection(QMysqlConnection::new(conn)))
        }

        _ => Err(format!("Unknown function: {}", func_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running MySQL instance
    // Run: docker-compose up -d mysql

    fn get_test_connection_string() -> String {
        "mysql://quest:quest_password@localhost:6603/quest_test".to_string()
    }

    #[test]
    #[ignore] // Requires MySQL running
    fn test_connect() {
        let mut scope = Scope::new();
        let conn_str = get_test_connection_string();

        let result = call_mysql_function(
            "mysql.connect",
            vec![QValue::Str(QString::new(conn_str))],
            &mut scope
        );

        assert!(result.is_ok());
        match result.unwrap() {
            QValue::MysqlConnection(_) => {},
            _ => panic!("Expected MysqlConnection"),
        }
    }

    #[test]
    #[ignore] // Requires MySQL running
    fn test_create_table() {
        let mut scope = Scope::new();
        let conn_str = get_test_connection_string();

        let conn_result = call_mysql_function(
            "mysql.connect",
            vec![QValue::Str(QString::new(conn_str))],
            &mut scope
        );
        assert!(conn_result.is_ok());

        if let QValue::MysqlConnection(conn) = conn_result.unwrap() {
            let cursor_result = conn.call_method("cursor", vec![]);
            assert!(cursor_result.is_ok());

            if let QValue::MysqlCursor(cursor) = cursor_result.unwrap() {
                // Drop table if exists
                let _ = cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new("DROP TABLE IF EXISTS test_users".to_string()))]
                );

                let sql = "CREATE TABLE test_users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255))";
                let result = cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new(sql.to_string()))]
                );
                assert!(result.is_ok());
            }
        }
    }
}
