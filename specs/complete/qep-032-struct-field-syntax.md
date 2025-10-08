# QEP-032: Struct Field Syntax Consistency

**Status:** Draft
**Author:** Quest Language Team
**Created:** 2025-10-06
**Related:** QEP-015 (Type Annotations), SYNTAX_CONVENTIONS.md, LANGUAGE_COMPARISON.md

## Abstract

This QEP proposes changing struct field declaration syntax from `type: name` to `name: type` to achieve consistency with function parameters, variable declarations, and industry standards across all major programming languages.

## Motivation

### Current Inconsistency

Quest currently uses **different syntax** for struct fields vs everything else:

```quest
# Struct fields - CURRENT (type: name)
type Person
    str: name
    int: age
    str?: email
end

# Function parameters - PLANNED (name: type - QEP-015)
fun greet(name: str, age: Int) -> str
    # ...
end

# Variable declarations - PLANNED (name: type - QEP-015)
let name: str = "Alice"
let age: Int = 30
```

### Problems This Causes

#### 1. **Inconsistent with ALL Major Languages**

**Zero major languages use `type: name` for struct/class fields:**

| Language | Syntax | Example |
|----------|--------|---------|
| Python | `name: type` | `class Person:\n    name: str` |
| TypeScript | `name: type` | `interface Person { name: string }` |
| Rust | `name: type` | `struct Person { name: String }` |
| Swift | `name: type` | `struct Person { var name: String }` |
| Kotlin | `name: type` | `data class Person(val name: String)` |
| Go | `name type` | `type Person struct { name string }` |
| C++ | `type name` | `struct Person { string name; }` |
| **Quest (current)** | **`type: name`** | **`str: name` (UNIQUE TO QUEST)** |

Even C++ and Java (which use `type name`) put the **name** in the field declaration, not buried after the colon.

#### 2. **Internal Inconsistency**

Three different parts of Quest will use three different patterns:

```quest
# Structs use type: name (current)
type Person
    str: name

    # Functions use name: type (QEP-015)
    fun greet(greeting: str) -> str
        greeting .. ", " .. self.name
    end
end

# Variables use name: type (QEP-015)
let person: Person = Person.new(name: "Alice")
```

**This is confusing** - why should field declarations be different?

#### 3. **Call Site Mismatch**

Constructor calls use `name: value`, but field declarations are reversed:

```quest
# Declaration (current)
type Person
    str: name    # type: name
    int: age     # type: name
end

# Call site
Person.new(name: "Alice", age: 30)  # name: value
#          ^^^^           ^^^
#          Field name comes first at call site,
#          but comes second in declaration!
```

#### 4. **Poor Alignment**

Current syntax makes fields hard to scan:

```quest
# Current - types first (misaligned names)
type Config
    str: hostname
    int: port
    int: timeout
    bool: ssl_enabled
    str: log_level
    int?: max_connections
    str?: backup_host
```

Compare to proposed:

```quest
# Proposed - names first (clean alignment)
type Config
    hostname:         str
    port:             int
    timeout:          int
    ssl_enabled:      bool
    log_level:        str
    max_connections:  int?
    backup_host:      str?
```

Field names align, types align - much easier to scan.

#### 5. **Learning Curve**

New users from Python/TypeScript/Rust/Swift/Kotlin must learn Quest's unique syntax:

```python
# Python developer writes (natural)
class Person:
    name: str
    age: Int

# Then learns Quest and sees (confusing)
type Person
    str: name    # Wait, backwards?
    int: age
```

### Solution: Change to `name: type`

```quest
type Person
    name: str           # Consistent with functions
    age: Int
    email: str?         # Optional uses ? after type

    fun greet(other: str) -> str
        "Hello " .. other .. ", I'm " .. self.name
    end
end

# Call site (unchanged)
Person.new(name: "Alice", age: 30, email: "alice@example.com")

# Variable declarations (consistent)
let person: Person = Person.new(name: "Alice")
```

## Design Principles

### 1. Universal Consistency

**Same pattern everywhere:**
- Struct fields: `name: type`
- Function params: `name: type`
- Variable declarations: `name: type`
- Lambda params: `name: type`
- Type annotations: `value: type`

