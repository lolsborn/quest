# QEP-026: Matrix/NDArray Implementation Options

**Status:** Analysis/Draft
**Created:** 2025-10-05
**Author:** Quest Language Team

## Abstract

This document analyzes options for implementing multidimensional array (matrix/ndarray) support in Quest. The documented syntax in `docs/language/types.md` shows aspirational matrix features that are not yet implemented. We compare two Rust ecosystem options: `ndarray` (general scientific computing) vs `burn` (deep learning framework).

## Current Documentation vs Reality

### What's Documented (But Not Implemented)

```quest
# 2D array literals with semicolons
arr{num} a[3,3] = [
    1, 2, 3;
    4, 5, 6;
    7, 8, 9;
]

# Matrix creation with arr.dim()
arr{num} x = arr.dim(3,3)  # 3x3 matrix
arr{num} y = arr.dim(4,2)  # 4x2 matrix

# Typed array syntax
arr{num}  # Array of numbers
```

### What Actually Exists

- Regular 1D arrays only: `[1, 2, 3]`
- Nested arrays: `[[1, 2], [3, 4]]` (but no special matrix operations)
- No `.dim()` method
- No typed array syntax `arr{num}`

## Option 1: ndarray (Recommended)

**Crate:** https://crates.io/crates/ndarray
**Docs:** https://docs.rs/ndarray/latest/ndarray
**Version:** 0.16+ (stable)

### Overview

`ndarray` is Rust's equivalent to NumPy - a mature, stable library for n-dimensional arrays and scientific computing.

### Key Features

| Feature | Description |
|---------|-------------|
| **Dimensions** | 0D to 6D static, or dynamic (unlimited) |
| **Element Types** | Generic over any type (`f64`, `i64`, custom structs) |
| **Views & Slicing** | Efficient views without copying, arbitrary strides, negative indexing |
| **Operations** | Element-wise ops, broadcasting, linear algebra, matrix multiplication |
| **Performance** | SIMD optimizations, optional BLAS integration, parallel processing (Rayon) |
| **Memory Layout** | Row-major (C) or column-major (Fortran), flexible strides |

### Core Types

```rust
// Owned arrays
Array<T, D>        // Array1<f64>, Array2<i32>, ArrayD<f64>
Array1<T>          // 1D array
Array2<T>          // 2D array (matrix)
ArrayD<T>          // Dynamic dimensionality

// Array views (borrowed)
ArrayView<T, D>    // Read-only view
ArrayViewMut<T, D> // Mutable view
```

### API Examples

```rust
use ndarray::{Array, Array2, arr2};

// Create 2D array
let a = arr2(&[[1., 2., 3.],
               [4., 5., 6.]]);

// Element-wise operations
let b = &a * 2.0;

// Matrix multiplication
let c = a.dot(&b.t());

// Slicing
let row = a.row(0);
let col = a.column(1);

// Iteration
for row in a.rows() {
    println!("{:?}", row);
}
```

### Quest Integration Design

#### Type Mapping

```rust
// In Quest's type system
pub enum QValue {
    Array(QArray),          // Existing 1D arrays
    NDArray(QNDArray),      // NEW: N-dimensional arrays
    // ... other types
}

pub struct QNDArray {
    pub data: ArrayD<QValue>,  // Dynamic dimensionality
    pub id: u64,
}
```

#### Quest Syntax

```quest
use "std/ndarray"

# Create matrices
let m = ndarray.zeros([3, 3])           # 3x3 zeros
let m = ndarray.ones([2, 4])            # 2x4 ones
let m = ndarray.array([[1, 2], [3, 4]]) # From nested arrays
let m = ndarray.range(0, 10).reshape([2, 5])

# Operations
let m2 = m.transpose()
let m3 = m.dot(m2)        # Matrix multiplication
let m4 = m + 5            # Broadcasting
let m5 = m * m2           # Element-wise

# Slicing
let row = m.row(0)
let col = m.column(1)
let sub = m.slice([0..2, 1..3])  # 2x2 submatrix

# Properties
puts(m.shape())           # [3, 3]
puts(m.ndim())            # 2
puts(m.size())            # 9

# Element access
let val = m[[0, 1]]       # Access element at (0, 1)
m[[0, 1]] = 42            # Set element
```

