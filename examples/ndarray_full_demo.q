#!/usr/bin/env quest
# Comprehensive NDArray Demo - All Features

use "std/ndarray" as np

puts("=== Quest NDArray - Complete Feature Demo ===\n")

# 1. Creation methods
puts("1. Array Creation:")
let zeros = np.zeros([2, 3])
let ones = np.ones([2, 3])
let full = np.full([2, 2], 7.5)
let eye = np.eye(3)
puts("  zeros(2,3), ones(2,3), full(2,2,7.5), eye(3) ✓\n")

# 2. From data
puts("2. From Nested Arrays:")
let m = np.array([[1, 2, 3], [4, 5, 6]])
puts("  " .. m._str())
puts("")

# 3. Ranges
puts("3. Range Functions:")
let range_arr = np.arange(0, 10, 2)
puts("  arange(0, 10, 2) = " .. range_arr._str())
let linear = np.linspace(0, 1, 5)
puts("  linspace(0, 1, 5) = " .. linear._str())
puts("")

# 4. Element-wise operations
puts("4. Element-wise Operations:")
let a = np.array([[1, 2], [3, 4]])
let b = np.array([[5, 6], [7, 8]])
let added = a.add(b)
let multiplied = a.mul(b)
puts("  A + B = " .. added.to_array()._str())
puts("  A * B (element-wise) = " .. multiplied.to_array()._str())
puts("")

# 5. Scalar operations
puts("5. Scalar Operations:")
let scaled = a.mul_scalar(2.5)
let shifted = a.add_scalar(10)
puts("  A * 2.5 = " .. scaled.to_array()._str())
puts("  A + 10 = " .. shifted.to_array()._str())
puts("")

# 6. Matrix operations
puts("6. Matrix Operations:")
let a_small = np.array([[1, 2], [3, 4]])
let transposed = a_small.transpose()
let matmul = a_small.dot(transposed)
puts("  A^T = " .. transposed.to_array()._str())
puts("  A · A^T = " .. matmul.to_array()._str())
puts("")

# 7. Aggregations
puts("7. Aggregations:")
let data = np.array([[1, 2, 3], [4, 5, 6]])
puts("  sum() = " .. data.sum()._str())
puts("  mean() = " .. data.mean()._str())
puts("  min() = " .. data.min()._str())
puts("  max() = " .. data.max()._str())
puts("  std() = " .. data.std()._str())
puts("  var() = " .. data.var()._str())
puts("")

# 8. Axis aggregations
puts("8. Axis-wise Operations:")
let col_sum = data.sum(0)
let row_mean = data.mean(1)
puts("  sum(axis=0) = " .. col_sum.to_array()._str())
puts("  mean(axis=1) = " .. row_mean.to_array()._str())
puts("")

# 9. Reshape and flatten
puts("9. Reshape & Flatten:")
let v = np.arange(0, 12)
let reshaped = v.reshape([3, 4])
let flattened = reshaped.flatten()
puts("  1D -> 2D -> 1D")
puts("  Original: " .. v.shape()._str())
puts("  Reshaped: " .. reshaped.shape()._str())
puts("  Flattened: " .. flattened.shape()._str())
puts("")

# 10. Conversion to arrays
puts("10. Convert to Quest Arrays:")
let small = np.array([[1, 2], [3, 4]])
let quest_array = small.to_array()
puts("  NDArray -> Array: " .. quest_array._str())
puts("  Can use normal array methods now")
puts("")

# 11. Complex example - data normalization
puts("11. Real-World Example - Data Normalization:")
let raw_data = np.array([[85, 90, 78], [92, 88, 95], [70, 85, 82]])
puts("  Raw data (test scores):")
puts("  " .. raw_data._str())

let mean_val = raw_data.mean()
let std_val = raw_data.std()
let normalized = raw_data.sub_scalar(mean_val).div_scalar(std_val)

puts("  Mean: " .. mean_val._str())
puts("  Std: " .. std_val._str())
puts("  Normalized (z-scores): computed ✓")
puts("")

puts("=== All Features Working! ===")
puts("\nAvailable operations:")
puts("  Creation: zeros, ones, full, eye, array, arange, linspace")
puts("  Element-wise: add, sub, mul, div")
puts("  Scalar: add_scalar, sub_scalar, mul_scalar, div_scalar")
puts("  Matrix: dot, transpose")
puts("  Aggregations: sum, mean, min, max, std, var (all with optional axis)")
puts("  Utilities: reshape, flatten, copy, to_array, shape, ndim, size")