### 2. Industry Standards

Follow what **every major language** does:
- Python: `name: type`
- TypeScript: `name: type`
- Rust: `name: type`
- Swift: `name: type`
- Kotlin: `name: type`

Quest should not be unique here without strong justification.

### 3. Call Site Alignment

Declaration order should match call site order:

```quest
# Declaration
type Person
    name: str    # name comes first

# Call site
Person.new(name: "Alice")  # name comes first
```

### 4. Visual Clarity

Names should align for easy scanning:

```quest
type Server
    host:      str
    port:      int
    timeout:   int?
    debug:     bool
```

## Specification

### New Syntax

```quest
type TypeName
    field_name: type_annotation
    optional_field: type_annotation?

    fun method(param: type) -> return_type
        # method body
    end
end
```

### Grammar Changes

```pest
// CURRENT (to be removed)
field_declaration_old = {
    type_expr ~ ":" ~ identifier ~ "?"?
}

// NEW (to be adopted)
field_declaration = {
    identifier ~ ":" ~ type_expr ~ "?"?
}

// During transition, support both with deprecation warning
field_declaration_transitional = {
    identifier ~ ":" ~ type_expr ~ "?"?         // New (preferred)
    | type_expr ~ ":" ~ identifier ~ "?"?       // Old (deprecated)
}
```

### Optional Marker Position

The `?` for optional fields comes **after the type**:

```quest
# ✓ Correct
type Person
    name: str       # Required
    age: Int?       # Optional
    email: str?     # Optional

# ✗ Wrong
type Person
    name?: str      # Error: ? must be after type
```

**Rationale:** Matches optional parameter syntax and is consistent with TypeScript/Swift.

## Examples

### Example 1: Basic Struct

**Before (current):**
```quest
type Person
    str: name
    int: age
    str?: email
end
```

**After (proposed):**
```quest
type Person
    name: str
    age: Int
    email: str?
end
```

### Example 2: Struct with Methods

**Before (current):**
```quest
type Rectangle
    float: width
    float: height

    fun area() -> float
        self.width * self.height
    end

    fun perimeter() -> float
        2.0 * (self.width + self.height)
    end
end
```

**After (proposed):**
```quest
type Rectangle
    width: float
    height: float

    fun area() -> float
        self.width * self.height
    end

    fun perimeter() -> float
        2.0 * (self.width + self.height)
    end
end
```

### Example 3: Complex Type

**Before (current):**
```quest
type Config
    str: hostname
    int: port
    int: timeout
    bool: ssl_enabled
    str: log_level
    int?: max_connections
    str?: backup_host

    fun validate() -> bool
        self.port > 0 and self.timeout > 0
    end
end
```

**After (proposed):**
```quest
type Config
    hostname:         str
    port:             int
    timeout:          int
    ssl_enabled:      bool
    log_level:        str
    max_connections:  int?
    backup_host:      str?

    fun validate() -> bool
        self.port > 0 and self.timeout > 0
    end
end
```

### Example 4: Nested Types

**Before (current):**
```quest
type Address
    str: street
    str: city
    str: zipcode
end

type Company
    str: name
    Address: headquarters
    int: employee_count
end
```

**After (proposed):**
```quest
type Address
    street:  str
    city:    str
    zipcode: str
end

type Company
    name:            str
    headquarters:    Address
    employee_count:  int
end
```

### Example 5: Trait Implementation

**Before (current):**
```quest
trait Drawable
    fun draw()
end

type Circle
    float: radius
    float: x
    float: y

    impl Drawable
        fun draw()
            puts("Drawing circle at (", self.x, ",", self.y, ")")
        end
    end
end
```

**After (proposed):**
```quest
trait Drawable
    fun draw()
end

type Circle
    radius: float
    x: float
    y: float

    impl Drawable
        fun draw()
            puts("Drawing circle at (", self.x, ",", self.y, ")")
        end
    end
end
```

### Example 6: With Defaults (Future)

```quest
type Server
    host: str = "0.0.0.0"
    port: Int = 8080
    debug: bool = false
end

# Usage
let s1 = Server.new()  # All defaults
let s2 = Server.new(port: 3000)  # Override one field
```

