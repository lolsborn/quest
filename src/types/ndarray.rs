use super::*;
use ::ndarray::{ArrayD, IxDyn, Axis, Array2, Ix2};

/// QNDArray - N-dimensional array for numerical computing
/// Wraps ndarray::ArrayD for efficient matrix/tensor operations
#[derive(Debug, Clone)]
pub struct QNDArray {
    pub data: ArrayD<f64>,  // Dynamic dimensions, f64 elements for now
    pub id: u64,
}

impl QNDArray {
    /// Create new NDArray from ArrayD
    pub fn new(data: ArrayD<f64>) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("NDArray", id);
        QNDArray { data, id }
    }

    /// Create from shape with zeros
    pub fn zeros(shape: Vec<usize>) -> Self {
        let data = ArrayD::zeros(IxDyn(&shape));
        Self::new(data)
    }

    /// Create from shape with ones
    pub fn ones(shape: Vec<usize>) -> Self {
        let data = ArrayD::ones(IxDyn(&shape));
        Self::new(data)
    }

    /// Create from shape filled with value
    pub fn full(shape: Vec<usize>, value: f64) -> Self {
        let data = ArrayD::from_elem(IxDyn(&shape), value);
        Self::new(data)
    }

    /// Create identity matrix (2D only)
    pub fn eye(n: usize) -> Result<Self, String> {
        let mut matrix = Array2::zeros((n, n));
        for i in 0..n {
            matrix[[i, i]] = 1.0;
        }
        // Convert Array2 to ArrayD
        let data = matrix.into_dyn();
        Ok(Self::new(data))
    }

    /// Get shape as vector
    pub fn shape(&self) -> Vec<usize> {
        self.data.shape().to_vec()
    }

    /// Get number of dimensions
    pub fn ndim(&self) -> usize {
        self.data.ndim()
    }

    /// Get total number of elements
    pub fn size(&self) -> usize {
        self.data.len()
    }

    /// Get element at index (multidimensional)
    pub fn get(&self, indices: &[usize]) -> Result<f64, String> {
        if indices.len() != self.ndim() {
            return Err(format!(
                "Expected {} indices, got {}",
                self.ndim(),
                indices.len()
            ));
        }

        self.data
            .get(IxDyn(indices))
            .copied()
            .ok_or_else(|| format!("Index {:?} out of bounds for shape {:?}", indices, self.shape()))
    }

    /// Set element at index
    pub fn set(&mut self, indices: &[usize], value: f64) -> Result<(), String> {
        if indices.len() != self.ndim() {
            return Err(format!(
                "Expected {} indices, got {}",
                self.ndim(),
                indices.len()
            ));
        }

        self.data
            .get_mut(IxDyn(indices))
            .map(|elem| *elem = value)
            .ok_or_else(|| format!("Index {:?} out of bounds for shape {:?}", indices, self.shape()))
    }

    /// Transpose (2D only for now)
    pub fn transpose(&self) -> Result<Self, String> {
        if self.ndim() != 2 {
            return Err(format!("transpose requires 2D array, got {}D", self.ndim()));
        }
        let transposed = self.data.t().to_owned();
        Ok(Self::new(transposed))
    }

    /// Reshape to new shape
    pub fn reshape(&self, new_shape: Vec<usize>) -> Result<Self, String> {
        let new_size: usize = new_shape.iter().product();
        if new_size != self.size() {
            return Err(format!(
                "Cannot reshape array of size {} into shape {:?} (size {})",
                self.size(),
                new_shape,
                new_size
            ));
        }

        // Use to_shape() which handles non-contiguous arrays by copying if needed
        let reshaped = self
            .data
            .to_shape(IxDyn(&new_shape))
            .map_err(|e| format!("Reshape error: {}", e))?
            .to_owned();

        Ok(Self::new(reshaped))
    }

    /// Matrix multiplication (2D only)
    pub fn dot(&self, other: &QNDArray) -> Result<Self, String> {
        if self.ndim() != 2 || other.ndim() != 2 {
            return Err("dot requires 2D arrays".to_string());
        }

        let shape_a = self.shape();
        let shape_b = other.shape();

        if shape_a[1] != shape_b[0] {
            return Err(format!(
                "Matrix dimensions incompatible for multiplication: {:?} and {:?}",
                shape_a, shape_b
            ));
        }

        // Convert to Array2 for matrix multiplication
        let a = self
            .data
            .view()
            .into_dimensionality::<Ix2>()
            .map_err(|e| format!("Failed to convert to 2D: {}", e))?;

        let b = other
            .data
            .view()
            .into_dimensionality::<Ix2>()
            .map_err(|e| format!("Failed to convert to 2D: {}", e))?;

        let result = a.dot(&b);
        Ok(Self::new(result.into_dyn()))
    }

    /// Sum along axis (or all elements if axis is None)
    pub fn sum(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                // Sum all elements
                let sum: f64 = self.data.iter().sum();
                Ok(QValue::Float(QFloat::new(sum)))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                let result = self.data.sum_axis(Axis(ax));
                Ok(QValue::NDArray(Self::new(result)))
            }
        }
    }

    /// Mean along axis (or all elements if axis is None)
    pub fn mean(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                // Mean of all elements
                let sum: f64 = self.data.iter().sum();
                let mean = sum / self.size() as f64;
                Ok(QValue::Float(QFloat::new(mean)))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                let result = self.data.mean_axis(Axis(ax)).ok_or("Mean calculation failed")?;
                Ok(QValue::NDArray(Self::new(result)))
            }
        }
    }

    /// Min along axis (or all elements if axis is None)
    pub fn min(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                let min = self.data.iter().cloned().fold(f64::INFINITY, f64::min);
                Ok(QValue::Float(QFloat::new(min)))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                let result = self.data.map_axis(Axis(ax), |view| {
                    view.iter().cloned().fold(f64::INFINITY, f64::min)
                });
                Ok(QValue::NDArray(Self::new(result)))
            }
        }
    }

    /// Max along axis (or all elements if axis is None)
    pub fn max(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                let max = self.data.iter().cloned().fold(f64::NEG_INFINITY, f64::max);
                Ok(QValue::Float(QFloat::new(max)))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                let result = self.data.map_axis(Axis(ax), |view| {
                    view.iter().cloned().fold(f64::NEG_INFINITY, f64::max)
                });
                Ok(QValue::NDArray(Self::new(result)))
            }
        }
    }

    /// Standard deviation
    pub fn std(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                let mean_val = match self.mean(None)? {
                    QValue::Float(f) => f.value,
                    _ => return Err("Mean calculation failed".to_string()),
                };
                let variance: f64 = self.data.iter()
                    .map(|&x| (x - mean_val).powi(2))
                    .sum::<f64>() / self.size() as f64;
                Ok(QValue::Float(QFloat::new(variance.sqrt())))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                // Calculate std along axis
                let variance = self.data.map_axis(Axis(ax), |view| {
                    let mean = view.mean().unwrap_or(0.0);
                    view.iter().map(|&x| (x - mean).powi(2)).sum::<f64>() / view.len() as f64
                });
                let std = variance.mapv(|v| v.sqrt());
                Ok(QValue::NDArray(Self::new(std)))
            }
        }
    }

    /// Variance
    pub fn var(&self, axis: Option<usize>) -> Result<QValue, String> {
        match axis {
            None => {
                let mean_val = match self.mean(None)? {
                    QValue::Float(f) => f.value,
                    _ => return Err("Mean calculation failed".to_string()),
                };
                let variance: f64 = self.data.iter()
                    .map(|&x| (x - mean_val).powi(2))
                    .sum::<f64>() / self.size() as f64;
                Ok(QValue::Float(QFloat::new(variance)))
            }
            Some(ax) => {
                if ax >= self.ndim() {
                    return Err(format!("Axis {} out of bounds for {}D array", ax, self.ndim()));
                }
                let variance = self.data.map_axis(Axis(ax), |view| {
                    let mean = view.mean().unwrap_or(0.0);
                    view.iter().map(|&x| (x - mean).powi(2)).sum::<f64>() / view.len() as f64
                });
                Ok(QValue::NDArray(Self::new(variance)))
            }
        }
    }

    /// Element-wise addition
    pub fn add(&self, other: &QNDArray) -> Result<Self, String> {
        if self.shape() != other.shape() {
            return Err(format!(
                "Shape mismatch for addition: {:?} vs {:?}",
                self.shape(),
                other.shape()
            ));
        }
        let result = &self.data + &other.data;
        Ok(Self::new(result))
    }

    /// Element-wise subtraction
    pub fn sub(&self, other: &QNDArray) -> Result<Self, String> {
        if self.shape() != other.shape() {
            return Err(format!(
                "Shape mismatch for subtraction: {:?} vs {:?}",
                self.shape(),
                other.shape()
            ));
        }
        let result = &self.data - &other.data;
        Ok(Self::new(result))
    }

    /// Element-wise multiplication (Hadamard product)
    pub fn mul(&self, other: &QNDArray) -> Result<Self, String> {
        if self.shape() != other.shape() {
            return Err(format!(
                "Shape mismatch for multiplication: {:?} vs {:?}",
                self.shape(),
                other.shape()
            ));
        }
        let result = &self.data * &other.data;
        Ok(Self::new(result))
    }

    /// Element-wise division
    pub fn div(&self, other: &QNDArray) -> Result<Self, String> {
        if self.shape() != other.shape() {
            return Err(format!(
                "Shape mismatch for division: {:?} vs {:?}",
                self.shape(),
                other.shape()
            ));
        }
        let result = &self.data / &other.data;
        Ok(Self::new(result))
    }

    /// Scalar addition
    pub fn add_scalar(&self, value: f64) -> Self {
        let result = &self.data + value;
        Self::new(result)
    }

    /// Scalar subtraction
    pub fn sub_scalar(&self, value: f64) -> Self {
        let result = &self.data - value;
        Self::new(result)
    }

    /// Scalar multiplication
    pub fn mul_scalar(&self, value: f64) -> Self {
        let result = &self.data * value;
        Self::new(result)
    }

    /// Scalar division
    pub fn div_scalar(&self, value: f64) -> Self {
        let result = &self.data / value;
        Self::new(result)
    }

    /// Flatten to 1D array
    pub fn flatten(&self) -> Self {
        let flat = self.data.to_shape(IxDyn(&[self.size()])).unwrap().to_owned();
        Self::new(flat)
    }

    /// Explicit copy
    pub fn copy(&self) -> Self {
        Self::new(self.data.clone())
    }

    /// Convert to nested Quest arrays
    pub fn to_array(&self) -> QValue {
        fn recursive_to_array(data: &ArrayD<f64>, indices: &mut Vec<usize>, depth: usize) -> QValue {
            if depth == data.ndim() {
                // Leaf: return scalar
                let val = data[IxDyn(indices)];
                return QValue::Float(QFloat::new(val));
            }

            let size = data.shape()[depth];
            let mut result = Vec::new();

            for i in 0..size {
                indices.push(i);
                result.push(recursive_to_array(data, indices, depth + 1));
                indices.pop();
            }

            QValue::Array(QArray::new(result))
        }

        let mut indices = Vec::new();
        recursive_to_array(&self.data, &mut indices, 0)
    }

    /// Call method on NDArray
    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        match method_name {
            "shape" => {
                if !args.is_empty() {
                    return Err(format!("shape expects 0 arguments, got {}", args.len()));
                }
                let shape_arr: Vec<QValue> = self
                    .shape()
                    .iter()
                    .map(|&s| QValue::Int(QInt::new(s as i64)))
                    .collect();
                Ok(QValue::Array(QArray::new(shape_arr)))
            }
            "ndim" => {
                if !args.is_empty() {
                    return Err(format!("ndim expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.ndim() as i64)))
            }
            "size" => {
                if !args.is_empty() {
                    return Err(format!("size expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.size() as i64)))
            }
            "transpose" | "T" => {
                if !args.is_empty() {
                    return Err(format!("transpose expects 0 arguments, got {}", args.len()));
                }
                let result = self.transpose()?;
                Ok(QValue::NDArray(result))
            }
            "reshape" => {
                if args.len() != 1 {
                    return Err(format!("reshape expects 1 argument (shape array), got {}", args.len()));
                }
                let shape = match &args[0] {
                    QValue::Array(arr) => {
                        arr.elements.borrow().iter().map(|v| {
                            match v {
                                QValue::Int(i) => Ok(i.value as usize),
                                _ => Err("reshape shape must contain integers".to_string()),
                            }
                        }).collect::<Result<Vec<_>, _>>()?
                    }
                    _ => return Err("reshape expects array argument".to_string()),
                };
                let result = self.reshape(shape)?;
                Ok(QValue::NDArray(result))
            }
            "dot" => {
                if args.len() != 1 {
                    return Err(format!("dot expects 1 argument, got {}", args.len()));
                }
                let other = match &args[0] {
                    QValue::NDArray(arr) => arr,
                    _ => return Err("dot expects NDArray argument".to_string()),
                };
                let result = self.dot(other)?;
                Ok(QValue::NDArray(result))
            }
            "sum" => {
                let axis = if args.is_empty() {
                    None
                } else if args.len() == 1 {
                    Some(match &args[0] {
                        QValue::Int(i) => i.value as usize,
                        QValue::Nil(_) => return self.sum(None),
                        _ => return Err("sum axis must be integer or nil".to_string()),
                    })
                } else {
                    return Err(format!("sum expects 0 or 1 arguments, got {}", args.len()));
                };
                self.sum(axis)
            }
            "mean" => {
                let axis = if args.is_empty() {
                    None
                } else if args.len() == 1 {
                    Some(match &args[0] {
                        QValue::Int(i) => i.value as usize,
                        QValue::Nil(_) => return self.mean(None),
                        _ => return Err("mean axis must be integer or nil".to_string()),
                    })
                } else {
                    return Err(format!("mean expects 0 or 1 arguments, got {}", args.len()));
                };
                self.mean(axis)
            }
            "min" => {
                let axis = parse_optional_axis(&args)?;
                self.min(axis)
            }
            "max" => {
                let axis = parse_optional_axis(&args)?;
                self.max(axis)
            }
            "std" => {
                let axis = parse_optional_axis(&args)?;
                self.std(axis)
            }
            "var" => {
                let axis = parse_optional_axis(&args)?;
                self.var(axis)
            }
            "add" => {
                if args.len() != 1 {
                    return Err(format!("add expects 1 argument, got {}", args.len()));
                }
                let other = match &args[0] {
                    QValue::NDArray(arr) => arr,
                    _ => return Err("add expects NDArray argument".to_string()),
                };
                let result = self.add(other)?;
                Ok(QValue::NDArray(result))
            }
            "sub" => {
                if args.len() != 1 {
                    return Err(format!("sub expects 1 argument, got {}", args.len()));
                }
                let other = match &args[0] {
                    QValue::NDArray(arr) => arr,
                    _ => return Err("sub expects NDArray argument".to_string()),
                };
                let result = self.sub(other)?;
                Ok(QValue::NDArray(result))
            }
            "mul" => {
                if args.len() != 1 {
                    return Err(format!("mul expects 1 argument, got {}", args.len()));
                }
                let other = match &args[0] {
                    QValue::NDArray(arr) => arr,
                    _ => return Err("mul expects NDArray argument".to_string()),
                };
                let result = self.mul(other)?;
                Ok(QValue::NDArray(result))
            }
            "div" => {
                if args.len() != 1 {
                    return Err(format!("div expects 1 argument, got {}", args.len()));
                }
                let other = match &args[0] {
                    QValue::NDArray(arr) => arr,
                    _ => return Err("div expects NDArray argument".to_string()),
                };
                let result = self.div(other)?;
                Ok(QValue::NDArray(result))
            }
            "add_scalar" => {
                if args.len() != 1 {
                    return Err(format!("add_scalar expects 1 argument, got {}", args.len()));
                }
                let value = args[0].as_num()?;
                Ok(QValue::NDArray(self.add_scalar(value)))
            }
            "sub_scalar" => {
                if args.len() != 1 {
                    return Err(format!("sub_scalar expects 1 argument, got {}", args.len()));
                }
                let value = args[0].as_num()?;
                Ok(QValue::NDArray(self.sub_scalar(value)))
            }
            "mul_scalar" => {
                if args.len() != 1 {
                    return Err(format!("mul_scalar expects 1 argument, got {}", args.len()));
                }
                let value = args[0].as_num()?;
                Ok(QValue::NDArray(self.mul_scalar(value)))
            }
            "div_scalar" => {
                if args.len() != 1 {
                    return Err(format!("div_scalar expects 1 argument, got {}", args.len()));
                }
                let value = args[0].as_num()?;
                Ok(QValue::NDArray(self.div_scalar(value)))
            }
            "flatten" => {
                if !args.is_empty() {
                    return Err(format!("flatten expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::NDArray(self.flatten()))
            }
            "copy" => {
                if !args.is_empty() {
                    return Err(format!("copy expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::NDArray(self.copy()))
            }
            "to_array" => {
                if !args.is_empty() {
                    return Err(format!("to_array expects 0 arguments, got {}", args.len()));
                }
                Ok(self.to_array())
            }
            "get" => {
                // get([i, j]) - access element at indices
                if args.len() != 1 {
                    return Err(format!("get expects 1 argument (indices array), got {}", args.len()));
                }
                let indices = match &args[0] {
                    QValue::Array(arr) => {
                        arr.elements
                            .borrow()
                            .iter()
                            .map(|v| match v {
                                QValue::Int(i) => Ok(i.value as usize),
                                _ => Err("get indices must be integers".to_string()),
                            })
                            .collect::<Result<Vec<_>, _>>()?
                    }
                    _ => return Err("get expects array of indices".to_string()),
                };
                let value = self.get(&indices)?;
                Ok(QValue::Float(QFloat::new(value)))
            }
            _ => Err(format!("Unknown method '{}' for NDArray type", method_name)),
        }
    }
}

/// Helper to parse optional axis argument
fn parse_optional_axis(args: &[QValue]) -> Result<Option<usize>, String> {
    if args.is_empty() {
        Ok(None)
    } else if args.len() == 1 {
        match &args[0] {
            QValue::Int(i) => Ok(Some(i.value as usize)),
            QValue::Nil(_) => Ok(None),
            _ => Err("axis must be integer or nil".to_string()),
        }
    } else {
        Err(format!("expects 0 or 1 arguments, got {}", args.len()))
    }
}

impl QObj for QNDArray {
    fn cls(&self) -> String {
        "NDArray".to_string()
    }

    fn q_type(&self) -> &'static str {
        "ndarray"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "ndarray" || type_name == "obj"
    }

    fn _str(&self) -> String {
        // Format as nested arrays
        format!("{:?}", self.data)
    }

    fn _rep(&self) -> String {
        format!("ndarray{:?}", self.data)
    }

    fn _doc(&self) -> String {
        format!(
            "NDArray with shape {:?}, {} dimensions, {} total elements",
            self.shape(),
            self.ndim(),
            self.size()
        )
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QNDArray {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("NDArray", self.id);
    }
}