### Dependencies

**Core (required):**
- `ndarray = "0.16"`
- `num-traits = "0.2"` (already in Quest via num-bigint)

**Optional features:**
```toml
[dependencies]
ndarray = { version = "0.16", features = ["rayon"] }  # Parallel
# OR
ndarray = { version = "0.16", features = ["blas"] }   # BLAS acceleration
```

### Pros

✅ **Mature & Stable** - Battle-tested, widely used
✅ **Lightweight** - ~100KB compiled, minimal dependencies
✅ **NumPy-like API** - Familiar to data scientists
✅ **Flexible** - Works for matrices, tensors, general arrays
✅ **Well-documented** - Excellent docs and examples
✅ **Optional Performance** - Can add BLAS/parallel when needed
✅ **Pure Rust** - No C dependencies in core
✅ **Minimal MSRV** - Rust 1.64+

### Cons

⚠️ **Generic Types** - Need to decide how Quest values map to ndarray elements
⚠️ **Limited GPU** - No native GPU support (CPU-focused)
⚠️ **Manual Broadcasting** - Not as automatic as NumPy

### Use Cases

- Scientific computing scripts
- Data processing pipelines
- Image manipulation
- Linear algebra
- Signal processing
- Statistics/analytics

---

## Option 2: Burn

**Repo:** https://github.com/tracel-ai/burn
**Docs:** https://burn.dev

### Overview

Burn is a modern deep learning framework for Rust, designed for neural networks and GPU-accelerated tensor operations.

### Key Features

| Feature | Description |
|---------|-------------|
| **Tensors** | N-dimensional tensors with autodifferentiation |
| **Backends** | CUDA, ROCm, Metal, Vulkan, WebGPU, CPU, WASM |
| **Autodiff** | Automatic differentiation for gradients |
| **Neural Nets** | Pre-built layers, optimizers, loss functions |
| **Model Import** | ONNX, PyTorch, Safetensors |
| **Portability** | Train on GPU, deploy anywhere (even WASM) |

### API Examples

```rust
use burn::tensor::{Tensor, backend::Backend};

// Create tensor
let tensor = Tensor::<Backend, 2>::zeros([3, 3]);

// Operations
let result = tensor.matmul(tensor.transpose());

// Deep learning specific
let output = tensor.relu().softmax(1);
```

### Quest Integration Complexity

Would require:
1. Backend selection/configuration
2. Type conversions for autodiff
3. Managing GPU memory
4. Complex error handling for device failures

### Dependencies

**Heavy stack:**
- `burn` core
- `burn-tensor`
- Backend crate (`burn-cuda`, `burn-wgpu`, etc.)
- Multiple transitive dependencies
- Total: 50+ dependencies

### Pros

✅ **GPU Acceleration** - Native GPU support
✅ **Deep Learning** - Built for neural networks
✅ **Modern API** - Clean Rust design
✅ **Multi-backend** - Works on various hardware

### Cons

❌ **Massive Overkill** - 99% of features unused for general scripting
❌ **Heavy Dependencies** - Large compile times, binary size
❌ **Complex Setup** - GPU drivers, backend selection
❌ **Active Development** - Breaking changes, unstable API
❌ **Deep Learning Focus** - Not designed for general arrays
❌ **Steep Learning Curve** - Requires understanding of backends
❌ **Compilation Time** - Significantly slower builds

### Use Cases (for Quest)

- Machine learning models
- GPU-accelerated numerical computing
- Neural network scripting

**Reality:** Quest is a scripting language. Users won't be training neural networks - they need general array operations.

---

## Comparison Matrix