## Migration Strategy

### Phase 1: Add Support for New Syntax (Deprecation Period)

**Support both syntaxes with warnings:**

```rust
// In parser
match field_pair.as_rule() {
    Rule::field_declaration => {
        // Try new syntax first
        if let Ok(field) = parse_new_field_syntax(field_pair) {
            field
        } else if let Ok(field) = parse_old_field_syntax(field_pair) {
            // Print deprecation warning
            eprintln!(
                "Warning: 'type: name' syntax is deprecated at {}:{}. Use 'name: type' instead.",
                file, line
            );
            field
        } else {
            return Err("Invalid field declaration".to_string());
        }
    }
}
```

**Warnings shown:**
```
Warning: 'str: name' syntax is deprecated at config.q:3
  Use 'name: str' instead.
  The old syntax will be removed in Quest 1.0

  3 | type Person
  4 |     str: name    ← Change to: name: str
  5 |     int: age     ← Change to: age: Int
```

### Phase 2: Update All Existing Code

**Automated migration tool:**

```bash
# Tool to update all .q files
quest migrate --struct-syntax ./

# Preview changes without applying
quest migrate --struct-syntax --dry-run ./
```

**Find/replace logic:**
```rust
// Regex pattern (simplified)
old: r"(\w+)\s*:\s*(\w+)"  // type: name
new: "$2: $1"               // name: type

// But must be inside type blocks only
// And handle ? correctly
```

**Update:**
1. All test files in `test/`
2. All examples in `examples/`
3. All stdlib files in `lib/std/`
4. Documentation in `docs/`
5. `CLAUDE.md`

### Phase 3: Remove Old Syntax Support

After adequate deprecation period (e.g., 3 months or 2 minor versions):

```rust
// Remove old syntax support entirely
field_declaration = {
    identifier ~ ":" ~ type_expr ~ "?"?
}
// Old syntax now causes parse error
```

### Phase 4: Update Documentation

Update all references:
- ✅ CLAUDE.md
- ✅ QEP documents
- ✅ Tutorial/guides
- ✅ Language specification
- ✅ Examples

## Backward Compatibility

### During Transition

**Both syntaxes work:**
```quest
type Person
    # Old syntax (deprecated warning)
    str: name

    # New syntax (preferred)
    age: Int
end
```

**No runtime behavior changes** - only syntax changes.

### After Transition

**Only new syntax works:**
```quest
type Person
    name: str    # ✓ OK
    str: name    # ✗ Parse error
end
```

### Constructor Calls (No Change)

```quest
# Construction syntax unchanged
Person.new(name: "Alice", age: 30)

# Always has been name: value
# Will continue to be name: value
```

## Benefits

### 1. Universal Consistency

**One pattern for all type annotations:**

```quest
# Variables
let x: Int = 5

# Function params
fun greet(name: str, age: Int)

# Struct fields
type Person
    name: str
    age: Int

# All use: name: type
```

### 2. Familiar to All Developers

Python, TypeScript, Rust, Swift, Kotlin developers all recognize:
```quest
type Person
    name: str
    age: Int
```

### 3. Better Readability

```quest
# Names align, types align
type Config
    hostname:    str
    port:        int
    timeout:     int
    ssl:         bool
    debug:       bool
```

### 4. Matches Call Sites

```quest
# Declaration order
type Person
    name: str    # name first

# Call order
Person.new(name: "Alice")  # name first
```

### 5. Easier Teaching

"In Quest, type annotations are always `name: type`"

vs

"In Quest, type annotations are `name: type` except for struct fields which are `type: name`"

## Costs

### 1. Breaking Change

All existing Quest code with structs must be updated.

**Mitigation:**
- Automated migration tool
- Deprecation period with warnings
- Only affects pre-1.0 code (acceptable)

### 2. Implementation Work

- Parser changes
- Test updates
- Documentation updates

**Mitigation:**
- Straightforward find/replace for most cases
- Worth it for long-term consistency

### 3. Temporary Confusion

During transition, both syntaxes exist.

