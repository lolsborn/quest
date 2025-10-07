use std::collections::HashMap;
use crate::{arg_err, value_err, type_err, attr_err};
use std::cell::RefCell;
use std::rc::Rc;
use std::hash::{Hash, Hasher};
use std::collections::hash_map::DefaultHasher;

use rand::{Rng as RandRng, SeedableRng, RngCore};
use rand::rngs::StdRng;
use rand::seq::{SliceRandom, IteratorRandom};
use rand_pcg::Pcg64;

use crate::types::*;

/// QRng represents a random number generator object in Quest
#[derive(Debug, Clone)]
pub enum QRng {
    /// Cryptographically secure RNG (ChaCha20-based)
    Secure(Rc<RefCell<StdRng>>),
    /// Fast non-cryptographic RNG (PCG64)
    Fast(Rc<RefCell<Pcg64>>),
    /// Seeded RNG for reproducible sequences (ChaCha20-based with known seed)
    Seeded(Rc<RefCell<StdRng>>),
}

impl QObj for QRng {
    fn cls(&self) -> String {
        "RNG".to_string()
    }

    fn q_type(&self) -> &'static str {
        "RNG"
    }

    fn is(&self, type_name: &str) -> bool {
        type_name == "RNG"
    }

    fn _str(&self) -> String {
        self.type_name().to_string()
    }

    fn _rep(&self) -> String {
        self.type_name().to_string()
    }

    fn _doc(&self) -> String {
        format!("Random number generator: {}", self.type_name())
    }

    fn _id(&self) -> u64 {
        // RNG objects don't have unique IDs (they're stateful tools, not data)
        // Return a hash of the type name
        match self {
            QRng::Secure(_) => 1,
            QRng::Fast(_) => 2,
            QRng::Seeded(_) => 3,
        }
    }
}

impl QRng {
    /// Get a string representation of the RNG type
    pub fn type_name(&self) -> &'static str {
        match self {
            QRng::Secure(_) => "RNG(secure)",
            QRng::Fast(_) => "RNG(fast)",
            QRng::Seeded(_) => "RNG(seeded)",
        }
    }

    /// Generate random integer in range [min, max] (inclusive)
    pub fn int(&self, min: i64, max: i64) -> Result<i64, String> {
        if min > max {
            return value_err!("min ({}) cannot be greater than max ({})", min, max);
        }

        let result = match self {
            QRng::Secure(rng) => rng.borrow_mut().gen_range(min..=max),
            QRng::Fast(rng) => rng.borrow_mut().gen_range(min..=max),
            QRng::Seeded(rng) => rng.borrow_mut().gen_range(min..=max),
        };

        Ok(result)
    }

    /// Generate random float in range [0.0, 1.0) or [min, max)
    pub fn float(&self, min: Option<f64>, max: Option<f64>) -> Result<f64, String> {
        let base = match self {
            QRng::Secure(rng) => rng.borrow_mut().gen::<f64>(),
            QRng::Fast(rng) => rng.borrow_mut().gen::<f64>(),
            QRng::Seeded(rng) => rng.borrow_mut().gen::<f64>(),
        };

        match (min, max) {
            (None, None) => Ok(base),
            (Some(min_val), Some(max_val)) => {
                if min_val > max_val {
                    return value_err!("min ({}) cannot be greater than max ({})", min_val, max_val);
                }
                Ok(min_val + (max_val - min_val) * base)
            }
            _ => Err("float() requires both min and max or neither".to_string()),
        }
    }

    /// Generate random boolean
    pub fn bool(&self) -> bool {
        match self {
            QRng::Secure(rng) => rng.borrow_mut().gen_range(0..=1) == 1,
            QRng::Fast(rng) => rng.borrow_mut().gen_range(0..=1) == 1,
            QRng::Seeded(rng) => rng.borrow_mut().gen_range(0..=1) == 1,
        }
    }

    /// Generate n random bytes
    pub fn bytes(&self, n: usize) -> Vec<u8> {
        let mut bytes = vec![0u8; n];
        match self {
            QRng::Secure(rng) => rng.borrow_mut().fill_bytes(&mut bytes),
            QRng::Fast(rng) => rng.borrow_mut().fill_bytes(&mut bytes),
            QRng::Seeded(rng) => rng.borrow_mut().fill_bytes(&mut bytes),
        }
        bytes
    }

    /// Pick random element from array
    pub fn choice(&self, array: &QArray) -> Result<QValue, String> {
        let elements = array.elements.borrow();
        if elements.is_empty() {
            return Err("Cannot choose from empty array".to_string());
        }

        let index = match self {
            QRng::Secure(rng) => rng.borrow_mut().gen_range(0..elements.len()),
            QRng::Fast(rng) => rng.borrow_mut().gen_range(0..elements.len()),
            QRng::Seeded(rng) => rng.borrow_mut().gen_range(0..elements.len()),
        };

        Ok(elements[index].clone())
    }

    /// Shuffle array in place (mutates the array)
    pub fn shuffle(&self, array: &QArray) -> Result<(), String> {
        let mut elements = array.elements.borrow_mut();

        match self {
            QRng::Secure(rng) => elements.shuffle(&mut *rng.borrow_mut()),
            QRng::Fast(rng) => elements.shuffle(&mut *rng.borrow_mut()),
            QRng::Seeded(rng) => elements.shuffle(&mut *rng.borrow_mut()),
        }

        Ok(())
    }

    /// Sample k random elements from array (without replacement)
    pub fn sample(&self, array: &QArray, k: usize) -> Result<Vec<QValue>, String> {
        let elements = array.elements.borrow();

        if k > elements.len() {
            return value_err!("Cannot sample {} elements from array of length {}", k, elements.len());
        }

        let sampled = match self {
            QRng::Secure(rng) => {
                elements.iter()
                    .cloned()
                    .choose_multiple(&mut *rng.borrow_mut(), k)
            }
            QRng::Fast(rng) => {
                elements.iter()
                    .cloned()
                    .choose_multiple(&mut *rng.borrow_mut(), k)
            }
            QRng::Seeded(rng) => {
                elements.iter()
                    .cloned()
                    .choose_multiple(&mut *rng.borrow_mut(), k)
            }
        };

        Ok(sampled)
    }
}

