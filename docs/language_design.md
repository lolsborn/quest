# Quest Language Design Decisions

This document captures the core design decisions and principles that guide Quest's implementation. These decisions inform how features are implemented and help maintain consistency as the language evolves.

## 1. Closure Semantics

**Decision: Closure by Reference (Python/Ruby style)**

Quest functions capture their lexical environment **by reference**, not by value. This means closures see modifications to outer variables made after the closure is created.

```quest
let x = 1

fun increment()
    x = x + 1  # Modifies outer x
end

increment()
puts(x)  # Prints: 2
```

**Rationale:**
- Matches Python, Ruby, JavaScript behavior
- Enables stateful closures and counter patterns
- More intuitive for module-level state management
- Simpler mental model for developers coming from mainstream languages

**Implementation:**
- Functions store body as string, not pre-compiled AST
- Parent scope is passed during function call, not captured at definition
- Module functions share `Rc<RefCell<HashMap>>` with module state

**Trade-off:** Cannot pre-parse function bodies without complex environment tracking.

---

## 2. Dynamic Evaluation

**Decision: Support `eval()` for Runtime Code Execution**

Quest supports dynamic code evaluation through an `eval()` function that can parse and execute Quest code from strings at runtime.

```quest
let code = "x + 1"
let x = 5
let result = eval(code)  # Returns 6
```

**Rationale:**
- Essential for REPL functionality
- Enables metaprogramming and DSL creation
- Useful for configuration and scripting scenarios
- Matches capabilities of Python, Ruby, JavaScript

**Implementation:**
- All functions store body as string for re-parsing
- Single unified evaluation path (`eval_pair` recursion)
- No separate bytecode or compiled representation

**Trade-off:** Re-parsing on every function call; slower than pre-compiled approaches.

---

## 3. Variable Scoping

**Decision: Lexical Scoping with Explicit Declaration**

Variables must be declared with `let` before use. Assignment to undeclared variables is an error. Scoping follows lexical (static) rules.

```quest
let x = 1        # Declare in outer scope

fun modify()
    x = 10       # Modifies outer x (closure by reference)
    let y = 20   # Declare in function scope
end

modify()
puts(x)  # 10
puts(y)  # Error: y not in scope
```

**Multiple Declaration:**
```quest
let a = 1, b = 2, c = 3  # Single statement, multiple bindings
```

**Rationale:**
- Prevents typo bugs (assigning to wrong variable name)
- Clear distinction between declaration and assignment
- Enables better error messages
- Follows Rust/JavaScript's `let` pattern

**Implementation:**
- `Scope` tracks stack of `HashMap<String, QValue>`
- `declare()` adds to current scope
- `update()` searches scope chain, errors if not found
- `get()` searches from innermost to outermost

---

## 4. Module System

**Decision: Stateful Modules with Explicit Exports via `pub` Keyword**

Modules are loaded once and cached. Module-level variables are shared across all imports. Only items marked with `pub` are exported and accessible from outside the module.

### 4.1 Public vs Private

**Public (Exported):**
```quest
# math_utils.q
pub let PI = 3.14159

pub fun square(x)
    x * x
end

pub type Point
    float: x
    float: y
end
```

**Private (Internal):**
```quest
# math_utils.q
let internal_cache = {}  # Not exported

fun helper(x)  # Not exported
    x + 1
end
```

**Usage:**
```quest
use "math_utils" as math

puts(math.PI)           # OK - public
puts(math.square(5))    # OK - public
let p = math.Point.new(x: 1.0, y: 2.0)  # OK - public

puts(math.internal_cache)  # Error: not exported
math.helper(10)            # Error: not exported
```

### 4.2 Shared State Across Imports

Module state is shared - changes to public module variables are visible to all importers.

```quest
# counter.q
pub let count = 0

pub fun increment()
    count = count + 1
    count
end

# main.q
use "counter" as c1
use "counter" as c2  # Same module, different alias

puts(c1.increment())  # 1
puts(c2.increment())  # 2 (shared state!)
```

### 4.3 Design Rationale

**Why explicit exports?**
- **Encapsulation:** Hide implementation details and internal helpers
- **Clear API:** Only exported items form the module's public interface
- **Refactoring safety:** Internal changes don't break importers
- **Namespace cleanliness:** Prevents accidental exposure of temporary variables
- **Documentation:** `pub` marks what's intended for external use

