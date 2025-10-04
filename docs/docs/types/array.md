# arrays

Arrays in Quest are ordered, mutable collections of values that can hold any type. Following Python's design, arrays are mutable - methods like `push()`, `pop()`, and `sort()` modify the array in place.

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

## Mutability

Arrays are mutable - methods that modify arrays change them in place:

```quest
let arr = [1, 2, 3]

# Add element (modifies arr)
arr.push(4)
puts(arr)  # [1, 2, 3, 4]

# Remove last element (returns removed element)
let last = arr.pop()
puts(last)  # 4
puts(arr)   # [1, 2, 3]

# Add to beginning
arr.unshift(0)
puts(arr)  # [0, 1, 2, 3]

# Remove from beginning (returns removed element)
let first = arr.shift()
puts(first)  # 0
puts(arr)    # [1, 2, 3]
```

## Common Patterns

### Building Arrays

```quest
let arr = []
arr.push(1)
arr.push(2)
arr.push(3)
puts(arr)  # [1, 2, 3]
```

### Stack Operations (LIFO)

```quest
let stack = []

# Push items
stack.push("first")
stack.push("second")
stack.push("third")

# Pop items
let item = stack.pop()
puts(item)   # third
puts(stack)  # [first, second]
```

### Queue Operations (FIFO)

```quest
let queue = []

# Enqueue (add to end)
queue.push("first")
queue.push("second")
queue.push("third")

# Dequeue (remove from front)
let item = queue.shift()
puts(item)   # first
puts(queue)  # [second, third]
```

### Array Transformation with map/filter

```quest
# Transform and filter in one chain
let nums = [1, 2, 3, 4, 5, 6]
let result = nums
    .filter(fun (x) x % 2 == 0 end)  # Get evens [2, 4, 6]
    .map(fun (x) x * x end)          # Square them [4, 16, 36]
puts(result)  # [4, 16, 36]
puts(nums)    # [1, 2, 3, 4, 5, 6] (unchanged - filter/map return new arrays)
```

### In-Place Sorting

```quest
let nums = [3, 1, 4, 1, 5, 9, 2, 6]
nums.sort()  # Sorts in place
puts(nums)   # [1, 1, 2, 3, 4, 5, 6, 9]

# Use sorted() for non-mutating version
let original = [5, 2, 8, 1]
let sorted = original.sorted()
puts(original)  # [5, 2, 8, 1] (unchanged)
puts(sorted)    # [1, 2, 5, 8]
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

## Array Methods

### Mutating Methods

These methods modify the array in place and return nil (except `pop()`, `shift()`, and `remove_at()` which return the removed element).

#### `push(value)`
Adds value to the end of the array.

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Nil

**Example:**
```quest
let arr = [1, 2, 3]
arr.push(4)
puts(arr)  # [1, 2, 3, 4]
```

#### `pop()`
Removes and returns the last element of the array.

**Returns:** Last element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [1, 2, 3, 4]
let last = arr.pop()
puts(last)  # 4
puts(arr)   # [1, 2, 3]
```

#### `shift()`
Removes and returns the first element of the array.

**Returns:** First element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [1, 2, 3, 4]
let first = arr.shift()
puts(first)  # 1
puts(arr)    # [2, 3, 4]
```

#### `unshift(value)`
Adds value to the beginning of the array.

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Nil

**Example:**
```quest
let arr = [2, 3, 4]
arr.unshift(1)
puts(arr)  # [1, 2, 3, 4]
```

#### `reverse()`
Reverses the array in place.

**Returns:** Nil

**Example:**
```quest
let arr = [1, 2, 3, 4]
arr.reverse()
puts(arr)  # [4, 3, 2, 1]
```

#### `sort()`
Sorts the array in place in ascending order. Works with numbers and strings.

**Returns:** Nil

**Example:**
```quest
let nums = [3, 1, 4, 1, 5, 9, 2, 6]
nums.sort()
puts(nums)  # [1, 1, 2, 3, 4, 5, 6, 9]

let words = ["dog", "cat", "bird", "fish"]
words.sort()
puts(words)  # [bird, cat, dog, fish]
```

#### `clear()`
Removes all elements from the array.

**Returns:** Nil

**Example:**
```quest
let arr = [1, 2, 3, 4, 5]
arr.clear()
puts(arr)  # []
```

#### `insert(index, value)`
Inserts value at the specified index, shifting subsequent elements.

**Parameters:**
- `index` - Zero-based index where to insert (Num)
- `value` - Value to insert (any type)

**Returns:** Nil

**Raises:** Error if index > array length

**Example:**
```quest
let arr = [1, 2, 4, 5]
arr.insert(2, 3)
puts(arr)  # [1, 2, 3, 4, 5]
```

#### `remove(value)`
Removes the first occurrence of value from the array.

**Parameters:**
- `value` - Value to remove (any type)

**Returns:** Bool (true if element was found and removed, false otherwise)

**Example:**
```quest
let arr = [1, 2, 3, 2, 4]
let found = arr.remove(2)
puts(found)  # true
puts(arr)    # [1, 3, 2, 4]
```

#### `remove_at(index)`
Removes and returns the element at the specified index.

**Parameters:**
- `index` - Zero-based index (Num)

**Returns:** Removed element

**Raises:** Error if index out of bounds

**Example:**
```quest
let arr = [1, 2, 3, 4, 5]
let removed = arr.remove_at(2)
puts(removed)  # 3
puts(arr)      # [1, 2, 4, 5]
```

### Non-Mutating Methods

These methods return new arrays or values without modifying the original array.

#### `len()`
Returns the number of elements in the array.

**Returns:** Int

**Example:**
```quest
let arr = [1, 2, 3, 4]
puts(arr.len())  # 4
```

#### `get(index)`
Returns the element at the specified index.

**Parameters:**
- `index` - Zero-based index (Int)

**Returns:** Element at index

**Raises:** Error if index out of bounds

**Example:**
```quest
let arr = ["a", "b", "c"]
puts(arr.get(0))  # a
puts(arr.get(1))  # b
```

#### `first()`
Returns the first element of the array.

**Returns:** First element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [10, 20, 30]
puts(arr.first())  # 10
```

