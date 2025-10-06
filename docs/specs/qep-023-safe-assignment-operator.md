# QEP-023: Safe Assignment Operator (?=)

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Inspired By:** JavaScript Safe Assignment Operator Proposal (Stage 0)

## Abstract

This QEP proposes a safe assignment operator `?=` for Quest that transforms exception-throwing expressions into tuple results of `[error, value]`. This provides an ergonomic alternative to `try/catch` blocks for inline error handling, reducing nesting and improving code readability while maintaining Quest's exception model.

## Motivation

### Current Problem: Try/Catch Verbosity

Quest's current exception handling requires verbose `try/catch` blocks that:
1. Create unnecessary nesting
2. Disrupt linear code flow
3. Make error handling tedious for simple cases
4. Force choice between error handling and code clarity

**Example 1: Current Pattern**
```quest
fun get_user_post(user_id, post_id)
    try
        let user = db.get_user(user_id)
        try
            let post = db.get_post(post_id)
            try
                let comments = db.get_comments(post.id)
                return format_post(post, comments, user)
            catch e
                log.error("Failed to get comments: " .. e.message())
                return nil
            end
        catch e
            log.error("Failed to get post: " .. e.message())
            return nil
        end
    catch e
        log.error("Failed to get user: " .. e.message())
        return nil
    end
end
```

**Example 2: Validation Pattern**
```quest
fun validate_input(data)
    try
        let parsed = json.parse(data)
    catch e
        return {"valid": false, "error": "Invalid JSON"}
    end

    try
        let validated = schema.validate(parsed)
    catch e
        return {"valid": false, "error": e.message()}
    end

    return {"valid": true, "data": validated}
end
```

### The JavaScript Safe Assignment Inspiration

JavaScript's Stage 0 proposal introduces a `try` operator (originally `?=`) that returns `[error, value]` tuples:

```javascript
// JavaScript proposal
const [error, data] = try fetchData()

if (error) {
    console.log("Failed:", error)
} else {
    console.log("Success:", data)
}
```

### Why This Fits Quest

Quest already has:
- ✅ Tuple/array destructuring: `let a, b = [1, 2]`
- ✅ Strong exception model with typed catches
- ✅ `nil` as a first-class value
- ✅ Methods like `.is()` for type checking

Quest can adopt this pattern naturally:
```quest
let err, user = ?= db.get_user(user_id)
```

## Proposal: The Safe Assignment Operator (?=)

### Syntax

```quest
let error, value = ?= expression
```

**Semantics:**
- If `expression` succeeds: returns `[nil, result]`
- If `expression` raises: returns `[exception, nil]`
- Never propagates exceptions outside its scope
- Works with any expression that might raise

### Detailed Behavior

#### 1. Success Case
```quest
let err, result = ?= 10 / 2

# err is nil
# result is 5

if err == nil
    puts("Success: " .. result._str())
end
```

#### 2. Exception Case
```quest
let err, result = ?= 10 / 0

# err is exception object with .message(), .type(), etc.
# result is nil

if err != nil
    puts("Error: " .. err.message())
end
```

#### 3. Complex Expressions
```quest
# Method chains
let err, data = ?= json.parse(input).validate().transform()

# Await-like patterns (if Quest adds async)
let err, response = ?= http.get("https://api.example.com")

# Function calls with multiple args
let err, user = ?= db.query("SELECT * FROM users WHERE id = ?", [user_id])
```

#### 4. Works with Type Checking
```quest
let err, value = ?= risky_operation()

if err.is("IOError")
    puts("I/O problem: " .. err.message())
elif err.is("ValueError")
    puts("Value problem: " .. err.message())
elif err != nil
    puts("Other error: " .. err.message())
else
    puts("Success: " .. value._str())
end
```

### Comparison with Try/Catch

#### Example 1: Database Operations