**Why shared state?**
- Enables singleton patterns and global state management
- Matches Python module behavior
- More efficient than copying module state per import
- Allows modules to maintain internal state (caches, connections, etc.)

**Comparison to other languages:**
- **Rust:** Similar `pub` keyword for visibility
- **Python:** Everything is public by default (convention: `_private`)
- **JavaScript:** `export` keyword for ES6 modules
- **Ruby:** Everything private by default unless explicitly made public

### 4.4 Implementation

**Module Loading:**
1. Parse and evaluate entire module file in fresh scope
2. Scan for `pub` declarations
3. Create `QModule` containing only public members
4. Cache module by canonicalized absolute path
5. Private variables remain in module's internal scope but aren't exported

**Storage:**
- Public members: `Rc<RefCell<HashMap<String, QValue>>>`
- Private members: Kept in module's evaluation scope (not accessible externally)
- Module cache: Maps resolved paths to `QValue::Module`

**Function Execution:**
- Public functions execute in scope with access to both public and private module state
- Private functions can only be called from within the module

### 4.5 Grammar Changes

**Current:**
```
let_statement = { "let" ~ identifier ~ "=" ~ expression }
fn_declaration = { "fun" ~ identifier ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end" }
type_declaration = { "type" ~ identifier ~ field_list ~ "end" }
```

**With `pub`:**
```
pub_modifier = { "pub" }
let_statement = { pub_modifier? ~ "let" ~ identifier ~ "=" ~ expression }
fn_declaration = { pub_modifier? ~ "fun" ~ identifier ~ "(" ~ parameter_list? ~ ")" ~ statement* ~ "end" }
type_declaration = { pub_modifier? ~ "type" ~ identifier ~ field_list ~ "end" }
```

### 4.6 Standard Library Shadowing (QEP-002)

Quest supports **hybrid standard library modules** where Rust-implemented stdlib modules can be extended or overridden by Quest code in the `lib/` directory.

**Module Resolution Order:**

When `use "std/math"` is executed:
1. Load Rust implementation (if it exists)
2. Check for Quest overlay: `lib/std/math.q` or `lib/std/math/index.q`
3. Merge implementations - Quest additions/replacements take precedence

**Quest Overlay Access:**

Overlay files can add new Quest functions and constants. The Rust implementations remain accessible without re-export:

```quest
# lib/std/math.q

# Document existing Rust functions (lazy-loaded on _doc() call)
%fun sin(x)
"""Calculate sine of x in radians."""

%fun cos(x)
"""Calculate cosine of x in radians."""

%fun pi
"""Mathematical constant π ≈ 3.14159"""

# Add new Quest functions (will be merged with Rust module)
pub fun degrees(radians)
    """Convert radians to degrees."""
    radians * 180 / math.pi  # Access Rust implementation directly
end

pub fun radians(degrees)
    """Convert degrees to radians."""
    degrees * math.pi / 180
end

# Add new constants
pub let tau = math.pi * 2
```

**Benefits:**
- User customization of stdlib without modifying Quest source
- Prototyping new stdlib features in Quest before Rust implementation
- Project-specific convenience wrappers
- Documentation via lazy-loaded `%` prefix declarations

**Documentation System:**

Use `%` prefix to document Rust-implemented functions without replacing them:

```quest
# lib/std/math.q
%fun sin(x)

"""
Calculate the sine of x (in radians).

Parameters:
  x: Num - Angle in radians

Returns: Num - Sine value between -1 and 1

Example:
  math.sin(0)      # 0.0
  math.sin(math.pi / 2)  # 1.0
"""
```

The `%` declaration is parsed but ignored during execution. When `math.sin._doc()` is called at runtime, Quest reads `lib/std/math.q`, finds the `%fun sin(x)` declaration, and returns the documentation string. **No re-export needed** - the Rust implementation remains accessible, but documentation is loaded from the `.q` file on demand.

**Directory Modules:**

Modules can be organized as directories with `index.q`:

```
lib/std/encoding/
├── index.q        # std/encoding module (general utilities)
├── json.q         # std/encoding/json module (JSON-specific)
└── b64.q          # std/encoding/b64 module (Base64-specific)
```

Each is an independent module - no automatic parent-child relationship.