| Criteria | ndarray | burn | Winner |
|----------|---------|------|--------|
| **Maturity** | Stable, v0.16+ | Beta, breaking changes | ⭐ ndarray |
| **Complexity** | Simple, focused | Complex, many features | ⭐ ndarray |
| **Dependencies** | Minimal (~5 crates) | Heavy (50+ crates) | ⭐ ndarray |
| **Compile Time** | Fast | Slow | ⭐ ndarray |
| **Binary Size** | ~100KB | Several MB | ⭐ ndarray |
| **API Familiarity** | NumPy-like | PyTorch-like | ⭐ ndarray |
| **Use Case Fit** | General arrays/matrices | Deep learning | ⭐ ndarray |
| **GPU Support** | No (CPU only) | Yes (multi-backend) | burn |
| **Documentation** | Excellent | Good but changing | ⭐ ndarray |
| **Learning Curve** | Gentle | Steep | ⭐ ndarray |

## Recommendation: Use `ndarray`

### Rationale

1. **Quest is a Scripting Language** - Users need general array/matrix operations, not deep learning frameworks
2. **Simplicity Matters** - ndarray is focused, stable, and easy to integrate
3. **NumPy Familiarity** - Python users expect NumPy-like arrays, not PyTorch tensors
4. **Performance is Adequate** - Optional BLAS gives 95% of GPU speed for common operations
5. **Dependency Hygiene** - Keep Quest's dependencies lean
6. **Maintenance Burden** - ndarray is stable; burn is changing rapidly

### When to Reconsider Burn

- If Quest adds first-class GPU support
- If users demand neural network primitives
- If autodiff becomes a core language feature
- If Quest targets WASM with GPU compute

For now, these are not Quest's goals.

## Implementation Plan

### Phase 1: Core Integration

1. Add `ndarray` dependency to `Cargo.toml`
2. Create `src/types/ndarray.rs` with `QNDArray` type
3. Implement basic construction: `zeros`, `ones`, `array`, `range`
4. Support element access: `arr[[i, j]]`
5. Add `_str()`, `_rep()` for REPL display

### Phase 2: Operations

1. Element-wise arithmetic: `+`, `-`, `*`, `/`
2. Matrix operations: `dot`, `transpose`, `reshape`
3. Slicing: `row`, `column`, `slice`
4. Aggregations: `sum`, `mean`, `max`, `min`

### Phase 3: Advanced Features

1. Broadcasting
2. Linear algebra: `inv`, `det`, `eig`, `svd`
3. Optional BLAS integration (feature flag)
4. Optional parallel processing (Rayon feature flag)

### Phase 4: Sugar Syntax

Implement the documented syntax:

```quest
# Matrix literals (needs parser changes)
let m = [[1, 2, 3], [4, 5, 6]].to_ndarray()

# Shape annotation (future type system enhancement)
arr{num}[3,3] m = ndarray.zeros([3, 3])
```

## Alternative: Hybrid Approach

**What if users need GPU?**

Start with `ndarray` core, provide `burn` as optional module:

```quest
use "std/ndarray"     # CPU-based arrays (always available)
use "std/ml"          # GPU tensors via burn (opt-in)

# Regular matrices (fast, simple)
let m = ndarray.zeros([1000, 1000])

# GPU tensors (for ML)
let t = ml.tensor([1000, 1000], device: "cuda")
```

This gives users choice without forcing complexity.

## Conclusion

**Use `ndarray` for Quest's matrix/ndarray implementation.**

- ✅ Right tool for the job
- ✅ Keeps Quest lean and fast
- ✅ Familiar API for Python users
- ✅ Stable, maintained, documented
- ✅ Sufficient performance for scripting

Reserve `burn` for a future GPU/ML extension if there's demand.

## Next Steps

1. Review and approve this analysis
2. Draft QEP-026 with detailed ndarray API design
3. Implement Phase 1 (core integration)
4. Write comprehensive tests
5. Update documentation with real examples
6. Consider performance benchmarks vs Python NumPy

## References

- ndarray docs: https://docs.rs/ndarray/latest/ndarray
- ndarray repo: https://github.com/rust-ndarray/ndarray
- NumPy for Rust users: https://github.com/rust-ndarray/ndarray/blob/master/README-quick-start.md
- burn repo: https://github.com/tracel-ai/burn
- burn docs: https://burn.dev