**Current (Try/Catch):**
```quest
fun get_user_post(user_id, post_id)
    try
        let user = db.get_user(user_id)
        try
            let post = db.get_post(post_id)
            return {"user": user, "post": post}
        catch e
            log.error("Post error: " .. e.message())
            return nil
        end
    catch e
        log.error("User error: " .. e.message())
        return nil
    end
end
```

**Proposed (Safe Assignment):**
```quest
fun get_user_post(user_id, post_id)
    let err, user = ?= db.get_user(user_id)
    if err != nil
        log.error("User error: " .. err.message())
        return nil
    end

    let err, post = ?= db.get_post(post_id)
    if err != nil
        log.error("Post error: " .. err.message())
        return nil
    end

    return {"user": user, "post": post}
end
```

**Benefits:**
- 40% less code (13 lines vs 22)
- No nesting
- Linear flow
- Clear error context

#### Example 2: Validation Pipeline

**Current (Try/Catch):**
```quest
fun process_data(input)
    try
        let parsed = json.parse(input)
    catch e
        return {"ok": false, "error": "Parse error: " .. e.message()}
    end

    try
        let validated = validate_schema(parsed)
    catch e
        return {"ok": false, "error": "Validation error: " .. e.message()}
    end

    try
        let transformed = transform_data(validated)
    catch e
        return {"ok": false, "error": "Transform error: " .. e.message()}
    end

    return {"ok": true, "data": transformed}
end
```

**Proposed (Safe Assignment):**
```quest
fun process_data(input)
    let err, parsed = ?= json.parse(input)
    if err != nil
        return {"ok": false, "error": "Parse error: " .. err.message()}
    end

    let err, validated = ?= validate_schema(parsed)
    if err != nil
        return {"ok": false, "error": "Validation error: " .. err.message()}
    end

    let err, transformed = ?= transform_data(validated)
    if err != nil
        return {"ok": false, "error": "Transform error: " .. err.message()}
    end

    return {"ok": true, "data": transformed}
end
```

**Benefits:**
- Same line count but more consistent pattern
- No try block scope issues
- Easier to add logging/telemetry
- Clearer error source

#### Example 3: Optional Chaining with Errors

**Current (Try/Catch):**
```quest
fun get_user_email(user_id)
    try
        let user = db.get_user(user_id)
        if user.profile == nil
            return nil
        end
        return user.profile.email
    catch e
        return nil
    end
end
```

**Proposed (Safe Assignment):**
```quest
fun get_user_email(user_id)
    let err, user = ?= db.get_user(user_id)
    if err != nil
        return nil
    end

    return user.profile?.email  # Elvis operator (QEP-019)
end
```

#### Example 4: Early Returns

**Current (Try/Catch):**
```quest
fun validate_and_process(data)
    try
        let step1 = process_step_1(data)
    catch e
        return {"error": "Step 1 failed", "details": e.message()}
    end

    try
        let step2 = process_step_2(step1)
    catch e
        return {"error": "Step 2 failed", "details": e.message()}
    end

    try
        let step3 = process_step_3(step2)
    catch e
        return {"error": "Step 3 failed", "details": e.message()}
    end

    return {"success": true, "result": step3}
end
```

**Proposed (Safe Assignment):**
```quest
fun validate_and_process(data)
    let err, step1 = ?= process_step_1(data)
    if err != nil
        return {"error": "Step 1 failed", "details": err.message()}
    end

    let err, step2 = ?= process_step_2(step1)
    if err != nil
        return {"error": "Step 2 failed", "details": err.message()}
    end

    let err, step3 = ?= process_step_3(step2)
    if err != nil
        return {"error": "Step 3 failed", "details": err.message()}
    end

    return {"success": true, "result": step3}
end
```

**Benefits:**
- Guard clause pattern
- Early returns for errors
- No deeply nested try blocks

## Detailed Design

### Return Value Structure

The `?=` operator always returns a 2-element array:
- **Index 0**: Error (exception object or `nil`)
- **Index 1**: Value (result or `nil`)

```quest
let err, value = ?= expression

# Equivalent to:
let result_tuple = try
    [nil, expression]
catch e
    [e, nil]
end
let err = result_tuple[0]
let value = result_tuple[1]
```