**Implementation:**
- Public members only: Overlay functions/constants must use `pub` to be exported
- Rust functions remain accessible: No re-export needed
- Lazy documentation: `%` declarations are parsed on-demand when `_doc()` is called
- No caching: Documentation is read from `.q` file each time
- Module merging: Quest overlay members are added to Rust module namespace
- Configuration: Can disable via `.settings.toml`

See `docs/specs/qep-002-stdlib-shadowing.md` for complete specification.

### 4.7 Future Considerations

**Selective Exports:**
```quest
# Export only specific items
pub {
    PI,
    square,
    Point
}
```

**Re-exports:**
```quest
pub use "std/math" as math  # Re-export imported module
```

**Visibility Levels:**
```quest
pub(crate) let internal_api = ...  # Future: crate-level visibility
```

---

## 5. Function Calling Conventions

**Decision: Positional Arguments with Future Named Arguments**

Functions use positional parameter matching. Exact arity checking (no varargs yet).

```quest
fun greet(name, age)
    "Hello " .. name .. ", age " .. age
end

greet("Alice", 30)  # OK
greet("Alice")      # Error: expects 2 arguments
```

**Future:** Named arguments for user-defined types already supported:
```quest
type Person
    str: name
    int?: age
end

Person.new(name: "Alice", age: 30)  # Named constructor args
```

**Stack Traces:**
- Every function call pushes `StackFrame` to `Scope.call_stack`
- Stack frames captured on exception creation
- Accessible via `exception.stack()` method

**Return Values:**
- Last evaluated expression is return value
- Explicit `return` statement (future)
- `nil` returned if no explicit value

---

## 6. Type System Philosophy

**Decision: Everything is an Object with Method-Based Operations**

All values in Quest are objects. All operations (even arithmetic) are method calls.

```quest
3.plus(4)     # => 7
3 + 4         # Sugar for 3.plus(4)
"hi".upper()  # => "HI"
```

**Object Identity:**
- Every object has unique ID via `AtomicU64` counter
- `nil` always has ID 0 (singleton)
- Accessible via `obj._id()` method

**QObj Trait:**
All types implement:
- `cls()` - Type name (e.g., "Int", "Str", "Module")
- `q_type()` - Type category (e.g., "num", "str", "module")
- `is(type_name)` - Type checking
- `_str()` - String representation
- `_rep()` - REPL display format
- `_doc()` - Documentation string
- `_id()` - Unique object ID

**Rationale:**
- Uniform interface for all values
- Easy to extend with new types
- Method dispatch is clean and consistent
- Matches Ruby's "everything is an object" philosophy

---

## 7. Memory Model

**Decision: Clone-Heavy with Selective Sharing via Rc<RefCell<>>**

Quest uses Rust's ownership model but abstracts it with liberal cloning. Shared mutable state uses `Rc<RefCell<>>`.

**Clone Semantics:**
- `QValue` is `Clone` - all values can be cheaply copied
- Variable assignment clones values
- Primitives (Int, Float, Bool, Str) are immutable and copied
- Collections (Arrays, Dicts) are mutable via interior mutability

**Shared State:**
- Module members: `Rc<RefCell<HashMap<String, QValue>>>`
- Module cache: `Rc<RefCell<HashMap<String, QValue>>>`
- Current script path: `Rc<RefCell<Option<String>>>`

**Rationale:**
- Simplifies implementation (no lifetime tracking)
- Prevents borrow checker issues in recursive evaluator
- Matches semantics of dynamically-typed languages
- Performance is acceptable for scripting use cases

**Trade-offs:**
- Higher memory usage than reference-based approach
- Some redundant clones during evaluation
- `RefCell` runtime borrow checking (potential panics)

---

## 7.1. Data Structure Mutability

**Decision: Arrays and Dictionaries are Mutable**

Collections (arrays and dictionaries) support in-place mutation. Mutating methods modify the collection directly rather than returning new copies.

```quest
let arr = [1, 2, 3]
arr.push(4)        # Mutates arr in-place
puts(arr.len())    # 4

let map = {"a": 1}
map["b"] = 2       # Mutates map in-place
puts(map.len())    # 2
```

