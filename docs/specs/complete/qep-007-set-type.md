# QEP-007: Set Type - Unique Collections

**Status:** Draft
**Author:** Quest Team
**Created:** 2025-10-05
**Type:** Built-in Type

## Abstract

This QEP proposes adding Set as a built-in collection type in Quest. Sets are unordered collections of unique elements with efficient membership testing and mathematical set operations (union, intersection, difference, symmetric difference). Sets complement existing collection types (Array, Dict) by providing a data structure optimized for uniqueness and set algebra.

## Rationale

Sets are fundamental data structures used for:
- **Deduplication** - Remove duplicates from arrays
- **Membership testing** - Fast O(1) lookups
- **Set operations** - Union, intersection, difference for data analysis
- **Tag systems** - Unique collections of tags, categories, permissions
- **Graph algorithms** - Visited nodes, adjacency tracking
- **Database operations** - Unique constraints, JOIN-like operations

Many modern languages include sets as built-in types (Python, JavaScript, Ruby, Rust). Quest currently lacks an efficient way to:
1. Store unique values
2. Test membership efficiently
3. Perform set algebra operations

Users currently work around this with dictionaries or manual deduplication, which is verbose and error-prone.

## Design Goals

1. **Immutable by default** - Set operations return new sets (like Python frozenset)
2. **Mutable methods available** - `add()`, `remove()`, `clear()` modify in place
3. **Hash-based** - O(1) membership testing
4. **Type-safe** - Only hashable types allowed (Int, Float, Str, Bool, not Array/Dict)
5. **Operator support** - `|` (union), `&` (intersection), `-` (difference)

## Syntax

### Set Literal

```quest
# Set literal syntax
let s = Set{1, 2, 3}
let colors = Set{"red", "green", "blue"}

# Empty set
let empty = Set{}

# From array (deduplication)
let arr = [1, 2, 2, 3, 3, 3]
let unique = Set.from_array(arr)  # Set{1, 2, 3}
```

### Alternative: Constructor Function

If set literals are too complex to parse initially:

```quest
# Constructor syntax
let s = Set.new([1, 2, 3])
let colors = Set.new(["red", "green", "blue"])
let empty = Set.new([])
```

## API Design

### Constructor

**`Set.new(elements)`**
- Creates set from array
- Automatically removes duplicates
- Returns Set

```quest
let s = Set.new([1, 2, 2, 3])
puts(s)  # Set{1, 2, 3}
```

**`Set.from_array(array)`** (alias for `new()`)

### Membership Methods

**`set.contains(value)`** - O(1) membership test
```quest
let s = Set.new([1, 2, 3])
puts(s.contains(2))  # true
puts(s.contains(5))  # false
```

**`set.len()`** - Number of elements
```quest
let s = Set.new([1, 2, 3])
puts(s.len())  # 3
```

**`set.empty()`** - Check if set is empty
```quest
let s = Set.new([])
puts(s.empty())  # true
```

### Mutation Methods

**`set.add(value)`** - Add element (mutates set)
```quest
let s = Set.new([1, 2])
s.add(3)
puts(s)  # Set{1, 2, 3}
s.add(2)  # No effect (already exists)
```

**`set.remove(value)`** - Remove element (mutates set)
```quest
let s = Set.new([1, 2, 3])
s.remove(2)
puts(s)  # Set{1, 3}
```

**`set.discard(value)`** - Remove if exists (no error if missing)
```quest
let s = Set.new([1, 2, 3])
s.discard(5)  # No error
```

**`set.clear()`** - Remove all elements
```quest
let s = Set.new([1, 2, 3])
s.clear()
puts(s.len())  # 0
```

**`set.pop()`** - Remove and return arbitrary element
```quest
let s = Set.new([1, 2, 3])
let elem = s.pop()
```

### Conversion Methods

**`set.to_array()`** - Convert to array
```quest
let s = Set.new([3, 1, 2])
let arr = s.to_array()
puts(arr)  # [1, 2, 3] (sorted)
```

**`set.sorted()`** - Return sorted array (alias)

### Set Operations (Return New Sets)

