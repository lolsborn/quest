# QEP-019: Elvis Operator (?:) for Null-Safe Defaults

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Related:** Nil handling, Optional chaining

---

## Abstract

This QEP proposes adding the **Elvis operator** (`?:`) to Quest for providing default values when expressions evaluate to `nil`. The operator is named after Elvis Presley because `?:` resembles his iconic hairstyle when viewed sideways. This operator simplifies null-safe code and eliminates verbose ternary patterns.

---

## Motivation

### Current Limitations

Quest currently requires verbose ternary expressions to provide defaults for nil values:

```quest
# Verbose: Check if nil, provide default
let name = user.name != nil ? user.name : "Anonymous"
let port = config.get("port") != nil ? config.get("port") : 8080
let value = dict.get("key") != nil ? dict.get("key") : "default"

# Inefficient: Expression evaluated twice
let result = expensive_function() != nil ? expensive_function() : fallback()
```

**Problems:**
1. **Repetition** - Expression appears twice (once in check, once in return)
2. **Inefficient** - Expression evaluated twice if it's a function call
3. **Verbose** - Simple concept requires long syntax
4. **Error-prone** - Easy to forget nil check or use wrong operator

### Proposed Solution: Elvis Operator

```quest
# Concise: Provide default if nil
let name = user.name ?: "Anonymous"
let port = config.get("port") ?: 8080
let value = dict.get("key") ?: "default"

# Efficient: Expression evaluated once
let result = expensive_function() ?: fallback()
```

**Benefits:**
1. **Concise** - Single operator, clear intent
2. **Efficient** - Left side evaluated only once
3. **Readable** - Obvious what it does ("value or default")
4. **Safe** - Can't accidentally double-evaluate

---

## Syntax and Semantics

### Basic Syntax

```quest
expression ?: default_value
```

**Evaluation:**
1. Evaluate left expression once
2. If result is `nil`, return right expression
3. If result is not `nil`, return result

**Key Property:** Left expression is evaluated **exactly once**.

### Examples

#### Basic Default Values

```quest
# String defaults
let name = user.name ?: "Unknown"
let title = article.title ?: "Untitled"

# Numeric defaults
let port = config.port ?: 8080
let timeout = settings.timeout ?: 30

# Array defaults
let items = get_items() ?: []
let tags = post.tags ?: ["untagged"]

# Dict defaults
let metadata = file.metadata ?: {}
let options = parse_options() ?: {"debug": false}
```

#### Method Call Defaults

```quest
# If method returns nil, use default
let value = dict.get("key") ?: "default"
let count = array.find(item) ?: 0
let result = api.fetch() ?: {"error": "Not found"}
```

#### Chaining Elvis Operators

```quest
# Try multiple sources, first non-nil wins
let value = env_var ?: config_value ?: default_value

# Equivalent to:
# if env_var != nil { env_var }
# else if config_value != nil { config_value }
# else { default_value }

# Example: Configuration precedence
let port = os.getenv("PORT") ?: settings.get("port") ?: 8080
```

#### With Optional Chaining (Future)

```quest
# If optional chaining supported:
let city = user?.address?.city ?: "Unknown"
let count = data?.items?.len() ?: 0
```

---

## Comparison with Other Approaches

### Current: Ternary with Nil Check

```quest
# Current approach (verbose)
let name = user.name != nil ? user.name : "Anonymous"
let port = config.port != nil ? config.port : 8080

# Problem: Expression evaluated/written twice
let result = expensive_call() != nil ? expensive_call() : fallback()
```

### With Elvis Operator

```quest
# Elvis operator (concise)
let name = user.name ?: "Anonymous"
let port = config.port ?: 8080

# Evaluated once
let result = expensive_call() ?: fallback()
```

### Alternative: Inline If

```quest
# Using inline if (Quest already has this)
let name = if user.name != nil then user.name else "Anonymous"

# Still verbose and duplicates expression
```

### Alternative: Logical OR Pattern (Some Languages)