**Mutable Operations:**
- **Arrays**: `push()`, `pop()`, `insert()`, `remove()`, `reverse()`, `sort()`, index assignment `arr[i] = x`
- **Dictionaries**: `set()`, `del()`, key assignment `dict[key] = value`

**Non-Mutating Operations:**
- **Arrays**: `map()`, `filter()`, `slice()`, `concat()` - return new arrays
- **Dictionaries**: `keys()`, `values()`, `each()` - don't modify original

**Rationale:**
- **Ergonomics**: Matches Python, JavaScript, Ruby expectations for collections
- **Performance**: Avoids copying large data structures unnecessarily
- **Common Patterns**: Building arrays/dicts incrementally is natural with mutation
- **Developer Expectations**: Most programmers expect `arr.push()` to modify in-place

**Implementation:**
- Arrays: `Rc<RefCell<Vec<QValue>>>` - shared reference with interior mutability
- Dictionaries: `Rc<RefCell<HashMap<String, QValue>>>` - shared reference with interior mutability
- Clone semantics: Cloning `QValue::Array` creates a new reference to the same underlying data
- Deep clones: Use explicit `.clone()` method when true copying is needed (future feature)

**Trade-offs:**
- Shared references mean mutations visible across all references
- Potential confusion if same array referenced from multiple variables
- Requires interior mutability pattern (`RefCell`) with runtime borrow checking

**Contrast with Primitives:**
- **Primitives** (Int, Float, Bool, Str): Immutable, copied on assignment
- **Collections** (Array, Dict): Mutable, shared references

```quest
# Primitives - copied
let x = 5
let y = x
y = 10
puts(x)  # 5 (unchanged)

# Collections - shared reference
let arr1 = [1, 2, 3]
let arr2 = arr1
arr2.push(4)
puts(arr1.len())  # 4 (same array!)
```

**Future Consideration:**
If deep copy semantics are needed, a `.clone()` method could be added:
```quest
let arr2 = arr1.clone()  # True copy
arr2.push(4)
puts(arr1.len())  # 3 (unchanged)
```

---

## 8. Error Handling

**Decision: Exceptions with Stack Traces**

Quest uses exception-based error handling with try/catch/ensure blocks.

```quest
try
    risky_operation()
catch e
    puts("Error: " .. e.message())
    puts("Stack: " .. e.stack())
ensure
    cleanup()
end
```

**Exception Objects:**
- `type()` - Exception type name
- `message()` - Error message
- `stack()` - Array of stack trace strings
- `line()`, `file()` - Source location (if available)
- `cause()` - Chained exception (if any)

**Stack Traces:**
- Fully implemented with `StackFrame` tracking
- Every function call pushes frame
- Captured when exception is created
- Includes function names (file/line future)

**Typed Catch:**
```quest
catch e: ValueError
    # Only catches ValueError
end
```

**Re-raising:**
```quest
catch e
    log(e)
    raise  # Re-raise same exception
end
```

**Rationale:**
- Familiar to Python/Ruby/JavaScript developers
- Better error messages than return-value based errors
- Stack traces essential for debugging
- `ensure` block guarantees cleanup

---

## 9. Performance Trade-offs

**Decision: Optimize for Simplicity and Maintainability First**

Quest prioritizes:
1. **Code clarity** over micro-optimizations
2. **Feature completeness** over raw speed
3. **Developer happiness** over performance benchmarks
4. **Easy debugging** over clever tricks

**Current Performance Characteristics:**
- **Function body re-parsing:** Every function call parses body string → AST (necessary due to Pest lifetime constraints and closure-by-reference semantics)
- **Liberal cloning:** Values cloned on assignment and parameter passing (simplicity over speed)
- **HashMap lookups:** Variable resolution via scope chain (generally cache-friendly)
- **No bytecode/JIT:** Direct AST interpretation only

**Known Bottlenecks:**
- Function calls in tight loops (re-parsing overhead)
- Large data structure cloning (arrays, dicts)
- Deep scope chains (nested function calls)

**When to Optimize:**
- Profile first, optimize bottlenecks
- Keep optimization behind abstractions
- Don't sacrifice clarity for <10% speedup
- Focus on algorithmic improvements

**Rationale:**
- Quest is a scripting language, not a systems language
- Premature optimization is root of all evil
- Simplicity enables rapid feature development
- Clean code is easier to optimize later

---

## 10. Future Considerations

