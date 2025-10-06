# QEP-017: Const Keyword

**Status:** ✅ Implemented
**Author:** Quest Team
**Created:** 2025-10-05
**Implemented:** 2025-10-05
**Related:** Variables, Scoping

## Abstract

This QEP proposes adding a `const` keyword for declaring immutable constants in Quest. Constants are single-assignment variables that cannot be reassigned after initialization, providing compile-time/runtime guarantees for values that shouldn't change.

## Motivation

### Current Limitations

Quest currently has no way to prevent variable reassignment:

```quest
let PI = 3.14159
# ... later in code ...
PI = 3.14  # Oops! Accidentally changed PI - no error

let MAX_USERS = 1000
# ... somewhere else ...
MAX_USERS = 500  # Silently changes the "constant"
```

Problems:
1. **No immutability guarantee** - Important values can be accidentally changed
2. **Convention only** - UPPERCASE naming is just convention, not enforced
3. **Refactoring hazards** - Hard to know if a value is meant to be constant
4. **Code clarity** - Intent isn't clear from syntax alone

### Benefits

Constants provide:

1. **Immutability** - Values can't be changed after initialization
2. **Intent clarity** - `const` explicitly means "don't change this"
3. **Error prevention** - Runtime error on reassignment attempts
4. **Compiler optimization** - Potential for optimizations (future)
5. **Better semantics** - Matches JavaScript, Rust, and other modern languages

## Specification

### Syntax

```quest
const <IDENTIFIER> = <expression>
```

### Rules

1. **Naming convention:**
   - Constants should use SCREAMING_SNAKE_CASE (e.g., `MAX_SIZE`, `PI`)
   - This is a strong convention, not enforced by the compiler
   - Lowercase names are allowed but discouraged

2. **Initialization:**
   - Must be initialized at declaration time
   - `const X` without value is an error

3. **Reassignment:**
   - Reassignment is a runtime error
   - `const X = 5; X = 10` raises error

4. **Scope:**
   - Same scoping rules as `let` variables
   - Constants are not global by default

5. **Shadowing:**
   - Constants can be shadowed in nested scopes
   - Shadowing creates a new constant, doesn't modify the original

6. **Mutability of contents:**
   - For primitive types (Int, Float, Str, Bool): fully immutable
   - For reference types (Array, Dict, Struct): the binding is immutable, but contents may be mutable
   - **Alternative design:** Make contents deeply immutable (discussed below)

### Grammar

```pest
const_declaration = {
    "const" ~ identifier ~ "=" ~ expression
}

statement = {
    const_declaration
    | let_statement
    | assignment
    | ...
}
```

## Examples

### Basic Constants

```quest
const PI = 3.14159
const E = 2.71828
const MAX_SIZE = 1000
const APP_NAME = "Quest App"
const DEBUG = true

puts(PI)  # 3.14159

# Error: Cannot reassign constant
PI = 3.14  # RuntimeError: Cannot reassign constant 'PI'
```

### Expression Initialization

```quest
const SECONDS_PER_DAY = 60 * 60 * 24  # 86400
const GREETING = "Hello, " .. "World!"
const VERSION = "1.0.0"
const MAX_RETRIES = 3

# Can use other constants
const DOUBLE_MAX_RETRIES = MAX_RETRIES * 2
```

### Scoped Constants

```quest
const OUTER = 100

fun test()
    const INNER = 200
    puts(OUTER)  # 100
    puts(INNER)  # 200
end

test()
# puts(INNER)  # Error: INNER not in scope
```

### Shadowing

```quest
const X = 10

if true
    const X = 20  # Shadows outer X
    puts(X)       # 20
end

puts(X)  # 10 (original X unchanged)
```

### Module Constants

```quest
# math_constants.q
const PI = 3.14159265359
const E = 2.71828182846
const PHI = 1.61803398875  # Golden ratio
const TAU = 6.28318530718  # 2 * PI

# main.q
use "math_constants"

puts(math_constants.PI)  # Access module constant
```

### Configuration Constants

