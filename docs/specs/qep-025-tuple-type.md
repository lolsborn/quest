# QEP-025: Immutable Tuple Type

**Status:** Draft
**Created:** 2025-10-05
**Author:** Quest Language Team

## Abstract

This QEP proposes adding an immutable **Tuple** type to Quest for representing fixed-size, ordered collections of heterogeneous values. Tuples complement Quest's existing Array type by providing immutability guarantees and are commonly used for multiple return values, dictionary keys, and data structures that shouldn't change.

## Motivation

Quest currently has Arrays (mutable, variable-length) and Dicts (mutable, key-value). Many use cases benefit from immutable, fixed-size sequences:

### Use Case 1: Multiple Return Values
```quest
# Current: Must use array
fun get_user()
    return ["Alice", 30, "alice@example.com"]
end

let user = get_user()
let name = user[0]   # Unclear what index means
let age = user[1]    # Type is Array, could be modified accidentally
```

With tuples:
```quest
fun get_user()
    return ("Alice", 30, "alice@example.com")
end

let (name, age, email) = get_user()  # Unpacking
```

### Use Case 2: Dictionary Keys
```quest
# Current: Can't use arrays as keys (they're mutable)
let coords = {}
coords["1,2"] = "treasure"  # String workaround

# With tuples (immutable, hashable):
let coords = {}
coords[(1, 2)] = "treasure"
coords[(3, 4)] = "monster"
```

### Use Case 3: Coordinates and Fixed Data
```quest
# RGB colors
let red = (255, 0, 0)
let green = (0, 255, 0)

# 2D/3D coordinates
let point = (10, 20)
let point3d = (10, 20, 30)

# Guaranteed to never change
fun process_color(color)
    let (r, g, b) = color
    # color can't be accidentally modified
end
```

### Use Case 4: Returning Multiple Values from DB Queries
```quest
fun get_min_max(table, column)
    let result = cursor.fetch_one()
    return (result.get("min"), result.get("max"))
end

let (min_age, max_age) = get_min_max("users", "age")
```

## Design Goals

1. **Immutability**: Once created, tuples cannot be modified
2. **Heterogeneous**: Can contain different types (like arrays)
3. **Hashable**: Can be used as dictionary keys (unlike arrays)
4. **Efficient**: Similar memory/performance to arrays
5. **Ergonomic**: Clean syntax for creation and unpacking
6. **Type Safety**: Clear distinction from arrays

## Specification

### Syntax for Tuple Creation

**Decided Approach**: Use `Tuple.new()` with variadic arguments

```quest
# No empty tuples - must have at least one element
let single = Tuple.new(42)
let pair = Tuple.new(1, 2)
let triple = Tuple.new("a", 2, 3.14)
let nested = Tuple.new(1, Tuple.new(2, 3), 4)
```

**Decision**: Empty tuples are **not supported**. Tuples must contain at least one element. Use `nil` for "no value" scenarios.

**Advantages**:
- ✅ No grammar ambiguity with `(expr)` grouping
- ✅ Consistent with Quest's object construction (`Array.new()`, `Dict.new()`)
- ✅ No single-element trailing comma confusion
- ✅ Explicit and clear
- ✅ Requires variadic args implementation (useful for other features)

**Alternative**: Parentheses literals `(1, 2, 3)`
- ❌ Ambiguous with expression grouping `(2 + 3)`
- ❌ Requires special parsing rules
- ❌ Trailing comma for single element: `(42,)` is confusing
- ✅ More concise and Python/Rust-like

**Recommendation**: Start with `Tuple.new()`, potentially add literal syntax later if demand exists.

### Variadic Arguments Dependency

This approach requires implementing **variadic function arguments**:

```quest
# Variadic function syntax
fun my_function(...args)
    # args is a Tuple containing all arguments
    for arg in args
        puts(arg)
    end
end

my_function(1, 2, 3)  # args = Tuple.new(1, 2, 3)
```

Or for types:
```quest
type Tuple
    fun self.new(...elements)
        # Create tuple from elements
    end
end
```

**Question**: What syntax for variadic parameters?
- **Option A**: `...args` (JavaScript-style)
- **Option B**: `*args` (Python-style)
- **Option C**: `args...` (Go-style)

**Recommendation**: `...args` (JavaScript/TypeScript familiarity)

### Accessing Elements

Same as arrays - zero-indexed with `[]`:

```quest
let point = Tuple.new(10, 20, 30)
puts(point[0])  # 10
puts(point[1])  # 20
puts(point[2])  # 30
```

### Immutability

Tuples are immutable - no modification methods:

```quest
let t = Tuple.new(1, 2, 3)
t[0] = 5        # Error: Tuples are immutable
t.push(4)       # Error: Method 'push' not found on Tuple
t.pop()         # Error: Method 'pop' not found on Tuple
```

### Unpacking/Destructuring

Unpack tuples into multiple variables using special syntax:

```quest
# Basic unpacking
let (x, y) = Tuple.new(10, 20)
puts(x)  # 10
puts(y)  # 20

# Function returns
fun get_coords()
    return Tuple.new(100, 200)
end

let (x, y) = get_coords()

# Nested unpacking
let (a, (b, c), d) = Tuple.new(1, Tuple.new(2, 3), 4)
# a=1, b=2, c=3, d=4
```

**Note**: The unpacking syntax `let (x, y) = ...` is **special syntax for tuple destructuring**, not creating a tuple literal on the left side. The parentheses here indicate "unpack into these variables" rather than "create a tuple".

### Ignoring Values with Underscore

Use `_` to ignore values during unpacking:

```quest
let (x, _, z) = Tuple.new(1, 2, 3)
# x = 1, z = 3 (middle value ignored)

let (first, _, _, last) = Tuple.new("a", "b", "c", "d")
# first = "a", last = "d"
```

**Decision**: Underscore `_` is supported for ignored values. **No spread/rest operator** (`...rest`) in MVP.

### Tuple Methods

#### `len()`
Returns the number of elements.

```quest
let t = Tuple.new(1, 2, 3)
puts(t.len())  # 3
```

#### `get(index)`
Get element at index (same as `[]`).

```quest
let t = Tuple.new("a", "b", "c")
puts(t.get(1))  # "b"
```

#### `contains(value)`
Check if tuple contains a value.

```quest
let t = Tuple.new(1, 2, 3)
puts(t.contains(2))  # true
puts(t.contains(5))  # false
```

#### `to_array()`
Convert tuple to array (mutable).

```quest
let t = Tuple.new(1, 2, 3)
let arr = t.to_array()  # [1, 2, 3]
arr.push(4)  # OK - arrays are mutable
```

#### `count(value)`
Count occurrences of value.

```quest
let t = Tuple.new(1, 2, 2, 3, 2)
puts(t.count(2))  # 3
```

#### `index(value)`
Find first index of value.

```quest
let t = Tuple.new("a", "b", "c", "b")
puts(t.index("b"))  # 1
puts(t.index("d"))  # nil (or error?)
```

### Comparison and Equality

Tuples support equality and comparison:

```quest
let t1 = Tuple.new(1, 2, 3)
let t2 = Tuple.new(1, 2, 3)
let t3 = Tuple.new(1, 2, 4)

puts(t1 == t2)   # true (value equality)
puts(t1 == t3)   # false
puts(t1 != t3)   # true

# Lexicographic comparison
puts(Tuple.new(1, 2) < Tuple.new(1, 3))    # true
puts(Tuple.new(2, 1) > Tuple.new(1, 3))    # true
puts(Tuple.new(1, 2, 3) < Tuple.new(1, 2)) # false (longer is greater)
```

### Tuples as Dictionary Keys

Tuples are hashable and can be used as dictionary keys:

```quest
let coords = {}
coords[Tuple.new(0, 0)] = "origin"
coords[Tuple.new(1, 2)] = "point A"
coords[Tuple.new(1, 2)] = "point B"  # Overwrites (same key)

puts(coords[Tuple.new(1, 2)])  # "point B"
puts(coords.contains(Tuple.new(0, 0)))  # true
```

**Decision**: Tuples with mutable elements **cannot be used as dictionary keys**.

```quest
let t1 = Tuple.new(1, 2, 3)      # All immutable - OK as key
let t2 = Tuple.new([1, 2], 3)    # Contains array (mutable)

let dict = {}
dict[t1] = "value"               # ✓ OK

dict[t2] = "value"               # ✗ Error: Tuple contains mutable element (Array at index 0) and cannot be used as dictionary key
```

**Allowed as keys**: Int, Float, Str, Bool, Nil, Decimal, BigInt, Tuple (if nested tuples are also valid)
**Not allowed as keys**: Array, Dict, custom types with mutable state

### Type Representation

Tuples have type `"Tuple"`:

```quest
let t = (1, 2, 3)
puts(t.cls())    # "Tuple"
puts(t._type())  # "Tuple"
puts(t._rep())   # "(1, 2, 3)"
```

### Iteration

Tuples are iterable:

```quest
let t = Tuple.new("a", "b", "c")

for item in t
    puts(item)
end
# Prints: a, b, c
```

### Conversion Between Tuples and Arrays