### Exception Object

The error object (when not `nil`) has the standard Quest exception interface:

```quest
let err, _ = ?= risky_operation()

if err != nil
    err.message()   # Error message string
    err.type()      # Exception type name
    err.stack()     # Stack trace
    err.is("IOError")  # Type checking
end
```

### Syntax Variants

#### Variant 1: Explicit Destructuring (Proposed)
```quest
let err, value = ?= expression
```

**Pros:**
- Clear assignment
- Matches JavaScript proposal
- Works with existing destructuring

**Cons:**
- Slightly verbose

#### Variant 2: Direct Assignment (Alternative)
```quest
let result = ?= expression
# result is [err, value] array
```

**Pros:**
- Shorter
- Can destructure later

**Cons:**
- Less ergonomic
- Requires extra step to use

#### Variant 3: Prefix Operator (Alternative)
```quest
let [err, value] = ?expression
```

**Pros:**
- Looks like unary operator
- Visual similarity to optional chaining `?`

**Cons:**
- Confusing with ternary `?:`
- Less clear semantics

**Decision:** Use Variant 1 (explicit destructuring) for clarity and consistency with JavaScript proposal.

### Grammar Changes

Add to [src/quest.pest](../../src/quest.pest):

```pest
let_statement = {
    "let" ~ identifier ~ ("," ~ identifier)* ~ "=" ~ "?=" ~ expression
    | "let" ~ identifier ~ ("," ~ identifier)* ~ "=" ~ expression
}

safe_assignment = { "?=" ~ expression }
```

**Precedence:** `?=` binds to the expression immediately following it.

```quest
# These are equivalent
let err, val = ?= foo()
let err, val = ?=(foo())

# Multiple ?= not allowed (parse error)
let err, val = ?= ?= foo()  # ERROR

# Use nested destructuring for nested tries
let err1, result1 = ?= outer()
if err1 == nil
    let err2, result2 = ?= inner(result1)
end
```

## Integration with Existing Features

### With Try/Catch (Coexistence)

`?=` does not replace try/catch - they coexist:

```quest
# Use ?= for simple inline errors
let err, data = ?= parse_json(input)

# Use try/catch for complex error handling
try
    let result = complex_operation()
    let processed = process(result)
    let validated = validate(processed)
    return validated
catch ValidationError as e
    log.error("Validation failed: " .. e.message())
    retry()
catch NetworkError as e
    log.error("Network issue: " .. e.message())
    fallback()
ensure
    cleanup()
end
```

**When to use ?=:**
- Single operation error handling
- Early return patterns
- Guard clauses
- Simple error logging

**When to use try/catch:**
- Multiple operations in one block
- Typed exception catching
- `ensure` blocks needed
- Complex error recovery

### With Elvis Operator (QEP-019)

Works naturally together:

```quest
# ?= for exception handling, ?. for nil handling
let err, user = ?= db.get_user(id)
let email = user?.profile?.email  # Safe nil navigation

if err != nil or email == nil
    return "No email found"
end

return email
```

### With Result Types (Future)

If Quest adds Rust-style Result types (QEP-024 candidate), `?=` complements them:

```quest
# Function returns Result<T, E>
fun risky_operation() -> Result
    if failure_condition
        return Err("Something went wrong")
    end
    return Ok(42)
end

# ?= works with both exceptions and Result types
let err, value = ?= risky_operation()
```

### With Inline If Expression

```quest
# Inline error handling
let err, value = ?= risky_op()
let result = value if err == nil else default_value

# Or more explicit
let result = if err == nil then value else default_value
```

## Implementation Strategy

### Phase 1: Parser Changes

Modify [src/quest.pest](../../src/quest.pest) to recognize `?=` operator:

```pest
safe_assignment_expr = { "?=" ~ expression }

let_statement = {
    "let" ~ identifier ~ ("," ~ identifier)* ~ "=" ~ safe_assignment_expr
    | "let" ~ identifier ~ ("," ~ identifier)* ~ "=" ~ expression
}
```

