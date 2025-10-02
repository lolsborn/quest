# Time Module Design

Quest's time module for date/time handling, inspired by TC39 Temporal API, implemented with jiff.

## Core Concepts

### Instant
A point in time with nanosecond precision (internally UTC).

### DateTime
A date and time with timezone awareness.

### Date
A calendar date (year, month, day).

### Time
A time of day (hour, minute, second, nanosecond).

### Duration
A length of time (days, hours, minutes, etc.).

## API Design

### Module Import

```quest
use "std/time" as time
```

## Functions

### Current Time

```quest
# Get current instant (UTC timestamp)
let now = time.now()
puts(now)  # "2025-01-10T15:30:45.123456789Z"

# Get current datetime in system timezone
let dt = time.now_local()
puts(dt)  # "2025-01-10T10:30:45.123-05:00[America/New_York]"

# Get current date
let today = time.today()
puts(today)  # "2025-01-10"

# Get current time
let current_time = time.time_now()
puts(current_time)  # "15:30:45.123"
```

### Creating DateTime Objects

```quest
# From string (ISO 8601)
let dt = time.parse("2025-01-10T15:30:00Z")
let dt = time.parse("2025-01-10 15:30:00")

# From components
let dt = time.datetime(2025, 1, 10, 15, 30, 0)
let dt = time.datetime(2025, 1, 10, 15, 30, 0, 0, "America/New_York")

# Date only
let date = time.date(2025, 1, 10)

# Time only
let t = time.time(15, 30, 45)
let t = time.time(15, 30, 45, 123000000)  # with nanoseconds
```

### Formatting

```quest
let dt = time.now()

# ISO 8601 (default)
puts(dt.to_string())  # "2025-01-10T15:30:45.123Z"

# Custom format (strftime style)
puts(dt.format("%Y-%m-%d %H:%M:%S"))  # "2025-01-10 15:30:45"
puts(dt.format("%B %d, %Y"))          # "January 10, 2025"
puts(dt.format("%I:%M %p"))           # "03:30 PM"

# Common formats
puts(dt.to_date_string())   # "2025-01-10"
puts(dt.to_time_string())   # "15:30:45"
puts(dt.to_rfc3339())       # "2025-01-10T15:30:45+00:00"
```

### Components/Getters

```quest
let dt = time.parse("2025-01-10T15:30:45.123Z")

# Date components
puts(dt.year())       # 2025
puts(dt.month())      # 1
puts(dt.day())        # 10
puts(dt.day_of_week()) # 5 (Friday, 1=Monday)
puts(dt.day_of_year()) # 10

# Time components
puts(dt.hour())       # 15
puts(dt.minute())     # 30
puts(dt.second())     # 45
puts(dt.millisecond()) # 123
puts(dt.microsecond()) # 123000
puts(dt.nanosecond())  # 123000000

# Timezone
puts(dt.timezone())   # "UTC"
puts(dt.offset())     # "+00:00"

# Unix timestamp
puts(dt.timestamp())  # 1736521845 (seconds)
puts(dt.timestamp_millis()) # 1736521845123
puts(dt.timestamp_nanos())  # 1736521845123000000
```

### Arithmetic

```quest
let dt = time.parse("2025-01-10T15:30:00Z")

# Add/subtract durations
let tomorrow = dt.add_days(1)
let next_week = dt.add_weeks(1)
let next_month = dt.add_months(1)
let next_year = dt.add_years(1)

let later = dt.add_hours(3)
let soon = dt.add_minutes(30)
let shortly = dt.add_seconds(45)

# Subtract
let yesterday = dt.subtract_days(1)
let hour_ago = dt.subtract_hours(1)

# Duration objects
let dur = time.duration(days: 1, hours: 3, minutes: 30)
let future = dt.add(dur)
let past = dt.subtract(dur)

# Difference between two times
let start = time.parse("2025-01-10T10:00:00Z")
let end = time.parse("2025-01-10T15:30:00Z")
let diff = end.since(start)

puts(diff.hours())    # 5
puts(diff.minutes())  # 330
puts(diff.seconds())  # 19800
puts(diff.to_string()) # "5h 30m"
```

### Comparison

```quest
let dt1 = time.parse("2025-01-10T10:00:00Z")
let dt2 = time.parse("2025-01-10T15:00:00Z")

puts(dt1.equals(dt2))    # false
puts(dt1.before(dt2))    # true
puts(dt1.after(dt2))     # false
puts(dt1.compare(dt2))   # -1 (before), 0 (equal), 1 (after)

# Can also use comparison operators if supported
puts(dt1 < dt2)   # true
puts(dt1 <= dt2)  # true
puts(dt1 > dt2)   # false
puts(dt1 >= dt2)  # false
puts(dt1 == dt2)  # false
```

### Timezone Conversion

```quest
let utc = time.parse("2025-01-10T15:30:00Z")

# Convert to different timezone
let ny = utc.to_timezone("America/New_York")
puts(ny)  # "2025-01-10T10:30:00-05:00[America/New_York]"

let tokyo = utc.to_timezone("Asia/Tokyo")
puts(tokyo)  # "2025-01-11T00:30:00+09:00[Asia/Tokyo]"

# Convert to local system timezone
let local = utc.to_local()
```

### Duration

```quest
# Create durations
let dur = time.duration(hours: 5, minutes: 30, seconds: 45)
let dur = time.duration(days: 2, hours: 12)

# Duration from components
let dur = time.days(5)
let dur = time.hours(24)
let dur = time.minutes(90)
let dur = time.seconds(3600)

# Parse duration string
let dur = time.parse_duration("5h 30m")
let dur = time.parse_duration("2d 12h 30m 15s")

# Duration operations
let total = dur1.add(dur2)
let remaining = dur1.subtract(dur2)
let doubled = dur.multiply(2)
let half = dur.divide(2)

# Conversion
puts(dur.as_hours())    # 5.5
puts(dur.as_minutes())  # 330
puts(dur.as_seconds())  # 19845
puts(dur.to_string())   # "5h 30m 45s"
```

