use super::*;
use std::cell::RefCell;
use std::rc::Rc;
use crate::{arg_err, attr_err, index_err};

#[derive(Debug, Clone)]
pub struct QArray {
    pub elements: Rc<RefCell<Vec<QValue>>>,
    pub id: u64,
}

impl QArray {
    pub fn new(elements: Vec<QValue>) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Array", id);
        QArray {
            elements: Rc::new(RefCell::new(elements)),
            id,
        }
    }

    /// Create array with pre-allocated capacity (QEP-042 #6)
    pub fn new_with_capacity(capacity: usize) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Array", id);
        QArray {
            elements: Rc::new(RefCell::new(Vec::with_capacity(capacity))),
            id,
        }
    }

    pub fn len(&self) -> usize {
        self.elements.borrow().len()
    }

    pub fn capacity(&self) -> usize {
        self.elements.borrow().capacity()
    }

    /// Push with aggressive growth strategy (QEP-042 #6)
    pub fn push_optimized(&self, value: QValue) {
        let mut elements = self.elements.borrow_mut();

        // If we're at capacity, pre-allocate more aggressively
        if elements.len() == elements.capacity() {
            let current_capacity = elements.capacity();
            let new_capacity = if current_capacity < 1024 {
                // Aggressive growth for small arrays (4x)
                (current_capacity * 4).max(16)
            } else {
                // Conservative growth for large arrays (2x)
                current_capacity * 2
            };
            elements.reserve(new_capacity - current_capacity);
        }

        elements.push(value);
    }

    pub fn get(&self, index: usize) -> Option<QValue> {
        self.elements.borrow().get(index).cloned()
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => {
                if !args.is_empty() {
                    return arg_err!("len expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.elements.borrow().len() as i64)))
            }
            "push" => {
                // Mutates: Add element to end, returns self for chaining
                if args.len() != 1 {
                    return arg_err!("push expects 1 argument, got {}", args.len());
                }
                // Use optimized push with aggressive growth strategy (QEP-042 #6)
                self.push_optimized(args[0].clone());
                Ok(QValue::Array(self.clone()))
            }
            "pop" => {
                // Mutates: Remove and return last element
                if !args.is_empty() {
                    return arg_err!("pop expects 0 arguments, got {}", args.len());
                }
                self.elements.borrow_mut().pop()
                    .ok_or_else(|| "Cannot pop from empty array".into())
            }
            "shift" => {
                // Mutates: Remove and return first element
                if !args.is_empty() {
                    return arg_err!("shift expects 0 arguments, got {}", args.len());
                }
                if self.elements.borrow().is_empty() {
                    return Err("Cannot shift from empty array".into());
                }
                Ok(self.elements.borrow_mut().remove(0))
            }
            "unshift" => {
                // Mutates: Add element to beginning, returns self for chaining
                if args.len() != 1 {
                    return arg_err!("unshift expects 1 argument, got {}", args.len());
                }
                self.elements.borrow_mut().insert(0, args[0].clone());
                Ok(QValue::Array(self.clone()))
            }
            "get" => {
                // Get element at index
                if args.len() != 1 {
                    return arg_err!("get expects 1 argument, got {}", args.len());
                }
                let index = args[0].as_num()? as usize;
                let elements = self.elements.borrow();
                elements.get(index)
                    .cloned()
                    .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, elements.len()).into())
            }
            "first" => {
                // Get first element
                if !args.is_empty() {
                    return arg_err!("first expects 0 arguments, got {}", args.len());
                }
                self.elements.borrow().first()
                    .cloned()
                    .ok_or_else(|| "Cannot get first element of empty array".into())
            }
            "last" => {
                // Get last element
                if !args.is_empty() {
                    return arg_err!("last expects 0 arguments, got {}", args.len());
                }
                self.elements.borrow().last()
                    .cloned()
                    .ok_or_else(|| "Cannot get last element of empty array".into())
            }
            "reverse" => {
                // Mutates: Reverse array in place, returns self for chaining
                if !args.is_empty() {
                    return arg_err!("reverse expects 0 arguments, got {}", args.len());
                }
                self.elements.borrow_mut().reverse();
                Ok(QValue::Array(self.clone()))
            }
            "reversed" => {
                // Non-mutating: Return new reversed array
                if !args.is_empty() {
                    return arg_err!("reversed expects 0 arguments, got {}", args.len());
                }
                let mut new_elements = self.elements.borrow().clone();
                new_elements.reverse();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "slice" => {
                // Non-mutating: Return subarray from start to end (exclusive)
                if args.len() != 2 {
                    return arg_err!("slice expects 2 arguments, got {}", args.len());
                }
                let start = args[0].as_num()? as i64;
                let end = args[1].as_num()? as i64;
                let elements = self.elements.borrow();
                let len = elements.len() as i64;

                // Handle negative indices
                let actual_start = if start < 0 {
                    (len + start).max(0) as usize
                } else {
                    start.min(len) as usize
                };

                let actual_end = if end < 0 {
                    (len + end).max(0) as usize
                } else {
                    end.min(len) as usize
                };

                if actual_start > actual_end {
                    return Ok(QValue::Array(QArray::new(Vec::new())));
                }

                let new_elements = elements[actual_start..actual_end].to_vec();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "concat" => {
                // Non-mutating: Combine this array with another array
                if args.len() != 1 {
                    return arg_err!("concat expects 1 argument, got {}", args.len());
                }
                match &args[0] {
                    QValue::Array(other) => {
                        let mut new_elements = self.elements.borrow().clone();
                        new_elements.extend(other.elements.borrow().clone());
                        Ok(QValue::Array(QArray::new(new_elements)))
                    }
                    _ => Err("concat expects an array argument".into())
                }
            }
            "join" => {
                // Query: Convert array to string with separator
                if args.len() != 1 {
                    return arg_err!("join expects 1 argument, got {}", args.len());
                }
                let separator = args[0].as_str();
                let elements = self.elements.borrow();
                let strings: Vec<String> = elements.iter()
                    .map(|v| v.as_obj().str())
                    .collect();
                Ok(QValue::Str(QString::new(strings.join(&separator))))
            }
            "contains" => {
                // Query: Check if array contains a value
                if args.len() != 1 {
                    return arg_err!("contains expects 1 argument, got {}", args.len());
                }
                let search_value = &args[0];
                let elements = self.elements.borrow();
                for elem in elements.iter() {
                    // Use Quest's equality comparison
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Bool(QBool::new(true)));
                    }
                }
                Ok(QValue::Bool(QBool::new(false)))
            }
            "index_of" => {
                // Query: Find index of first occurrence of value
                if args.len() != 1 {
                    return arg_err!("index_of expects 1 argument, got {}", args.len());
                }
                let search_value = &args[0];
                let elements = self.elements.borrow();
                for (i, elem) in elements.iter().enumerate() {
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Int(QInt::new(i as i64)));
                    }
                }
                Ok(QValue::Int(QInt::new(-1)))
            }
            "count" => {
                // Query: Count occurrences of value
                if args.len() != 1 {
                    return arg_err!("count expects 1 argument, got {}", args.len());
                }
                let search_value = &args[0];
                let elements = self.elements.borrow();
                let mut count = 0;
                for elem in elements.iter() {
                    if values_equal(elem, search_value) {
                        count += 1;
                    }
                }
                Ok(QValue::Int(QInt::new(count as i64)))
            }
            "empty" => {
                // Query: Check if array is empty
                if !args.is_empty() {
                    return arg_err!("empty expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.elements.borrow().is_empty())))
            }
            "sort" => {
                // Mutates: Sort array in place, returns self for chaining
                if !args.is_empty() {
                    return arg_err!("sort expects 0 arguments, got {}", args.len());
                }
                let mut elements = self.elements.borrow_mut();

                // Sort with type-aware comparison
                elements.sort_by(|a, b| {
                    compare_values(a, b).unwrap_or(std::cmp::Ordering::Equal)
                });

                drop(elements);  // Release borrow before cloning self
                Ok(QValue::Array(self.clone()))
            }
            "sorted" => {
                // Non-mutating: Return sorted copy
                if !args.is_empty() {
                    return arg_err!("sorted expects 0 arguments, got {}", args.len());
                }
                let mut new_elements = self.elements.borrow().clone();

                // Sort with type-aware comparison
                new_elements.sort_by(|a, b| {
                    compare_values(a, b).unwrap_or(std::cmp::Ordering::Equal)
                });

                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "clear" => {
                // Mutates: Remove all elements, returns self for chaining
                if !args.is_empty() {
                    return arg_err!("clear expects 0 arguments, got {}", args.len());
                }
                self.elements.borrow_mut().clear();
                Ok(QValue::Array(self.clone()))
            }
            "insert" => {
                // Mutates: Insert value at index, returns self for chaining
                if args.len() != 2 {
                    return arg_err!("insert expects 2 arguments (index, value), got {}", args.len());
                }
                let index = args[0].as_num()? as usize;
                let value = args[1].clone();
                let mut elements = self.elements.borrow_mut();

                if index > elements.len() {
                    return index_err!("Index {} out of bounds for array of length {}", index, elements.len());
                }

                elements.insert(index, value);
                drop(elements);  // Release borrow before cloning self
                Ok(QValue::Array(self.clone()))
            }
            "remove" => {
                // Mutates: Remove first occurrence of value, returns true if found
                if args.len() != 1 {
                    return arg_err!("remove expects 1 argument, got {}", args.len());
                }
                let search_value = &args[0];
                let mut elements = self.elements.borrow_mut();

                for (i, elem) in elements.iter().enumerate() {
                    if values_equal(elem, search_value) {
                        elements.remove(i);
                        return Ok(QValue::Bool(QBool::new(true)));
                    }
                }
                Ok(QValue::Bool(QBool::new(false)))
            }
            "remove_at" => {
                // Mutates: Remove and return element at index
                if args.len() != 1 {
                    return arg_err!("remove_at expects 1 argument, got {}", args.len());
                }
                let index = args[0].as_num()? as usize;
                let mut elements = self.elements.borrow_mut();

                if index >= elements.len() {
                    return index_err!("Index {} out of bounds for array of length {}", index, elements.len());
                }

                Ok(elements.remove(index))
            }
            _ => attr_err!("Array has no method '{}'", method_name),
        }
    }
}