### Phase 2: Evaluator Changes

In [src/main.rs](../../src/main.rs), add evaluation logic:

```rust
fn eval_safe_assignment(expr: Pair<Rule>, variables: &mut Scope) -> Result<QValue, String> {
    // Evaluate the expression after ?=
    let result = match eval_expression(expr, variables) {
        Ok(value) => {
            // Success case: [nil, value]
            vec![QValue::Nil(QNil), value]
        }
        Err(err_msg) => {
            // Error case: [exception, nil]
            let exception = create_exception(err_msg);
            vec![exception, QValue::Nil(QNil)]
        }
    };

    // Return as array
    Ok(QValue::Array(QArray::new(result)))
}

fn create_exception(message: String) -> QValue {
    // Create exception object with message(), type(), stack()
    // For now, can be a simple struct or Dict
    let mut exc_dict = HashMap::new();
    exc_dict.insert("message".to_string(), QValue::Str(QString::new(message.clone())));
    exc_dict.insert("type".to_string(), QValue::Str(QString::new("Exception".to_string())));

    QValue::Dict(Box::new(QDict::new(exc_dict)))
}
```

### Phase 3: Exception Object

Create proper exception type [src/types/exception.rs](../../src/types/exception.rs):

```rust
#[derive(Debug, Clone)]
pub struct QException {
    pub message: String,
    pub exc_type: String,
    pub stack_trace: Vec<String>,
    pub id: u64,
}

impl QException {
    pub fn call_method(&self, method_name: &str, args: Vec<QValue>) -> Result<QValue, String> {
        match method_name {
            "message" => {
                if !args.is_empty() {
                    return Err(format!("message expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.message.clone())))
            }
            "type" => {
                if !args.is_empty() {
                    return Err(format!("type expects 0 arguments, got {}", args.len()));
                }
                Ok(QValue::Str(QString::new(self.exc_type.clone())))
            }
            "stack" => {
                if !args.is_empty() {
                    return Err(format!("stack expects 0 arguments, got {}", args.len()));
                }
                let stack_arr = self.stack_trace.iter()
                    .map(|s| QValue::Str(QString::new(s.clone())))
                    .collect();
                Ok(QValue::Array(QArray::new(stack_arr)))
            }
            "is" => {
                if args.len() != 1 {
                    return Err(format!("is expects 1 argument, got {}", args.len()));
                }
                let type_name = match &args[0] {
                    QValue::Str(s) => (*s.value).clone(),
                    _ => return Err("is expects string type name".to_string()),
                };
                Ok(QValue::Bool(QBool::new(self.exc_type == type_name)))
            }
            _ => Err(format!("Unknown method '{}' on Exception", method_name))
        }
    }
}
```

### Phase 4: QValue Extension

Add Exception variant to [src/types/mod.rs](../../src/types/mod.rs):

```rust
pub enum QValue {
    // ... existing variants
    Exception(QException),
}
```

### Phase 5: Testing

Create comprehensive test suite [test/safe_assignment_test.q](../../test/safe_assignment_test.q):