### Utility Functions

```quest
# Sleep (blocks execution)
time.sleep(2)           # Sleep for 2 seconds
time.sleep(0.5)         # Sleep for 500ms
time.sleep_millis(500)  # Sleep for 500ms
time.sleep_micros(1000) # Sleep for 1000 microseconds

# Measure elapsed time
let start = time.now()
# ... do work ...
let elapsed = time.now().since(start)
puts("Took {elapsed.as_seconds()} seconds")

# Round/truncate
let dt = time.now()
let rounded_hour = dt.round_to_hour()
let rounded_minute = dt.round_to_minute()
let start_of_day = dt.start_of_day()
let end_of_day = dt.end_of_day()
let start_of_month = dt.start_of_month()
let end_of_month = dt.end_of_month()

# Validation
let is_valid = time.is_valid_date(2025, 2, 30)  # false
let is_leap = time.is_leap_year(2024)           # true
```

### Range and Iteration

```quest
# Date ranges
let start = time.date(2025, 1, 1)
let end = time.date(2025, 1, 10)

# Generate sequence of dates
let dates = time.date_range(start, end)
dates.each(fun(date)
    puts(date)
end)

# Step by different amounts
let every_other_day = time.date_range(start, end, step: 2)
let weeks = time.date_range(start, end, step: 7)
```

## Complete Examples

### Example 1: Birthday Calculator

```quest
use "std/time" as time

let birthday = time.date(1990, 5, 15)
let today = time.today()
let age = today.year() - birthday.year()

# Check if birthday has passed this year
let this_year_birthday = time.date(today.year(), birthday.month(), birthday.day())
if today.before(this_year_birthday)
    age = age - 1
end

puts("You are {age} years old")

# Days until next birthday
let next_birthday = time.date(today.year(), birthday.month(), birthday.day())
if today.after(next_birthday)
    next_birthday = time.date(today.year() + 1, birthday.month(), birthday.day())
end

let days_until = next_birthday.since(today).as_days()
puts("Days until birthday: {days_until}")
```

### Example 2: Meeting Scheduler

```quest
use "std/time" as time

# Schedule meeting in NY time
let meeting_ny = time.parse("2025-01-15T14:00:00[America/New_York]")

# Convert to other timezones
let meeting_london = meeting_ny.to_timezone("Europe/London")
let meeting_tokyo = meeting_ny.to_timezone("Asia/Tokyo")

puts("Meeting times:")
puts("  New York: {meeting_ny.format('%I:%M %p %Z')}")
puts("  London:   {meeting_london.format('%I:%M %p %Z')}")
puts("  Tokyo:    {meeting_tokyo.format('%I:%M %p %Z')}")
```

### Example 3: Performance Timing

```quest
use "std/time" as time

let start = time.now()

# Do some work
let sum = 0
for i in 0 to 1000000
    sum = sum + i
end

let elapsed = time.now().since(start)
puts("Computation took {elapsed.as_millis()} ms")
```

### Example 4: Countdown Timer

```quest
use "std/time" as time

let target = time.parse("2025-12-31T23:59:59Z")

while true
    let now = time.now()
    let remaining = target.since(now)

    if remaining.as_seconds() <= 0
        puts("Happy New Year!")
        break
    end

    let days = remaining.days()
    let hours = remaining.hours() % 24
    let minutes = remaining.minutes() % 60
    let seconds = remaining.seconds() % 60

    puts("Time remaining: {days}d {hours}h {minutes}m {seconds}s")
    time.sleep(1)
end
```

### Example 5: Business Days Calculator

```quest
use "std/time" as time

fun is_weekend(date)
    let dow = date.day_of_week()
    dow == 6 or dow == 7  # Saturday or Sunday
end

fun add_business_days(start_date, days)
    let current = start_date
    let added = 0

    while added < days
        current = current.add_days(1)
        if !is_weekend(current)
            added = added + 1
        end
    end

    current
end

let today = time.today()
let deadline = add_business_days(today, 10)
puts("10 business days from now: {deadline}")
```

## Implementation Notes

### Rust Side (using jiff)

- Use `jiff::Timestamp` for instants
- Use `jiff::Zoned` for timezone-aware datetime
- Use `jiff::civil::Date` for dates
- Use `jiff::civil::Time` for times
- Use `jiff::Span` for durations
- All datetime objects wrapped in `QValue::DateTime` (new type)

### Quest Side

- DateTime objects are immutable
- All operations return new datetime objects
- Timezone database from jiff (IANA tzdb)
- ISO 8601 as default string format
- Methods follow Temporal API naming conventions

### Performance

- Lazy parsing (parse strings only when needed)
- Cache timezone lookups
- Efficient comparison using underlying timestamps
- Duration calculations optimized by jiff

## Format Specifiers

Common strftime format codes supported:

- `%Y` - Year (4 digits)
- `%m` - Month (01-12)
- `%d` - Day (01-31)
- `%H` - Hour 24h (00-23)
- `%I` - Hour 12h (01-12)
- `%M` - Minute (00-59)
- `%S` - Second (00-59)
- `%p` - AM/PM
- `%A` - Full weekday name
- `%a` - Abbreviated weekday
- `%B` - Full month name
- `%b` - Abbreviated month
- `%Z` - Timezone name
- `%z` - Timezone offset
