use super::*;

#[derive(Debug, Clone)]
pub struct QArray {
    pub elements: Vec<QValue>,
    pub id: u64,
}

impl QArray {
    pub fn new(elements: Vec<QValue>) -> Self {
        QArray {
            elements,
            id: next_object_id(),
        }
    }

    pub fn len(&self) -> usize {
        self.elements.len()
    }

    pub fn get(&self, index: usize) -> Option<&QValue> {
        self.elements.get(index)
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => {
                if !args.is_empty() {
                    return Err(format!("len expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Int(QInt::new(self.elements.len() as i64)))
            }
            "push" => {
                // Returns a new array with the element added to the end
                if args.len() != 1 {
                    return Err(format!("push expects 1 argument, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();
                new_elements.push(args[0].clone());
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "pop" => {
                // Returns a new array with the last element removed
                if !args.is_empty() {
                    return Err(format!("pop expects 0 arguments, got {}", args.len()));
                }
                if self.elements.is_empty() {
                    return Err("Cannot pop from empty array".to_string());
                }
                let mut new_elements = self.elements.clone();
                new_elements.pop();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "shift" => {
                // Returns a new array with the first element removed
                if !args.is_empty() {
                    return Err(format!("shift expects 0 arguments, got {}", args.len()));
                }
                if self.elements.is_empty() {
                    return Err("Cannot shift from empty array".to_string());
                }
                let new_elements = self.elements[1..].to_vec();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "unshift" => {
                // Returns a new array with the element added to the beginning
                if args.len() != 1 {
                    return Err(format!("unshift expects 1 argument, got {}", args.len()));
                }
                let mut new_elements = vec![args[0].clone()];
                new_elements.extend(self.elements.clone());
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "get" => {
                // Get element at index
                if args.len() != 1 {
                    return Err(format!("get expects 1 argument, got {}", args.len()));
                }
                let index = args[0].as_num()? as usize;
                self.elements.get(index)
                    .cloned()
                    .ok_or_else(|| format!("Index {} out of bounds for array of length {}", index, self.elements.len()))
            }
            "first" => {
                // Get first element
                if !args.is_empty() {
                    return Err(format!("first expects 0 arguments, got {}", args.len()));
                }
                self.elements.first()
                    .cloned()
                    .ok_or_else(|| "Cannot get first element of empty array".to_string())
            }
            "last" => {
                // Get last element
                if !args.is_empty() {
                    return Err(format!("last expects 0 arguments, got {}", args.len()));
                }
                self.elements.last()
                    .cloned()
                    .ok_or_else(|| "Cannot get last element of empty array".to_string())
            }
            "reverse" => {
                // Return new array with elements in reverse order
                if !args.is_empty() {
                    return Err(format!("reverse expects 0 arguments, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();
                new_elements.reverse();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "slice" => {
                // Return subarray from start to end (exclusive)
                if args.len() != 2 {
                    return Err(format!("slice expects 2 arguments, got {}", args.len()));
                }
                let start = args[0].as_num()? as i64;
                let end = args[1].as_num()? as i64;
                let len = self.elements.len() as i64;

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

                let new_elements = self.elements[actual_start..actual_end].to_vec();
                Ok(QValue::Array(QArray::new(new_elements)))
            }
            "concat" => {
                // Combine this array with another array
                if args.len() != 1 {
                    return Err(format!("concat expects 1 argument, got {}", args.len()));
                }
                match &args[0] {
                    QValue::Array(other) => {
                        let mut new_elements = self.elements.clone();
                        new_elements.extend(other.elements.clone());
                        Ok(QValue::Array(QArray::new(new_elements)))
                    }
                    _ => Err("concat expects an array argument".to_string())
                }
            }
            "join" => {
                // Convert array to string with separator
                if args.len() != 1 {
                    return Err(format!("join expects 1 argument, got {}", args.len()));
                }
                let separator = args[0].as_str();
                let strings: Vec<String> = self.elements.iter()
                    .map(|v| v.as_obj()._str())
                    .collect();
                Ok(QValue::Str(QString::new(strings.join(&separator))))
            }
            "contains" => {
                // Check if array contains a value
                if args.len() != 1 {
                    return Err(format!("contains expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                for elem in &self.elements {
                    // Use Quest's equality comparison
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Bool(QBool::new(true)));
                    }
                }
                Ok(QValue::Bool(QBool::new(false)))
            }
            "index_of" => {
                // Find index of first occurrence of value
                if args.len() != 1 {
                    return Err(format!("index_of expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                for (i, elem) in self.elements.iter().enumerate() {
                    if values_equal(elem, search_value) {
                        return Ok(QValue::Int(QInt::new(i as i64)));
                    }
                }
                Ok(QValue::Int(QInt::new(-1)))
            }
            "count" => {
                // Count occurrences of value
                if args.len() != 1 {
                    return Err(format!("count expects 1 argument, got {}", args.len()));
                }
                let search_value = &args[0];
                let mut count = 0;
                for elem in &self.elements {
                    if values_equal(elem, search_value) {
                        count += 1;
                    }
                }
                Ok(QValue::Int(QInt::new(count as i64)))
            }
            "empty" => {
                // Check if array is empty
                if !args.is_empty() {
                    return Err(format!("empty expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Bool(QBool::new(self.elements.is_empty())))
            }
            "sort" => {
                // Return sorted array (ascending order)
                if !args.is_empty() {
                    return Err(format!("sort expects 0 arguments, got {}", args.len()));
                }
                let mut new_elements = self.elements.clone();

                // Sort with type-aware comparison
                new_elements.sort_by(|a, b| {
                    compare_values(a, b).unwrap_or(std::cmp::Ordering::Equal)
                });

                Ok(QValue::Array(QArray::new(new_elements)))
            }
            _ => Err(format!("Array has no method '{}'", method_name)),
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

    fn _str(&self) -> String {
        let elements: Vec<String> = self.elements.iter().map(|e| e.as_str()).collect();
        format!("[{}]", elements.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Array with {} elements", self.elements.len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
