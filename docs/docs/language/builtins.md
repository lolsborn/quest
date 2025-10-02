# Built-in Functions

Quest provides several built-in functions that are always available without needing to import any modules.

## Output Functions

### `puts(args...)`

Prints values to stdout, followed by a newline. Multiple arguments are printed without separators.

**Arguments:** Any number of values

**Returns:** `nil`

**Example:**
```quest
puts("Hello, World!")           # Hello, World!
puts("Answer:", 42)             # Answer:42
puts("x =", 5, "y =", 10)      # x =5y =10
```

### `print(args...)`

Prints values to stdout without a trailing newline.

**Arguments:** Any number of values

**Returns:** `nil`

**Example:**
```quest
print("Loading")
print(".")
print(".")
print(".")
puts(" Done!")
# Output: Loading... Done!
```

## Utility Functions

### `len(value)`

Returns the length of a collection or string.

**Arguments:**
- `value` - An array, dict, or string

**Returns:** Number - the length/size

**Example:**
```quest
let arr = [1, 2, 3, 4, 5]
puts(len(arr))              # 5

let text = "hello"
puts(len(text))             # 5

let dict = {"a": 1, "b": 2}
puts(len(dict))             # 2
```

## Time Functions

### `ticks_ms()`

Returns the number of milliseconds elapsed since the program started. Uses a monotonic clock that is not affected by system time changes, making it ideal for measuring elapsed time and performance.

**Arguments:** None

**Returns:** Number - milliseconds since program start

**Example:**
```quest
let start = ticks_ms()

# Do some work
let sum = 0
let i = 0
while i < 100000
    sum = sum + i
    i = i + 1
end

let finish = ticks_ms()
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
- For calendar time, use the `time` module instead

**Comparison with `time` module:**

| Feature | `ticks_ms()` | `time` module |
|---------|--------------|---------------|
| Purpose | Performance measurement | Calendar time |
| Clock | Monotonic | System clock |
| Units | Milliseconds | Various (with nanosecond precision) |
| Start point | Program start | Unix epoch or custom |
| Use case | Elapsed time, benchmarks | Dates, times, scheduling |

## Type Checking

Quest is dynamically typed, but you can check types at runtime:

```quest
let x = 5
puts(x.cls())  # "Num"

let s = "hello"
puts(s.cls())  # "Str"
```

## See Also

- [Standard Library](../stdlib/index.md) - Additional functions in modules
- [time module](../stdlib/time.md) - Calendar and timezone-aware time operations
- [sys module](../stdlib/sys.md) - System information and script metadata