**`set.union(other)`** or `set | other`
- Elements in either set
```quest
let s1 = Set.new([1, 2, 3])
let s2 = Set.new([3, 4, 5])
let s3 = s1.union(s2)
puts(s3)  # Set{1, 2, 3, 4, 5}
```

**`set.intersection(other)`** or `set & other`
- Elements in both sets
```quest
let s1 = Set.new([1, 2, 3])
let s2 = Set.new([2, 3, 4])
let s3 = s1.intersection(s2)
puts(s3)  # Set{2, 3}
```

**`set.difference(other)`** or `set - other`
- Elements in first set but not second
```quest
let s1 = Set.new([1, 2, 3])
let s2 = Set.new([2, 3, 4])
let s3 = s1.difference(s2)
puts(s3)  # Set{1}
```

**`set.symmetric_difference(other)`** or `set ^ other`
- Elements in either set but not both
```quest
let s1 = Set.new([1, 2, 3])
let s2 = Set.new([2, 3, 4])
let s3 = s1.symmetric_difference(s2)
puts(s3)  # Set{1, 4}
```

### Set Comparison Methods

**`set.is_subset(other)`** or `set <= other`
```quest
let s1 = Set.new([1, 2])
let s2 = Set.new([1, 2, 3])
puts(s1.is_subset(s2))  # true
```

**`set.is_superset(other)`** or `set >= other`

**`set.is_disjoint(other)`** - No common elements
```quest
let s1 = Set.new([1, 2])
let s2 = Set.new([3, 4])
puts(s1.is_disjoint(s2))  # true
```

### Update Methods (Mutate in Place)

**`set.update(other)`** - Add all elements from other
**`set.intersection_update(other)`** - Keep only common elements
**`set.difference_update(other)`** - Remove elements in other
**`set.symmetric_difference_update(other)`** - XOR update

## Implementation

### Rust Structure

```rust
// src/types/set.rs
use std::collections::HashSet;
use std::rc::Rc;
use std::cell::RefCell;

pub struct QSet {
    // Use HashSet for O(1) operations
    pub elements: Rc<RefCell<HashSet<SetElement>>>,
    pub id: u64,
}

// Wrapper for hashable elements
#[derive(Debug, Clone, Hash, Eq, PartialEq)]
pub enum SetElement {
    Int(i64),
    Float(OrderedFloat<f64>),  // Wrapper for hashable floats
    Str(String),
    Bool(bool),
}

impl QSet {
    pub fn new(elements: Vec<SetElement>) -> Self {
        let set: HashSet<SetElement> = elements.into_iter().collect();
        QSet {
            elements: Rc::new(RefCell::new(set)),
            id: next_object_id(),
        }
    }

    pub fn contains(&self, elem: &SetElement) -> bool {
        self.elements.borrow().contains(elem)
    }

    pub fn add(&self, elem: SetElement) {
        self.elements.borrow_mut().insert(elem);
    }

    // ... other methods
}
```

### QValue Variant

```rust
pub enum QValue {
    // ... existing variants
    Set(QSet),
}
```

### Hashable Float Wrapper

Since floats aren't hashable by default, use ordered float:

```rust
use ordered_float::OrderedFloat;

// Or implement our own:
#[derive(Debug, Clone, Copy)]
struct HashableFloat(f64);

impl Hash for HashableFloat {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.0.to_bits().hash(state)
    }
}

impl Eq for HashableFloat {}
impl PartialEq for HashableFloat {
    fn eq(&self, other: &Self) -> bool {
        self.0.to_bits() == other.0.to_bits()
    }
}
```

## Examples

### Deduplication

```quest
let tags = ["rust", "python", "rust", "javascript", "python"]
let unique_tags = Set.new(tags)
puts(unique_tags.len())  # 3
puts(unique_tags.to_array())  # ["javascript", "python", "rust"]
```

### Membership Testing

```quest
let allowed_users = Set.new(["alice", "bob", "charlie"])

fun is_authorized(username)
    allowed_users.contains(username)
end

puts(is_authorized("alice"))  # true
puts(is_authorized("eve"))    # false
```

