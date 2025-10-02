# arrays

Arrays in Quest are ordered collections of values that can hold any type. Arrays are immutable by default - methods that modify arrays return new arrays rather than mutating the original.

## Array Literals

```quest
let empty = []
let numbers = [1, 2, 3, 4, 5]
let mixed = [1, "hello", true, nil]
let nested = [[1, 2], [3, 4], [5, 6]]
```

## Array Access

Arrays can be accessed using bracket notation with zero-based indexing:

```quest
let arr = [10, 20, 30, 40]
puts(arr[0])   # 10
puts(arr[1])   # 20
puts(arr[3])   # 40
```

## Immutability Pattern

Since arrays are immutable in expressions, use reassignment to "update" an array:

```quest
let arr = [1, 2, 3]

# Add element
arr = arr.push(4)
puts(arr)  # [1, 2, 3, 4]

# Remove last element
arr = arr.pop()
puts(arr)  # [1, 2, 3]

# Add to beginning
arr = arr.unshift(0)
puts(arr)  # [0, 1, 2, 3]

# Remove from beginning
arr = arr.shift()
puts(arr)  # [1, 2, 3]
```

## Common Patterns

### Building Arrays

```quest
let arr = []
arr = arr.push(1)
arr = arr.push(2)
arr = arr.push(3)
puts(arr)  # [1, 2, 3]
```

### Stack Operations (LIFO)

```quest
let stack = []

# Push items
stack = stack.push("first")
stack = stack.push("second")
stack = stack.push("third")

# Pop items
let item = stack.last()  # Get top item
stack = stack.pop()      # Remove it
puts(item)  # third
```

### Queue Operations (FIFO)

```quest
let queue = []

# Enqueue (add to end)
queue = queue.push("first")
queue = queue.push("second")
queue = queue.push("third")

# Dequeue (remove from front)
let item = queue.first()  # Get front item
queue = queue.shift()     # Remove it
puts(item)  # first
```

### Array Transformation with map/filter

```quest
# Transform and filter in one chain
let nums = [1, 2, 3, 4, 5, 6]
let result = nums
    .filter(fun (x) x % 2 == 0 end)  # Get evens [2, 4, 6]
    .map(fun (x) x * x end)          # Square them [4, 16, 36]
puts(result)  # [4, 16, 36]
```

### Finding Elements

```quest
let users = [
    {"name": "Alice", "age": 30},
    {"name": "Bob", "age": 25},
    {"name": "Carol", "age": 35}
]

# Find first user over 30
let user = users.find(fun (u) u["age"] > 30 end)
puts(user["name"])  # Carol

# Check if any user is under 20
let has_teen = users.any(fun (u) u["age"] < 20 end)
puts(has_teen)  # false
```

### Aggregating Data

```quest
let sales = [120, 450, 230, 890, 150]

# Sum
let total = sales.reduce(fun (sum, x) sum + x end, 0)
puts(total)  # 1840

# Max (using reduce)
let max_sale = sales.reduce(
    fun (max, x)
        if x > max
            x
        else
            max
        end
    end,
    0
)
puts(max_sale)  # 890
```

### Extracting Path Components

```quest
# Using split from strings and array methods
let path = "/home/user/documents/file.txt"
let parts = path.split("/").filter(fun (p) p.len() > 0 end)
let filename = parts.last()
puts(filename)  # file.txt
```

## Array Methods

### `len()`
Returns the number of elements in the array.

**Returns:** Num

**Example:**
```quest
let arr = [1, 2, 3, 4]
puts(arr.len())  # 4
```

### `push(value)`
Returns a new array with the value added to the end.

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Array (new array with element added)

**Example:**
```quest
let arr = [1, 2, 3]
let arr2 = arr.push(4)
puts(arr)   # [1, 2, 3]
puts(arr2)  # [1, 2, 3, 4]
```

### `pop()`
Returns a new array with the last element removed.

**Returns:** Array (new array without last element)

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [1, 2, 3, 4]
let arr2 = arr.pop()
puts(arr)   # [1, 2, 3, 4]
puts(arr2)  # [1, 2, 3]
```

### `shift()`
Returns a new array with the first element removed.

**Returns:** Array (new array without first element)

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [1, 2, 3, 4]
let arr2 = arr.shift()
puts(arr)   # [1, 2, 3, 4]
puts(arr2)  # [2, 3, 4]
```