```quest
# config.q
const DATABASE_URL = "postgresql://localhost:5432/mydb"
const MAX_CONNECTIONS = 100
const TIMEOUT_MS = 5000
const RETRY_COUNT = 3
const DEBUG_MODE = false

# app.q
use "config"

fun connect_to_db()
    puts("Connecting to: " .. config.DATABASE_URL)
    # ...
end
```

## Reference Type Mutability

### Design Decision: Shallow Immutability

Constants have **shallow immutability** - the binding cannot change, but contents of reference types can:

```quest
const NUMBERS = [1, 2, 3]

# Error: Cannot reassign constant
NUMBERS = [4, 5, 6]  # ❌ Error

# Allowed: Mutating contents
NUMBERS.push(4)      # ✅ OK - modifies array contents
puts(NUMBERS)        # [1, 2, 3, 4]

const CONFIG = {"debug": true}

# Error: Cannot reassign constant
CONFIG = {"debug": false}  # ❌ Error

# Allowed: Mutating contents
CONFIG.set("debug", false)  # ✅ OK - modifies dict contents
puts(CONFIG)                # {"debug": false}
```

**Rationale:**
- Matches JavaScript `const` behavior
- Simpler to implement
- Most use cases care about the binding, not deep immutability
- Deep immutability can be added via future `.freeze()` method

### Alternative: Deep Immutability (Not Chosen)

```quest
# Hypothetical deep immutability (NOT in this QEP)
const NUMBERS = [1, 2, 3]

NUMBERS = [4, 5, 6]  # ❌ Error: Cannot reassign
NUMBERS.push(4)      # ❌ Error: Cannot mutate frozen array
```

This would require:
- Frozen/immutable collection types
- More complex implementation
- May not match user expectations (JavaScript developers expect shallow)

**Proposed:** Start with shallow immutability. Add `.freeze()` method in future QEP if deep immutability is needed.

## Comparison with Other Languages

### JavaScript

```javascript
const PI = 3.14;
PI = 3;  // Error

const arr = [1, 2];
arr = [3, 4];    // Error
arr.push(3);     // OK - shallow immutability
```

Quest matches JavaScript behavior. ✅

### Rust

```rust
const PI: f64 = 3.14;
// PI = 3.0;  // Compile error

let x = 5;
// x = 6;  // Compile error (immutable by default)

let mut y = 5;
y = 6;  // OK - explicit mutability
```

Rust has `const` for compile-time constants and immutable-by-default bindings. Quest is different (mutable by default).

### Python

```python
# No const keyword - convention only
PI = 3.14
PI = 3  # No error - just convention
```

Quest improves on Python by enforcing immutability.

### Ruby

```ruby
PI = 3.14
PI = 3  # Warning: already initialized constant (but still allows it)
```

Ruby warns but allows reassignment. Quest prevents it completely.

## Implementation Strategy

### Phase 1: Grammar & Keywords

1. Add `const` to keywords in `quest.pest`
2. Add `const_declaration` rule
3. Update statement alternatives

```pest
keyword = @{
    ("let" | "if" | "elif" | "else" | "end"
    | "fun" | "return" | "for" | "in" | "while"
    | "type" | "trait" | "impl" | "static"
    | "use" | "and" | "or" | "not" | "nil"
    | "true" | "false" | "try" | "catch" | "raise"
    | "ensure" | "with" | "as" | "del"
    | "case" | "when"
    | "const" | "break" | "continue" | "pub")
    ~ !(ASCII_ALPHANUMERIC | "_")
}

const_declaration = {
    "const" ~ identifier ~ "=" ~ expression
}
```

### Phase 2: Scope Tracking

Add constant tracking to Scope:

```rust
pub struct Scope {
    pub variables: HashMap<String, QValue>,
    pub constants: HashSet<String>,  // Track which variables are constants
    // ... other fields
}
```

### Phase 3: Evaluator Changes

1. **Handle const declaration:**

