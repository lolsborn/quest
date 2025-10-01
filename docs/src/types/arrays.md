# Arrays

Arrays in Quest are ordered collections of values. Arrays are immutable by default - methods that modify arrays return new arrays rather than mutating the original.

## Array Literals

```q
let empty = []
let numbers = [1, 2, 3, 4, 5]
let mixed = [1, "hello", true, nil]
let nested = [[1, 2], [3, 4], [5, 6]]
```quest

## Array Methods

### `len()`
Returns the number of elements in the array

**Returns:** Num

**Example:**
```q
let arr = [1, 2, 3, 4]
puts(arr.len())  # 4
```quest

### `push(value)`
Returns a new array with the value added to the end

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Array (new array with element added)

**Example:**
```q
let arr = [1, 2, 3]
let arr2 = arr.push(4)
puts(arr)   # [1, 2, 3]
puts(arr2)  # [1, 2, 3, 4]
```quest

### `pop()`
Returns a new array with the last element removed

**Returns:** Array (new array without last element)

**Raises:** Error if array is empty

**Example:**
```q
let arr = [1, 2, 3, 4]
let arr2 = arr.pop()
puts(arr)   # [1, 2, 3, 4]
puts(arr2)  # [1, 2, 3]
```quest

### `shift()`
Returns a new array with the first element removed

**Returns:** Array (new array without first element)

**Raises:** Error if array is empty

**Example:**
```q
let arr = [1, 2, 3, 4]
let arr2 = arr.shift()
puts(arr)   # [1, 2, 3, 4]
puts(arr2)  # [2, 3, 4]
```quest

### `unshift(value)`
Returns a new array with the value added to the beginning

**Parameters:**
- `value` - Value to add (any type)

**Returns:** Array (new array with element prepended)

**Example:**
```q
let arr = [2, 3, 4]
let arr2 = arr.unshift(1)
puts(arr)   # [2, 3, 4]
puts(arr2)  # [1, 2, 3, 4]
```quest

### `get(index)`
Returns the element at the specified index

**Parameters:**
- `index` - Zero-based index (Num)

**Returns:** Element at index

**Raises:** Error if index out of bounds

**Example:**
```q
let arr = ["a", "b", "c"]
puts(arr.get(0))  # a
puts(arr.get(1))  # b
puts(arr.get(2))  # c
```quest

### `first()`
Returns the first element of the array

**Returns:** First element

**Raises:** Error if array is empty

**Example:**
```q
let arr = [10, 20, 30]
puts(arr.first())  # 10
```quest

### `last()`
Returns the last element of the array

**Returns:** Last element

**Raises:** Error if array is empty

**Example:**
```q
let arr = [10, 20, 30]
puts(arr.last())  # 30
```quest

## Array Access with `[]`

Arrays can be accessed using bracket notation:

```q
let arr = [10, 20, 30, 40]
puts(arr[0])   # 10
puts(arr[1])   # 20
puts(arr[3])   # 40
```quest

## Immutability Pattern

Since arrays are immutable in expressions, use reassignment to "update" an array:

```q
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
```quest

## Common Patterns

### Building Arrays

```q
let arr = []
arr = arr.push(1)
arr = arr.push(2)
arr = arr.push(3)
puts(arr)  # [1, 2, 3]
```quest

### Stack Operations (LIFO)

```q
let stack = []

# Push items
stack = stack.push("first")
stack = stack.push("second")
stack = stack.push("third")

# Pop items (returns new array)
let item = stack.last()  # Get top item
stack = stack.pop()      # Remove it
puts(item)  # third
```quest

### Queue Operations (FIFO)

```q
let queue = []

# Enqueue (add to end)
queue = queue.push("first")
queue = queue.push("second")
queue = queue.push("third")

# Dequeue (remove from front)
let item = queue.first()  # Get front item
queue = queue.shift()     # Remove it
puts(item)  # first
```quest

### Checking Array Contents

```q
let arr = [1, 2, 3, 4, 5]

# Check if empty
if arr.len() == 0
    puts("Array is empty")
end

# Get first and last
if arr.len() > 0
    puts("First:", arr.first())
    puts("Last:", arr.last())
end

# Safe access
if arr.len() > 2
    puts("Third element:", arr.get(2))
end
```quest

### Array Transformation

```q
# Build a new array based on another
let numbers = [1, 2, 3, 4, 5]
let evens = []

# Filter evens (when iteration is implemented)
# for num in numbers
#     if num % 2 == 0
#         evens = evens.push(num)
#     end
# end
```quest

## Notes

- Arrays are **zero-indexed** (first element is at index 0)
- Arrays are **heterogeneous** (can contain mixed types)
- Arrays are **immutable** in expressions (methods return new arrays)
- Use reassignment (`arr = arr.push(x)`) to update array variables
- Out-of-bounds access raises an error
- Empty array operations (pop/shift/first/last on `[]`) raise errors