### `unshift(value)`
Returns a new array with the value added to the beginning.

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Array (new array with element prepended)

**Example:**
```quest
let arr = [2, 3, 4]
let arr2 = arr.unshift(1)
puts(arr)   # [2, 3, 4]
puts(arr2)  # [1, 2, 3, 4]
```

### `get(index)`
Returns the element at the specified index.

**Parameters:**
- `index` - Zero-based index (Num)

**Returns:** Element at index

**Raises:** Error if index out of bounds

**Example:**
```quest
let arr = ["a", "b", "c"]
puts(arr.get(0))  # a
puts(arr.get(1))  # b
puts(arr.get(2))  # c
```

### `first()`
Returns the first element of the array.

**Returns:** First element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [10, 20, 30]
puts(arr.first())  # 10
```

### `last()`
Returns the last element of the array.

**Returns:** Last element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [10, 20, 30]
puts(arr.last())  # 30
```

### `reverse()`
Returns a new array with elements in reverse order.

**Returns:** Array (reversed)

**Example:**
```quest
let arr = [1, 2, 3, 4]
let rev = arr.reverse()
puts(rev)  # [4, 3, 2, 1]
puts(arr)  # [1, 2, 3, 4] (original unchanged)
```

### `slice(start, end)`
Returns a new array containing elements from `start` index up to (but not including) `end` index. Supports negative indices to count from the end.

**Parameters:**
- `start` - Starting index (Num), negative counts from end
- `end` - Ending index (Num, exclusive), negative counts from end

**Returns:** Array (slice of original)

**Example:**
```quest
let arr = [0, 1, 2, 3, 4, 5]
puts(arr.slice(1, 4))    # [1, 2, 3]
puts(arr.slice(0, 2))    # [0, 1]
puts(arr.slice(2, -1))   # [2, 3, 4]
puts(arr.slice(-3, -1))  # [3, 4]
```

### `concat(other)`
Returns a new array combining this array with another array.

**Parameters:**
- `other` - Array to concatenate

**Returns:** Array (combined)

**Example:**
```quest
let a = [1, 2, 3]
let b = [4, 5, 6]
let combined = a.concat(b)
puts(combined)  # [1, 2, 3, 4, 5, 6]
```

### `join(separator)`
Converts array to a string with elements joined by separator.

**Parameters:**
- `separator` - String to place between elements

**Returns:** Str (joined string)

**Example:**
```quest
let arr = ["a", "b", "c"]
puts(arr.join(", "))     # a, b, c
puts(arr.join(""))       # abc
puts([1, 2, 3].join("-")) # 1-2-3
```

### `contains(value)`
Checks if the array contains the specified value.

**Parameters:**
- `value` - Value to search for (any type)

**Returns:** Bool (true if found)

**Example:**
```quest
let arr = [1, 2, 3, 4, 5]
puts(arr.contains(3))  # true
puts(arr.contains(6))  # false
```

### `index_of(value)`
Returns the index of the first occurrence of value, or -1 if not found.

**Parameters:**
- `value` - Value to search for (any type)

**Returns:** Num (index or -1)

**Example:**
```quest
let arr = ["a", "b", "c", "b"]
puts(arr.index_of("b"))  # 1
puts(arr.index_of("x"))  # -1
```

### `count(value)`
Counts how many times a value appears in the array.

**Parameters:**
- `value` - Value to count (any type)

**Returns:** Num (count)

**Example:**
```quest
let arr = [1, 2, 3, 2, 4, 2]
puts(arr.count(2))  # 3
puts(arr.count(5))  # 0
```

### `empty()`
Checks if the array is empty.

**Returns:** Bool (true if empty)

**Example:**
```quest
let arr1 = []
let arr2 = [1, 2, 3]
puts(arr1.empty())  # true
puts(arr2.empty())  # false
```

### `sort()`
Returns a new array with elements sorted in ascending order. Works with numbers and strings.

**Returns:** Array (sorted)

