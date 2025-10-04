# Type Validation System

**Status:** Proposed
**Version:** 1.0
**Last Updated:** 2025-10-03

## Overview

Quest provides a comprehensive validation system inspired by Pydantic, allowing types to declare optional fields, field validators, and built-in validation rules. Validation occurs automatically during type construction, ensuring data integrity at the boundary.

## Motivation

**Problem:** Current type system lacks validation capabilities:
1. No way to mark fields as optional vs required
2. No field-level validation (ranges, formats, patterns)
3. No cross-field validation
4. Manual validation code scattered throughout applications
5. Poor error messages for invalid data

**Solution:** Integrate validation directly into the type system using declarative validators, providing clear error messages and automatic validation on construction.

## Core Concepts

### 1. Object Initialization and Validation

Quest types support multiple initialization patterns, all with automatic validation:

#### Pattern 1: Named Arguments (Traditional)

```quest
type User
    str: name
    str: email
    num?: age
end

# Create instance with named arguments
let user = User.new(name: "Alice", email: "alice@example.com", age: 30)
```

**When to use:** Creating objects in code with known field values.

#### Pattern 2: Dictionary-Based (Positional Dict)

```quest
# Pass a dict as the first argument
let data = {"name": "Alice", "email": "alice@example.com", "age": 30}
let user = User.new(data)  # Pass dict directly to .new()
```

**When to use:** When you have a dict from external sources (API response, config file, etc.).

#### Pattern 3: model_validate() (Explicit Validation)

```quest
# Explicit validation method
let data = {"name": "Alice", "email": "alice@example.com", "age": 30}
let user = User.model_validate(data)  # Semantically clearer for validation
```

**When to use:** When validating external/untrusted data (JSON, user input, API requests).

**Key differences:**
- `User.new(data)` and `User.model_validate(data)` are functionally identical
- `model_validate()` makes validation intent explicit (preferred for external data)
- Both run the same validation logic
- Both raise `ValidationError` on invalid data

#### Validation is Always Enforced

**Critical:** All three initialization patterns enforce validation. Invalid data **always raises an exception** - no partially-constructed or invalid instances are ever created.

```quest
use "std/validate" as v

type User
    str: name
    str: email
    num?: age

    fun validate_email(value)
        v.email()(value)
    end

    fun validate_age(value)
        v.optional(v.range(13, 120))(value)
    end
end

# All three patterns validate the same way:

# 1. Named arguments - validation exception on invalid email
try
    let u1 = User.new(name: "Alice", email: "invalid", age: 25)
catch e: ValidationError
    puts("Validation error: ", e.message())  # "Field 'email' validation failed: Invalid email format"
end

# 2. Dict to .new() - validation exception on age out of range
try
    let u2 = User.new({"name": "Bob", "email": "bob@example.com", "age": 999})
catch e: ValidationError
    puts("Validation error: ", e.message())  # "Field 'age' validation failed: Value must be between 13 and 120"
end

# 3. model_validate() - validation exception on missing required field
try
    let u3 = User.model_validate({"name": "Charlie"})
catch e: ValidationError
    puts("Validation error: ", e.message())  # "Missing required field 'email' for type 'User'"
end

# Success: All validations pass
let u4 = User.new(name: "Dave", email: "dave@example.com", age: 30)
puts("Created user: ", u4.email)  # "dave@example.com"
```

**Validation sequence:**
1. Check required fields are present
2. Check type annotations match (str, num, bool, etc.)
3. Run `validate_before_model()` hook (if defined)
4. Run field validators (`validate_<field_name>`)
5. Run `validate_after_model()` hook (if defined)
6. Return valid instance OR raise `ValidationError`

**Exception types:**
- `ValidationError` - Base type for all validation failures
  - Has `.message()` method returning error message string
  - Has `.errors()` method returning structured error details (Pydantic-style)
- Subtypes may include: `MissingFieldError`, `TypeMismatchError`, `ConstraintError`

**ValidationError structure:**
```quest
try
    let user = User.new({"email": "invalid", "age": 999})
catch e: ValidationError
    puts(e.message())  # Human-readable summary

    # Structured error details
    let errors = e.errors()
    # Returns array of error dicts:
    # [
    #   {
    #     "type": "email",
    #     "loc": ["email"],
    #     "msg": "Invalid email format",
    #     "input": "invalid"
    #   },
    #   {
    #     "type": "value_error",
    #     "loc": ["age"],
    #     "msg": "Value must be between 13 and 120",
    #     "input": 999
    #   }
    # ]
end
```

### 2. The Validates Trait

Types automatically implement the `Validates` trait:

```quest
trait Validates
    fun model_validate(data)
end
```

**Implementation details:**
- All types with fields automatically get `model_validate()` as a static method
- `model_validate()` accepts a dict and returns a validated instance
- Internally calls the same validation logic as `Type.new()`

**Practical example - JSON API validation:**
```quest
use "std/encoding/json" as json
use "std/validate" as v

type CreateUserRequest
    str: username
    str: email
    str: password

    fun validate_email(value)
        v.email()(value.lower())
    end

    fun validate_password(value)
        v.min_length(8)(value)
    end
end

fun handle_create_user(json_body)
    try
        # Parse JSON string to dict
        let data = json.parse(json_body)

        # Validate dict to typed object (raises ValidationError if invalid)
        let request = CreateUserRequest.model_validate(data)

        # At this point, request is guaranteed valid
        # Safe to use without additional checks
        let user = create_user_in_db(request.username, request.email, request.password)

        # Serialize response
        return {status: 201, body: user.json()}
    catch e: ValidationError
        # Invalid request data
        return {status: 400, body: json.stringify({"error": e.message()})}
    catch e: JsonParseError
        # Malformed JSON
        return {status: 400, body: json.stringify({"error": "Invalid JSON"})}
    catch e
        # Database or other error
        return {status: 500, body: json.stringify({"error": "Internal server error"})}
    end
end

# Example usage
let response = handle_create_user('{"username": "alice", "email": "alice@example.com", "password": "secret123"}')
puts(response.status)  # 201

let bad_response = handle_create_user('{"username": "bob", "email": "invalid"}')
puts(bad_response.status)  # 400 - missing password and invalid email
```

### 3. JSON Serialization

All QObjects have a `.json()` method that produces a JSON representation:

```quest
type Person
    str: name
    num: age
end

let person = Person.new(name: "Alice", age: 30)
puts(person.json())  # {"name": "Alice", "age": 30}

# Arrays
let numbers = [1, 2, 3]
puts(numbers.json())  # [1, 2, 3]

# Nested structures
type Address
    str: city
    str: state
end

type Customer
    str: name
    Address: address
end

let customer = Customer.new(
    name: "Bob",
    address: Address.new(city: "Portland", state: "OR")
)
puts(customer.json())  # {"name": "Bob", "address": {"city": "Portland", "state": "OR"}}
```