```quest
# Tuple → Array
let t = Tuple.new(1, 2, 3)
let arr = t.to_array()  # [1, 2, 3]

# Array → Tuple
let arr = [1, 2, 3]
let t = Tuple.from_array(arr)  # Tuple.new(1, 2, 3)
```

## Variadic Arguments (Prerequisite)

To implement `Tuple.new(1, 2, 3)`, Quest needs variadic function arguments.

### Syntax

```quest
fun my_function(...args)
    # args is a Tuple containing all arguments
    puts("Received " .. args.len() .. " arguments")
    for arg in args
        puts(arg)
    end
end

my_function(1, 2, 3, 4)
# Prints:
# Received 4 arguments
# 1
# 2
# 3
# 4
```

### With Named Parameters

```quest
fun greet(prefix, ...names)
    for name in names
        puts(prefix .. ", " .. name)
    end
end

greet("Hello", "Alice", "Bob", "Charlie")
# Prints:
# Hello, Alice
# Hello, Bob
# Hello, Charlie
```

### Implementation in Types

```quest
type Tuple
    fun self.new(...elements)
        # Create QTuple from elements
        # Implementation detail: elements is internally Vec<QValue>
    end
end
```

### Grammar for Variadic Parameters

```pest
parameter_list = {
    parameter ~ ("," ~ parameter)*
    | variadic_parameter
    | parameter ~ ("," ~ parameter)* ~ "," ~ variadic_parameter
}

variadic_parameter = {
    "..." ~ identifier
}
```

### Variadic Argument Packing

When a function with `...args` is called:

```quest
fun test(...args)
    # args is automatically a Tuple
end

test(1, 2, 3)  # args = Tuple.new(1, 2, 3)
```

**Implementation Note**: The evaluator packs remaining arguments into a Tuple automatically.

## Grammar Changes

### Pest Grammar

**Note**: Since tuples use `Tuple.new()` syntax, no special grammar for tuple literals is needed. The grammar changes focus on:

1. **Variadic parameters**
2. **Tuple unpacking in let statements**

```pest
// Variadic parameter in function definitions
parameter_list = {
    parameter ~ ("," ~ parameter)*
    | parameter ~ ("," ~ parameter)* ~ "," ~ variadic_parameter
    | variadic_parameter
}

variadic_parameter = {
    "..." ~ identifier
}

// Tuple unpacking in let statement
tuple_unpacking = {
    "(" ~ tuple_unpack_item ~ ("," ~ tuple_unpack_item)* ~ ")"
}

tuple_unpack_item = {
    identifier | "_" | tuple_unpacking  // Support nested unpacking
}

let_statement = {
    "let" ~ tuple_unpacking ~ "=" ~ expression    // let (x, y) = Tuple.new(1, 2)
    | "let" ~ identifier ~ "=" ~ expression       // let x = 5
}
```

**No ambiguity**: Since we use `Tuple.new()`, there's no confusion between grouping `(expr)` and tuple literals.

## Implementation Details

### Internal Representation

```rust
#[derive(Debug, Clone)]
pub struct QTuple {
    pub elements: Vec<QValue>,
    pub id: u64,
}

impl QTuple {
    pub fn new(elements: Vec<QValue>) -> Self {
        QTuple {
            elements,
            id: next_object_id(),
        }
    }

    pub fn get(&self, index: usize) -> Option<&QValue> {
        self.elements.get(index)
    }

    pub fn len(&self) -> usize {
        self.elements.len()
    }

    pub fn hash(&self) -> Result<u64, String> {
        // Hash all elements if all are immutable
        // Return error if any element is mutable
    }
}
```

### QValue Enum Addition

```rust
pub enum QValue {
    // ... existing variants
    Tuple(QTuple),
}
```

### Hashing for Dictionary Keys

```rust
impl Hash for QTuple {
    fn hash<H: Hasher>(&self, state: &mut H) {
        for element in &self.elements {
            match element {
                QValue::Int(i) => i.value.hash(state),
                QValue::Str(s) => s.value.hash(state),
                QValue::Bool(b) => b.value.hash(state),
                QValue::Tuple(t) => t.hash(state),
                QValue::Nil(_) => 0.hash(state),
                // Mutable types - error or skip?
                _ => return Err("Tuple contains unhashable element"),
            }
        }
        Ok(())
    }
}
```

## Examples

### Example 1: RGB Color Processing

