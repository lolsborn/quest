# Bug #017: `pub` Keyword Not Implemented for Field Visibility

**Status:** Open
**Severity:** High
**Priority:** P0
**Discovered:** 2025-10-08 (Fuzz Testing Sessions 001, 002)
**Component:** Type System / Field Access

---

## Summary

Type fields are private by default with no working mechanism to make them public. The `pub` keyword is documented in `CLAUDE.md` but not implemented in the parser or runtime. This makes user-defined types nearly unusable for data objects, forcing verbose getter methods for every field access.

---

## Impact

- **Cannot test or validate type instances** - Field access raises `AttrErr` even for simple data types
- **Forces verbose getter boilerplate** - Every field needs a method for external access
- **Blocks type system usability** - Makes Quest types impractical compared to dicts/arrays
- **Documentation mismatch** - `CLAUDE.md` shows `pub` keyword that doesn't work

---

## Current Behavior

```quest
type Point
    x: Int
    y: Int
end

let p = Point.new(x: 10, y: 20)
puts(p.x)  # AttrErr: Field 'x' of type Point is private
```

**Error Message:**
```
AttrErr: Field 'x' of type Point is private
```

---

## Expected Behavior

### Option A: Rust-style `pub` Keyword (Recommended)

```quest
type Point
    pub x: Int      # Public - accessible as point.x
    pub y: Int      # Public
    secret: Str     # Private - only accessible in methods

    fun get_secret()
        self.secret  # OK - method can access private field
    end
end

let p = Point.new(x: 10, y: 20, secret: "hidden")
puts(p.x)           # 10 - OK
puts(p.y)           # 20 - OK
puts(p.secret)      # AttrErr: Field 'secret' is private
puts(p.get_secret()) # "hidden" - OK via method
```

### Option B: Make All Fields Public by Default (Python/Ruby-style)

```quest
type Point
    x: Int      # Public by default
    y: Int
end

let p = Point.new(x: 10, y: 20)
puts(p.x)  # 10 - OK
```

**Recommendation:** Implement Option A (`pub` keyword) as it:
- Matches existing documentation
- Provides encapsulation control
- Follows Rust conventions (Quest already uses Rust syntax)
- Allows both data-oriented and encapsulated types

---

## Reproduction

### Test Case 1: Simple Data Type

```quest
use "std/test"

type Point
    pub x: Int
    pub y: Int
end

test.describe("Point type", fun ()
    test.it("allows access to public fields", fun ()
        let p = Point.new(x: 10, y: 20)
        test.assert_eq(p.x, 10)  # Currently fails with AttrErr
        test.assert_eq(p.y, 20)  # Currently fails with AttrErr
    end)
end)
```

### Test Case 2: Mixed Public/Private Fields

```quest
type BankAccount
    pub account_number: Str
    pub balance: Int
    pin: Str  # Private

    fun verify_pin(input: Str)
        self.pin == input
    end
end

let account = BankAccount.new(
    account_number: "12345",
    balance: 1000,
    pin: "1234"
)

puts(account.account_number)  # Should work
puts(account.balance)          # Should work
puts(account.pin)              # Should raise AttrErr (private)
puts(account.verify_pin("1234"))  # Should work (method access)
```

### Test Case 3: Current Workaround (Verbose)

```quest
# What users must do today - verbose getter methods
type Point
    x: Int
    y: Int

    fun get_x() self.x end
    fun get_y() self.y end
end

let p = Point.new(x: 10, y: 20)
puts(p.get_x())  # Works but verbose
puts(p.get_y())  # Works but verbose
```

---

## Root Cause Analysis

### Possible Causes

1. **Parser doesn't recognize `pub` keyword** in type field declarations
2. **Runtime doesn't enforce visibility rules** - treats all fields as private
3. **Field access check missing visibility flag** - always raises AttrErr for external access
4. **Incomplete QEP implementation** - feature partially implemented but not finished

### Files Likely Involved

