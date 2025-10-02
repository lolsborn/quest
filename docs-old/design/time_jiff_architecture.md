# Time Module - Jiff Integration Architecture

This document describes the technical architecture for implementing Quest's time module as a wrapper around the Rust [jiff](https://docs.rs/jiff/) library.

## Overview

The time module provides Quest with production-grade datetime handling, including:
- Timezone-aware datetime operations
- Nanosecond precision
- Full IANA timezone database support
- Automatic DST handling
- Comprehensive duration arithmetic
- Multiple parsing/formatting options

## Why Jiff?

Jiff was chosen for several reasons:

1. **Temporal API Compatibility** - Inspired by JavaScript's Temporal proposal, providing modern datetime semantics
2. **Pit of Success Design** - Hard to misuse, encourages correct datetime handling
3. **Comprehensive** - Handles timezones, DST, leap seconds, and edge cases
4. **Performance** - Optimized Rust implementation with nanosecond precision
5. **Well-Maintained** - Active development, comprehensive test suite
6. **Zero Runtime Dependencies** - Timezone database embedded at compile time

## Type Mapping

### Quest Types → Jiff Types

| Quest Type | Jiff Type | Description |
|------------|-----------|-------------|
| `QValue::Timestamp` | `jiff::Timestamp` | Instant in time (UTC, nanoseconds since Unix epoch) |
| `QValue::Zoned` | `jiff::Zoned` | Timezone-aware datetime |
| `QValue::Date` | `jiff::civil::Date` | Calendar date (year, month, day) |
| `QValue::Time` | `jiff::civil::Time` | Time of day (hour, minute, second, nanosecond) |
| `QValue::Span` | `jiff::Span` | Duration/span with calendar and clock units |

### New QValue Variants

Add to `src/types.rs`:

```rust
pub enum QValue {
    // ... existing variants ...
    Timestamp(QTimestamp),
    Zoned(QZoned),
    Date(QDate),
    Time(QTime),
    Span(QSpan),
}
```

## Rust Implementation

### 1. Type Wrappers (`src/types.rs`)

Each jiff type needs a Quest wrapper implementing the `QObj` trait:

#### QTimestamp

```rust
#[derive(Debug, Clone)]
pub struct QTimestamp {
    pub inner: jiff::Timestamp,
    pub id: u64,
}

impl QTimestamp {
    pub fn new(timestamp: jiff::Timestamp) -> Self {
        QTimestamp {
            inner: timestamp,
            id: next_object_id(),
        }
    }

    pub fn now() -> Self {
        Self::new(jiff::Timestamp::now())
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "to_zoned" => {
                // args[0] should be timezone string
                let tz_str = args[0].as_str()?;
                let tz = jiff::tz::TimeZone::get(tz_str)
                    .map_err(|e| format!("Invalid timezone: {}", e))?;
                let zoned = self.inner.to_zoned(tz);
                Ok(QValue::Zoned(QZoned::new(zoned)))
            }
            "as_seconds" => {
                Ok(QValue::Num(QNum::new(self.inner.as_second() as f64)))
            }
            "as_millis" => {
                Ok(QValue::Num(QNum::new(self.inner.as_millisecond() as f64)))
            }
            "as_nanos" => {
                Ok(QValue::Num(QNum::new(self.inner.as_nanosecond() as f64)))
            }
            "_str" => Ok(QValue::Str(QString::new(self.inner.to_string()))),
            "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
            _ => Err(format!("Unknown method '{}' for Timestamp", method_name))
        }
    }
}

impl QObj for QTimestamp {
    fn cls(&self) -> String { "Timestamp".to_string() }
    fn q_type(&self) -> &'static str { "timestamp" }
    fn is(&self, type_name: &str) -> bool { type_name == "timestamp" || type_name == "obj" }
    fn _str(&self) -> String { self.inner.to_string() }
    fn _rep(&self) -> String { format!("Timestamp({})", self._str()) }
    fn _doc(&self) -> String { "Timestamp: An instant in time (UTC)".to_string() }
    fn _id(&self) -> u64 { self.id }
}
```

#### QZoned