```quest
use "std/test"

test.module("Safe Assignment Operator (?=)")

test.describe("Basic success cases", fun ()
    test.it("returns [nil, value] on success", fun ()
        let err, value = ?= 10 / 2
        test.assert_eq(err, nil, "Error should be nil")
        test.assert_eq(value, 5, "Value should be 5")
    end)

    test.it("works with function calls", fun ()
        fun safe_func()
            return 42
        end

        let err, value = ?= safe_func()
        test.assert_eq(err, nil, nil)
        test.assert_eq(value, 42, nil)
    end)
end)

test.describe("Basic error cases", fun ()
    test.it("returns [exception, nil] on error", fun ()
        let err, value = ?= 10 / 0
        test.assert_neq(err, nil, "Error should not be nil")
        test.assert_eq(value, nil, "Value should be nil")
        test.assert(err.message().contains("Division by zero"), nil)
    end)

    test.it("captures raised exceptions", fun ()
        fun failing_func()
            raise "Intentional error"
        end

        let err, value = ?= failing_func()
        test.assert_neq(err, nil, nil)
        test.assert_eq(value, nil, nil)
        test.assert(err.message().contains("Intentional"), nil)
    end)
end)

test.describe("Exception object methods", fun ()
    test.it("exception has message() method", fun ()
        let err, _ = ?= raise "Test error"
        test.assert_type(err.message(), "Str", nil)
        test.assert_eq(err.message(), "Test error", nil)
    end)

    test.it("exception has type() method", fun ()
        let err, _ = ?= 10 / 0
        test.assert_type(err.type(), "Str", nil)
    end)

    test.it("exception has is() method", fun ()
        let err, _ = ?= 10 / 0
        # Assuming division by zero raises MathError
        test.assert(err.is("MathError"), nil)
    end)
end)

test.describe("Complex expressions", fun ()
    test.it("works with method chains", fun ()
        let arr = [1, 2, 3]
        let err, value = ?= arr.map(fun (x) x * 2 end).filter(fun (x) x > 2 end)
        test.assert_eq(err, nil, nil)
        test.assert_eq(value.len(), 2, nil)
    end)

    test.it("works with nested function calls", fun ()
        fun inner() 42 end
        fun outer() inner() * 2 end

        let err, value = ?= outer()
        test.assert_eq(err, nil, nil)
        test.assert_eq(value, 84, nil)
    end)
end)

test.describe("Integration with other features", fun ()
    test.it("works with if expressions", fun ()
        let err, value = ?= 10 / 2
        let result = value if err == nil else 0
        test.assert_eq(result, 5, nil)
    end)

    test.it("works with early returns", fun ()
        fun process()
            let err, value = ?= risky_operation()
            if err != nil
                return nil
            end
            return value * 2
        end

        fun risky_operation()
            return 21
        end

        test.assert_eq(process(), 42, nil)
    end)
end)

test.describe("Real-world patterns", fun ()
    test.it("handles database-style operations", fun ()
        fun mock_db_get(id)
            if id < 0
                raise "Invalid ID"
            end
            return {"id": id, "name": "User " .. id._str()}
        end

        let err, user = ?= mock_db_get(1)
        test.assert_eq(err, nil, nil)
        test.assert_eq(user["id"], 1, nil)

        let err2, user2 = ?= mock_db_get(-1)
        test.assert_neq(err2, nil, nil)
        test.assert_eq(user2, nil, nil)
    end)

    test.it("handles validation pipelines", fun ()
        fun parse_and_validate(input)
            let err, parsed = ?= json.parse(input)
            if err != nil
                return {"ok": false, "error": "Parse error"}
            end

            return {"ok": true, "data": parsed}
        end

        let result = parse_and_validate('{"test": 123}')
        test.assert(result["ok"], nil)
    end)
end)
```

## Use Cases

### Use Case 1: API Request Handling

```quest
use "std/http/client"

fun fetch_user_data(user_id)
    let err, response = ?= http.get(f"https://api.example.com/users/{user_id}")
    if err != nil
        log.error("HTTP request failed: " .. err.message())
        return nil
    end

    let err, data = ?= json.parse(response.text())
    if err != nil
        log.error("JSON parsing failed: " .. err.message())
        return nil
    end

    return data
end
```

### Use Case 2: File Operations

```quest
use "std/io"

fun read_config(filename)
    let err, content = ?= io.read(filename)
    if err != nil
        if err.is("FileNotFoundError")
            # Use defaults
            return default_config()
        else
            log.error("Failed to read config: " .. err.message())
            raise "Configuration error"
        end
    end

    let err, config = ?= parse_config(content)
    if err != nil
        log.error("Invalid config format: " .. err.message())
        return default_config()
    end

    return config
end
```

### Use Case 3: Database Transactions