### Set Operations

```quest
let group_a = Set.new(["alice", "bob", "charlie"])
let group_b = Set.new(["bob", "charlie", "david"])

# Who's in at least one group?
let all_members = group_a.union(group_b)
puts(all_members)  # Set{"alice", "bob", "charlie", "david"}

# Who's in both groups?
let both_groups = group_a.intersection(group_b)
puts(both_groups)  # Set{"bob", "charlie"}

# Who's only in group A?
let only_a = group_a.difference(group_b)
puts(only_a)  # Set{"alice"}
```

### Tracking Visited Nodes

```quest
let visited = Set.new([])
let to_visit = [1, 2, 3, 4, 5]

for node in to_visit
    if not visited.contains(node)
        visited.add(node)
        # Process node...
    end
end
```

### Finding Unique Values

```quest
let votes = ["alice", "bob", "alice", "charlie", "bob", "alice"]
let unique_voters = Set.new(votes)
puts("Unique voters: " .. unique_voters.len())  # 3
```

## Comparison with Other Languages

### Python
```python
s = {1, 2, 3}              # Quest: Set.new([1, 2, 3])
s = set([1, 2, 2, 3])     # Quest: Set.new([1, 2, 2, 3])
s.add(4)                   # Quest: s.add(4)
s1 | s2                    # Quest: s1.union(s2)
s1 & s2                    # Quest: s1.intersection(s2)
```

### JavaScript
```javascript
const s = new Set([1, 2, 3])   // Quest: Set.new([1, 2, 3])
s.add(4)                        // Quest: s.add(4)
s.has(2)                        // Quest: s.contains(2)
```

### Rust
```rust
use std::collections::HashSet;
let mut s = HashSet::new();    // Quest: Set.new([])
s.insert(1);                    // Quest: s.add(1)
s.contains(&1);                 // Quest: s.contains(1)
```

## Open Questions

1. **Literal syntax - `Set{1, 2, 3}` or constructor `Set.new([1, 2, 3])`?**
   - Literal requires parser changes
   - Constructor works immediately
   - **Decision:** Start with constructor, add literal in Phase 2

2. **Should sets be ordered (preserve insertion order)?**
   - Python 3.7+ preserves order
   - Classic sets are unordered
   - **Decision:** Unordered (true to mathematical sets, simpler implementation)

3. **Operator overloading for set operations?**
   - `s1 | s2` for union, `s1 & s2` for intersection
   - Requires operator overloading support
   - **Decision:** Phase 2 - use methods for now

4. **Equality semantics - value or identity?**
   - `Set.new([1, 2]) == Set.new([1, 2])` → true or false?
   - **Decision:** Value equality (compare elements)

5. **Iteration order?**
   - Unordered by default
   - Could sort when converting to array
   - **Decision:** `to_array()` returns sorted array for consistency

## Implementation Checklist

- [ ] Add `ordered-float` crate to Cargo.toml (for hashable floats)
- [ ] Create `src/types/set.rs`
- [ ] Implement `QSet` struct with `HashSet` backend
- [ ] Implement `SetElement` enum for hashable types
- [ ] Add `QValue::Set` variant
- [ ] Implement `Set.new()` constructor
- [ ] Implement membership methods (contains, len, empty)
- [ ] Implement mutation methods (add, remove, clear)
- [ ] Implement set operations (union, intersection, difference)
- [ ] Implement comparison methods (is_subset, is_superset, is_disjoint)
- [ ] Implement `to_array()` conversion
- [ ] Add to all QValue match statements
- [ ] Write comprehensive test suite
- [ ] Document in CLAUDE.md

## Conclusion

Adding Set as a built-in type fills an important gap in Quest's collection types. With Array for ordered sequences, Dict for key-value mappings, and Set for unique collections, Quest will have a complete set of fundamental data structures. The implementation leverages Rust's efficient `HashSet` while providing a Pythonic API familiar to developers.

**Next Steps:** Implement constructor-based API first (no syntax changes), then consider adding `Set{...}` literal syntax in a future QEP.
