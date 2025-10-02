// Time Module for Quest
// Provides comprehensive date and time handling using the jiff library

use crate::types::{QObj, QValue, QNum, QString, QBool};
use crate::next_object_id;
use jiff::{Timestamp as JiffTimestamp, Zoned as JiffZoned, civil::{Date as JiffDate, Time as JiffTime}, Span as JiffSpan, ToSpan, tz::TimeZone};
use std::collections::HashMap;

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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "to_zoned" => {
                if args.len() != 1 {
                    return Err(format!("to_zoned expects 1 argument (timezone), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Str(tz) => {
                        let zone = TimeZone::get(&tz.value)
                            .map_err(|e| format!("Invalid timezone '{}': {}", tz.value, e))?;
                        let zoned = self.timestamp.to_zoned(zone);
                        Ok(QValue::Zoned(QZoned::new(zoned)))
                    }
                    _ => Err("to_zoned expects a string timezone name".to_string()),
                }
            }
            "as_seconds" => {
                if !args.is_empty() {
                    return Err(format!("as_seconds expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.timestamp.as_second() as f64)))
            }
            "as_millis" => {
                if !args.is_empty() {
                    return Err(format!("as_millis expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.timestamp.as_millisecond() as f64)))
            }
            "as_nanos" => {
                if !args.is_empty() {
                    return Err(format!("as_nanos expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.timestamp.as_nanosecond() as f64)))
            }
            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' on Timestamp", method_name)),
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

    fn _str(&self) -> String {
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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            // Component getters
            "year" => {
                if !args.is_empty() {
                    return Err(format!("year expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.year() as f64)))
            }
            "month" => {
                if !args.is_empty() {
                    return Err(format!("month expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.month() as f64)))
            }
            "day" => {
                if !args.is_empty() {
                    return Err(format!("day expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.day() as f64)))
            }
            "hour" => {
                if !args.is_empty() {
                    return Err(format!("hour expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.hour() as f64)))
            }
            "minute" => {
                if !args.is_empty() {
                    return Err(format!("minute expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.minute() as f64)))
            }
            "second" => {
                if !args.is_empty() {
                    return Err(format!("second expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.second() as f64)))
            }
            "millisecond" => {
                if !args.is_empty() {
                    return Err(format!("millisecond expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.millisecond() as f64)))
            }
            "microsecond" => {
                if !args.is_empty() {
                    return Err(format!("microsecond expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.microsecond() as f64)))
            }
            "nanosecond" => {
                if !args.is_empty() {
                    return Err(format!("nanosecond expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.subsec_nanosecond() as f64)))
            }
            "day_of_week" => {
                if !args.is_empty() {
                    return Err(format!("day_of_week expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.weekday().to_monday_one_offset() as f64)))
            }
            "day_of_year" => {
                if !args.is_empty() {
                    return Err(format!("day_of_year expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.zoned.day_of_year() as f64)))
            }
            "timezone" => {
                if !args.is_empty() {
                    return Err(format!("timezone expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.zoned.time_zone().iana_name().unwrap_or("UTC").to_string())))
            }

            // Formatting
            "format" => {
                if args.len() != 1 {
                    return Err(format!("format expects 1 argument (pattern), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Str(pattern) => {
                        let result = self.zoned.strftime(&pattern.value).to_string();
                        Ok(QValue::Str(QString::new(result)))
                    }
                    _ => Err("format expects a string pattern".to_string()),
                }
            }
            "to_rfc3339" => {
                if !args.is_empty() {
                    return Err(format!("to_rfc3339 expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(format!("{:?}", self.zoned))))
            }

            // Timezone conversion
            "to_timezone" => {
                if args.len() != 1 {
                    return Err(format!("to_timezone expects 1 argument (timezone), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Str(tz) => {
                        let zone = TimeZone::get(&tz.value)
                            .map_err(|e| format!("Invalid timezone '{}': {}", tz.value, e))?;
                        let new_zoned = self.zoned.with_time_zone(zone);
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("to_timezone expects a string timezone name".to_string()),
                }
            }
            "to_utc" => {
                if !args.is_empty() {
                    return Err(format!("to_utc expects 0 arguments, got {}", args.len()));
                }
                let utc_zone: jiff::tz::TimeZone = jiff::tz::TimeZone::UTC;
                let new_zoned = self.zoned.with_time_zone(utc_zone);
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }

            // Arithmetic
            "add_years" => {
                if args.len() != 1 {
                    return Err(format!("add_years expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let years = n.value as i64;
                        let span = years.years();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_years error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_years expects a number".to_string()),
                }
            }
            "add_months" => {
                if args.len() != 1 {
                    return Err(format!("add_months expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let months = n.value as i64;
                        let span = months.months();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_months error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_months expects a number".to_string()),
                }
            }
            "add_days" => {
                if args.len() != 1 {
                    return Err(format!("add_days expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let days = n.value as i64;
                        let span = days.days();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_days error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_days expects a number".to_string()),
                }
            }
            "add_hours" => {
                if args.len() != 1 {
                    return Err(format!("add_hours expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let hours = n.value as i64;
                        let span = hours.hours();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_hours error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_hours expects a number".to_string()),
                }
            }
            "add_minutes" => {
                if args.len() != 1 {
                    return Err(format!("add_minutes expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let minutes = n.value as i64;
                        let span = minutes.minutes();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_minutes error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_minutes expects a number".to_string()),
                }
            }
            "add_seconds" => {
                if args.len() != 1 {
                    return Err(format!("add_seconds expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let seconds = n.value as i64;
                        let span = seconds.seconds();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("add_seconds error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add_seconds expects a number".to_string()),
                }
            }
            "add" => {
                if args.len() != 1 {
                    return Err(format!("add expects 1 argument (span), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Span(span) => {
                        let new_zoned = self.zoned.checked_add(span.span)
                            .map_err(|e| format!("add error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("add expects a Span object".to_string()),
                }
            }
            "subtract_years" => {
                if args.len() != 1 {
                    return Err(format!("subtract_years expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let years = -(n.value as i64);
                        let span = years.years();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_years error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_years expects a number".to_string()),
                }
            }
            "subtract_months" => {
                if args.len() != 1 {
                    return Err(format!("subtract_months expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let months = -(n.value as i64);
                        let span = months.months();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_months error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_months expects a number".to_string()),
                }
            }
            "subtract_days" => {
                if args.len() != 1 {
                    return Err(format!("subtract_days expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let days = -(n.value as i64);
                        let span = days.days();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_days error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_days expects a number".to_string()),
                }
            }
            "subtract_hours" => {
                if args.len() != 1 {
                    return Err(format!("subtract_hours expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let hours = -(n.value as i64);
                        let span = hours.hours();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_hours error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_hours expects a number".to_string()),
                }
            }
            "subtract_minutes" => {
                if args.len() != 1 {
                    return Err(format!("subtract_minutes expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let minutes = -(n.value as i64);
                        let span = minutes.minutes();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_minutes error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_minutes expects a number".to_string()),
                }
            }
            "subtract_seconds" => {
                if args.len() != 1 {
                    return Err(format!("subtract_seconds expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let seconds = -(n.value as i64);
                        let span = seconds.seconds();
                        let new_zoned = self.zoned.checked_add(span)
                            .map_err(|e| format!("subtract_seconds error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract_seconds expects a number".to_string()),
                }
            }
            "subtract" => {
                if args.len() != 1 {
                    return Err(format!("subtract expects 1 argument (span), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Span(span) => {
                        let new_zoned = self.zoned.checked_sub(span.span)
                            .map_err(|e| format!("subtract error: {}", e))?;
                        Ok(QValue::Zoned(QZoned::new(new_zoned)))
                    }
                    _ => Err("subtract expects a Span object".to_string()),
                }
            }
            "since" => {
                if args.len() != 1 {
                    return Err(format!("since expects 1 argument (other), got {}", args.len()));
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
                    _ => Err("since expects a Zoned or Timestamp object".to_string()),
                }
            }

            // Comparison
            "equals" => {
                if args.len() != 1 {
                    return Err(format!("equals expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() == other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() == ts.timestamp)))
                    }
                    _ => Err("equals expects a Zoned or Timestamp object".to_string()),
                }
            }
            "before" => {
                if args.len() != 1 {
                    return Err(format!("before expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() < other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() < ts.timestamp)))
                    }
                    _ => Err("before expects a Zoned or Timestamp object".to_string()),
                }
            }
            "after" => {
                if args.len() != 1 {
                    return Err(format!("after expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Zoned(other) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() > other.zoned.timestamp())))
                    }
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.zoned.timestamp() > ts.timestamp)))
                    }
                    _ => Err("after expects a Zoned or Timestamp object".to_string()),
                }
            }

            // Rounding
            "round_to_hour" => {
                if !args.is_empty() {
                    return Err(format!("round_to_hour expects 0 arguments, got {}", args.len()));
                }
                let new_zoned = self.zoned.round(jiff::Unit::Hour)
                    .map_err(|e| format!("round_to_hour error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "round_to_minute" => {
                if !args.is_empty() {
                    return Err(format!("round_to_minute expects 0 arguments, got {}", args.len()));
                }
                let new_zoned = self.zoned.round(jiff::Unit::Minute)
                    .map_err(|e| format!("round_to_minute error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "start_of_day" => {
                if !args.is_empty() {
                    return Err(format!("start_of_day expects 0 arguments, got {}", args.len()));
                }
                let new_zoned = self.zoned.start_of_day()
                    .map_err(|e| format!("start_of_day error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "end_of_day" => {
                if !args.is_empty() {
                    return Err(format!("end_of_day expects 0 arguments, got {}", args.len()));
                }
                let new_zoned = self.zoned.end_of_day()
                    .map_err(|e| format!("end_of_day error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(new_zoned)))
            }
            "start_of_month" => {
                if !args.is_empty() {
                    return Err(format!("start_of_month expects 0 arguments, got {}", args.len()));
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
                    return Err(format!("end_of_month expects 0 arguments, got {}", args.len()));
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

            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' on Zoned", method_name)),
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

    fn _str(&self) -> String {
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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            // Component getters
            "year" => {
                if !args.is_empty() {
                    return Err(format!("year expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.date.year() as f64)))
            }
            "month" => {
                if !args.is_empty() {
                    return Err(format!("month expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.date.month() as f64)))
            }
            "day" => {
                if !args.is_empty() {
                    return Err(format!("day expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.date.day() as f64)))
            }
            "day_of_week" => {
                if !args.is_empty() {
                    return Err(format!("day_of_week expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.date.weekday().to_monday_one_offset() as f64)))
            }
            "day_of_year" => {
                if !args.is_empty() {
                    return Err(format!("day_of_year expects 0 arguments, got {}", args.len()));
                }
                match self.date.day_of_year_no_leap() {
                    Some(doy) => Ok(QValue::Num(QNum::new(doy as f64))),
                    None => Err("Failed to get day of year".to_string()),
                }
            }

            // Arithmetic
            "add_days" => {
                if args.len() != 1 {
                    return Err(format!("add_days expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let days = n.value as i64;
                        let span = days.days();
                        let new_date = self.date.checked_add(span)
                            .map_err(|e| format!("add_days error: {}", e))?;
                        Ok(QValue::Date(QDate::new(new_date)))
                    }
                    _ => Err("add_days expects a number".to_string()),
                }
            }
            "add_months" => {
                if args.len() != 1 {
                    return Err(format!("add_months expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let months = n.value as i64;
                        let span = months.months();
                        let new_date = self.date.checked_add(span)
                            .map_err(|e| format!("add_months error: {}", e))?;
                        Ok(QValue::Date(QDate::new(new_date)))
                    }
                    _ => Err("add_months expects a number".to_string()),
                }
            }
            "add_years" => {
                if args.len() != 1 {
                    return Err(format!("add_years expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let years = n.value as i64;
                        let span = years.years();
                        let new_date = self.date.checked_add(span)
                            .map_err(|e| format!("add_years error: {}", e))?;
                        Ok(QValue::Date(QDate::new(new_date)))
                    }
                    _ => Err("add_years expects a number".to_string()),
                }
            }
            // Note: since() method for Date not available in jiff 0.1
            // Users can convert to Zoned and use since there if needed

            // Comparison
            "equals" => {
                if args.len() != 1 {
                    return Err(format!("equals expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date == other.date)))
                    }
                    _ => Err("equals expects a Date object".to_string()),
                }
            }
            "before" => {
                if args.len() != 1 {
                    return Err(format!("before expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date < other.date)))
                    }
                    _ => Err("before expects a Date object".to_string()),
                }
            }
            "after" => {
                if args.len() != 1 {
                    return Err(format!("after expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Date(other) => {
                        Ok(QValue::Bool(QBool::new(self.date > other.date)))
                    }
                    _ => Err("after expects a Date object".to_string()),
                }
            }

            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' on Date", method_name)),
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

    fn _str(&self) -> String {
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

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "hour" => {
                if !args.is_empty() {
                    return Err(format!("hour expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.time.hour() as f64)))
            }
            "minute" => {
                if !args.is_empty() {
                    return Err(format!("minute expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.time.minute() as f64)))
            }
            "second" => {
                if !args.is_empty() {
                    return Err(format!("second expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.time.second() as f64)))
            }
            "nanosecond" => {
                if !args.is_empty() {
                    return Err(format!("nanosecond expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.time.subsec_nanosecond() as f64)))
            }
            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' on Time", method_name)),
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

    fn _str(&self) -> String {
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

impl QSpan {
    pub fn new(span: JiffSpan) -> Self {
        Self {
            span,
            id: next_object_id(),
        }
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        use crate::types::try_call_qobj_method;
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }


        match method_name {
            // Component getters
            "years" => {
                if !args.is_empty() {
                    return Err(format!("years expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_years() as f64)))
            }
            "months" => {
                if !args.is_empty() {
                    return Err(format!("months expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_months() as f64)))
            }
            "days" => {
                if !args.is_empty() {
                    return Err(format!("days expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_days() as f64)))
            }
            "hours" => {
                if !args.is_empty() {
                    return Err(format!("hours expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_hours() as f64)))
            }
            "minutes" => {
                if !args.is_empty() {
                    return Err(format!("minutes expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_minutes() as f64)))
            }
            "seconds" => {
                if !args.is_empty() {
                    return Err(format!("seconds expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.span.get_seconds() as f64)))
            }

            // Conversion
            "as_hours" => {
                if !args.is_empty() {
                    return Err(format!("as_hours expects 0 arguments, got {}", args.len()));
                }
                let total = self.span.total(jiff::Unit::Hour)
                    .map_err(|e| format!("as_hours error: {}", e))?;
                Ok(QValue::Num(QNum::new(total)))
            }
            "as_minutes" => {
                if !args.is_empty() {
                    return Err(format!("as_minutes expects 0 arguments, got {}", args.len()));
                }
                let total = self.span.total(jiff::Unit::Minute)
                    .map_err(|e| format!("as_minutes error: {}", e))?;
                Ok(QValue::Num(QNum::new(total)))
            }
            "as_seconds" => {
                if !args.is_empty() {
                    return Err(format!("as_seconds expects 0 arguments, got {}", args.len()));
                }
                let total = self.span.total(jiff::Unit::Second)
                    .map_err(|e| format!("as_seconds error: {}", e))?;
                Ok(QValue::Num(QNum::new(total)))
            }
            "as_millis" => {
                if !args.is_empty() {
                    return Err(format!("as_millis expects 0 arguments, got {}", args.len()));
                }
                let total = self.span.total(jiff::Unit::Millisecond)
                    .map_err(|e| format!("as_millis error: {}", e))?;
                Ok(QValue::Num(QNum::new(total)))
            }

            // Arithmetic
            "add" => {
                if args.len() != 1 {
                    return Err(format!("add expects 1 argument (other), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Span(other) => {
                        let new_span = self.span.checked_add(other.span)
                            .map_err(|e| format!("add error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("add expects a Span object".to_string()),
                }
            }
            "subtract" => {
                if args.len() != 1 {
                    return Err(format!("subtract expects 1 argument (other), got {}", args.len()));
                }
                match &args[0] {
                    QValue::Span(other) => {
                        let new_span = self.span.checked_sub(other.span)
                            .map_err(|e| format!("subtract error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("subtract expects a Span object".to_string()),
                }
            }
            "multiply" => {
                if args.len() != 1 {
                    return Err(format!("multiply expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        let new_span = self.span.checked_mul(n.value as i64)
                            .map_err(|e| format!("multiply error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("multiply expects a number".to_string()),
                }
            }
            "divide" => {
                if args.len() != 1 {
                    return Err(format!("divide expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Num(n) => {
                        if n.value == 0.0 {
                            return Err("Cannot divide by zero".to_string());
                        }
                        // Jiff doesn't have checked_div, so we multiply by reciprocal
                        let reciprocal = 1.0 / n.value;
                        let new_span = self.span.checked_mul(reciprocal as i64)
                            .map_err(|e| format!("divide error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(new_span)))
                    }
                    _ => Err("divide expects a number".to_string()),
                }
            }

            "_id" => {
                if !args.is_empty() {
                    return Err(format!("_id expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Num(QNum::new(self.id as f64)))
            }
            _ => Err(format!("Unknown method '{}' on Span", method_name)),
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

    fn _str(&self) -> String {
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
    use crate::types::{QModule, QFun};

    let mut module = HashMap::new();

    // Helper to create function references
    fn create_time_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "time".to_string(), doc.to_string()))
    }

    // Current time functions
    module.insert("now".to_string(), create_time_fn("now", "Get the current instant as a UTC timestamp"));
    module.insert("now_local".to_string(), create_time_fn("now_local", "Get the current datetime in the system's local timezone"));
    module.insert("today".to_string(), create_time_fn("today", "Get today's date in the local timezone"));
    module.insert("time_now".to_string(), create_time_fn("time_now", "Get the current time of day in the local timezone"));

    // Construction functions
    module.insert("parse".to_string(), create_time_fn("parse", "Parse a datetime string in various formats"));
    module.insert("datetime".to_string(), create_time_fn("datetime", "Create a timezone-aware datetime from components"));
    module.insert("date".to_string(), create_time_fn("date", "Create a calendar date"));
    module.insert("time".to_string(), create_time_fn("time", "Create a time of day"));

    // Span creation functions
    module.insert("span".to_string(), create_time_fn("span", "Create a span from components"));
    module.insert("days".to_string(), create_time_fn("days", "Create a span of n days"));
    module.insert("hours".to_string(), create_time_fn("hours", "Create a span of n hours"));
    module.insert("minutes".to_string(), create_time_fn("minutes", "Create a span of n minutes"));
    module.insert("seconds".to_string(), create_time_fn("seconds", "Create a span of n seconds"));

    // Utility functions
    module.insert("sleep".to_string(), create_time_fn("sleep", "Sleep for a specified duration in seconds"));
    module.insert("is_leap_year".to_string(), create_time_fn("is_leap_year", "Check if a year is a leap year"));
    module.insert("ticks_ms".to_string(), create_time_fn("ticks_ms", "Get milliseconds elapsed since program start"));

    QValue::Module(QModule::new("time".to_string(), module))
}