```quest
use "std/db/postgres"

fun create_user_with_profile(username, email, profile_data)
    let err, conn = ?= db.connect(connection_string)
    if err != nil
        return {"success": false, "error": err.message()}
    end

    let err, user_id = ?= conn.execute(
        "INSERT INTO users (username, email) VALUES ($1, $2) RETURNING id",
        [username, email]
    )
    if err != nil
        return {"success": false, "error": "Failed to create user"}
    end

    let err, _ = ?= conn.execute(
        "INSERT INTO profiles (user_id, data) VALUES ($1, $2)",
        [user_id, profile_data]
    )
    if err != nil
        # Rollback would happen here
        return {"success": false, "error": "Failed to create profile"}
    end

    conn.commit()
    return {"success": true, "user_id": user_id}
end
```

### Use Case 4: Data Pipeline

```quest
fun process_data_pipeline(input)
    let err, cleaned = ?= clean_data(input)
    if err != nil
        telemetry.record("pipeline_error", "clean", err.message())
        return nil
    end

    let err, validated = ?= validate_data(cleaned)
    if err != nil
        telemetry.record("pipeline_error", "validate", err.message())
        return nil
    end

    let err, transformed = ?= transform_data(validated)
    if err != nil
        telemetry.record("pipeline_error", "transform", err.message())
        return nil
    end

    let err, result = ?= save_data(transformed)
    if err != nil
        telemetry.record("pipeline_error", "save", err.message())
        return nil
    end

    telemetry.record("pipeline_success", "complete", result.id)
    return result
end
```

## Advantages

### 1. Reduced Nesting
Eliminates pyramid of doom from nested try/catch blocks.

### 2. Linear Code Flow
Errors handled inline without disrupting main logic flow.

### 3. Explicit Error Handling
Developers must explicitly check for errors (no silent failures).

### 4. Consistent Pattern
Same pattern works for all exception scenarios.

### 5. Better Telemetry
Easy to add logging/metrics at each error point.

### 6. Type Safety (Future)
Works naturally with typed exceptions and Result types.

### 7. Composability
Easy to chain multiple safe operations.

## Disadvantages & Mitigations

### 1. Variable Name Collision

**Problem:** Multiple `?=` in scope use same `err` variable name.

```quest
let err, user = ?= get_user(id)
let err, post = ?= get_post(id)  # Shadows previous err
```

**Mitigation 1:** Use descriptive names
```quest
let user_err, user = ?= get_user(id)
let post_err, post = ?= get_post(id)
```

**Mitigation 2:** Check immediately
```quest
let err, user = ?= get_user(id)
if err != nil
    return err
end

let err, post = ?= get_post(id)  # Safe, previous err out of scope
if err != nil
    return err
end
```

### 2. Forgotten Error Checks

**Problem:** Developer might ignore error.

```quest
let err, value = ?= risky_op()
# Forgot to check err!
use_value(value)  # Could be nil!
```

**Mitigation 1:** Linter warning (future)
```quest
# Compiler/linter warns: "Unused variable 'err' from safe assignment"
```

**Mitigation 2:** Documentation and best practices
- Always check `err != nil` immediately
- Use guard clauses for early returns

**Mitigation 3:** Result type integration (future QEP)
```rust
// Rust-style ? operator requires explicit handling
let value = ?= risky_op() else return  // Must handle error path
```

### 3. More Verbose Than Try/Catch for Multiple Operations

**Problem:** Multiple related operations need individual checks.

**When to use try/catch instead:**
```quest
# Multiple operations, single error handler
try
    let step1 = operation1()
    let step2 = operation2(step1)
    let step3 = operation3(step2)
    return step3
catch e
    log.error("Pipeline failed: " .. e.message())
    return nil
end
```

**Guidance:** Use `?=` for individual operations, try/catch for batches.

### 4. Confusion with Ternary Operator

**Problem:** `?=` might be confused with `?:` (ternary).

