// Time Module for Quest
use crate::control_flow::EvalError;
// Provides comprehensive date and time handling using the jiff library

use crate::types::{QObj, QValue, QInt, QFloat, QString, QBool, QNil, next_object_id};
use crate::{arg_err, attr_err};
use jiff::{Timestamp as JiffTimestamp, Zoned as JiffZoned, civil::{Date as JiffDate, Time as JiffTime}, Span as JiffSpan, ToSpan, tz::TimeZone};
use std::collections::HashMap;
use crate::types::*;

// =============================================================================
// Type Definitions
// =============================================================================

/// QTimestamp - An instant in time (UTC, nanosecond precision)
#[derive(Debug, Clone)]
pub struct QTimestamp {
    pub timestamp: JiffTimestamp,
    pub id: u64,
}

impl QTimestamp {
    pub fn new(timestamp: JiffTimestamp) -> Self {
        Self {
            timestamp,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "to_zoned" => {
                if args.len() != 1 {
                    return arg_err!("to_zoned expects 1 argument (timezone), got {}", args.len());
                }
                match &args[0] {
                    QValue::Str(tz) => {
                        let zone = TimeZone::get(&tz.value)
                            .map_err(|e| format!("Invalid timezone '{}': {}", tz.value, e))?;
                        let zoned = self.timestamp.to_zoned(zone);
                        Ok(QValue::Zoned(QZoned::new(zoned)))
                    }
                    _ => Err("to_zoned expects a string timezone name".into()),
                }
            }
            "as_seconds" => {
                if !args.is_empty() {
                    return arg_err!("as_seconds expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.timestamp.as_second())))
            }
            "as_millis" => {
                if !args.is_empty() {
                    return arg_err!("as_millis expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.timestamp.as_millisecond())))
            }
            "as_micros" => {
                if !args.is_empty() {
                    return arg_err!("as_micros expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.timestamp.as_microsecond())))
            }
            "as_nanos" => {
                if !args.is_empty() {
                    return arg_err!("as_nanos expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.timestamp.as_nanosecond() as i64)))
            }
            "since" => {
                if args.len() != 1 {
                    return arg_err!("since expects 1 argument (other timestamp), got {}", args.len());
                }
                match &args[0] {
                    QValue::Timestamp(other) => {
                        let span = self.timestamp.since(other.timestamp)
                            .map_err(|e| format!("since error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    _ => Err("since expects a Timestamp object".into()),
                }
            }
            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on Timestamp", method_name),
        }
    }
}

impl QObj for QTimestamp {
    fn cls(&self) -> String {
        "Timestamp".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Timestamp"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Timestamp"
    }

    fn str(&self) -> String {
        format!("{}", self.timestamp)
    }

    fn _rep(&self) -> String {
        format!("Timestamp({})", self.timestamp)
    }

    fn _doc(&self) -> String {
        "An instant in time (UTC, nanosecond precision)".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// QZoned - A timezone-aware datetime
#[derive(Debug, Clone)]
pub struct QZoned {
    pub zoned: JiffZoned,
    pub id: u64,
}

impl QZoned {
    pub fn new(zoned: JiffZoned) -> Self {
        Self {
            zoned,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            // Component getters
            "year" => {
                if !args.is_empty() {
                    return arg_err!("year expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.year() as i64)))
            }
            "month" => {
                if !args.is_empty() {
                    return arg_err!("month expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.month() as i64)))
            }
            "day" => {
                if !args.is_empty() {
                    return arg_err!("day expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.day() as i64)))
            }
            "hour" => {
                if !args.is_empty() {
                    return arg_err!("hour expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.hour() as i64)))
            }
            "minute" => {
                if !args.is_empty() {
                    return arg_err!("minute expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.minute() as i64)))
            }
            "second" => {
                if !args.is_empty() {
                    return arg_err!("second expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.second() as i64)))
            }
            "millisecond" => {
                if !args.is_empty() {
                    return arg_err!("millisecond expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.millisecond() as i64)))
            }
            "microsecond" => {
                if !args.is_empty() {
                    return arg_err!("microsecond expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.microsecond() as i64)))
            }
            "nanosecond" => {
                if !args.is_empty() {
                    return arg_err!("nanosecond expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.subsec_nanosecond() as i64)))
            }
            "day_of_week" => {
                if !args.is_empty() {
                    return arg_err!("day_of_week expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.weekday().to_monday_one_offset() as i64)))
            }
            "day_of_year" => {
                if !args.is_empty() {
                    return arg_err!("day_of_year expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.zoned.day_of_year() as i64)))
            }
            "timezone" => {
                if !args.is_empty() {
                    return arg_err!("timezone expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.zoned.time_zone().iana_name().unwrap_or("UTC").to_string())))
            }
            "quarter" => {
                if !args.is_empty() {
                    return arg_err!("quarter expects 0 arguments, got {}", args.len());
                }
                // Calculate quarter from month (1-4)
                let quarter = ((self.zoned.month() - 1) / 3) + 1;
                Ok(QValue::Int(QInt::new(quarter as i64)))
            }

            // Formatting
            "format" => {
                if args.len() != 1 {
                    return arg_err!("format expects 1 argument (pattern), got {}", args.len());
                }
                match &args[0] {
                    QValue::Str(pattern) => {
                        let result = self.zoned.strftime(pattern.value.as_ref()).to_string();
                        Ok(QValue::Str(QString::new(result)))
                    }
                    _ => Err("format expects a string pattern".into()),
                }
            }
            "to_rfc3339" => {
                if !args.is_empty() {
                    return arg_err!("to_rfc3339 expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(format!("{:?}", self.zoned))))
            }

            // Timezone conversion
            "to_timezone" => {
                if args.len() != 1 {
                    return arg_err!("to_timezone expects 1 argument (timezone), got {}", args.len());
                }
                match &args[0] {
                    QValue::Str(tz) => {
                        let zone = TimeZone::get(&tz.value)
                            .map_err(|e| format!("Invalid timezone '{}': {}", tz.value, e))?;
                        let new_zoned = self.zoned.with_time_zone(zone);
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("to_timezone expects a string timezone name".into()),
                }
            }
            "to_utc" => {
                if !args.is_empty() {
                    return arg_err!("to_utc expects 0 arguments, got {}", args.len());
                }
                let utc_zone: jiff::tz::TimeZone = jiff::tz::TimeZone::UTC;
                let new_zoned = self.zoned.with_time_zone(utc_zone);
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }

            // Arithmetic
            "add_years" => {
                if args.len() != 1 {
                    return arg_err!("add_years expects 1 argument, got {}", args.len());
                }
                let years = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_years expects a number".into()),
                };
                let span = years.years();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_years error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add_months" => {
                if args.len() != 1 {
                    return arg_err!("add_months expects 1 argument, got {}", args.len());
                }
                let months = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_months expects a number".into()),
                };
                let span = months.months();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_months error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add_days" => {
                if args.len() != 1 {
                    return arg_err!("add_days expects 1 argument, got {}", args.len());
                }
                let days = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_days expects a number".into()),
                };
                let span = days.days();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_days error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add_hours" => {
                if args.len() != 1 {
                    return arg_err!("add_hours expects 1 argument, got {}", args.len());
                }
                let hours = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_hours expects a number".into()),
                };
                let span = hours.hours();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_hours error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add_minutes" => {
                if args.len() != 1 {
                    return arg_err!("add_minutes expects 1 argument, got {}", args.len());
                }
                let minutes = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_minutes expects a number".into()),
                };
                let span = minutes.minutes();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_minutes error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add_seconds" => {
                if args.len() != 1 {
                    return arg_err!("add_seconds expects 1 argument, got {}", args.len());
                }
                let seconds = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_seconds expects a number".into()),
                };
                let span = seconds.seconds();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("add_seconds error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "add" => {
                if args.len() != 1 {
                    return arg_err!("add expects 1 argument (span), got {}", args.len());
                }
                match &args[0] {
                    QValue::Span(span) => {
                        let new_zoned = self.zoned.checked_add(span.span)
                            .map_err(|e| format!("add error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add expects a Span object".into()),
                }
            }
            "subtract_years" => {
                if args.len() != 1 {
                    return arg_err!("subtract_years expects 1 argument, got {}", args.len());
                }
                let years = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_years expects a number".into()),
                };
                let span = years.years();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_years error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract_months" => {
                if args.len() != 1 {
                    return arg_err!("subtract_months expects 1 argument, got {}", args.len());
                }
                let months = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_months expects a number".into()),
                };
                let span = months.months();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_months error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract_days" => {
                if args.len() != 1 {
                    return arg_err!("subtract_days expects 1 argument, got {}", args.len());
                }
                let days = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_days expects a number".into()),
                };
                let span = days.days();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_days error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract_hours" => {
                if args.len() != 1 {
                    return arg_err!("subtract_hours expects 1 argument, got {}", args.len());
                }
                let hours = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_hours expects a number".into()),
                };
                let span = hours.hours();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_hours error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract_minutes" => {
                if args.len() != 1 {
                    return arg_err!("subtract_minutes expects 1 argument, got {}", args.len());
                }
                let minutes = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_minutes expects a number".into()),
                };
                let span = minutes.minutes();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_minutes error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract_seconds" => {
                if args.len() != 1 {
                    return arg_err!("subtract_seconds expects 1 argument, got {}", args.len());
                }
                let seconds = match &args[0] {
                    QValue::Int(n) => -n.value,
                    QValue::Float(n) => -(n.value as i64),
                    _ => return Err("subtract_seconds expects a number".into()),
                };
                let span = seconds.seconds();
                let new_zoned = self.zoned.checked_add(span)
                    .map_err(|e| format!("subtract_seconds error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "subtract" => {
                if args.len() != 1 {
                    return arg_err!("subtract expects 1 argument (span), got {}", args.len());
                }
                match &args[0] {
                    QValue::Span(span) => {
                        let new_zoned = self.zoned.checked_sub(span.span)
                            .map_err(|e| format!("subtract error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract expects a Span object".into()),
                }
            }
            "since" => {
                if args.len() != 1 {
                    return arg_err!("since expects 1 argument (other), got {}", args.len());
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        let span = self.zoned.since(&other.zoned)
                            .map_err(|e| format!("since error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    QValue::Timestamp(ts) => {
                        let other_zoned = ts.timestamp.to_zoned(self.zoned.time_zone().clone());
                        let span = self.zoned.since(&other_zoned)
                            .map_err(|e| format!("since error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    _ => Err("since expects a Zoned or Timestamp object".into()),
                }
            }

            // Comparison
            "equals" => {
                if args.len() != 1 {
                    return arg_err!("equals expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() == other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() == ts.timestamp)))
                    }
                    _ => Err("equals expects a Zoned or Timestamp object".into()),
                }
            }
            "before" => {
                if args.len() != 1 {
                    return arg_err!("before expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() < other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() < ts.timestamp)))
                    }
                    _ => Err("before expects a Zoned or Timestamp object".into()),
                }
            }
            "after" => {
                if args.len() != 1 {
                    return arg_err!("after expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() > other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() > ts.timestamp)))
                    }
                    _ => Err("after expects a Zoned or Timestamp object".into()),
                }
            }

            // Rounding
            "round_to_hour" => {
                if !args.is_empty() {
                    return arg_err!("round_to_hour expects 0 arguments, got {}", args.len());
                }
                let new_zoned = self.zoned.round(jiff::Unit::Hour)
                    .map_err(|e| format!("round_to_hour error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "round_to_minute" => {
                if !args.is_empty() {
                    return arg_err!("round_to_minute expects 0 arguments, got {}", args.len());
                }
                let new_zoned = self.zoned.round(jiff::Unit::Minute)
                    .map_err(|e| format!("round_to_minute error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "start_of_day" => {
                if !args.is_empty() {
                    return arg_err!("start_of_day expects 0 arguments, got {}", args.len());
                }
                let new_zoned = self.zoned.start_of_day()
                    .map_err(|e| format!("start_of_day error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "end_of_day" => {
                if !args.is_empty() {
                    return arg_err!("end_of_day expects 0 arguments, got {}", args.len());
                }
                let new_zoned = self.zoned.end_of_day()
                    .map_err(|e| format!("end_of_day error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "start_of_month" => {
                if !args.is_empty() {
                    return arg_err!("start_of_month expects 0 arguments, got {}", args.len());
                }
                // Set to first day of month, start of day
                let date = self.zoned.date();
                let first_day = date.first_of_month();
                let new_zoned = first_day.to_zoned(self.zoned.time_zone().clone())
                    .map_err(|e| format!("start_of_month error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "end_of_month" => {
                if !args.is_empty() {
                    return arg_err!("end_of_month expects 0 arguments, got {}", args.len());
                }
                // Set to last day of month, end of day
                let date = self.zoned.date();
                let last_day = date.last_of_month();
                let last_zoned = last_day.to_zoned(self.zoned.time_zone().clone())
                    .map_err(|e| format!("end_of_month error: {}", e))?;
                let new_zoned = last_zoned.end_of_day()
                    .map_err(|e| format!("end_of_month error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "start_of_quarter" => {
                if !args.is_empty() {
                    return arg_err!("start_of_quarter expects 0 arguments, got {}", args.len());
                }
                // Calculate first month of quarter
                let quarter = ((self.zoned.month() - 1) / 3) + 1;
                let first_month = (quarter - 1) * 3 + 1;

                let year = self.zoned.year();
                let first_date = JiffDate::new(year, first_month, 1)
                    .map_err(|e| format!("start_of_quarter error: {}", e))?;
                let new_zoned = first_date.to_zoned(self.zoned.time_zone().clone())
                    .map_err(|e| format!("start_of_quarter error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "end_of_quarter" => {
                if !args.is_empty() {
                    return arg_err!("end_of_quarter expects 0 arguments, got {}", args.len());
                }
                // Calculate last month of quarter
                let quarter = ((self.zoned.month() - 1) / 3) + 1;
                let last_month = quarter * 3;

                let year = self.zoned.year();
                let temp_date = JiffDate::new(year, last_month, 1)
                    .map_err(|e| format!("end_of_quarter error: {}", e))?;
                let last_day = temp_date.last_of_month();
                let last_zoned = last_day.to_zoned(self.zoned.time_zone().clone())
                    .map_err(|e| format!("end_of_quarter error: {}", e))?;
                let new_zoned = last_zoned.end_of_day()
                    .map_err(|e| format!("end_of_quarter error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }

            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on Zoned", method_name),
        }
    }
}

impl QObj for QZoned {
    fn cls(&self) -> String {
        "Zoned".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Zoned"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Zoned"
    }

    fn str(&self) -> String {
        format!("{}", self.zoned)
    }

    fn _rep(&self) -> String {
        format!("Zoned({})", self.zoned)
    }

    fn _doc(&self) -> String {
        "A timezone-aware datetime".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// QDate - A calendar date (year, month, day)
#[derive(Debug, Clone)]
pub struct QDate {
    pub date: JiffDate,
    pub id: u64,
}

impl QDate {
    pub fn new(date: JiffDate) -> Self {
        Self {
            date,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            // Component getters
            "year" => {
                if !args.is_empty() {
                    return arg_err!("year expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.date.year() as i64)))
            }
            "month" => {
                if !args.is_empty() {
                    return arg_err!("month expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.date.month() as i64)))
            }
            "day" => {
                if !args.is_empty() {
                    return arg_err!("day expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.date.day() as i64)))
            }
            "day_of_week" => {
                if !args.is_empty() {
                    return arg_err!("day_of_week expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.date.weekday().to_monday_one_offset() as i64)))
            }
            "day_of_year" => {
                if !args.is_empty() {
                    return arg_err!("day_of_year expects 0 arguments, got {}", args.len());
                }
                match self.date.day_of_year_no_leap() {
                    Some(doy) => Ok(QValue::Int(QInt::new(doy as i64))),
                    None => Err("Failed to get day of year".into()),
                }
            }
            "week_number" => {
                if !args.is_empty() {
                    return arg_err!("week_number expects 0 arguments, got {}", args.len());
                }
                // Get ISO week number (1-53)
                let iso = self.date.iso_week_date();
                Ok(QValue::Int(QInt::new(iso.week() as i64)))
            }
            "iso_year" => {
                if !args.is_empty() {
                    return arg_err!("iso_year expects 0 arguments, got {}", args.len());
                }
                // Get ISO year (may differ from calendar year for week 1)
                let iso = self.date.iso_week_date();
                Ok(QValue::Int(QInt::new(iso.year() as i64)))
            }
            "quarter" => {
                if !args.is_empty() {
                    return arg_err!("quarter expects 0 arguments, got {}", args.len());
                }
                // Calculate quarter from month (1-4)
                let quarter = ((self.date.month() - 1) / 3) + 1;
                Ok(QValue::Int(QInt::new(quarter as i64)))
            }

            // Arithmetic
            "add_days" => {
                if args.len() != 1 {
                    return arg_err!("add_days expects 1 argument, got {}", args.len());
                }
                let days = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_days expects a number".into()),
                };
                let span = days.days();
                let new_date = self.date.checked_add(span)
                    .map_err(|e| format!("add_days error: {}", e))?;
                Ok(QValue::Date(QDate::new(new_date)))
            }
            "add_months" => {
                if args.len() != 1 {
                    return arg_err!("add_months expects 1 argument, got {}", args.len());
                }
                let months = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_months expects a number".into()),
                };
                let span = months.months();
                let new_date = self.date.checked_add(span)
                    .map_err(|e| format!("add_months error: {}", e))?;
                Ok(QValue::Date(QDate::new(new_date)))
            }
            "add_years" => {
                if args.len() != 1 {
                    return arg_err!("add_years expects 1 argument, got {}", args.len());
                }
                let years = match &args[0] {
                    QValue::Int(n) => n.value,
                    QValue::Float(n) => n.value as i64,
                    _ => return Err("add_years expects a number".into()),
                };
                let span = years.years();
                let new_date = self.date.checked_add(span)
                    .map_err(|e| format!("add_years error: {}", e))?;
                Ok(QValue::Date(QDate::new(new_date)))
            }

            // Duration calculation
            "since" => {
                if args.len() != 1 {
                    return arg_err!("since expects 1 argument (other date), got {}", args.len());
                }
                match &args[0] {
                    QValue::Date(other) => {
                        let span = self.date.since(other.date)
                            .map_err(|e| format!("since error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    _ => Err("since expects a Date object".into()),
                }
            }

            // Combine with time
            "at_time" => {
                if args.len() < 1 || args.len() > 2 {
                    return arg_err!("at_time expects 1 or 2 arguments (time, timezone?), got {}", args.len());
                }
                match &args[0] {
                    QValue::Time(time_val) => {
                        let tz_name = if args.len() == 2 {
                            args[1].as_str()
                        } else {
                            "UTC".to_string()
                        };

                        let zone = TimeZone::get(&tz_name)
                            .map_err(|e| format!("Invalid timezone '{}': {}", tz_name, e))?;

                        let datetime = self.date.at(
                            time_val.time.hour(),
                            time_val.time.minute(),
                            time_val.time.second(),
                            time_val.time.subsec_nanosecond()
                        );

                        let zoned = datetime.to_zoned(zone)
                            .map_err(|e| format!("Failed to create zoned datetime: {}", e))?;

                        Ok(QValue::Zoned(QZoned::new(zoned)))
                    }
                    _ => Err("at_time expects a Time object as first argument".into()),
                }
            }

            // Comparison
            "equals" => {
                if args.len() != 1 {
                    return arg_err!("equals expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date == other.date)))
                    }
                    _ => Err("equals expects a Date object".into()),
                }
            }
            "before" => {
                if args.len() != 1 {
                    return arg_err!("before expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date < other.date)))
                    }
                    _ => Err("before expects a Date object".into()),
                }
            }
            "after" => {
                if args.len() != 1 {
                    return arg_err!("after expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date > other.date)))
                    }
                    _ => Err("after expects a Date object".into()),
                }
            }

            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on Date", method_name),
        }
    }
}

impl QObj for QDate {
    fn cls(&self) -> String {
        "Date".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Date"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Date"
    }

    fn str(&self) -> String {
        format!("{}", self.date)
    }

    fn _rep(&self) -> String {
        format!("Date({})", self.date)
    }

    fn _doc(&self) -> String {
        "A calendar date (year, month, day)".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// QTime - A time of day (hour, minute, second, nanosecond)
#[derive(Debug, Clone)]
pub struct QTime {
    pub time: JiffTime,
    pub id: u64,
}

impl QTime {
    pub fn new(time: JiffTime) -> Self {
        Self {
            time,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "hour" => {
                if !args.is_empty() {
                    return arg_err!("hour expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.time.hour() as i64)))
            }
            "minute" => {
                if !args.is_empty() {
                    return arg_err!("minute expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.time.minute() as i64)))
            }
            "second" => {
                if !args.is_empty() {
                    return arg_err!("second expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.time.second() as i64)))
            }
            "nanosecond" => {
                if !args.is_empty() {
                    return arg_err!("nanosecond expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.time.subsec_nanosecond() as i64)))
            }

            // Duration calculation
            "since" => {
                if args.len() != 1 {
                    return arg_err!("since expects 1 argument (other time), got {}", args.len());
                }
                match &args[0] {
                    QValue::Time(other) => {
                        let span = self.time.since(other.time)
                            .map_err(|e| format!("since error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    _ => Err("since expects a Time object".into()),
                }
            }

            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on Time", method_name),
        }
    }
}

impl QObj for QTime {
    fn cls(&self) -> String {
        "Time".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Time"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Time"
    }

    fn str(&self) -> String {
        format!("{}", self.time)
    }

    fn _rep(&self) -> String {
        format!("Time({})", self.time)
    }

    fn _doc(&self) -> String {
        "A time of day (hour, minute, second, nanosecond)".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

/// QSpan - A duration mixing calendar and clock units
#[derive(Debug, Clone)]
pub struct QSpan {
    pub span: JiffSpan,
    pub id: u64,
}

/// QDateRange - A range of dates
#[derive(Debug, Clone)]
pub struct QDateRange {
    pub start: JiffDate,
    pub end: JiffDate,
    pub id: u64,
}

impl QDateRange {
    pub fn new(start: JiffDate, end: JiffDate) -> Self {
        Self {
            start,
            end,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "start" => {
                if !args.is_empty() {
                    return arg_err!("start expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Date(QDate::new(self.start)))
            }
            "end" => {
                if !args.is_empty() {
                    return arg_err!("end expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Date(QDate::new(self.end)))
            }
            "contains" => {
                if args.len() != 1 {
                    return arg_err!("contains expects 1 argument (date), got {}", args.len());
                }
                match &args[0] {
                    QValue::Date(date) => {
                        let result = date.date >= self.start && date.date <= self.end;
                        Ok(QValue::Bool(QBool::new(result)))
                    }
                    _ => Err("contains expects a Date object".into()),
                }
            }
            "overlaps" => {
                if args.len() != 1 {
                    return arg_err!("overlaps expects 1 argument (range), got {}", args.len());
                }
                match &args[0] {
                    QValue::DateRange(other) => {
                        // Ranges overlap if: start1 <= end2 && start2 <= end1
                        let result = self.start <= other.end && other.start <= self.end;
                        Ok(QValue::Bool(QBool::new(result)))
                    }
                    _ => Err("overlaps expects a DateRange object".into()),
                }
            }
            "duration" => {
                if !args.is_empty() {
                    return arg_err!("duration expects 0 arguments, got {}", args.len());
                }
                let span = self.end.since(self.start)
                    .map_err(|e| format!("duration error: {}", e))?;
                Ok(QValue::Span(QSpan::new(span)))
            }
            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on DateRange", method_name),
        }
    }
}

impl QObj for QDateRange {
    fn cls(&self) -> String {
        "DateRange".to_string()
    }

    fn q_type(&self) -> &'static str {
        "DateRange"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "DateRange"
    }

    fn str(&self) -> String {
        format!("{}..{}", self.start, self.end)
    }

    fn _rep(&self) -> String {
        format!("DateRange({}..{})", self.start, self.end)
    }

    fn _doc(&self) -> String {
        "A range of dates".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl QSpan {
    pub fn new(span: JiffSpan) -> Self {
        Self {
            span,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }


        match method_name {
            // Component getters
            "years" => {
                if !args.is_empty() {
                    return arg_err!("years expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_years() as i64)))
            }
            "months" => {
                if !args.is_empty() {
                    return arg_err!("months expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_months() as i64)))
            }
            "days" => {
                if !args.is_empty() {
                    return arg_err!("days expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_days() as i64)))
            }
            "hours" => {
                if !args.is_empty() {
                    return arg_err!("hours expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_hours() as i64)))
            }
            "minutes" => {
                if !args.is_empty() {
                    return arg_err!("minutes expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_minutes() as i64)))
            }
            "seconds" => {
                if !args.is_empty() {
                    return arg_err!("seconds expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.span.get_seconds() as i64)))
            }

            // Conversion
            "as_hours" => {
                if !args.is_empty() {
                    return arg_err!("as_hours expects 0 arguments, got {}", args.len());
                }
                let total = self.span.total(jiff::Unit::Hour)
                    .map_err(|e| format!("as_hours error: {}", e))?;
                Ok(QValue::Float(QFloat::new(total)))
            }
            "as_minutes" => {
                if !args.is_empty() {
                    return arg_err!("as_minutes expects 0 arguments, got {}", args.len());
                }
                let total = self.span.total(jiff::Unit::Minute)
                    .map_err(|e| format!("as_minutes error: {}", e))?;
                Ok(QValue::Float(QFloat::new(total)))
            }
            "as_seconds" => {
                if !args.is_empty() {
                    return arg_err!("as_seconds expects 0 arguments, got {}", args.len());
                }
                let total = self.span.total(jiff::Unit::Second)
                    .map_err(|e| format!("as_seconds error: {}", e))?;
                Ok(QValue::Float(QFloat::new(total)))
            }
            "as_millis" => {
                if !args.is_empty() {
                    return arg_err!("as_millis expects 0 arguments, got {}", args.len());
                }
                let total = self.span.total(jiff::Unit::Millisecond)
                    .map_err(|e| format!("as_millis error: {}", e))?;
                Ok(QValue::Float(QFloat::new(total)))
            }

            // Arithmetic
            "add" => {
                if args.len() != 1 {
                    return arg_err!("add expects 1 argument (other), got {}", args.len());
                }
                match &args[0] {
                    QValue::Span(other) => {
                        let new_span = self.span.checked_add(other.span)
                            .map_err(|e| format!("add error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("add expects a Span object".into()),
                }
            }
            "subtract" => {
                if args.len() != 1 {
                    return arg_err!("subtract expects 1 argument (other), got {}", args.len());
                }
                match &args[0] {
                    QValue::Span(other) => {
                        let new_span = self.span.checked_sub(other.span)
                            .map_err(|e| format!("subtract error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("subtract expects a Span object".into()),
                }
            }
            "multiply" => {
                if args.len() != 1 {
                    return arg_err!("multiply expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(n) => {
                        let new_span = self.span.checked_mul(n.value)
                            .map_err(|e| format!("multiply error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    QValue::Float(n) => {
                        let new_span = self.span.checked_mul(n.value as i64)
                            .map_err(|e| format!("multiply error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("multiply expects a number".into()),
                }
            }
            "divide" => {
                if args.len() != 1 {
                    return arg_err!("divide expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Int(n) => {
                        if n.value == 0 {
                            return Err("Cannot divide by zero".into());
                        }
                        // Jiff doesn't have checked_div, so we multiply by reciprocal
                        let reciprocal = 1.0 / n.value as f64;
                        let new_span = self.span.checked_mul(reciprocal as i64)
                            .map_err(|e| format!("divide error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    QValue::Float(n) => {
                        if n.value == 0.0 {
                            return Err("Cannot divide by zero".into());
                        }
                        // Jiff doesn't have checked_div, so we multiply by reciprocal
                        let reciprocal = 1.0 / n.value;
                        let new_span = self.span.checked_mul(reciprocal as i64)
                            .map_err(|e| format!("divide error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("divide expects a number".into()),
                }
            }

            "humanize" => {
                if !args.is_empty() {
                    return arg_err!("humanize expects 0 arguments, got {}", args.len());
                }

                // Convert span to human-friendly description
                let total_seconds = match self.span.total(jiff::Unit::Second) {
                    Ok(s) => s,
                    Err(_) => return Err("Cannot humanize this span".into()),
                };

                let abs_seconds = total_seconds.abs();
                let is_past = total_seconds < 0.0;

                let result = if abs_seconds < 60.0 {
                    // Less than a minute
                    let secs = abs_seconds as i64;
                    if secs == 1 {
                        "1 second".to_string()
                    } else {
                        format!("{} seconds", secs)
                    }
                } else if abs_seconds < 3600.0 {
                    // Less than an hour
                    let mins = (abs_seconds / 60.0) as i64;
                    if mins == 1 {
                        "1 minute".to_string()
                    } else {
                        format!("{} minutes", mins)
                    }
                } else if abs_seconds < 86400.0 {
                    // Less than a day
                    let hours = (abs_seconds / 3600.0) as i64;
                    if hours == 1 {
                        "1 hour".to_string()
                    } else {
                        format!("{} hours", hours)
                    }
                } else if abs_seconds < 2592000.0 {
                    // Less than 30 days
                    let days = (abs_seconds / 86400.0) as i64;
                    if days == 1 {
                        "1 day".to_string()
                    } else {
                        format!("{} days", days)
                    }
                } else if abs_seconds < 31536000.0 {
                    // Less than a year
                    let months = (abs_seconds / 2592000.0) as i64;
                    if months == 1 {
                        "1 month".to_string()
                    } else {
                        format!("{} months", months)
                    }
                } else {
                    // Years
                    let years = (abs_seconds / 31536000.0) as i64;
                    if years == 1 {
                        "1 year".to_string()
                    } else {
                        format!("{} years", years)
                    }
                };

                let final_result = if is_past {
                    format!("{} ago", result)
                } else {
                    format!("in {}", result)
                };

                Ok(QValue::Str(QString::new(final_result)))
            }

            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            _ => attr_err!("Unknown method '{}' on Span", method_name),
        }
    }
}

impl QObj for QSpan {
    fn cls(&self) -> String {
        "Span".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Span"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Span"
    }

    fn str(&self) -> String {
        format!("{}", self.span)
    }

    fn _rep(&self) -> String {
        format!("Span({})", self.span)
    }

    fn _doc(&self) -> String {
        "A duration mixing calendar and clock units".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

// =============================================================================
// Module Creation
// =============================================================================

pub fn create_time_module() -> QValue {
    let mut module = HashMap::new();

    // Current time functions
    module.insert("now".to_string(), create_fn("time", "now"));
    module.insert("now_local".to_string(), create_fn("time", "now_local"));
    module.insert("today".to_string(), create_fn("time", "today"));
    module.insert("time_now".to_string(), create_fn("time", "time_now"));

    // Construction functions
    module.insert("parse".to_string(), create_fn("time", "parse"));
    module.insert("parse_duration".to_string(), create_fn("time", "parse_duration"));
    module.insert("datetime".to_string(), create_fn("time", "datetime"));
    module.insert("date".to_string(), create_fn("time", "date"));
    module.insert("time".to_string(), create_fn("time", "time"));
    module.insert("from_iso_week".to_string(), create_fn("time", "from_iso_week"));
    module.insert("from_timestamp".to_string(), create_fn("time", "from_timestamp"));
    module.insert("from_timestamp_ms".to_string(), create_fn("time", "from_timestamp_ms"));
    module.insert("from_timestamp_us".to_string(), create_fn("time", "from_timestamp_us"));

    // Span creation functions
    module.insert("span".to_string(), create_fn("time", "span"));
    module.insert("days".to_string(), create_fn("time", "days"));
    module.insert("hours".to_string(), create_fn("time", "hours"));
    module.insert("minutes".to_string(), create_fn("time", "minutes"));
    module.insert("seconds".to_string(), create_fn("time", "seconds"));

    // Date range functions
    module.insert("range".to_string(), create_fn("time", "range"));

    // Utility functions
    module.insert("sleep".to_string(), create_fn("time", "sleep"));
    module.insert("is_leap_year".to_string(), create_fn("time", "is_leap_year"));
    module.insert("ticks_ms".to_string(), create_fn("time", "ticks_ms"));

    QValue::Module(Box::new(QModule::new("time".to_string(), module)))
}

// =============================================================================
// Function Handler
// =============================================================================

/// Handle time.* function calls
pub fn call_time_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, EvalError> {
    match func_name {
        "time.now" => {
            if !args.is_empty() {
                return arg_err!("time.now expects 0 arguments, got {}", args.len());
            }
            let now = JiffTimestamp::now();
            Ok(QValue::Timestamp(QTimestamp::new(now)))
        }

        "time.now_local" => {
            if !args.is_empty() {
                return arg_err!("time.now_local expects 0 arguments, got {}", args.len());
            }
            let now = JiffZoned::now();
            Ok(QValue::Zoned(QZoned::new(now)))
        }

        "time.today" => {
            if !args.is_empty() {
                return arg_err!("time.today expects 0 arguments, got {}", args.len());
            }
            let now = JiffZoned::now();
            let today = now.date();
            Ok(QValue::Date(QDate::new(today)))
        }

        "time.time_now" => {
            if !args.is_empty() {
                return arg_err!("time.time_now expects 0 arguments, got {}", args.len());
            }
            let now = JiffZoned::now();
            let time = now.time();
            Ok(QValue::Time(QTime::new(time)))
        }

        "time.datetime" => {
            // time.datetime(year, month, day, hour, minute, second, timezone?)
            if args.len() < 6 || args.len() > 7 {
                return arg_err!("time.datetime expects 6 or 7 arguments (year, month, day, hour, minute, second, timezone?), got {}", args.len());
            }

            let year = args[0].as_num()? as i16;
            let month = args[1].as_num()? as i8;
            let day = args[2].as_num()? as i8;
            let hour = args[3].as_num()? as i8;
            let minute = args[4].as_num()? as i8;
            let second = args[5].as_num()? as i8;

            let tz_name = if args.len() == 7 {
                args[6].as_str()
            } else {
                "UTC".to_string()
            };

            let tz = TimeZone::get(&tz_name)
                .map_err(|e| format!("Invalid timezone '{}': {}", tz_name, e))?;

            let zoned = jiff::civil::date(year, month, day)
                .at(hour, minute, second, 0)
                .to_zoned(tz)
                .map_err(|e| format!("Failed to create datetime: {}", e))?;

            Ok(QValue::Zoned(QZoned::new(zoned)))
        }

        "time.date" => {
            // time.date(year, month, day)
            if args.len() != 3 {
                return arg_err!("time.date expects 3 arguments (year, month, day), got {}", args.len());
            }

            let year = args[0].as_num()? as i16;
            let month = args[1].as_num()? as i8;
            let day = args[2].as_num()? as i8;

            let date = JiffDate::new(year, month, day)
                .map_err(|e| format!("Invalid date: {}", e))?;

            Ok(QValue::Date(QDate::new(date)))
        }

        "time.from_iso_week" => {
            // time.from_iso_week(year, week, weekday)
            if args.len() != 3 {
                return arg_err!("time.from_iso_week expects 3 arguments (iso_year, week, weekday), got {}", args.len());
            }

            let year = args[0].as_num()? as i16;
            let week = args[1].as_num()? as i8;
            let weekday_num = args[2].as_num()? as i8;

            // Create ISOWeekDate and convert to Date
            use jiff::civil::{ISOWeekDate, Weekday};
            let weekday = match weekday_num {
                1 => Weekday::Monday,
                2 => Weekday::Tuesday,
                3 => Weekday::Wednesday,
                4 => Weekday::Thursday,
                5 => Weekday::Friday,
                6 => Weekday::Saturday,
                7 => Weekday::Sunday,
                _ => return arg_err!("Invalid weekday: {} (must be 1-7, where 1=Monday)", weekday_num),
            };

            let iso = ISOWeekDate::new(year, week, weekday)
                .map_err(|e| format!("Invalid ISO week date: {}", e))?;
            let date = iso.date();

            Ok(QValue::Date(QDate::new(date)))
        }

        "time.time" => {
            // time.time(hour, minute, second, nanosecond?)
            if args.len() < 3 || args.len() > 4 {
                return arg_err!("time.time expects 3 or 4 arguments (hour, minute, second, nanosecond?), got {}", args.len());
            }

            let hour = args[0].as_num()? as i8;
            let minute = args[1].as_num()? as i8;
            let second = args[2].as_num()? as i8;
            let nanosecond = if args.len() == 4 {
                args[3].as_num()? as i32
            } else {
                0
            };

            let time = JiffTime::new(hour, minute, second, nanosecond)
                .map_err(|e| format!("Invalid time: {}", e))?;

            Ok(QValue::Time(QTime::new(time)))
        }

        "time.parse" => {
            if args.len() != 1 {
                return arg_err!("time.parse expects 1 argument (string), got {}", args.len());
            }

            let input = args[0].as_str();

            // Try parsing as Zoned (with timezone) first
            if let Ok(zoned) = input.parse::<JiffZoned>() {
                return Ok(QValue::Zoned(QZoned::new(zoned)));
            }

            // Try parsing as Timestamp (UTC)
            if let Ok(timestamp) = input.parse::<JiffTimestamp>() {
                return Ok(QValue::Timestamp(QTimestamp::new(timestamp)));
            }

            // Try parsing as Date
            if let Ok(date) = input.parse::<JiffDate>() {
                return Ok(QValue::Date(QDate::new(date)));
            }

            // Try parsing as Time
            if let Ok(time) = input.parse::<JiffTime>() {
                return Ok(QValue::Time(QTime::new(time)));
            }

            arg_err!("Failed to parse '{}' as a date/time value. Supported formats: ISO 8601, RFC 3339, RFC 2822", input)
        }

        "time.parse_duration" => {
            if args.len() != 1 {
                return arg_err!("time.parse_duration expects 1 argument (string), got {}", args.len());
            }

            let input_str = args[0].as_str();
            let input = input_str.trim();

            // Parse duration string like "2h30m", "90s", "1d12h30m15s"
            let mut total_seconds: i64 = 0;
            let mut current_num = String::new();

            for ch in input.chars() {
                if ch.is_ascii_digit() {
                    current_num.push(ch);
                } else if ch.is_alphabetic() {
                    if current_num.is_empty() {
                        return arg_err!("Invalid duration format: '{}' - number expected before unit", input);
                    }

                    let num: i64 = current_num.parse()
                        .map_err(|_| format!("Invalid number in duration: '{}'", current_num))?;

                    match ch {
                        'd' => total_seconds += num * 86400,      // days
                        'h' => total_seconds += num * 3600,       // hours
                        'm' => total_seconds += num * 60,         // minutes
                        's' => total_seconds += num,              // seconds
                        _ => return arg_err!("Invalid duration unit: '{}'. Supported: d (days), h (hours), m (minutes), s (seconds)", ch),
                    }

                    current_num.clear();
                } else if ch.is_whitespace() {
                    // Allow whitespace between components
                    continue;
                } else {
                    return arg_err!("Invalid character in duration: '{}'", ch);
                }
            }

            if !current_num.is_empty() {
                return arg_err!("Duration must end with a unit (d, h, m, s): '{}'", input);
            }

            if total_seconds == 0 {
                return Err("Duration cannot be zero or empty".into());
            }

            let span = total_seconds.seconds();
            Ok(QValue::Span(QSpan::new(span)))
        }

        "time.days" => {
            if args.len() != 1 {
                return arg_err!("time.days expects 1 argument, got {}", args.len());
            }

            let days = args[0].as_num()? as i64;
            let span = days.days();

            Ok(QValue::Span(QSpan::new(span)))
        }

        "time.hours" => {
            if args.len() != 1 {
                return arg_err!("time.hours expects 1 argument, got {}", args.len());
            }

            let hours = args[0].as_num()? as i64;
            let span = hours.hours();

            Ok(QValue::Span(QSpan::new(span)))
        }

        "time.minutes" => {
            if args.len() != 1 {
                return arg_err!("time.minutes expects 1 argument, got {}", args.len());
            }

            let minutes = args[0].as_num()? as i64;
            let span = minutes.minutes();

            Ok(QValue::Span(QSpan::new(span)))
        }

        "time.seconds" => {
            if args.len() != 1 {
                return arg_err!("time.seconds expects 1 argument, got {}", args.len());
            }

            let seconds = args[0].as_num()? as i64;
            let span = seconds.seconds();

            Ok(QValue::Span(QSpan::new(span)))
        }

        "time.range" => {
            if args.len() != 2 {
                return arg_err!("time.range expects 2 arguments (start_date, end_date), got {}", args.len());
            }

            match (&args[0], &args[1]) {
                (QValue::Date(start), QValue::Date(end)) => {
                    Ok(QValue::DateRange(QDateRange::new(start.date, end.date)))
                }
                _ => Err("time.range expects two Date objects".into()),
            }
        }

        "time.sleep" => {
            if args.len() != 1 {
                return arg_err!("time.sleep expects 1 argument, got {}", args.len());
            }

            let seconds = args[0].as_num()?;
            if seconds < 0.0 {
                return Err("time.sleep expects a non-negative number".into());
            }

            let duration = std::time::Duration::from_secs_f64(seconds);
            std::thread::sleep(duration);

            Ok(QValue::Nil(QNil))
        }

        "time.is_leap_year" => {
            if args.len() != 1 {
                return arg_err!("time.is_leap_year expects 1 argument, got {}", args.len());
            }

            let year = args[0].as_num()? as i16;
            let is_leap = (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);

            Ok(QValue::Bool(QBool::new(is_leap)))
        }

        "time.from_timestamp" => {
            if args.len() != 1 {
                return arg_err!("time.from_timestamp expects 1 argument (seconds), got {}", args.len());
            }

            let seconds = args[0].as_num()? as i64;
            let timestamp = JiffTimestamp::from_second(seconds)
                .map_err(|e| format!("Invalid timestamp: {}", e))?;

            Ok(QValue::Timestamp(QTimestamp::new(timestamp)))
        }

        "time.from_timestamp_ms" => {
            if args.len() != 1 {
                return arg_err!("time.from_timestamp_ms expects 1 argument (milliseconds), got {}", args.len());
            }

            let millis = args[0].as_num()? as i64;
            let timestamp = JiffTimestamp::from_millisecond(millis)
                .map_err(|e| format!("Invalid timestamp: {}", e))?;

            Ok(QValue::Timestamp(QTimestamp::new(timestamp)))
        }

        "time.from_timestamp_us" => {
            if args.len() != 1 {
                return arg_err!("time.from_timestamp_us expects 1 argument (microseconds), got {}", args.len());
            }

            let micros = args[0].as_num()? as i64;
            let timestamp = JiffTimestamp::from_microsecond(micros)
                .map_err(|e| format!("Invalid timestamp: {}", e))?;

            Ok(QValue::Timestamp(QTimestamp::new(timestamp)))
        }

        "time.ticks_ms" => {
            // Return milliseconds elapsed since program start
            if !args.is_empty() {
                return arg_err!("time.ticks_ms() expects 0 arguments, got {}", args.len());
            }
            let elapsed = crate::get_start_time().elapsed().as_millis() as i64;
            Ok(QValue::Int(QInt::new(elapsed)))
        }

        _ => attr_err!("Unknown time function: {}", func_name)
    }
}