**Mitigation:**
- Clear warnings pointing to new syntax
- Short deprecation period
- Good documentation

## Implementation Checklist

### Phase 1: Grammar and Parser (v0.X)
- [ ] Update `field_declaration` rule in quest.pest
- [ ] Add support for new `name: type` syntax
- [ ] Keep support for old `type: name` syntax (deprecated)
- [ ] Add deprecation warnings when old syntax used
- [ ] Add tests for both syntaxes

### Phase 2: Migration Tool (v0.X)
- [ ] Create `quest migrate` command
- [ ] Implement struct syntax converter
- [ ] Add `--dry-run` option
- [ ] Add tests for migration tool
- [ ] Document migration tool usage

### Phase 3: Update Codebase (v0.X)
- [ ] Run migration tool on `test/`
- [ ] Run migration tool on `examples/`
- [ ] Run migration tool on `lib/std/`
- [ ] Update all documentation
- [ ] Update CLAUDE.md
- [ ] Update all QEPs
- [ ] Verify all tests pass

### Phase 4: Deprecation Period (v0.X - v0.Y)
- [ ] Release with both syntaxes supported
- [ ] Collect user feedback
- [ ] Help users migrate their code
- [ ] Monitor deprecation warning usage
- [ ] Set removal date (e.g., 3 months)

### Phase 5: Remove Old Syntax (v1.0)
- [ ] Remove old syntax support from parser
- [ ] Remove transitional grammar rules
- [ ] Remove deprecation warnings (no longer needed)
- [ ] Update error messages for old syntax
- [ ] Final documentation sweep

## Timeline

**Recommended timeline for Quest pre-1.0:**

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Development | 1-2 weeks | New syntax supported, migration tool ready |
| Internal migration | 1 week | All Quest code updated |
| Deprecation period | 3 months | Users migrate their code |
| Removal | v1.0 release | Old syntax removed |

**If Quest is already post-1.0:** Extend deprecation period to 6-12 months.

## Alternatives Considered

### Alternative 1: Keep Current Syntax

**Rejected:** Inconsistent with literally every major language. No compelling reason to be different.

### Alternative 2: Support Both Forever

**Rejected:** Having two ways to do the same thing is confusing and leads to inconsistent codebases.

### Alternative 3: Make Both Type-First

Make functions use `type: name` too:

```quest
fun greet(str: name, int: age)  # Match structs
```

**Rejected:** This makes Quest inconsistent with ALL modern languages for function parameters. Even worse than current situation.

### Alternative 4: Use No Colons

```quest
type Person
    name str
    age int
```

**Rejected:** Less clear than `name: type`. The colon provides visual separation.

## FAQ

### Q: Why change established syntax?

**A:** Because Quest is (presumably) pre-1.0, and this is the RIGHT time to fix inconsistencies. Post-1.0, breaking changes are much more painful.

### Q: Isn't this just cosmetic?

**A:** Syntax consistency affects:
- Learning curve for new users
- Code readability
- Alignment with industry standards
- Internal mental model consistency

These are important for language adoption.

### Q: What if users like the current syntax?

**A:** The evidence suggests `name: type` is superior:
- Used by Python, TypeScript, Rust, Swift, Kotlin
- More readable (names align)
- Matches call sites
- Consistent with function syntax

If Quest's current syntax were better, other languages would have adopted it. They haven't.

### Q: Can I customize this per-project?

**A:** No. Quest should have ONE way to declare struct fields, not multiple. Consistency across the ecosystem is valuable.

## See Also

- [SYNTAX_CONVENTIONS.md](SYNTAX_CONVENTIONS.md) - Documents current inconsistency
- [LANGUAGE_COMPARISON.md](LANGUAGE_COMPARISON.md) - Shows how other languages do it
- [QEP-015: Type Annotations](qep-015-type-annotations.md) - Function parameter types
- [CLAUDE.md](../CLAUDE.md) - Current language reference

## References

- Python PEP 484 - Type Hints
- TypeScript Handbook - Interfaces
- Rust Book - Defining Structs
- Swift Language Guide - Structures
- Kotlin Documentation - Data Classes

## Copyright

This document is placed in the public domain.