impl QObj for QArray {
    fn cls(&self) -> String {
        "Array".to_string()
    }

    fn q_type(&self) -> &'static str {
        "array"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "array" || type_name == "obj"
    }

    fn str(&self) -> String {
        let elements = self.elements.borrow();
        let strings: Vec<String> = elements.iter().map(|e| e.as_str()).collect();
        format!("[{}]", strings.join(", "))
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        format!("Array with {} elements", self.elements.borrow().len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QArray {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Array", self.id);
    }
}

/// Call a static method on the Array type
pub fn call_array_static_method(method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
    match method_name {
        "new" => {
            // Ruby-style: Array.new(count, value)
            // Creates an array with `count` elements, each initialized to `value`
            if args.is_empty() {
                // No args: create empty array
                Ok(QValue::Array(QArray::new(Vec::new())))
            } else if args.len() == 1 {
                // One arg: create array with count nil elements
                let count = args[0].as_num()? as usize;
                let elements = vec![QValue::Nil(QNil); count];
                Ok(QValue::Array(QArray::new(elements)))
            } else if args.len() == 2 {
                // Two args: create array with count copies of value
                let count = args[0].as_num()? as usize;
                let value = args[1].clone();
                let elements = vec![value; count];
                Ok(QValue::Array(QArray::new(elements)))
            } else {
                arg_err!("Array.new expects 0, 1, or 2 arguments (count, value), got {}", args.len())
            }
        }
        _ => attr_err!("Array has no static method '{}'", method_name),
    }
}

/// Create a QType for Array with static methods
pub fn create_array_type() -> QType {
    QType::with_doc(
        "Array".to_string(),
        Vec::new(),
        Some("Built-in Array type with static constructor methods".to_string())
    )
}
