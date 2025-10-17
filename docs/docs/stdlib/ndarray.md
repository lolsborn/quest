# ndarray - N-Dimensional Arrays

The `std/ndarray` module provides efficient multi-dimensional arrays for numerical computing, powered by Rust's `ndarray` crate.

## Overview

NDArrays are optimized for:
- **Numerical computing** - Fast matrix and tensor operations
- **Scientific computing** - Statistics, linear algebra, data science
- **Machine learning** - Feature matrices, neural network tensors
- **Data analysis** - Efficient aggregations and transformations

All NDArray operations use 64-bit floating point (`f64`) elements.

## Import

```quest
use "std/ndarray" as np
```

## Creation Functions

### `zeros(shape)`

Create an array filled with zeros.

**Parameters:**
- `shape` (Array): Shape as array of integers, e.g., `[2, 3]` for 2×3 matrix

**Returns:** NDArray

**Example:**
```quest
let a = np.zeros([2, 3])
# [[0.0, 0.0, 0.0],
#  [0.0, 0.0, 0.0]]
```

### `ones(shape)`

Create an array filled with ones.

**Parameters:**
- `shape` (Array): Shape as array of integers

**Returns:** NDArray

**Example:**
```quest
let a = np.ones([2, 2])
# [[1.0, 1.0],
#  [1.0, 1.0]]
```

### `full(shape, value)`

Create an array filled with a specific value.

**Parameters:**
- `shape` (Array): Shape as array of integers
- `value` (Number): Fill value

**Returns:** NDArray

**Example:**
```quest
let a = np.full([2, 3], 7.5)
# [[7.5, 7.5, 7.5],
#  [7.5, 7.5, 7.5]]
```

### `eye(n)`

Create an n×n identity matrix.

**Parameters:**
- `n` (Int): Size of the square matrix

**Returns:** NDArray (2D)

**Example:**
```quest
let identity = np.eye(3)
# [[1.0, 0.0, 0.0],
#  [0.0, 1.0, 0.0],
#  [0.0, 0.0, 1.0]]
```

### `array(nested_array)`

Create an NDArray from nested Quest arrays.

**Parameters:**
- `nested_array` (Array): Nested arrays with consistent dimensions

**Returns:** NDArray

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])
# 2D array: shape [2, 3]

let b = np.array([1, 2, 3, 4, 5])
# 1D array: shape [5]

let c = np.array([[[1, 2], [3, 4]], [[5, 6], [7, 8]]])
# 3D array: shape [2, 2, 2]
```

### `arange(start, stop, [step])`

Create a 1D array with evenly spaced values.

**Parameters:**
- `start` (Number): Start value (inclusive)
- `stop` (Number): End value (exclusive)
- `step` (Number, optional): Step size (default: 1.0)

**Returns:** NDArray (1D)

**Example:**
```quest
let a = np.arange(0, 10, 2)
# [0.0, 2.0, 4.0, 6.0, 8.0]

let b = np.arange(0, 5)
# [0.0, 1.0, 2.0, 3.0, 4.0]
```

### `linspace(start, stop, num)`

Create a 1D array with linearly spaced values.

**Parameters:**
- `start` (Number): Start value (inclusive)
- `stop` (Number): End value (inclusive)
- `num` (Int): Number of values to generate

**Returns:** NDArray (1D)

**Example:**
```quest
let a = np.linspace(0, 1, 5)
# [0.0, 0.25, 0.5, 0.75, 1.0]

let b = np.linspace(0, 10, 3)
# [0.0, 5.0, 10.0]
```

## Element-wise Operations

### `add(other)`

Element-wise addition.

**Parameters:**
- `other` (NDArray): Array with compatible shape

**Returns:** NDArray

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let b = np.array([[5, 6], [7, 8]])
let c = a.add(b)
# [[6.0, 8.0],
#  [10.0, 12.0]]
```

### `sub(other)`

Element-wise subtraction.

**Example:**
```quest
let a = np.array([10, 20, 30])
let b = np.array([1, 2, 3])
let c = a.sub(b)
# [9.0, 18.0, 27.0]
```

### `mul(other)`

Element-wise multiplication (Hadamard product).

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let b = np.array([[2, 2], [2, 2]])
let c = a.mul(b)
# [[2.0, 4.0],
#  [6.0, 8.0]]
```

### `div(other)`

Element-wise division.

**Example:**
```quest
let a = np.array([10, 20, 30])
let b = np.array([2, 4, 5])
let c = a.div(b)
# [5.0, 5.0, 6.0]
```

## Scalar Operations

### `add_scalar(value)`

Add a scalar to all elements.

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let b = a.add_scalar(10)
# [[11.0, 12.0],
#  [13.0, 14.0]]
```

### `sub_scalar(value)`

Subtract a scalar from all elements.

### `mul_scalar(value)`

Multiply all elements by a scalar.

**Example:**
```quest
let a = np.array([1, 2, 3])
let b = a.mul_scalar(2.5)
# [2.5, 5.0, 7.5]
```

### `div_scalar(value)`

Divide all elements by a scalar.

## Matrix Operations

### `dot(other)`

Matrix multiplication (dot product).

**Parameters:**
- `other` (NDArray): Compatible array for matrix multiplication