### 10.1 Potential Optimizations

**Parse Caching (Low-hanging fruit):**
- Cache parsed AST in `QUserFun` after first call
- **Challenges:**
  - Pest `Pair` types have lifetimes tied to input string
  - Would need custom AST structure that owns data
  - Moderate implementation effort (~500 LOC)
- **Compatibility:**
  - ✅ Works with closure-by-reference (scope passed at call time)
  - ✅ Works with `eval()` (dynamic code still parsed normally)
  - ✅ No semantic changes required
- **Expected speedup:** 5-10x for function-heavy code
- **Recommendation:** Worth implementing if profiling shows parse overhead

**String Interning:**
- Reduce memory for repeated variable names
- Faster HashMap key comparisons
- Requires global intern table
- **Expected speedup:** 10-20% on memory bandwidth

**Bytecode Compilation:**
- Parse once, compile to bytecode
- Interpreter executes bytecode instead of AST
- Requires: custom IR design, bytecode format, interpreter loop
- Trade-off: Major complexity vs 5-10x speedup
- **Compatibility:** Same as parse caching

**JIT Compilation:**
- Hot function detection
- Compile to native code via Cranelift or similar
- Requires: type inference, register allocation, calling conventions
- Trade-off: Major complexity for 10-100x speedup on hot loops
- **Compatibility:** Requires type profiling for closure variables

**Scope Lookup Caching:**
- Cache variable lookups for frequently-accessed globals
- Invalidate on scope changes
- Trade-off: Complexity vs 20-30% speedup
- **Compatibility:** Breaks if closures mutate captured variables

### 10.2 Language Features

**Pattern Matching:**
```quest
match value
    case 0 -> "zero"
    case 1..10 -> "small"
    case _ -> "large"
end
```

**Generators/Iterators:**
```quest
fun count_up(n)
    let i = 0
    while i < n
        yield i
        i = i + 1
    end
end
```

**Async/Await:**
```quest
async fun fetch_data(url)
    let response = await http.get(url)
    response.json()
end
```

**Macros/Metaprogramming:**
```quest
macro benchmark(name, body)
    # Code generation
end
```

### 10.3 Implementation Challenges

**Closure Pre-Compilation:**
- Want: Parse once for speed
- Need: Capture by reference semantics
- Solution: Hybrid approach with environment snapshots and mutation tracking

**Custom AST for Caching:**
- Pest `Pair` lifetimes prevent storage
- Need: Custom AST that owns data
- Challenge: Large implementation effort, memory overhead

**RefCell Borrow Conflicts:**
- Current: Module state in `Rc<RefCell<>>`
- Issue: Nested calls can cause borrow panics
- Solution: `RwLock`, message passing, or single-threaded check elimination

---

## Design Principles Summary

1. **Developer Happiness First** - Ergonomics > Performance
2. **Explicit Over Implicit** - Clear syntax, fewer surprises
3. **Closure by Reference** - Mutable shared state in closures
4. **Dynamic When Needed** - Support `eval()` and runtime flexibility
5. **Objects All The Way Down** - Uniform method-based interface
6. **Exceptions for Errors** - Stack traces and structured error handling
7. **Simplicity in Implementation** - Clone liberally, optimize later
8. **Module State is Shared** - Singleton-like module behavior
9. **Lexical Scoping** - Predictable variable resolution
10. **Future-Proof Design** - Keep optimization paths open

---

## Decision-Making Process

When adding new features or making implementation choices:

1. **Does it align with "developer happiness"?**
   - Is the syntax intuitive?
   - Does it reduce boilerplate?
   - Will users find it natural?

2. **Does it maintain semantic consistency?**
   - Does it follow closure-by-reference semantics?
   - Is it compatible with `eval()`?
   - Does it work with the object system?

3. **Is the implementation maintainable?**
   - Can future contributors understand it?
   - Does it add significant complexity?
   - Are trade-offs documented?

4. **Are performance implications acceptable?**
   - Is it fast enough for scripting use cases?
   - Can it be optimized later if needed?
   - Does it create pathological slowdowns?

5. **Is it future-proof?**
   - Does it block future optimizations?
   - Can it evolve as the language grows?
   - Is there a migration path?

When in doubt, prioritize **simplicity and clarity** over **cleverness and speed**.

---

## Runtime Optimizations