```quest
type Color
    tuple: rgb

    fun self.red()
        Color.new(rgb: (255, 0, 0))
    end

    fun self.green()
        Color.new(rgb: (0, 255, 0))
    end

    fun brightness()
        let (r, g, b) = self.rgb
        (r + g + b) / 3
    end

    fun invert()
        let (r, g, b) = self.rgb
        Color.new(rgb: (255 - r, 255 - g, 255 - b))
    end
end

let red = Color.red()
puts(red.brightness())  # 85
let cyan = red.invert()
puts(cyan.rgb)          # (0, 255, 255)
```

### Example 2: Function with Multiple Returns

```quest
fun divide_with_remainder(dividend, divisor)
    let quotient = dividend / divisor
    let remainder = dividend % divisor
    return (quotient, remainder)
end

let (q, r) = divide_with_remainder(17, 5)
puts("17 / 5 = " .. q .. " remainder " .. r)
# Output: 17 / 5 = 3 remainder 2
```

### Example 3: Grid/Board Games

```quest
# Chess board coordinates
let board = {}
board[(0, 0)] = "rook"
board[(0, 1)] = "knight"
board[(0, 7)] = "rook"

fun move_piece(from, to)
    let piece = board[from]
    board.del(from)
    board[to] = piece
end

move_piece((0, 0), (0, 3))  # Move rook
```

### Example 4: Database Results

```quest
use "std/db/postgres"

fun get_user_summary(user_id)
    let cursor = conn.cursor()
    cursor.execute("SELECT name, email, created_at FROM users WHERE id = $1", [user_id])
    let row = cursor.fetch_one()

    return (
        row.get("name"),
        row.get("email"),
        row.get("created_at")
    )
end

let (name, email, created) = get_user_summary(42)
puts("User: " .. name)
puts("Email: " .. email)
```

### Example 5: Named Tuple Pattern (Struct-like)

```quest
# Simulate named tuples with comments
fun create_point(x, y)
    # Returns (x, y) tuple
    return (x, y)
end

let point = create_point(10, 20)
let (x, y) = point
```

Or with a type wrapper:
```quest
type Point
    tuple: coords  # (x, y)

    fun x()
        self.coords[0]
    end

    fun y()
        self.coords[1]
    end
end
```

## Design Decisions (Finalized)

### 1. Syntax: Tuple.new() with Variadic Args ✅

**Decision**: Use `Tuple.new(1, 2, 3)` rather than literal syntax `(1, 2, 3)`

**Rationale**:
- No grammar ambiguity with expression grouping
- Consistent with Quest's object model
- Requires implementing variadic arguments (useful for other features)

### 2. Mutable Elements as Dict Keys ✅

**Decision**: **Runtime error** when tuple containing mutable elements is used as dict key

```quest
let t = Tuple.new([1, 2], 3)  # Contains array
dict[t] = "value"  # Error: Tuple contains mutable element (Array at index 0)
```

**Rationale**: Clear error message prevents subtle bugs from hash invalidation

### 3. Unpacking with Underscore ✅

**Decision**: Support `_` for ignoring values

```quest
let (x, _, z) = Tuple.new(1, 2, 3)  # x=1, z=3
```

**Rationale**: Common pattern, minimal complexity

### 4. Empty Tuples ✅

**Decision**: **Not supported** - tuples must have at least one element

```quest
Tuple.new()  # Error: Tuple requires at least one element
```

**Rationale**: Empty tuple has limited use cases; use `nil` instead

### 5. Rest/Spread Operator ✅

**Decision**: **Not supported** in MVP

```quest
let (first, ...rest) = tuple  # Not implemented
```

**Rationale**: Defer to future QEP - adds complexity, less common

### 6. Tuple Comparison Semantics

**Decision**: Lexicographic comparison (element-by-element)

```quest
Tuple.new(1, 2) < Tuple.new(1, 3)     # true
Tuple.new(1, 2, 3) < Tuple.new(1, 2)  # false (longer is greater)
```

**Rationale**: Matches Python/Ruby behavior, intuitive

### 7. Type Annotations

**Decision**: Start with generic `tuple` annotation

```quest
tuple: coords  # Generic tuple type
```

**Future**: Typed tuples like `tuple<int, int>` in later QEP

## Comparison with Other Languages

### Python
```python
empty = ()
single = (42,)  # Trailing comma required
pair = (1, 2)
x, y = pair     # Unpacking
```

### Rust
```rust
let empty: () = ();
let single = (42,);
let pair = (1, 2);
let (x, y) = pair;
```

### Ruby
```ruby
# No native tuple - uses arrays or returns multiple values
x, y = [1, 2]  # Array unpacking
```

### JavaScript (No native tuples)
```javascript
const pair = [1, 2];  // Uses arrays
const [x, y] = pair;  // Destructuring
```

Quest's tuple syntax is most similar to Python and Rust.

