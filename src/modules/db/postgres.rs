use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use postgres::{Client, Row, types::ToSql};
use crate::types::*;
use crate::scope::Scope;
use chrono::{DateTime, Utc, NaiveDate, NaiveTime, NaiveDateTime};
use pg_interval::Interval;
use serde_json;
use rust_decimal::prelude::*;

/// Wrapper for PostgreSQL Client that implements QObj
#[derive(Clone)]
pub struct QPostgresConnection {
    conn: Arc<Mutex<Client>>,
    id: u64,
}

impl std::fmt::Debug for QPostgresConnection {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QPostgresConnection")
            .field("id", &self.id)
            .finish()
    }
}

impl QPostgresConnection {
    pub fn new(conn: Client) -> Self {
        QPostgresConnection {
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
                conn.batch_execute("COMMIT")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "rollback" => {
                let mut conn = self.conn.lock().unwrap();
                conn.batch_execute("ROLLBACK")
                    .map_err(|e| format!("DatabaseError: {}", e))?;
                Ok(QValue::Nil(QNil))
            }

            "cursor" => {
                Ok(QValue::PostgresCursor(QPostgresCursor::new(self.conn.clone())))
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
            "_str" => Ok(QValue::Str(QString::new(format!("<PostgresConnection {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<PostgresConnection {}>", self.id)))),

            _ => Err(format!("Unknown method '{}' on PostgresConnection", method_name))
        }
    }
}

impl QObj for QPostgresConnection {
    fn cls(&self) -> String {
        "PostgresConnection".to_string()
    }

    fn q_type(&self) -> &'static str {
        "PostgresConnection"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "PostgresConnection"
    }

    fn _str(&self) -> String {
        format!("<PostgresConnection {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<PostgresConnection {}>", self.id)
    }