/// Create the rand module
pub fn create_rand_module() -> QValue {
    let mut members = HashMap::new();

    members.insert("secure".to_string(), create_fn("rand", "secure"));
    members.insert("fast".to_string(), create_fn("rand", "fast"));
    members.insert("seed".to_string(), create_fn("rand", "seed"));

    QValue::Module(Box::new(QModule::new("rand".to_string(), members)))
}

/// Handle rand.* function calls (module-level constructors)
pub fn call_rand_function(func_name: &str, args: Vec<QValue>, _scope: &mut crate::Scope) -> Result<QValue, String> {
    match func_name {
        "rand.secure" => rand_secure(args),
        "rand.fast" => rand_fast(args),
        "rand.seed" => rand_seed(args),
        _ => attr_err!("Unknown rand function: {}", func_name)
    }
}

/// rand.secure() - Create cryptographically secure RNG
fn rand_secure(args: Vec<QValue>) -> Result<QValue, String> {
    if !args.is_empty() {
        return arg_err!("secure() expects 0 arguments, got {}", args.len());
    }

    let rng = StdRng::from_entropy();  // Seeded from OS
    Ok(QValue::Rng(Box::new(QRng::Secure(Rc::new(RefCell::new(rng))))))
}

/// rand.fast() - Create fast non-cryptographic RNG
fn rand_fast(args: Vec<QValue>) -> Result<QValue, String> {
    if !args.is_empty() {
        return arg_err!("fast() expects 0 arguments, got {}", args.len());
    }

    // Seed the fast RNG from a secure source
    let mut seed_rng = StdRng::from_entropy();
    let seed = seed_rng.gen();
    let rng = Pcg64::seed_from_u64(seed);

    Ok(QValue::Rng(Box::new(QRng::Fast(Rc::new(RefCell::new(rng))))))
}

/// rand.seed(value) - Create seeded RNG for reproducible sequences
fn rand_seed(args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("seed() expects 1 argument, got {}", args.len());
    }

    let seed = match &args[0] {
        QValue::Int(i) => i.value as u64,
        QValue::Str(s) => {
            // Hash the string to get a seed
            let mut hasher = DefaultHasher::new();
            s.value.hash(&mut hasher);
            hasher.finish()
        }
        _ => return type_err!("seed() expects Int or Str, got {}", args[0].as_obj().cls()),
    };

    let rng = StdRng::seed_from_u64(seed);
    Ok(QValue::Rng(Box::new(QRng::Seeded(Rc::new(RefCell::new(rng))))))
}