```quest
# JavaScript/Python style (NOT proposed for Quest)
let name = user.name || "Anonymous"  # ❌ Treats false/0/"" as nil

# Quest's Elvis only checks nil
let name = user.name ?: "Anonymous"  # ✅ Only nil triggers default
```

---

## Comparison with Other Languages

### Kotlin (Origin of Elvis Operator)

```kotlin
val name = user.name ?: "Unknown"
val port = config.port ?: 8080
```

**Same syntax as proposed for Quest.** ✅

### Groovy

```groovy
def name = user.name ?: "Unknown"
def items = getItems() ?: []
```

**Same syntax as proposed for Quest.** ✅

### C# (Null-Coalescing Operator)

```csharp
string name = user.Name ?? "Unknown";
int port = config.Port ?? 8080;
```

**Different syntax** (`??` vs `?:`), same semantics.

### Swift (Nil-Coalescing Operator)

```swift
let name = user.name ?? "Unknown"
let port = config.port ?? 8080
```

**Different syntax** (`??` vs `?:`), same semantics.

### JavaScript (Nullish Coalescing)

```javascript
const name = user.name ?? "Unknown"
const port = config.port ?? 8080
```

**Different syntax** (`??` vs `?:`), same semantics.
**Note:** JS `??` checks for `null` or `undefined`, not all falsy values.

### Ruby

```ruby
# Ruby doesn't have Elvis, uses ||
name = user.name || "Unknown"
```

**Different semantics:** `||` triggers on any falsy value (nil, false), not just nil.

### Python

```python
# Python doesn't have Elvis, uses or
name = user.name or "Unknown"
```

**Different semantics:** `or` triggers on any falsy value (None, False, 0, "", []), not just None.

### Proposed for Quest

```quest
let name = user.name ?: "Unknown"
```

**Syntax:** `?:` (like Kotlin/Groovy)
**Semantics:** Only `nil` triggers default (not false, 0, "", [])

---

## Why `?:` Instead of `??`

| Operator | Languages | Pros | Cons |
|----------|-----------|------|------|
| `?:` | Kotlin, Groovy, PHP | Looks like "?", clear "or" intent | Requires two characters |
| `??` | C#, Swift, JS, Dart | Clean, symmetric | Less obvious "or" intent |
| `\|\|` | Ruby, Python | Familiar | Wrong semantics (all falsy) |

**Recommendation:** Use `?:` (Elvis)

**Rationale:**
1. **Visual connection to `?`** - Related to optional/nullable concept
2. **"Or" intuition** - `:` resembles "or" in ternary (`? :`)
3. **Precedent** - Kotlin (modern language) uses it successfully
4. **Unique** - Won't conflict with other operators

---

## Precedence

### Operator Precedence Table (Updated)

| Precedence | Operators | Associativity |
|------------|-----------|---------------|
| 1 (Highest) | `()`, `[]`, `.` | Left |
| 2 | `not`, `-` (unary), `+` (unary) | Right |
| 3 | `*`, `/`, `%` | Left |
| 4 | `+`, `-` | Left |
| 5 | `..` (concat) | Left |
| 6 | `==`, `!=`, `<`, `>`, `<=`, `>=` | Left |
| 7 | `&` (bitwise and) | Left |
| 8 | `\|` (bitwise or) | Left |
| 9 | `and` | Left |
| 10 | `or` | Left |
| **11** | **`?:` (Elvis)** | **Right** |
| 12 (Lowest) | `? :` (ternary) | Right |

**Associativity:** Right-to-left (allows chaining)

### Precedence Examples

```quest
# Higher precedence operators bind tighter
let x = a + b ?: c      # (a + b) ?: c
let y = a ?: b + c      # a ?: (b + c)
let z = a == b ?: c     # (a == b) ?: c  (comparison first)

# Elvis has lower precedence than comparison
let valid = x > 0 ?: false  # (x > 0) ?: false

# Elvis chains right-to-left
let x = a ?: b ?: c     # a ?: (b ?: c)

# Elvis has higher precedence than ternary
let x = a ?: b ? c : d  # (a ?: b) ? c : d
```

