use super::*;
use std::cell::RefCell;
use std::rc::Rc;

#[derive(Debug, Clone)]
pub struct QDict {
    pub map: Rc<RefCell<HashMap<String, QValue>>>,
    pub id: u64,
}

impl QDict {
    pub fn new(map: HashMap<String, QValue>) -> Self {
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Dict", id);
        QDict {
            map: Rc::new(RefCell::new(map)),
            id,
        }
    }

    pub fn get(&self, key: &str) -> Option<QValue> {
        self.map.borrow().get(key).cloned()
    }

    pub fn has(&self, key: &str) -> bool {
        self.map.borrow().contains_key(key)
    }

    pub fn keys(&self) -> Vec<String> {
        self.map.borrow().keys().cloned().collect()
    }

    pub fn values(&self) -> Vec<QValue> {
        self.map.borrow().values().cloned().collect()
    }

    pub fn len(&self) -> usize {
        self.map.borrow().len()
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
                    return arg_err!("contains() expects 1 argument, got {}", _args.len());
                }
                let key = _args[0].as_str();
                Ok(QValue::Bool(QBool::new(self.has(&key))))
            }
            "get" => {
                // Get value for key, returns nil if not found (or default if provided)
                if _args.is_empty() || _args.len() > 2 {
                    return arg_err!("get() expects 1 or 2 arguments, got {}", _args.len());
                }
                let key = _args[0].as_str();
                match self.get(&key) {
                    Some(value) => Ok(value),
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
                    return arg_err!("set() expects 2 arguments (key, value), got {}", _args.len());
                }
                let key = _args[0].as_str();
                let value = _args[1].clone();

                let new_map = self.map.borrow().clone();
                let mut new_map = new_map;
                new_map.insert(key, value);
                Ok(QValue::Dict(Box::new(QDict::new(new_map))))
            }
            "remove" => {
                // Returns new dict with key removed (immutable)
                if _args.len() != 1 {
                    return arg_err!("remove() expects 1 argument, got {}", _args.len());
                }
                let key = _args[0].as_str();

                let new_map = self.map.borrow().clone();
                let mut new_map = new_map;
                new_map.remove(&key);
                Ok(QValue::Dict(Box::new(QDict::new(new_map))))
            }
            "clone" => {
                // Returns a deep copy of the dict
                if !_args.is_empty() {
                    return arg_err!("clone() expects 0 arguments, got {}", _args.len());
                }
                let new_map = self.map.borrow().clone();
                Ok(QValue::Dict(Box::new(QDict::new(new_map))))
            }
            _ => attr_err!("Dict has no method '{}'", method_name),
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

    fn str(&self) -> String {
        let map = self.map.borrow();
        let mut pairs: Vec<String> = map.iter()
            .map(|(k, v)| format!("{}: {}", k, v.as_str()))
            .collect();
        pairs.sort();
        format!("{{{}}}", pairs.join(", "))
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        format!("Dict with {} entries", self.map.borrow().len())
    }

    fn _id(&self) -> u64 {
        self.id
    }
}

impl Drop for QDict {
    fn drop(&mut self) {
        crate::alloc_counter::track_dealloc("Dict", self.id);
    }
}