```rust
Rule::const_declaration => {
    let mut inner = pair.into_inner();
    let name = inner.next().unwrap().as_str().to_string();
    let value = eval_pair(inner.next().unwrap(), scope)?;

    // Check if already defined as constant
    if scope.constants.contains(&name) {
        return Err(format!("Cannot redeclare constant '{}'", name));
    }

    // Store value and mark as constant
    scope.variables.insert(name.clone(), value);
    scope.constants.insert(name);

    Ok(QValue::Nil(QNil::new()))
}
```

2. **Modify assignment handler:**

```rust
Rule::assignment => {
    let mut inner = pair.into_inner();
    let name = inner.next().unwrap().as_str();

    // Check if constant
    if scope.constants.contains(name) {
        return Err(format!("Cannot reassign constant '{}'", name));
    }

    // ... rest of assignment logic
}
```

3. **Handle compound assignment:**

```rust
// +=, -=, etc. should also check for constants
if scope.constants.contains(&var_name) {
    return Err(format!("Cannot modify constant '{}'", var_name));
}
```

### Phase 4: Testing

Comprehensive tests for:
- Basic const declarations
- Reassignment errors
- Compound assignment errors
- Scoping behavior
- Shadowing
- Reference type mutability
- Initialization requirements

**Estimated effort:** 3-4 hours total

## Testing Strategy

### Basic Tests

```quest
# test/variables/const_test.q
use "std/test"

test.module("Const Keyword")

test.describe("Basic const declaration", fun ()
    test.it("declares constant", fun ()
        const X = 42
        test.assert_eq(X, 42, nil)
    end)

    test.it("allows multiple constants", fun ()
        const A = 1
        const B = 2
        const C = 3
        test.assert_eq(A + B + C, 6, nil)
    end)

    test.it("works with different types", fun ()
        const INT_VAL = 42
        const FLOAT_VAL = 3.14
        const STR_VAL = "hello"
        const BOOL_VAL = true

        test.assert_eq(INT_VAL.cls(), "Int", nil)
        test.assert_eq(FLOAT_VAL.cls(), "Float", nil)
        test.assert_eq(STR_VAL.cls(), "Str", nil)
        test.assert_eq(BOOL_VAL.cls(), "Bool", nil)
    end)
end)

test.describe("Const immutability", fun ()
    test.it("prevents reassignment", fun ()
        const X = 10

        test.assert_raises(fun ()
            X = 20
        end, "Cannot reassign constant", nil)
    end)

    test.it("prevents compound assignment", fun ()
        const X = 10

        test.assert_raises(fun ()
            X += 5
        end, "Cannot modify constant", nil)
    end)

    test.it("prevents all compound operators", fun ()
        const X = 10

        test.assert_raises(fun () X += 1 end, nil, nil)
        test.assert_raises(fun () X -= 1 end, nil, nil)
        test.assert_raises(fun () X *= 2 end, nil, nil)
        test.assert_raises(fun () X /= 2 end, nil, nil)
    end)
end)

test.describe("Const initialization", fun ()
    test.it("requires initial value", fun ()
        test.assert_raises(fun ()
            eval("const X")
        end, nil, nil)
    end)

    test.it("can initialize with expressions", fun ()
        const A = 5 + 5
        const B = 10 * 2
        const C = "Hello" .. " World"

        test.assert_eq(A, 10, nil)
        test.assert_eq(B, 20, nil)
        test.assert_eq(C, "Hello World", nil)
    end)

    test.it("can reference other constants", fun ()
        const X = 10
        const Y = X * 2
        const Z = Y + X

        test.assert_eq(Z, 30, nil)
    end)
end)

test.describe("Const scoping", fun ()
    test.it("respects function scope", fun ()
        const OUTER = 100

        fun test_func()
            const INNER = 200
            OUTER + INNER
        end

        test.assert_eq(test_func(), 300, nil)
    end)

    test.it("allows shadowing in nested scopes", fun ()
        const X = 10

        if true
            const X = 20
            test.assert_eq(X, 20, "Inner X should be 20")
        end

        test.assert_eq(X, 10, "Outer X should still be 10")
    end)

    test.it("shadowed constant is independent", fun ()
        const X = 10

        if true
            const X = 20
            # This X is a new constant, not the outer one
            test.assert_raises(fun ()
                X = 30
            end, "Cannot reassign constant", nil)
        end

        # Outer X is unchanged
        test.assert_eq(X, 10, nil)
    end)
end)

test.describe("Const with reference types", fun ()
    test.it("prevents rebinding of arrays", fun ()
        const ARR = [1, 2, 3]

        test.assert_raises(fun ()
            ARR = [4, 5, 6]
        end, "Cannot reassign constant", nil)
    end)

    test.it("allows mutating array contents", fun ()
        const ARR = [1, 2, 3]
        ARR.push(4)

        test.assert_eq(ARR.len(), 4, nil)
        test.assert_eq(ARR.get(3), 4, nil)
    end)

    test.it("prevents rebinding of dicts", fun ()
        const CONFIG = {"debug": true}

        test.assert_raises(fun ()
            CONFIG = {"debug": false}
        end, "Cannot reassign constant", nil)
    end)

    test.it("allows mutating dict contents", fun ()
        const CONFIG = {"debug": true}
        CONFIG.set("debug", false)

        test.assert_eq(CONFIG.get("debug"), false, nil)
    end)
end)
```