### Associativity: Right-to-Left

**Right associativity** enables natural chaining:

```quest
# Right associativity: a ?: (b ?: c)
let value = env ?: config ?: default

# Evaluation:
# 1. Check env (nil?)
# 2. If nil, check config (nil?)
# 3. If nil, use default
# First non-nil wins

# Left associativity would be: (a ?: b) ?: c
# This works too, but right is more intuitive
```

---

## Grammar Changes

### Current Grammar (quest.pest)

```pest
expression = { lambda_expr }

lambda_expr = {
    "fun" ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end"
    | logical_or
}

logical_or = { logical_and ~ (or_op ~ logical_and)* }
logical_and = { logical_not ~ (and_op ~ logical_not)* }
# ... rest of precedence chain
```

### Proposed Grammar

```pest
expression = { lambda_expr }

lambda_expr = {
    "fun" ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end"
    | elvis_expr
}

# New: Elvis operator (between or and ternary)
elvis_expr = { ternary_expr ~ (elvis_op ~ ternary_expr)* }
elvis_op = { "?:" }

# Ternary moves down one level
ternary_expr = { logical_or ~ ("?" ~ logical_or ~ ":" ~ logical_or)? }

logical_or = { logical_and ~ (or_op ~ logical_and)* }
logical_and = { logical_not ~ (and_op ~ logical_not)* }
# ... rest unchanged
```

**Changes:**
1. Add `elvis_expr` rule above ternary
2. Add `elvis_op = { "?:" }` token
3. Ternary becomes child of elvis (lower precedence)

---

## Implementation Strategy

### Phase 1: Grammar (30 minutes)

1. Add `elvis_expr` rule to grammar
2. Add `elvis_op` token
3. Update precedence chain
4. Test grammar parsing

**File:** `src/quest.pest`

### Phase 2: Evaluator (1 hour)

Add evaluation logic in `eval_pair()`:

```rust
// In src/main.rs, eval_pair()

Rule::elvis_expr => {
    let mut inner = pair.into_inner();
    let mut result = eval_pair(inner.next().unwrap(), scope)?;

    for pair in inner {
        match pair.as_rule() {
            Rule::elvis_op => {
                // Skip operator token
                continue;
            }
            _ => {
                // If result is nil, evaluate right side
                if matches!(result, QValue::Nil(_)) {
                    result = eval_pair(pair, scope)?;
                }
                // Otherwise keep result (short-circuit)
            }
        }
    }

    Ok(result)
}
```

**Key Points:**
- Evaluate left side once
- Check if nil
- If nil, evaluate and return right side
- If not nil, return left (short-circuit right)

### Phase 3: Testing (2 hours)

Comprehensive test suite:

```quest
# test/operators/elvis_test.q
use "std/test"

test.module("Elvis Operator")

test.describe("Basic nil handling", fun ()
    test.it("returns left if not nil", fun ()
        let x = 5 ?: 10
        test.assert_eq(x, 5, nil)
    end)

    test.it("returns right if left is nil", fun ()
        let x = nil ?: 10
        test.assert_eq(x, 10, nil)
    end)
end)

test.describe("Type preservation", fun ()
    test.it("works with strings", fun ()
        test.assert_eq("hello" ?: "world", "hello", nil)
        test.assert_eq(nil ?: "world", "world", nil)
    end)

    test.it("works with numbers", fun ()
        test.assert_eq(42 ?: 0, 42, nil)
        test.assert_eq(nil ?: 0, 0, nil)
    end)

    test.it("works with arrays", fun ()
        test.assert_eq([1, 2] ?: [], [1, 2], nil)
        test.assert_eq(nil ?: [], [], nil)
    end)
end)

test.describe("Method calls", fun ()
    test.it("evaluates left once", fun ()
        let counter = 0
        fun increment()
            counter = counter + 1
            if counter == 1
                nil
            else
                42
            end
        end

        let result = increment() ?: 99
        test.assert_eq(counter, 1, "Left evaluated once")
        test.assert_eq(result, 99, "Got default")
    end)
end)

test.describe("Chaining", fun ()
    test.it("chains multiple defaults", fun ()
        let a = nil
        let b = nil
        let c = "final"

        test.assert_eq(a ?: b ?: c, "final", nil)
    end)

    test.it("stops at first non-nil", fun ()
        let a = nil
        let b = "middle"
        let c = "final"

        test.assert_eq(a ?: b ?: c, "middle", nil)
    end)
end)

test.describe("Precedence", fun ()
    test.it("has lower precedence than arithmetic", fun ()
        let x = nil
        test.assert_eq(x ?: 5 + 3, 8, nil)  # x ?: (5 + 3)
    end)

    test.it("has lower precedence than comparison", fun ()
        let x = 10
        test.assert_eq(x > 5 ?: false, true, nil)  # (x > 5) ?: false
    end)

    test.it("has higher precedence than ternary", fun ()
        let x = nil
        let result = x ?: 5 > 3 ? "yes" : "no"
        # Parsed as: (x ?: 5) > 3 ? "yes" : "no"
        # (nil ?: 5) = 5, then 5 > 3 = true, then "yes"
        test.assert_eq(result, "yes", nil)
    end)
end)

test.describe("False and zero are not nil", fun ()
    test.it("false returns false, not default", fun ()
        test.assert_eq(false ?: true, false, nil)
    end)

    test.it("zero returns zero, not default", fun ()
        test.assert_eq(0 ?: 42, 0, nil)
    end)

    test.it("empty string returns empty string", fun ()
        test.assert_eq("" ?: "default", "", nil)
    end)

    test.it("empty array returns empty array", fun ()
        let result = [] ?: [1, 2, 3]
        test.assert_eq(result.len(), 0, nil)
    end)
end)
```

### Phase 4: Documentation (1 hour)

Update user documentation, add examples, update grammar reference.

**Total Estimated Effort:** 4-5 hours

---

## Use Cases

### 1. Configuration with Defaults

```quest
use "std/os"
use "std/settings"

# Multi-level fallback: env → config → default
let port = os.getenv("PORT") ?: settings.get("port") ?: 8080
let host = os.getenv("HOST") ?: settings.get("host") ?: "localhost"
let debug = os.getenv("DEBUG") ?: settings.get("debug") ?: false
```

### 2. Dictionary/Map Access

```quest
let config = {"timeout": 30, "retries": 3}

# Provide default if key missing
let timeout = config.get("timeout") ?: 60
let retries = config.get("retries") ?: 5
let port = config.get("port") ?: 8080  # Key doesn't exist
```

### 3. Optional Function Results

```quest
fun find_user(id)
    # Returns user or nil
    # ...
end

# Use default if not found
let user = find_user(123) ?: default_user
let name = find_user(123)?.name ?: "Guest"  # With optional chaining
```

### 4. API Response Handling

```quest
use "std/http/client"
use "std/encoding/json"

let response = http.get("https://api.example.com/data")

if response.ok()
    let data = response.json()

    # Provide defaults for missing fields
    let title = data.get("title") ?: "Untitled"
    let author = data.get("author") ?: "Unknown"
    let tags = data.get("tags") ?: []
    let metadata = data.get("metadata") ?: {}
end
```

### 5. Parsing with Fallbacks

```quest
# Parse user input with fallback
let input = "42"
let value = try_parse_int(input) ?: 0

# Multiple parse attempts
let date = parse_iso_date(input) ?: parse_us_date(input) ?: default_date()
```

### 6. Array/Collection Operations

```quest
# First match or default
let item = array.find(predicate) ?: default_item
let index = array.find_index(predicate) ?: -1
let value = array.first() ?: fallback
```

### 7. Resource Loading

```quest
# Try multiple sources
let template = load_custom_template() ?: load_default_template()
let config = load_user_config() ?: load_system_config() ?: default_config()
```

---

## Edge Cases

### 1. False Is Not Nil

