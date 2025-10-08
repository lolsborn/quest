# QEP-038: Trait-Based Exception Validation

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Related:** [QEP-037: Typed Exceptions](qep-037-typed-exceptions.md)

## Abstract

Enforce that custom exception types implement the `Error` trait before they can be raised. This adds compile-time safety to the exception system and ensures all custom exceptions provide a consistent interface.

**Rating:** 7/10 - Important for type safety

## Motivation

### Current Problem

Quest currently allows **any struct** to be raised as an exception:

```quest
type MyRandomType
    foo: str
    bar: Int
end

# This works but shouldn't!
raise MyRandomType.new(foo: "test", bar: 42)
```

This creates several issues:

1. **No standard interface** - Different exception types may have different field names (`msg` vs `message` vs `error_text`)
2. **Runtime confusion** - Catching and handling exceptions becomes inconsistent
3. **Poor error messages** - No guarantee that exceptions can be formatted properly
4. **Type safety gap** - The trait system exists but isn't enforced for exceptions

### Desired Behavior

Only types implementing the `Error` trait should be raiseable:

```quest
trait Error
    fun message() -> str
end

type MyError
    pub message: str

    impl Error
        fun message() self.message end
    end
end

# ✓ This works - implements Error
raise MyError.new(message: "Something went wrong")

# ✗ This fails - doesn't implement Error
type NotAnError
    data: Int
end

raise NotAnError.new(data: 42)  # Error: NotAnError doesn't implement Error trait
```

## Design

### Error Trait Definition

The `Error` trait should be defined in the Quest standard library (built-in):

```quest
trait Error
    fun message() -> str
end
```

**Required methods:**
- `message()` - Returns a string description of the error

**Optional methods** (for future enhancement):
- `cause()` - Returns the underlying cause (another exception)
- `stack()` - Returns stack trace information

### Built-in Exception Types

All built-in exception types automatically implement `Error`:

```quest
# Built-in types (implemented in Rust, exposed as Quest types):
# Err, ValueError, TypeError, IndexErr, KeyErr, ArgErr, AttrErr,
# NameErr, RuntimeErr, IOErr, ImportErr, SyntaxErr

# All have:
let e = IndexErr.new("Index 0 out of bounds")
e.message()  # "Index 0 out of bounds"
e.does(Error)  # true
```

### Validation Points

Exception trait validation occurs at two points:

#### 1. Raise Statement (Runtime)

When `raise` is executed with a custom struct:

```rust
// In src/main.rs, Rule::raise_statement handler
QValue::Struct(s) => {
    // Check if the type implements Error trait
    if let Some(qtype) = find_type_definition(&s.type_name, scope) {
        if !qtype.implemented_traits.contains(&"Error".to_string()) {
            return type_err!(
                "Cannot raise type '{}' - must implement Error trait",
                s.type_name
            );
        }

        // Call .message() method to get error message
        let msg = call_instance_method(&s, "message", vec![], scope)?
            .as_str();

        return Err(format!("{}: {}", s.type_name, msg));
    } else {
        return type_err!("Type {} not found", s.type_name);
    }
}
```

#### 2. Catch Clause (Runtime)

When catching typed exceptions, verify the type implements `Error`:

```quest
catch e: MyCustomError
    # At this point, MyCustomError must implement Error
    puts(e.message())
end
```

## Implementation Plan

### Phase 1: Define Error Trait (Built-in)

Create `Error` trait as a built-in type (similar to how built-in exception types work):

```rust
// In src/exception_types.rs or similar
pub fn create_error_trait() -> QTrait {
    let required_methods = vec![
        TraitMethod::new(
            "message".to_string(),
            Vec::new(),  // No parameters
            Some("str".to_string())  // Returns str
        ),
    ];

    QTrait::with_doc(
        "Error".to_string(),
        required_methods,
        Some("Base trait for all exception types".to_string())
    )
}
```

Register in global scope at startup:

```rust
// In main.rs initialization
scope.declare("Error", QValue::Trait(create_error_trait()))?;
```

### Phase 2: Update Built-in Exceptions

Mark all built-in exception types as implementing `Error`:

```rust
// In exception type constructors
impl ExceptionType {
    pub fn to_quest_type(&self) -> QType {
        let mut qtype = QType::with_doc(
            self.name().to_string(),
            vec![
                FieldDef::public("message".to_string(), Some("str".to_string()), false),
            ],
            Some(format!("{} exception type", self.name()))
        );

        // Mark as implementing Error trait
        qtype.add_trait("Error".to_string());

        qtype
    }
}
```

