# Time Module API Reference

The `time` module provides comprehensive date and time handling for Quest, powered by the [jiff](https://docs.rs/jiff/) library. It offers timezone-aware datetime operations, duration arithmetic, and formatting capabilities with nanosecond precision.

## Module Import

```quest
use "std/time" as time
```

## Core Concepts

### Overview

Quest's time module introduces five new data structures:
- **Timestamp** - An instant in time (UTC, nanosecond precision)
- **Zoned** - A timezone-aware datetime
- **Date** - A calendar date (year, month, day)
- **Time** - A time of day (hour, minute, second, nanosecond)
- **Span** - A duration or time span

All types implement Quest's `QObj` trait and have common methods like `._str()`, `._rep()`, `._doc()`, `._id()`, and `.cls()`.

### Immutability

All datetime objects are **immutable** - operations return new objects rather than modifying existing ones. This design:
- Prevents accidental mutations
- Enables safe sharing across contexts
- Simplifies reasoning about code
- Matches functional programming best practices

```quest
let dt = time.now()
let tomorrow = dt.add_days(1)  # Returns NEW datetime, dt unchanged
puts(dt._str())                 # Original datetime still intact
```

### Timezone Handling

The module uses the IANA Time Zone Database for accurate timezone and DST handling. Timezones are specified using IANA names like:
- `"America/New_York"`
- `"Europe/London"`
- `"Asia/Tokyo"`
- `"UTC"`

## Current Time Functions

### `time.now()`
Get the current instant as a UTC timestamp.

**Returns:** Timestamp

**Example:**
```quest
let now = time.now()
puts(now._str())  # "2025-10-01T14:30:45.123456789Z"
```

### `time.now_local()`
Get the current datetime in the system's local timezone.

**Returns:** Zoned

**Example:**
```quest
let local = time.now_local()
puts(local._str())  # "2025-10-01T10:30:45.123-04:00[America/New_York]"
```

### `time.today()`
Get today's date in the local timezone.

**Returns:** Date

**Example:**
```quest
let today = time.today()
puts(today._str())  # "2025-10-01"
```

### `time.time_now()`
Get the current time of day in the local timezone.

**Returns:** Time

**Example:**
```quest
let now = time.time_now()
puts(now._str())  # "14:30:45.123456789"
```

## Construction Functions

### `time.parse(string)`
Parse a datetime string in various formats (ISO 8601, RFC 3339, RFC 2822).

**Parameters:**
- `string` - Datetime string to parse (Str)

**Returns:** Timestamp, Zoned, Date, or Time depending on input format

**Example:**
```quest
let dt1 = time.parse("2025-10-01T14:30:00Z")
let dt2 = time.parse("2025-10-01T14:30:00-05:00")
let dt3 = time.parse("2025-10-01 14:30:00")
let date = time.parse("2025-10-01")
```

### `time.datetime(year, month, day, hour, minute, second, timezone?)`
Create a timezone-aware datetime from components.

**Parameters:**
- `year` - Year (Num)
- `month` - Month 1-12 (Num)
- `day` - Day 1-31 (Num)
- `hour` - Hour 0-23 (Num)
- `minute` - Minute 0-59 (Num)
- `second` - Second 0-59 (Num)
- `timezone` - Optional timezone name (Str), defaults to "UTC"

**Returns:** Zoned

**Example:**
```quest
let dt1 = time.datetime(2025, 10, 1, 14, 30, 0)  # UTC
let dt2 = time.datetime(2025, 10, 1, 14, 30, 0, "America/New_York")
```

### `time.date(year, month, day)`
Create a calendar date.

**Parameters:**
- `year` - Year (Num)
- `month` - Month 1-12 (Num)
- `day` - Day 1-31 (Num)

**Returns:** Date

**Example:**
```quest
let date = time.date(2025, 10, 1)
puts(date._str())  # "2025-10-01"
```

### `time.time(hour, minute, second, nanosecond?)`
Create a time of day.

**Parameters:**
- `hour` - Hour 0-23 (Num)
- `minute` - Minute 0-59 (Num)
- `second` - Second 0-59 (Num)
- `nanosecond` - Optional nanoseconds (Num), defaults to 0

**Returns:** Time

**Example:**
```quest
let t1 = time.time(14, 30, 45)
let t2 = time.time(14, 30, 45, 123456789)
```

## Timestamp Methods

Methods available on Timestamp objects.

### `timestamp.to_zoned(timezone)`
Convert timestamp to a timezone-aware datetime.

**Parameters:**
- `timezone` - Timezone name (Str)

**Returns:** Zoned

**Example:**
```quest
let ts = time.now()
let ny = ts.to_zoned("America/New_York")
let tokyo = ts.to_zoned("Asia/Tokyo")
```

### `timestamp.as_seconds()`
Get Unix timestamp in seconds.

**Returns:** Num

**Example:**
```quest
let ts = time.now()
puts(ts.as_seconds())  # 1727794245
```

### `timestamp.as_millis()`
Get Unix timestamp in milliseconds.

**Returns:** Num

**Example:**
```quest
let ts = time.now()
puts(ts.as_millis())  # 1727794245123
```

### `timestamp.as_nanos()`
Get Unix timestamp in nanoseconds.

**Returns:** Num

**Example:**
```quest
let ts = time.now()
puts(ts.as_nanos())  # 1727794245123456789
```

## Zoned DateTime Methods

Methods available on Zoned (timezone-aware datetime) objects.

### Component Getters

#### `zoned.year()`
Get the year component.

**Returns:** Num

#### `zoned.month()`
Get the month component (1-12).

**Returns:** Num

#### `zoned.day()`
Get the day of month (1-31).

**Returns:** Num

#### `zoned.hour()`
Get the hour component (0-23).

**Returns:** Num

#### `zoned.minute()`
Get the minute component (0-59).

**Returns:** Num

#### `zoned.second()`
Get the second component (0-59).

**Returns:** Num

#### `zoned.millisecond()`
Get the millisecond component (0-999).

**Returns:** Num

#### `zoned.microsecond()`
Get the microsecond component (0-999999).

**Returns:** Num

#### `zoned.nanosecond()`
Get the nanosecond component (0-999999999).

**Returns:** Num

#### `zoned.day_of_week()`
Get the day of week (1=Monday, 7=Sunday).

**Returns:** Num

#### `zoned.day_of_year()`
Get the day of year (1-366).

**Returns:** Num

#### `zoned.timezone()`
Get the timezone name.

**Returns:** Str

**Example:**
```quest
let dt = time.parse("2025-10-01T14:30:45-05:00[America/New_York]")
puts(dt.year())          # 2025
puts(dt.month())         # 10
puts(dt.day())           # 1
puts(dt.hour())          # 14
puts(dt.minute())        # 30
puts(dt.second())        # 45
puts(dt.day_of_week())   # 3 (Wednesday)
puts(dt.timezone())      # "America/New_York"
```

### Formatting Methods

#### `zoned.format(pattern)`
Format datetime using strftime-style format codes.

**Parameters:**
- `pattern` - Format string (Str)

**Returns:** Str

**Common format codes:**
- `%Y` - Year (4 digits, e.g., 2025)
- `%m` - Month (01-12)
- `%d` - Day (01-31)
- `%H` - Hour 24h (00-23)
- `%I` - Hour 12h (01-12)
- `%M` - Minute (00-59)
- `%S` - Second (00-59)
- `%p` - AM/PM
- `%A` - Full weekday name (Monday, Tuesday, etc.)
- `%a` - Abbreviated weekday (Mon, Tue, etc.)
- `%B` - Full month name (January, February, etc.)
- `%b` - Abbreviated month (Jan, Feb, etc.)
- `%Z` - Timezone name
- `%z` - Timezone offset (+0000)

**Example:**
```quest
let dt = time.now_local()
puts(dt.format("%Y-%m-%d %H:%M:%S"))  # "2025-10-01 14:30:45"
puts(dt.format("%B %d, %Y"))          # "October 01, 2025"
puts(dt.format("%I:%M %p"))           # "02:30 PM"
puts(dt.format("%A, %B %d, %Y"))      # "Wednesday, October 01, 2025"
```

#### `zoned.to_rfc3339()`
Format as RFC 3339 string.

**Returns:** Str

**Example:**
```quest
let dt = time.now_local()
puts(dt.to_rfc3339())  # "2025-10-01T14:30:45-04:00"
```

#### `zoned._str()`
Default string representation (ISO 8601).

**Returns:** Str

**Example:**
```quest
let dt = time.now_local()
puts(dt._str())  # "2025-10-01T14:30:45-04:00[America/New_York]"
```

### Timezone Conversion

#### `zoned.to_timezone(timezone)`
Convert to a different timezone.

**Parameters:**
- `timezone` - Target timezone name (Str)

**Returns:** Zoned

**Example:**
```quest
let ny = time.parse("2025-10-01T14:30:00-05:00[America/New_York]")
let london = ny.to_timezone("Europe/London")
let tokyo = ny.to_timezone("Asia/Tokyo")

puts(ny._str())      # "2025-10-01T14:30:00-05:00[America/New_York]"
puts(london._str())  # "2025-10-01T20:30:00+01:00[Europe/London]"
puts(tokyo._str())   # "2025-10-02T04:30:00+09:00[Asia/Tokyo]"
```

#### `zoned.to_utc()`
Convert to UTC timezone.

**Returns:** Zoned

**Example:**
```quest
let local = time.now_local()
let utc = local.to_utc()
```

### Arithmetic Methods

#### `zoned.add_years(years)`
Add years to the datetime.

**Parameters:**
- `years` - Number of years to add (Num)

**Returns:** Zoned

#### `zoned.add_months(months)`
Add months to the datetime.

**Parameters:**
- `months` - Number of months to add (Num)

**Returns:** Zoned

#### `zoned.add_days(days)`
Add days to the datetime.

**Parameters:**
- `days` - Number of days to add (Num)

**Returns:** Zoned

#### `zoned.add_hours(hours)`
Add hours to the datetime.

**Parameters:**
- `hours` - Number of hours to add (Num)

**Returns:** Zoned

#### `zoned.add_minutes(minutes)`
Add minutes to the datetime.

**Parameters:**
- `minutes` - Number of minutes to add (Num)

**Returns:** Zoned

#### `zoned.add_seconds(seconds)`
Add seconds to the datetime.

**Parameters:**
- `seconds` - Number of seconds to add (Num)

**Returns:** Zoned

**Example:**
```quest
let dt = time.parse("2025-10-01T14:30:00Z")
let tomorrow = dt.add_days(1)
let next_week = dt.add_days(7)
let next_month = dt.add_months(1)
let next_year = dt.add_years(1)
let later = dt.add_hours(3).add_minutes(30)
```

#### `zoned.subtract_years(years)`
Subtract years from the datetime.

**Parameters:**
- `years` - Number of years to subtract (Num)

**Returns:** Zoned

#### `zoned.subtract_months(months)`
Subtract months from the datetime.

**Parameters:**
- `months` - Number of months to subtract (Num)

**Returns:** Zoned

#### `zoned.subtract_days(days)`
Subtract days from the datetime.

**Parameters:**
- `days` - Number of days to subtract (Num)

**Returns:** Zoned

#### `zoned.subtract_hours(hours)`
Subtract hours from the datetime.

**Parameters:**
- `hours` - Number of hours to subtract (Num)

**Returns:** Zoned

#### `zoned.subtract_minutes(minutes)`
Subtract minutes from the datetime.

**Parameters:**
- `minutes` - Number of minutes to subtract (Num)

**Returns:** Zoned

#### `zoned.subtract_seconds(seconds)`
Subtract seconds from the datetime.

**Parameters:**
- `seconds` - Number of seconds to subtract (Num)

**Returns:** Zoned

**Example:**
```quest
let dt = time.now()
let yesterday = dt.subtract_days(1)
let last_week = dt.subtract_days(7)
let hour_ago = dt.subtract_hours(1)
```

#### `zoned.add(span)`
Add a span/duration to the datetime.

**Parameters:**
- `span` - Span object to add (Span)

**Returns:** Zoned

**Example:**
```quest
let dt = time.now()
let span = time.span(days: 2, hours: 3, minutes: 30)
let future = dt.add(span)
```

#### `zoned.subtract(span)`
Subtract a span/duration from the datetime.

**Parameters:**
- `span` - Span object to subtract (Span)

**Returns:** Zoned

#### `zoned.since(other)`
Calculate the duration between this datetime and another.

**Parameters:**
- `other` - Earlier datetime (Zoned or Timestamp)

**Returns:** Span

**Example:**
```quest
let start = time.parse("2025-10-01T10:00:00Z")
let end = time.parse("2025-10-01T15:30:45Z")
let duration = end.since(start)

puts(duration.hours())    # 5
puts(duration.minutes())  # 330
puts(duration.seconds())  # 19845
```

### Comparison Methods

#### `zoned.equals(other)`
Check if two datetimes represent the same instant.

**Parameters:**
- `other` - Datetime to compare (Zoned or Timestamp)

**Returns:** Bool

#### `zoned.before(other)`
Check if this datetime is before another.

**Parameters:**
- `other` - Datetime to compare (Zoned or Timestamp)

**Returns:** Bool

#### `zoned.after(other)`
Check if this datetime is after another.

**Parameters:**
- `other` - Datetime to compare (Zoned or Timestamp)

**Returns:** Bool

**Example:**
```quest
let dt1 = time.parse("2025-10-01T10:00:00Z")
let dt2 = time.parse("2025-10-01T15:00:00Z")

puts(dt1.equals(dt2))  # false
puts(dt1.before(dt2))  # true
puts(dt1.after(dt2))   # false
```

### Rounding Methods

#### `zoned.round_to_hour()`
Round datetime to the nearest hour.

**Returns:** Zoned

#### `zoned.round_to_minute()`
Round datetime to the nearest minute.

**Returns:** Zoned

#### `zoned.start_of_day()`
Get the start of the day (00:00:00).

**Returns:** Zoned

#### `zoned.end_of_day()`
Get the end of the day (23:59:59.999999999).

**Returns:** Zoned

#### `zoned.start_of_month()`
Get the first day of the month at 00:00:00.

**Returns:** Zoned

#### `zoned.end_of_month()`
Get the last day of the month at 23:59:59.999999999.

**Returns:** Zoned

**Example:**
```quest
let dt = time.parse("2025-10-15T14:30:45Z")
puts(dt.start_of_day()._str())    # "2025-10-15T00:00:00Z"
puts(dt.start_of_month()._str())  # "2025-10-01T00:00:00Z"
puts(dt.end_of_month()._str())    # "2025-10-31T23:59:59.999999999Z"
```

## Date Methods

Methods available on Date objects.

### Component Getters

#### `date.year()`
Get the year.

**Returns:** Num

#### `date.month()`
Get the month (1-12).

**Returns:** Num

#### `date.day()`
Get the day of month (1-31).

**Returns:** Num

#### `date.day_of_week()`
Get the day of week (1=Monday, 7=Sunday).

**Returns:** Num

#### `date.day_of_year()`
Get the day of year (1-366).

**Returns:** Num

### Arithmetic

#### `date.add_days(days)`
Add days to the date.

**Parameters:**
- `days` - Number of days (Num)

**Returns:** Date

#### `date.add_months(months)`
Add months to the date.

**Parameters:**
- `months` - Number of months (Num)

**Returns:** Date

#### `date.add_years(years)`
Add years to the date.

**Parameters:**
- `years` - Number of years (Num)

**Returns:** Date

**Example:**
```quest
let date = time.date(2025, 10, 1)
let tomorrow = date.add_days(1)
let next_month = date.add_months(1)
let next_year = date.add_years(1)
```

### Comparison

#### `date.equals(other)`
Check if two dates are equal.

**Parameters:**
- `other` - Date to compare (Date)

**Returns:** Bool

#### `date.before(other)`
Check if this date is before another.

**Parameters:**
- `other` - Date to compare (Date)

**Returns:** Bool

#### `date.after(other)`
Check if this date is after another.

**Parameters:**
- `other` - Date to compare (Date)

**Returns:** Bool

## Time Methods

Methods available on Time objects.

### Component Getters

#### `time.hour()`
Get the hour (0-23).

**Returns:** Num

#### `time.minute()`
Get the minute (0-59).

**Returns:** Num

#### `time.second()`
Get the second (0-59).

**Returns:** Num

#### `time.nanosecond()`
Get the nanosecond (0-999999999).

**Returns:** Num

## Span (Duration) Functions

### `time.span(years?, months?, days?, hours?, minutes?, seconds?, millis?, micros?, nanos?)`
Create a span from components (all parameters are optional named parameters).

**Parameters:**
- `years` - Number of years (Num)
- `months` - Number of months (Num)
- `days` - Number of days (Num)
- `hours` - Number of hours (Num)
- `minutes` - Number of minutes (Num)
- `seconds` - Number of seconds (Num)
- `millis` - Number of milliseconds (Num)
- `micros` - Number of microseconds (Num)
- `nanos` - Number of nanoseconds (Num)

**Returns:** Span

**Example:**
```quest
let span1 = time.span(days: 5, hours: 3)
let span2 = time.span(hours: 2, minutes: 30, seconds: 45)
let span3 = time.span(years: 1, months: 6, days: 15)
```

### `time.days(n)`
Create a span of n days.

**Parameters:**
- `n` - Number of days (Num)

**Returns:** Span

### `time.hours(n)`
Create a span of n hours.

**Parameters:**
- `n` - Number of hours (Num)

**Returns:** Span

### `time.minutes(n)`
Create a span of n minutes.

**Parameters:**
- `n` - Number of minutes (Num)

**Returns:** Span

### `time.seconds(n)`
Create a span of n seconds.

**Parameters:**
- `n` - Number of seconds (Num)

**Returns:** Span

**Example:**
```quest
let five_days = time.days(5)
let three_hours = time.hours(3)
let thirty_minutes = time.minutes(30)
```

## Span Methods

Methods available on Span objects.

### Component Getters

#### `span.years()`
Get the years component.

**Returns:** Num

#### `span.months()`
Get the months component.

**Returns:** Num

#### `span.days()`
Get the days component.

**Returns:** Num

#### `span.hours()`
Get the hours component.

**Returns:** Num

#### `span.minutes()`
Get the minutes component.

**Returns:** Num

#### `span.seconds()`
Get the seconds component.

**Returns:** Num

### Conversion

#### `span.as_hours()`
Convert entire span to hours (fractional).

**Returns:** Num

#### `span.as_minutes()`
Convert entire span to minutes (fractional).

**Returns:** Num

#### `span.as_seconds()`
Convert entire span to seconds (fractional).

**Returns:** Num

#### `span.as_millis()`
Convert entire span to milliseconds.

**Returns:** Num

**Example:**
```quest
let span = time.span(hours: 2, minutes: 30)
puts(span.as_hours())    # 2.5
puts(span.as_minutes())  # 150
puts(span.as_seconds())  # 9000
```

### Arithmetic

#### `span.add(other)`
Add two spans.

**Parameters:**
- `other` - Span to add (Span)

**Returns:** Span

#### `span.subtract(other)`
Subtract a span from this one.

**Parameters:**
- `other` - Span to subtract (Span)

**Returns:** Span

#### `span.multiply(n)`
Multiply span by a scalar.

**Parameters:**
- `n` - Multiplier (Num)

**Returns:** Span

#### `span.divide(n)`
Divide span by a scalar.

**Parameters:**
- `n` - Divisor (Num)

**Returns:** Span

**Example:**
```quest
let span1 = time.hours(5)
let span2 = time.minutes(30)
let total = span1.add(span2)
let doubled = span1.multiply(2)
let half = span1.divide(2)
```

## Utility Functions

### `time.sleep(seconds)`
Sleep for a specified duration (blocks execution).

**Parameters:**
- `seconds` - Duration in seconds (Num, can be fractional)

**Example:**
```quest
time.sleep(2)      # Sleep for 2 seconds
time.sleep(0.5)    # Sleep for 500ms
time.sleep(0.001)  # Sleep for 1ms
```

### `time.is_leap_year(year)`
Check if a year is a leap year.

**Parameters:**
- `year` - Year to check (Num)

**Returns:** Bool

**Example:**
```quest
puts(time.is_leap_year(2024))  # true
puts(time.is_leap_year(2025))  # false
```

### `time.ticks_ms()`
Get milliseconds elapsed since the program started. Uses a monotonic clock that is not affected by system time changes, making it ideal for measuring elapsed time and performance.

**Parameters:** None

**Returns:** Num - milliseconds since program start

**Example:**
```quest
use "std/time" as time

let start = time.ticks_ms()

# Do some work
let sum = 0
let i = 0
while i < 100000
    sum = sum + i
    i = i + 1
end

let finish = time.ticks_ms()
puts("Operation took", finish - start, "ms")
# Output: Operation took 245ms
```

**Use Cases:**
- Performance measurement
- Timing operations
- Benchmarking
- Rate limiting
- Timeout detection

**Notes:**
- The clock starts when the Quest program begins execution
- Returns a monotonic time that only moves forward
- Not affected by system clock adjustments
- Suitable for measuring short durations with millisecond precision
- For calendar time and dates, use `time.now()`, `time.today()`, etc.

## Complete Examples

### Example 1: Age Calculator

```quest
use "std/time" as time

let birthday = time.date(1990, 5, 15)
let today = time.today()

# Calculate age
let age = today.year() - birthday.year()
let this_year_birthday = time.date(today.year(), birthday.month(), birthday.day())
if today.before(this_year_birthday)
    age = age - 1
end

puts("You are " .. age._str() .. " years old")

# Days until next birthday
let next_birthday = this_year_birthday
if today.after(next_birthday)
    next_birthday = time.date(today.year() + 1, birthday.month(), birthday.day())
end

let days_until = next_birthday.since(today).days()
puts("Days until birthday: " .. days_until._str())
```

### Example 2: Timezone Converter

```quest
use "std/time" as time

# Meeting scheduled in New York
let meeting = time.datetime(2025, 10, 15, 14, 0, 0, "America/New_York")

puts("Meeting Times:")
puts("  New York:  " .. meeting.format("%I:%M %p %Z"))
puts("  London:    " .. meeting.to_timezone("Europe/London").format("%I:%M %p %Z"))
puts("  Tokyo:     " .. meeting.to_timezone("Asia/Tokyo").format("%I:%M %p %Z"))
puts("  Sydney:    " .. meeting.to_timezone("Australia/Sydney").format("%I:%M %p %Z"))
```

### Example 3: Performance Timer

```quest
use "std/time" as time

let start = time.now()

# Do some work
let sum = 0
for i in 1..1000000
    sum = sum + i
end

let elapsed = time.now().since(start)
puts("Computation took " .. elapsed.as_millis()._str() .. " ms")
```

### Example 4: Date Range Iteration

```quest
use "std/time" as time

let start_date = time.date(2025, 10, 1)
let end_date = time.date(2025, 10, 7)

let current = start_date
while current.before(end_date) or current.equals(end_date)
    puts(current.format("%A, %B %d"))  # "Wednesday, October 01"
    current = current.add_days(1)
end
```

### Example 5: Business Days Calculator

```quest
use "std/time" as time

fun is_weekend(date)
    let dow = date.day_of_week()
    return dow == 6 or dow == 7  # Saturday or Sunday
end

fun add_business_days(start_date, count)
    let current = start_date
    let added = 0

    while added < count
        current = current.add_days(1)
        if not is_weekend(current)
            added = added + 1
        end
    end

    return current
end

let today = time.today()
let deadline = add_business_days(today, 10)
puts("10 business days from now: " .. deadline._str())
```

## Integration with Other Modules

### With Logging

```quest
use "std/time" as time
use "std/log" as log

# The log module automatically uses time.now() for timestamps
log.info("Application started")

# You can also manually log with timestamps
let start_time = time.now()
# ... do work ...
let duration = time.now().since(start_time)
log.info("Task completed in " .. duration.as_seconds()._str() .. " seconds")
```

## Implementation Notes

### Jiff Integration

The time module is implemented as a thin wrapper around the [jiff](https://docs.rs/jiff/) Rust library, which provides:
- Temporal API compatibility (inspired by JavaScript's Temporal proposal)
- Full IANA timezone database support
- Automatic DST handling
- Nanosecond precision
- Comprehensive datetime arithmetic

### Performance Considerations

- Timezone lookups are cached by jiff
- All datetime objects are immutable (functional style)
- Arithmetic operations are optimized by jiff's internal representation
- String parsing is lazy where possible

### Error Handling

Invalid operations (like creating February 30th) will raise exceptions with descriptive error messages:

```quest
# This will raise an error
let invalid = time.date(2025, 2, 30)  # Error: invalid date
```

## Types Reference

Quest's time module introduces five new data structures. While these are implemented in Rust, they can be conceptualized as Quest types:

```quest
# Conceptual Quest type definitions (actual implementation is in Rust)

type Timestamp
    # An instant in time (UTC, nanosecond precision)
    # Internal: i128 nanoseconds since Unix epoch

    fun to_zoned(timezone: str) -> Zoned
    fun as_seconds() -> num
    fun as_millis() -> num
    fun as_nanos() -> num
end

type Zoned
    # A timezone-aware datetime
    # Internal: Timestamp + TimeZone + civil DateTime

    # Component getters
    fun year() -> num
    fun month() -> num
    fun day() -> num
    fun hour() -> num
    fun minute() -> num
    fun second() -> num
    fun nanosecond() -> num
    fun day_of_week() -> num
    fun day_of_year() -> num
    fun timezone() -> str

    # Formatting
    fun format(pattern: str) -> str
    fun to_rfc3339() -> str

    # Timezone conversion
    fun to_timezone(tz: str) -> Zoned
    fun to_utc() -> Zoned

    # Arithmetic
    fun add_years(n: num) -> Zoned
    fun add_months(n: num) -> Zoned
    fun add_days(n: num) -> Zoned
    fun add_hours(n: num) -> Zoned
    fun add_minutes(n: num) -> Zoned
    fun add_seconds(n: num) -> Zoned
    fun add(span: Span) -> Zoned
    fun subtract_days(n: num) -> Zoned
    fun subtract(span: Span) -> Zoned
    fun since(other: Zoned) -> Span

    # Comparison
    fun equals(other: Zoned) -> bool
    fun before(other: Zoned) -> bool
    fun after(other: Zoned) -> bool

    # Rounding
    fun round_to_hour() -> Zoned
    fun round_to_minute() -> Zoned
    fun start_of_day() -> Zoned
    fun end_of_day() -> Zoned
    fun start_of_month() -> Zoned
    fun end_of_month() -> Zoned
end

type Date
    # A calendar date (year, month, day)
    # Internal: i16 year, i8 month, i8 day

    fun year() -> num
    fun month() -> num
    fun day() -> num
    fun day_of_week() -> num
    fun day_of_year() -> num

    fun add_days(n: num) -> Date
    fun add_months(n: num) -> Date
    fun add_years(n: num) -> Date

    fun equals(other: Date) -> bool
    fun before(other: Date) -> bool
    fun after(other: Date) -> bool
end

type Time
    # A time of day (hour, minute, second, nanosecond)
    # Internal: i8 hour, i8 minute, i8 second, i32 nanosecond

    fun hour() -> num
    fun minute() -> num
    fun second() -> num
    fun nanosecond() -> num
end

type Span
    # A duration mixing calendar and clock units
    # Internal: years, months, days, hours, minutes, seconds, nanos

    # Component getters
    fun years() -> num
    fun months() -> num
    fun days() -> num
    fun hours() -> num
    fun minutes() -> num
    fun seconds() -> num

    # Conversion
    fun as_hours() -> num
    fun as_minutes() -> num
    fun as_seconds() -> num
    fun as_millis() -> num

    # Arithmetic
    fun add(other: Span) -> Span
    fun subtract(other: Span) -> Span
    fun multiply(n: num) -> Span
    fun divide(n: num) -> Span
end

# Common trait: All types implement QObj
trait Temporal
    fun _str() -> str        # String representation
    fun _rep() -> str        # REPL display format
    fun _doc() -> str        # Documentation
    fun _id() -> num         # Unique object ID
    fun cls() -> str         # Type name
end

# Timestamp, Zoned, Date, Time, Span all implement Temporal
```

### Detailed Type Descriptions

#### 1. Timestamp
An instant in time represented as UTC with nanosecond precision. Internally stores nanoseconds since Unix epoch (1970-01-01 00:00:00 UTC).

**Creation:**
- `time.now()` - Current instant
- `time.parse("2025-10-01T14:30:00Z")` - Parse from string

**Key Properties:**
- Always UTC
- Nanosecond precision
- Comparable and orderable
- Immutable

**Example:**
```quest
let ts = time.now()
puts(ts._str())        # "2025-10-01T14:30:45.123456789Z"
puts(ts.as_seconds())  # 1727794245
puts(ts.as_millis())   # 1727794245123
```

#### 2. Zoned
A timezone-aware datetime that combines a timestamp with timezone information and civil datetime (date + time). This is the primary type for working with human-readable dates and times.

**Creation:**
- `time.now_local()` - Current datetime in system timezone
- `time.datetime(2025, 10, 1, 14, 30, 0, "America/New_York")` - From components
- `time.parse("2025-10-01T14:30:00-05:00[America/New_York]")` - Parse from string

**Key Properties:**
- Timezone-aware (stores IANA timezone)
- Has both absolute (timestamp) and civil (date+time) representations
- Automatic DST handling
- Immutable

**Example:**
```quest
let dt = time.now_local()
puts(dt._str())          # "2025-10-01T10:30:45-04:00[America/New_York]"
puts(dt.year())          # 2025
puts(dt.month())         # 10
puts(dt.timezone())      # "America/New_York"
puts(dt.format("%B %d")) # "October 01"
```

#### 3. Date
A calendar date without time-of-day or timezone information. Represents year, month, and day.

**Creation:**
- `time.today()` - Today's date in local timezone
- `time.date(2025, 10, 1)` - From components
- `time.parse("2025-10-01")` - Parse from string

**Key Properties:**
- No time component
- No timezone information
- Useful for date arithmetic (birthdays, deadlines, etc.)
- Immutable

**Example:**
```quest
let date = time.date(2025, 10, 1)
puts(date._str())        # "2025-10-01"
puts(date.day_of_week()) # 3 (Wednesday)
let tomorrow = date.add_days(1)
```

#### 4. Time
A time-of-day without date or timezone information. Represents hour, minute, second, and nanosecond.

**Creation:**
- `time.time_now()` - Current time in local timezone
- `time.time(14, 30, 45)` - From components
- `time.time(14, 30, 45, 123456789)` - With nanoseconds

**Key Properties:**
- No date component
- No timezone information
- Nanosecond precision
- Immutable

**Example:**
```quest
let t = time.time(14, 30, 45)
puts(t._str())       # "14:30:45"
puts(t.hour())       # 14
puts(t.minute())     # 30
puts(t.second())     # 45
```

#### 5. Span
A duration or time span that can mix calendar units (years, months, days) with clock units (hours, minutes, seconds, nanoseconds). Used for datetime arithmetic and measuring elapsed time.

**Creation:**
- `time.span(days: 5, hours: 3)` - From components
- `time.days(7)` - Convenience constructor
- `dt1.since(dt2)` - Difference between two datetimes

**Key Properties:**
- Can represent both calendar and clock durations
- Aware of variable-length months and DST transitions
- Immutable
- Supports arithmetic operations

**Example:**
```quest
let span = time.span(days: 2, hours: 3, minutes: 30)
puts(span.as_hours())  # 51.5 (2 days + 3.5 hours)

let dur = time.hours(5).add(time.minutes(30))
puts(dur.as_minutes()) # 330
```

### Type Hierarchy

All five types implement Quest's `QObj` trait and have these common methods:
- `._str()` - String representation
- `._rep()` - REPL display format
- `._doc()` - Documentation
- `._id()` - Unique object ID
- `.cls()` - Type name