- `src/quest.pest` - Grammar for type field declarations (add `pub` keyword)
- `src/types/struct.rs` or similar - Field storage with visibility metadata
- `src/main.rs` - Field access evaluation (check visibility before allowing access)
- Type definition evaluation - Store `pub` flag per field

---

## Suggested Implementation

### Phase 1: Parser Changes

```pest
// In quest.pest
type_field = { pub_keyword? ~ IDENT ~ ":" ~ type_annotation ~ default_value? }
pub_keyword = { "pub" }
```

### Phase 2: Runtime Storage

```rust
// Store visibility per field
struct FieldDefinition {
    name: String,
    type_annotation: Option<String>,
    is_public: bool,  // NEW: track visibility
    default_value: Option<QValue>,
}
```

### Phase 3: Access Control

```rust
// In field access code
fn access_field(obj: &QStruct, field_name: &str, external_access: bool) -> Result<QValue> {
    let field_def = obj.get_field_definition(field_name)?;

    // NEW: Check visibility for external access
    if external_access && !field_def.is_public {
        return Err(AttrErr::new(format!(
            "Field '{}' of type {} is private",
            field_name,
            obj.type_name()
        )));
    }

    obj.get_field_value(field_name)
}
```

---

## Test Coverage Required

1. **Public field access from external code** ✓
2. **Private field access raises AttrErr** ✓
3. **Private field access from methods works** ✓
4. **Fields default to private when `pub` omitted** ✓
5. **Mixed public/private fields in same type** ✓
6. **Nested types with visibility** (struct containing struct)
7. **Field access in trait implementations**
8. **Field visibility in inherited contexts** (if inheritance added later)

---

## Related Issues

- **Improvement #3:** Implement field visibility (pub keyword)
- **Improvement #26:** Expand type field documentation
- **Improvement #10:** Better error messages for private field access

---

## Documentation Updates Needed

### CLAUDE.md

Update examples to clarify current status:

```markdown
**User-Defined Types**: Rust-inspired structs with field visibility control

type Person
    pub name: Str        # Public field - accessible externally
    pub age: Int?        # Public optional field
    secret: Str          # Private field - only accessible in methods

    fun greet()          # Instance method (has self)
        "Hello, " .. self.name
    end

    fun reveal_secret()  # Private field access via method
        self.secret
    end
end

let person = Person.new(name: "Alice", age: 30, secret: "hidden")
puts(person.name)     # "Alice" - OK (public)
puts(person.age)      # 30 - OK (public)
puts(person.secret)   # AttrErr: Field 'secret' is private
puts(person.reveal_secret())  # "hidden" - OK (via method)
```

### Error Message Improvement

```
AttrErr: Field 'value' of type Calculator is private
  Hint: Add 'pub' before the field declaration to make it public:

        type Calculator
            pub value: Int  # Public field
        end

  Or access via a method:

        fun get_value()
            self.value
        end
```

---

## Priority Justification

**P0 (Critical Path)** because:

1. **Highest user impact** - Blocks practical use of type system
2. **Already documented** - Users expect it to work per CLAUDE.md
3. **Enables testing** - Can't validate type instances without field access
4. **Unblocks other features** - Decorators, trait testing all need field access
5. **No dependencies** - Can be implemented immediately
6. **Clear implementation path** - Well-defined scope and solution

---

## Acceptance Criteria

- [ ] `pub` keyword parses in type field declarations
- [ ] Public fields accessible from external code
- [ ] Private fields (no `pub`) raise AttrErr from external code
- [ ] Private fields accessible from instance methods
- [ ] Mixed public/private fields work correctly
- [ ] Error message suggests adding `pub` keyword
- [ ] Documentation updated with working examples
- [ ] Test suite covers all visibility scenarios
- [ ] Existing tests still pass (all fields currently private)

---

## Notes

- **Backward Compatibility:** Existing code treats all fields as private, so making `pub` explicit is backward compatible
- **Alternative Considered:** Making all fields public by default would be simpler but loses encapsulation benefits
- **Future Enhancement:** Could add `pub(crate)`, `pub(module)` visibility levels like Rust if needed
