use crate::types::*;
use crate::control_flow::EvalError;
use crate::{arg_err, attr_err, value_err};
use ndarray::{ArrayD, IxDyn};
use std::collections::HashMap;

pub fn create_ndarray_module() -> QValue {
    let mut members = HashMap::new();

    // Construction functions
    members.insert("zeros".to_string(), create_fn("ndarray", "zeros"));
    members.insert("ones".to_string(), create_fn("ndarray", "ones"));
    members.insert("full".to_string(), create_fn("ndarray", "full"));
    members.insert("eye".to_string(), create_fn("ndarray", "eye"));
    members.insert("array".to_string(), create_fn("ndarray", "array"));
    members.insert("arange".to_string(), create_fn("ndarray", "arange"));
    members.insert("linspace".to_string(), create_fn("ndarray", "linspace"));

    QValue::Module(Box::new(QModule::new("ndarray".to_string(), members)))
}

pub fn call_ndarray_function(name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
    match name {
        "ndarray.zeros" => {
            // zeros([3, 3]) - create array filled with zeros
            if args.len() != 1 {
                return arg_err!("zeros expects 1 argument (shape array), got {}", args.len());
            }

            let shape = parse_shape(&args[0])?;
            let arr = QNDArray::zeros(shape);
            Ok(QValue::NDArray(arr))
        }

        "ndarray.ones" => {
            // ones([2, 4]) - create array filled with ones
            if args.len() != 1 {
                return arg_err!("ones expects 1 argument (shape array), got {}", args.len());
            }

            let shape = parse_shape(&args[0])?;
            let arr = QNDArray::ones(shape);
            Ok(QValue::NDArray(arr))
        }

        "ndarray.full" => {
            // full([2, 3], 5.0) - create array filled with value
            if args.len() != 2 {
                return arg_err!("full expects 2 arguments (shape, value), got {}", args.len());
            }

            let shape = parse_shape(&args[0])?;
            let value = args[1].as_num()?;
            let arr = QNDArray::full(shape, value);
            Ok(QValue::NDArray(arr))
        }

        "ndarray.eye" => {
            // eye(3) - create identity matrix
            if args.len() != 1 {
                return arg_err!("eye expects 1 argument (size), got {}", args.len());
            }

            let n = args[0].as_num()? as usize;
            let arr = QNDArray::eye(n)?;
            Ok(QValue::NDArray(arr))
        }

        "ndarray.array" => {
            // array([[1, 2], [3, 4]]) - create from nested arrays
            if args.len() != 1 {
                return arg_err!("array expects 1 argument (nested array), got {}", args.len());
            }

            match &args[0] {
                QValue::Array(arr) => {
                    let data = nested_array_to_ndarray(arr)?;
                    Ok(QValue::NDArray(QNDArray::new(data)))
                }
                _ => Err("array expects an Array argument".into()),
            }
        }

        "ndarray.arange" => {
            // arange(0, 10) or arange(0, 10, 2) - create range array
            if args.len() < 2 || args.len() > 3 {
                return arg_err!("arange expects 2-3 arguments (start, stop, [step]), got {}", args.len());
            }

            let start = args[0].as_num()?;
            let stop = args[1].as_num()?;
            let step = if args.len() == 3 {
                args[2].as_num()?
            } else {
                1.0
            };

            if step == 0.0 {
                return Err("arange step cannot be zero".into());
            }

            let mut values = Vec::new();
            let mut current = start;

            if step > 0.0 {
                while current < stop {
                    values.push(current);
                    current += step;
                }
            } else {
                while current > stop {
                    values.push(current);
                    current += step;
                }
            }

            let data = ArrayD::from_shape_vec(IxDyn(&[values.len()]), values)
                .map_err(|e| format!("Failed to create array: {}", e))?;

            Ok(QValue::NDArray(QNDArray::new(data)))
        }

        "ndarray.linspace" => {
            // linspace(0, 10, 50) - create evenly spaced array
            if args.len() != 3 {
                return arg_err!("linspace expects 3 arguments (start, stop, num), got {}", args.len());
            }

            let start = args[0].as_num()?;
            let stop = args[1].as_num()?;
            let num = args[2].as_num()? as usize;

            if num == 0 {
                return Err("linspace num must be > 0".into());
            }

            let mut values = Vec::with_capacity(num);
            if num == 1 {
                values.push(start);
            } else {
                let step = (stop - start) / (num - 1) as f64;
                for i in 0..num {
                    values.push(start + step * i as f64);
                }
            }

            let data = ArrayD::from_shape_vec(IxDyn(&[num]), values)
                .map_err(|e| format!("Failed to create array: {}", e))?;

            Ok(QValue::NDArray(QNDArray::new(data)))
        }

        _ => attr_err!("Unknown ndarray function: {}", name),
    }
}