**JSON serialization rules:**
- `Num` → JSON number
- `Str` → JSON string
- `Bool` → JSON boolean
- `Nil` → JSON null
- `Array` → JSON array (recursively serialize elements)
- `Dict` → JSON object (recursively serialize values)
- `Struct` → JSON object with field names as keys
- `Bytes` → Base64-encoded string
- `Uuid` → Hyphenated string format

**Round-trip validation:**
```quest
use "std/encoding/json" as json

type Product
    str: name
    num: price
end

let product = Product.new(name: "Widget", price: 19.99)

# Serialize to JSON string
let json_str = product.json()

# Parse back to dict
let data = json.parse(json_str)

# Validate back to Product
let restored = Product.model_validate(data)

puts(restored.name)   # "Widget"
puts(restored.price)  # 19.99
```

### 4. Optional Fields

Fields can be marked as optional using the `?` suffix:

```quest
type User
    str: name           # Required
    num: age           # Required
    str?: email        # Optional (defaults to nil)
    str?: bio          # Optional (defaults to nil)
end
```

**Behavior:**
- Required fields must be provided during construction
- Optional fields default to `nil` if not provided
- Type checking still applies when value is provided

### 5. Field Validators

Validators are defined as methods with the naming pattern `validate_<field_name>`:

```quest
type User
    str: name
    num: age
    str?: email

    fun validate_age(value)
        if value < 0 or value > 150
            raise ValueError("Age must be between 0 and 150")
        end
        value
    end

    fun validate_email(value)
        if value != nil and not value.contains("@")
            raise ValueError("Invalid email format")
        end
        value
    end
end
```

**Validator rules:**
- Method name must be `validate_<field_name>`
- Takes field value as single argument
- Returns validated/transformed value
- Raises exception for invalid values
- Runs during construction (after type checking)
- **Only one validator per field** - but it can call multiple validation functions

**Multiple validators with composition:**
```quest
use "std/validate" as v

type User
    str: username
    str: email

    fun validate_username(value)
        # Single method, multiple validators composed
        v.all([
            v.min_length(3),
            v.max_length(20),
            v.alphanumeric()
        ])(value)
    end

    fun validate_email(value)
        # Transform then validate
        let normalized = value.lower().trim()
        v.email()(normalized)
    end
end
```

### 6. Built-in Validators

Quest provides a library of common validators via the `std/validate` module:

```quest
use "std/validate" as v

type Product
    str: name
    num: price
    str: sku
    num: stock
    str?: description

    fun validate_price(value)
        v.min(0)(value)
    end

    fun validate_sku(value)
        v.pattern("^[A-Z]{3}-\\d{4}$")(value)
    end

    fun validate_stock(value)
        v.range(0, 10000)(value)
    end

    fun validate_description(value)
        v.optional(v.max_length(500))(value)
    end
end
```

## Syntax

### Type Declaration with Validation

**Basic structure:**
```quest
type TypeName
    type_annotation: field_name
    type_annotation?: optional_field

    # Field validator: validate_<field_name>
    fun validate_field_name(value)
        # Validation logic
        value  # Return validated value
    end

    # Cross-field validator: validate()
    fun validate()
        # Access self.field_name
        # Validate relationships between fields
    end

    # Regular methods
    fun method_name()
        # Implementation
    end
end
```

### Required vs Optional Fields

```quest
type Person
    str: name          # Required: must provide during construction
    num: age           # Required
    str?: email        # Optional: can be nil
    str?: phone        # Optional: can be nil
end

# Valid constructions
let p1 = Person.new(name: "Alice", age: 30)
let p2 = Person.new(name: "Bob", age: 25, email: "bob@example.com")

# Invalid - missing required field
let p3 = Person.new(name: "Charlie")  # Error: Missing required field 'age'
```

### Field Validators

**Simple validator:**
```quest
type Account
    str: username
    num: balance

    fun validate_balance(value)
        if value < 0
            raise ValueError("Balance cannot be negative")
        end
        value
    end
end
```

**Validator with transformation:**
```quest
type User
    str: email
    str: name

    fun validate_email(value)
        value.lower().trim()  # Transform to lowercase and trim
    end

    fun validate_name(value)
        value.trim().capitalize()
    end
end
```

**Optional field validator:**
```quest
type Profile
    str: username
    str?: bio

    fun validate_bio(value)
        if value != nil and value.len() > 500
            raise ValueError("Bio must be 500 characters or less")
        end
        value
    end
end
```

### Cross-Field Validation

Quest provides three hooks for validation that involves multiple fields:

#### 1. validate_before_model()

Runs **before** field validators. Has access to raw field values.

```quest
type User
    str: username
    str?: email
    str?: phone

    fun validate_before_model()
        # At least one contact method required
        if self.email == nil and self.phone == nil
            raise ValueError("Either email or phone is required")
        end
    end
end
```

#### 2. Field Validators (validate_<field_name>)

Run for each field individually. See previous section.

#### 3. validate_after_model()

Runs **after** field validators. Has access to validated/transformed field values.

```quest
type DateRange
    num: start_date
    num: end_date

    fun validate_after_model()
        if self.start_date > self.end_date
            raise ValueError("Start date must be before end date")
        end
    end
end

type PasswordReset
    str: password
    str: password_confirm

    fun validate_after_model()
        if self.password != self.password_confirm
            raise ValueError("Passwords do not match")
        end
    end
end
```

**Validation execution order:**
1. Check required fields present
2. Check type annotations
3. **Run `validate_before_model()`** (if defined)
4. Run field validators (`validate_<field_name>`)
5. **Run `validate_after_model()`** (if defined)
6. Return valid instance or raise error

**When to use each:**
- `validate_before_model()` - Conditional requirements (e.g., "email required if phone is nil")
- Field validators - Individual field validation and transformation
- `validate_after_model()` - Cross-field consistency checks using validated values

**Complete example with all three:**
```quest
use "std/validate" as v

type PaymentMethod
    str: type              # "card", "bank", "paypal"
    str?: card_number
    str?: card_cvv
    str?: bank_account
    str?: paypal_email

    fun validate_before_model()
        # Ensure type-specific fields are provided
        if self.type == "card"
            if self.card_number == nil or self.card_cvv == nil
                raise ValueError("Card payments require card_number and card_cvv")
            end
        elif self.type == "bank"
            if self.bank_account == nil
                raise ValueError("Bank payments require bank_account")
            end
        elif self.type == "paypal"
            if self.paypal_email == nil
                raise ValueError("PayPal payments require paypal_email")
            end
        end
    end

    fun validate_type(value)
        v.one_of(["card", "bank", "paypal"])(value)
    end

    fun validate_card_number(value)
        v.optional(v.pattern("^[0-9]{16}$"))(value)
    end

    fun validate_card_cvv(value)
        v.optional(v.pattern("^[0-9]{3,4}$"))(value)
    end

    fun validate_paypal_email(value)
        v.optional(v.email())(value)
    end

    fun validate_after_model()
        # Additional cross-field checks after individual validation
        if self.type == "card"
            # Ensure card number passes Luhn check
            if not luhn_check(self.card_number)
                raise ValueError("Invalid card number")
            end
        end
    end
end
```