### Integration Tests

```quest
test.describe("Real-world usage", fun ()
    test.it("mathematical constants", fun ()
        const PI = 3.14159
        const E = 2.71828
        const TAU = 2 * PI

        let circle_area = fun (r)
            PI * r * r
        end

        test.assert(circle_area(10) > 314.0, nil)
    end)

    test.it("configuration constants", fun ()
        const MAX_RETRIES = 3
        const TIMEOUT_MS = 5000
        const BASE_URL = "https://api.example.com"

        fun make_request()
            let retries = 0
            while retries < MAX_RETRIES
                # Attempt request...
                retries += 1
            end
            retries
        end

        test.assert_eq(make_request(), 3, nil)
    end)
end)
```

## Documentation Updates

### CLAUDE.md

Add to Variables & Scoping section:

```markdown
### Constants

**Declaration**: Use `const` keyword for immutable values
```quest
const PI = 3.14159
const MAX_SIZE = 1000
const APP_NAME = "Quest"
```

**Rules:**
- Must be initialized at declaration
- Cannot be reassigned (runtime error)
- Convention: SCREAMING_SNAKE_CASE for names
- Scoping: Same as `let` variables
- Shadowing: Allowed in nested scopes
- Reference types: Binding is immutable, contents may be mutable

**Examples:**
```quest
const X = 42
X = 50  # Error: Cannot reassign constant 'X'

const ARR = [1, 2, 3]
ARR = [4, 5, 6]  # Error: Cannot reassign constant
ARR.push(4)      # OK: Mutating contents is allowed
```
```

### User Documentation (docs/docs/language/variables.md)

Add comprehensive section:
- What are constants
- When to use constants vs let
- Naming conventions
- Scoping behavior
- Reference type mutability
- Common patterns and use cases

### LANGUAGE_FEATURE_COMPARISON.md

Update from ❌ to ✅:
```markdown
| Constants | ✅ `const` keyword | ⚠️ Convention (CAPS) | ✅ CONSTANT | Quest has enforced constants |
```

## Design Decisions

### 1. Shallow vs Deep Immutability

**Chosen:** Shallow immutability (binding only)

**Rationale:**
- Matches JavaScript `const` (familiar to most developers)
- Simpler implementation
- Most use cases care about preventing reassignment
- Deep immutability can be added via `.freeze()` method later

### 2. Naming Convention

**Chosen:** Convention (SCREAMING_SNAKE_CASE), not enforced

**Rationale:**
- Flexibility for developers
- Lowercase constants may be appropriate in some contexts
- Linters can enforce style rules
- Python/JavaScript also don't enforce naming

### 3. Initialization Requirement

**Chosen:** Must initialize at declaration

```quest
const X = 5     # ✅ OK
const Y         # ❌ Error: const requires initialization
```

**Rationale:**
- A constant without a value doesn't make sense
- Prevents bugs from uninitialized constants
- Matches JavaScript behavior