## Backward Compatibility

**Potential Issue**: `()` in expressions

Current Quest code might use `()` for grouping:
```quest
let result = (a + b) * c
```

**Resolution**: Grouping with single expression and no comma remains unchanged.

Only `()` (empty), `(x,)` (trailing comma), or `(x, y)` (multiple elements) are tuples.

## Implementation Phases

### Phase 1: Core Tuple Type
- [x] Internal `QTuple` struct
- [x] Tuple literal parsing `(1, 2, 3)`
- [x] Element access `tuple[0]`
- [x] Basic methods: `len()`, `get()`, `contains()`
- [x] Type checking and immutability
- [x] `_str()`, `_rep()`, `_type()` implementations

### Phase 2: Unpacking
- [x] Basic unpacking: `let (x, y) = (1, 2)`
- [x] Nested unpacking: `let (a, (b, c)) = (1, (2, 3))`
- [x] Underscore ignore: `let (x, _, z) = (1, 2, 3)`

### Phase 3: Dictionary Keys
- [x] Hashing implementation
- [x] Validation for mutable elements
- [x] Dict key usage
- [x] Error messages

### Phase 4: Advanced Features (Optional)
- [ ] Rest operator: `let (first, ...rest) = tuple`
- [ ] Typed tuples: `(int, str)` annotations
- [ ] Pattern matching integration (when implemented)

## Testing Requirements

### Unit Tests
1. Tuple creation (empty, single, multiple elements)
2. Element access (valid indices, out of bounds)
3. Immutability enforcement
4. Unpacking (basic, nested, with underscore)
5. Comparison and equality
6. Hashing and dict key usage
7. Iteration
8. Method calls (len, contains, etc.)
9. Type checking
10. Edge cases (nested tuples, mixed types)

### Integration Tests
1. Function multiple returns
2. Database query results
3. Game coordinates
4. Error handling

## Performance Considerations

- **Memory**: Similar to Array (Vec<QValue> + object ID)
- **Creation**: ~O(n) to clone elements
- **Access**: O(1) indexing
- **Hashing**: O(n) to hash all elements
- **Comparison**: O(n) worst case

## Migration Path

No breaking changes - this is a pure addition. Existing code continues to work.

Optional: Add linter suggestion to use tuples for fixed-size returns.

## References

- Python tuples: https://docs.python.org/3/tutorial/datastructures.html#tuples-and-sequences
- Rust tuples: https://doc.rust-lang.org/book/ch03-02-data-types.html#the-tuple-type
- Swift tuples: https://docs.swift.org/swift-book/LanguageGuide/TheBasics.html

## Implementation Checklist

### Phase 1: Variadic Arguments (Prerequisite)
- [ ] Add grammar for `...args` syntax
- [ ] Parser support for variadic parameters
- [ ] Evaluator: Pack remaining args into Tuple
- [ ] Tests for variadic functions

### Phase 2: Core Tuple Type
- [ ] `QTuple` struct in `src/types/tuple.rs`
- [ ] `QValue::Tuple` variant
- [ ] `Tuple.new(...elements)` constructor
- [ ] Element access `tuple[index]`
- [ ] Basic methods: `len()`, `get()`, `contains()`, `count()`, `index()`
- [ ] Type checking: `cls()`, `_type()`, `_rep()`, `_str()`
- [ ] Immutability enforcement
- [ ] Tests for creation and access

### Phase 3: Unpacking/Destructuring
- [ ] Grammar for `let (x, y) = ...`
- [ ] Support nested unpacking
- [ ] Support underscore `_` for ignored values
- [ ] Error handling for length mismatch
- [ ] Tests for unpacking

### Phase 4: Dictionary Keys
- [ ] Hash implementation for Tuple
- [ ] Validation: error if contains mutable elements
- [ ] Dict key integration
- [ ] Tests for tuples as keys

### Phase 5: Comparison & Iteration
- [ ] Equality operators (`==`, `!=`)
- [ ] Comparison operators (`<`, `>`, `<=`, `>=`)
- [ ] Lexicographic comparison logic
- [ ] Iterator implementation
- [ ] Tests for comparison and iteration

### Phase 6: Conversion Methods
- [ ] `to_array()` method
- [ ] `Tuple.from_array(arr)` static method
- [ ] Tests for conversions

## Status

**Ready for Implementation** - All design decisions finalized.

**Key Decisions**:
- ✅ Use `Tuple.new()` with variadic args
- ✅ Runtime error for mutable elements as dict keys
- ✅ Support `_` for unpacking
- ✅ No empty tuples
- ✅ No spread operator in MVP
- ✅ Lexicographic comparison