## Built-in Validators

Quest provides a comprehensive validator library via the `std/validate` module:

### Numeric Validators

```quest
use "std/validate" as v

# Range validation
v.range(min, max)        # Value must be between min and max
v.min(value)              # Value must be >= min
v.max(value)              # Value must be <= max
v.positive()              # Value must be > 0
v.negative()              # Value must be < 0
v.non_negative()          # Value must be >= 0

# Example
type Product
    num: price
    num: quantity

    fun validate_price(value)
        v.positive()(value)
    end

    fun validate_quantity(value)
        v.range(0, 1000)(value)
    end
end
```

### String Validators

```quest
use "std/validate" as v

# Length validation
v.min_length(n)           # String length >= n
v.max_length(n)           # String length <= n
v.length_range(min, max)  # String length between min and max
v.exact_length(n)         # String length exactly n

# Pattern validation
v.pattern(regex)          # String matches regex
v.email()                 # Valid email format
v.url()                   # Valid URL format
v.uuid()                  # Valid UUID format

# Content validation
v.one_of(values)          # Value in allowed list
v.not_empty()             # String is not empty or whitespace-only
v.alpha()                 # Only alphabetic characters
v.alphanumeric()          # Only alphanumeric characters
v.numeric_string()        # String contains only digits

# Example
type User
    str: username
    str: email
    str: role

    fun validate_username(value)
        v.length_range(3, 20)(value)
        v.alphanumeric()(value)
    end

    fun validate_email(value)
        v.email()(value)
    end

    fun validate_role(value)
        v.one_of(["admin", "user", "guest"])(value)
    end
end
```

### Array Validators

```quest
use "std/validate" as v

# Size validation
v.min_items(n)            # Array has at least n items
v.max_items(n)            # Array has at most n items
v.items_range(min, max)   # Array size between min and max
v.not_empty_array()       # Array has at least 1 item

# Content validation
v.unique_items()          # All array items are unique
v.each(validator)         # Apply validator to each item

# Example
type Playlist
    str: name
    array: song_ids
    array: tags

    fun validate_song_ids(value)
        v.min_items(1)(value)
        v.unique_items()(value)
    end

    fun validate_tags(value)
        v.max_items(10)(value)
        v.each(v.max_length(20))(value)
    end
end
```

### Dict Validators

```quest
use "std/validate" as v

# Key validation
v.required_keys(keys)     # Dict must have these keys
v.allowed_keys(keys)      # Dict can only have these keys
v.min_keys(n)             # Dict has at least n keys

# Example
type Config
    dict: settings

    fun validate_settings(value)
        v.required_keys(["host", "port"])(value)
        v.allowed_keys(["host", "port", "debug", "timeout"])(value)
    end
end
```

### Optional Validators

```quest
use "std/validate" as v

# Wrap any validator to allow nil values
v.optional(validator)

# Example
type Person
    str: name
    str?: bio
    num?: age

    fun validate_bio(value)
        v.optional(v.max_length(500))(value)
    end

    fun validate_age(value)
        v.optional(v.range(0, 150))(value)
    end
end
```

### Composite Validators

Chain multiple validators together:

```quest
use "std/validate" as v

type User
    str: username
    str: password

    fun validate_username(value)
        v.all([
            v.min_length(3),
            v.max_length(20),
            v.pattern("^[a-zA-Z0-9_]+$")
        ])(value)
    end

    fun validate_password(value)
        v.all([
            v.min_length(8),
            v.pattern(".*[A-Z].*"),      # At least one uppercase
            v.pattern(".*[0-9].*"),      # At least one digit
            v.pattern(".*[^a-zA-Z0-9].*") # At least one special char
        ])(value)
    end
end
```

## Complete Examples

### Example 1: API Request Validation with JSON

```quest
use "std/validate" as v
use "std/encoding/json" as json

type CreateUserRequest
    str: username
    str: email
    str: password
    num?: age
    array?: tags

    fun validate_username(value)
        v.all([
            v.min_length(3),
            v.max_length(20),
            v.alphanumeric()
        ])(value)
    end

    fun validate_email(value)
        v.email()(value.lower())
    end

    fun validate_password(value)
        v.min_length(8)(value)
    end

    fun validate_age(value)
        v.optional(v.range(13, 120))(value)
    end

    fun validate_tags(value)
        v.optional(v.max_items(5))(value)
    end
end

# API handler
fun create_user_handler(request_body)
    try
        # Parse JSON request body
        let data = json.parse(request_body)

        # Validate using model_validate()
        let user_request = CreateUserRequest.model_validate(data)

        # Now we have a validated object - safe to use
        let new_user = create_user_in_db(
            user_request.username,
            user_request.email,
            user_request.password
        )

        # Serialize response
        return {
            status: 201,
            body: new_user.json()
        }
    catch e: ValidationError
        # Return validation errors to client
        return {
            status: 400,
            body: json.stringify({"error": e.message()})
        }
    catch e
        return {
            status: 500,
            body: json.stringify({"error": "Internal server error"})
        }
    end
end

# Example usage
let request = json.stringify({
    "username": "alice",
    "email": "ALICE@EXAMPLE.COM",
    "password": "secret123",
    "age": 25,
    "tags": ["developer", "admin"]
})

let response = create_user_handler(request)
puts(response.status)  # 201
```

### Example 2: User Registration

```quest
use "std/validate" as v

type UserRegistration
    str: username
    str: email
    str: password
    str: password_confirm
    num?: age
    str?: bio

    fun validate_username(value)
        v.all([
            v.min_length(3),
            v.max_length(20),
            v.alphanumeric()
        ])(value)
    end

    fun validate_email(value)
        v.email()(value.lower())  # Normalize to lowercase
    end

    fun validate_password(value)
        v.all([
            v.min_length(8),
            v.pattern(".*[A-Z].*"),
            v.pattern(".*[0-9].*")
        ])(value)
    end

    fun validate_age(value)
        v.optional(v.range(13, 120))(value)
    end

    fun validate_bio(value)
        v.optional(v.max_length(500))(value)
    end

    fun validate()
        if self.password != self.password_confirm
            raise ValueError("Passwords do not match")
        end
    end
end

# Usage
try
    let user = UserRegistration.new(
        username: "alice",
        email: "ALICE@example.com",
        password: "Secret123",
        password_confirm: "Secret123",
        age: 25
    )
    puts("User created: ", user.email)  # "alice@example.com"
catch e
    puts("Validation error: ", e.message())
end
```

### Example 3: Product Creation

```quest
use "std/validate" as v

type CreateProductRequest
    str: name
    num: price
    str: sku
    num: stock
    str?: description
    array: tags
    dict: metadata

    fun validate_name(value)
        v.all([
            v.not_empty(),
            v.max_length(200)
        ])(value.trim())
    end

    fun validate_price(value)
        v.positive()(value)
    end

    fun validate_sku(value)
        v.pattern("^[A-Z]{3}-\\d{4}$")(value.upper())
    end

    fun validate_stock(value)
        v.non_negative()(value)
    end

    fun validate_description(value)
        v.optional(v.max_length(1000))(value)
    end

    fun validate_tags(value)
        v.all([
            v.max_items(10),
            v.unique_items(),
            v.each(v.max_length(20))
        ])(value)
    end

    fun validate_metadata(value)
        v.allowed_keys(["category", "brand", "weight"])(value)
    end
end
```