/// Parse shape from QValue (expects Array of integers)
fn parse_shape(value: &QValue) -> Result<Vec<usize>, String> {
    match value {
        QValue::Array(arr) => {
            arr.elements
                .borrow()
                .iter()
                .map(|v| match v {
                    QValue::Int(i) => {
                        if i.value < 0 {
                            value_err!("Shape dimensions must be non-negative, got {}", i.value)
                        } else {
                            Ok(i.value as usize)
                        }
                    }
                    _ => Err("Shape must contain integers".into()),
                })
                .collect()
        }
        _ => Err("Shape must be an Array".into()),
    }
}

/// Convert nested Quest arrays to ndarray
fn nested_array_to_ndarray(arr: &QArray) -> Result<ArrayD<f64>, String> {
    // Determine shape and flatten data
    let elements = arr.elements.borrow();

    if elements.is_empty() {
        return Err("Cannot create ndarray from empty array".into());
    }

    // Check if this is a 1D array of numbers
    if let QValue::Int(_) | QValue::Float(_) = &elements[0] {
        // 1D array
        let values: Result<Vec<f64>, String> = elements
            .iter()
            .map(|v| v.as_num())
            .collect();

        let values = values?;
        let shape = vec![values.len()];

        return ArrayD::from_shape_vec(IxDyn(&shape), values)
            .map_err(|e| format!("Failed to create array: {}", e));
    }

    // Check if nested arrays (2D+)
    if let QValue::Array(_) = &elements[0] {
        // Multi-dimensional array
        let (shape, flat_values) = flatten_nested_array(arr)?;

        return ArrayD::from_shape_vec(IxDyn(&shape), flat_values)
            .map_err(|e| format!("Failed to create array: {}", e));
    }

    Err("Array must contain numbers or nested arrays".into())
}

/// Flatten nested arrays and determine shape
fn flatten_nested_array(arr: &QArray) -> Result<(Vec<usize>, Vec<f64>), String> {
    // First, determine the shape by traversing the structure
    let shape = determine_shape(arr)?;

    // Then flatten the data
    let mut flat_values = Vec::new();
    flatten_recursive(arr, &shape, &mut flat_values, 0)?;

    Ok((shape, flat_values))
}

/// Determine the shape of a nested array structure
fn determine_shape(arr: &QArray) -> Result<Vec<usize>, String> {
    let elements = arr.elements.borrow();

    if elements.is_empty() {
        return Err("Cannot create ndarray from empty array".into());
    }

    let mut shape = vec![elements.len()];

    // Check first element to determine deeper dimensions
    match &elements[0] {
        QValue::Array(nested) => {
            // Recursively determine shape of nested structure
            let nested_shape = determine_shape(nested)?;
            shape.extend(nested_shape);
        }
        QValue::Int(_) | QValue::Float(_) => {
            // Leaf level reached
        }
        _ => return Err("Nested arrays must contain numbers or arrays".into()),
    }

    Ok(shape)
}

fn flatten_recursive(
    arr: &QArray,
    expected_shape: &[usize],
    output: &mut Vec<f64>,
    depth: usize,
) -> Result<(), String> {
    let elements = arr.elements.borrow();

    if elements.len() != expected_shape[depth] {
        return value_err!(
            "Inconsistent array shape at depth {}: expected {}, got {}",
            depth,
            expected_shape[depth],
            elements.len()
        );
    }

    if depth == expected_shape.len() - 1 {
        // Leaf level - extract numbers
        for elem in elements.iter() {
            output.push(elem.as_num()?);
        }
    } else {
        // Recurse into nested arrays
        for elem in elements.iter() {
            match elem {
                QValue::Array(nested) => {
                    flatten_recursive(nested, expected_shape, output, depth + 1)?;
                }
                _ => return value_err!("Expected nested array at depth {}", depth),
            }
        }
    }

    Ok(())
}
