# QEP-037: Typed Exception System

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Related:** QEP-036 (bracket indexing tests exposed this issue)

## Abstract

This QEP proposes replacing Quest's current string-based error system with a proper typed exception hierarchy. Currently, all errors are ad-hoc formatted strings (863 sites across 54 files), making it impossible to catch errors by category, write reliable tests, or provide type-safe error handling. This proposal introduces structured exception types with a hierarchical matching system, enabling robust error handling patterns similar to Python, Ruby, and Java.

## Motivation

### Current State

Quest uses strings for all exceptions:

```rust
// In Rust code - 863 sites like this
return Err(format!("String index out of bounds: {}", idx));
return Err(format!("{} expects {} arguments, got {}", name, expected, got));
return Err(format!("Cannot call method '{}' on nil", method));
```

Exception "types" are parsed from error string prefixes:

```rust
// src/main.rs:3245-3249
let (exc_type, exc_msg) = if let Some(colon_pos) = error_msg.find(": ") {
    (error_msg[..colon_pos].to_string(), error_msg[colon_pos + 2..].to_string())
} else {
    ("Error".to_string(), error_msg.clone())
};
```

This creates an `type()` method that returns parsed strings:

```quest
try
    "hello"[10]
catch e
    puts(e.type())  # → "String index out of bounds" (not a type!)
    puts(e.message())   # → "10 (valid: 0..4 or -5..-1)"
end
```

### Problems This Causes

#### 1. **Impossible to Catch by Category**

```quest
# Want to catch all index errors
catch e: IndexErr  # ✗ Doesn't work - "String index out of bounds" != "IndexErr"
```

Each subsystem uses different error message formats:
- `"String index out of bounds: 10"`
- `"Index 5 out of bounds for array of length 3"`
- `"Bytes index out of bounds: -10"`

There's no common `IndexErr` type to catch.

#### 2. **Test Framework Broken**

The test framework's `assert_raises(expected_exc_type, test_fn, message)` expects exact string matches:

```quest
# lib/std/test.q:837
if e.type() != expected_exc_type
```

With no base exception type to represent "any error", tests tried using `nil` as a workaround:

```quest
test.assert_raises(nil, fun () "hello"[10] end, nil)  # ✗ Broken: nil is not an exception type!
```

This never worked because `nil` is not a valid exception type - you cannot raise or catch `nil`.

**Result:** 15/23 tests fail in QEP-036 bracket indexing test suite because there's no way to assert "any error was raised".

#### 3. **No Error Hierarchy**

Cannot catch broad categories:

```quest
# Want to catch any error
catch e: Err  # ✗ Doesn't work - no base exception type in old system

# Want specific handling with fallback
try
    risky_operation()
catch e: NetworkErr
    retry()
catch e: Err  # ✗ Can't catch "all other errors" in old system
    log_error(e)
end
```

#### 4. **Inconsistent Error Formats**

**Current System:** Analysis of 863 error sites shows inconsistent patterns where the first colon in the error message is treated as the type delimiter:

| Error String (CURRENT) | Parsed Type | Parsed Message |
|---|---|---|
| `"String index out of bounds: 10 (valid: 0..4)"` | `"String index out of bounds"` | `"10 (valid: 0..4)"` |
| `"String index must be Int, got: Float"` | `"String index must be Int, got"` | `"Float"` |
| `"Index too large (must fit in Int)"` | `"Error"` | `"Index too large (must fit in Int)"` |

The first two examples parse the *natural colon* in the error message as the type delimiter, producing nonsensical "types". The third example has no colon, so it defaults to `"Error"` with the full message.

**After Migration:** With typed exception macros, we add proper type prefixes:

| Error String (AFTER MIGRATION) | Parsed Type | Parsed Message |
|---|---|---|
| `"IndexErr: String index out of bounds: 10 (valid: 0..4)"` | `"IndexErr"` | `"String index out of bounds: 10 (valid: 0..4)"` |
| `"TypeErr: String index must be Int, got: Float"` | `"TypeErr"` | `"String index must be Int, got: Float"` |
| `"RuntimeErr: Index too large (must fit in Int)"` | `"RuntimeErr"` | `"Index too large (must fit in Int)"` |

Now the **first colon** delimits the exception type, and subsequent colons are part of the message.

#### 5. **No Type Safety**

Typos in exception names aren't caught:

```quest
catch e: IndxError  # ✗ Typo - silently never matches
catch e: IndexErorr  # ✗ Another typo
```

Rust compiler can't help because everything is strings.

### Error Distribution Analysis

Analysis of all 863 error sites reveals natural categories:

| Category | Count | % | Examples |
|---|---|---|---|
| **ArgErr** | 582 | 67% | "expects 2 arguments, got 1", "slice requires start < end" |
| **RuntimeErr** | 187 | 22% | "Division by zero", "Stack overflow" |
| **TypeErr** | 38 | 4% | "Cannot index into Str", "Index must be Int, got Float" |
| **ValueErr** | 16 | 2% | "Invalid UTF-8 in bytes", "Illegal base for conversion" |
| **AttrErr** | 12 | 1% | "Type Foo has no method 'bar'", "Nil has no attributes" |
| **IndexErr** | 10 | 1% | "String index out of bounds", "Array index out of bounds" |
| **IOErr** | 7 | <1% | "File not found", "Permission denied", "Directory not found" |
| **NameErr** | 6 | <1% | "Undefined function", "Variable not defined", "Type not found" |
| **KeyErr** | 2 | <1% | "Dictionary key not found" |
| **ImportErr** | 3 | <1% | "Module not found", "Failed to load module" |
| **Total** | **863** | **100%** | |