```quest
# Important: Only nil triggers default
let flag = false ?: true
puts(flag)  # false (not true!)

# This is intentional - only nil means "missing"
```

### 2. Zero Is Not Nil

```quest
let count = 0 ?: 10
puts(count)  # 0 (not 10!)

# Use explicit comparison if you want zero to trigger default:
let count = if x == 0 then 10 else x
```

### 3. Empty Collections Are Not Nil

```quest
let items = [] ?: [1, 2, 3]
puts(items.len())  # 0 (empty array is not nil!)

let dict = {} ?: {"default": true}
puts(dict.keys().len())  # 0 (empty dict is not nil!)
```

### 4. Chaining with Side Effects

```quest
# Each side evaluated at most once
let x = expensive1() ?: expensive2() ?: expensive3()

# If expensive1() returns non-nil, expensive2/3 not called
# If expensive1() returns nil, expensive2() called once
# If expensive2() returns nil, expensive3() called once
```

### 5. Nil Literal on Right

```quest
# Technically valid but pointless
let x = something ?: nil  # If something is nil, result is nil

# Better: Just use something directly
let x = something
```

### 6. Nested Elvis in Expressions

```quest
# Complex but valid
let x = (a ?: b) + (c ?: d)
let y = (items.first() ?: default).process()
let z = dict.get(key1 ?: key2) ?: fallback
```

---

## Comparison with Ternary Operator

| Feature | Elvis `a ?: b` | Ternary `a ? b : c` |
|---------|----------------|---------------------|
| **Condition** | Checks if `a` is nil | Checks if `a` is truthy |
| **True branch** | Returns `a` itself | Returns `b` (different expression) |
| **False branch** | Returns `b` | Returns `c` |
| **Evaluation** | `a` evaluated once | `a` evaluated once, then `b` or `c` |
| **Common use** | Default for nil | Conditional choice |

### Examples

```quest
# Elvis: Use value or default
let name = user.name ?: "Unknown"
# If user.name exists: return user.name
# If user.name is nil: return "Unknown"

# Ternary: Choose between two values
let name = is_admin ? "Admin" : "User"
# If is_admin is truthy: return "Admin"
# Otherwise: return "User"

# When they differ:
let x = 0
let y = x ?: 10    # y = 0 (zero is not nil)
let z = x ? 10 : 5 # z = 5 (zero is falsy)
```

---

## Benefits

### 1. Conciseness

**Before:**
```quest
let name = user.name != nil ? user.name : "Unknown"
let port = config.port != nil ? config.port : 8080
let items = get_items() != nil ? get_items() : []
```

**After:**
```quest
let name = user.name ?: "Unknown"
let port = config.port ?: 8080
let items = get_items() ?: []
```

**Result:** 60% reduction in code length.

### 2. Correctness

**Before (Bug Risk):**
```quest
# Easy to mess up - expression called twice!
let result = expensive_call() != nil ? expensive_call() : fallback
# Bug: expensive_call() called twice if not nil
# Could return different values, waste performance

# Need intermediate variable:
let temp = expensive_call()
let result = temp != nil ? temp : fallback
```

**After:**
```quest
# Correct by default - evaluated once
let result = expensive_call() ?: fallback
```

### 3. Readability

**Before:**
```quest
# Intent unclear - why check != nil twice?
let value = dict.get("key") != nil ? dict.get("key") : "default"
```

**After:**
```quest
# Clear intent: "use this or default"
let value = dict.get("key") ?: "default"
```

### 4. Composability

**Before:**
```quest
# Multiple fallbacks - nested ternaries
let port = env_port != nil ? env_port : (config_port != nil ? config_port : 8080)
```

**After:**
```quest
# Clean chaining
let port = env_port ?: config_port ?: 8080
```

---

## Drawbacks and Alternatives

### Drawback 1: New Syntax to Learn

**Concern:** Users need to learn another operator.

**Mitigation:**
- Clear documentation with examples
- Similar to other languages (Kotlin, Groovy, PHP)
- Intuitive once seen: "value or default"

