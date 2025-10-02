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