    fn _doc(&self) -> String {
        "PostgreSQL database connection".to_string()
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

/// Wrapper for PostgreSQL cursor (connection + results)
#[derive(Clone)]
pub struct QPostgresCursor {
    conn: Arc<Mutex<Client>>,
    current_results: Arc<Mutex<Vec<HashMap<String, QValue>>>>,
    position: Arc<Mutex<usize>>,
    row_count: Arc<Mutex<i64>>,
    description: Arc<Mutex<Option<Vec<ColumnDescription>>>>,
    id: u64,
}

impl std::fmt::Debug for QPostgresCursor {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("QPostgresCursor")
            .field("id", &self.id)
            .field("row_count", &self.row_count)
            .finish()
    }
}

impl QPostgresCursor {
    pub fn new(conn: Arc<Mutex<Client>>) -> Self {
        QPostgresCursor {
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
                    let count = {
                        let mut conn = self.conn.lock().unwrap();
                        execute_with_params(&mut conn, &sql, Some(params))?
                    };
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
            "_str" => Ok(QValue::Str(QString::new(format!("<PostgresCursor {}>", self.id)))),
            "_rep" => Ok(QValue::Str(QString::new(format!("<PostgresCursor {}>", self.id)))),

            _ => Err(format!("Unknown method '{}' on PostgresCursor", method_name))
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

impl QObj for QPostgresCursor {
    fn cls(&self) -> String {
        "PostgresCursor".to_string()
    }

    fn q_type(&self) -> &'static str {
        "PostgresCursor"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "PostgresCursor"
    }

    fn _str(&self) -> String {
        format!("<PostgresCursor {}>", self.id)
    }

    fn _rep(&self) -> String {
        format!("<PostgresCursor {}>", self.id)
    }

    fn _doc(&self) -> String {
        "PostgreSQL database cursor".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// =============================================================================
// Date/Time Conversion Helpers
// =============================================================================

/// Convert jiff Timestamp to chrono DateTime<Utc>
fn jiff_timestamp_to_chrono(ts: &crate::modules::time::QTimestamp) -> DateTime<Utc> {
    let seconds = ts.timestamp.as_second();
    let nanos = ts.timestamp.subsec_nanosecond() as u32;
    DateTime::from_timestamp(seconds, nanos).unwrap_or_else(|| Utc::now())
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

/// Convert jiff Zoned to chrono DateTime<Utc> (converts to UTC)
fn jiff_zoned_to_chrono(zoned: &crate::modules::time::QZoned) -> DateTime<Utc> {
    let seconds = zoned.zoned.timestamp().as_second();
    let nanos = zoned.zoned.timestamp().subsec_nanosecond() as u32;
    DateTime::from_timestamp(seconds, nanos).unwrap_or_else(|| Utc::now())
}

/// Convert chrono DateTime<Utc> to jiff Timestamp
#[allow(dead_code)]
fn chrono_to_jiff_timestamp(dt: DateTime<Utc>) -> crate::modules::time::QTimestamp {
    use jiff::Timestamp as JiffTimestamp;
    let seconds = dt.timestamp();
    let nanos = dt.timestamp_subsec_nanos();
    let ts = JiffTimestamp::from_second(seconds).unwrap()
        .checked_add(jiff::Span::new().nanoseconds(nanos as i64)).unwrap();
    crate::modules::time::QTimestamp::new(ts)
}

/// Convert chrono NaiveDateTime to jiff Timestamp
fn chrono_to_jiff_timestamp_from_naive(dt: NaiveDateTime) -> crate::modules::time::QTimestamp {
    use jiff::Timestamp as JiffTimestamp;
    use chrono::Timelike;

    // Convert NaiveDateTime to Unix timestamp
    let seconds = dt.and_utc().timestamp();
    let nanos = dt.nanosecond();

    let ts = JiffTimestamp::from_second(seconds).unwrap()
        .checked_add(jiff::Span::new().nanoseconds(nanos as i64)).unwrap();
    crate::modules::time::QTimestamp::new(ts)
}

/// Convert chrono NaiveDate to jiff Date
fn chrono_to_jiff_date(date: NaiveDate) -> crate::modules::time::QDate {
    use jiff::civil::Date as JiffDate;
    use chrono::Datelike;

    let jiff_date = JiffDate::new(
        date.year() as i16,
        date.month() as i8,
        date.day() as i8
    ).unwrap();
    crate::modules::time::QDate::new(jiff_date)
}

/// Convert chrono NaiveTime to jiff Time
fn chrono_to_jiff_time(time: NaiveTime) -> crate::modules::time::QTime {
    use jiff::civil::Time as JiffTime;
    use chrono::Timelike;

    let jiff_time = JiffTime::new(
        time.hour() as i8,
        time.minute() as i8,
        time.second() as i8,
        time.nanosecond() as i32
    ).unwrap();
    crate::modules::time::QTime::new(jiff_time)
}

/// Convert chrono NaiveDateTime to jiff Zoned (assumes UTC)
fn chrono_to_jiff_zoned(dt: NaiveDateTime) -> crate::modules::time::QZoned {
    use jiff::civil::date;
    use jiff::tz::TimeZone;
    use chrono::Datelike;
    use chrono::Timelike;

    let jiff_dt = date(
        dt.year() as i16,
        dt.month() as i8,
        dt.day() as i8
    ).at(
        dt.hour() as i8,
        dt.minute() as i8,
        dt.second() as i8,
        dt.nanosecond() as i32
    );

    let zoned = jiff_dt.to_zoned(TimeZone::UTC).unwrap();
    crate::modules::time::QZoned::new(zoned)
}

/// Convert jiff Span to PostgreSQL Interval
fn jiff_span_to_pg_interval(span: &crate::modules::time::QSpan) -> Interval {
    // PostgreSQL INTERVAL has: months, days, microseconds
    // jiff Span has: years, months, days, hours, minutes, seconds, milliseconds, microseconds, nanoseconds

    let years = span.span.get_years() as i64;
    let months = span.span.get_months() as i64 + (years * 12); // Consolidate years into months
    let days = span.span.get_days() as i64;

    // Calculate total microseconds from time components
    let hours_micros = span.span.get_hours() as i64 * 3_600_000_000i64;
    let minutes_micros = span.span.get_minutes() as i64 * 60_000_000i64;
    let seconds_micros = span.span.get_seconds() as i64 * 1_000_000i64;
    let millis_micros = span.span.get_milliseconds() as i64 * 1_000i64;
    let micros = span.span.get_microseconds() as i64;
    let nanos_micros = span.span.get_nanoseconds() as i64 / 1000; // Convert to microseconds

    let total_microseconds = hours_micros + minutes_micros + seconds_micros +
                            millis_micros + micros + nanos_micros;

    Interval {
        months: months as i32,
        days: days as i32,
        microseconds: total_microseconds,
    }
}

/// Convert PostgreSQL Interval to jiff Span
fn pg_interval_to_jiff_span(interval: &Interval) -> crate::modules::time::QSpan {
    use jiff::Span as JiffSpan;

    // Break down months into years and months
    let years = interval.months / 12;
    let months = interval.months % 12;
    let days = interval.days;

    // Break down microseconds into time components
    let total_seconds = interval.microseconds / 1_000_000;
    let remaining_micros = interval.microseconds % 1_000_000;

    let hours = total_seconds / 3600;
    let minutes = (total_seconds % 3600) / 60;
    let seconds = total_seconds % 60;

    let milliseconds = remaining_micros / 1000;
    let microseconds = remaining_micros % 1000;

    let span = JiffSpan::new()
        .years(years as i64)
        .months(months as i64)
        .days(days as i64)
        .hours(hours)
        .minutes(minutes)
        .seconds(seconds)
        .milliseconds(milliseconds)
        .microseconds(microseconds);

    crate::modules::time::QSpan::new(span)
}

/// Convert Quest Dict/Array to serde_json::Value
fn qvalue_to_json(value: &QValue) -> Result<serde_json::Value, String> {
    match value {
        QValue::Nil(_) => Ok(serde_json::Value::Null),
        QValue::Bool(b) => Ok(serde_json::Value::Bool(b.value)),
        QValue::Int(i) => Ok(serde_json::Value::Number(serde_json::Number::from(i.value))),
        QValue::Float(f) => {
            if let Some(num) = serde_json::Number::from_f64(f.value) {
                Ok(serde_json::Value::Number(num))
            } else {
                Err(format!("Cannot convert {} to JSON number", f.value))
            }
        }
        QValue::Num(n) => {
            // For backward compatibility, handle Num
            if let Some(num) = serde_json::Number::from_f64(n.value) {
                Ok(serde_json::Value::Number(num))
            } else {
                Err(format!("Cannot convert {} to JSON number", n.value))
            }
        }
        QValue::Str(s) => Ok(serde_json::Value::String(s.value.clone())),
        QValue::Array(arr) => {
            let json_arr: Result<Vec<serde_json::Value>, String> = arr.elements.iter()
                .map(qvalue_to_json)
                .collect();
            Ok(serde_json::Value::Array(json_arr?))
        }
        QValue::Dict(dict) => {
            let mut json_obj = serde_json::Map::new();
            for (key, val) in &dict.map {
                json_obj.insert(key.clone(), qvalue_to_json(val)?);
            }
            Ok(serde_json::Value::Object(json_obj))
        }
        _ => Err(format!("Cannot convert {} to JSON", value.q_type()))
    }
}

/// Convert serde_json::Value to Quest Dict/Array
fn json_to_qvalue(value: &serde_json::Value) -> QValue {
    match value {
        serde_json::Value::Null => QValue::Nil(QNil),
        serde_json::Value::Bool(b) => QValue::Bool(QBool::new(*b)),
        serde_json::Value::Number(n) => {
            if let Some(i) = n.as_i64() {
                QValue::Int(QInt::new(i))
            } else if let Some(f) = n.as_f64() {
                QValue::Float(QFloat::new(f))
            } else {
                QValue::Nil(QNil)
            }
        }
        serde_json::Value::String(s) => QValue::Str(QString::new(s.clone())),
        serde_json::Value::Array(arr) => {
            let elements: Vec<QValue> = arr.iter().map(json_to_qvalue).collect();
            QValue::Array(QArray::new(elements))
        }
        serde_json::Value::Object(obj) => {
            let mut dict = HashMap::new();
            for (key, val) in obj {
                dict.insert(key.clone(), json_to_qvalue(val));
            }
            QValue::Dict(QDict::new(dict))
        }
    }
}

/// Check if all elements in a Quest array are the same type
#[allow(dead_code)]
fn array_element_type(arr: &QArray) -> Option<&'static str> {
    if arr.elements.is_empty() {
        return None;
    }

    let first_type = arr.elements[0].q_type();

    // Check if all elements have the same type
    for elem in &arr.elements {
        if elem.q_type() != first_type {
            return None; // Mixed types
        }
    }

    Some(first_type)
}

// =============================================================================
// Parameter Conversion
// =============================================================================

/// Convert QValue to PostgreSQL parameter
fn qvalue_to_pg_param(value: &QValue) -> Result<Box<dyn ToSql + Sync>, String> {
    match value {
        // For NULL, we use Option<String> as it's the most flexible type for PostgreSQL's implicit casting
        QValue::Nil(_) => Ok(Box::new(None::<String>)),
        QValue::Int(i) => {
            // Integer value - use i32 or i64 depending on magnitude
            let abs_val = i.value.abs();
            if abs_val < 2147483648 {
                Ok(Box::new(i.value as i32))
            } else {
                Ok(Box::new(i.value))
            }
        }
        QValue::Num(n) => {
            if n.value.fract() == 0.0 {
                // Integer value - use i32 or i64 depending on magnitude
                // Note: We don't use i16 because prepared statements are too strict about type matching
                // and i32 should work for all integer columns via PostgreSQL's type casting
                let abs_val = n.value.abs();
                if abs_val < 2147483648.0 {
                    // Fits in i32 (PostgreSQL INTEGER/INT4)
                    Ok(Box::new(n.value as i32))
                } else {
                    // Fits in i64 (PostgreSQL BIGINT/INT8)
                    Ok(Box::new(n.value as i64))
                }
            } else {
                // Float (PostgreSQL REAL/DOUBLE PRECISION)
                // Use f32 by default since PostgreSQL will auto-promote to f64 when needed
                // but won't auto-demote f64 to f32 for REAL columns
                Ok(Box::new(n.value as f32))
            }
        }
        QValue::Float(f) => Ok(Box::new(f.value as f32)),
        QValue::Decimal(d) => {
            // Decimal maps directly to PostgreSQL NUMERIC/DECIMAL
            Ok(Box::new(d.value))
        }
        QValue::Str(s) => Ok(Box::new(s.value.clone())),
        QValue::Bool(b) => Ok(Box::new(b.value)),
        QValue::Bytes(b) => Ok(Box::new(b.data.clone())),
        QValue::Uuid(u) => Ok(Box::new(u.value)),

        // Date/Time types
        QValue::Timestamp(ts) => {
            // Timestamps map to TIMESTAMP (without time zone) which uses NaiveDateTime
            let chrono_dt = jiff_timestamp_to_chrono(ts);
            Ok(Box::new(chrono_dt.naive_utc()))
        }
        QValue::Zoned(z) => {
            // Zoned datetimes map to TIMESTAMPTZ (with time zone) which uses DateTime<Utc>
            let chrono_dt = jiff_zoned_to_chrono(z);
            Ok(Box::new(chrono_dt))
        }
        QValue::Date(d) => {
            let chrono_date = jiff_date_to_chrono(d);
            Ok(Box::new(chrono_date))
        }
        QValue::Time(t) => {
            let chrono_time = jiff_time_to_chrono(t);
            Ok(Box::new(chrono_time))
        }
        QValue::Span(s) => {
            let interval = jiff_span_to_pg_interval(s);
            Ok(Box::new(interval))
        }

        // Arrays can be either PostgreSQL ARRAY types or JSON
        // We always convert to JSON since it's more flexible and works for both
        QValue::Array(_) => {
            let json_value = qvalue_to_json(value)?;
            Ok(Box::new(json_value))
        }

        // JSON/JSONB types - Dict always maps to JSON
        QValue::Dict(_) => {
            let json_value = qvalue_to_json(value)?;
            Ok(Box::new(json_value))
        }

        _ => Err(format!("Cannot convert {} to SQL parameter", value.q_type()))
    }
}

/// Execute statement with parameters
fn execute_with_params(conn: &mut Client, sql: &str, params: Option<&QValue>) -> Result<u64, String> {
    if let Some(params_value) = params {
        match params_value {
            QValue::Array(arr) => {
                // Positional parameters ($1, $2, etc)
                let pg_params: Result<Vec<Box<dyn ToSql + Sync>>, String> = arr.elements.iter()
                    .map(qvalue_to_pg_param)
                    .collect();
                let pg_params = pg_params?;
                let params_refs: Vec<&(dyn ToSql + Sync)> = pg_params.iter()
                    .map(|p| p.as_ref())
                    .collect();

                conn.execute(sql, params_refs.as_slice())
                    .map_err(|e| map_postgres_error(e))
            }
            _ => Err("PostgreSQL only supports positional parameters (arrays)".to_string())
        }
    } else {
        conn.execute(sql, &[])
            .map_err(|e| map_postgres_error(e))
    }
}

/// Query with parameters and return rows with column metadata
fn query_with_params_and_metadata(conn: &mut Client, sql: &str, params: Option<&QValue>) -> Result<(Vec<HashMap<String, QValue>>, Vec<ColumnDescription>), String> {
    // Execute the query without prepared statement to allow type flexibility
    let rows = if let Some(params_value) = params {
        match params_value {
            QValue::Array(arr) => {
                // Positional parameters
                let pg_params: Result<Vec<Box<dyn ToSql + Sync>>, String> = arr.elements.iter()
                    .map(qvalue_to_pg_param)
                    .collect();
                let pg_params = pg_params?;
                let params_refs: Vec<&(dyn ToSql + Sync)> = pg_params.iter()
                    .map(|p| p.as_ref())
                    .collect();

                conn.query(sql, params_refs.as_slice())
                    .map_err(|e| map_postgres_error(e))?
            }
            _ => return Err("PostgreSQL only supports positional parameters (arrays)".to_string())
        }
    } else {
        conn.query(sql, &[])
            .map_err(|e| map_postgres_error(e))?
    };

    // Get column metadata from the first row if available
    // If no rows, we'll have empty column metadata
    let columns: Vec<ColumnDescription> = if let Some(first_row) = rows.first() {
        first_row.columns().iter().map(|col| ColumnDescription {
            name: col.name().to_string(),
            type_code: format!("{:?}", col.type_()),
        }).collect()
    } else {
        // For empty result sets, prepare the statement to get column info
        let stmt = conn.prepare(sql)
            .map_err(|e| map_postgres_error(e))?;
        stmt.columns().iter().map(|col| ColumnDescription {
            name: col.name().to_string(),
            type_code: format!("{:?}", col.type_()),
        }).collect()
    };

    let mut results = Vec::new();
    for row in rows {
        results.push(row_to_dict(&row)?);
    }
    Ok((results, columns))
}

/// Convert PostgreSQL row to Quest dict
fn row_to_dict(row: &Row) -> Result<HashMap<String, QValue>, String> {
    let mut dict = HashMap::new();

    for (idx, column) in row.columns().iter().enumerate() {
        let col_name = column.name().to_string();

        // Try to get value as different types
        // Try date/time types first (they're more specific)
        let value = if let Ok(v) = row.try_get::<_, Option<DateTime<Utc>>>(idx) {
            // TIMESTAMPTZ returns DateTime<Utc> -> convert to QZoned (timezone-aware)
            v.map(|dt| QValue::Zoned(chrono_to_jiff_zoned(dt.naive_utc()))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<NaiveDateTime>>(idx) {
            // TIMESTAMP returns NaiveDateTime -> convert to QTimestamp (no timezone)
            v.map(|dt| QValue::Timestamp(chrono_to_jiff_timestamp_from_naive(dt))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<NaiveDate>>(idx) {
            v.map(|d| QValue::Date(chrono_to_jiff_date(d))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<NaiveTime>>(idx) {
            v.map(|t| QValue::Time(chrono_to_jiff_time(t))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Interval>>(idx) {
            v.map(|i| QValue::Span(pg_interval_to_jiff_span(&i))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<serde_json::Value>>(idx) {
            // JSON and JSONB both return serde_json::Value
            v.map(|j| json_to_qvalue(&j)).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<i32>>>(idx) {
            // INTEGER[] or INT[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|i| QValue::Int(QInt::new(i as i64))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<i64>>>(idx) {
            // BIGINT[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|i| QValue::Int(QInt::new(i))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<f32>>>(idx) {
            // REAL[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|f| QValue::Float(QFloat::new(f as f64))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<f64>>>(idx) {
            // DOUBLE PRECISION[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|f| QValue::Float(QFloat::new(f))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<String>>>(idx) {
            // TEXT[] or VARCHAR[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|s| QValue::Str(QString::new(s))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<bool>>>(idx) {
            // BOOLEAN[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|b| QValue::Bool(QBool::new(b))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<uuid::Uuid>>>(idx) {
            // UUID[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|u| QValue::Uuid(QUuid::new(u))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<Decimal>>>(idx) {
            // NUMERIC[] or DECIMAL[] arrays
            v.map(|arr| {
                let elements: Vec<QValue> = arr.into_iter().map(|d| QValue::Decimal(QDecimal::new(d))).collect();
                QValue::Array(QArray::new(elements))
            }).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<uuid::Uuid>>(idx) {
            v.map(|u| QValue::Uuid(QUuid::new(u))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<i32>>(idx) {
            v.map(|i| QValue::Int(QInt::new(i as i64))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<i64>>(idx) {
            v.map(|i| QValue::Int(QInt::new(i))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<f32>>(idx) {
            v.map(|f| QValue::Float(QFloat::new(f as f64))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<f64>>(idx) {
            v.map(|f| QValue::Float(QFloat::new(f))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Decimal>>(idx) {
            // NUMERIC/DECIMAL types
            v.map(|d| QValue::Decimal(QDecimal::new(d))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<String>>(idx) {
            v.map(|s| QValue::Str(QString::new(s))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<bool>>(idx) {
            v.map(|b| QValue::Bool(QBool::new(b))).unwrap_or(QValue::Nil(QNil))
        } else if let Ok(v) = row.try_get::<_, Option<Vec<u8>>>(idx) {
            v.map(|b| QValue::Bytes(QBytes::new(b))).unwrap_or(QValue::Nil(QNil))
        } else {
            // Default to nil for unsupported types
            QValue::Nil(QNil)
        };

        dict.insert(col_name, value);
    }

    Ok(dict)
}

/// Map postgres errors to QEP-001 exception hierarchy
fn map_postgres_error(err: postgres::Error) -> String {
    if let Some(db_err) = err.as_db_error() {
        match db_err.code().code() {
            "23505" => format!("IntegrityError: {}", db_err.message()),
            "23503" => format!("IntegrityError: {}", db_err.message()),
            "42P01" => format!("ProgrammingError: {}", db_err.message()),
            "42703" => format!("ProgrammingError: {}", db_err.message()),
            "42601" => format!("ProgrammingError: {}", db_err.message()),
            _ => format!("DatabaseError: {}", db_err.message())
        }
    } else {
        format!("DatabaseError: {}", err)
    }
}

/// Create the postgres module
pub fn create_postgres_module() -> QValue {
    let mut members = HashMap::new();

    // Add module functions
    members.insert("connect".to_string(), QValue::Fun(QFun {
        name: "connect".to_string(),
        parent_type: "postgres".to_string(),
        doc: "Open a connection to a PostgreSQL database.".to_string(),
        id: next_object_id(),
    }));

    QValue::Module(QModule::new("postgres".to_string(), members))
}

/// Call postgres module functions
pub fn call_postgres_function(func_name: &str, args: Vec<QValue>, _scope: &mut Scope) -> Result<QValue, String> {
    match func_name {
        "postgres.connect" => {
            if args.len() != 1 {
                return Err(format!("postgres.connect expects 1 argument (connection_string), got {}", args.len()));
            }
            let conn_str = args[0].as_str();

            let conn = Client::connect(&conn_str, postgres::NoTls)
                .map_err(|e| format!("DatabaseError: Failed to connect to database: {}", e))?;

            Ok(QValue::PostgresConnection(QPostgresConnection::new(conn)))
        }

        _ => Err(format!("Unknown function: {}", func_name))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // Note: These tests require a running PostgreSQL instance
    // Run: docker-compose up -d postgres

    fn get_test_connection_string() -> String {
        "host=localhost port=6432 user=quest password=quest_password dbname=quest_test".to_string()
    }

    #[test]
    #[ignore] // Requires PostgreSQL running
    fn test_connect() {
        let mut scope = Scope::new();
        let conn_str = get_test_connection_string();

        let result = call_postgres_function(
            "postgres.connect",
            vec![QValue::Str(QString::new(conn_str))],
            &mut scope
        );

        assert!(result.is_ok());
        match result.unwrap() {
            QValue::PostgresConnection(_) => {},
            _ => panic!("Expected PostgresConnection"),
        }
    }

    #[test]
    #[ignore] // Requires PostgreSQL running
    fn test_create_table() {
        let mut scope = Scope::new();
        let conn_str = get_test_connection_string();

        let conn_result = call_postgres_function(
            "postgres.connect",
            vec![QValue::Str(QString::new(conn_str))],
            &mut scope
        );
        assert!(conn_result.is_ok());

        if let QValue::PostgresConnection(conn) = conn_result.unwrap() {
            let cursor_result = conn.call_method("cursor", vec![]);
            assert!(cursor_result.is_ok());

            if let QValue::PostgresCursor(cursor) = cursor_result.unwrap() {
                // Drop table if exists
                let _ = cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new("DROP TABLE IF EXISTS test_users".to_string()))]
                );

                let sql = "CREATE TABLE test_users (id SERIAL PRIMARY KEY, name TEXT)";
                let result = cursor.call_method(
                    "execute",
                    vec![QValue::Str(QString::new(sql.to_string()))]
                );
                assert!(result.is_ok());
            }
        }
    }
}