**Mitigation:** Different operators, different contexts
- `?:` is an expression operator: `value ? true_case : false_case`
- `?=` is an assignment operator: `let err, val = ?= expr`

### 5. Not a Complete Replacement

**Problem:** Some scenarios still need try/catch.

**When try/catch is better:**
- Typed exception catching: `catch IOError as e`
- Ensure blocks: `try ... catch ... ensure cleanup() end`
- Multiple operations with shared error handling

**Solution:** Coexistence. Use the right tool for the job.

## Alternative Designs Considered

### Alternative 1: try Expression (JavaScript Direction)

JavaScript proposal is moving toward `try` expressions:

```javascript
const result = try someFunction()
const [ok, error, value] = try someFunction()
```

**Quest version:**
```quest
let result = try? risky_op()
# Returns [err, value] array

# Or with destructuring
let err, value = try? risky_op()
```

**Pros:**
- More explicit keyword
- Aligns with JavaScript final direction

**Cons:**
- `try` already means something (try/catch blocks)
- Less concise than `?=`

**Decision:** Keep `?=` for now, reconsider if JavaScript finalizes `try` expression.

### Alternative 2: Result Type (Rust-Style)

Return explicit Result objects:

```quest
fun risky_op() -> Result
    if error_condition
        return Err("Error message")
    end
    return Ok(42)
end

# Usage
let result = risky_op()
if result.is_err()
    puts(result.unwrap_err())
else
    puts(result.unwrap())
end
```

**Pros:**
- Explicit return types
- Type-safe error handling
- Compiler can enforce checks

**Cons:**
- Requires type system changes
- Large refactor for existing code
- More verbose

**Decision:** Keep `?=` for ergonomics. Result types could be added later (QEP-024) and work together with `?=`.

### Alternative 3: Null-Coalescing Pattern

Return `nil` on errors instead of exceptions:

```quest
let value = risky_op() ?? default_value
```

**Pros:**
- Very concise
- Familiar pattern

**Cons:**
- Loses error information
- Can't distinguish between `nil` result and error
- Silent failures

**Decision:** Not sufficient. Errors need context.

### Alternative 4: Go-Style Multiple Returns

Functions return (value, error):

```quest
fun risky_op()
    if error
        return nil, "Error message"
    end
    return 42, nil
end

# Usage
let value, err = risky_op()
```

**Pros:**
- Explicit in function signatures
- Common pattern (Go, Lua)

**Cons:**
- Requires all functions to change
- Breaking change
- Doesn't work with existing code

**Decision:** `?=` wraps existing functions, no changes needed.

## Migration Path

### Phase 1: Introduce ?= (Non-Breaking)

Add `?=` operator without changing existing code. Both styles coexist:

```quest
# Old style still works
try
    let value = risky_op()
catch e
    handle_error(e)
end

# New style available
let err, value = ?= risky_op()
if err != nil
    handle_error(err)
end
```

### Phase 2: Documentation & Examples

Update docs to show both patterns and when to use each.

### Phase 3: Standard Library Examples

Add `?=` examples to commonly-used modules:
- `std/io` - File operations
- `std/http/client` - HTTP requests
- `std/db/*` - Database queries
- `std/encoding/json` - JSON parsing

### Phase 4: Community Adoption

Let community try and provide feedback before marking as stable.

### Phase 5: Optimization

Optimize `?=` implementation for common cases (avoid exception object creation overhead when possible).

## Performance Considerations

### Exception Object Creation

Creating exception objects has overhead. Optimize for common success case:

```rust
// Lazy exception creation
fn eval_safe_assignment(expr: Pair<Rule>, variables: &mut Scope) -> Result<QValue, String> {
    match eval_expression(expr, variables) {
        Ok(value) => {
            // Fast path: no exception object created
            Ok(QValue::Array(QArray::new(vec![QValue::Nil(QNil), value])))
        }
        Err(err_msg) => {
            // Slow path: create exception only on error
            let exception = create_exception(err_msg);
            Ok(QValue::Array(QArray::new(vec![exception, QValue::Nil(QNil)])))
        }
    }
}
```

