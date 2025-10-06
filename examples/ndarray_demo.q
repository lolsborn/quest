#!/usr/bin/env quest
# NDArray Demo - NumPy-like multidimensional arrays in Quest

use "std/ndarray" as np

puts("=== Quest NDArray Demo ===\n")

# Create matrices
puts("Creating a 3x3 zero matrix:")
let zeros = np.zeros([3, 3])
puts(zeros)
puts("Shape: " .. zeros.shape()._str() .. ", Size: " .. zeros.size()._str())
puts("")

puts("Creating a 3x3 identity matrix:")
let eye = np.eye(3)
puts(eye)
puts("")

puts("Creating from nested arrays:")
let m = np.array([[1, 2, 3], [4, 5, 6]])
puts(m)
puts("Shape: " .. m.shape()._str() .. ", Dimensions: " .. m.ndim()._str())
puts("")

# Operations
puts("Transpose:")
let mt = m.transpose()
puts(mt)
puts("Transposed shape: " .. mt.shape()._str())
puts("")

puts("Matrix multiplication:")
let a = np.array([[1, 2], [3, 4]])
let b = np.array([[5, 6], [7, 8]])
let c = a.dot(b)
puts("A = " .. a._str())
puts("B = " .. b._str())
puts("A · B = " .. c._str())
puts("")

# Reshape
puts("Reshaping:")
let v = np.arange(0, 12)
puts("1D array: " .. v._str())
let reshaped = v.reshape([3, 4])
puts("Reshaped to 3x4:")
puts(reshaped)
puts("")

# Aggregations
puts("Aggregations:")
let data = np.full([3, 4], 2.0)
puts("Matrix of 2.0s:")
puts(data)
puts("Sum of all elements: " .. data.sum()._str())
puts("Mean of all elements: " .. data.mean()._str())
puts("")

# Range and linspace
puts("Creating ranges:")
let range_arr = np.arange(0, 10, 2)
puts("arange(0, 10, 2) = " .. range_arr._str())

let linear = np.linspace(0, 1, 5)
puts("linspace(0, 1, 5) = " .. linear._str())
puts("")

# 3D arrays
puts("3D tensor:")
let cube = np.zeros([2, 3, 4])
puts("Shape: " .. cube.shape()._str() .. ", Size: " .. cube.size()._str())
puts("3D array created!")
puts("")

puts("✓ NDArray module loaded and working!")