```rust
#[derive(Debug, Clone)]
pub struct QZoned {
    pub inner: jiff::Zoned,
    pub id: u64,
}

impl QZoned {
    pub fn new(zoned: jiff::Zoned) -> Self {
        QZoned {
            inner: zoned,
            id: next_object_id(),
        }
    }

    pub fn now() -> Self {
        Self::new(jiff::Zoned::now())
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            // Component getters
            "year" => Ok(QValue::Num(QNum::new(self.inner.year() as f64))),
            "month" => Ok(QValue::Num(QNum::new(self.inner.month() as f64))),
            "day" => Ok(QValue::Num(QNum::new(self.inner.day() as f64))),
            "hour" => Ok(QValue::Num(QNum::new(self.inner.hour() as f64))),
            "minute" => Ok(QValue::Num(QNum::new(self.inner.minute() as f64))),
            "second" => Ok(QValue::Num(QNum::new(self.inner.second() as f64))),
            "nanosecond" => Ok(QValue::Num(QNum::new(self.inner.subsec_nanosecond() as f64))),
            "day_of_week" => {
                // Jiff uses ISO week date (Monday=1), which matches our spec
                Ok(QValue::Num(QNum::new(self.inner.weekday().to_monday_one_offset() as f64)))
            }
            "timezone" => {
                Ok(QValue::Str(QString::new(self.inner.time_zone().iana_name().unwrap_or("UTC").to_string())))
            }

            // Formatting
            "format" => {
                let pattern = args[0].as_str()?;
                let formatted = self.inner.strftime(pattern)
                    .map_err(|e| format!("Format error: {}", e))?;
                Ok(QValue::Str(QString::new(formatted.to_string())))
            }
            "to_rfc3339" => {
                Ok(QValue::Str(QString::new(self.inner.to_string())))
            }

            // Timezone conversion
            "to_timezone" => {
                let tz_str = args[0].as_str()?;
                let tz = jiff::tz::TimeZone::get(tz_str)
                    .map_err(|e| format!("Invalid timezone: {}", e))?;
                let converted = self.inner.with_time_zone(tz);
                Ok(QValue::Zoned(QZoned::new(converted)))
            }
            "to_utc" => {
                let utc = self.inner.with_time_zone(jiff::tz::TimeZone::UTC);
                Ok(QValue::Zoned(QZoned::new(utc)))
            }

            // Arithmetic
            "add_years" => {
                let years = args[0].as_num()? as i64;
                let span = jiff::Span::new().years(years);
                let result = self.inner.checked_add(span)
                    .map_err(|e| format!("Arithmetic error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(result)))
            }
            "add_months" => {
                let months = args[0].as_num()? as i64;
                let span = jiff::Span::new().months(months);
                let result = self.inner.checked_add(span)
                    .map_err(|e| format!("Arithmetic error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(result)))
            }
            "add_days" => {
                let days = args[0].as_num()? as i64;
                let span = jiff::Span::new().days(days);
                let result = self.inner.checked_add(span)
                    .map_err(|e| format!("Arithmetic error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(result)))
            }
            "add_hours" => {
                let hours = args[0].as_num()? as i64;
                let span = jiff::Span::new().hours(hours);
                let result = self.inner.checked_add(span)
                    .map_err(|e| format!("Arithmetic error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(result)))
            }
            // ... similar for add_minutes, add_seconds, subtract_* ...

            // Comparison
            "equals" => {
                match &args[0] {
                    QValue::Zoned(other) => Ok(QValue::Bool(QBool::new(self.inner == other.inner))),
                    QValue::Timestamp(ts) => {
                        Ok(QValue::Bool(QBool::new(self.inner.timestamp() == ts.inner)))
                    }
                    _ => Err("equals() requires a Zoned or Timestamp argument".to_string())
                }
            }
            "before" => {
                match &args[0] {
                    QValue::Zoned(other) => Ok(QValue::Bool(QBool::new(self.inner < other.inner))),
                    _ => Err("before() requires a Zoned argument".to_string())
                }
            }
            "after" => {
                match &args[0] {
                    QValue::Zoned(other) => Ok(QValue::Bool(QBool::new(self.inner > other.inner))),
                    _ => Err("after() requires a Zoned argument".to_string())
                }
            }

            // Duration calculation
            "since" => {
                match &args[0] {
                    QValue::Zoned(other) => {
                        let span = self.inner.since(other.inner)
                            .map_err(|e| format!("Duration calculation error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span)))
                    }
                    QValue::Timestamp(ts) => {
                        let span = self.inner.timestamp().since(ts.inner)
                            .map_err(|e| format!("Duration calculation error: {}", e))?;
                        Ok(QValue::Span(QSpan::new(span.to_jiff_span())))
                    }
                    _ => Err("since() requires a Zoned or Timestamp argument".to_string())
                }
            }

            // Rounding
            "round_to_hour" => {
                let rounded = self.inner.round(jiff::Unit::Hour)
                    .map_err(|e| format!("Rounding error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(rounded)))
            }
            "start_of_day" => {
                let start = self.inner.start_of_day()
                    .map_err(|e| format!("Error: {}", e))?;
                Ok(QValue::Zoned(QZoned::new(start)))
            }
            // ... other methods ...

            "_str" => Ok(QValue::Str(QString::new(self.inner.to_string()))),
            "_id" => Ok(QValue::Num(QNum::new(self.id as f64))),
            _ => Err(format!("Unknown method '{}' for Zoned", method_name))
        }
    }
}

impl QObj for QZoned {
    fn cls(&self) -> String { "Zoned".to_string() }
    fn q_type(&self) -> &'static str { "zoned" }
    fn is(&self, type_name: &str) -> bool { type_name == "zoned" || type_name == "obj" }
    fn _str(&self) -> String { self.inner.to_string() }
    fn _rep(&self) -> String { format!("Zoned({})", self._str()) }
    fn _doc(&self) -> String { "Zoned: A timezone-aware datetime".to_string() }
    fn _id(&self) -> u64 { self.id }
}
```