/// Handle rng.* method calls on RNG objects
pub fn call_rng_method(rng: &QRng, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match method_name {
        // RNG-specific methods
        "int" => rng_int(rng, args),
        "float" => rng_float(rng, args),
        "bool" => rng_bool(rng, args),
        "bytes" => rng_bytes(rng, args),
        "choice" => rng_choice(rng, args),
        "shuffle" => rng_shuffle(rng, args),
        "sample" => rng_sample(rng, args),
        // Object introspection methods
        "cls" | "_type" => {
            if !args.is_empty() {
                return arg_err!("{}() expects 0 arguments, got {}", method_name, args.len());
            }
            Ok(QValue::Str(QString::new(rng.cls())))
        }
        "_str" => {
            if !args.is_empty() {
                return arg_err!("_str() expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Str(QString::new(rng._str())))
        }
        "_rep" => {
            if !args.is_empty() {
                return arg_err!("_rep() expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Str(QString::new(rng._rep())))
        }
        "_doc" => {
            if !args.is_empty() {
                return arg_err!("_doc() expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Str(QString::new(rng._doc())))
        }
        "_id" => {
            if !args.is_empty() {
                return arg_err!("_id() expects 0 arguments, got {}", args.len());
            }
            Ok(QValue::Int(QInt::new(rng._id() as i64)))
        }
        _ => attr_err!("Unknown RNG method: {}", method_name)
    }
}

/// rng.int(min, max) - Generate random integer
fn rng_int(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 2 {
        return arg_err!("int() expects 2 arguments, got {}", args.len());
    }

    let min = match &args[0] {
        QValue::Int(i) => i.value,
        _ => return type_err!("int() min must be Int, got {}", args[0].as_obj().cls()),
    };

    let max = match &args[1] {
        QValue::Int(i) => i.value,
        _ => return type_err!("int() max must be Int, got {}", args[1].as_obj().cls()),
    };

    let result = rng.int(min, max)?;
    Ok(QValue::Int(QInt::new(result)))
}

/// rng.float() or rng.float(min, max) - Generate random float
fn rng_float(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    let (min, max) = match args.len() {
        0 => (None, None),
        2 => {
            let min_val = match &args[0] {
                QValue::Int(i) => i.value as f64,
                QValue::Float(f) => f.value,
                _ => return type_err!("float() min must be Int or Float, got {}", args[0].as_obj().cls()),
            };

            let max_val = match &args[1] {
                QValue::Int(i) => i.value as f64,
                QValue::Float(f) => f.value,
                _ => return type_err!("float() max must be Int or Float, got {}", args[1].as_obj().cls()),
            };

            (Some(min_val), Some(max_val))
        }
        _ => return arg_err!("float() expects 0 or 2 arguments, got {}", args.len()),
    };

    let result = rng.float(min, max)?;
    Ok(QValue::Float(QFloat::new(result)))
}

/// rng.bool() - Generate random boolean
fn rng_bool(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if !args.is_empty() {
        return arg_err!("bool() expects 0 arguments, got {}", args.len());
    }

    let result = rng.bool();
    Ok(QValue::Bool(QBool::new(result)))
}

/// rng.bytes(n) - Generate n random bytes
fn rng_bytes(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("bytes() expects 1 argument, got {}", args.len());
    }

    let n = match &args[0] {
        QValue::Int(i) => {
            if i.value < 0 {
                return value_err!("bytes() n cannot be negative, got {}", i.value);
            }
            i.value as usize
        }
        _ => return type_err!("bytes() expects Int, got {}", args[0].as_obj().cls()),
    };

    let bytes = rng.bytes(n);
    Ok(QValue::Bytes(QBytes::new(bytes)))
}

/// rng.choice(array) - Pick random element from array
fn rng_choice(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("choice() expects 1 argument, got {}", args.len());
    }

    let array = match &args[0] {
        QValue::Array(a) => a,
        _ => return type_err!("choice() expects Array, got {}", args[0].as_obj().cls()),
    };

    rng.choice(array)
}

/// rng.shuffle(array) - Shuffle array in place
fn rng_shuffle(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 1 {
        return arg_err!("shuffle() expects 1 argument, got {}", args.len());
    }

    let array = match &args[0] {
        QValue::Array(a) => a,
        _ => return type_err!("shuffle() expects Array, got {}", args[0].as_obj().cls()),
    };

    rng.shuffle(array)?;
    Ok(QValue::Nil(QNil))
}

/// rng.sample(array, k) - Sample k random elements (without replacement)
fn rng_sample(rng: &QRng, args: Vec<QValue>) -> Result<QValue, String> {
    if args.len() != 2 {
        return arg_err!("sample() expects 2 arguments, got {}", args.len());
    }

    let array = match &args[0] {
        QValue::Array(a) => a,
        _ => return type_err!("sample() first argument must be Array, got {}", args[0].as_obj().cls()),
    };

    let k = match &args[1] {
        QValue::Int(i) => {
            if i.value < 0 {
                return value_err!("sample() k cannot be negative, got {}", i.value);
            }
            i.value as usize
        }
        _ => return type_err!("sample() k must be Int, got {}", args[1].as_obj().cls()),
    };

    let sampled = rng.sample(array, k)?;
    Ok(QValue::Array(QArray::new(sampled)))
}
