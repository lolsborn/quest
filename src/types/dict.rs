use super::*;

#[derive(Debug, Clone)]
pub struct QDict {
    pub map: HashMap<String, QValue>,
    pub id: u64,
}

impl QDict {
    pub fn new(map: HashMap<String, QValue>) -> Self {
        QDict {
            map,
            id: next_object_id(),
        }
    }

    pub fn get(&self, key: &str) -> Option<&QValue> {
        self.map.get(key)
    }

    pub fn has(&self, key: &str) -> bool {
        self.map.contains_key(key)
    }

    pub fn keys(&self) -> Vec<String> {
        self.map.keys().cloned().collect()
    }

    pub fn values(&self) -> Vec<QValue> {
        self.map.values().cloned().collect()
    }

    pub fn len(&self) -> usize {
        self.map.len()
    }

    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        // Try QObj trait methods first
        if let Some(result) = try_call_qobj_method(self, method_name, &_args) {
            return result;
        }

        // Handle type-specific methods
        match method_name {
            "len" => Ok(QValue::Int(QInt::new(self.len() as i64))),
            "keys" => {
                let keys: Vec<QValue> = self.keys().iter()
                    .map(|k| QValue::Str(QString::new(k.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(keys)))
            }
            "values" => {
                Ok(QValue::Array(QArray::new(self.values())))
            }
            "contains" => {
                if _args.len() != 1 {
                    return Err(format!("contains() expects 1 argument, got {}", _args.len()));
                }
                let key = _args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.has(&key))))
            }
            "get" => {
                // Get value for key, returns nil if not found (or default if provided)
                if _args.is_empty() || _args.len() > 2 {
                    return Err(format!("get() expects 1 or 2 arguments, got {}", _args.len()));
                }
                let key = _args[0].as_str();
                match self.get(&key) {
                    Some(value) => Ok(value.clone()),
                    None => {
                        // Return default if provided, else nil
                        if _args.len() == 2 {
                            Ok(_args[1].clone())
                        } else {
                            Ok(QValue::Nil(QNil))
                        }
                    }
                }
            }
            "set" => {
                // Returns new dict with key set to value (immutable)
                if _args.len() != 2 {
                    return Err(format!("set() expects 2 arguments (key, value), got {}", _args.len()));
                }
                let key = _args[0].as_str();
                let value = _args[1].clone();

                let mut new_map = self.map.clone();
                new_map.insert(key, value);
                Ok(QValue::Dict(QDict::new(new_map)))
            }
            "remove" => {
                // Returns new dict with key removed (immutable)
                if _args.len() != 1 {
                    return Err(format!("remove() expects 1 argument, got {}", _args.len()));
                }
                let key = _args[0].as_str();

                let mut new_map = self.map.clone();
                new_map.remove(&key);
                Ok(QValue::Dict(QDict::new(new_map)))
            }
            _ => Err(format!("Dict has no method '{}'", method_name)),
        }
    }
}

impl QObj for QDict {
    fn cls(&self) -> String {
        "Dict".to_string()
    }

    fn q_type(&self) -> &'static str {
        "dict"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "dict" || type_name == "obj"
    }

    fn _str(&self) -> String {
        let mut pairs: Vec<String> = self.map.iter()
            .map(|(k, v)| format!("{}: {}", k, v.as_str()))
            .collect();
        pairs.sort();
        format!("{{{}}}", pairs.join(", "))
    }

    fn _rep(&self) -> String {
        self._str()
    }

    fn _doc(&self) -> String {
        format!("Dict with {} entries", self.map.len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