### Phase 3: Add Validation to Raise Statement

Update the `raise_statement` handler in `src/main.rs`:

```rust
Rule::raise_statement => {
    // ... existing code ...

    QValue::Struct(s) => {
        // ✅ NEW: Validate Error trait implementation
        if let Some(qtype) = find_type_definition(&s.type_name, scope) {
            if !qtype.implemented_traits.contains(&"Error".to_string()) {
                return type_err!(
                    "Cannot raise type '{}' that doesn't implement Error trait",
                    s.type_name
                );
            }

            // Call the message() method (required by Error trait)
            let message_result = if let Some(message_method) = qtype.get_method("message") {
                // Create scope with 'self' bound
                let mut method_scope = Scope::new();
                method_scope.declare("self", QValue::Struct(s.clone()))?;
                call_user_function(message_method, vec![], &mut method_scope)?
            } else {
                // Fallback to field access (for backwards compat during migration)
                s.fields.get("message")
                    .cloned()
                    .unwrap_or(QValue::Str(QString::new("No message".to_string())))
            };

            let msg = message_result.as_str();
            return Err(format!("{}: {}", s.type_name, msg));
        } else {
            return type_err!("Type {} not found", s.type_name);
        }
    }

    // ... rest of code ...
}
```

### Phase 4: Add Validation to Catch Clauses

When catching typed exceptions, verify at runtime:

```rust
// In catch clause handling
if let Some(exception_type_name) = &catch_type {
    // Look up the type to verify it implements Error
    if let Some(qtype) = find_type_definition(exception_type_name, scope) {
        if !qtype.implemented_traits.contains(&"Error".to_string()) {
            return type_err!(
                "Cannot catch type '{}' that doesn't implement Error trait",
                exception_type_name
            );
        }
    }
}
```

### Phase 5: Update Documentation

Update CLAUDE.md and exception documentation:

```quest
# Creating Custom Exceptions

All custom exception types must implement the Error trait:

trait Error
    fun message() -> str
end

type ValidationError
    pub field: str
    pub reason: str

    impl Error
        fun message()
            "Validation failed for " .. self.field .. ": " .. self.reason
        end
    end
end

# Usage
raise ValidationError.new(field: "email", reason: "invalid format")

# Catching
try
    validate_email(email)
catch e: ValidationError
    puts("Validation error: " .. e.message())
end
```

## Examples

### Example 1: Simple Custom Exception

```quest
type NetworkError
    pub url: str
    pub status_code: Int

    impl Error
        fun message()
            "Network request to " .. self.url .. " failed with status " .. self.status_code.str()
        end
    end
end

# Usage
fun fetch_data(url)
    if status != 200
        raise NetworkError.new(url: url, status_code: status)
    end
end

# Catching
try
    fetch_data("https://api.example.com")
catch e: NetworkError
    puts("Request failed: " .. e.message())
    puts("URL was: " .. e.url)
    puts("Status: " .. e.status_code.str())
end
```

### Example 2: Exception Hierarchy

```quest
# Base custom exception
type AppError
    pub context: str

    impl Error
        fun message()
            "Application error: " .. self.context
        end
    end
end

# Specific exceptions (future: could have subtype relationships)
type DatabaseError
    pub query: str
    pub db_message: str

    impl Error
        fun message()
            "Database error executing query: " .. self.db_message
        end
    end
end

type AuthenticationError
    pub username: str

    impl Error
        fun message()
            "Authentication failed for user: " .. self.username
        end
    end
end

# Catching
try
    perform_operation()
catch e: DatabaseError
    log_database_error(e)
catch e: AuthenticationError
    redirect_to_login()
catch e: Err  # Catch all other errors
    log_generic_error(e)
end
```

### Example 3: Exception with Cause Chain

```quest
type ConfigError
    pub config_key: str
    pub inner_error: str

    impl Error
        fun message()
            "Configuration error for key '" .. self.config_key .. "': " .. self.inner_error
        end
    end
end

fun load_config(key)
    try
        parse_value(get_env(key))
    catch e: Err
        raise ConfigError.new(
            config_key: key,
            inner_error: e.message()
        )
    end
end
```

## Error Messages

### Exception Doesn't Implement Error

```
TypeErr: Cannot raise type 'MyType' that doesn't implement Error trait
  at line 42 in my_file.q

Hint: Add 'impl Error' block to MyType:

  type MyType
      message: str

      impl Error
          fun message() self.message end
      end
  end
```