#### `last()`
Returns the last element of the array.

**Returns:** Last element

**Raises:** Error if array is empty

**Example:**
```quest
let arr = [10, 20, 30]
puts(arr.last())  # 30
```

#### `reversed()`
Returns a new array with elements in reverse order.

**Returns:** Array (new reversed array)

**Example:**
```quest
let arr = [1, 2, 3, 4]
let rev = arr.reversed()
puts(rev)  # [4, 3, 2, 1]
puts(arr)  # [1, 2, 3, 4] (original unchanged)
```

#### `sorted()`
Returns a new array with elements sorted in ascending order.

**Returns:** Array (new sorted array)

**Example:**
```quest
let nums = [3, 1, 4, 1, 5, 9, 2, 6]
let sorted = nums.sorted()
puts(sorted)  # [1, 1, 2, 3, 4, 5, 6, 9]
puts(nums)    # [3, 1, 4, 1, 5, 9, 2, 6] (original unchanged)
```

#### `slice(start, end)`
Returns a new array containing elements from `start` index up to (but not including) `end` index. Supports negative indices to count from the end.

**Parameters:**
- `start` - Starting index (Int), negative counts from end
- `end` - Ending index (Int, exclusive), negative counts from end

**Returns:** Array (new slice)

**Example:**
```quest
let arr = [0, 1, 2, 3, 4, 5]
puts(arr.slice(1, 4))    # [1, 2, 3]
puts(arr.slice(0, 2))    # [0, 1]
puts(arr.slice(2, -1))   # [2, 3, 4]
puts(arr.slice(-3, -1))  # [3, 4]
```

#### `concat(other)`
Returns a new array combining this array with another array.

**Parameters:**
- `other` - Array to concatenate

**Returns:** Array (new combined array)

**Example:**
```quest
let a = [1, 2, 3]
let b = [4, 5, 6]
let combined = a.concat(b)
puts(combined)  # [1, 2, 3, 4, 5, 6]
puts(a)         # [1, 2, 3] (original unchanged)
```

#### `join(separator)`
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

#### `contains(value)`
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

#### `index_of(value)`
Returns the index of the first occurrence of value, or -1 if not found.

**Parameters:**
- `value` - Value to search for (any type)

**Returns:** Int (index or -1)

**Example:**
```quest
let arr = ["a", "b", "c", "b"]
puts(arr.index_of("b"))  # 1
puts(arr.index_of("x"))  # -1
```

#### `count(value)`
Counts how many times a value appears in the array.

**Parameters:**
- `value` - Value to count (any type)

**Returns:** Int (count)

**Example:**
```quest
let arr = [1, 2, 3, 2, 4, 2]
puts(arr.count(2))  # 3
puts(arr.count(5))  # 0
```

#### `empty()`
Checks if the array is empty.

**Returns:** Bool (true if empty)

**Example:**
```quest
let arr1 = []
let arr2 = [1, 2, 3]
puts(arr1.empty())  # true
puts(arr2.empty())  # false
```

### Higher-Order Methods

These methods take functions as arguments and return new arrays or values.

#### `map(fn)`
Transform each element by applying a function. Returns a new array with transformed elements.

**Parameters:**
- `fn` - Function that takes one element and returns transformed value

**Returns:** Array (new transformed array)

**Example:**
```quest
let nums = [1, 2, 3, 4]
let doubled = nums.map(fun (x) x * 2 end)
puts(doubled)  # [2, 4, 6, 8]
puts(nums)     # [1, 2, 3, 4] (original unchanged)

let words = ["hello", "world"]
let upper = words.map(fun (s) s.upper() end)
puts(upper)  # [HELLO, WORLD]
```

#### `filter(fn)`
Select elements that match a predicate function. Returns a new array with matching elements.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Array (new filtered array)

**Example:**
```quest
let nums = [1, 2, 3, 4, 5, 6]
let evens = nums.filter(fun (x) x % 2 == 0 end)
puts(evens)  # [2, 4, 6]
puts(nums)   # [1, 2, 3, 4, 5, 6] (original unchanged)
```

#### `each(fn)`
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
arr.each(fun (elem, idx)
    puts(idx .. ": " .. elem)
end)
# Output:
# 0: a
# 1: b
# 2: c
```

#### `reduce(fn, initial)`
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
```

#### `any(fn)`
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

#### `all(fn)`
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

#### `find(fn)`
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

#### `find_index(fn)`
Find index of first element matching predicate. Returns -1 if not found.

**Parameters:**
- `fn` - Function that takes one element and returns Bool

**Returns:** Int (index or -1)

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
- Arrays are **mutable** - most methods modify the array in place
- **Mutating methods**: `push()`, `pop()`, `shift()`, `unshift()`, `reverse()`, `sort()`, `clear()`, `insert()`, `remove()`, `remove_at()`
- **Non-mutating alternatives**: Use `sorted()` and `reversed()` for copies
- **Higher-order methods** (`map`, `filter`, etc.) always return new arrays
- Out-of-bounds access raises an error
- Empty array operations (pop/shift/first/last on `[]`) raise errors
- Negative indices in `slice()` count backwards from the end