**Notes:**
- **NameErr** includes what was originally categorized as "NotFoundError" (undefined variables, functions, types)
- **IOErr** includes file/directory operations that were in RuntimeError
- **ImportErr** includes module loading errors split from RuntimeError
- These categories align with Python's exception hierarchy

## Proposal

### Exception Type Hierarchy

Introduce structured exception types with Rust-style naming (using `Err` suffix):

```
Err (base exception - catches all)
├── ValueErr         # Invalid value for operation
├── TypeErr          # Wrong type for operation
├── IndexErr         # Sequence index out of range
├── KeyErr           # Dictionary key not found
├── ArgErr           # Wrong number/type of arguments
├── AttrErr          # Object has no attribute/method
├── NameErr          # Name not found in scope
├── RuntimeErr       # Generic runtime error
├── IOErr            # Input/output operation failed
├── ImportErr        # Module import failed
└── (user-defined)   # Custom exception types
```

**Rationale for `Err` naming:**
- Shorter, more concise (matches Rust's `Result<T, Err>` pattern)
- `Err` as base type is clear and unambiguous
- Consistent suffix makes exception types easy to identify

### Rust Implementation

#### 1. Exception Type Enum

```rust
// src/types/exception.rs

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
pub enum ExceptionType {
    // Base exception (catches everything)
    Err,

    // Standard exceptions (using Err suffix)
    ValueErr,
    TypeErr,
    IndexErr,
    KeyErr,
    ArgErr,
    AttrErr,
    NameErr,
    RuntimeErr,
    IOErr,
    ImportErr,

    // User-defined exception (from Quest code)
    Custom(String),
}

impl ExceptionType {
    /// Get the string name of this exception type
    pub fn name(&self) -> &str {
        match self {
            ExceptionType::Err => "Err",
            ExceptionType::ValueErr => "ValueErr",
            ExceptionType::TypeErr => "TypeErr",
            ExceptionType::IndexErr => "IndexErr",
            ExceptionType::KeyErr => "KeyErr",
            ExceptionType::ArgErr => "ArgErr",
            ExceptionType::AttrErr => "AttrErr",
            ExceptionType::NameErr => "NameErr",
            ExceptionType::RuntimeErr => "RuntimeErr",
            ExceptionType::IOErr => "IOErr",
            ExceptionType::ImportErr => "ImportErr",
            ExceptionType::Custom(name) => name,
        }
    }

    /// Check if this exception type is a subtype of (or equal to) parent
    pub fn is_subtype_of(&self, parent: &ExceptionType) -> bool {
        // Base case: same type
        if self == parent {
            return true;
        }

        // Err is the base type - all exceptions are subtypes of Err
        if matches!(parent, ExceptionType::Err) {
            return true;
        }

        // Future: add subtype relationships for user-defined types
        // (would require trait-based hierarchy design)
        false
    }

    /// Parse exception type from string (used in catch clauses and error parsing)
    pub fn from_str(s: &str) -> Self {
        match s {
            "Err" => ExceptionType::Err,
            "ValueErr" => ExceptionType::ValueErr,
            "TypeErr" => ExceptionType::TypeErr,
            "IndexErr" => ExceptionType::IndexErr,
            "KeyErr" => ExceptionType::KeyErr,
            "ArgErr" => ExceptionType::ArgErr,
            "AttrErr" => ExceptionType::AttrErr,
            "NameErr" => ExceptionType::NameErr,
            "RuntimeErr" => ExceptionType::RuntimeErr,
            "IOErr" => ExceptionType::IOErr,
            "ImportErr" => ExceptionType::ImportErr,
            _ => ExceptionType::Custom(s.to_string()),
        }
    }
}

impl fmt::Display for ExceptionType {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", self.name())
    }
}
```

#### 2. Update QException Struct

```rust
// src/types/exception.rs

#[derive(Debug, Clone)]
pub struct QException {
    pub exception_type: ExceptionType,  // Changed from String to enum
    pub message: String,
    pub line: Option<usize>,
    pub file: Option<String>,
    pub stack: Vec<String>,
    pub cause: Option<Box<QException>>,
    pub id: u64,
}

impl QException {
    /// Create a new exception with typed exception
    pub fn new(exception_type: ExceptionType, message: String, line: Option<usize>, file: Option<String>) -> Self {
        QException {
            exception_type,
            message,
            line,
            file,
            stack: Vec::new(),
            cause: None,
            id: next_object_id(),
        }
    }

    /// Convenience constructors for common exception types
    pub fn index_err(message: String) -> Self {
        Self::new(ExceptionType::IndexErr, message, None, None)
    }

    pub fn type_err(message: String) -> Self {
        Self::new(ExceptionType::TypeErr, message, None, None)
    }

    pub fn value_err(message: String) -> Self {
        Self::new(ExceptionType::ValueErr, message, None, None)
    }

    pub fn arg_err(message: String) -> Self {
        Self::new(ExceptionType::ArgErr, message, None, None)
    }

    pub fn attr_err(message: String) -> Self {
        Self::new(ExceptionType::AttrErr, message, None, None)
    }

    pub fn name_err(message: String) -> Self {
        Self::new(ExceptionType::NameErr, message, None, None)
    }

    pub fn runtime_err(message: String) -> Self {
        Self::new(ExceptionType::RuntimeErr, message, None, None)
    }

    pub fn io_err(message: String) -> Self {
        Self::new(ExceptionType::IOErr, message, None, None)
    }

    pub fn key_err(message: String) -> Self {
        Self::new(ExceptionType::KeyErr, message, None, None)
    }
}

impl QObj for QException {
    fn _str(&self) -> String {
        format!("{}: {}", self.exception_type, self.message)
    }
    // ... rest unchanged
}

impl QException {
    pub fn call_method(&self, method_name: &str, _args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "exc_type" | "type" => {
                // Return exception type name as string
                Ok(QValue::Str(QString::new(self.exception_type.name().to_string())))
            },
            "message" => Ok(QValue::Str(QString::new(self.message.clone()))),
            // ... rest unchanged
        }
    }
}
```

#### 3. Error Raising Macros

Create convenience macros for raising typed exceptions:

```rust
// src/error_macros.rs

/// Raise an IndexErr
#[macro_export]
macro_rules! index_err {
    ($($arg:tt)*) => {
        Err(format!("IndexErr: {}", format!($($arg)*)))
    };
}

/// Raise a TypeErr
#[macro_export]
macro_rules! type_err {
    ($($arg:tt)*) => {
        Err(format!("TypeErr: {}", format!($($arg)*)))
    };
}

/// Raise a ValueErr
#[macro_export]
macro_rules! value_err {
    ($($arg:tt)*) => {
        Err(format!("ValueErr: {}", format!($($arg)*)))
    };
}

/// Raise an ArgErr
#[macro_export]
macro_rules! arg_err {
    ($($arg:tt)*) => {
        Err(format!("ArgErr: {}", format!($($arg)*)))
    };
}

/// Raise an AttrErr
#[macro_export]
macro_rules! attr_err {
    ($($arg:tt)*) => {
        Err(format!("AttrErr: {}", format!($($arg)*)))
    };
}

/// Raise a NameErr
#[macro_export]
macro_rules! name_err {
    ($($arg:tt)*) => {
        Err(format!("NameErr: {}", format!($($arg)*)))
    };
}

/// Raise a RuntimeErr
#[macro_export]
macro_rules! runtime_err {
    ($($arg:tt)*) => {
        Err(format!("RuntimeErr: {}", format!($($arg)*)))
    };
}

/// Raise an IOErr
#[macro_export]
macro_rules! io_err {
    ($($arg:tt)*) => {
        Err(format!("IOErr: {}", format!($($arg)*)))
    };
}

/// Raise a KeyErr
#[macro_export]
macro_rules! key_err {
    ($($arg:tt)*) => {
        Err(format!("KeyErr: {}", format!($($arg)*)))
    };
}
```

#### 4. Update Raise Statement to Validate Error Trait

```rust
// src/main.rs - in raise_statement evaluation

Rule::raise_statement => {
    let mut inner = pair.into_inner();

    if let Some(expr_pair) = inner.next() {
        // raise with expression
        let value = eval_pair(expr_pair, scope)?;

        match value {
            QValue::Exception(e) => {
                // Built-in exception object
                return Err(format!("{}: {}", e.exception_type, e.message));
            }
            QValue::Struct(s) => {
                // Custom exception type - check if it implements Error trait
                if !s.implements_trait("Error") {
                    return runtime_err!(
                        "Cannot raise type '{}' - must implement Error trait",
                        s.type_name
                    );
                }
                let msg = s.fields.get("message")
                    .map(|v| v.as_str())
                    .unwrap_or_else(|| "No message".to_string());
                return Err(format!("{}: {}", s.type_name, msg));
            }
            _ => {
                return runtime_err!(
                    "Cannot raise type '{}' - must implement Error trait",
                    value.q_type()
                );
            }
        }
    } else {
        // Bare raise - re-raise current exception
        if let Some(exc) = &scope.current_exception {
            return Err(format!("{}: {}", exc.exception_type, exc.message));
        } else {
            return runtime_err!("No active exception to re-raise");
        }
    }
}
```

#### 5. Update Error Parsing in Try/Catch

```rust
// src/main.rs - in try_statement evaluation

match try_result {
    Err(error_msg) => {
        // Parse exception type from "ExceptionType: message" format
        // All errors MUST have type prefix (no fallback)
        let (exc_type, exc_msg) = if let Some(colon_pos) = error_msg.find(": ") {
            let type_str = &error_msg[..colon_pos];
            let msg = &error_msg[colon_pos + 2..];
            (ExceptionType::from_str(type_str), msg.to_string())
        } else {
            panic!("Internal error: exception without type prefix: {}", error_msg);
        };

        let mut exception = QException::new(exc_type, exc_msg, None, None);
        exception.stack = scope.get_stack_trace();
        scope.current_exception = Some(exception.clone());

        // Try each catch clause
        for (var_name, exception_type_filter, body) in catch_clauses {
            // Check if this catch clause matches the exception type
            let matches = if let Some(ref expected_type_str) = exception_type_filter {
                let expected_type = ExceptionType::from_str(expected_type_str);
                // Use subtype checking (enables catching Err to match all exceptions)
                exception.exception_type.is_subtype_of(&expected_type)
            } else {
                true // catch-all (no type specified)
            };

            if matches {
                // Bind exception and execute catch block
                scope.declare(&var_name, QValue::Exception(exception.clone()))?;
                // ... execute catch body ...
                break;
            }
        }
    }
}
```

#### 6. Implement Built-in Exception Types as Quest Objects

All built-in exception types (`Err`, `IndexErr`, `TypeErr`, etc.) should be available as Quest types with a `.new()` constructor:

```rust
// src/stdlib/exceptions.rs (new file)

use crate::types::*;

/// Create built-in exception type objects
pub fn register_exception_types(scope: &mut Scope) {
    // Register Err base type
    scope.declare("Err", create_exception_type("Err")).unwrap();
    scope.declare("IndexErr", create_exception_type("IndexErr")).unwrap();
    scope.declare("TypeErr", create_exception_type("TypeErr")).unwrap();
    scope.declare("ValueErr", create_exception_type("ValueErr")).unwrap();
    scope.declare("ArgErr", create_exception_type("ArgErr")).unwrap();
    scope.declare("AttrErr", create_exception_type("AttrErr")).unwrap();
    scope.declare("NameErr", create_exception_type("NameErr")).unwrap();
    scope.declare("RuntimeErr", create_exception_type("RuntimeErr")).unwrap();
    scope.declare("IOErr", create_exception_type("IOErr")).unwrap();
    scope.declare("ImportErr", create_exception_type("ImportErr")).unwrap();
    scope.declare("KeyErr", create_exception_type("KeyErr")).unwrap();
}

fn create_exception_type(name: &str) -> QValue {
    // Create a type object with a static .new() method
    let mut type_obj = QType::new(name.to_string());

    // Add .new(message) static method
    type_obj.add_static_method("new", |args| {
        if args.len() != 1 {
            return arg_err!("new expects 1 argument (message), got {}", args.len());
        }

        let message = match &args[0] {
            QValue::Str(s) => s.value.to_string(),
            _ => return type_err!("Exception message must be str, got {}", args[0].q_type()),
        };

        let exc_type = ExceptionType::from_str(name);
        let exception = QException::new(exc_type, message, None, None);
        Ok(QValue::Exception(exception))
    });

    QValue::Type(type_obj)
}
```

**Usage in Quest:**
```quest
# All exception types are available as global types
raise Err.new("generic error")
raise IndexErr.new("index out of bounds")
raise TypeErr.new("type mismatch")
```

### Quest-Level Usage

#### 1. Catching Specific Exception Types

```quest
try
    let arr = [1, 2, 3]
    puts(arr[10])
catch e: IndexErr
    puts("Index out of range: " .. e.message())
catch e: Err  # Catches all other exceptions
    puts("Other error: " .. e.type())
end
```

#### 2. Catching Base Exception Type

```quest
try
    risky_operation()
catch e: Err  # Catches ALL exceptions (base type)
    puts("Something went wrong: " .. e.str())
end
```

#### 3. Raising Exceptions

**Generic exceptions** with `Err.new()`:

```quest
fun do_something()
    if some_condition
        raise Err.new("fart nuggets")
    end
end

try
    do_something()
catch e: Err
    puts("Error: " .. e.message())  # "fart nuggets"
    puts("Type: " .. e.type())  # "Err"
end
```

**Specific exception types**:

```quest
fun validate_age(age)
    if age < 0
        raise ValueErr.new("Age cannot be negative")
    end
    if age > 150
        raise ValueErr.new("Age is unrealistic")
    end
end

try
    validate_age(-5)
catch e: ValueErr
    puts("Invalid age: " .. e.message())
end
```

**More examples**:

```quest
raise IndexErr.new("Array index out of bounds: 10")
raise TypeErr.new("Expected Int, got Str")
raise IOErr.new("File not found: config.txt")
```

**Only objects implementing `Error` trait can be raised**:

```quest
raise "some error"  # ✗ RuntimeErr: Cannot raise type 'str' - must implement Error trait
raise 42            # ✗ RuntimeErr: Cannot raise type 'int' - must implement Error trait
raise nil           # ✗ RuntimeErr: Cannot raise type 'nil' - must implement Error trait
```

#### 4. Testing with Typed Exceptions

```quest
use "std/test"

test.describe("Array indexing", fun ()
    test.it("raises IndexErr on out of bounds", fun ()
        # Now works! Err is the base exception type
        test.assert_raises(Err, fun () [1, 2, 3][10] end, nil)

        # Can also be specific
        test.assert_raises(IndexErr, fun () [1, 2, 3][10] end, nil)
    end)

    test.it("raises TypeErr on invalid index type", fun ()
        test.assert_raises(TypeErr, fun () [1, 2, 3]["foo"] end, nil)
    end)
end)
```

### User-Defined Exception Types (Future)

Allow users to define custom exception types by implementing the `Error` trait:

```quest
# The Error trait defines the interface for exceptions
trait Error
    fun message()
    fun str()
end

# Define custom exception types
type DatabaseErr
    message: str

    static fun new(msg)
        DatabaseErr.new(message: msg)
    end

    impl Error
        fun message()
            self.message
        end

        fun str()
            "DatabaseErr: " .. self.message
        end
    end
end

type ConnectionErr
    message: str

    static fun new(msg)
        ConnectionErr.new(message: msg)
    end

    impl Error
        fun message()
            self.message
        end

        fun str()
            "ConnectionErr: " .. self.message
        end
    end
end

fun connect_to_db()
    raise ConnectionErr.new("Failed to connect to database")
end

try
    connect_to_db()
catch e: ConnectionErr
    puts("Connection problem: " .. e.message())
catch e: DatabaseErr
    puts("Database problem: " .. e.message())
catch e: Err  # Catches all exceptions (built-in and custom)
    puts("Other problem: " .. e.str())
end
```

**Implementation approach:**

1. Define `Error` trait with methods: `message()`, `_str()`
2. Built-in exception types (`Err`, `IndexErr`, etc.) automatically implement `Error`
3. At `raise` time, validate that the object implements the `Error` trait:
   ```quest
   raise my_obj  # Runtime error if my_obj doesn't implement Error
   ```
4. Custom exception types stored as `ExceptionType::Custom(String)` in Rust
5. The catch clause matching supports:
   - Built-in types: `catch e: IndexErr`
   - Custom types by name: `catch e: DatabaseErr`
   - Base type catches all: `catch e: Err`

**Validation example:**

```quest
type NotAnError
    message: str
end

raise NotAnError.new(message: "test")
# RuntimeErr: Cannot raise type 'NotAnError' - must implement Error trait
```

**Note:** Custom exception hierarchies are matched by exact name only. Trait-based exception hierarchies (e.g., `DatabaseErr` catching both `ConnectionErr` and `QueryErr`) would require additional design work and are out of scope for this QEP.

## Important Distinction: `Error` (Trait) vs `Err` (Type)

This is a critical distinction that prevents confusion:

### `Error` - The Trait (Interface)

- **Purpose**: Defines the interface that all exception objects must implement
- **Methods**: `message()`, `_str()`, etc.
- **Usage**: Types implement this trait to become raiseable
- **NOT USED IN**: Catch clauses, `assert_raises()`, or exception matching

```quest
# Error is a TRAIT - defines what exception objects can do
trait Error
    fun message()
    fun str()
end

# Types implement Error to become exceptions
type DatabaseErr
    impl Error
        fun message() ... end
        fun str() ... end
    end
end
```

### `Err` - The Base Exception Type

- **Purpose**: The base exception type that catches all exceptions
- **Hierarchy**: All built-in exceptions (IndexErr, TypeErr, etc.) are subtypes of Err
- **Usage**: Used in catch clauses and `assert_raises()` to catch "any exception"

```quest
# Err is a TYPE - the root of the exception hierarchy
catch e: Err  # Catches all exceptions (IndexErr, TypeErr, DatabaseErr, etc.)
test.assert_raises(Err, fun () risky_operation() end, nil)
```

### Catch Clause Type Matching

**✓ Valid - catch by exception TYPE:**

```quest
catch e: Err            # Catches base exception type (and all subtypes)
catch e: IndexErr       # Catches IndexErr type specifically
catch e: DatabaseErr    # Catches user-defined DatabaseErr type
catch e                 # Catches all exceptions (no type filter)
```

**✗ Invalid - catch by TRAIT name:**

```quest
catch e: Error          # ✗ Error! "Error" is a trait, not an exception type
                        # Should use "Err" instead
```

### Type Checking Rules

At runtime, catch clause type matching validates:
1. **Built-in exception types**: `Err`, `IndexErr`, `TypeErr`, `ValueErr`, etc.
2. **User-defined types**: Any struct that implements the `Error` trait
3. **NOT trait names**: `Error` is not a valid catch type (use `Err` instead)

### Test Framework Usage

**✓ Correct:**
```quest
test.assert_raises(Err, fun () arr[100] end, nil)         # Catch any exception
test.assert_raises(IndexErr, fun () arr[100] end, nil)    # Catch specific type
```

**✗ Incorrect:**
```quest
test.assert_raises(Error, fun () arr[100] end, nil)       # ✗ Error is a trait, not a type
test.assert_raises(nil, fun () arr[100] end, nil)         # ✗ nil is not an exception type
```

### Summary Table

| Name | Kind | Purpose | Used in catch? | Used in raise? |
|------|------|---------|----------------|----------------|
| `Error` | Trait | Interface for exceptions | ✗ No | ✗ No (implement it) |
| `Err` | Type | Base exception type | ✓ Yes | ✓ Yes |
| `IndexErr` | Type | Index out of bounds | ✓ Yes | ✓ Yes |
| `TypeErr` | Type | Type mismatch | ✓ Yes | ✓ Yes |
| `DatabaseErr` | Type (user) | Custom exception | ✓ Yes | ✓ Yes |

## Migration Strategy

### Phase 1: Add Error Macros and Update Error Sites

**Goal:** Replace all 863 error sites with typed exception macros.

**Approach:**
1. Add error macros to `src/error_macros.rs`
2. Replace all `Err(format!(...))` with typed macros

**Example migration:**

```rust
// Before
return Err(format!("String index out of bounds: {}", idx));

// After
return index_err!("String index out of bounds: {}", idx);
// Expands to: Err(format!("IndexErr: String index out of bounds: {}", idx))
```

**Migration by category:**
- ArgErr: 582 sites (function argument validation)
- RuntimeErr: 187 sites (general runtime errors)
- TypeErr: 38 sites (type mismatches)
- ValueErr: 16 sites (invalid values)
- AttrErr: 12 sites (missing methods/attributes)
- IndexErr: 10 sites (out of bounds access)
- IOErr: 7 sites (file/directory operations)
- NameErr: 6 sites (undefined names)
- ImportErr: 3 sites (module loading)
- KeyErr: 2 sites (dictionary access)

**Tools:** Automated with regex search-replace + manual verification.

### Phase 2: Update Exception Type Enum

**Goal:** Change `QException.exception_type` from `String` to `ExceptionType` enum.

**Changes:**
1. Update `QException` struct definition
2. Add `ExceptionType` enum with `from_str()` and `is_subtype_of()`
3. Update exception parsing in `try_statement` evaluation
4. Update `type()` method to return `exception_type.name()`


### Phase 3: Update Catch Matching

**Goal:** Enable hierarchical exception matching.

**Changes:**
1. Update catch clause matching to use `is_subtype_of()`
2. Ensure `catch e: Err` catches all exceptions
3. Ensure `catch e` (no type) catches all exceptions

**Testing:**
```quest
# Test hierarchical catching
try
    arr[100]
catch e: Err  # Should catch IndexErr
    puts("Caught via base type")
end
```

### Phase 4: Update Test Framework

**Goal:** Fix `assert_raises` to work with typed exceptions.

**Changes:**

```quest
# lib/std/test.q

pub fun assert_raises(expected_exc_type, test_fn, message)
    try
        test_fn()
        # No exception raised - fail
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected " .. expected_exc_type .. " to be raised but nothing was raised"
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    catch e
        # Exception was raised - check if it matches
        let actual_type = e.type()

        # Special case: "Err" is the base exception type - matches all exceptions
        # Otherwise, check for exact match (future: implement is_subtype_of in Quest)
        let matches = (expected_exc_type == "Err") or (actual_type == expected_exc_type)

        if not matches
            fail_count = fail_count + 1
            describe_fail_count = describe_fail_count + 1
            module_fail_count = module_fail_count + 1

            let failure_msg = "Expected " .. expected_exc_type .. " but got " .. actual_type .. ": " .. e.message()
            if message != nil
                failure_msg = failure_msg .. " (" .. message .. ")"
            end

            if condensed_output
                describe_failures = describe_failures.concat([failure_msg])
            else
                puts("  " .. red("✗") .. " " .. failure_msg)
            end
        end
    end
end
```

**Add helper for "any error" testing:**

```quest
# lib/std/test.q

pub fun assert_error(test_fn, message)
    # Simplified version: just check that ANY error is raised
    # Equivalent to assert_raises(Err, test_fn, message)
    try
        test_fn()
        # No exception - fail
        fail_count = fail_count + 1
        describe_fail_count = describe_fail_count + 1
        module_fail_count = module_fail_count + 1

        let failure_msg = "Expected an error to be raised but nothing was raised"
        if message != nil
            failure_msg = failure_msg .. ": " .. message
        end

        if condensed_output
            describe_failures = describe_failures.concat([failure_msg])
        else
            puts("  " .. red("✗") .. " " .. failure_msg)
        end
    catch e
        # Success - any error is acceptable
    end
end
```

### Phase 5: Update All Test Files

**Goal:** Update all test assertions to use typed exceptions.

**Before:**
```quest
test.assert_raises(nil, fun () "hello"[10] end, nil)  # ✗ Broken
```

**After:**
```quest
test.assert_raises(Err, fun () "hello"[10] end, nil)  # ✓ Works
# Or be specific:
test.assert_raises(IndexErr, fun () "hello"[10] end, nil)
```

**Files to update:** ~50 test files with error assertions.

### Phase 6: Documentation

**Goal:** Document the new exception system.

**Updates needed:**
1. Create `docs/exceptions.md` - comprehensive exception handling guide
2. Update `CLAUDE.md` - add exception types section
3. Update `docs/control_flow.md` - update try/catch examples
4. Add migration guide for error messages

## Examples

### Before (Current System)

```quest
# Catching exceptions is fragile
try
    "hello"[10]
catch e
    # Have to parse message strings to determine error type
    if e.type().contains("index")
        puts("Index error")
    else
        puts("Other error")
    end
end

# Testing requires exact string matches (broken)
test.assert_raises(nil, fun () "hello"[10] end, nil)  # ✗ Always fails

# No way to catch "all errors" reliably
try
    risky_operation()
catch e  # Only way to catch all - can't have fallback
    handle_error(e)
end
```

### After (Typed System)

```quest
# Clean exception catching by type
try
    "hello"[10]
catch e: IndexErr
    puts("Index error: " .. e.message())
catch e: TypeErr
    puts("Type error: " .. e.message())
catch e: Err  # Catches all other exceptions
    puts("Other error: " .. e.type())
end

# Testing with base type
test.assert_raises(Err, fun () "hello"[10] end, nil)  # ✓ Works

# Or be specific
test.assert_raises(IndexErr, fun () "hello"[10] end, nil)  # ✓ Works

# Hierarchical catching
try
    complex_operation()
catch e: IndexErr
    # Handle index errors specifically
    puts("Index problem")
catch e: Err
    # Catch everything else
    log_error(e)
    retry()
end
```

### Raising Typed Exceptions in Rust

```rust
// Before
return Err(format!("String index out of bounds: {} (valid: 0..{} or -{}..{})",
    idx, len - 1, len, -1));

// After
return index_err!("String index out of bounds: {} (valid: 0..{} or -{}..{})",
    idx, len - 1, len, -1);
// Produces: "IndexErr: String index out of bounds: 10 (valid: 0..4 or -5..-1)"
```

### Exception Type Distribution

After migration, all 863 error messages will follow consistent `ExceptionType: message` format:

| Exception Type | Count | Example |
|---|---|---|
| ArgErr | 582 | `"ArgErr: slice expects 2 arguments, got 1"` |
| RuntimeErr | 187 | `"RuntimeErr: Division by zero"` |
| TypeErr | 38 | `"TypeErr: Index must be Int, got Float"` |
| ValueErr | 16 | `"ValueErr: Invalid UTF-8 in bytes"` |
| AttrErr | 12 | `"AttrErr: Type Foo has no method 'bar'"` |
| IndexErr | 10 | `"IndexErr: String index out of bounds: 10"` |
| IOErr | 7 | `"IOErr: File not found: foo.txt"` |
| NameErr | 6 | `"NameErr: Undefined function: foo"` |
| ImportErr | 3 | `"ImportErr: Failed to load module 'foo'"` |
| KeyErr | 2 | `"KeyErr: Key 'x' not found in dict"` |
| **Total** | **863** | |

## Breaking Changes

This QEP introduces **breaking changes** to Quest's exception system:

### 1. String-Based Raise Removed

**OLD:** `raise "some error message"` (string)
**NEW:** `raise Err.new("some error message")` (object implementing `Error` trait)

All code using string-based `raise` will break with a runtime error:
```quest
raise "error"  # RuntimeErr: Cannot raise type 'str' - must implement Error trait
```

### 2. Exception Types Changed

**OLD:** Exception types were parsed from message text inconsistently
- `e.type()` returned `"String index out of bounds"` (not a real type)

**NEW:** Exception types are proper typed values
- `e.type()` returns `"IndexErr"` (real exception type)

### 3. Test Framework Changes

**OLD:** Tests incorrectly used `assert_raises(nil, ...)` which never worked
**NEW:** Tests must use `assert_raises(Err, ...)` for "any error" or specific types

Example:
```quest
# OLD (broken)
test.assert_raises(nil, fun () arr[100] end, nil)

# NEW (correct)
test.assert_raises(Err, fun () arr[100] end, nil)
test.assert_raises(IndexErr, fun () arr[100] end, nil)  # or specific type
```

### 4. Catch Clause Matching

**OLD:** Catch clauses matched against parsed message prefixes
**NEW:** Catch clauses match against proper exception types

Example:
```quest
# OLD catch patterns won't work
catch e: "String index out of bounds"  # Won't match anything

# NEW catch patterns
catch e: IndexErr  # Matches IndexErr
catch e: Err       # Matches all exceptions
```

### 5. Rust Error Sites

**OLD:** Free-form error strings: `Err(format!("..."))`
**NEW:** Typed error macros: `index_err!("...")`

All 863 error sites in Rust code must be updated to use typed macros.

### Migration Required

All existing Quest code using exceptions must be updated:
1. Replace `raise "string"` with `raise ExceptionType.new("string")`
2. Update `assert_raises(nil, ...)` to `assert_raises(Err, ...)`
3. Update catch clauses to use proper exception type names
4. Review any code that parses `e.type()` output

## Alternatives Considered

### Alternative 1: Keep Current String System

**Rejected because:**
- Tests are broken (cannot assert "any error")
- Cannot catch by category
- String parsing is fragile
- No type safety
- Inconsistent error formats

### Alternative 2: Use Result<T, QException> Everywhere

Instead of `Result<T, String>`, use `Result<T, QException>`:

```rust
pub fn eval_pair(pair: Pair<Rule>, scope: &mut Scope) -> Result<QValue, QException> {
    // ...
}
```

**Rejected because:**
- Massive breaking change (100+ function signatures)
- Adds complexity to error handling
- Still need string conversion for Rust `?` operator interop
- Doesn't solve the core problem (need typed exceptions anyway)

**Better:** Keep `Result<T, String>` and parse at try/catch boundaries (current proposal).

### Alternative 3: No Exception Hierarchy

Just have flat exception types, no subtype relationships:

```rust
pub enum ExceptionType {
    IndexErr,
    TypeErr,
    // ... etc
}

// No is_subtype_of() method
// catch e: Err doesn't exist
```

**Rejected because:**
- Cannot catch "all errors" with a single catch
- No fallback handling
- Less flexible than Python/Ruby/Java conventions
- Users expect hierarchical catching

## Testing

### Unit Tests

Add tests for exception type system:

```rust
// src/types/exception.rs

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exception_type_names() {
        assert_eq!(ExceptionType::IndexErr.name(), "IndexErr");
        assert_eq!(ExceptionType::Err.name(), "Err");
        assert_eq!(ExceptionType::Custom("MyError".into()).name(), "MyError");
    }

    #[test]
    fn test_exception_type_parsing() {
        assert_eq!(ExceptionType::from_str("IndexErr"), ExceptionType::IndexErr);
        assert_eq!(ExceptionType::from_str("CustomError"), ExceptionType::Custom("CustomError".into()));
    }

    #[test]
    fn test_exception_subtyping() {
        let index_error = ExceptionType::IndexErr;
        let error = ExceptionType::Err;

        // IndexErr is subtype of Err
        assert!(index_error.is_subtype_of(&error));

        // Err is subtype of itself
        assert!(error.is_subtype_of(&error));

        // IndexErr is not subtype of TypeErr
        assert!(!index_error.is_subtype_of(&ExceptionType::TypeErr));
    }
}
```

### Integration Tests

Add Quest-level tests:

```quest
use "std/test"

test.module("Exception Type System")

test.describe("Typed exceptions", fun ()
    test.it("catches specific exception types", fun ()
        let caught_type = nil
        try
            "hello"[10]
        catch e: IndexErr
            caught_type = "IndexErr"
        end
        test.assert_eq(caught_type, "IndexErr")    end)

    test.it("catches base Err type", fun ()
        let caught = false
        try
            "hello"[10]
        catch e: Err
            caught = true
        end
        test.assert(caught, "Should catch IndexErr via Err base type")
    end)

    test.it("matches most specific catch first", fun ()
        let which = nil
        try
            "hello"[10]
        catch e: IndexErr
            which = "specific"
        catch e: Err
            which = "general"
        end
        test.assert_eq(which, "specific")    end)

    test.it("falls through to general catch", fun ()
        let which = nil
        try
            1 / 0  # RuntimeError or ValueErr
        catch e: IndexErr
            which = "specific"
        catch e: Err
            which = "general"
        end
        test.assert_eq(which, "general")    end)
end)

test.describe("Test framework", fun ()
    test.it("assert_raises works with base Err type", fun ()
        # This should pass - Err matches all exceptions
        test.assert_raises(Err, fun () "hello"[10] end, nil)
    end)

    test.it("assert_raises works with specific types", fun ()
        test.assert_raises(IndexErr, fun () "hello"[10] end, nil)
        test.assert_raises(TypeErr, fun () "hello"["x"] end, nil)
    end)

    test.it("assert_error helper works", fun ()
        test.assert_error(fun () "hello"[10] end, nil)
    end)
end)
```

## Implementation Timeline

### Week 1: Foundation
- **Day 1-2:** Create `ExceptionType` enum and update `QException` struct
- **Day 3:** Add error raising macros
- **Day 4-5:** Update exception parsing and catch matching

### Week 2: Migration (863 error sites)
- **Day 1-2:** Migrate ArgumentError sites (582)
- **Day 3:** Migrate RuntimeError sites (187)
- **Day 4:** Migrate TypeErr/ValueErr/AttributeError (66 sites)
- **Day 5:** Migrate IndexErr/IOError/NameError/ImportError/KeyError (28 sites)

### Week 3: Testing & Documentation
- **Day 1:** Update test framework (`assert_raises`, add `assert_error`)
- **Day 2-3:** Update all test files to use typed exceptions
- **Day 4:** Write documentation (docs/exceptions.md, update guides)
- **Day 5:** Final testing and cleanup

**Total:** 3 weeks for complete implementation and migration.

## Success Criteria

1. ✅ All 863 error sites use typed exception macros
2. ✅ Exception parsing uses `ExceptionType` enum
3. ✅ `catch e: Err` catches all exceptions
4. ✅ `catch e: IndexErr` catches only index errors
5. ✅ Test framework `assert_raises(Err, ...)` works correctly
6. ✅ All existing tests pass
7. ✅ QEP-036 bracket indexing tests pass (15/23 → 23/23)
8. ✅ Documentation complete

## Summary

This QEP replaces Quest's ad-hoc string-based error system with proper typed exceptions. The benefits include:

- ✅ **Type-safe error handling** - catch exceptions by category
- ✅ **Hierarchical catching** - `catch e: Err` matches all exceptions
- ✅ **Better testing** - `assert_raises(Err, ...)` and `assert_raises(IndexErr, ...)`
- ✅ **Consistent format** - all errors follow `ExceptionType: message` pattern
- ✅ **Backwards compatible** - existing code continues to work
- ✅ **Easy migration** - macros + automated refactoring
- ✅ **Fixes broken tests** - QEP-036 bracket indexing tests now pass

The implementation is straightforward: add type enum, update parsing, migrate error sites, fix test framework. The entire migration can be done in 3 weeks with zero breaking changes.

**Recommendation:** Approve and implement. This foundational improvement benefits the entire language.