#### QDate, QTime, QSpan

Similar implementations for Date, Time, and Span types.

### 2. Module Creation (`src/modules/time.rs`)

```rust
use std::collections::HashMap;
use crate::types::*;
use jiff;

pub fn create_time_module() -> QValue {
    fn create_time_fn(name: &str, doc: &str) -> QValue {
        QValue::Fun(QFun::new(name.to_string(), "time".to_string(), doc.to_string()))
    }

    let mut members = HashMap::new();

    // Current time functions
    members.insert("now".to_string(), create_time_fn("now", "Get current timestamp (UTC)"));
    members.insert("now_local".to_string(), create_time_fn("now_local", "Get current datetime in local timezone"));
    members.insert("today".to_string(), create_time_fn("today", "Get today's date"));
    members.insert("time_now".to_string(), create_time_fn("time_now", "Get current time of day"));

    // Construction functions
    members.insert("parse".to_string(), create_time_fn("parse", "Parse datetime string"));
    members.insert("datetime".to_string(), create_time_fn("datetime", "Create datetime from components"));
    members.insert("date".to_string(), create_time_fn("date", "Create date from year, month, day"));
    members.insert("time".to_string(), create_time_fn("time", "Create time from hour, minute, second"));

    // Span/duration functions
    members.insert("span".to_string(), create_time_fn("span", "Create span from components"));
    members.insert("days".to_string(), create_time_fn("days", "Create span of n days"));
    members.insert("hours".to_string(), create_time_fn("hours", "Create span of n hours"));
    members.insert("minutes".to_string(), create_time_fn("minutes", "Create span of n minutes"));
    members.insert("seconds".to_string(), create_time_fn("seconds", "Create span of n seconds"));

    // Utility functions
    members.insert("sleep".to_string(), create_time_fn("sleep", "Sleep for specified duration"));
    members.insert("is_leap_year".to_string(), create_time_fn("is_leap_year", "Check if year is a leap year"));

    QValue::Module(QModule::new("time".to_string(), members))
}
```

### 3. Builtin Function Handlers (`src/main.rs`)

Add to `call_builtin_function()`:

```rust
// In call_builtin_function()
match func_name {
    // ... existing functions ...

    // Time module functions
    "time.now" => {
        Ok(QValue::Timestamp(QTimestamp::now()))
    }
    "time.now_local" => {
        Ok(QValue::Zoned(QZoned::now()))
    }
    "time.today" => {
        let now = jiff::Zoned::now();
        let date = now.date();
        Ok(QValue::Date(QDate::new(date)))
    }
    "time.parse" => {
        if args.len() != 1 {
            return Err(format!("time.parse expects 1 argument, got {}", args.len()));
        }
        let s = args[0].as_str()?;

        // Try parsing as Zoned first
        if let Ok(zoned) = jiff::Zoned::strptime("%Y-%m-%dT%H:%M:%S%z", s) {
            return Ok(QValue::Zoned(QZoned::new(zoned)));
        }

        // Try as Timestamp
        if let Ok(ts) = jiff::Timestamp::from_str(s) {
            return Ok(QValue::Timestamp(QTimestamp::new(ts)));
        }

        // Try as Date
        if let Ok(date) = jiff::civil::Date::from_str(s) {
            return Ok(QValue::Date(QDate::new(date)));
        }

        Err(format!("Could not parse datetime: {}", s))
    }
    "time.datetime" => {
        // Parse arguments: year, month, day, hour, minute, second, [timezone]
        if args.len() < 6 || args.len() > 7 {
            return Err(format!("time.datetime expects 6-7 arguments, got {}", args.len()));
        }

        let year = args[0].as_num()? as i16;
        let month = args[1].as_num()? as i8;
        let day = args[2].as_num()? as i8;
        let hour = args[3].as_num()? as i8;
        let minute = args[4].as_num()? as i8;
        let second = args[5].as_num()? as i8;

        let tz = if args.len() == 7 {
            let tz_str = args[6].as_str()?;
            jiff::tz::TimeZone::get(tz_str)
                .map_err(|e| format!("Invalid timezone: {}", e))?
        } else {
            jiff::tz::TimeZone::UTC
        };

        let dt = jiff::civil::DateTime::new(year, month, day, hour, minute, second, 0)
            .map_err(|e| format!("Invalid datetime: {}", e))?;
        let zoned = dt.to_zoned(tz)
            .map_err(|e| format!("Could not create zoned datetime: {}", e))?;

        Ok(QValue::Zoned(QZoned::new(zoned)))
    }
    "time.sleep" => {
        if args.len() != 1 {
            return Err(format!("time.sleep expects 1 argument, got {}", args.len()));
        }
        let seconds = args[0].as_num()?;
        let duration = std::time::Duration::from_secs_f64(seconds);
        std::thread::sleep(duration);
        Ok(QValue::Nil(QNil))
    }
    // ... more time functions ...

    _ => Err(format!("Unknown builtin function: {}", func_name))
}
```

## Module Registration

### 1. Update `src/modules/mod.rs`

```rust
pub mod time;
pub use time::create_time_module;
```

### 2. Register in `src/main.rs`

In the module loading section:

```rust
let module_opt = match builtin_name {
    "math" => Some(create_math_module()),
    "os" => Some(create_os_module()),
    "term" => Some(create_term_module()),
    "time" => Some(create_time_module()),  // Add this
    // ... other modules ...
    _ => None,
};
```

## Cargo Dependencies

Add to `Cargo.toml`:

```toml
[dependencies]
jiff = { version = "0.1", features = ["std"] }
```

## Error Handling Strategy

1. **Invalid Dates**: Raise exceptions with descriptive messages
   ```
   Error: Invalid date: month must be 1-12, got 13
   ```

2. **Timezone Errors**: Return error for unknown timezones
   ```
   Error: Invalid timezone: 'America/Atlantis'
   ```

3. **Arithmetic Overflow**: Handle gracefully with error messages
   ```
   Error: Datetime arithmetic overflow
   ```

4. **Parse Errors**: Clear messages about what went wrong
   ```
   Error: Could not parse '2025-13-01': invalid month
   ```

## Performance Optimizations

1. **Lazy Parsing**: Don't parse strings until needed
2. **Timezone Caching**: Jiff caches timezone lookups automatically
3. **Immutable Design**: No defensive copying needed
4. **Efficient Comparison**: Use underlying timestamp for comparisons
5. **Zero-Copy String Formatting**: Where possible, use jiff's Display impl

## Testing Strategy

Create comprehensive test suite in `test/time/`:
- `basic.q` - Core functionality tests
- `arithmetic.q` - Date/time arithmetic tests
- `timezones.q` - Timezone conversion tests
- `parsing.q` - Parsing various formats
- `formatting.q` - Format string tests
- `spans.q` - Duration/span tests

## Integration with Logging

Update `std/log.q` to use the time module:

```quest
fun get_timestamp()
    # Replace placeholder with actual time module
    let dt = time.now_local()
    return dt.format("%Y-%m-%d %H:%M:%S")
end
```

## Future Enhancements

1. **Date Ranges**: Iterator support for date ranges
2. **Recurring Events**: RRULE support for repeating dates
3. **Holidays**: Calendar holiday calculations
4. **Business Day Math**: Skip weekends/holidays in arithmetic
5. **Time Zone Changes**: Track when timezones change for a location
6. **Relative Time**: "3 days ago", "in 2 weeks" formatting

## Migration Path

Since there's no existing time module in Quest, this is a greenfield implementation. The API is designed to be:
- **Familiar**: Similar to Python's datetime, JavaScript's Temporal
- **Safe**: Hard to misuse, clear error messages
- **Ergonomic**: Natural method chaining, sensible defaults
- **Complete**: Covers common use cases without external dependencies
