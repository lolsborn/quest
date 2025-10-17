use std::collections::HashSet;
use crate::{arg_err, key_err, type_err, attr_err};
use std::rc::Rc;
use std::cell::RefCell;
use ordered_float::OrderedFloat;
use crate::types::*;

/// SetElement represents a hashable value that can be stored in a Set
#[derive(Debug, Clone, Hash, Eq, PartialEq)]
pub enum SetElement {
    Int(i64),
    Float(OrderedFloat<f64>),
    Str(String),
    Bool(bool),
}

impl SetElement {
    /// Convert QValue to SetElement (only for hashable types)
    pub fn from_qvalue(value: &QValue) -> Result<Self, String> {
        match value {
            QValue::Int(i) => Ok(SetElement::Int(i.value)),
            QValue::Float(f) => Ok(SetElement::Float(OrderedFloat(f.value))),
            QValue::Str(s) => Ok(SetElement::Str(s.value.as_ref().clone())),
            QValue::Bool(b) => Ok(SetElement::Bool(b.value)),
            _ => type_err!("Type {} is not hashable and cannot be added to Set", value.as_obj().cls()),
        }
    }

    /// Convert SetElement back to QValue
    pub fn to_qvalue(&self) -> QValue {
        match self {
            SetElement::Int(i) => QValue::Int(QInt::new(*i)),
            SetElement::Float(f) => QValue::Float(QFloat::new(f.0)),
            SetElement::Str(s) => QValue::Str(QString::new(s.clone())),
            SetElement::Bool(b) => QValue::Bool(QBool::new(*b)),
        }
    }
}

#[derive(Debug)]
pub struct QSet {
    pub elements: Rc<RefCell<HashSet<SetElement>>>,
    pub id: u64,
}

impl QSet {
    pub fn new(elements: Vec<SetElement>) -> Self {
        let set: HashSet<SetElement> = elements.into_iter().collect();
        let id = next_object_id();
        crate::alloc_counter::track_alloc("Set", id);
        QSet {
            elements: Rc::new(RefCell::new(set)),
            id,
        }
    }

    pub fn empty() -> Self {
        Self::new(Vec::new())
    }

    pub fn contains(&self, elem: &SetElement) -> bool {
        self.elements.borrow().contains(elem)
    }

    pub fn len(&self) -> usize {
        self.elements.borrow().len()
    }

    pub fn is_empty(&self) -> bool {
        self.elements.borrow().is_empty()
    }

    pub fn add(&self, elem: SetElement) {
        self.elements.borrow_mut().insert(elem);
    }

    pub fn remove(&self, elem: &SetElement) -> Result<(), String> {
        if self.elements.borrow_mut().remove(elem) {
            Ok(())
        } else {
            key_err!("Element not found in set")
        }
    }

    pub fn discard(&self, elem: &SetElement) {
        self.elements.borrow_mut().remove(elem);
    }

    pub fn clear(&self) {
        self.elements.borrow_mut().clear();
    }

    pub fn pop(&self) -> Option<SetElement> {
        let mut elements = self.elements.borrow_mut();
        let elem = elements.iter().next().cloned();
        if let Some(ref e) = elem {
            elements.remove(e);
        }
        elem
    }

    pub fn to_array(&self) -> Vec<SetElement> {
        let mut vec: Vec<SetElement> = self.elements.borrow().iter().cloned().collect();
        // Sort for consistent ordering
        vec.sort_by(|a, b| {
            match (a, b) {
                (SetElement::Int(a), SetElement::Int(b)) => a.cmp(b),
                (SetElement::Float(a), SetElement::Float(b)) => a.cmp(b),
                (SetElement::Str(a), SetElement::Str(b)) => a.cmp(b),
                (SetElement::Bool(a), SetElement::Bool(b)) => a.cmp(b),
                // Mixed types - order by type priority
                (SetElement::Bool(_), _) => std::cmp::Ordering::Less,
                (_, SetElement::Bool(_)) => std::cmp::Ordering::Greater,
                (SetElement::Int(_), SetElement::Float(_)) => std::cmp::Ordering::Less,
                (SetElement::Float(_), SetElement::Int(_)) => std::cmp::Ordering::Greater,
                (SetElement::Int(_), SetElement::Str(_)) => std::cmp::Ordering::Less,
                (SetElement::Str(_), SetElement::Int(_)) => std::cmp::Ordering::Greater,
                (SetElement::Float(_), SetElement::Str(_)) => std::cmp::Ordering::Less,
                (SetElement::Str(_), SetElement::Float(_)) => std::cmp::Ordering::Greater,
            }
        });
        vec
    }

    pub fn union(&self, other: &QSet) -> QSet {
        let mut result = self.elements.borrow().clone();
        for elem in other.elements.borrow().iter() {
            result.insert(elem.clone());
        }
        QSet::new(result.into_iter().collect())
    }

    pub fn intersection(&self, other: &QSet) -> QSet {
        let result: HashSet<SetElement> = self.elements.borrow()
            .intersection(&*other.elements.borrow())
            .cloned()
            .collect();
        QSet::new(result.into_iter().collect())
    }

    pub fn difference(&self, other: &QSet) -> QSet {
        let result: HashSet<SetElement> = self.elements.borrow()
            .difference(&*other.elements.borrow())
            .cloned()
            .collect();
        QSet::new(result.into_iter().collect())
    }

    pub fn symmetric_difference(&self, other: &QSet) -> QSet {
        let result: HashSet<SetElement> = self.elements.borrow()
            .symmetric_difference(&*other.elements.borrow())
            .cloned()
            .collect();
        QSet::new(result.into_iter().collect())
    }

    pub fn is_subset(&self, other: &QSet) -> bool {
        self.elements.borrow().is_subset(&*other.elements.borrow())
    }