### 4. Scope Rules

**Chosen:** Same as `let` (not global by default)

**Rationale:**
- Consistency with existing variables
- Module-level constants can be achieved with module scope
- Global constants are rare and can be passed explicitly

### 5. Redeclaration

**Chosen:** Error on redeclaration in same scope, allow shadowing

```quest
const X = 10
const X = 20  # Error: Cannot redeclare constant 'X'

if true
    const X = 20  # OK: Shadows outer X
end
```

**Rationale:**
- Prevents accidental redeclaration bugs
- Shadowing is useful for refactoring
- Matches most languages with const

## Error Messages

Good error messages for common mistakes:

```
Error: Cannot reassign constant 'PI' at line 5
  PI = 3.14
  ^^

Error: Constant 'MAX_SIZE' requires initialization at line 3
  const MAX_SIZE
  ^^^^^^^^^^^^^^

Error: Cannot modify constant 'COUNT' with compound assignment at line 8
  COUNT += 1
  ^^^^^^^^^^

Error: Constant 'DEBUG' is already declared at line 12
  const DEBUG = false
  ^^^^^^^^^^^^^^^^^^^
```

## Future Enhancements

### 1. Compile-Time Constants (Future QEP)

Evaluate at compile time for optimization:

```quest
const PI = 3.14159  # Evaluated at runtime currently

# Future: compile-time evaluation
const TWICE_PI = PI * 2  # Could be folded at compile time
```

### 2. Frozen Collections (Future QEP)

Deep immutability:

```quest
const NUMBERS = [1, 2, 3].freeze()
NUMBERS.push(4)  # Error: Cannot modify frozen array

const CONFIG = {"debug": true}.freeze()
CONFIG.set("debug", false)  # Error: Cannot modify frozen dict
```

### 3. Type Annotations on Constants

```quest
const PI: float = 3.14159
const MAX_SIZE: int = 1000
```

## Breaking Changes

**Minimal:**
- `const` becomes a reserved keyword
- Code using `const` as a variable name will break (unlikely)

## Migration

No migration needed for existing code. Constants are opt-in.

## Performance Considerations

**Current:** No performance benefit (constants stored like variables)

**Future optimizations:**
- Compile-time constant folding
- Inline constant values
- Memory layout optimizations

**Note:** Start with correctness, optimize later.

## Status

- [x] Grammar design (quest.pest:53)
- [x] Add const keyword (already in keywords)
- [x] Add constant tracking to Scope (scope.rs:97, 112, 147, 168, 217-236)
- [x] Update assignment handlers (main.rs:1087-1094)
- [x] Const declaration handler (main.rs:492-501)
- [x] Basic tests (test/variables/const_test.q)
- [x] Scoping tests (26 total tests)
- [x] Reference type tests (shallow immutability tested)
- [x] Error message tests (reassignment and compound assignment)
- [x] Documentation
- [x] CLAUDE.md updates
- [x] User docs (docs/docs/language/variables.md)

## Implementation Notes

**Files Changed:**
- `src/quest.pest` - Added `const_declaration` rule
- `src/scope.rs` - Added `constants: Vec<HashSet<String>>` tracking, `declare_const()`, `is_const()` methods
- `src/main.rs` - Added `Rule::const_declaration` handler, updated assignment to check constants
- `test/variables/const_test.q` - 26 comprehensive tests
- `docs/docs/language/variables.md` - Full const documentation section
- `CLAUDE.md` - Updated variables line to mention const

**Test Coverage:**
- 26 tests covering all aspects of const behavior
- All tests passing (100%)
- Tests cover: declaration, immutability, scoping, shadowing, reference types, real-world usage

## Conclusion

The `const` keyword provides much-needed immutability guarantees for Quest, preventing accidental reassignment of important values. The shallow immutability model matches JavaScript's familiar behavior while keeping implementation simple.

This is a low-effort, high-value feature that improves code safety and clarity.

## References

- JavaScript const: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/const
- Rust const: https://doc.rust-lang.org/std/keyword.const.html
- Python PEP 591: Adding a final qualifier to typing