### Tuple Allocation

Array allocation is cheap in Quest (Rc<RefCell<Vec>>), but could optimize further with specialized tuple type.

### Benchmarks Needed

Compare performance:
1. `try/catch` block
2. `?=` operator
3. Function that returns Result-like dict

Expected: `?=` should be comparable to try/catch (both catch exceptions).

## Documentation Requirements

### 1. Language Guide Update

Add section: "Error Handling with Safe Assignment (?=)"
- Basic syntax
- When to use vs try/catch
- Common patterns
- Gotchas

### 2. Exception Object Documentation

Document exception object methods:
- `message()` - Get error message
- `type()` - Get exception type
- `stack()` - Get stack trace
- `is(type_name)` - Check exception type

### 3. Best Practices Guide

Create guide for error handling patterns:
- Early returns with ?=
- Validation pipelines
- Database operations
- API requests

### 4. Migration Guide

For users familiar with try/catch, show equivalents and when to use each.

## Related QEPs

- **QEP-006**: Exception Handling - Defines try/catch/ensure
- **QEP-019**: Elvis Operator - Nil-safe navigation (complements ?=)
- **QEP-024**: Result Types (Future) - Rust-style Result<T, E>

## Future Enhancements

### 1. Try Expression (JavaScript Alignment)

If JavaScript finalizes `try` expression syntax, consider adding:
```quest
let result = try? expression
```

### 2. Result Type Integration

Add Result<T, E> type that works with ?=:
```quest
fun risky() -> Result<Int, Str>
    return Ok(42)
end

let err, value = ?= risky()
```

### 3. Linter Rules

- Warn on unused `err` variable
- Suggest ?= when simple try/catch with immediate return
- Warn on ?= result used without nil check

### 4. Optional Chaining Integration

Combine ?= with optional chaining:
```quest
let err, data = ?= http.get(url)
let value = data?.response?.body?.value  # nil-safe after error check
```

### 5. Pattern Matching (Future)

```quest
match ?= risky_op()
    [nil, value] -> handle_success(value)
    [err, _] -> handle_error(err)
end
```

## Conclusion

The safe assignment operator (`?=`) provides Quest with an ergonomic, modern error handling pattern inspired by JavaScript's Stage 0 proposal. It complements Quest's existing try/catch mechanism by offering:

- **Reduced nesting** for simple error cases
- **Linear code flow** with explicit error checks
- **Compatibility** with existing exception model
- **Flexibility** to choose the right tool for the job

**Key Benefits:**
- ✅ Non-breaking addition
- ✅ Works with existing code
- ✅ Reduces boilerplate in common cases
- ✅ Maintains Quest's developer happiness focus
- ✅ Aligns with modern language trends

**Implementation Effort:** ~2-3 weeks
- Week 1: Parser and evaluator changes
- Week 2: Exception object and testing
- Week 3: Documentation and examples

**Risk:** Low - additive feature, doesn't break existing code

**Recommendation:** Implement as experimental feature, gather community feedback, then stabilize.

## References

### JavaScript Safe Assignment Proposal
- GitHub: https://github.com/arthurfiorette/proposal-safe-assignment-operator
- Stage: 0 (Early proposal)
- Status: Evolving toward `try` expressions

### Similar Patterns in Other Languages

**Go:**
```go
value, err := riskyOperation()
if err != nil {
    // handle error
}
```

**Rust:**
```rust
let value = risky_operation()?;  // Propagates error
match risky_operation() {
    Ok(val) => handle_success(val),
    Err(e) => handle_error(e),
}
```

**Lua:**
```lua
local success, result = pcall(risky_function)
if not success then
    -- handle error
end
```

**Swift:**
```swift
do {
    let result = try riskyOperation()
} catch {
    // handle error
}

// Or with optional try
let result = try? riskyOperation()  // Returns nil on error
```

Quest's `?=` takes inspiration from these patterns while fitting Quest's syntax and philosophy.