    pub fn is_superset(&self, other: &QSet) -> bool {
        self.elements.borrow().is_superset(&*other.elements.borrow())
    }

    pub fn is_disjoint(&self, other: &QSet) -> bool {
        self.elements.borrow().is_disjoint(&*other.elements.borrow())
    }

    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, EvalError> {
        match method_name {
            "contains" => {
                if args.len() != 1 {
                    return arg_err!("contains expects 1 argument, got {}", args.len());
                }
                let elem = SetElement::from_qvalue(&args[0])?;
                Ok(QValue::Bool(QBool::new(self.contains(&elem))))
            }
            "len" => {
                if !args.is_empty() {
                    return arg_err!("len expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.len() as i64)))
            }
            "empty" => {
                if !args.is_empty() {
                    return arg_err!("empty expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Bool(QBool::new(self.is_empty())))
            }
            "add" => {
                if args.len() != 1 {
                    return arg_err!("add expects 1 argument, got {}", args.len());
                }
                let elem = SetElement::from_qvalue(&args[0])?;
                self.add(elem);
                Ok(QValue::Nil(QNil))
            }
            "remove" => {
                if args.len() != 1 {
                    return arg_err!("remove expects 1 argument, got {}", args.len());
                }
                let elem = SetElement::from_qvalue(&args[0])?;
                self.remove(&elem)?;
                Ok(QValue::Nil(QNil))
            }
            "discard" => {
                if args.len() != 1 {
                    return arg_err!("discard expects 1 argument, got {}", args.len());
                }
                let elem = SetElement::from_qvalue(&args[0])?;
                self.discard(&elem);
                Ok(QValue::Nil(QNil))
            }
            "clear" => {
                if !args.is_empty() {
                    return arg_err!("clear expects 0 arguments, got {}", args.len());
                }
                self.clear();
                Ok(QValue::Nil(QNil))
            }
            "pop" => {
                if !args.is_empty() {
                    return arg_err!("pop expects 0 arguments, got {}", args.len());
                }
                match self.pop() {
                    Some(elem) => Ok(elem.to_qvalue()),
                    None => Err("pop from empty set".into()),
                }
            }
            "to_array" | "sorted" => {
                if !args.is_empty() {
                    return arg_err!("to_array expects 0 arguments, got {}", args.len());
                }
                let array_elements: Vec<QValue> = self.to_array()
                    .into_iter()
                    .map(|e| e.to_qvalue())
                    .collect();
                Ok(QValue::Array(QArray::new(array_elements)))
            }
            "union" => {
                if args.len() != 1 {
                    return arg_err!("union expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("union expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Set(self.union(other)))
            }
            "intersection" => {
                if args.len() != 1 {
                    return arg_err!("intersection expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("intersection expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Set(self.intersection(other)))
            }
            "difference" => {
                if args.len() != 1 {
                    return arg_err!("difference expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("difference expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Set(self.difference(other)))
            }
            "symmetric_difference" => {
                if args.len() != 1 {
                    return arg_err!("symmetric_difference expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("symmetric_difference expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Set(self.symmetric_difference(other)))
            }
            "is_subset" => {
                if args.len() != 1 {
                    return arg_err!("is_subset expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("is_subset expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Bool(QBool::new(self.is_subset(other))))
            }
            "is_superset" => {
                if args.len() != 1 {
                    return arg_err!("is_superset expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("is_superset expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Bool(QBool::new(self.is_superset(other))))
            }
            "is_disjoint" => {
                if args.len() != 1 {
                    return arg_err!("is_disjoint expects 1 argument, got {}", args.len());
                }
                let other = match &args[0] {
                    QValue::Set(s) => s,
                    _ => return type_err!("is_disjoint expects Set, got {}", args[0].as_obj().cls()),
                };
                Ok(QValue::Bool(QBool::new(self.is_disjoint(other))))
            }
            "_id" => {
                if !args.is_empty() {
                    return arg_err!("_id expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Int(QInt::new(self.id as i64)))
            }
            "cls" | "_type" => {
                if !args.is_empty() {
                    return arg_err!("cls expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.cls())))
            }
            "str" => {
                if !args.is_empty() {
                    return arg_err!("_str expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self.str())))
            }
            "_rep" => {
                if !args.is_empty() {
                    return arg_err!("_rep expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self._rep())))
            }
            "_doc" => {
                if !args.is_empty() {
                    return arg_err!("_doc expects 0 arguments, got {}", args.len());
                }
                Ok(QValue::Str(QString::new(self._doc())))
            }
            _ => attr_err!("Unknown method '{}' for Set", method_name),
        }
    }
}

impl Clone for QSet {
    fn clone(&self) -> Self {
        QSet {
            elements: Rc::clone(&self.elements),
            id: self.id,
        }
    }
}

impl QObj for QSet {
    fn cls(&self) -> String {
        "Set".to_string()
    }

    fn q_type(&self) -> &'static str {
        "Set"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "Set"
    }

    fn str(&self) -> String {
        let elements = self.to_array();
        let elem_strs: Vec<String> = elements.iter()
            .map(|e| match e {
                SetElement::Str(s) => format!("\"{}\"", s),
                SetElement::Int(i) => i.to_string(),
                SetElement::Float(f) => f.to_string(),
                SetElement::Bool(b) => b.to_string(),
            })
            .collect();
        format!("Set{{{}}}", elem_strs.join(", "))
    }

    fn _rep(&self) -> String {
        self.str()
    }

    fn _doc(&self) -> String {
        "Set: Unordered collection of unique hashable elements".to_string()
    }

    fn _id(&self) -> u64 {
        self.id
    }
}