**Example:**
```quest
let nums = [3, 1, 4, 1, 5, 9, 2, 6]
puts(nums.sort())  # [1, 1, 2, 3, 4, 5, 6, 9]

let words = ["dog", "cat", "bird", "fish"]
puts(words.sort())  # [bird, cat, dog, fish]
```

### `map(fn)`
Transform each element by applying a function. Returns a new array with transformed elements.

**Parameters:**
- `fn` - Function that takes one element and returns transformed value

**Returns:** Array (transformed)

**Example:**
```quest
let nums = [1, 2, 3, 4]
let doubled = nums.map(fun (x) x * 2 end)
puts(doubled)  # [2, 4, 6, 8]

let words = ["hello", "world"]
let upper = words.map(fun (s) s.upper() end)
puts(upper)  # [HELLO, WORLD]
```

### `filter(fn)`
Select elements that match a predicate function. Returns a new array with matching elements.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Array (filtered)

**Example:**
```quest
let nums = [1, 2, 3, 4, 5, 6]
let evens = nums.filter(fun (x) x % 2 == 0 end)
puts(evens)  # [2, 4, 6]

let words = ["cat", "elephant", "dog", "giraffe"]
let long = words.filter(fun (w) w.len() > 3 end)
puts(long)  # [elephant, giraffe]
```

### `each(fn)`
Iterate over elements, calling function for each. Used for side effects, returns nil.

**Parameters:**
- `fn` - Function taking element (and optionally index)

**Returns:** Nil

**Example:**
```quest
let arr = ["a", "b", "c"]
arr.each(fun (elem) puts(elem) end)
# Output:
# a
# b
# c

# With index
arr.each(fun (elem, idx) puts(f"{idx}: {elem}") end)
# Output:
# 0: a
# 1: b
# 2: c
```

### `reduce(fn, initial)`
Reduce array to single value by applying accumulator function.

**Parameters:**
- `fn` - Function taking (accumulator, element) and returning new accumulator
- `initial` - Initial accumulator value

**Returns:** Final accumulator value (any type)

**Example:**
```quest
let nums = [1, 2, 3, 4, 5]
let sum = nums.reduce(fun (acc, x) acc + x end, 0)
puts(sum)  # 15

let product = nums.reduce(fun (acc, x) acc * x end, 1)
puts(product)  # 120

let words = ["hello", "world", "from", "quest"]
let sentence = words.reduce(fun (acc, w) acc .. " " .. w end, "")
puts(sentence)  #  hello world from quest
```

### `any(fn)`
Check if any element matches predicate.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Bool (true if any match)

**Example:**
```quest
let nums = [1, 2, 3, 4, 5]
puts(nums.any(fun (x) x > 3 end))  # true
puts(nums.any(fun (x) x > 10 end)) # false
```

### `all(fn)`
Check if all elements match predicate.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Bool (true if all match)

**Example:**
```quest
let nums = [2, 4, 6, 8]
puts(nums.all(fun (x) x % 2 == 0 end))  # true
puts(nums.all(fun (x) x > 5 end))       # false
```

### `find(fn)`
Find first element matching predicate. Returns nil if not found.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** First matching element or nil

**Example:**
```quest
let nums = [1, 2, 3, 4, 5]
let found = nums.find(fun (x) x > 3 end)
puts(found)  # 4

let not_found = nums.find(fun (x) x > 10 end)
puts(not_found)  # nil
```

### `find_index(fn)`
Find index of first element matching predicate. Returns -1 if not found.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Num (index or -1)

**Example:**
```quest
let words = ["cat", "dog", "elephant", "bird"]
let idx = words.find_index(fun (w) w.len() > 5 end)
puts(idx)  # 2 (elephant is at index 2)

let not_found = words.find_index(fun (w) w.len() > 10 end)
puts(not_found)  # -1
```

## Notes

- Arrays are **zero-indexed** (first element is at index 0)
- Arrays are **heterogeneous** (can contain mixed types)
- Arrays are **immutable** (methods return new arrays)
- Use reassignment (`arr = arr.push(x)`) to update array variables
- Out-of-bounds access raises an error
- Empty array operations (pop/shift/first/last on `[]`) raise errors
- Higher-order methods (`map`, `filter`, etc.) require function arguments
- Negative indices in `slice()` count backwards from the end