### Example 4: Date Range with Cross-Validation

```quest
use "std/validate" as v

type EventSchedule
    num: start_timestamp
    num: end_timestamp
    num: capacity
    num: registered
    str: status

    fun validate_start_timestamp(value)
        v.positive()(value)
    end

    fun validate_end_timestamp(value)
        v.positive()(value)
    end

    fun validate_capacity(value)
        v.range(1, 10000)(value)
    end

    fun validate_registered(value)
        v.non_negative()(value)
    end

    fun validate_status(value)
        v.one_of(["draft", "open", "full", "closed"])(value)
    end

    fun validate()
        # Check dates
        if self.start_timestamp >= self.end_timestamp
            raise ValueError("Start time must be before end time")
        end

        # Check capacity limit
        if self.registered > self.capacity
            raise ValueError("Registered count cannot exceed capacity")
        end

        # Check status consistency
        if self.status == "full" and self.registered < self.capacity
            raise ValueError("Status 'full' requires registered >= capacity")
        end
    end
end
```

### Example 5: Nested Type Validation

```quest
use "std/validate" as v

type Address
    str: street
    str: city
    str: state
    str: zip_code

    fun validate_zip_code(value)
        v.pattern("^\\d{5}(-\\d{4})?$")(value)
    end
end

type ContactInfo
    str: email
    str?: phone

    fun validate_email(value)
        v.email()(value)
    end

    fun validate_phone(value)
        v.optional(v.pattern("^\\+?[0-9]{10,15}$"))(value)
    end
end

type Customer
    str: name
    Address: address          # Nested type
    ContactInfo: contact      # Nested type
    num: account_balance

    fun validate_name(value)
        v.not_empty()(value.trim())
    end

    fun validate_account_balance(value)
        v.non_negative()(value)
    end
end

# Usage with nested validation
let customer = Customer.new(
    name: "Alice Johnson",
    address: Address.new(
        street: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip_code: "62701"
    ),
    contact: ContactInfo.new(
        email: "alice@example.com",
        phone: "+15551234567"
    ),
    account_balance: 0.0
)
```

## Implementation Details

### QObj Trait Extension

The `QObj` trait is extended with the `json()` method:

```rust
pub trait QObj {
    fn cls(&self) -> String;
    fn q_type(&self) -> &'static str;
    fn is(&self, type_name: &str) -> bool;
    fn _str(&self) -> String;
    fn _rep(&self) -> String;
    fn _doc(&self) -> String;
    fn _id(&self) -> u64;

    // New: JSON serialization
    fn json(&self) -> String;
}
```

All QValue types must implement this method.

### Validates Trait

The `Validates` trait is defined in the standard library:

```rust
// In std/validate module or core
pub trait Validates {
    fn model_validate(&self, data: QValue) -> Result<QValue, String>;
}

// All QType instances automatically implement Validates
impl Validates for QType {
    fn model_validate(&self, data: QValue) -> Result<QValue, String> {
        let dict = match data {
            QValue::Dict(d) => d.to_hashmap(),
            _ => return Err("model_validate() requires a dict argument".to_string())
        };
        construct_type_instance(self, dict)
    }
}
```

**Note:** In Quest code, users don't explicitly implement the `Validates` trait. All types with fields automatically get `model_validate()` as a static method.

### Grammar Changes

**Add optional field syntax:**
```pest
type_field = {
    type_annotation ~ optional_marker? ~ ":" ~ identifier
}

optional_marker = { "?" }

type_annotation = {
    identifier  # "str", "num", "bool", "MyType", etc.
}
```

**No changes needed for validators** - they use existing method syntax. Validators are detected by naming convention:
- `validate_<field_name>` → field validator (e.g., `validate_email`, `validate_age`)
- `validate_before_model()` → pre-validation hook (runs before field validators)
- `validate_after_model()` → post-validation hook (runs after field validators)

**No changes needed for model_validate()** - automatically added as a static method to all types.

**No changes needed for json()** - automatically available via QObj trait.

### Type.new() Implementation

The `Type.new()` constructor supports both named arguments and dict arguments:

```rust
fn call_type_constructor(type_def: &QType, args: Vec<QValue>) -> Result<QValue, String> {
    // Check if single argument that can be converted to dict
    if args.len() == 1 {
        // Handle JSON types - only JsonObject is valid
        let arg = match &args[0] {
            QValue::JsonObject(json_obj) => {
                // Convert JSON object to Quest Dict
                json_object_to_dict(json_obj)?
            },
            QValue::JsonArray(_) => {
                return Err(format!(
                    "ValueError: Cannot construct type '{}' from JSON array. Expected JSON object.",
                    type_def.name
                ));
            },
            QValue::JsonString(_) | QValue::JsonNumber(_) | QValue::JsonBool(_) | QValue::JsonNull => {
                return Err(format!(
                    "ValueError: Cannot construct type '{}' from JSON primitive. Expected JSON object.",
                    type_def.name
                ));
            },
            other => other.clone()
        };

        // Check if we have a Dict (either original or converted)
        if let QValue::Dict(dict) = &arg {
            // Dict-based construction: User.new({"name": "Alice", ...})
            let fields_map = dict.to_hashmap();
            return construct_type_instance(type_def, fields_map);
        }
    }

    // Otherwise, expect named arguments
    // User.new(name: "Alice", age: 30)
    let fields_map = convert_named_args_to_map(args)?;
    construct_type_instance(type_def, fields_map)
}

fn json_object_to_dict(json_obj: &QJsonObject) -> Result<QValue, String> {
    // Convert JSON object to Quest dictionary
    // This happens BEFORE validation
    let mut dict_entries = HashMap::new();

    for (key, json_value) in json_obj.entries() {
        // Convert each JSON value to corresponding QValue
        let qvalue = match json_value {
            JsonValue::String(s) => QValue::Str(QString::new(s.clone())),
            JsonValue::Number(n) => QValue::Num(QNum::new(*n)),
            JsonValue::Bool(b) => QValue::Bool(QBool::new(*b)),
            JsonValue::Null => QValue::Nil(QNil::new()),
            JsonValue::Array(arr) => json_array_to_qarray(arr)?,
            JsonValue::Object(obj) => json_object_to_dict(&obj)?,
        };
        dict_entries.insert(key.clone(), qvalue);
    }

    Ok(QValue::Dict(QDict::new(dict_entries)))
}

fn convert_named_args_to_map(args: Vec<QValue>) -> Result<HashMap<String, QValue>, String> {
    // Parse named arguments from call
    // This is implementation-specific based on how named args are represented
    // In the AST during parsing
    todo!("Convert named arguments to HashMap")
}
```