### Drawback 2: Only Checks Nil

**Concern:** Some users might expect it to check false, 0, "", [] too (like Ruby's `||`).

**Mitigation:**
- Document clearly: "Only nil triggers default"
- This is actually a benefit (more predictable)
- Matches modern languages (JS `??`, C# `??`, Swift `??`)

### Alternative 1: Extend || Operator

```quest
# Make || check only nil (like Ruby)
let x = value || default
```

**Rejected:**
- Changes semantics of existing `or` operator
- Breaking change
- Less clear than dedicated operator

### Alternative 2: Use ?? Instead

```quest
# Like C#, Swift, JavaScript
let x = value ?? default
```

**Considered:**
- Valid alternative
- Slightly cleaner visually
- But `?:` has better "or" intuition
- `?:` matches Kotlin (modern, popular language)

**Decision:** Use `?:` (Elvis) per precedent and visual connection to `?`.

### Alternative 3: Add or_else() Method

```quest
# Method-based approach
let x = value.or_else(default)
```

**Rejected:**
- Only works on objects with the method
- Can't chain as cleanly
- More verbose than operator
- Doesn't solve "evaluate once" problem for functions

---

## Implementation Checklist

### Phase 1: Grammar
- [ ] Add `elvis_expr` rule
- [ ] Add `elvis_op` token (`:?`)
- [ ] Update precedence chain
- [ ] Test grammar parsing

### Phase 2: Evaluator
- [ ] Add `Rule::elvis_expr` handler
- [ ] Implement short-circuit evaluation
- [ ] Ensure left side evaluated exactly once
- [ ] Handle chaining (right associativity)

### Phase 3: Testing
- [ ] Basic nil handling (5 tests)
- [ ] Type preservation (4 tests)
- [ ] Method call evaluation (2 tests)
- [ ] Chaining (3 tests)
- [ ] Precedence (3 tests)
- [ ] False/zero not nil (4 tests)
- [ ] Edge cases (3 tests)
- [ ] Total: ~25 tests

### Phase 4: Documentation
- [ ] Add to language guide
- [ ] Add operator reference
- [ ] Add use case examples
- [ ] Update LANGUAGE_FEATURE_COMPARISON.md
- [ ] Add to CLAUDE.md

---

## Examples in Practice

### Example 1: Web Server Configuration

```quest
use "std/os"
use "std/settings"

type ServerConfig
    str: host
    int: port
    bool: debug
    int: workers

    static fun from_env()
        ServerConfig.new(
            host: os.getenv("HOST") ?: settings.get("host") ?: "0.0.0.0",
            port: os.getenv("PORT")?.to_int() ?: settings.get("port") ?: 8080,
            debug: os.getenv("DEBUG") ?: settings.get("debug") ?: false,
            workers: os.getenv("WORKERS")?.to_int() ?: settings.get("workers") ?: 4
        )
    end
end

let config = ServerConfig.from_env()
```

### Example 2: User Profile Display

```quest
type User
    str?: name
    str?: email
    str?: avatar_url
    str?: bio

    fun display_name()
        self.name ?: self.email ?: "Anonymous User"
    end

    fun display_avatar()
        self.avatar_url ?: "/images/default-avatar.png"
    end

    fun display_bio()
        self.bio ?: "No bio provided"
    end
end
```

### Example 3: API Client with Retries

```quest
use "std/http/client"

fun fetch_with_fallback(primary_url, fallback_url)
    let primary = try_fetch(primary_url)
    if primary != nil
        return primary
    end

    let fallback = try_fetch(fallback_url)
    return fallback ?: {"error": "All endpoints failed"}
end

# With Elvis:
fun fetch_with_fallback(primary_url, fallback_url)
    try_fetch(primary_url) ?: try_fetch(fallback_url) ?: {"error": "All endpoints failed"}
end
```

### Example 4: Template Rendering

```quest
fun render_template(data)
    let template = """
    <h1>{{title}}</h1>
    <p>By {{author}}</p>
    <p>{{content}}</p>
    """

    template
        .replace("{{title}}", data.get("title") ?: "Untitled")
        .replace("{{author}}", data.get("author") ?: "Unknown")
        .replace("{{content}}", data.get("content") ?: "No content")
end
```

---

## Migration Path

**No Breaking Changes:**
- Elvis operator is new syntax
- Doesn't change any existing behavior
- Fully backward compatible

**Adoption Path:**
1. Add operator (Phase 1-4)
2. Update standard library to use Elvis where appropriate
3. Document in upgrade guide
4. Provide examples and best practices

---

## Performance Considerations

### Overhead: Minimal

**Elvis operator:**
```quest
let x = expensive() ?: fallback
```

**Compiles to essentially:**
```rust
let temp = expensive();
if temp.is_nil() {
    fallback
} else {
    temp
}
```

**Performance:** Same as manual if/else check.

### Benefit: Prevents Double Evaluation

**Before (inefficient):**
```quest
# Bug: expensive() called twice!
let x = expensive() != nil ? expensive() : fallback

# Must use intermediate:
let temp = expensive()
let x = temp != nil ? temp : fallback
```

**After (efficient):**
```quest
# Automatically efficient
let x = expensive() ?: fallback
```

---

## Future Enhancements

### 1. Optional Chaining (`?.`)

Combine with optional chaining for safe navigation:

```quest
# If optional chaining added in future QEP:
let city = user?.address?.city ?: "Unknown"
let count = data?.items?.len() ?: 0
```

### 2. Elvis Assignment (`?:=`)

Assign only if currently nil:

```quest
# Hypothetical future enhancement
x ?:= default  # Same as: x = x ?: default

# Use case: Lazy initialization
self.cache ?:= {}  # Initialize if not set
```

### 3. Safe Navigation with Elvis

```quest
# Future: Combine ?. and ?:
let value = obj?.nested?.deep?.value ?: default
```

---

## Open Questions

1. **Should we support `??` as alias for `?:`?**
   - **Proposed:** No, choose one syntax
   - **Rationale:** Less confusion, clearer docs

2. **Should Elvis work with exceptions?**
   ```quest
   # Should exception be caught and treated as nil?
   let x = may_throw() ?: default
   ```
   - **Proposed:** No, exceptions propagate normally
   - **Rationale:** Different concern (error handling vs nil handling)

3. **Should empty string/array trigger default?**
   - **Proposed:** No, only nil
   - **Rationale:** More predictable, matches modern languages

---

## References

- Kotlin Elvis Operator: https://kotlinlang.org/docs/null-safety.html#elvis-operator
- Groovy Elvis Operator: https://docs.groovy-lang.org/latest/html/documentation/#_elvis_operator
- C# Null-Coalescing: https://docs.microsoft.com/en-us/dotnet/csharp/language-reference/operators/null-coalescing-operator
- Swift Nil-Coalescing: https://docs.swift.org/swift-book/LanguageGuide/BasicOperators.html
- JavaScript Nullish Coalescing: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Nullish_coalescing

---

## Conclusion

The Elvis operator (`?:`) fills a critical gap in Quest's nil-handling capabilities. It provides:

1. **Concise syntax** for default values (60% reduction vs ternary)
2. **Correctness** by default (evaluates once, can't double-evaluate)
3. **Readability** through clear "value or default" intent
4. **Composability** via natural chaining

**Implementation is straightforward** (~4-5 hours) and leverages existing grammar infrastructure. The operator is familiar to developers from Kotlin, Groovy, and PHP, making adoption smooth.

**Recommendation:** Implement in next minor version.

---

## Status

- [ ] Grammar design
- [ ] Grammar implementation
- [ ] Evaluator implementation
- [ ] Unit tests (25 tests)
- [ ] Integration tests
- [ ] Documentation (language guide)
- [ ] Examples
- [ ] LANGUAGE_FEATURE_COMPARISON.md update
- [ ] CLAUDE.md update

**Estimated Total Effort:** 4-5 hours