**Returns:** NDArray

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let b = np.array([[5, 6], [7, 8]])
let c = a.dot(b)
# [[19.0, 22.0],
#  [43.0, 50.0]]
```

### `transpose()`

Transpose a 2D matrix (swap rows and columns).

**Returns:** NDArray (2D)

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])
let b = a.transpose()
# [[1.0, 4.0],
#  [2.0, 5.0],
#  [3.0, 6.0]]
```

## Aggregations

All aggregation methods support optional `axis` parameter for axis-wise operations.

### `sum([axis])`

Sum of all elements or along an axis.

**Parameters:**
- `axis` (Int, optional): Axis to sum along (0=columns, 1=rows)

**Returns:** Number (no axis) or NDArray (with axis)

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])

let total = a.sum()        # 21.0 (all elements)
let col_sum = a.sum(0)     # [5.0, 7.0, 9.0] (sum columns)
let row_sum = a.sum(1)     # [6.0, 15.0] (sum rows)
```

### `mean([axis])`

Mean (average) of elements.

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])
let avg = a.mean()         # 3.5
let col_avg = a.mean(0)    # [2.5, 3.5, 4.5]
```

### `min([axis])`

Minimum value.

**Example:**
```quest
let a = np.array([[5, 2, 8], [1, 9, 3]])
let minimum = a.min()      # 1.0
let col_min = a.min(0)     # [1.0, 2.0, 3.0]
```

### `max([axis])`

Maximum value.

### `std([axis])`

Standard deviation.

**Example:**
```quest
let a = np.array([1, 2, 3, 4, 5])
let stdev = a.std()        # 1.4142135623730951
```

### `var([axis])`

Variance.

## Shape Manipulation

### `reshape(new_shape)`

Reshape array to new dimensions (total size must match).

**Parameters:**
- `new_shape` (Array): New shape as array of integers

**Returns:** NDArray

**Example:**
```quest
let a = np.arange(0, 12)          # Shape: [12]
let b = a.reshape([3, 4])         # Shape: [3, 4]
let c = a.reshape([2, 2, 3])      # Shape: [2, 2, 3]
```

### `flatten()`

Flatten to 1D array.

**Returns:** NDArray (1D)

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let b = a.flatten()
# [1.0, 2.0, 3.0, 4.0]
```

## Properties and Utilities

### `shape()`

Get array dimensions as Quest array.

**Returns:** Array of integers

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])
let s = a.shape()          # [2, 3]
```

### `ndim()`

Get number of dimensions.

**Returns:** Int

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let dims = a.ndim()        # 2
```

### `size()`

Get total number of elements.

**Returns:** Int

**Example:**
```quest
let a = np.zeros([3, 4])
let n = a.size()           # 12
```

### `get(indices)`

Get element at multi-dimensional index.

**Parameters:**
- `indices` (Array): Index for each dimension

**Returns:** Number

**Example:**
```quest
let a = np.array([[1, 2, 3], [4, 5, 6]])
let val = a.get([1, 2])    # 6.0
```

### `set(indices, value)`

Set element at multi-dimensional index.

**Parameters:**
- `indices` (Array): Index for each dimension
- `value` (Number): New value

**Example:**
```quest
let a = np.zeros([2, 2])
a.set([0, 1], 5.0)
# [[0.0, 5.0],
#  [0.0, 0.0]]
```

### `copy()`

Create a deep copy of the array.

**Returns:** NDArray

### `to_array()`

Convert NDArray to nested Quest arrays.

**Returns:** Array (nested for multi-dimensional)

**Example:**
```quest
let a = np.array([[1, 2], [3, 4]])
let arr = a.to_array()
# [[1.0, 2.0], [3.0, 4.0]] (Quest Array)
```

## Complete Example: Data Normalization

```quest
use "std/ndarray" as np

# Test scores for 3 students across 3 exams
let raw_scores = np.array([
    [85, 90, 78],
    [92, 88, 95],
    [70, 85, 82]
])

puts("Raw scores:")
puts(raw_scores.str())

# Calculate statistics
let mean_score = raw_scores.mean()
let std_score = raw_scores.std()

puts("Mean: " .. mean_score.str())
puts("Standard deviation: " .. std_score.str())

# Normalize to z-scores
let normalized = raw_scores.sub_scalar(mean_score).div_scalar(std_score)

puts("Normalized (z-scores):")
puts(normalized.str())

# Find best and worst performers
let student_avgs = raw_scores.mean(1)
let best_idx = student_avgs.max()
let worst_idx = student_avgs.min()

puts("Student averages: " .. student_avgs.to_array().str())
```

## Performance Tips

1. **Use NDArray for large datasets** - Much faster than nested Quest arrays for numerical operations
2. **Avoid repeated to_array() calls** - Expensive conversion, keep data in NDArray format
3. **Batch operations** - Use element-wise and aggregation methods instead of loops
4. **Preallocate** - Use `zeros()` or `ones()` then mutate with `set()` for building arrays

## Limitations

- **Element type**: Currently only supports `f64` (64-bit float). Integer operations are converted to float.
- **Broadcasting**: Not yet implemented (arrays must have compatible shapes)
- **Advanced indexing**: Only basic multi-dimensional indexing via `get()`/`set()`
- **Transpose**: Currently only supports 2D matrices

## See Also

- [Array Type](../types/array.md) - Quest's dynamic arrays
- [Number Types](../types/number.md) - Int and Float
- [Math Module](./math.md) - Mathematical functions