**Key behaviors:**
1. If `args.len() == 1` and `args[0]` is a `JsonObject` → **convert to Dict first**, then validate
2. If `args.len() == 1` and `args[0]` is a `JsonArray`, `JsonString`, `JsonNumber`, `JsonBool`, or `JsonNull` → **raise ValueError**
3. If `args.len() == 1` and `args[0]` is a `Dict` → treat as dict-based construction
4. Otherwise → expect named arguments from call site
5. All valid paths call `construct_type_instance()` with a HashMap

**JSON to Dict conversion:**
- Only `JsonObject` can be converted to Dict for type construction
- Happens **before** validation starts
- Converts JSON types to Quest types:
  - JSON string → `QValue::Str`
  - JSON number → `QValue::Num`
  - JSON boolean → `QValue::Bool`
  - JSON null → `QValue::Nil`
  - JSON array → `QValue::Array` (recursively convert elements)
  - JSON object → `QValue::Dict` (recursively convert nested objects)
- After conversion, validation treats it like any other dict

**Invalid JSON type examples:**
```quest
use "std/encoding/json" as json

type User
    str: name
    num: age
end

# Valid: JSON object
let obj = json.parse('{"name": "Alice", "age": 30}')
let user = User.new(obj)  # OK - JsonObject converted to Dict

# Invalid: JSON array
let arr = json.parse('[1, 2, 3]')
try
    let user = User.new(arr)
catch e: ValueError
    puts(e.message())  # "Cannot construct type 'User' from JSON array. Expected JSON object."
end

# Invalid: JSON primitive (string)
let str_val = json.parse('"hello"')
try
    let user = User.new(str_val)
catch e: ValueError
    puts(e.message())  # "Cannot construct type 'User' from JSON primitive. Expected JSON object."
end

# Invalid: JSON primitive (number)
let num_val = json.parse('42')
try
    let user = User.new(num_val)
catch e: ValueError
    puts(e.message())  # "Cannot construct type 'User' from JSON primitive. Expected JSON object."
end
```

### Type Construction with Validation

```rust
fn construct_type_instance(
    type_def: &QType,
    args: HashMap<String, QValue>
) -> Result<QValue, String> {
    let mut fields = HashMap::new();

    // 1. Check all required fields are provided
    for field in &type_def.fields {
        if !field.optional && !args.contains_key(&field.name) {
            return Err(format!(
                "ValidationError: Missing required field '{}' for type '{}'",
                field.name,
                type_def.name
            ));
        }
    }

    // 2. Type check and set field values
    for field in &type_def.fields {
        let value = if let Some(val) = args.get(&field.name) {
            // Validate type annotation
            if !matches_type(val, &field.type_annotation) {
                return Err(format!(
                    "ValidationError: Type mismatch for field '{}': expected {}, got {}",
                    field.name,
                    field.type_annotation,
                    val.cls()
                ));
            }
            val.clone()
        } else if field.optional {
            QValue::Nil(QNil)
        } else {
            return Err(format!(
                "ValidationError: Missing required field '{}' for type '{}'",
                field.name,
                type_def.name
            ));
        };

        fields.insert(field.name.clone(), value);
    }

    // 3. Create instance
    let mut instance = QStruct::new(
        type_def.name.clone(),
        type_def.id,
        fields
    );

    // 4. Run validate_before_model() if defined
    if let Some(before_method) = type_def.methods.get("validate_before_model") {
        before_method.call_with_self(&instance)
            .map_err(|e| format!("ValidationError: Pre-validation failed: {}", e))?;
    }

    // 5. Run field validators (validate_<field_name> methods)
    for field in &type_def.fields {
        let validator_name = format!("validate_{}", field.name);
        if let Some(method) = type_def.methods.get(&validator_name) {
            let field_value = instance.get_field(&field.name)?;

            // Call validator - may raise ValidationError
            let validated_value = method.call(vec![field_value])
                .map_err(|e| format!("ValidationError: Field '{}' validation failed: {}", field.name, e))?;

            instance.set_field(&field.name, validated_value);
        }
    }

    // 6. Run validate_after_model() if defined
    if let Some(after_method) = type_def.methods.get("validate_after_model") {
        after_method.call_with_self(&instance)
            .map_err(|e| format!("ValidationError: Post-validation failed: {}", e))?;
    }

    Ok(QValue::Struct(instance))
}
```

**Key points:**
- All validation errors are prefixed with `"ValidationError:"` for consistent error handling
- Field validators that raise exceptions are caught and re-wrapped with context
- Type checking happens before any validation methods
- **Validation order:**
  1. Check required fields and type annotations
  2. Run `validate_before_model()` (conditional requirements)
  3. Run field validators `validate_<field_name>` (individual validation)
  4. Run `validate_after_model()` (cross-field consistency)
- **Validation failures raise exceptions** - no instance is created on validation failure

### model_validate() Implementation

The `model_validate()` method is a static method automatically added to all types:

```rust
impl QType {
    pub fn model_validate(&self, data: QValue) -> Result<QValue, String> {
        // 1. Convert data to HashMap (must be dict)
        let dict = match data {
            QValue::Dict(d) => d.to_hashmap(),
            _ => return Err("model_validate() requires a dict argument".to_string())
        };

        // 2. Use existing type construction logic
        construct_type_instance(self, dict)
    }
}

// When calling Type.model_validate(data), it's handled as a static method call
fn call_static_method(type_def: &QType, method: &str, args: Vec<QValue>) -> Result<QValue, String> {
    match method {
        "new" => construct_type_instance(type_def, convert_args_to_fields(args)?),
        "model_validate" => {
            if args.len() != 1 {
                return Err("model_validate() takes 1 argument".to_string());
            }
            type_def.model_validate(args[0].clone())
        },
        _ => Err(format!("Unknown static method: {}", method))
    }
}
```

**Key points:**
- `model_validate()` is available on the type itself (static method)
- Takes a single dict argument
- Uses same validation logic as `.new()` constructor
- Returns validated instance or raises error

### json() Implementation

The `.json()` method is added to all QObjects:

```rust
impl QObj for QNum {
    fn json(&self) -> String {
        self.value.to_string()
    }
}

impl QObj for QString {
    fn json(&self) -> String {
        // Properly escape string for JSON
        format!("\"{}\"", escape_json_string(&self.value))
    }
}

impl QObj for QBool {
    fn json(&self) -> String {
        if self.value { "true" } else { "false" }.to_string()
    }
}

impl QObj for QNil {
    fn json(&self) -> String {
        "null".to_string()
    }
}

impl QObj for QArray {
    fn json(&self) -> String {
        let items: Vec<String> = self.items
            .iter()
            .map(|item| item.json())
            .collect();
        format!("[{}]", items.join(", "))
    }
}

impl QObj for QDict {
    fn json(&self) -> String {
        let pairs: Vec<String> = self.entries
            .iter()
            .map(|(k, v)| format!("\"{}\": {}", escape_json_string(k), v.json()))
            .collect();
        format!("{{{}}}", pairs.join(", "))
    }
}

impl QObj for QStruct {
    fn json(&self) -> String {
        let pairs: Vec<String> = self.fields
            .iter()
            .map(|(k, v)| format!("\"{}\": {}", escape_json_string(k), v.json()))
            .collect();
        format!("{{{}}}", pairs.join(", "))
    }
}

impl QObj for QBytes {
    fn json(&self) -> String {
        // Encode as base64 string
        let b64 = base64_encode(&self.data);
        format!("\"{}\"", b64)
    }
}

impl QObj for QUuid {
    fn json(&self) -> String {
        // Use hyphenated format
        format!("\"{}\"", self.uuid.to_string())
    }
}

fn escape_json_string(s: &str) -> String {
    s.replace("\\", "\\\\")
     .replace("\"", "\\\"")
     .replace("\n", "\\n")
     .replace("\r", "\\r")
     .replace("\t", "\\t")
}
```

**Key points:**
- Every QValue type implements `.json()`
- Returns a JSON string representation
- Handles nested structures recursively
- Properly escapes strings
- Special handling for Bytes (base64) and Uuid (hyphenated)

### Validator Implementation

```rust
// Validators module
pub fn create_validators_module() -> QValue {
    let mut validators = HashMap::new();

    // Numeric validators
    validators.insert("range", create_range_validator());
    validators.insert("min", create_min_validator());
    validators.insert("max", create_max_validator());
    validators.insert("positive", create_positive_validator());

    // String validators
    validators.insert("min_length", create_min_length_validator());
    validators.insert("max_length", create_max_length_validator());
    validators.insert("pattern", create_pattern_validator());
    validators.insert("email", create_email_validator());
    validators.insert("url", create_url_validator());

    // Array validators
    validators.insert("min_items", create_min_items_validator());
    validators.insert("unique_items", create_unique_items_validator());
    validators.insert("each", create_each_validator());

    // Composite validators
    validators.insert("optional", create_optional_validator());
    validators.insert("all", create_all_validator());

    QValue::Module(QModule::new("Validators".to_string(), validators))
}

// Example: range validator
fn create_range_validator() -> QValue {
    QValue::Fun(QFun::new_native(|args| {
        if args.len() != 2 {
            return Err("range() expects 2 arguments (min, max)".to_string());
        }

        let min = args[0].as_num()?;
        let max = args[1].as_num()?;

        // Return a validator function
        Ok(QValue::UserFun(QUserFun::new_closure(move |val_args| {
            if val_args.len() != 1 {
                return Err("Validator expects 1 argument".to_string());
            }

            let value = val_args[0].as_num()?;
            if value < min || value > max {
                return Err(format!("Value must be between {} and {}", min, max));
            }

            Ok(val_args[0].clone())
        })))
    }))
}
```

## ValidationError Details

### Exception Methods

`ValidationError` provides two methods for accessing error information:

#### 1. message() - Human-Readable Summary

Returns a single string summarizing all validation errors:

```quest
try
    let user = User.new({"email": "invalid", "age": -5})
catch e: ValidationError
    puts(e.message())
    # "Validation failed: Field 'email' validation failed: Invalid email format; Field 'age' validation failed: Value must be between 0 and 150"
end
```

#### 2. errors() - Structured Error Details

Returns an array of error dictionaries (Pydantic-style format):

```quest
try
    let user = User.new({"email": "invalid", "age": -5})
catch e: ValidationError
    let errors = e.errors()
    # Returns:
    # [
    #   {
    #     "type": "value_error",
    #     "loc": ["email"],
    #     "msg": "Invalid email format",
    #     "input": "invalid"
    #   },
    #   {
    #     "type": "value_error",
    #     "loc": ["age"],
    #     "msg": "Value must be between 0 and 150",
    #     "input": -5
    #   }
    # ]
end
```

**Error dict structure:**
- `type` (str) - Error type: `"missing"`, `"type_error"`, `"value_error"`, `"email"`, etc.
- `loc` (array) - Location of error as array of field names (supports nested fields)
- `msg` (str) - Human-readable error message
- `input` (any) - The invalid input value that caused the error

### Using errors() in API Responses

The `.errors()` method is particularly useful for returning structured validation errors to API clients:

```quest
use "std/encoding/json" as json
use "std/validate" as v

type CreateUserRequest
    str: username
    str: email
    str: password
    num?: age

    fun validate_username(value)
        v.all([
            v.min_length(3),
            v.max_length(20),
            v.alphanumeric()
        ])(value)
    end

    fun validate_email(value)
        v.email()(value.lower())
    end

    fun validate_password(value)
        v.min_length(8)(value)
    end

    fun validate_age(value)
        v.optional(v.range(13, 120))(value)
    end
end

fun handle_create_user_api(request_body)
    try
        let data = json.parse(request_body)
        let request = CreateUserRequest.model_validate(data)

        # Success - create user
        let user = create_user_in_db(request)
        return {
            status: 201,
            body: user.json()
        }
    catch e: ValidationError
        # Return structured validation errors
        return {
            status: 422,  # Unprocessable Entity
            body: json.stringify({
                "detail": e.errors()
            })
        }
    catch e
        return {
            status: 500,
            body: json.stringify({"error": "Internal server error"})
        }
    end
end

# Example: Invalid request
let response = handle_create_user_api(json.stringify({
    "username": "ab",
    "email": "not-an-email",
    "password": "short",
    "age": 999
}))

puts(response.status)  # 422
puts(response.body)
# {
#   "detail": [
#     {
#       "type": "value_error",
#       "loc": ["username"],
#       "msg": "String length must be at least 3",
#       "input": "ab"
#     },
#     {
#       "type": "email",
#       "loc": ["email"],
#       "msg": "Invalid email format",
#       "input": "not-an-email"
#     },
#     {
#       "type": "value_error",
#       "loc": ["password"],
#       "msg": "String length must be at least 8",
#       "input": "short"
#     },
#     {
#       "type": "value_error",
#       "loc": ["age"],
#       "msg": "Value must be between 13 and 120",
#       "input": 999
#     }
#   ]
# }
```

### Nested Field Errors

For nested types, the `loc` array shows the full path to the error:

```quest
type Address
    str: street
    str: city
    str: zip_code

    fun validate_zip_code(value)
        v.pattern("^\\d{5}$")(value)
    end
end

type User
    str: name
    Address: address
end

try
    let user = User.new({
        "name": "Alice",
        "address": {
            "street": "123 Main St",
            "city": "Portland",
            "zip_code": "invalid"
        }
    })
catch e: ValidationError
    let errors = e.errors()
    # [
    #   {
    #     "type": "value_error",
    #     "loc": ["address", "zip_code"],
    #     "msg": "String must match pattern ^\\d{5}$",
    #     "input": "invalid"
    #   }
    # ]
end
```

### Error Type Categories

Common error types returned by `.errors()`:

- `"missing"` - Required field not provided
- `"type_error"` - Type annotation mismatch (expected str, got num, etc.)
- `"value_error"` - General validation failure
- `"email"` - Invalid email format
- `"url"` - Invalid URL format
- `"pattern"` - Regex pattern mismatch
- `"range"` - Value outside allowed range
- `"length"` - String length constraint violation
- `"items"` - Array size constraint violation

## Error Message Examples

Human-readable error messages from `.message()`:

```
ValidationError: Field 'age' validation failed: Value must be between 0 and 150

ValidationError: Field 'email' validation failed: Invalid email format

ValidationError: Field 'username' validation failed: String length must be at least 3

ValidationError: Pre-validation failed: Either email or phone is required

ValidationError: Post-validation failed: Start date must be before end date

ValidationError: Missing required field 'name' for type 'User'

ValidationError: Type mismatch for field 'age': expected num, got str

ValueError: Cannot construct type 'User' from JSON array. Expected JSON object.

ValueError: Cannot construct type 'Product' from JSON primitive. Expected JSON object.
```

## Benefits

1. **Type Safety:** Validation enforced at construction time
2. **Self-Documenting:** Validators describe acceptable values
3. **DRY:** Reusable validators eliminate duplicate code
4. **Clear Errors:** Actionable error messages with context
5. **Composable:** Chain and combine validators
6. **Performance:** Validate once at boundary, trust internally
7. **Maintainability:** Centralized validation logic in type definitions

## Best Practices

### 1. Validate at Boundaries

```quest
# Good: Validate external input
fun handle_request(request_data)
    try
        let req = CreateUserRequest.new(request_data)
        # req is now guaranteed valid
        create_user(req)
    catch e: ValidationError
        return {status: 400, error: e.message()}
    end
end

# Bad: Manual validation scattered everywhere
fun handle_request(request_data)
    if not request_data.has("username")
        return {status: 400, error: "Missing username"}
    end
    if request_data.username.len() < 3
        return {status: 400, error: "Username too short"}
    end
    # ... more validation
end
```

### 2. Use Built-in Validators

```quest
use "std/validate" as v

# Good: Use built-in validators
fun validate_email(value)
    v.email()(value)
end

# Bad: Reinvent validation logic
fun validate_email(value)
    if not value.contains("@") or not value.contains(".")
        raise ValueError("Invalid email")
    end
    value
end
```

### 3. Transform in Validators

```quest
use "std/validate" as v

# Good: Normalize during validation
fun validate_email(value)
    v.email()(value.lower().trim())
end

# Bad: Transform after validation
let user = User.new(email: email)
user.email = user.email.lower().trim()  # Can't do this - fields are immutable
```

## Limitations

1. **Validation Overhead:** Adds cost at construction time
2. **No Partial Validation:** All-or-nothing (either valid instance or error)
3. **Immutable Fields:** Can't modify validated fields after construction
4. **No Async Validators:** All validation is synchronous

## Future Enhancements

1. **Custom Error Types:** Define domain-specific validation errors
2. **Validation Context:** Pass additional context to validators
3. **Conditional Validation:** Skip validators based on conditions
4. **IDE Integration:** Autocomplete validator names and parameters
5. **Async Validators:** Support for database lookups, API calls, etc.
6. **Partial Validation:** Validate subset of fields (for PATCH requests)
7. **Validation Groups:** Group validators and run specific groups
8. **Custom JSON Serialization:** Allow types to override json() behavior

## Open Questions

### Comparison with Pydantic

Quest's validation system is inspired by Pydantic but has some differences. The following features and behaviors need clarification or consideration for implementation:

#### 1. Field Default Values

**Pydantic:**
```python
class User(BaseModel):
    name: str
    role: str = "user"  # Non-nil default
    created_at: datetime = Field(default_factory=datetime.now)
```

**Quest Current:** Only supports `nil` for optional fields
```quest
type User
    str: name
    str?: role  # Can only default to nil
end
```

**Proposed Enhancement:**
```quest
type User
    str: name
    str: role = "user"  # Default value
    num: created_at = ticks_ms()  # Default from function call
end
```

**Questions:**
- Should we support non-nil defaults?
- Should defaults be evaluated once at type definition or per-instance?
- Syntax: `str: field = "default"` or `str: field (default: "default")`?

#### 2. Field Aliases (Critical for API Integration)

**Pydantic:**
```python
class User(BaseModel):
    user_name: str = Field(alias="userName")  # API uses camelCase
```

**Quest Current:** No alias support - forces API and internal names to match

**Proposed Enhancement:**
```quest
type User
    str: user_name (alias: "userName")
    str: email_address (alias: "emailAddress")
end

# API sends: {"userName": "alice", "emailAddress": "alice@example.com"}
# Internally: user.user_name, user.email_address
```

**Questions:**
- Syntax for alias declaration?
- Should aliases work bidirectionally (read and write)?
- Should `.dict()` and `.json()` use aliases or internal names by default?

#### 3. dict() Method for Dictionary Conversion

**Pydantic:**
```python
user.model_dump()  # Returns dict
user.model_dump_json()  # Returns JSON string
```

**Quest Current:** Only has `.json()` which returns JSON string

**Proposed Enhancement:**
```quest
let user = User.new(name: "Alice", age: 30)
let d = user.dict()  # {"name": "Alice", "age": 30} - returns Dict
let j = user.json()  # '{"name":"Alice","age":30}' - returns Str
```

**Questions:**
- Should we add `.dict()` method to all structs?
- Naming: `.dict()`, `.to_dict()`, or `.as_dict()`?
- Should nested structs automatically convert to nested dicts?

#### 4. Exclude/Include Fields in Serialization

**Pydantic:**
```python
user.model_dump(exclude={'password', 'ssn'})
user.model_dump(include={'name', 'email'})
```

**Quest Current:** No way to exclude sensitive fields from serialization

**Proposed Enhancement:**
```quest
let user_public = user.dict(exclude: ["password", "ssn"])
let user_json = user.json(exclude: ["password"])

# Or mark fields as excluded by default
type User
    str: name
    str: email
    str: password (exclude: true)  # Never in dict() or json()
    str: ssn (exclude: true)
end
```

**Questions:**
- Support both runtime (method parameter) and declaration-time (field attribute) exclusion?
- Naming: `exclude`, `private`, `internal`?
- Should excluded fields be completely hidden or just excluded from serialization?
- Support for `include` (whitelist) vs `exclude` (blacklist)?

#### 5. Extra Fields Handling

**Pydantic:**
```python
class Config:
    extra = "forbid"  # Reject unknown fields
    extra = "allow"   # Keep unknown fields
    extra = "ignore"  # Silently ignore (default in Quest?)
```

**Quest Current:** Unclear behavior for unknown fields in dict/JSON

**Proposed Enhancement:**
```quest
type User (extra: "forbid")  # Raise error on unknown fields
    str: name
    str: email
end

type FlexibleConfig (extra: "allow")  # Keep unknown fields
    str: host
    num: port
    # Plus any other fields
end

try
    User.new({"name": "Alice", "email": "alice@example.com", "unknown": 123})
catch e: ValidationError
    # Error: Unknown field 'unknown' for type 'User'
end
```