While Quest's design philosophy is "clone liberally, optimize later," several key optimizations have been implemented to improve performance without compromising semantics or maintainability.

### Heap Allocation Optimizations

#### 1. Bool Singleton Pattern
- **Implementation**: Two static instances (true/false) using `OnceLock`
- **Impact**: 99.99% reduction in Bool allocations (15,004 → 2)
- **Trade-off**: Cloning still happens, but objects are shared (same ID)
- **Rationale**: Only 2 possible values, perfect for singleton pattern
- **File**: `src/types/bool.rs`

#### 2. Integer Cache [-128, 127]
- **Implementation**: Pre-allocated array of 256 QInt objects using `OnceLock`
- **Impact**: 64% reduction in Int allocations (140,011 → ~50,000)
- **Coverage**: Loop counters, array indices, small arithmetic (99% of integer usage)
- **Cache size**: 4 KB (256 × 16 bytes)
- **Rationale**: Small integers are extremely common in loops and indexing
- **File**: `src/types/int.rs`

#### 3. Reference-Counted Strings
- **Implementation**: Changed `QString.value` from `String` to `Rc<String>`
- **Impact**: String cloning 10-400x faster (depends on string length)
- **Clone cost**: ~3ns (refcount increment) vs 30-1200ns (full copy)
- **Memory**: Shared string data between clones, 50% smaller QString struct
- **Rationale**: Quest strings are immutable, perfect for Rc
- **File**: `src/types/string.rs`

### Stack Allocation Optimizations

#### 4. Boxed Large Enum Variants
- **Implementation**: Wrapped large QValue variants in `Box<T>`
- **Variants boxed**: Dict, Type, Struct, Module, UserFun
- **Impact**: 88% reduction in stack copying (QValue: 200 bytes → 24 bytes)
- **Stack savings**: 7 MB per 10k operations
- **Trade-off**: 2ns pointer dereference for boxed types (~1% of operations)
- **Rationale**: Large types used infrequently, small types (Int/Float/Str) stay inline
- **Files**: 29 source files updated to wrap/unwrap Box

### Profiling & Debugging

#### QUEST_CLONE_DEBUG Environment Variable
- **Purpose**: Track object allocations and deallocations for profiling
- **Usage**: `QUEST_CLONE_DEBUG=1 quest script.q`
- **Output**: Per-object allocation/deallocation logs + summary statistics
- **Overhead**: <1% when disabled (early return on static bool check)
- **Key insight**: Revealed 1.6x clone factor (260k deallocs vs 160k allocs)
- **File**: `src/alloc_counter.rs`

### Performance Characteristics

#### Combined Impact
- **Heap allocations**: 60% reduction (175k → 70k)
- **malloc/free calls**: 67% reduction (420k → 140k)
- **Stack copying**: 88% reduction (8 MB → 960 KB per 10k ops)
- **Overall speedup**: Estimated 10-15%

#### Clone Factor Analysis
Quest's value semantics cause extensive cloning:
- Bool: 7,502x clone factor (2 allocations, 15,004 deallocations)
- Int: 1.54x clone factor (arithmetic clones operands)
- Str: 1.50x clone factor (concatenation creates temps)

This is **correct behavior** for immutability, but optimizations make it much cheaper.

### Design Philosophy Maintained

All optimizations preserve Quest's core principles:
- ✅ **Developer happiness** - Zero API changes, invisible to users
- ✅ **Simplicity** - Singletons and caching are simple patterns
- ✅ **Correctness** - All tests pass, no semantic changes
- ✅ **Maintainability** - Clean code, comprehensive documentation
- ✅ **Future-proof** - Leaves room for further optimization

The optimizations target **implementation efficiency** without compromising **language semantics**.

### Lessons for Future Development

1. **Profile first** - QUEST_CLONE_DEBUG revealed where to optimize
2. **Common values** - Singleton pattern works for discrete value sets
3. **Immutability enables sharing** - Rc perfect for immutable strings
4. **Enum size matters** - Boxing large variants dramatically reduces stack pressure
5. **Trade-offs work** - Small cost on rare ops, big gain on common ops

These optimizations demonstrate that Quest can be both **developer-friendly** (simple semantics, liberal cloning) and **performant** (smart caching, minimal overhead) through careful implementation choices.