### Catch of Non-Error Type

```
TypeErr: Cannot catch type 'MyType' that doesn't implement Error trait
  at line 15: catch e: MyType

Types in catch clauses must implement the Error trait.
```

## Backwards Compatibility

### Migration Path

Existing code that raises structs without Error trait will break. Provide migration:

1. **Deprecation Warning Period** (optional, if feasible)
   - Add warning when raising non-Error types
   - Give users time to migrate

2. **Auto-migration for Simple Cases**
   ```quest
   # Before (breaks in QEP-038)
   type MyError
       message: str
   end

   # After (add impl block)
   type MyError
       message: str

       impl Error
           fun message() self.message end
       end
   end
   ```

3. **Built-in Types Unaffected**
   All built-in exception types (`IndexErr`, `ValueError`, etc.) automatically work.

### String Raises Still Work

For backwards compatibility, string-based raises remain supported:

```quest
raise "Something went wrong"  # Still works (treated as RuntimeErr)
```

## Benefits

1. **Type Safety** - Compile-time guarantee that exceptions have consistent interface
2. **Better Error Messages** - All exceptions guaranteed to have `.message()` method
3. **Clearer Intent** - Explicit declaration that a type is meant to be an exception
4. **IDE Support** - Type checkers/IDEs can validate exception usage
5. **Documentation** - Self-documenting code (seeing `impl Error` makes intent clear)

## Limitations

1. **Breaking Change** - Existing code that raises non-Error types will break
2. **Boilerplate** - Requires adding `impl Error` block to custom exceptions
3. **Runtime Check** - Validation happens at runtime, not parse time (Quest doesn't have static type checking)

## Future Enhancements

### 1. Exception Subtyping

Allow creating exception hierarchies:

```quest
trait AppError extends Error
    fun severity() -> str
end

type CriticalError
    impl AppError
        fun message() "Critical error occurred" end
        fun severity() "CRITICAL" end
    end
end
```

### 2. Optional Error Methods

Add optional methods to Error trait:

```quest
trait Error
    fun message() -> str
    fun cause() -> Error?      # Optional: underlying cause
    fun stack() -> array       # Optional: stack trace
    fun severity() -> str      # Optional: error severity
end
```

### 3. Parse-Time Validation

If Quest adds static type checking, validate Error trait at parse time instead of runtime.

## Implementation Checklist

- [ ] Define `Error` trait as built-in type
- [ ] Register Error trait in global scope at startup
- [ ] Mark all built-in exception types as implementing Error
- [ ] Add validation to `raise_statement` handler
- [ ] Add validation to `catch_clause` handler
- [ ] Update error messages with helpful hints
- [ ] Create migration guide for existing code
- [ ] Update test suite (add positive and negative tests)
- [ ] Update CLAUDE.md with Error trait requirements
- [ ] Update exception documentation

## Testing Strategy

```quest
# Test file: test/exceptions/error_trait_test.q

test.describe("Error Trait Validation", fun ()
    test.it("allows raising types that implement Error", fun ()
        type GoodError
            pub message: str
            impl Error
                fun message() self.message end
            end
        end

        test.assert_raises(GoodError, fun ()
            raise GoodError.new(message: "test")
        end, nil)
    end)

    test.it("rejects raising types that don't implement Error", fun ()
        type BadError
            message: str
        end

        test.assert_raises(TypeErr, fun ()
            raise BadError.new(message: "test")
        end, "Should reject non-Error type")
    end)

    test.it("built-in exceptions work without explicit impl", fun ()
        test.assert_raises(RuntimeErr, fun ()
            raise RuntimeErr.new("test")
        end, nil)
    end)

    test.it("rejects catching non-Error types", fun ()
        type NotAnError
            data: Int
        end

        test.assert_raises(TypeErr, fun ()
            try
                raise RuntimeErr.new("test")
            catch e: NotAnError
                puts(e)
            end
        end, "Should reject non-Error in catch")
    end)
end)
```

## See Also

- [QEP-037: Typed Exceptions](qep-037-typed-exceptions.md) - Foundation for this enhancement
- Quest Traits Documentation - How trait implementation works
- Error Handling Guide - Best practices for exceptions

## References

- Rust's `Error` trait system
- Java's `Throwable` interface requirement
- Python's `BaseException` class hierarchy
- Go's `error` interface

## Copyright

This document is placed in the public domain.