**Questions:**
- What is current default behavior?
- Should default be "ignore" (silently drop) or "forbid" (raise error)?
- If "allow", where are extra fields stored and how are they accessed?

#### 6. Computed/Derived Fields

**Pydantic:**
```python
class User(BaseModel):
    first_name: str
    last_name: str

    @computed_field
    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}"

user.model_dump()  # Includes full_name in output
```

**Quest Current:** Methods exist but don't serialize

**Proposed Enhancement:**
```quest
type User
    str: first_name
    str: last_name

    computed fun full_name()
        self.first_name .. " " .. self.last_name
    end
end

user.dict()
# {"first_name": "Alice", "last_name": "Smith", "full_name": "Alice Smith"}
```

**Questions:**
- Should computed fields be included in `.dict()` and `.json()` by default?
- Performance implications for expensive computed fields?
- Can computed fields be excluded like regular fields?
- Should computed fields be cached or recomputed each time?

#### 7. Validation Context

**Pydantic:**
```python
User.model_validate(data, context={"current_user_id": 123})

# In validator
@field_validator('assignee_id')
def validate_assignee(cls, v, info):
    if v == info.context['current_user_id']:
        raise ValueError("Cannot assign to yourself")
```

**Quest Current:** No context passing to validators

**Proposed Enhancement:**
```quest
type Task
    str: title
    num: assignee_id

    fun validate_assignee_id(value, ctx)
        if value == ctx.current_user_id
            raise ValueError("Cannot assign to yourself")
        end
        value
    end
end

Task.model_validate(data, context: {"current_user_id": 123})
```

**Questions:**
- Signature: `validate_field(value, ctx)` or `validate_field(value, context: ctx)`?
- Should context be optional (backward compatible)?
- Available in `validate_before_model()` and `validate_after_model()` too?
- How to access context in those methods (no value parameter)?

#### 8. Field Metadata/Documentation

**Pydantic:**
```python
class User(BaseModel):
    email: str = Field(
        description="User's email address",
        examples=["alice@example.com"],
        json_schema_extra={"format": "email"}
    )
```

**Quest Current:** No field-level metadata

**Proposed Enhancement:**
```quest
type User
    str: email
        doc: "User's email address"
        example: "alice@example.com"

    num: age
        doc: "User's age in years"
        min: 0
        max: 150
end

# Access metadata
User.fields().email.doc()  # "User's email address"
```

**Questions:**
- Syntax for field metadata?
- Should metadata affect validation (e.g., `min: 0` implies `v.min(0)`)?
- Use for auto-generating API documentation?
- Relationship with `%` documentation syntax from stdlib_shadowing spec?

#### 9. Strict Mode vs Type Coercion

**Pydantic:**
```python
class User(BaseModel):
    age: int

    model_config = ConfigDict(strict=True)

# Without strict: User(age="25") → age=25 (coerced)
# With strict: User(age="25") → ValidationError
```

**Quest Current:** Unclear type coercion behavior

**Questions:**
- When JSON parses `{"age": "25"}`, does Quest coerce to num?
- Should `User.new({"age": "25"})` fail type checking or coerce?
- Different behavior for `JsonObject` vs `Dict`?
- Per-type or per-field strict mode?

```quest
type User (strict: true)  # No coercion at all
    num: age
end

type FlexibleUser (strict: false)  # Allow coercion
    num: age  # "25" → 25
end
```

#### 10. Discriminated Unions/Polymorphic Types

**Pydantic:**
```python
class Cat(BaseModel):
    pet_type: Literal["cat"]
    meow: str

class Dog(BaseModel):
    pet_type: Literal["dog"]
    bark: str

Pet = Union[Cat, Dog, Discriminator("pet_type")]

# JSON: {"pet_type": "cat", "meow": "loud"}
# Automatically creates Cat instance
```

**Quest Current:** No union type support

**Future Enhancement:**
```quest
type Cat
    str: pet_type = "cat"
    str: meow
end

type Dog
    str: pet_type = "dog"
    str: bark
end

type Pet = Cat | Dog (discriminator: "pet_type")

# Parse JSON based on discriminator field
let pet_data = {"pet_type": "cat", "meow": "loud"}
let pet = Pet.model_validate(pet_data)  # Returns Cat instance
```

**Questions:**
- Grammar support for union types?
- Runtime type discrimination logic?
- Error messages when discriminator doesn't match any type?

### Clarification Needed

The following behaviors need to be defined in the spec:

1. **Nested Type Validation:**
   - Does `Address: address` field automatically validate nested objects?
   - If dict has `{"address": {...}}`, does it automatically construct Address type?
   - Error location format for nested validation errors?

2. **Extra Fields Default Behavior:**
   - What happens when dict has fields not defined in type?
   - Silently ignored, stored somewhere, or error?

3. **Field Validator Order:**
   - Do field validators run in field definition order?
   - Does order matter for interdependent validations?

4. **Type Transformation in Validators:**
   - Can `validate_email(str)` return a different type?
   - Can validators transform optional to required (nil → default)?

5. **Instance Immutability:**
   - Are struct instances truly immutable?
   - Does `user.name = "new"` fail at runtime or compile time?
   - How to create modified copies (builder pattern, `.copy()` method)?

6. **Validation Error Accumulation:**
   - Does validation stop at first error or collect all errors?
   - Does `.errors()` return all field validation failures?
   - If `validate_before_model()` fails, do field validators still run?

7. **Circular Type References:**
   ```quest
   type Node
       str: name
       Node?: parent
       array: children  # Array of Node?
   end
   ```
   - How are circular references handled?
   - Can types reference themselves?

8. **Array and Dict Element Validation:**
   ```quest
   type Team
       array: members  # Array of User objects?
       dict: settings   # Dict with str keys and any values?
   end
   ```
   - Can you specify element types for arrays and dicts?
   - Syntax: `array<User>` or `array: User[]`?
   - How to validate dict key and value types?

### Priority Ranking

**High Priority (Common Use Cases):**
1. **Field aliases** - Essential for API integration with different naming conventions
2. **dict() method** - Need dict conversion without JSON string intermediary
3. **Exclude from serialization** - Security critical (passwords, tokens, sensitive data)
4. **Default values** - Very common pattern in most data models
5. **Extra fields policy** - Prevent silent bugs from typos or API changes

**Medium Priority (Valuable Features):**
6. **Computed fields** - Common pattern for derived data
7. **Validation context** - Needed for context-aware validation
8. **Field metadata** - Useful for documentation and tooling
9. **Type coercion clarification** - Important for API/JSON handling

**Low Priority (Advanced Features):**
10. **Discriminated unions** - Complex feature, less common use case
11. **Strict mode per-field** - Advanced control, niche use cases

## See Also

- [Type System](../docs/types.md) - Quest type system overview
- [Module Settings](module_settings.md) - Settings validation using similar patterns
- [Error Handling](../docs/error_handling.md) - Exception handling patterns
